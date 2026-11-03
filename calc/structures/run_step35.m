function S = run_step35(out_dir, parts)
%RUN_STEP35  Step 3.5: 3-D structural analysis of the case, carrier, seat liners and flange bolts; mass closure.
%   S = run_step35()                    full run (about 30 minutes), results in calc/results/step35
%   S = run_step35(out_dir)
%   S = run_step35(out_dir, parts)      parts: any of 'case', 'carrier', 'fscase', 'conv' (default all)
%
%   Run from the repo root with calc/structures, calc/gear_detail,
%   calc/manufacturing and calc/assembly on the path, after run_step34
%   (calc/results/step34/step34.mat). Loads (st_loads), seat liners
%   (st_liners), flange bolts (st_bolts, VDI 2230), the 3-D case (st_case3d)
%   and carrier (st_carrier3d) on the CATIA STEP geometry, the case limit
%   stress at a finer mesh ('conv'), and the mass closure (st_mass). Writes
%   CSV tables, plots in Turkish and English and step35.mat.
%   Source: Phase 3 report, Section 3.5.

if nargin < 1 || isempty(out_dir)
    out_dir = fullfile('calc', 'results', 'step35');
end
if nargin < 2, parts = {'case', 'carrier', 'fscase', 'conv'}; end
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
in = st_inputs();
gi = gd_inputs();
L = st_loads(in, gi);
fprintf('\n== Loads: T_prop MCT %.0f N m, ring torque MCT %.0f / limit %.0f N m; LD-08 %.0f N m (x%.2f)\n', ...
        L.T_mct, L.T_ring_mct, L.T_ring_lim, in.T_LD08, L.k08);
fprintf('K_gamma P99: LD-01 %.3f, LD-08 %.3f; LD-05 seat reactions: inner %.0f N, outer %.0f N\n', ...
        L.cases(1).Kgam, L.cases(2).Kgam, L.R_in, L.R_out);
S = struct('in', in, 'L', L);

Ln = st_liners(in);
fprintf('\n== Seat liners (interference sized for %g degC)\n', max(in.T_fit));
disp(Ln.T);
S.liners = Ln;
L.p_liner = Ln.p_seat_cold * [1 1];

B = st_bolts(in, L);
fprintf(['\n== Flange bolts (VDI 2230): F_Mzul %.0f N, M_A %.1f N m, F_Mmin %.0f N; Phi_n %.3f; F_A %.0f N, F_Q %.0f N\n' ...
         '   F_Z %.0f N, preload change -40 / 149 degC %.0f / %.0f N; F_KRmin %.0f N (opening %d)\n' ...
         '   S_F %.2f, S_D %.2f, S_p %.2f, S_strip %.2f; slip S_G %.2f (friction only)\n' ...
         '   dowels %d x %g mm: %.0f N each, shear S %.2f, bearing on A357 S %.2f\n'], ...
        B.F_Mzul, B.M_A, B.F_Mmin, B.Phi_n, B.F_A, B.F_Q, B.F_Z, B.dF_cold, B.dF_hot, B.F_KRmin, B.opening, ...
        B.S_F, B.S_D, B.S_p, B.S_strip, B.S_G, in.dowel.n, in.dowel.d, B.F_dowel, B.S_dowel, B.S_dowel_bearing);
S.bolts = B;
% engine mount ring (ICD-24 placeholder): whole RGB reaction torque, propeller moment about the mount face
for sz = {'M8', 'M10'}
    im = in;  mt = in.mount;  bb = in.bolt;
    for fn = fieldnames(mt.(sz{1}))', bb.(fn{1}) = mt.(sz{1}).(fn{1}); end
    bb.n = mt.n;  bb.pcd = mt.pcd;  bb.z_prop = mt.z_prop;  bb.L_k = mt.L_k;
    im.bolt = bb;
    Lm = L;  Lm.T_ring_lim = in.K_over * L.T_mct * (1 - 1 / 12.93);   % propeller torque less the input torque
    Bm = st_bolts(im, Lm);
    fprintf('   mount ring 12 x %s 12.9 on PCD 140: F_A %.0f N, F_Mmin %.0f N, F_KRmin %.0f N (opening %d), S_F %.2f, slip S_G %.2f\n', ...
            sz{1}, Bm.F_A, Bm.F_Mmin, Bm.F_KRmin, Bm.opening, Bm.S_F, Bm.S_G);
    S.mount.(sz{1}) = Bm;
end

if any(strcmp(parts, 'case'))
    t = tic;
    K = st_case3d(in, L);
    fprintf(['\n== Case 3-D (%d nodes, %.2f kg, %.0f s)\n   seat stiffness inner %.3g / %.3g, outer %.3g / %.3g N/m (fixed / springs)\n' ...
             '   limit von Mises %.0f / %.0f MPa (allowed %.0f): n_y %.2f / %.2f, n_u %.2f / %.2f\n' ...
             '   liners at -40 degC: %.0f MPa alone, %.0f MPa with the limit load (n_y %.2f / %.2f)\n' ...
             '   fatigue: sa %.1f, sm %.1f MPa at z %.0f mm, Goodman n %.2f\n   ring seat twist at MCT %.2f um over 70 mm\n'], ...
            K.n_nodes, K.m, toc(t), K.k_in, K.k_out, K.sig_lim, K.allow, K.n_y, K.n_u, K.sig_liner, K.sig_liner_lim, ...
            K.n_liner, K.fatigue.sa, K.fatigue.sm, K.fatigue.node_z, K.fatigue.n_f, K.twist_um);
    S.case = rmfield(K, 'R_lim');
    H = st_khb(gi, K.twist_um);
    fprintf('   K_Hbeta back-check, planet-ring mesh: f_ma %.1f -> %.1f um, K_Hbeta %.3f -> %.3f, S_H ring %.2f -> %.2f\n', ...
            H.f_ma, H.KHb, H.S_H2);
    S.khb = H;
    X = st_liner_fix(in, K.sig_liner / Ln.T.sig_vm_cold(1));
    fprintf(['   NU1024 liner fix (A357 at n >= %.2f): boss r %.0f -> %.1f mm, +%.2f kg (fit held to 149 degC); ' ...
             'or the fit held only to %.0f degC with the present boss\n'], in.n_liner_min, in.liner(1).r_boss, X.r_boss, X.dm_kg, X.T_hold);
    S.liner_fix = X;
    S.case_R = K.R_lim;
end
if any(strcmp(parts, 'fscase'))
    for sup = {'mount', 'flange'}
        t = tic;
        Q = st_fscase3d(in, L, B, gi, [], sup{1});
        fprintf(['\n== First-stage case 3-D, held at the %s (%d nodes, %.2f kg, %.0f s): gear forces Ft %.0f, Fr %.0f, Fa %.0f N at MCT\n' ...
                 '   limit von Mises %.0f MPa: n_y %.2f, n_u %.2f, largest displacement %.2f mm; fatigue sa %.1f sm %.1f MPa, Goodman n %.2f\n' ...
                 '   first-stage alignment at MCT: %.2f um over the face width (f_ma of step 2.4 %.1f um), centre distance %.1f um\n'], ...
                sup{1}, Q.n_nodes, Q.m, toc(t), Q.F1, Q.sig_lim, Q.n_y, Q.n_u, Q.u_max_mm, Q.fatigue.sa, Q.fatigue.sm, Q.fatigue.n_f, ...
                Q.slope_um, Q.f_ma, Q.dcd_um);
        H1 = st_khb(gi, Q.slope_um, 1);
        fprintf('   K_Hbeta back-check, first stage: f_ma %.1f -> %.1f um, K_Hbeta %.3f -> %.3f, S_H %.2f -> %.2f\n', H1.f_ma, H1.KHb, H1.S_H1);
        Q.khb = H1;
        S.(['fscase_' sup{1}]) = rmfield(Q, 'R_lim');
        S.(['fscase_' sup{1} '_R']) = Q.R_lim;
    end
end
if any(strcmp(parts, 'conv'))
    K2 = st_case3d(in, L, in.Hmax_fine, true);
    fprintf('== Case at Hmax %g mm: %d nodes, limit %.0f / %.0f MPa (fixed / springs)\n', in.Hmax_fine * 1e3, K2.n_nodes, K2.sig_lim);
    S.case_fine = rmfield(K2, 'R_lim');
end
if any(strcmp(parts, 'carrier'))
    t = tic;
    Cr = st_carrier3d(in, L);
    fprintf(['\n== Carrier 3-D (%d nodes, %.2f kg, %.0f s): windup at MCT %.4f deg (%.1f um at the pins), shaft %.4f deg\n' ...
             '   press fit of the M50NiL pins: p %.0f MPa, hoop %.0f MPa (n_y %.2f)\n'], ...
            Cr.n_nodes, Cr.m, toc(t), Cr.windup_deg, Cr.windup_um, Cr.rot_shaft_deg, Cr.press.p, Cr.press.sig_hoop, Cr.press.n_y);
    for q = 1:numel(Cr.names)
        fprintf('   %s: plates %.0f MPa (n_y %.2f), at the pin bores %.0f + press %.0f -> n_y %.2f; shaft %.0f MPa\n', ...
                Cr.names{q}, Cr.sig(q), Cr.n_y(q), Cr.sig_bore(q), Cr.press.sig_hoop, Cr.n_y_with_press(q), Cr.sig_shaft(q));
    end
    for k = 2:3                                        % 10 mm plates (mass card B): extra pin tilt against the 15 mm carrier
        Hc(k - 1) = st_khb(gi, Cr.pin_tilt_um - in.carr_tilt_15, k); %#ok<AGROW>
        fprintf('   K_Hbeta with the extra pin tilt %.2f um, mesh %d: %.3f -> %.3f, S_H %.2f -> %.2f / %.2f -> %.2f\n', ...
                Cr.pin_tilt_um - in.carr_tilt_15, k, Hc(k - 1).KHb, Hc(k - 1).S_H1, Hc(k - 1).S_H2);
    end
    Cr.khb = Hc;
    S.carrier = rmfield(Cr, 'R');
    S.carrier_R = Cr.R;
end
if isfield(S, 'carrier')
    st32 = load(fullfile('calc', 'results', 'step32', 'step32.mat'));
    st34 = load(fullfile('calc', 'results', 'step34', 'step34.mat'));
    Mc = st_mass(in, st32.S.mass, st34.S, S.carrier, S.liner_fix);
    fprintf('\n== Mass closure (SYS-06, roll-up %.2f kg; nothing applied)\n', Mc.roll_up);
    disp(Mc.lines);  disp(Mc.pkg);
    S.mass = Mc;
end
save(fullfile(out_dir, 'step35.mat'), 'S', '-v7.3');
for lang = {'tr', 'en'}
    if isfield(S, 'case_R'), plot_field(S.case_R, 'case', lang{1}, out_dir); end
    if isfield(S, 'carrier_R'), plot_field(S.carrier_R, 'carrier', lang{1}, out_dir); end
    if isfield(S, 'fscase_mount_R'), plot_field(S.fscase_mount_R, 'fscase_mount', lang{1}, out_dir); end
    if isfield(S, 'fscase_flange_R'), plot_field(S.fscase_flange_R, 'fscase_flange', lang{1}, out_dir); end
    plot_margins(S, lang{1}, out_dir);
end
end

function plot_field(R, what, lang, out_dir)
% von Mises stress of the case at limit load (fixed flange) or of the carrier at LD-08
tr = strcmp(lang, 'tr');
fig = figure('Visible', 'off', 'Position', [100 100 900 700]);
pdeplot3D(R.Mesh, ColorMapData=R.VonMisesStress / 1e6);
colormap(turbo);  cb = colorbar;  cb.Label.String = 'von Mises [MPa]';
view(35, 20);
if strcmp(what, 'case')
    if tr, t = 'Planet gövdesi, sınır yük (LD-05 + LD-01 halka torku + 20 kN itki), flanş sabit';
    else,  t = 'Planetary case, limit load (LD-05 + LD-01 ring torque + 20 kN thrust), flange fixed'; end
elseif strcmp(what, 'fscase_mount')
    if tr, t = 'Birinci kademe gövdesi, 3.1 yerleşimi: bütün pervane yükü PT eksenindeki bağlantı halkasına (sınır yük)';
    else,  t = 'First-stage case, step 3.1 layout: all propeller loads to the mount ring at the PT axis (limit load)'; end
elseif strcmp(what, 'fscase_flange')
    if tr, t = 'Birinci kademe gövdesi, bağlantı planet gövdesi flanşında: dişli kuvvetleri ve 2,5 g (sınır yük)';
    else,  t = 'First-stage case, mounts at the planetary case flange: gear forces and 2.5 g (limit load)'; end
else
    if tr, t = 'Pervane milli taşıyıcı, LD-08 ani duruş torku, mil ucu sabit';
    else,  t = 'Carrier with the propeller shaft, LD-08 stop torque, shaft end fixed'; end
end
title(t);
set(findall(fig, '-property', 'FontName'), 'FontName', 'Arial');
exportgraphics(fig, fullfile(out_dir, [what '_' lang '.png']), 'Resolution', 150);
close(fig);
end

function plot_margins(S, lang, out_dir)
% safety factors of every step 3.5 check against 1
tr = strcmp(lang, 'tr');
v = {};  n = [];
B = S.bolts;
[v, n] = addm(v, n, ifelse(tr, 'flanş cıvataları: akma (VDI R8)', 'flange bolts: yield (VDI R8)'), B.S_F);
[v, n] = addm(v, n, ifelse(tr, 'flanş cıvataları: yorulma (R9)', 'flange bolts: fatigue (R9)'), B.S_D);
[v, n] = addm(v, n, ifelse(tr, 'flanş: A357 üzerinde pul basıncı (R10)', 'flange: washer pressure on A357 (R10)'), B.S_p);
[v, n] = addm(v, n, ifelse(tr, 'flanş: yalnız sürtünmeyle kayma (R12)', 'flange: slip by friction only (R12)'), B.S_G);
[v, n] = addm(v, n, ifelse(tr, 'flanş: pimler, A357 üzerinde ezilme', 'flange: dowel pins, bearing on A357'), B.S_dowel_bearing);
if isfield(S, 'mount')
    [v, n] = addm(v, n, ifelse(tr, 'bağlantı halkası 12 x M8: kayma', 'mount ring 12 x M8: slip'), S.mount.M8.S_G);
    [v, n] = addm(v, n, ifelse(tr, 'bağlantı halkası 12 x M10: kayma', 'mount ring 12 x M10: slip'), S.mount.M10.S_G);
end
Ln = S.liners.T;
[v, n] = addm(v, n, ifelse(tr, 'NU1024 gömleği: -40 °C''de A357', 'NU1024 liner: A357 at -40 degC'), Ln.n_cold(1));
if isfield(S, 'case')
    K = S.case;
    [v, n] = addm(v, n, ifelse(tr, 'gövde: sınır yük, akma (flanş sabit)', 'case: limit, yield (flange fixed)'), K.n_y(1));
    [v, n] = addm(v, n, ifelse(tr, 'gövde: sınır yük, akma (yay flanş)', 'case: limit, yield (bolted springs)'), K.n_y(2));
    [v, n] = addm(v, n, ifelse(tr, 'gövde: -40 °C gömlek + sınır yük', 'case: liners at -40 degC + limit'), K.n_liner(2));
    [v, n] = addm(v, n, ifelse(tr, 'gövde: yorulma, 1P (Goodman)', 'case: fatigue, 1P (Goodman)'), K.fatigue.n_f);
    [v, n] = addm(v, n, ifelse(tr, 'gövde: dış yuva direngenliği / taban (yay)', 'case: outer seat stiffness / floor (springs)'), K.k_out(2) / 5e7);
end
if isfield(S, 'fscase_mount')
    [v, n] = addm(v, n, ifelse(tr, 'birinci kademe gövdesi, 3.1 bağlantısı: akma', 'first-stage case, step 3.1 mount: yield'), S.fscase_mount.n_y);
    [v, n] = addm(v, n, ifelse(tr, 'birinci kademe gövdesi, flanş bağlantısı: akma', 'first-stage case, flange mounts: yield'), S.fscase_flange.n_y);
end
if isfield(S, 'carrier')
    C = S.carrier;
    [v, n] = addm(v, n, ifelse(tr, 'taşıyıcı: LD-01, presle akma', 'carrier: LD-01, yield with press fit'), C.n_y_with_press(1));
    [v, n] = addm(v, n, ifelse(tr, 'taşıyıcı: LD-08, presle akma', 'carrier: LD-08, yield with press fit'), C.n_y_with_press(2));
end
fig = figure('Visible', 'off', 'Position', [100 100 1000 560]);
nn = min(n, 6);
barh(nn, 'FaceColor', [0.15 0.35 0.65]);
hold on;  xline(1, 'r--', 'LineWidth', 1.5);  grid on
for k = 1:numel(n), text(nn(k) + 0.05, k, sprintf('%.2f', n(k)), 'FontSize', 8); end
set(gca, 'YTick', 1:numel(v), 'YTickLabel', v, 'YDir', 'reverse', 'FontSize', 8);
xlim([0 6.6]);
if tr, xlabel('güvenlik katsayısı (6''nın üstü kesildi)'); title('3.5 yapısal kontrolleri: güvenlik katsayıları');
else,  xlabel('safety factor (cut at 6)'); title('Step 3.5 structural checks: safety factors'); end
set(findall(fig, '-property', 'FontName'), 'FontName', 'Arial');
exportgraphics(fig, fullfile(out_dir, ['margins_' lang '.png']), 'Resolution', 150);
close(fig);
end

function [v, n] = addm(v, n, lab, x)
v{end + 1} = lab;  n(end + 1) = x;
end

function v = ifelse(c, a, b)
if c, v = a; else, v = b; end
end
