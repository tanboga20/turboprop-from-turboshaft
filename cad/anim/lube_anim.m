function lube_anim(out_dir, nfr, test, stl_dir)
%LUBE_ANIM  Frames of the oil jet animation: the CATIA gear train turning at the true speed ratios in a
%   ghost case, cooled oil spraying from the jets onto the meshes and bearings and hot oil draining to
%   the scavenge line. Jet positions are illustrative (the oil passages are drawn in Phase 3); jet
%   sizes and flows are those of step 2.7. Run from the repo root after cad/anim/export_stl.vbs.
if nargin < 2, nfr = 300; end
if nargin < 3, test = false; end
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
if nargin < 4, stl_dir = fullfile('cad', 'anim', 'stl'); end
G = struct('zs', 45, 'zp', 37, 'zr', 119, 'a', 82, 'n', 4, 'z1', 31, 'z2', 110, 'zg', 57, ...
           'a1', 145.974, 'ag', 172.488);
names = {'case', 'ring', 'carrier', 'sun', 'planet', 'gear2', 'pinion', 'gen_gear'};
for k = 1:numel(names)
    T = stlread(fullfile(stl_dir, [names{k} '.stl']));
    M.(names{k}) = crease(T.Points, T.ConnectivityList, 32);
end
inst = {'case', 'ring', 'carrier', 'sun', 'planet', 'planet', 'planet', 'planet', 'gear2', 'pinion', 'gen_gear'};
mute = @(c) 0.6 * c + 0.4 * [0.85 0.85 0.85];
col = struct('case', [0.80 0.82 0.85], 'ring', mute([0.60 0.62 0.66]), 'carrier', mute([0.30 0.62 0.38]), ...
             'sun', mute([0.22 0.44 0.80]), 'planet', mute([0.95 0.56 0.16]), 'gear2', mute([0.42 0.62 0.90]), ...
             'pinion', mute([0.82 0.28 0.25]), 'gen_gear', mute([0.56 0.42 0.76]));
hot = [0.92 0.36 0.08];  cool = [0.05 0.42 0.95];

fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'pixels', 'Position', [0 0 1200 760], ...
             'InvertHardcopy', 'off', 'Renderer', 'opengl');
ax = axes(fig, 'Position', [0.02 0.06 0.66 0.86], 'Color', 'w');
hold(ax, 'on');  axis(ax, 'off');
ax.Projection = 'perspective';  ax.DataAspectRatio = [1 1 1];
H = gobjects(1, numel(inst));
for k = 1:numel(inst)
    m = M.(inst{k});
    zc = reshape(m.V(m.F', 3), 3, []);
    if strcmp(inst{k}, 'carrier')                    % rear plate and posts only
        m.F = m.F(any(zc <= 95, 1), :);
    elseif strcmp(inst{k}, 'case')                   % the planetary case and the front wall, nose cut off
        m.F = m.F(all(zc <= 200, 1), :);
    end
    H(k) = patch(ax, 'Faces', m.F, 'Vertices', m.V, 'VertexNormals', m.N, 'FaceColor', col.(inst{k}), ...
                 'EdgeColor', 'none', 'FaceLighting', 'gouraud', 'BackFaceLighting', 'reverselit', ...
                 'AmbientStrength', 0.45, 'DiffuseStrength', 0.6, 'SpecularStrength', 0.25);
    Mi{k} = m; %#ok<AGROW>
end
H(1).FaceAlpha = 0.13;
cyl(ax, [0 0 -192], [0 0 1], 52, 70, [0.55 0.58 0.62]);              % pump pack on the intermediate shaft
light(ax, 'Position', [1 1.2 1.5], 'Style', 'infinite');
light(ax, 'Position', [-1.5 -0.4 0.6], 'Style', 'infinite', 'Color', 0.45 * [1 1 1]);
light(ax, 'Position', [0.2 -1 -1], 'Style', 'infinite', 'Color', 0.25 * [1 1 1]);

% supply line from the cooler into the case, galleries to the jets; scavenge line out of the sump
supply = [170 70 -240; 170 70 -10];
scav = [0 -150 71; 0 -175 71; 0 -175 -240];
plot3(ax, supply(:, 1), supply(:, 2), supply(:, 3), '-', 'Color', [cool 0.30], 'LineWidth', 7);
plot3(ax, scav(:, 1), scav(:, 2), scav(:, 3), '-', 'Color', [hot 0.30], 'LineWidth', 7);
J = {[42 -113.9 -62], [2 -113.9 -62];  [42 -113.9 -36], [2 -113.9 -36];          % first-stage mesh
     [0 -96 -100], [0 -122 -100];  [0 -96 0], [0 -122 0]};                          % input shaft bearings
gal = [170 70 -10; 42 70 -10; 42 -113.9 -10; 42 -113.9 -62];
plot3(ax, gal(:, 1), gal(:, 2), gal(:, 3), '-', 'Color', [cool 0.45], 'LineWidth', 1.8);
gal2 = [42 70 -10; 0 70 -10; 0 -96 -10; 0 -96 -100];
plot3(ax, gal2(:, 1), gal2(:, 2), gal2(:, 3), '-', 'Color', [cool 0.45], 'LineWidth', 1.8);

rng(7);
drops_s = scatter3(ax, nan, nan, nan, 60, cool, 'filled', 'MarkerEdgeColor', 'none');
drops_r = scatter3(ax, nan, nan, nan, 60, hot, 'filled', 'MarkerEdgeColor', 'none');
spray = scatter3(ax, nan, nan, nan, 44, cool, 'filled', 'MarkerEdgeColor', 'w', 'LineWidth', 0.7);
drip = scatter3(ax, nan, nan, nan, 40, hot, 'filled', 'MarkerEdgeColor', 'w', 'LineWidth', 0.7);
nsp = 8;  Ts = 25;  jit = (rand(nsp, 3) - 0.5) * 7;  ph = (0:nsp - 1)' / nsp + rand(nsp, 1) * 0.05;
ndr = 14;  phd = (0:ndr - 1)' / ndr;  xd = (rand(ndr, 1) - 0.5) * 120;  zd = 40 + rand(ndr, 1) * 62;

annotation(fig, 'textbox', [0.02 0.90 0.96 0.08], 'String', ...
    'Yağ memeleri çalışırken: soğutulmuş yağ kavramalara ve rulmanlara', 'EdgeColor', 'none', ...
    'FontSize', 19, 'FontWeight', 'bold', 'FontName', 'Segoe UI', 'HorizontalAlignment', 'center', 'Color', [0.1 0.1 0.1]);
b = sprintf('\\color[rgb]{%g,%g,%g}●\\color[rgb]{0.15,0.15,0.15} ', cool);
r = sprintf('\\color[rgb]{%g,%g,%g}●\\color[rgb]{0.15,0.15,0.15} ', hot);
leg = {'\bf32 meme ve delik, 400 kPa\rm'
       [b 'Birinci kademe kavraması: 2 × 1,55 mm, 3,3 L/dk']
       [b 'Planet kavramaları, güneş tarafından:']
       '     8 × 0,79 mm, 3,8 L/dk'
       [b 'Planet rulmanları, pimlerden: 4 × 0,60 mm, 1,4 L/dk']
       [b 'Giriş mili rulmanları: 3 × 0,84 mm, 2,1 L/dk']
       [b 'Ara mil ve pervane mili rulmanları: 6 × 0,60 mm, 2,1 L/dk']
       [b 'Aksesuarlar, jeneratör, kamalı bağlantılar:']
       '     7 × 0,60 mm, 2,4 L/dk'
       [b 'PT arka yatak bölmesi: 2 × 0,82 mm, 1,3 L/dk']
       ''
       'Yağlama 16,4 L/dk; PCU ve sızıntıyla 23,5 L/dk'
       ''
       [b 'soğutucudan gelen yağ, 100 °C']
       [r 'emme hattından tanka dönen yağ, yaklaşık 125 °C']
       ''
       '\color[rgb]{0.4,0.4,0.4}Gri silindir: pompa paketi (ara milden 6.200 rpm).'
       '\color[rgb]{0.4,0.4,0.4}Meme yerleri temsilî; kanallar Faz 3''te çizilecek.'};
annotation(fig, 'textbox', [0.66 0.10 0.34 0.78], 'String', leg, 'EdgeColor', 'none', 'FontSize', 12.5, ...
           'FontName', 'Segoe UI', 'VerticalAlignment', 'middle', 'Interpreter', 'tex');

ax.CameraTarget = [-20 -45 -30];
ax.CameraPosition = ax.CameraTarget + 1500 * [0.80 0.22 0.56] / norm([0.80 0.22 0.56]);
ax.CameraUpVector = [0 1 0];
ax.CameraViewAngle = 23;

if test, nfr = 1; end
for f = 1:nfr
    t = (f - 1) / nfr;
    phc = 90 * t;
    P = pose(G, phc);
    for k = 1:numel(inst)
        rr = P(k).rot;  R = [cosd(rr) -sind(rr) 0; sind(rr) cosd(rr) 0; 0 0 1];
        set(H(k), 'Vertices', Mi{k}.V * R' + P(k).t, 'VertexNormals', Mi{k}.N * R');
    end
    X = along(supply, 30, t * 30 * 12);
    set(drops_s, 'XData', X(:, 1), 'YData', X(:, 2), 'ZData', X(:, 3));
    X = along(scav, 30, t * 30 * 12);
    set(drops_r, 'XData', X(:, 1), 'YData', X(:, 2), 'ZData', X(:, 3));
    JJ = J;
    for i = 0:G.n - 1
        th = 90 * i + phc;
        JJ(end + 1, :) = {[50 * cosd(th - 14), 50 * sind(th - 14), 128], [46 * cosd(th - 3), 46 * sind(th - 3), 107]}; %#ok<AGROW>
        c0 = [G.a * cosd(th), G.a * sind(th), 109];
        JJ(end + 1, :) = {c0, c0 + 24 * [cosd(th + 90), sind(th + 90), 0]}; %#ok<AGROW>
        JJ(end + 1, :) = {c0, c0 + 24 * [cosd(th - 90), sind(th - 90), 0]}; %#ok<AGROW>
    end
    S = zeros(0, 3);
    u = mod(ph + t * nfr / Ts, 1);
    for j = 1:size(JJ, 1)
        a0 = JJ{j, 1};  a1 = JJ{j, 2};
        S = [S; a0 + u .* (a1 - a0) + jit .* u]; %#ok<AGROW>
    end
    set(spray, 'XData', S(:, 1), 'YData', S(:, 2), 'ZData', S(:, 3));
    v = mod(phd + t * nfr / 40, 1);                     % drops falling from the stage to the sump
    D = [xd .* (1 - v), -118 - 30 * v, zd + (71 - zd) .* v];
    set(drip, 'XData', D(:, 1), 'YData', D(:, 2), 'ZData', D(:, 3));
    img = print(fig, '-RGBImage', '-r96');
    if test
        imwrite(img, fullfile(out_dir, 'lube_test.png'));
    else
        imwrite(img, fullfile(out_dir, sprintf('lube_%03d.png', f)));
    end
end
close(fig);
end

% ------------------------------------------------------------------ helpers
function X = along(p, spacing, offset)
d = [0; cumsum(vecnorm(diff(p), 2, 2))];
s = (mod(offset, spacing):spacing:d(end))';
X = interp1(d, p, s);
end

function h = cyl(ax, c, axisv, r, len, colr)
n = 48;  th = linspace(0, 2 * pi, n + 1)';  th(end) = [];
axisv = axisv / norm(axisv);
u = null(axisv);  e1 = u(:, 1)';  e2 = u(:, 2)';
ring = cos(th) * e1 + sin(th) * e2;
A = c - axisv * len / 2 + r * ring;  B = c + axisv * len / 2 + r * ring;
V = [A; B; c - axisv * len / 2; c + axisv * len / 2];
F = [(1:n)' [2:n 1]' [n + 2:2 * n n + 1]' (n + 1:2 * n)'];
cap1 = [(1:n)' [2:n 1]' repmat(2 * n + 1, n, 1) repmat(2 * n + 1, n, 1)];
cap2 = [(n + 1:2 * n)' [n + 2:2 * n n + 1]' repmat(2 * n + 2, n, 1) repmat(2 * n + 2, n, 1)];
h = patch(ax, 'Faces', [F; cap1; cap2], 'Vertices', V, 'FaceColor', colr, 'EdgeColor', 'none', ...
          'FaceLighting', 'gouraud', 'AmbientStrength', 0.45, 'DiffuseStrength', 0.65, 'SpecularStrength', 0.3);
end

function P = pose(G, phc)
phs = phc * (G.zs + G.zr) / G.zs;
psi = -(phs - phc) * G.zs / G.zp;
P = repmat(struct('rot', 0, 't', [0 0 0]), 1, 11);
P(2) = struct('rot', 0.756, 't', [0 0 36]);
P(3) = struct('rot', phc, 't', [0 0 15]);
P(4) = struct('rot', 2 + phs, 't', [0 0 36]);
pp = 360 / G.zp;
for i = 0:G.n - 1
    th = 360 * i / G.n;
    ph = 2.432 + th * (G.zs + G.zp) / G.zp;
    P(5 + i) = struct('rot', ph - pp * floor(ph / pp) + phc + psi, 't', [G.a * cosd(th + phc), G.a * sind(th + phc), 36]);
end
P(9) = struct('rot', phs, 't', [0 0 -75]);
P(10) = struct('rot', 180 / G.z1 - phs * G.z2 / G.z1, 't', [0 -G.a1 -75]);
P(11) = struct('rot', -phs * G.z2 / G.zg, 't', [G.ag * cosd(135), G.ag * sind(135), -75 + (52 - 16) / 2]);
end

function m = crease(P, F, angdeg)
nf = size(F, 1);
FN = cross(P(F(:, 2), :) - P(F(:, 1), :), P(F(:, 3), :) - P(F(:, 1), :), 2);
A = vecnorm(FN, 2, 2);  FN = FN ./ max(A, eps);
vf = accumarray(F(:), repmat((1:nf)', 3, 1), [size(P, 1) 1], @(x) {x});
c = cosd(angdeg);
V = P(reshape(F', [], 1), :);  N = zeros(3 * nf, 3);
for f = 1:nf
    for j = 1:3
        adj = vf{F(f, j)};
        w = FN(adj, :) * FN(f, :)' >= c;
        n = sum(FN(adj(w), :) .* A(adj(w)), 1);
        N(3 * (f - 1) + j, :) = n / max(norm(n), eps);
    end
end
m = struct('V', V, 'F', reshape(1:3 * nf, 3, nf)', 'N', N);
end
