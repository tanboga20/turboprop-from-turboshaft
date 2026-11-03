function rgb_anim(mode, out_dir, nfr, stl_dir)
%RGB_ANIM  Frames of the RGB animations of the summary report, from the CATIA parts exported as STL.
%   rgb_anim('test', out_dir)          one frame of each view
%   rgb_anim('run', out_dir, n)        gear train turning at the true speed ratios (carrier 90 deg = one loop)
%   rgb_anim('assembly', out_dir)      parts flying into place, then turning
%   rgb_anim('removal', out_dir)       shop removal of the modules (step 3.10, maintenance/mnt_tasks_v1.csv)
%   Run from the repo root after cad/anim/export_stl.vbs (STL files in cad/anim/stl); make_webp.py
%   turns the frames into an animated WebP. Placement and tooth phases as in cad/scripts/assembly.vbs.

if nargin < 4, stl_dir = fullfile('cad', 'anim', 'stl'); end
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
if nargin < 3, nfr = 360; end
G = struct('zs', 45, 'zp', 37, 'zr', 119, 'a', 82, 'n', 4, 'z1', 31, 'z2', 110, 'zg', 57, ...
           'a1', 145.974, 'ag', 172.488);

names = {'case', 'ring', 'carrier', 'sun', 'planet', 'gear2', 'pinion', 'gen_gear'};
for k = 1:numel(names)
    T = stlread(fullfile(stl_dir, [names{k} '.stl']));
    M.(names{k}) = crease(T.Points, T.ConnectivityList, 32);
end

col = struct('case', [0.78 0.80 0.83], 'ring', [0.60 0.62 0.66], 'carrier', [0.30 0.62 0.38], ...
             'sun', [0.22 0.44 0.80], 'planet', [0.95 0.56 0.16], 'gear2', [0.42 0.62 0.90], ...
             'pinion', [0.82 0.28 0.25], 'gen_gear', [0.56 0.42 0.76]);
inst = {'case', 'ring', 'carrier', 'sun', 'planet', 'planet', 'planet', 'planet', 'gear2', 'pinion', 'gen_gear'};

switch mode
    case 'test'
        S = scene(M, col, inst, 'run');
        draw(S, pose(G, 0), M, inst);
        frame(S, fullfile(out_dir, 'test_run.png'));
        close(S.fig);
        S = scene(M, col, inst, 'assembly');
        draw(S, pose(G, 0), M, inst);
        frame(S, fullfile(out_dir, 'test_assembly.png'));
        close(S.fig);
    case 'run'
        S = scene(M, col, inst, 'run');
        for f = 1:nfr
            draw(S, pose(G, 90 * (f - 1) / nfr), M, inst);
            frame(S, fullfile(out_dir, sprintf('run_%03d.png', f)));
        end
        close(S.fig);
    case 'assembly'
        assembly(G, M, col, inst, out_dir);
    case 'removal'
        removal(G, M, col, inst, out_dir);
end
end

% ------------------------------------------------------------------ kinematics
function P = pose(G, phc)
% angles in degrees about +z and positions (mm) of the 11 instances; phc = carrier angle
phs = phc * (G.zs + G.zr) / G.zs;                 % sun and intermediate shaft (ring fixed)
psi = -(phs - phc) * G.zs / G.zp;                 % planet spin relative to the carrier
P = repmat(struct('rot', 0, 't', [0 0 0]), 1, 11);
P(1) = struct('rot', 0, 't', [0 0 0]);
P(2) = struct('rot', 0.756, 't', [0 0 36]);
P(3) = struct('rot', phc, 't', [0 0 15]);
P(4) = struct('rot', 2 + phs, 't', [0 0 36]);
pp = 360 / G.zp;
for i = 0:G.n - 1
    th = 360 * i / G.n;
    ph = 2.432 + th * (G.zs + G.zp) / G.zp;
    r0 = ph - pp * floor(ph / pp);
    P(5 + i) = struct('rot', r0 + phc + psi, 't', [G.a * cosd(th + phc), G.a * sind(th + phc), 36]);
end
P(9) = struct('rot', phs, 't', [0 0 -75]);
P(10) = struct('rot', 180 / G.z1 - phs * G.z2 / G.z1, 't', [0 -G.a1 -75]);
P(11) = struct('rot', -phs * G.z2 / G.zg, 't', [G.ag * cosd(135), G.ag * sind(135), -75 + (52 - 16) / 2]);
end

% ------------------------------------------------------------------ scene
function S = scene(M, col, inst, view_name)
S.fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'pixels', 'Position', [0 0 1200 760], ...
               'InvertHardcopy', 'off', 'Renderer', 'opengl');
S.ax = axes(S.fig, 'Position', [0 0 1 1], 'Color', 'w');
hold(S.ax, 'on');
axis(S.ax, 'off');
S.ax.Projection = 'perspective';
S.ax.DataAspectRatio = [1 1 1];
S.view = view_name;
S.h = gobjects(1, numel(inst));
S.front = [];
for k = 1:numel(inst)
    m = M.(inst{k});
    if strcmp(view_name, 'run') && strcmp(inst{k}, 'carrier')
        zc = reshape(m.V(m.F', 3), 3, []);
        fr = m;                                          % front plate and a shaft stub, see-through
        fr.F = m.F(all(zc > 95, 1) & all(zc <= 205, 1), :);
        m.F = m.F(any(zc <= 95, 1), :);                  % rear plate and posts
        S.front = patch(S.ax, 'Faces', fr.F, 'Vertices', fr.V, 'VertexNormals', fr.N, ...
                        'FaceColor', col.carrier, 'EdgeColor', 'none', 'FaceLighting', 'gouraud', ...
                        'FaceAlpha', 0.22, 'AmbientStrength', 0.5, 'DiffuseStrength', 0.6, 'SpecularStrength', 0.2);
        S.mfront = fr;
    end
    S.h(k) = patch(S.ax, 'Faces', m.F, 'Vertices', m.V, 'VertexNormals', m.N, ...
                   'FaceColor', col.(inst{k}), 'EdgeColor', 'none', 'FaceLighting', 'gouraud', ...
                   'BackFaceLighting', 'reverselit', 'AmbientStrength', 0.38, 'DiffuseStrength', 0.72, ...
                   'SpecularStrength', 0.45, 'SpecularExponent', 14, 'SpecularColorReflectance', 0.6);
    S.m{k} = m;
end
if strcmp(view_name, 'run')
    S.h(1).Visible = 'off';                              % case hidden
    S.ax.CameraTarget = [-20 -35 0];
    S.ax.CameraPosition = S.ax.CameraTarget + 1500 * [0.80 0.22 0.56] / norm([0.80 0.22 0.56]);
    S.ax.CameraUpVector = [0 1 0];
    S.ax.CameraViewAngle = 21;
    S.ax.Position = [0.02 0.06 0.70 0.86];
    annotation(S.fig, 'textbox', [0.02 0.90 0.96 0.08], 'String', ...
               'RGB dişli takımı gerçek devir oranlarıyla (yaklaşık 1.360 kat yavaşlatılmış)', ...
               'EdgeColor', 'none', 'FontSize', 19, 'FontWeight', 'bold', 'FontName', 'Segoe UI', ...
               'HorizontalAlignment', 'center', 'Color', [0.1 0.1 0.1]);
    leg = {sprintf('\\color[rgb]{%g,%g,%g}\\bf■\\rm\\color[rgb]{0.15,0.15,0.15} Giriş pinyonu, z 31: güç türbini, 22.000 rpm', col.pinion)
           sprintf('\\color[rgb]{%g,%g,%g}\\bf■\\rm\\color[rgb]{0.15,0.15,0.15} Birinci kademe dişlisi, z 110: 6.200 rpm', col.gear2)
           sprintf('\\color[rgb]{%g,%g,%g}\\bf■\\rm\\color[rgb]{0.15,0.15,0.15} Güneş, z 45: ara mille aynı hızda', col.sun)
           sprintf('\\color[rgb]{%g,%g,%g}\\bf■\\rm\\color[rgb]{0.15,0.15,0.15} Dört planet, z 37: pim üzerinde 5.471 rpm', col.planet)
           sprintf('\\color[rgb]{%g,%g,%g}\\bf■\\rm\\color[rgb]{0.15,0.15,0.15} Halka dişli, z 119: sabit', col.ring)
           sprintf('\\color[rgb]{%g,%g,%g}\\bf■\\rm\\color[rgb]{0.15,0.15,0.15} Taşıyıcı ve pervane mili: 1.701 rpm', col.carrier)
           sprintf('\\color[rgb]{%g,%g,%g}\\bf■\\rm\\color[rgb]{0.15,0.15,0.15} Jeneratör dişlisi, z 57: 11.965 rpm', col.gen_gear)
           ''
           '\color[rgb]{0.35,0.35,0.35}Taşıyıcının ön plakası saydam,'
           '\color[rgb]{0.35,0.35,0.35}gövde gizli; parçalar CATIA''dan.'};
    annotation(S.fig, 'textbox', [0.69 0.18 0.30 0.62], 'String', leg, 'EdgeColor', 'none', ...
               'FontSize', 13, 'FontName', 'Segoe UI', 'VerticalAlignment', 'middle', 'Interpreter', 'tex');
else
    S.h(1).FaceAlpha = 0.16;
    S.ax.CameraTarget = [-10 -30 170];
    S.ax.CameraUpVector = [0 1 0];
    S.ax.CameraViewAngle = 24;
    S.ax.CameraPosition = S.ax.CameraTarget + 1750 * [sind(60) * cosd(22), sind(22), cosd(60) * cosd(22)];
end
S.ax.XLim = [-400 400]; S.ax.YLim = [-400 400]; S.ax.ZLim = [-500 800];
light(S.ax, 'Position', [1 1.2 1.5], 'Style', 'infinite', 'Color', [1 1 1]);
light(S.ax, 'Position', [-1.5 -0.4 0.6], 'Style', 'infinite', 'Color', 0.45 * [1 1 1]);
light(S.ax, 'Position', [0.2 -1 -1], 'Style', 'infinite', 'Color', 0.25 * [1 1 1]);
end

function draw(S, P, ~, inst)
for k = 1:numel(inst)
    m = S.m{k};
    r = P(k).rot;
    R = [cosd(r) -sind(r) 0; sind(r) cosd(r) 0; 0 0 1];
    set(S.h(k), 'Vertices', m.V * R' + P(k).t, 'VertexNormals', m.N * R');
    if k == 3 && ~isempty(S.front)
        set(S.front, 'Vertices', S.mfront.V * R' + P(k).t, 'VertexNormals', S.mfront.N * R');
    end
end
end

function frame(S, file)
img = print(S.fig, '-RGBImage', '-r96');
imwrite(img, file);
end

% ------------------------------------------------------------------ assembly choreography
function assembly(G, M, col, inst, out_dir)
S = scene(M, col, inst, 'assembly');
P0 = pose(G, 0);
% groups: instance list, start offset (mm), first and last frame of the move, caption
grp = {
    2,          [0 0 650],      1,   26, 'Halka dişli: z 119, nitrürlenmiş 32CrMoV13, 4,43 kg; gövdeye sabit'
    [3 5 6 7 8], [0 0 900],    27,   56, 'Taşıyıcı, pervane mili ve dört planet: planetler pimler üzerinde tam dolu makaralı rulmanlarla döner'
    4,          [0 0 -520],    57,   80, 'Güneş: z 45, ara milden kamalı bağlantıyla yüzer; dört planeti birden sürer'
    9,          [0 0 -600],    81,  104, 'Birinci kademe dişlisi: z 110, helisel; ara mil üzerinde, güneşle aynı hızda döner'
    10,         [0 -330 0],   105,  126, 'Giriş pinyonu: z 31, güç türbininin ekseninde, 146 mm aşağıda'
    11,         330 * [cosd(135) sind(135) 0], 127, 146, 'Jeneratör dişlisi: z 57, birinci kademe dişlisinden 11.965 rpm ile döner'
    1,          [0 0 900],    147,  172, 'Gövde: A357-T6 kum döküm, konik burunlu, 10,98 kg (burada saydam)'
};
nmove = 172;  nrun = 70;  nhold = 18;
ntot = nmove + nrun + nhold;
cap = annotation(S.fig, 'textbox', [0.03 0.025 0.94 0.07], 'String', '', 'EdgeColor', 'none', ...
                 'FontSize', 15, 'FontName', 'Segoe UI', 'HorizontalAlignment', 'center', ...
                 'VerticalAlignment', 'middle', 'Color', [0.15 0.15 0.15]);
annotation(S.fig, 'textbox', [0.03 0.90 0.94 0.08], 'String', ...
           'RGB montajı: CATIA parçaları hesaplardan gelen ölçülerle, adım adım', 'EdgeColor', 'none', ...
           'FontSize', 19, 'FontWeight', 'bold', 'FontName', 'Segoe UI', 'HorizontalAlignment', 'center', ...
           'Color', [0.1 0.1 0.1]);
for f = 1:ntot
    if f <= nmove
        P = P0;
    else
        P = pose(G, 22 * min(1, (f - nmove) / nrun));
    end
    txt = '';
    for g = 1:size(grp, 1)
        ids = grp{g, 1};  d = grp{g, 2};  s = grp{g, 3};  e = grp{g, 4};
        if f < s
            u = 0;
        elseif f > e
            u = 1;
        else
            u = (f - s) / (e - s);
            txt = grp{g, 5};
        end
        w = 1 - (3 * u^2 - 2 * u^3);
        for k = ids
            P(k).t = P(k).t + w * d;
            set(S.h(k), 'Visible', matlab.lang.OnOffSwitchState(f >= s - 1));
        end
    end
    if f > nmove
        txt = 'Çalışırken: güç türbini 22.000 rpm, ara mil 6.200 rpm, pervane 1.701 rpm (yavaşlatılmış)';
    elseif isempty(txt)
        txt = cap.String;
    end
    cap.String = txt;
    az = 34 + 34 * (f - 1) / (ntot - 1);
    u = min(1, f / nmove);
    dist = 2700 - 950 * (3 * u^2 - 2 * u^3);
    S.ax.CameraPosition = S.ax.CameraTarget + dist * [sind(az) * cosd(22), sind(22), cosd(az) * cosd(22)];
    draw(S, P, M, inst);
    frame(S, fullfile(out_dir, sprintf('asm_%03d.png', f)));
end
close(S.fig);
end

% ------------------------------------------------------------------ module removal (step 3.10)
function removal(G, M, col, inst, out_dir)
% the shop breakdown of maintenance/mnt_tasks_v1.csv (tasks T02, T03), Turkish captions
S = scene(M, col, inst, 'assembly');
S.ax.CameraTarget = [0 -40 330];
S.ax.ZLim = [-500 1400];  S.ax.YLim = [-450 400];
P0 = pose(G, 0);
% moves: instance list, offset (mm), first and last frame, caption
mv = {
    [1 2 3 5 6 7 8], [0 0 330],    21,  60, 'T02: planet modülü flanştan ayrılır (30 x M6, 6 pim); güneş kendi milinde kalır'
    [1 2],           [0 0 330],    71, 105, 'Taşıyıcı planetlerle halkadan ve gövdeden çekilir; planet rulmanları ve halka muayene edilir'
    11,              230 * [cosd(135) sind(135) 0], 116, 140, 'T03: jeneratör kartuşu çıkar (8 x M6); aksesuarlar tek tek değişebilir'
    10,              [0 -230 0],  151, 175, 'Giriş mili rulmanlarıyla çekilir'
    [4 9],           [0 0 -260],  181, 205, 'Ara mil, dişli 2 ve güneş çekilir; dişli 2, sönüm halkası ve kesme boyunları muayene edilir'
};
ntot = 230;
cap = annotation(S.fig, 'textbox', [0.03 0.025 0.94 0.07], 'String', '', 'EdgeColor', 'none', ...
                 'FontSize', 15, 'FontName', 'Segoe UI', 'HorizontalAlignment', 'center', ...
                 'VerticalAlignment', 'middle', 'Color', [0.15 0.15 0.15]);
annotation(S.fig, 'textbox', [0.03 0.90 0.94 0.08], 'String', ...
           'RGB modüllerinin atölyede sökülmesi (adım 3.10, bakım görev tablosu)', 'EdgeColor', 'none', ...
           'FontSize', 19, 'FontWeight', 'bold', 'FontName', 'Segoe UI', 'HorizontalAlignment', 'center', ...
           'Color', [0.1 0.1 0.1]);
txt = 'RGB motordan söküldükten sonra sehpasında (T01: sökme 2,6 sa, takma 4,7 sa, tahmin)';
for f = 1:ntot
    P = P0;
    for g = 1:size(mv, 1)
        ids = mv{g, 1};  d = mv{g, 2};  s = mv{g, 3};  e = mv{g, 4};
        u = min(1, max(0, (f - s) / (e - s)));
        w = 3 * u^2 - 2 * u^3;
        for k = ids
            P(k).t = P(k).t + w * d;
        end
        if f >= s, txt = mv{g, 5}; end
    end
    cap.String = txt;
    az = 55 + 25 * (f - 1) / (ntot - 1);
    S.ax.CameraPosition = S.ax.CameraTarget + 3300 * [sind(az) * cosd(20), sind(20), cosd(az) * cosd(20)];
    draw(S, P, M, inst);
    frame(S, fullfile(out_dir, sprintf('rem_%03d.png', f)));
end
close(S.fig);
end

% ------------------------------------------------------------------ mesh
function m = crease(P, F, angdeg)
% split vertices; each corner normal averages the adjacent faces within angdeg (sharp edges stay sharp)
nf = size(F, 1);
FN = cross(P(F(:, 2), :) - P(F(:, 1), :), P(F(:, 3), :) - P(F(:, 1), :), 2);
A = vecnorm(FN, 2, 2);
FN = FN ./ max(A, eps);
vf = accumarray(F(:), repmat((1:nf)', 3, 1), [size(P, 1) 1], @(x) {x});
c = cosd(angdeg);
V = P(reshape(F', [], 1), :);
N = zeros(3 * nf, 3);
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
