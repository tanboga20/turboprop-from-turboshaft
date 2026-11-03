function R = run_step14(out_dir)
%RUN_STEP14  Step 1.4 full run: accessory pads, RGB losses, oil system sizing, shaft break.
%   run_step14              run from the repo root; writes to calc/results/step14
%   R = run_step14(out_dir)
%
%   Needs calc/rgb_sizing on the path (gear_geometry, iso6336_lite and the
%   step 1.3 layout functions): addpath('calc/rgb_sizing', 'calc/agb_lube').
%   1. Builds the RGB design of lube_inputs (in14.design) with the step 1.3 tool.
%   2. Sizes the oil system by a fixed point: losses at maximum continuous
%      power (in14.ops(1)) set the oil flow, the flow sets the pump power,
%      the pump power adds to the losses.
%   3. Losses at every operating point of in14.ops (pump power x speed^3).
%   4. Loss sensitivity at maximum continuous power to the uncertain inputs.
%   5. Shaft break: the main case (in14 values) and a map of peak speed over
%      detection-to-valve time, for three torque decay times, two rotor
%      inertias and two break torques (MC and LD-01).
%   6. RGB mass with the accessory drive mass in place of the 6 kg placeholder.
%
%   Files written to out_dir:
%     summary.txt       every table of the step
%     losses.csv        loss breakdown at each operating point
%     shaft_break.csv   the shaft-break map
%     losses.png        loss breakdown chart
%     shaft_break.png   speed after the break and peak speed over delay
%     tests.txt         output of test_step14 (TC10-TC17)
%   Output struct R: in, in14, L (rgb_layout), A (accessory_pads), S
%   (lube_sizing), ops (rgb_losses per operating point), sens, brk (main
%   case), map, mass (RGB total with the new accessory drives).
%
%   Source: Phase 1 report, Section 4.

if nargin < 1
    out_dir = fullfile('calc', 'results', 'step14');
end
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end
in = rgb_inputs();
in14 = lube_inputs();

% 1. The RGB design
L = design(in14.design, in);
n_mid = in.n_PT / L.t.u1;

% 2. Oil system sizing at maximum continuous power
op = in14.ops(1);
P_pumps = 0;
T_pump = 0;
for it = 1:50
    A = accessory_pads(L, in, in14, T_pump);
    Rmc = rgb_losses(L, A, op, P_pumps, in, in14);
    S = lube_sizing(Rmc.Q_oil, n_mid, in14);
    if abs(S.P_pumps - P_pumps) < 1e-6
        break
    end
    P_pumps = S.P_pumps;
    T_pump = S.T_pump;
end
A = accessory_pads(L, in, in14, S.T_pump);

% 3. Every operating point
ops = cell(1, numel(in14.ops));
for j = 1:numel(in14.ops)
    o = in14.ops(j);
    ops{j} = rgb_losses(L, A, o, S.P_pumps * o.f_n^3, in, in14);
end

% 4. Sensitivity of the maximum continuous losses
sens = struct('name', {}, 'L_mech', {}, 'Q_oil', {}, 'eta', {});
cases = {'baseline', {};
         'bearing f0 2 (roller), 1.5 (ball)', {'f0_roller', 2, 'f0_ball', 1.5};
         'bearing f0 4 (roller), 3 (ball)', {'f0_roller', 4, 'f0_ball', 3};
         'roughness Ra 0.2 um', {'Ra', 0.2};
         'roughness Ra 0.4 um', {'Ra', 0.4};
         'lubricant factor X_L 0.8', {'XL', 0.8};
         'pump efficiencies x 1.5', {'eta_supply', 1.5 * in14.eta_supply, 'eta_scav', 1.5 * in14.eta_scav}};
for j = 1:size(cases, 1)
    p = in14;
    c = cases{j, 2};
    for k = 1:2:numel(c)
        p.(c{k}) = c{k + 1};
    end
    Pp = S.P_pumps * in14.eta_supply / p.eta_supply;   % both efficiencies scale together here
    r = rgb_losses(L, A, op, Pp, in, p);
    sens(end + 1) = struct('name', cases{j, 1}, 'L_mech', r.L_mech, 'Q_oil', r.Q_oil, 'eta', r.eta); %#ok<AGROW>
end

% 5. Shaft break
brk = shaft_break(in14.J_PT, ops{1}.T_PT, in.n_PT, in14.t_proc + in14.t_valve, in14.tau_cut, in14);
delays = 0.005:0.005:0.100;
taus = [0.05 0.10 0.20];
Js = [in14.J_PT, in14.J_PT_low];
Q0s = [ops{1}.T_PT, in.K_over * in.T_PT];
map = zeros(numel(Js) * numel(Q0s) * numel(taus), numel(delays));
rows = zeros(size(map, 1), 3);
k = 0;
for J = Js
    for Q0 = Q0s
        for tau = taus
            k = k + 1;
            rows(k, :) = [J, Q0, tau];
            for d = 1:numel(delays)
                map(k, d) = shaft_break(J, Q0, in.n_PT, delays(d), tau, in14).peak;
            end
        end
    end
end

% 6. RGB mass with the accessory drives of this step
sub = L.mass.total / (1 + in.misc_share) - in.m_accessory + A.mass.total;
mass = struct('rgb_13', L.mass.total, 'acc_13', in.m_accessory, 'acc_14', A.mass.total, ...
              'rgb_14', sub * (1 + in.misc_share));

R = struct('in', in, 'in14', in14, 'L', L, 'A', A, 'S', S, 'iterations', it, 'ops', {ops}, ...
           'sens', sens, 'brk', brk, 'delays', delays, 'map_rows', rows, 'map', map, 'mass', mass);

% Files
write_summary(fullfile(out_dir, 'summary.txt'), R);
write_losses_csv(fullfile(out_dir, 'losses.csv'), R);
fid = fopen(fullfile(out_dir, 'shaft_break.csv'), 'w');
fprintf(fid, 'J_kgm2,Q0_Nm,tau_s%s\n', sprintf(',peak_at_%gms', 1000 * delays));
for k = 1:size(map, 1)
    fprintf(fid, '%.3f,%.1f,%.2f%s\n', rows(k, :), sprintf(',%.4f', map(k, :)));
end
fclose(fid);
try
    plot_losses(R, fullfile(out_dir, 'losses.png'));
    plot_break(R, fullfile(out_dir, 'shaft_break.png'));
catch err
    warning('run_step14: plots not written (%s)', err.message);
end
test_line = run_tests(fullfile(out_dir, 'tests.txt'));

% Summary on the screen
o = ops{1};
fprintf('Design %d/%d | %d/%d/%d, N = %d; fixed point in %d iterations\n', L.t.z1, L.t.z2, ...
        L.t.zs, L.t.zp, L.t.zr, L.t.N, it);
fprintf('Max continuous: P_PT %.1f kW, losses %.2f kW (efficiency %.2f%%), heat into oil %.2f kW\n', ...
        o.P_PT / 1e3, o.L_mech / 1e3, 100 * o.eta, o.Q_oil / 1e3);
fprintf('Oil: flow %.1f L/min, pump %.1f L/min (%.2f cm^3/rev), tank %.1f L\n', S.Q_lube, S.cap, ...
        S.V_d, S.V_tank);
fprintf('Shaft break: detected at %.1f ms, peak %.1f%% at %.0f ms\n', 1000 * brk.t_det, ...
        100 * brk.peak, 1000 * brk.t_peak);
fprintf('Accessory drives %.2f kg; RGB %.1f kg (step 1.3: %.1f kg)\n', A.mass.total, mass.rgb_14, ...
        mass.rgb_13);
fprintf('Tests: %s\n', test_line);
fprintf('Files written to %s\n', out_dir);
end

function L = design(d, in)
% One layout O design from its tooth counts [z1 z2 zs zp N] (step 1.3 tool)
t = tooth_set_check(d(1), d(2), d(3), d(4), d(5), in);
s1 = size_stage1(t.z1, t.z2, in);
s2 = size_stage2(t, in);
L = rgb_layout(t, s1, s2, in);
end

function write_summary(file, R)
in = R.in;  in14 = R.in14;  L = R.L;  A = R.A;  S = R.S;
fid = fopen(file, 'w');
fprintf(fid, 'Step 1.4: accessory pads, RGB losses, oil system, shaft break\n');
fprintf(fid, 'RGB design %d/%d | %d/%d/%d, N = %d (layout O, step 1.3 tool)\n', L.t.z1, L.t.z2, ...
        L.t.zs, L.t.zp, L.t.zr, L.t.N);

fprintf(fid, '\nAccessory pads (ACC-02, ACC-03)\n');
fprintf(fid, '  %-10s %8s %9s %9s %6s %6s %5s %7s %7s %7s %7s %7s %8s\n', 'pad', 'n rpm', ...
        'n/n_PT', 'CT7-9', 'z1', 'z2', 'b', 'S_H', 'S_F', 'S_H1.5', 'S_Fst', 'd_neck', 'T_shear');
names = {'generator', 'OSG', 'PCU'};
P = {A.gen, A.osg, A.pcu};
for j = 1:3
    p = P{j};
    ct7 = NaN;
    if isfield(p, 'ratio_ct7'), ct7 = p.ratio_ct7; end
    fprintf(fid, '  %-10s %8.1f %9.5f %9.5f %6d %6d %5g %7.3f %7.3f %7.3f %7.3f %7.2f %8.1f\n', ...
            names{j}, p.n, p.ratio, ct7, p.z1, p.z2, p.b, p.r.S_H, min(p.r.S_F1, p.r.S_F2), ...
            p.rf.S_H, min(p.rs.S_F1, p.rs.S_F2), p.d_shear, p.T_shear);
end
fprintf(fid, '  oil pump: %.1f rpm on the intermediate shaft, %.2f N m, neck %.2f mm, shear %.1f N m\n', ...
        A.pump.n, A.pump.T, A.pump.d_shear, A.pump.T_shear);
m = A.mass;
fprintf(fid, ['  drive mass [kg]: generator gear %.3f, OSG gears %.3f, PCU gears %.3f, shafts %.3f, ' ...
              'bearings %.3f, quills %.3f, pad adapters %.2f, housing %.2f; total %.2f\n'], ...
        m.gen_gear, m.osg_gears, m.pcu_gears, m.acc_shafts, m.acc_bearings, m.quills, ...
        m.adapters, m.housing, m.total);
fprintf(fid, '  RGB mass: step 1.3 %.2f kg with %g kg placeholder -> %.2f kg (SYS-06: %g)\n', ...
        R.mass.rgb_13, R.mass.acc_13, R.mass.rgb_14, in.m_max);

fprintf(fid, '\nLosses [W] (oil properties at T_in + %g/2)\n', in14.dT_oil);
f = fieldnames(R.ops{1}.L);
fprintf(fid, '  %-15s', 'item');
fprintf(fid, ' %10s', in14.ops.name);
fprintf(fid, '\n');
for k = 1:numel(f)
    fprintf(fid, '  %-15s', f{k});
    for j = 1:numel(R.ops)
        fprintf(fid, ' %10.1f', R.ops{j}.L.(f{k}));
    end
    fprintf(fid, '\n');
end
rowf = @(name, fn, sc, fmt) fprintf(fid, ['  %-15s' repmat([' ' fmt], 1, numel(R.ops)) '\n'], ...
                                    name, cellfun(@(o) sc * o.(fn), R.ops));
rowf('L_mech', 'L_mech', 1, '%10.1f');
rowf('Q_oil', 'Q_oil', 1, '%10.1f');
rowf('P_PT kW', 'P_PT', 1e-3, '%10.2f');
rowf('P_prop kW', 'P_prop', 1e-3, '%10.2f');
rowf('P_gen kW', 'P_gen', 1e-3, '%10.2f');
rowf('T_PT N m', 'T_PT', 1, '%10.2f');
rowf('efficiency %', 'eta', 100, '%10.3f');
fprintf(fid, '  first stage at MC: mu_mz %.4f, H_V %.4f\n', R.ops{1}.mu_s1, R.ops{1}.HV_s1);
fprintf(fid, '  SYS-05: losses at MC %.2f kW (limit 13.6 kW); LUB-04: heat into oil %.2f kW (limit 18 kW)\n', ...
        R.ops{1}.L_mech / 1e3, R.ops{1}.Q_oil / 1e3);

fprintf(fid, '\nLoss sensitivity at MC\n');
for j = 1:numel(R.sens)
    s = R.sens(j);
    fprintf(fid, '  %-36s L_mech %8.1f W  Q_oil %8.1f W  efficiency %.3f%%\n', s.name, s.L_mech, ...
            s.Q_oil, 100 * s.eta);
end

fprintf(fid, '\nOil system (design heat %.1f W at T_in %g degC, dT %g K)\n', R.ops{1}.Q_oil, ...
        in14.T_in, in14.dT_oil);
fprintf(fid, '  lube flow %.2f L/min, need with PCU and leaks %.2f, pump capacity %.2f L/min, %.3f cm^3/rev\n', ...
        S.Q_lube, S.Q_need, S.cap, S.V_d);
fprintf(fid, '  scavenge %.2f L/min; pump power supply %.0f W, scavenge %.0f W, torque %.3f N m\n', ...
        S.cap_s, S.P_sup, S.P_scv, S.T_pump);
fprintf(fid, '  tank: dwell %.2f, consumption %.2f, usable %.2f, total %.2f L\n', S.V_dwell, S.V_cons, ...
        S.V_usable, S.V_tank);
fprintf(fid, '  cooler at %g kW: oil in %.1f degC, air %.3f kg/s, LMTD %.1f K, UA %.1f W/K, mass %.1f kg\n', ...
        in14.Q_cooler / 1e3, S.T_hot, S.m_air, S.lmtd, S.UA, S.m_cooler);
fprintf(fid, '  oil jets at %.2f MPa: %.1f m/s\n', in14.dp_jet / 1e6, S.v_jet);

b = R.brk;
fprintf(fid, '\nShaft break (SAF-03): J %.3f kg m^2, Q0 %.1f N m, delay %.0f ms, tau %.0f ms\n', ...
        in14.J_PT, R.ops{1}.T_PT, 1000 * (in14.t_proc + in14.t_valve), 1000 * in14.tau_cut);
fprintf(fid, '  initial rate %.1f %%/s, detected at %.1f ms, valve closed at %.1f ms, peak %.2f%% at %.0f ms\n', ...
        100 * b.rate0, 1000 * b.t_det, 1000 * b.t_cut, 100 * b.peak, 1000 * b.t_peak);
fprintf(fid, '  peak speed [%%] over detection-to-valve time [ms]\n  %-22s', 'J, Q0, tau');
fprintf(fid, ' %6g', 1000 * R.delays(1:4:end));
fprintf(fid, '\n');
for k = 1:size(R.map, 1)
    fprintf(fid, '  %.3f %6.1f %4.2f     ', R.map_rows(k, :));
    fprintf(fid, ' %6.1f', 100 * R.map(k, 1:4:end));
    fprintf(fid, '\n');
end
fclose(fid);
end

function write_losses_csv(file, R)
f = fieldnames(R.ops{1}.L);
fid = fopen(file, 'w');
fprintf(fid, 'case,f_T,T_in_C%s,L_mech,Q_oil,P_PT,eta\n', sprintf(',%s', f{:}));
for j = 1:numel(R.ops)
    o = R.ops{j};
    op = R.in14.ops(j);
    v = cellfun(@(x) o.L.(x), f);
    fprintf(fid, '%s,%g,%g%s,%.2f,%.2f,%.2f,%.6f\n', op.name, op.f_T, op.T_in, ...
            sprintf(',%.2f', v), o.L_mech, o.Q_oil, o.P_PT, o.eta);
end
fclose(fid);
end

function plot_losses(R, file)
% Stacked loss groups at each operating point
groups = {'Meshes', {'mesh_s1', 'mesh_sp', 'mesh_pr', 'mesh_gen', 'mesh_osg', 'mesh_pcu'};
          'Bearings', {'brg_inp', 'brg_mid', 'brg_prop', 'brg_planet', 'brg_acc'};
          'Windage', {'wind_pinion', 'wind_gear2', 'wind_planetary', 'wind_acc'};
          'Oil pumps', {'pumps'};
          'PCU and OSG', {'pcu_osg'}};
Y = zeros(numel(R.ops), size(groups, 1));
for j = 1:numel(R.ops)
    for g = 1:size(groups, 1)
        Y(j, g) = sum(cellfun(@(x) R.ops{j}.L.(x), groups{g, 2})) / 1e3;
    end
end
L_mech = cellfun(@(o) o.L_mech, R.ops) / 1e3;   % the first four groups; SYS-05 applies to it
fig = figure('Visible', 'off', 'Position', [100 100 960 480]);
bar(Y, 'stacked');
hold on
plot(1:numel(R.ops), L_mech, 'kv', 'MarkerFaceColor', 'k');
plot([0.5, numel(R.ops) + 0.5], [13.6 13.6], 'k--');
plot([0.5, numel(R.ops) + 0.5], [18 18], 'r--');
set(gca, 'XTick', 1:numel(R.ops), 'XTickLabel', {R.in14.ops.name});
ylim([0, 21]);
ylabel('Power loss (kW)');
legend([groups(:, 1); {'L_{mech}, RGB losses'; 'SYS-05 limit on L_{mech}, 13.6 kW'; ...
        'LUB-04 cooler duty, 18 kW'}], 'Location', 'eastoutside');
title('RGB losses (L_{mech}) and heat into the oil (bar top)');
grid on
print(fig, file, '-dpng', '-r150');
close(fig);
end

function plot_break(R, file)
fig = figure('Visible', 'off', 'Position', [100 100 1000 460]);
subplot(1, 2, 1);
plot(1000 * R.brk.t, 100 * R.brk.n / R.in.n_PT);
xlim([0, 800]);
xlabel('Time after the break (ms)');
ylabel('Power turbine speed (%)');
title({'Main case', sprintf('J %.3f kg m^2, Q_0 %.0f N m', R.in14.J_PT, R.ops{1}.T_PT), ...
       sprintf('delay %.0f ms, \\tau %.0f ms', 1000 * (R.in14.t_proc + R.in14.t_valve), 1000 * R.in14.tau_cut)});
grid on
subplot(1, 2, 2);
hold on
for k = 1:3                                 % J_PT and MC torque, the three decay times
    plot(1000 * R.delays, 100 * R.map(k, :), 'DisplayName', sprintf('\\tau %.0f ms', 1000 * R.map_rows(k, 3)));
end
xlabel('Detection to closed valve (ms)');
ylabel('Peak speed (%)');
title({'Peak speed', sprintf('J %.3f kg m^2, Q_0 %.0f N m', R.in14.J_PT, R.ops{1}.T_PT), ' '});
legend('Location', 'northwest');
grid on
print(fig, file, '-dpng', '-r150');
close(fig);
end

function last = run_tests(file)
% Runs test_step14, saves its output and returns its last line
txt = evalc('test_step14');
fid = fopen(file, 'w');
fprintf(fid, '%s', txt);
fclose(fid);
lines = strsplit(strtrim(txt), char(10));
last = strtrim(lines{end});
end
