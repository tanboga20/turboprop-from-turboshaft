function S = run_step32(out_dir)
%RUN_STEP32  Step 3.2: oil system hardware and hydraulic network of the complete RGB.
%   S = run_step32()                  results in calc/results/step32, CATIA files in cad/params
%   S = run_step32(out_dir)
%
%   Run from the repo root with calc/oil_system, calc/assembly,
%   calc/lubrication, calc/agb_lube, calc/gear_detail, calc/shafts_bearings
%   and calc/accessory on the path, after step 3.1 (cad/assy/part_volumes.csv).
%   Builds the network on the step 3.1 layout, solves it at maximum
%   continuous power, ground idle and the -40 degC cold start, finds the
%   warm-up temperature and time, checks the pump inlet at 45,000 ft and at
%   -1.27 g, the run without oil (LUB-07) and writes the oil hardware for
%   CATIA (cad/params/oil_revolved.txt, oil_assembly.txt). Prints the jet
%   table and the results; draws the schematic, the jet pressures and the
%   cold start in Turkish and English; saves step32.mat and jets.csv.
%   Source: Phase 3 report, Section 3.2.

if nargin < 1 || isempty(out_dir)
    out_dir = fullfile('calc', 'results', 'step32');
end
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
in = os_inputs();
li = lb_inputs();
D = lb_design();
R = lb_losses(D, li.ops(1), 2392.6, li);               % step 2.7 design point (pump power included)
F = lb_flows(R.L, 4, li, R.oil);
ai = as_inputs();  gi = gd_inputs();  ad = ad_inputs();  sb = sb_inputs();
L = as_layout(ai, as_geom(ai, gi, ad, sb), gi, ad, sb);
N = os_network(in, L, F, li, R.oil);
Qp100 = 5.8 * 6200 * li.eta_vol / 1000;                % L/min, step 2.7 supply element at 100% speed
o100 = oil_props(100, li.oil);
Cc = lb_cooler(18e3, F.Q_need / 6e4 * o100.rho, li.v_face_design, li);
cool = struct('dp0', Cc.dp_oil / 1e3, 'Q0', F.Q_need, 'nu0', oil_props(100 + li.dT_oil / 2, li.oil).nu);

for k = 1:3
    op = in.ops(k);
    Sk = os_solve(in, N, li, op, os_oil(op.T, li), Qp100, cool);
    fprintf('\n== %s (pump %.0f%%, oil %g degC)\n', op.name, 100 * op.n, op.T);
    fprintf('manifold %.0f kPa, pump outlet %.0f kPa; pump %.1f, network %.1f, regulating valve %.1f, relief %.1f L/min\n', ...
            Sk.p_m, Sk.p_out, Sk.Q_pump, Sk.Q_net, Sk.Q_prv, Sk.Q_relief);
    fprintf('filter bypass %d, cooler loop %d; jets: lowest pressure %.0f kPa, flow ratio %.2f..%.2f\n', ...
            Sk.bypass_filter, Sk.loop, min(Sk.jets.p_jet), min(Sk.jets.Q ./ Sk.jets.Q_design), ...
            max(Sk.jets.Q ./ Sk.jets.Q_design));
    Sop(k) = Sk; %#ok<AGROW>
end
disp(Sop(1).jets);
writetable(Sop(1).jets, fullfile(out_dir, 'jets.csv'));
CS = os_coldstart(in, N, li, Qp100, cool);
fprintf('\n== Cold start: jets at %.0f%% of their flow from %.1f degC, warm-up about %.0f s at idle\n', ...
        100 * in.Q_ok, CS.T_ok, CS.t_ok);
I = os_inlet(in, li, Qp100);
fprintf('\n== Pump inlet: %.1f kPa abs at %g ft (margin %.1f), %.1f at -1.27 g, %.1f cold at sea level; negative g %.1f s\n', ...
        I.p_in, in.alt_ft, I.margin, I.p_in_negg, I.p_in_cold, I.t_negg);
vol = readtable(fullfile('cad', 'assy', 'part_volumes.csv'), 'TextType', 'string');
M = as_mass(ai, L, vol);
kg = @(p) M.parts.kg(strcmp(M.parts.part, p));
m_parts = sum(cellfun(kg, {'planet', 'planet_rollers', 'sun', 'ring', 'gear2', 'pinion', 'gen_gear'})) + ...
          sum(M.parts.kg(startsWith(M.parts.part, 'brg_')));
m_case = sum(cellfun(kg, {'case', 'fs_case', 'acc_cover', 'gen_cartridge', 'qj_housing'}));
W = os_lub07(in, li, D, m_parts, m_case);
fprintf('\n== Run without oil (LUB-07): cruise losses %.2f kW\n', W.P_cruise);
disp(W.t);  disp(W.res);
X = os_mist(in, li, D, m_parts, m_case);
fprintf('\n== Emergency air-oil mist (LUB-07, Hamit''s decision: at least 6 min at 75%% MCP; values TBR)\n');
disp(X.t);  disp(X.mass);
H = os_export(in, N, L, fullfile('cad', 'params'));
fprintf('oil hardware: %d parts, %d instances\n', numel(H.parts), size(H.inst, 1));
% values from steps 2.7 and 3.1 the Python reference takes as given (tested there)
fid = fopen(fullfile('cad', 'params', 'oil_network.txt'), 'a');
fprintf(fid, 'Qp100 = %.10g\ncool_dp0 = %.10g\ncool_Q0 = %.10g\ncool_nu0 = %.10g\nP_cruise = %.10g\n', ...
        Qp100, cool.dp0, cool.Q0, cool.nu0, W.P_cruise);
fprintf(fid, 'm_parts = %.10g\nm_case = %.10g\nQ_pcu = %.10g\nQ_leak = %.10g\n', m_parts, m_case, N.Q_pcu, N.Q_leak);
fprintf(fid, 'P_mist = %.10g %.10g\n', X.t.P_kW(1), X.t.P_kW(7));   % mesh + bearing losses: cruise, 75% MCP
Wm = os_lubmass(in, N, vol, li);
fprintf(fid, 'm_lub_hw = %.10g\nm_mist = %.10g\n', Wm.lub_hw, Wm.mist);   % SYS-06 lines of step 3.2
fclose(fid);
Mx = as_mass(ai, L, vol, struct('lub_hw', Wm.lub_hw, 'mist', Wm.mist));
fprintf('\n== Mass with the oil hardware (%.2f kg, replaces the 1.5 kg allowance) and the LUB-07 mist system (%.2f kg)\n', ...
        Wm.lub_hw, Wm.mist);
fprintf('modelled %.2f, allowances %.2f, total %.2f kg; SYS-06 margin %.2f against 110 kg (TBR), %.2f against 100 kg\n', ...
        Mx.modelled, Mx.allowances, Mx.total, Mx.margin_tbr, Mx.margin);
fprintf('input drive (SYS-11) %.2f kg, margin %.2f against %g kg (TBR); RGB + input drive %.2f kg\n', ...
        Mx.drive, Mx.margin_drive, ai.m_drive_limit, Mx.total_with_drive);
for lang = {'tr', 'en'}
    plot_jets(Sop, lang{1}, out_dir);
    plot_cold(CS, in, lang{1}, out_dir);
end
S = struct('N', N, 'ops', Sop, 'cold', CS, 'inlet', I, 'lub07', W, 'mist', X, 'lubmass', Wm, 'mass', Mx, 'hardware', H, 'Qp100', Qp100, 'cool', cool);
for lang = {'tr', 'en'}
    os_schematic(S, lang{1}, out_dir);
end
save(fullfile(out_dir, 'step32.mat'), 'S');
end

function plot_jets(Sop, lang, out_dir)
tr = strcmp(lang, 'tr');
J = Sop(1).jets;
fig = figure('Visible', 'off', 'Position', [100 100 1200 560]);
x = 1:height(J);
subplot(2, 1, 1);
bar(x, [Sop(1).jets.p_jet Sop(2).jets.p_jet], 'grouped');
yline(172, 'r--');
ylabel('kPa');
if tr
    legend({'azami sürekli güç', 'yer rölantisi', 'LUB-03 alt sınırı (normal çalışma)'}, 'Location', 'southoutside', 'NumColumns', 3);
    title('Her memenin önündeki basınç');
else
    legend({'maximum continuous', 'ground idle', 'LUB-03 floor (normal operation)'}, 'Location', 'southoutside', 'NumColumns', 3);
    title('Pressure ahead of each jet');
end
set(gca, 'XTick', x, 'XTickLabel', []);
subplot(2, 1, 2);
bar(x, J.Q ./ J.Q_design, 'FaceColor', [0.15 0.35 0.65]);
yline(1, 'k--');
set(gca, 'XTick', x, 'XTickLabel', J.jet, 'XTickLabelRotation', 60, 'FontSize', 7);
if tr
    ylabel('debi / tasarım debisi');
    title('Azami sürekli güçte meme debisi, 2.7 tasarım debisine oranla (en küçük meme 0,6 mm)');
else
    ylabel('flow / design flow');
    title('Jet flow at maximum continuous power over its step 2.7 design flow (smallest jet 0.6 mm)');
end
set(findall(fig, '-property', 'FontName'), 'FontName', 'Arial');
exportgraphics(fig, fullfile(out_dir, ['jets_' lang '.png']), 'Resolution', 150);
close(fig);
end

function plot_cold(CS, in, lang, out_dir)
tr = strcmp(lang, 'tr');
fig = figure('Visible', 'off', 'Position', [100 100 800 420]);
plot(CS.T, CS.ratio, 'o-', 'LineWidth', 1.5);
hold on;  grid on
yline(in.Q_ok, 'r--');
xline(CS.T_ok, 'k:');
if tr
    xlabel('yağ sıcaklığı [°C]');  ylabel('en düşük meme debisi / tasarım');
    title(sprintf('Yer rölantisinde soğuk ilk çalışma: memeler %.0f °C''den sonra beslenir (ısınma ~%.0f dk)', ...
                  CS.T_ok, CS.t_ok / 60));
else
    xlabel('oil temperature [°C]');  ylabel('lowest jet flow / design');
    title(sprintf('Cold start at ground idle: jets fed from %.0f °C (warm-up about %.0f min)', CS.T_ok, CS.t_ok / 60));
end
set(findall(fig, '-property', 'FontName'), 'FontName', 'Arial');
exportgraphics(fig, fullfile(out_dir, ['cold_' lang '.png']), 'Resolution', 150);
close(fig);
end
