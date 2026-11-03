function os_schematic(S, lang, out_dir)
%OS_SCHEMATIC  Schematic of the RGB oil system with the maximum continuous power flows and pressures.
%   os_schematic(S, lang, out_dir)
%
%   S = run_step32 result, lang 'tr' or 'en'. Draws tank, pump, filter,
%   thermostatic valve and cooler loop, manifold with the regulating valve,
%   the branches with their flows, the scavenge with the chip detectors and
%   the oil debris monitor; writes schematic_<lang>.png.
%   Source: Phase 3 report, Section 3.2 ("Schematic").

tr = strcmp(lang, 'tr');
M = S.ops(1);
fig = figure('Visible', 'off', 'Position', [100 100 1300 700], 'Color', 'w');
ax = axes('Position', [0 0 1 1]);  axis(ax, [0 130 0 70]);  axis off;  hold on
box = @(x, y, w, h, t, c) [rectangle('Position', [x y w h], 'Curvature', 0.15, 'FaceColor', c, 'EdgeColor', [0.2 0.2 0.2]), ...
                           text(x + w / 2, y + h / 2, t, 'HorizontalAlignment', 'center', 'FontSize', 9)];
arr = @(x1, y1, x2, y2) annotation('arrow', [x1 x2] / 130, [y1 y2] / 70, 'HeadLength', 6, 'HeadWidth', 6);
c1 = [0.86 0.92 0.98];  c2 = [0.98 0.92 0.84];  c3 = [0.90 0.96 0.88];
L = @(t_tr, t_en) pick(tr, t_tr, t_en);
box(2, 40, 14, 10, L({'Yağ tankı', '6,8 L, +34,5 kPa'}, {'Oil tank', '6.8 L, +34.5 kPa'}), c2);
box(22, 40, 14, 10, L({'Besleme pompası', sprintf('%.1f L/dk', M.Q_pump)}, {'Supply pump', sprintf('%.1f L/min', M.Q_pump)}), c1);
box(42, 40, 14, 10, L({'Filtre 3 µm', 'baypas 170 kPa'}, {'Filter 3 µm', 'bypass 170 kPa'}), c1);
box(42, 56, 14, 10, L({'Termostatik valf', '60 °C altı: döngü kapalı'}, {'Thermostatic valve', 'below 60 °C: loop shut'}), c2);
box(62, 56, 16, 10, L({'Soğutucu (gövdede)', '18 kW, hortumlar 2 × 1,5 m'}, {'Cooler (nacelle)', '18 kW, hoses 2 x 1.5 m'}), c2);
box(62, 40, 16, 10, L({'Manifold + basınç valfi', sprintf('%.0f kPa', M.p_m)}, {'Manifold + regulating valve', sprintf('%.0f kPa', M.p_m)}), c1);
arr(16, 45, 22, 45);  arr(36, 45, 42, 45);  arr(49, 50, 49, 56);  arr(56, 61, 62, 61);  arr(70, 56, 70, 50);
arr(56, 44, 62, 44);
text(57, 42.5, L('soğuk', 'cold'), 'FontSize', 8);
text(17, 36, L({'emme ≤150 mm, Ø32', '(arayüz gereksinimi)'}, {'suction ≤150 mm, Ø32', '(interface requirement)'}), 'FontSize', 8);
% branches
B = S.N.branch;
y = 66;
for k = 1:numel(B)
    nj = numel(B(k).jet);
    q = M.Qb(k);
    nm = B(k).name;
    if tr, nm = tr_name(nm); end
    text(86, y, sprintf('%s  (%d)  %.2f', nm, nj, q), 'FontSize', 8);
    annotation('line', [78 85.5] / 130, [45 y] / 70, 'Color', [0.5 0.5 0.5]);
    y = y - 4.3;
end
text(86, 69, L('Kollar (meme sayısı), L/dk', 'Branches (jets), L/min'), 'FontSize', 9, 'FontWeight', 'bold');
text(86, y, sprintf('PCU %.2f, %s %.2f, %s %.2f', M.Q_pcu, L('kaçak', 'leaks'), M.Q_leak, L('basınç valfi geri', 'regulating valve back'), M.Q_prv), ...
     'FontSize', 8);
% scavenge
box(22, 14, 14, 10, L({'Geri emiş', 'pompaları'}, {'Scavenge', 'pumps'}), c3);
box(42, 14, 14, 10, L({'Yağ döküntü', 'izleyicisi (ODM)'}, {'Oil debris', 'monitor (ODM)'}), c3);
box(62, 14, 16, 10, L({'Karterler: 2 talaş dedektörü,', 'numune valfi'}, {'Sumps: 2 chip detectors,', 'sampling valve'}), c3);
arr(62, 19, 56, 19);  arr(42, 19, 36, 19);  arr(22, 19, 9, 19);  arr(9, 19, 9, 40);
text(2, 6, L({'Planet rulmanları ve planet kavramaları: taşıyıcı arka plakasına iki oluklu sabit transfer manşonu; ikinci oluk pervane hatve yağını (PIF-02)', ...
              'taşıyıcı direği ve ön plaka üzerinden eksendeki tüpe götürür. LUB-07 (yağsız 30 dk): açık, karar bekliyor.'}, ...
             {'Planet bearings and planetary meshes: two-groove stationary transfer sleeve into the carrier rear plate; the second groove takes the', ...
              'pitch oil (PIF-02) through a carrier post and the front plate to the tube on the axis. LUB-07 (30 min without oil): open, decision pending.'}), ...
     'FontSize', 8);
title_t = L('RGB yağ sistemi, azami sürekli güçte debiler ve basınçlar', 'RGB oil system, flows and pressures at maximum continuous power');
text(2, 67, title_t, 'FontSize', 11, 'FontWeight', 'bold');
set(findall(fig, '-property', 'FontName'), 'FontName', 'Arial');
exportgraphics(fig, fullfile(out_dir, ['schematic_' lang '.png']), 'Resolution', 150);
close(fig);
end

function v = pick(tr, a, b)
if tr, v = a; else, v = b; end
end

function t = tr_name(n)
map = {'first-stage mesh, into mesh', 'birinci kademe kavrama, giriş'; 'first-stage mesh, out of mesh', 'birinci kademe kavrama, çıkış'; ...
       'input shaft bearings', 'giriş mili rulmanları'; 'intermediate shaft bearings', 'ara mil rulmanları'; ...
       'generator mesh', 'jeneratör kavraması'; 'OSG mesh', 'OSG kavraması'; 'PCU mesh', 'PCU kavraması'; ...
       'generator shaft bearings', 'jeneratör mili rulmanları'; 'generator quill spline', 'jeneratör quill kaması'; ...
       'pump quill spline', 'pompa quill kaması'; 'propeller shaft bearings', 'pervane mili rulmanları'; ...
       'carrier (planet bearings and planetary meshes)', 'taşıyıcı (planet rulmanları ve kavramaları)'; ...
       'PT rear sump', 'PT arka karteri'};
t = n;
k = find(strcmp(map(:, 1), n), 1);
if ~isempty(k), t = map{k, 2}; end
end
