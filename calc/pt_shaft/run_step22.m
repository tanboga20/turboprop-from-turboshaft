function S = run_step22(out_dir, mode)
%RUN_STEP22  Step 2.2 full run: PT output shaft, diaphragm couplings, torque meter, tunnel.
%   run_step22              run from the repo root; writes to calc/results/step22
%   S = run_step22(out_dir)
%   run_step22(out_dir, 'plots')   redraws the plots from out_dir/step22.mat
%
%   Needs calc/pt_shaft and calc/rotor_damper (beam_timoshenko) on the path:
%   addpath('calc/pt_shaft', 'calc/rotor_damper').
%   1. Diaphragm couplings: every rim radius, hub ratio, thickness and pack
%      count of in.dia; the smallest rim radius with a design that meets
%      every criterion, then the most flexible such design (lowest k_theta).
%   2. Floating shaft: every diameter and wall of in.D_list x in.t_list at
%      the nominal length; the lightest design that meets DYN-01, STR-03,
%      the buckling and yield margins and the torque meter's twist; the
%      same for the lengths of in.L_list.
%   3. Torque meter of the chosen shaft (CTL-01).
%   4. PT rear bearing (LUB-10, STR-02): loads, life, minimum load.
%   5. Shaft tunnel: temperatures for every buffer air flow and both gas
%      temperatures; the smallest flow that keeps the shaft at or below
%      in.tun.T_shaft_max. Rear sump heat and the oil flow it needs.
%
%   Files written to out_dir:
%     summary.txt               every table of the step
%     shaft_grid.csv            every floating shaft of the grid with its checks
%     tunnel.csv                temperatures along the tunnel, chosen flow
%     shaft_map_en.png, tunnel_en.png and the _tr versions (Turkish labels)
%     step22.mat                the output struct, for redrawing the plots
%     tests.txt                 output of test_step22 (TC24-TC29)
%
%   Source: Phase 2 report, Section 2.2.

if nargin < 1 || isempty(out_dir)
    out_dir = fullfile('calc', 'results', 'step22');
end
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end
if nargin == 2 && strcmp(mode, 'plots')
    S = load(fullfile(out_dir, 'step22.mat')).S;
    plots(out_dir, S, 'en');
    plots(out_dir, S, 'tr');
    return
end
in = ptshaft_inputs();
S.in = in;

% 1. Diaphragm couplings
best = [];
for a = in.dia.a_list
    for br = in.dia.b_ratio
        for t = in.dia.t_list
            for np = in.dia.n_list
                c = diaphragm(a, br * a, t, in, in.n_PT, np);
                if c.ok && (isempty(best) || a < best.a - 1e-12 || ...
                            (abs(a - best.a) < 1e-12 && c.k_th < best.c.k_th))
                    best = struct('a', a, 'b', br * a, 't', t, 'n', np, 'c', c);
                end
            end
        end
    end
    if ~isempty(best), break, end           % smallest rim radius that works
end
S.dia = best;

% 2. Floating shaft
lim_hi = (1 + in.margin) * in.n_steady(2);         % DYN-01; tube_shaft adds in.ncr_extra
k_th = best.c.k_th;
M_bend = best.c.M_mis;
grid = [];
for D = in.D_list
    for t = in.t_list
        if t > D / 6, continue, end
        s = tube_shaft(D, t, in.L, in, k_th, M_bend);
        grid = [grid; D, t, s.m, s.n_cr, s.twist_100, s.n_f, s.n_buck, s.n_yield, s.ok, s.kt]; %#ok<AGROW>
    end
end
S.grid = grid;
okrows = grid(grid(:, 9) == 1, :);
[~, i] = min(okrows(:, 3));
S.D = okrows(i, 1);
S.t = okrows(i, 2);
S.shaft = tube_shaft(S.D, S.t, in.L, in, k_th, M_bend);
for j = 1:numel(in.L_list)
    best_m = inf;  pick = [NaN NaN NaN NaN];
    for D = in.D_list
        for t = in.t_list
            if t > D / 6, continue, end
            s = tube_shaft(D, t, in.L_list(j), in, k_th, M_bend);
            if s.ok && s.m < best_m
                best_m = s.m;  pick = [D, t, s.m, s.n_cr];
            end
        end
    end
    S.L_sens(j, :) = [in.L_list(j), pick];
end
S.lim_hi = lim_hi;

% 3. Torque meter
S.tm = torque_meter(S.shaft, in);

% 4. Rear bearing: the coupling's restoring moment acts over an 80 mm stub to the bearing
S.rb = rear_bearing(in, best.c.M_mis / 0.08);

% 5. Shaft tunnel and rear sump
for g = 1:numel(in.tun.T_gas)
    for j = 1:numel(in.tun.m_air_list)
        th = tunnel_thermal(S.D, in.L, in.tun.m_air_list(j), in.tun.T_gas(g), in);
        S.tun_grid(g, j) = struct('T_gas', in.tun.T_gas(g), 'm_air', in.tun.m_air_list(j), ...
                                  'T_shaft_max', th.T_shaft_max, 'T_air_out', th.T_air_out, ...
                                  'Q_in', th.Q_in, 'P_wind', th.P_wind, 'ok', th.ok);
    end
end
okhot = [S.tun_grid(end, :).ok];
j = find(okhot, 1);
S.m_air = in.tun.m_air_list(j);
S.tun = tunnel_thermal(S.D, in.L, S.m_air, in.tun.T_gas(end), in);
% Rear sump: hot frame through 15 mm of insulation, plus the bearing heat; oil 30 K rise
sp = in.sump;
A_s = pi * sp.D * sp.L + 2 * pi / 4 * sp.D^2;
R_s = in.tun.t_ins / (in.tun.k_ins * A_s) + 1 / (in.tun.h_gas * A_s);
S.Q_sump = (in.tun.T_gas(end) - in.tun.T_sump_max) / R_s + sp.P_brg;
S.oil_sump = S.Q_sump / (2000 * 30) / 950 * 60e3;   % L/min at cp 2000 J/(kg K), 950 kg/m^3

save(fullfile(out_dir, 'step22.mat'), 'S');
write_summary(fullfile(out_dir, 'summary.txt'), S);
write_csv(out_dir, S);
plots(out_dir, S, 'en');
plots(out_dir, S, 'tr');
diary(fullfile(out_dir, 'tests.txt'));
test_step22;
diary off
end

function write_summary(file, S)
in = S.in;  c = S.dia.c;  s = S.shaft;
fid = fopen(file, 'w');
fprintf(fid, 'Step 2.2: PT output shaft, diaphragm couplings, torque meter, rear bearing, shaft tunnel\n');
fprintf(fid, 'Torques: T_100 %.1f, T_MC %.1f, LD-01 %.1f N m; alternating %.0f%% of T_MC; misalignment %.2f deg, %.1f mm\n', ...
        in.T_100, in.T_MC, in.T_lim, 100 * in.T_alt, in.mis.theta, in.mis.axial * 1e3);

fprintf(fid, '\n1. Diaphragm coupling (15-5PH, flat): rim radius %.0f mm, hub radius %.1f mm, %d x %.2f mm diaphragm(s), %.3f kg\n', ...
        S.dia.a * 1e3, S.dia.b * 1e3, S.dia.n, S.dia.t * 1e3, c.mass);
fprintf(fid, '  stiffness: axial %.3g N/m, angular %.1f N m/rad (%.2f N m/deg)\n', c.k_ax, c.k_th, c.k_th * pi / 180);
fprintf(fid, '  loads on the shafts at continuous misalignment: axial %.0f N, moment %.2f N m\n', c.F_ax, c.M_mis);
fprintf(fid, '  stresses [MPa]: torque shear %.1f (MC) %.1f (LD-01), axial bending %.1f, tilt bending %.1f (alternating), hoop %.1f (100%%), %.1f (break %.0f rpm)\n', ...
        c.tau_MC / 1e6, c.tau_lim / 1e6, c.sig_ax / 1e6, c.sig_th / 1e6, c.sig_cf / 1e6, c.sig_cf_brk / 1e6, in.n_break);
fprintf(fid, '  safeties: fatigue %.2f (min %.1f), static %.2f, burst %.2f, shear buckling %.2f (min %.1f)\n', ...
        c.n_f, in.dia.n_f_min, c.n_static, c.n_burst, c.n_buck, in.dia.n_buck_min);

fprintf(fid, '\n2. Floating shaft (AISI 4340), length %.2f m: %.0f x %.1f mm, %.2f kg\n', in.L, S.D * 1e3, S.t * 1e3, s.m);
fprintf(fid, '  critical speed %.0f rpm (DYN-01 needs %.0f, design %.0f), twist at T_100 %.2f deg (min %.2f)\n', s.n_cr, ...
        S.lim_hi, in.ncr_extra * S.lim_hi, s.twist_100, in.tm.theta_min);
fprintf(fid, '  shear [MPa]: %.1f at MC, %.1f at LD-01; fatigue n_f %.2f, yield %.2f, buckling %.1f\n', s.tau_MC / 1e6, ...
        s.tau_lim / 1e6, s.n_f, s.n_yield, s.n_buck);
fprintf(fid, '  length sensitivity (lightest design that meets every criterion):\n');
for j = 1:size(S.L_sens, 1)
    if isnan(S.L_sens(j, 2))
        fprintf(fid, '    L %.2f m: no tube of the grid meets the critical speed and the twist together\n', S.L_sens(j, 1));
    else
        fprintf(fid, '    L %.2f m: %.0f x %.1f mm, %.2f kg, critical %.0f rpm\n', S.L_sens(j, 1), S.L_sens(j, 2) * 1e3, ...
                S.L_sens(j, 3) * 1e3, S.L_sens(j, 4), S.L_sens(j, 5));
    end
end

tm = S.tm;
fprintf(fid, '\n3. Torque meter: twist %.3f deg at T_100, %.3f deg at LD-01; resolution %.4f deg -> %.2f%% of T_100; temperature effect %.1f%% over %g K (needs the shaft temperature)\n', ...
        tm.twist_100, tm.twist_lim, tm.res, 100 * tm.err_res, 100 * tm.err_temp, in.tm.dT_shaft);

rb = S.rb;
fprintf(fid, '\n4. PT rear bearing (%.0f mm bore roller): running load %.0f N (weight %.0f, unbalance %.0f), limit %.0f N\n', ...
        in.brg.d * 1e3, rb.P, rb.F_1g, rb.F_unb, rb.P_lim);
fprintf(fid, '  L10 %.3g h (need %g), s0 %.1f, DN %.3g; minimum load against skidding %.0f N -> skid risk %d\n', ...
        rb.L10, in.L10_req, rb.s0, rb.DN, rb.F_rm, rb.skid);

fprintf(fid, '\n5. Shaft tunnel (insulation %.0f mm, gap %.0f mm, air in at %g degC)\n', in.tun.t_ins * 1e3, ...
        in.tun.gap * 1e3, in.tun.T_air_in);
fprintf(fid, '  %-8s %-10s %12s %12s %10s %10s\n', 'gas degC', 'air g/s', 'shaft max', 'air out', 'Q W', 'wind W');
for g = 1:size(S.tun_grid, 1)
    for j = 1:size(S.tun_grid, 2)
        r = S.tun_grid(g, j);
        fprintf(fid, '  %-8.0f %-10.1f %12.1f %12.1f %10.0f %10.1f\n', r.T_gas, r.m_air * 1e3, r.T_shaft_max, ...
                r.T_air_out, r.Q_in, r.P_wind);
    end
end
fprintf(fid, '  chosen buffer air %.1f g/s: shaft at most %.1f degC on the %g degC gas\n', S.m_air * 1e3, ...
        S.tun.T_shaft_max, in.tun.T_gas(end));
fprintf(fid, '  rear sump heat %.0f W (bearing %g W) -> oil %.2f L/min at a 30 K rise (LUB-10)\n', S.Q_sump, ...
        in.sump.P_brg, S.oil_sump);
fclose(fid);
end

function write_csv(out_dir, S)
fid = fopen(fullfile(out_dir, 'shaft_grid.csv'), 'w');
fprintf(fid, 'D_mm,t_mm,mass_kg,n_cr_rpm,twist_deg,n_f,n_buck,n_yield,ok\n');
fprintf(fid, '%.1f,%.2f,%.3f,%.0f,%.3f,%.3f,%.2f,%.2f,%d\n', [S.grid(:, 1:2) * 1e3, S.grid(:, 3:9)].');
fclose(fid);
fid = fopen(fullfile(out_dir, 'tunnel.csv'), 'w');
fprintf(fid, 'x_m,T_air_C,T_liner_C,T_shaft_C\n');
fprintf(fid, '%.4f,%.2f,%.2f,%.2f\n', [S.tun.x, S.tun.T_air(1:end - 1), S.tun.T_liner, S.tun.T_shaft].');
fclose(fid);
end

function plots(out_dir, S, lang)
in = S.in;
if strcmp(lang, 'tr')
    L = struct('D', 'Dış çap D (mm)', 't', 'Cidar kalınlığı t (mm)', 'ncr', 'kritik hız tasarım sınırı %.0f rpm (DYN-01 %.0f rpm + %%5)', ...
               'tw', 'tork ölçer burulması sınırı', 'kt', 'burulma rijitliği tabanı %.0f N·m/rad (2.3)', ...
               'ok', 'bütün kontrolleri geçiyor', 'pick', 'seçilen', ...
               'mass', 'kütle (kg)', 'title', sprintf('Yüzer mil, uzunluk %.2f m: tasarım alanı', in.L), ...
               'x', 'Tünel boyunca konum (m)', 'T', 'Sıcaklık (°C)', 'air', 'tampon hava', 'liner', 'tünel iç cidarı', ...
               'shaft', 'mil', 'lim', 'mil sınırı', ...
               'ttitle', sprintf('Şaft tüneli, gaz %g °C, tampon hava %.1f g/s', in.tun.T_gas(end), S.m_air * 1e3));
else
    L = struct('D', 'Outer diameter D (mm)', 't', 'Wall thickness t (mm)', 'ncr', 'critical speed design limit %.0f rpm (DYN-01 %.0f rpm + 5%%)', ...
               'tw', 'torque meter twist limit', 'kt', 'torsional stiffness floor %.0f N·m/rad (2.3)', ...
               'ok', 'meets every check', 'pick', 'chosen', ...
               'mass', 'mass (kg)', 'title', sprintf('Floating shaft, length %.2f m: design space', in.L), ...
               'x', 'Position along the tunnel (m)', 'T', 'Temperature (°C)', 'air', 'buffer air', 'liner', ...
               'tunnel liner', 'shaft', 'shaft', 'lim', 'shaft limit', ...
               'ttitle', sprintf('Shaft tunnel, gas %g °C, buffer air %.1f g/s', in.tun.T_gas(end), S.m_air * 1e3));
end
g = S.grid;
Du = unique(g(:, 1));  tu = unique(g(:, 2));
[DD, TT] = meshgrid(Du, tu);
F = @(col) griddata(g(:, 1), g(:, 2), g(:, col), DD, TT);
fig = figure('Visible', 'off', 'Position', [100 100 820 520]);
hold on
ok = g(:, 9) == 1;
h0 = plot(g(ok, 1) * 1e3, g(ok, 2) * 1e3, 's', 'MarkerSize', 6, 'MarkerFaceColor', [0.85 0.94 0.85], ...
          'MarkerEdgeColor', [0.6 0.8 0.6]);
[cm, hm] = contour(DD * 1e3, TT * 1e3, F(3), [0.5 1 1.5 2 3 4 5], ':', 'Color', [0.4 0.4 0.4]);
clabel(cm, hm, 'FontSize', 7, 'Color', [0.4 0.4 0.4]);
lim = in.ncr_extra * S.lim_hi;
[~, h1] = contour(DD * 1e3, TT * 1e3, F(4), [lim lim], '-', 'Color', [0.75 0.22 0.17], 'LineWidth', 1.6);
[~, h2] = contour(DD * 1e3, TT * 1e3, F(5), [in.tm.theta_min in.tm.theta_min], '-', 'Color', [0.12 0.44 0.70], ...
                  'LineWidth', 1.6);
[~, h4] = contour(DD * 1e3, TT * 1e3, F(10), [in.kt_min in.kt_min], '-', 'Color', [0.20 0.55 0.25], 'LineWidth', 1.6);
h3 = plot(S.D * 1e3, S.t * 1e3, 'kp', 'MarkerSize', 13, 'MarkerFaceColor', [0.96 0.77 0.2]);
xlabel(L.D);  ylabel(L.t);  grid on;  box on
legend([h0 h1 h2 h4 h3 hm], {L.ok, sprintf(L.ncr, lim, S.lim_hi), ...
       sprintf('%s %.2f°', L.tw, in.tm.theta_min), sprintf(L.kt, in.kt_min), ...
       sprintf('%s %.0f × %.1f mm', L.pick, S.D * 1e3, S.t * 1e3), L.mass}, 'Location', 'northeast', 'FontSize', 8);
title(L.title, 'FontWeight', 'normal', 'FontSize', 10);
exportgraphics(fig, fullfile(out_dir, ['shaft_map_' lang '.png']), 'Resolution', 150);
close(fig);

fig = figure('Visible', 'off', 'Position', [100 100 760 440]);
hold on
x = S.tun.x;
plot(x, S.tun.T_liner, '-', 'Color', [0.75 0.22 0.17], 'LineWidth', 1.4);
plot(x, S.tun.T_air(1:end - 1), '-', 'Color', [0.12 0.44 0.70], 'LineWidth', 1.4);
plot(x, S.tun.T_shaft, '--', 'Color', [0.1 0.1 0.1], 'LineWidth', 1.2);
yline(in.tun.T_shaft_max, ':k', L.lim, 'LabelHorizontalAlignment', 'right', 'LabelVerticalAlignment', 'top');
xlabel(L.x);  ylabel(L.T);  grid on;  box on
legend({L.liner, L.air, L.shaft}, 'Location', 'southeast', 'FontSize', 8);
title(L.ttitle, 'FontWeight', 'normal', 'FontSize', 10);
exportgraphics(fig, fullfile(out_dir, ['tunnel_' lang '.png']), 'Resolution', 150);
close(fig);
end
