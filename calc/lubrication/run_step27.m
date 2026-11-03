function S = run_step27(out_dir, mode)
%RUN_STEP27  Step 2.7: the RGB lubrication system (LUB-01 to LUB-10, SYS-05).
%   S = run_step27()                  full run, results in calc/results/step27
%   S = run_step27(out_dir)           results in out_dir
%   S = run_step27(out_dir, 'plots')  redraw the plots from step27.mat
%
%   Runs from the repo root with calc/lubrication, calc/agb_lube,
%   calc/gear_detail, calc/shafts_bearings and calc/accessory on the path.
%   Steps:
%    1. heat balance of the detailed RGB at maximum continuous power and the
%       oil flows and jets it needs, by a fixed point (the pump power is a
%       loss and depends on the flow)
%    2. losses at the four operating points (SYS-05, LUB-04)
%    3. pumps: supply and the two scavenge elements (RGB sump, PT rear sump)
%    4. air-oil cooler at the LUB-04 duty over a range of face velocities,
%       and the options of decision 5 (LUB-09)
%    5. tank (LUB-06), windmilling flow (SAF-04), MIL-PRF-7808 check
%   Writes summary.txt, jets.csv, two plots in English and Turkish and
%   step27.mat to out_dir (calc/results is not committed).
%
%   Source: Phase 2 report, Section 2.7.

if nargin < 1 || isempty(out_dir)
    out_dir = fullfile('calc', 'results', 'step27');
end
if nargin < 2, mode = 'full'; end
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
if strcmp(mode, 'plots')
    L = load(fullfile(out_dir, 'step27.mat'));
    make_plots(L.S, out_dir);
    S = L.S;
    return
end

in = lb_inputs();
D = lb_design();
n_mid = D.M(1).ns;
N = D.gi.s2.N;

% 1. Fixed point at maximum continuous power
P_pumps = 2000;
for it = 1:30
    R = lb_losses(D, in.ops(1), P_pumps, in);
    F = lb_flows(R.L, N, in, R.oil);
    P = pumps(F, in, n_mid, R.oil);
    if abs(P.P - P_pumps) < 0.1, break, end
    P_pumps = P.P;
end
S = struct('in', in, 'F', F, 'P', P, 'iter', it);

% 2. Operating points; the pumps turn with the intermediate shaft, so their power is the same
for k = 1:numel(in.ops)
    Rk(k) = lb_losses(D, in.ops(k), P_pumps, in); %#ok<AGROW>
end
S.R = Rk;
oil = R.oil;
m_oil = F.Q_need / 6e4 * oil.rho;
S.dT_rgb = Rk(1).Q_oil / (m_oil * oil.cp);                 % K, oil temperature rise through the RGB at MC

% 4. Cooler at the LUB-04 duty and the decision 5 options
for j = 1:numel(in.v_face)
    Cs(j) = lb_cooler(in.Q_cooler, m_oil, in.v_face(j), in); %#ok<AGROW>
end
S.Cs = Cs;
S.C = lb_cooler(in.Q_cooler, m_oil, in.v_face_design, in);
dT_core = in.Q_cooler / (in.core_mdot * 1005);
dp_rel = (S.C.dp_air + in.dp_ducts) / (in.p_air * 1e3) * 100;
S.optA = struct('dT', dT_core, 'dp_rel', dp_rel, 'loss_pct', in.dPdT * dT_core + in.dPdp * dp_rel);
S.optC = struct('P_fan', S.C.P_fan);

% 5. Tank, windmilling, 7808
cap = P.cap;
V_dwell = cap * in.t_dwell / 60;
V_cons = in.consumption * in.mission_h;
V_usable = in.V_gulp + in.V_circuit + V_dwell + V_cons + in.V_feather;
S.tank = struct('V_dwell', V_dwell, 'V_cons', V_cons, 'V_usable', V_usable, ...
                'V_tank', (V_usable + in.V_unusable) / (1 - in.expansion));
Lw = Rk(1).L;
wind = Lw.wind_pinion + Lw.wind_gear2 + Lw.wind_planetary + Lw.wind_acc;
brg0 = Lw.brg_inp + Lw.brg_mid + Lw.brg_prop + Lw.brg_planet + Lw.brg_acc;
f = in.f_windmill;
S.windmill = struct('flow', f * F.Q_need, 'heat', wind * f^2.8 + 0.5 * brg0 * f^(5/3), ...
                    'heat_MC', Rk(1).Q_oil - Lw.rear_sump);
S.windmill.ratio = (S.windmill.flow / F.Q_need) / (S.windmill.heat / S.windmill.heat_MC);
o78 = oil_props(105, in.oil7808);
S.oil7808 = struct('nu105', o78.nu, 'nu100_23699', oil_props(100, in.oil).nu);

save(fullfile(out_dir, 'step27.mat'), 'S');
write_summary(S, out_dir);
write_csv(S, out_dir);
make_plots(S, out_dir);
end

function P = pumps(F, in, n, oil)
% Supply pump and two scavenge elements: capacities [L/min], displacement [cm^3/rev], power [W], torque [N m]
cap = in.pump_margin * F.Q_need;
cap_s = in.k_scav * in.pump_margin * [F.Q_main, F.Q_rear] * (1 + in.leak);
P_sup = in.dp_supply * 1e3 * cap / 6e4 / in.eta_supply;
P_scv = in.dp_scav * 1e3 * sum(cap_s) / 6e4 / in.eta_scav;
P = struct('cap', cap, 'V_d', cap * 1000 / (n * in.eta_vol), 'cap_s', cap_s, ...
           'V_ds', cap_s * 1000 / (n * in.eta_vol), 'P_sup', P_sup, 'P_scv', P_scv, 'P', P_sup + P_scv, ...
           'T', (P_sup + P_scv) / (n * 2 * pi / 60), 'rho', oil.rho);
end

function write_summary(S, out_dir)
in = S.in;  F = S.F;  P = S.P;  C = S.C;
fid = fopen(fullfile(out_dir, 'summary.txt'), 'w');
fprintf(fid, 'Step 2.7: RGB lubrication system (fixed point in %d iterations)\n\n', S.iter);
names = fieldnames(S.R(1).L);
fprintf(fid, '%-16s', 'loss [W]');  fprintf(fid, '%11s', S.in.ops.name);  fprintf(fid, '\n');
for k = 1:numel(names)
    fprintf(fid, '%-16s', names{k});
    for j = 1:numel(S.R), fprintf(fid, '%11.1f', S.R(j).L.(names{k})); end
    fprintf(fid, '\n');
end
fprintf(fid, '%-16s', 'L_mech (SYS-05)');  fprintf(fid, '%11.1f', [S.R.L_mech]);  fprintf(fid, '\n');
fprintf(fid, '%-16s', 'Q_oil (LUB-04)');  fprintf(fid, '%11.1f', [S.R.Q_oil]);  fprintf(fid, '\n');
fprintf(fid, '%-16s', 'P_PT kW');  fprintf(fid, '%11.2f', [S.R.P_PT] / 1e3);  fprintf(fid, '\n');
fprintf(fid, '%-16s', 'efficiency %');  fprintf(fid, '%11.3f', 100 * [S.R.eta]);  fprintf(fid, '\n');
fprintf(fid, 'SYS-05: %.2f kW at MC (limit 13.6); LUB-04: %.2f kW into the oil (limit 18); oil rise through the RGB %.1f K\n\n', ...
        S.R(1).L_mech / 1e3, S.R(1).Q_oil / 1e3, S.dT_rgb);
fprintf(fid, 'Oil flows and jets at MC (dp %d kPa, jet velocity %.1f m/s, design rise %d K):\n', in.dp_jet, F.v_jet, in.dT_oil);
fprintf(fid, '  %-28s %8s %8s %8s %5s %6s\n', 'component', 'heat W', 'need', 'flow', 'jets', 'd mm');
for k = 1:numel(F.comp)
    c = F.comp(k);
    fprintf(fid, '  %-28s %8.0f %8.2f %8.2f %5d %6.2f\n', c.name, c.heat, c.need, c.flow, c.jets, c.d);
end
fprintf(fid, '  lube %.2f L/min, with the PCU %.1f and %.0f%% leaks: %.2f L/min (RGB sump %.2f, PT rear sump %.2f)\n\n', ...
        F.Q_lube, in.Q_pcu, 100 * in.leak, F.Q_need, F.Q_main, F.Q_rear);
fprintf(fid, 'Pumps at %.0f rpm: supply %.1f L/min (%.2f cm3/rev); scavenge RGB %.1f, rear %.1f L/min (%.2f, %.2f cm3/rev)\n', ...
        S.R(1).P_PT * 0 + 6200, P.cap, P.V_d, P.cap_s, P.V_ds);
fprintf(fid, '  power supply %.0f W, scavenge %.0f W, total %.0f W, torque %.2f N m (step 2.6 pump neck: 3.46 N m)\n\n', ...
        P.P_sup, P.P_scv, P.P, P.T);
fprintf(fid, 'Cooler at %.0f kW, air %.2f kg/s at %d degC, oil out %d degC (oil in %.1f degC):\n', in.Q_cooler / 1e3, ...
        in.m_air, in.T_amb, in.T_oil_out, C.T_oil_in);
fprintf(fid, '  %6s %8s %8s %8s %8s %8s %8s %8s %8s\n', 'v m/s', 'face m2', 'W mm', 'L mm', 'dp_a Pa', 'dp_o kPa', 'mass kg', 'fan W', 'Re_a');
for j = 1:numel(S.Cs)
    q = S.Cs(j);
    fprintf(fid, '  %6.1f %8.4f %8.0f %8.1f %8.0f %8.1f %8.2f %8.0f %8.0f\n', q.v_face, q.A_fr, q.W, q.L, q.dp_air, ...
            q.dp_oil / 1e3, q.m_cooler, q.P_fan, q.Re_a);
end
fprintf(fid, '  design %.1f m/s: eps %.3f, NTU %.3f, UA %.0f W/K; air j %.4f f %.4f h %.0f W/m2K eta_o %.3f; oil Re %.0f h %.0f W/m2K eta_o %.3f\n\n', ...
        C.v_face, C.eps, C.NTU, C.UA, C.j_a, C.f_a, C.h_a, C.eta_oa, C.Re_o, C.h_o, C.eta_oo);
fprintf(fid, 'Decision 5: A (engine inlet) heats the core air %.1f K and costs %.2f%% pressure: about %.1f%% power (TBR);\n', ...
        S.optA.dT, S.optA.dp_rel, S.optA.loss_pct);
fprintf(fid, '  C (fan) needs %.0f W at the LUB-04 duty on the ground\n\n', S.optC.P_fan);
t = S.tank;
fprintf(fid, 'Tank: dwell %.2f, consumption %.2f, usable %.2f, total %.2f L\n', t.V_dwell, t.V_cons, t.V_usable, t.V_tank);
w = S.windmill;
fprintf(fid, 'Windmilling at %.0f%% speed: flow %.1f L/min, heat about %.0f W (MC %.0f W): flow share / heat share %.1f\n', ...
        100 * in.f_windmill, w.flow, w.heat, w.heat_MC, w.ratio);
fprintf(fid, 'MIL-PRF-7808 at 105 degC: %.2f cSt (23699 at 100 degC: %.2f cSt)\n', S.oil7808.nu105, S.oil7808.nu100_23699);
fclose(fid);
type(fullfile(out_dir, 'summary.txt'));
end

function write_csv(S, out_dir)
fid = fopen(fullfile(out_dir, 'jets.csv'), 'w');
fprintf(fid, 'component,heat_W,need_Lmin,flow_Lmin,jets,d_mm\n');
for k = 1:numel(S.F.comp)
    c = S.F.comp(k);
    fprintf(fid, '%s,%.1f,%.3f,%.3f,%d,%.2f\n', c.name, c.heat, c.need, c.flow, c.jets, c.d);
end
fclose(fid);
end

function make_plots(S, out_dir)
for lang = {'en', 'tr'}
    plots(S, out_dir, lang{1});
end
end

function plots(S, out_dir, lang)
in = S.in;
tr = strcmp(lang, 'tr');
if tr
    on = {'azami sürekli', 'azami sürekli, sıcak yağ', 'bekleme (%50)', 'alçalma (%30)'};
    gn = {'kavramalar', 'rulmanlar', 'çalkalanma', 'pompalar', 'PCU ve OSG', 'PT arka yatak bölmesi'};
    L = struct('y', 'Isı (kW)', 't1', 'RGB kayıpları ve yağa giren ısı (çalışma noktalarında)', ...
               's5', 'SYS-05: 13,6 kW (mekanik kayıp)', 'l4', 'LUB-04: 18 kW (yağa giren ısı)', ...
               'v', 'Hava yüz hızı (m/s)', 'm', 'Soğutucu kütlesi (kg)', 'f', 'Fan gücü, yerde (W)', ...
               't2', 'Hava-yağ soğutucusu, 18 kW, 53 °C gün: boyut ve fan gücü', 'd', 'tasarım');
else
    on = {'maximum continuous', 'maximum continuous, hot oil', 'loiter (50%)', 'descent (30%)'};
    gn = {'meshes', 'bearings', 'windage', 'pumps', 'PCU and OSG', 'PT rear sump'};
    L = struct('y', 'Heat (kW)', 't1', 'RGB losses and heat into the oil at the operating points', ...
               's5', 'SYS-05: 13.6 kW (mechanical loss)', 'l4', 'LUB-04: 18 kW (heat into the oil)', ...
               'v', 'Air face velocity (m/s)', 'm', 'Cooler mass (kg)', 'f', 'Fan power on the ground (W)', ...
               't2', 'Air-oil cooler, 18 kW, 53 °C day: size and fan power', 'd', 'design');
end
blue = [0.12 0.44 0.70];  lblue = [0.55 0.75 0.90];  gold = [0.85 0.60 0.10];  grey = [0.45 0.45 0.45];
red = [0.75 0.22 0.17];  green = [0.30 0.60 0.35];

% 1. Heat balance
Y = zeros(numel(S.R), 6);
for k = 1:numel(S.R)
    l = S.R(k).L;
    Y(k, :) = [l.mesh_s1 + l.mesh_sp + l.mesh_pr + l.mesh_gen + l.mesh_osg + l.mesh_pcu, ...
               l.brg_inp + l.brg_mid + l.brg_prop + l.brg_planet + l.brg_acc, ...
               l.wind_pinion + l.wind_gear2 + l.wind_planetary + l.wind_acc, l.pumps, l.pcu_osg, l.rear_sump] / 1e3;
end
fig = figure('Visible', 'off', 'Position', [100 100 1000 430]);
b = bar(Y, 0.55, 'stacked');
cols = {blue, lblue, gold, grey, green, red};
for k = 1:6, b(k).FaceColor = cols{k}; end
hold on
h1 = yline(13.6, '--', 'Color', grey, 'LineWidth', 1.2);
h2 = yline(18, ':', 'Color', red, 'LineWidth', 1.4);
set(gca, 'XTickLabel', on);  ylabel(L.y);  grid on;  ylim([0 20]);
legend([b h1 h2], [gn, {L.s5, L.l4}], 'Location', 'northeast', 'FontSize', 8);
title(L.t1, 'FontWeight', 'normal', 'FontSize', 10);
exportgraphics(fig, fullfile(out_dir, ['heat_' lang '.png']), 'Resolution', 150);
close(fig);

% 2. Cooler trade
fig = figure('Visible', 'off', 'Position', [100 100 900 400]);
v = [S.Cs.v_face];
yyaxis left
plot(v, [S.Cs.m_cooler], 'o-', 'Color', blue, 'MarkerFaceColor', blue, 'LineWidth', 1.3);
ylabel(L.m);  set(gca, 'YColor', blue);  ylim([0 1.2 * max([S.Cs.m_cooler])]);
yyaxis right
plot(v, [S.Cs.P_fan], 's-', 'Color', red, 'MarkerFaceColor', red, 'LineWidth', 1.3);  hold on
plot(S.C.v_face, S.C.P_fan, 'kp', 'MarkerSize', 12, 'MarkerFaceColor', 'y');
text(S.C.v_face, S.C.P_fan * 1.08, ['  ' L.d], 'FontSize', 8);
ylabel(L.f);  set(gca, 'YColor', red);  ylim([0 1.2 * max([S.Cs.P_fan])]);
xlabel(L.v);  grid on
title(L.t2, 'FontWeight', 'normal', 'FontSize', 10);
exportgraphics(fig, fullfile(out_dir, ['cooler_' lang '.png']), 'Resolution', 150);
close(fig);
end
