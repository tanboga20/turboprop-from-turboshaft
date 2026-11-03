function S = run_step31(out_dir)
%RUN_STEP31  Step 3.1: layout of the complete RGB, carrier lightening, mass roll-up.
%   S = run_step31()                  results in calc/results/step31
%   S = run_step31(out_dir)
%
%   Run from the repo root with calc/assembly, calc/gear_detail,
%   calc/shafts_bearings and calc/accessory on the path, after the CATIA
%   parts are built (cad/assy/part_volumes.csv; see cad/README.md). Prints
%   the axial stations, the accessory angles with their margins and the
%   collector sensitivity, the carrier plate check (plain against
%   lightened), the CATIA clash summary, the mass table against SYS-06 and
%   the remaining reduction options; draws the end view of the layout, the
%   plate stresses and the mass breakdown in Turkish and English
%   (layout_*.png, carrier_*.png, mass_*.png) and saves step31.mat.
%   Source: Phase 3 report, Section 3.1.

if nargin < 1 || isempty(out_dir)
    out_dir = fullfile('calc', 'results', 'step31');
end
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
in = as_inputs();
gi = gd_inputs();  ad = ad_inputs();  sb = sb_inputs();
G = as_geom(in, gi, ad, sb);
L = as_layout(in, G, gi, ad, sb);
a = L.ang;
z = L.z;

fprintf('\n== Axial stations [mm] (z = 0 attachment flange face, propeller at +z)\n');
fprintf('front roller bearings %.1f, gear centre %.1f, rear roller bearings %.1f, engine-side face %.1f\n', ...
        z.bf, z.c, z.br, z.rear);
fprintf('QJ210 %.1f..%.1f, QJ209 %.1f..%.1f, accessory cover %.1f..%.1f, PCU mesh %.1f, OSG mesh %.1f\n', ...
        z.qj_mid, z.qj_pt, z.cov, z.pcu, z.osg);

fprintf('\n== Accessory angles: generator %g deg, OSG %g deg from the generator axis, PCU %g deg\n', ...
        a.theta_g, a.theta_o, a.theta_p);
for k = 1:size(a.margin, 1)
    fprintf('  %-42s %8.1f mm\n', a.margin{k, 1}, a.margin{k, 2});
end
fprintf('feasible generator angles %g..%g deg; mass proxy case %.2f + cover %.2f kg\n', ...
        min(a.tg_feasible), max(a.tg_feasible), a.m_fs, a.m_cov);
fprintf('if the generator must clear the exhaust collector (L_free < %g mm):\n', G.L_unit('generator') + 8);
for k = 1:numel(a.sens.R_exh)
    fprintf('  R_exh %g mm: generator %g..%g deg\n', a.sens.R_exh(k), a.sens.tg_range(k, :));
end

B = as_carrier(in, gi, 'bench');
C0 = as_carrier(in, gi, false);
C1 = as_carrier(in, gi, true);
fprintf('\n== Carrier front plate (plane stress), benchmark error %.4f%%\n', 100 * B.err);
fprintf('%-28s %10s %10s\n', '', 'plain', 'lightened');
fprintf('%-28s %10.1f %10.1f\n', 'deflection at pins, MCT [um]', C0.u_pin_MCT, C1.u_pin_MCT);
fprintf('%-28s %10.0f %10.0f\n', 'windup, MCT [urad]', C0.windup_MCT, C1.windup_MCT);
fprintf('%-28s %10.0f %10.0f\n', 'peak von Mises LD-01 [MPa]', C0.vm_lim, C1.vm_lim);
fprintf('%-28s %10.0f %10.0f\n', 'peak von Mises LD-08 [MPa]', C0.vm_LD08, C1.vm_LD08);
fprintf('%-28s %10.2f %10.2f\n', 'yield safety LD-01', C0.SF_lim, C1.SF_lim);
fprintf('%-28s %10.2f %10.2f\n', 'yield safety LD-08', C0.SF_LD08, C1.SF_LD08);
fprintf('scallops remove %.3f kg from both plates\n', C1.m_saved);

cl = readtable(fullfile('cad', 'assy', 'clash_report.csv'), 'TextType', 'string');
fprintf('\n== CATIA clash analysis: %d conflicts, %d clashes, %d contacts\n', height(cl), ...
        sum(cl.type == "clash"), sum(cl.type == "contact"));

vol = readtable(fullfile('cad', 'assy', 'part_volumes.csv'), 'TextType', 'string');
M = as_mass(in, L, vol);
O = as_lighten(in, L, M, gi);
fprintf('\n== Mass (SYS-06)\n');
disp(sortrows(M.parts(M.parts.kg > 0, :), 'kg', 'descend'));
fprintf('planetary %.2f, first stage %.2f, accessories %.2f, modelled %.2f kg\n', M.module.planetary, ...
        M.module.first_stage, M.module.accessories, M.modelled);
fprintf('allowances %.2f kg (bolts %.2f), total %.2f kg; cooler and tank outside SYS-06: %.2f kg\n', ...
        M.allowances, M.bolts, M.total, M.with_ext - M.total);
fprintf('input drive (SYS-11): PT shaft %.2f + couplings %.2f + tunnel %.2f = %.2f kg (limit %g, TBR); RGB + input drive %.2f kg\n', ...
        in.drive.shaft, in.drive.couplings, M.tunnel, M.drive, in.m_drive_limit, M.total_with_drive);
disp(O.measures);
disp(O.pkg);

for lang = {'tr', 'en'}
    plot_layout(L, G, in, lang{1}, out_dir);
    plot_carrier(C0, C1, lang{1}, out_dir);
    plot_mass(M, O, in, lang{1}, out_dir);
end
S = struct('L', L, 'carrier', struct('plain', rmfield(C0, {'model', 'R'}), 'light', rmfield(C1, {'model', 'R'})), ...
           'bench', B, 'mass', M, 'options', O, 'clash', cl);
save(fullfile(out_dir, 'step31.mat'), 'S');
end

function plot_layout(L, G, in, lang, out_dir)
tr = strcmp(lang, 'tr');
a = L.ang;
fig = figure('Visible', 'off', 'Position', [100 100 900 900]);
hold on;  axis equal;  box on;  grid on
t = linspace(0, 2 * pi, 361);
circ = @(c, r, sty, col) plot(c(1) + r * cos(t), c(2) + r * sin(t), sty, 'Color', col, 'LineWidth', 1.2);
outline(L.fs.out.segs, [0.15 0.35 0.65], 2);
outline(L.fs.cav.segs, [0.15 0.35 0.65], 0.8);
outline(L.cov.out.segs, [0.80 0.45 0.10], 2);
circ([0 0], G.R_flange, '-', [0.5 0.5 0.5]);
circ([0 0], G.r_tip.gear2, '-', [0 0 0]);
circ(a.PT, G.r_tip.pinion, '-', [0 0 0]);
circ(a.Gp, G.r_tip.gen, '-', [0 0 0]);
circ(a.Op, G.r_tip.osg, '-', [0 0 0]);
circ(a.Gp, G.r_tip.osg_pin, ':', [0 0 0]);                       % OSG pinion on the generator shaft
circ(a.Pp, G.r_tip.pcu, '-', [0.8 0.45 0.1]);
circ(a.Gp, G.r_unit('generator'), '--', [0.6 0.1 0.1]);
circ(a.Op, G.r_unit('OSG'), '--', [0.1 0.5 0.1]);
circ(a.Pp, G.r_unit('PCU'), '--', [0.5 0.1 0.6]);
circ(a.PT, in.r_ker, '-.', [0.3 0.3 0.3]);
plot([0 a.PT(1) a.Gp(1) a.Op(1) a.Pp(1)], [0 a.PT(2) a.Gp(2) a.Op(2) a.Pp(2)], 'k+', 'MarkerSize', 10);
if tr
    lab = {'pervane ekseni', 'PT ekseni', sprintf('jeneratör %g°', a.theta_g), 'OSG', sprintf('PCU %g°', a.theta_p)};
    title('Uçtan görünüş (pervane tarafından): birinci kademe gövdesi (mavi), aksesuar kapağı (turuncu), üniteler (kesikli)');
    xlabel('x [mm]');  ylabel('y [mm]');
    text(a.PT(1) + in.r_ker * 0.7, a.PT(2) - in.r_ker * 0.8, 'tünel/kaplin sınırı (TBD)', 'FontSize', 8);
else
    lab = {'propeller axis', 'PT axis', sprintf('generator %g deg', a.theta_g), 'OSG', sprintf('PCU %g deg', a.theta_p)};
    title('End view from the propeller: first-stage case (blue), accessory cover (orange), units (dashed)');
    xlabel('x [mm]');  ylabel('y [mm]');
    text(a.PT(1) + in.r_ker * 0.7, a.PT(2) - in.r_ker * 0.8, 'tunnel/coupling keep-out (TBD)', 'FontSize', 8);
end
P = [0 0; a.PT; a.Gp; a.Op; a.Pp];
for k = 1:5
    text(P(k, 1) + 6, P(k, 2) + 6, lab{k}, 'FontSize', 9, 'FontWeight', 'bold');
end
xlim([-260 330]);  ylim([-260 330]);
set(findall(fig, '-property', 'FontName'), 'FontName', 'Arial');
exportgraphics(fig, fullfile(out_dir, ['layout_' lang '.png']), 'Resolution', 150);
close(fig);
end

function outline(sg, col, lw)
for k = 1:size(sg, 1)
    s = sg(k, :);
    if s(1) == 0
        plot(s([2 4]), s([3 5]), '-', 'Color', col, 'LineWidth', lw);
    else
        a1 = atan2(s(3) - s(7), s(2) - s(6));
        a2 = atan2(s(5) - s(7), s(4) - s(6));
        a2 = a1 + mod(a2 - a1, 2 * pi);
        r = norm(s(2:3) - s(6:7));
        u = linspace(a1, a2, 100);
        plot(s(6) + r * cos(u), s(7) + r * sin(u), '-', 'Color', col, 'LineWidth', lw);
    end
end
end

function plot_carrier(C0, C1, lang, out_dir)
tr = strcmp(lang, 'tr');
fig = figure('Visible', 'off', 'Position', [100 100 1300 560]);
CC = {C0, C1};
if tr
    ttl = {'Düz plaka', 'Hafifletilmiş plaka (8 oyuk)'};
    cb = 'von Mises, LD-01 sınır torku [MPa]';
else
    ttl = {'Plain plate', 'Lightened plate (8 scallops)'};
    cb = 'von Mises at the LD-01 limit torque [MPa]';
end
for k = 1:2
    subplot(1, 2, k);
    C = CC{k};
    pdeplot(C.R.Mesh, 'XYData', C.R.VonMisesStress * C.T_lim, 'ColorMap', 'jet');
    clim([0 320]);
    axis equal;  axis off
    c = colorbar;  c.Label.String = cb;
    if tr
        title(sprintf('%s: pim çemberinde sehim %.1f µm (MCT), tepe %.0f MPa', ttl{k}, C.u_pin_MCT, C.vm_lim));
    else
        title(sprintf('%s: deflection at the pins %.1f µm (MCT), peak %.0f MPa', ttl{k}, C.u_pin_MCT, C.vm_lim));
    end
end
set(findall(fig, '-property', 'FontName'), 'FontName', 'Arial');
exportgraphics(fig, fullfile(out_dir, ['carrier_' lang '.png']), 'Resolution', 150);
close(fig);
end

function plot_mass(M, O, in, lang, out_dir)
tr = strcmp(lang, 'tr');
fig = figure('Visible', 'off', 'Position', [100 100 1000 520]);
v = [M.module.planetary M.module.first_stage M.module.accessories M.allowances];
pk = O.pkg.total_kg';
X = [v; v; v; v];
% each package bar: the modelled modules scaled to the package total, allowances on top
for k = 2:4
    X(k, 1:3) = v(1:3) * (pk(k) - v(4)) / sum(v(1:3));
end
b = barh(X, 'stacked');
cols = [0.15 0.35 0.65; 0.30 0.60 0.85; 0.80 0.45 0.10; 0.6 0.6 0.6];
for k = 1:4, b(k).FaceColor = cols(k, :); end
hold on
xline(in.m_limit, 'k--', 'LineWidth', 1.5);
xline(110, 'r-', 'LineWidth', 1.5);
for k = 1:4
    text(pk(k) + 0.8, k, sprintf('%.1f kg', pk(k)), 'FontWeight', 'bold');
end
xlim([0 125]);
if tr
    set(gca, 'YTickLabel', {'A: model (paket A)', 'B: A + titanyum mil', 'C: A + WE43 döküm', 'D: A + B + C'});
    legend({'planet modülü', 'birinci kademe', 'aksesuarlar', 'paylar (cıvata, meme, HUMS, filtre)', ...
            'SYS-06 eski 100 kg', 'SYS-06 yeni 110 kg (TBR)'}, 'Location', 'southoutside', 'NumColumns', 3);
    xlabel('kuru kütle [kg]');
    title('SYS-06 kütle dökümü: CATIA modeli ve seçenekler (A seçeneği seçildi)');
else
    set(gca, 'YTickLabel', {'A: model (package A)', 'B: A + titanium shaft', 'C: A + WE43 castings', 'D: A + B + C'});
    legend({'planetary module', 'first stage', 'accessories', 'allowances (bolts, jets, HUMS, filter)', ...
            'SYS-06 old 100 kg', 'SYS-06 new 110 kg (TBR)'}, 'Location', 'southoutside', 'NumColumns', 3);
    xlabel('dry mass [kg]');
    title('SYS-06 mass breakdown: CATIA model and options (option A chosen)');
end
set(gca, 'YDir', 'reverse');
set(findall(fig, '-property', 'FontName'), 'FontName', 'Arial');
exportgraphics(fig, fullfile(out_dir, ['mass_' lang '.png']), 'Resolution', 150);
close(fig);
end
