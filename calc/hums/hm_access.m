function A = hm_access(stl_dir, out_dir)
%HM_ACCESS  Line of sight from the two borescope ports to the gear meshes (MNT-02), on the CATIA parts.
%   A = hm_access(stl_dir)             check only
%   A = hm_access(stl_dir, out_dir)    check and pictures (access_en.png, access_tr.png)
%
%   stl_dir: the CATIA parts exported as STL by cad/anim/export_stl.vbs (case, ring, carrier, sun,
%   planet, gear2, pinion, gen_gear), placed as in cad/scripts/assembly.vbs (ring, sun and planets at
%   z 36, carrier at z 15, first stage at z -75; mm). The STL set is the step 2.9 geometry; the
%   step 3.5 carrier plates and the 3.6 flange change do not move the faces used here.
%   Ports (step 2.10, positions TBR):
%    - BP1, planetary: a radial port through the case wall at z 117, 45 deg from the sensor, between
%      two planets with the carrier at 0. The probe tip stops at r 123 in the annular cavity between
%      the ring front face (z 106), the carrier front plate (r <= 113) and the case front wall, and
%      looks back along -z at the front ends of the ring-planet mesh. The carrier is turned (propeller
%      turned by hand) to bring each planet under the port: here a planet sits at 45 deg.
%    - BP2, first stage: a port in the side wall of the first-stage case on the line tangent to both
%      pitch circles at the pinion-gear pitch point (x from +150 to the mesh), the probe tip at x 60.
%   Each check casts rays from the probe tip to target points over the mesh (face width x depth) and
%   finds the first part each ray hits (Moller-Trumbore): a target is seen if no part lies in the way
%   before the last 3 mm of the ray, or the first hit is a tooth of the meshing pair within the mesh
%   zone of the target (BP1 6 mm; BP2 25 mm, the half-length of the path of contact zone where the
%   tangent line runs inside both tip circles, 19 mm, plus margin). The probe path from the port to
%   the tip is checked the same way.
%   Output A(k): name, tip, view, n_target, n_seen, path_clear, blocking parts.
%
%   Source: Phase 3 report, Section 3.10.

names = {'case', 'ring', 'carrier', 'sun', 'planet', 'gear2', 'pinion', 'gen_gear'};
for k = 1:numel(names)
    T = stlread(fullfile(stl_dir, [names{k} '.stl']));
    M.(names{k}) = struct('P', T.Points, 'F', T.ConnectivityList);
end
a = 82;  a1 = 145.974;  ag = 172.488;  th = 45;
inst = {'case', [0 0 0], 0; 'ring', [0 0 36], 0.756; 'carrier', [0 0 15], th; 'sun', [0 0 36], 2};
for i = 0:3
    inst(end + 1, :) = {'planet', [a * cosd(th + 90 * i), a * sind(th + 90 * i), 36], 0}; %#ok<AGROW>
end
inst = [inst; {'gear2', [0 0 -75], 0; 'pinion', [0 -a1 -75], 180 / 31; ...
               'gen_gear', [ag * cosd(135), ag * sind(135), -57], 0}];
parts = struct('name', {}, 'V', {}, 'F', {});
for k = 1:size(inst, 1)
    m = M.(inst{k, 1});  r = inst{k, 3};
    R = [cosd(r) -sind(r) 0; sind(r) cosd(r) 0; 0 0 1];
    parts(k) = struct('name', inst{k, 1}, 'V', m.P * R' + inst{k, 2}, 'F', m.F);
end

% BP1: planetary, port at 45 deg, z 117
u = [cosd(th) sind(th) 0];
A(1).name = 'BP1 planetary ring-planet mesh';
A(1).port = [160 * u(1:2) 117];  A(1).tip = [123 * u(1:2) 117];
[zz, rr] = meshgrid(106.5, linspace(114, 121, 8));
ang = linspace(-6, 6, 7);
tg = [];
for q = ang
    v = [cosd(th + q) sind(th + q)];
    tg = [tg; rr(:) * v, zz(:)]; %#ok<AGROW>
end
A(1).targets = tg;  A(1).pair = {'ring', 'planet'};  A(1).zone = 6;  A(1).skip_path = {'case'};
% BP2: first stage, pitch point (0, -r1p... ) on the tangent line
r2 = a1 * 110 / 141;
[zq, xq] = meshgrid(linspace(-73, -25, 9), linspace(-8, 8, 5));
A(2).name = 'BP2 first-stage pinion-gear mesh';
A(2).port = [150 -r2 -49];  A(2).tip = [60 -r2 -49];
A(2).targets = [xq(:), -r2 + 0 * xq(:), zq(:)];
A(2).pair = {'gear2', 'pinion'};  A(2).zone = 25;  A(2).skip_path = {};

for k = 1:2
    [ok, blk] = sight(parts, A(k).tip, A(k).targets, A(k).pair, A(k).zone);
    A(k).n_target = size(A(k).targets, 1);
    A(k).n_seen = nnz(ok);
    A(k).seen = ok;
    A(k).blocking = unique(blk(~ok));
    keep = ~ismember({parts.name}, A(k).skip_path);
    [okp, blkp] = sight(parts(keep), A(k).port, A(k).tip, {}, 0);
    A(k).path_clear = okp;
    A(k).path_block = blkp;
end
if nargin > 1
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    for lang = {'en', 'tr'}
        picture(parts, A, out_dir, lang{1});
    end
end
end

function [ok, blk] = sight(parts, o, tg, pair, zone)
% ray from o to each target: first part hit and its distance
nt = size(tg, 1);
ok = false(nt, 1);  blk = repmat({''}, nt, 1);
for j = 1:nt
    d = tg(j, :) - o;  L = norm(d);  d = d / L;
    best = inf;  who = '';
    for k = 1:numel(parts)
        t = ray_mesh(o, d, parts(k).V, parts(k).F);
        t = t(t > 1e-6 & t < L);
        if ~isempty(t) && min(t) < best
            best = min(t);  who = parts(k).name;
        end
    end
    ok(j) = best >= L - 3 || (ismember(who, pair) && best >= L - zone);
    blk{j} = who;
end
end

function t = ray_mesh(o, d, V, F)
% Moller-Trumbore, all triangles at once; t: hit distances
v0 = V(F(:, 1), :);  e1 = V(F(:, 2), :) - v0;  e2 = V(F(:, 3), :) - v0;
p = cross(repmat(d, size(e2, 1), 1), e2, 2);
det = sum(e1 .* p, 2);
s = o - v0;
uu = sum(s .* p, 2) ./ det;
q = cross(s, e1, 2);
vv = (q * d') ./ det;
t = sum(e2 .* q, 2) ./ det;
hit = abs(det) > 1e-12 & uu >= 0 & vv >= 0 & uu + vv <= 1;
t = t(hit);
end

function picture(parts, A, out_dir, lang)
tr = strcmp(lang, 'tr');
col = struct('case', [0.78 0.80 0.83], 'ring', [0.60 0.62 0.66], 'carrier', [0.30 0.62 0.38], ...
             'sun', [0.22 0.44 0.80], 'planet', [0.95 0.56 0.16], 'gear2', [0.42 0.62 0.90], ...
             'pinion', [0.82 0.28 0.25], 'gen_gear', [0.56 0.42 0.76]);
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [0 0 1300 620]);
views = {[1 2 3 4 5 6 7 8], A(1), [100 18], [88 88 108], 55; [9 10 11], A(2), [-30 20], [25 -116 -49], 75};
for p = 1:2
    ax = subplot(1, 2, p);  hold(ax, 'on');  axis(ax, 'equal', 'off');
    for k = views{p, 1}
        fa = 1;  if strcmp(parts(k).name, 'case'), fa = 0.15; end
        patch(ax, 'Faces', parts(k).F, 'Vertices', parts(k).V, 'FaceColor', col.(parts(k).name), ...
              'EdgeColor', 'none', 'FaceAlpha', fa, 'FaceLighting', 'gouraud');
    end
    B = views{p, 2};
    plot3(ax, [B.port(1) B.tip(1)], [B.port(2) B.tip(2)], [B.port(3) B.tip(3)], 'k-', 'LineWidth', 3);
    for j = 1:size(B.targets, 1)
        c = [0.1 0.6 0.2];  if ~B.seen(j), c = [0.85 0.1 0.1]; end
        plot3(ax, [B.tip(1) B.targets(j, 1)], [B.tip(2) B.targets(j, 2)], [B.tip(3) B.targets(j, 3)], ...
              '-', 'Color', [c 0.35]);
    end
    view(ax, views{p, 3});  camlight(ax, 'headlight');
    c0 = views{p, 4};  w = views{p, 5};
    xlim(ax, c0(1) + w * [-1 1]);  ylim(ax, c0(2) + w * [-1 1]);  zlim(ax, c0(3) + w * [-1 1]);
    if tr
        tt = {{'BP1 planet kademesi: gövdede z 117 radyal delik; uç, halka ön yüzü', sprintf('ile taşıyıcı ön plakası arasındaki boşlukta; %d / %d hedef görülüyor', B.n_seen, B.n_target)}, ...
              {'BP2 birinci kademe: yan duvardan teğet bakış,', sprintf('pinyon-dişli kavraması; %d / %d hedef görülüyor', B.n_seen, B.n_target)}};
    else
        tt = {{'BP1 planetary: radial port at z 117, tip in the cavity between', sprintf('the ring front face and the carrier front plate; %d / %d targets seen', B.n_seen, B.n_target)}, ...
              {'BP2 first stage: tangent view through the side wall', sprintf('at the pinion-gear mesh; %d / %d targets seen', B.n_seen, B.n_target)}};
    end
    title(ax, tt{p}, 'FontSize', 11, 'FontWeight', 'normal');
end
exportgraphics(fig, fullfile(out_dir, sprintf('access_%s.png', lang)), 'Resolution', 110);
close(fig);
end
