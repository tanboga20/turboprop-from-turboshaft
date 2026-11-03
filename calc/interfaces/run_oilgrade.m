function R = run_oilgrade(out_csv)
%RUN_OILGRADE  Oil grade check behind Hamit's oil decision (Type II only).
%   R = run_oilgrade()          writes calc/interfaces/oil_grade_check.csv
%   R = run_oilgrade(out_csv)
%
%   Run from the repo root with calc/interfaces, calc/gear_detail,
%   calc/shafts_bearings, calc/lubrication, calc/agb_lube and calc/oil_system
%   on the path, after run_step32 (calc/results/step32/step32.mat). About
%   2 minutes. For MIL-PRF-23699 (Type II, data sheet) and MIL-PRF-7808
%   (Type I, grade 3 minimums, as in gd_inputs) at oil inlet 60, 100 and
%   132 degC:
%     - the ISO/TS 6336-20 scuffing safety S_S and the film ratio at the
%       pitch point of the three meshes (gd_scuffing at maximum continuous
%       torque, K_gamma P99 as step 2.4);
%     - the ISO 281 mission life L10m of every RGB bearing (run_step25
%       rerun through the step 3.3 if_override hook, bearing temperature =
%       inlet + 10 K as in step 2.5).
%   And the RGB oil inlet at maximum continuous power on a 53, -20 and
%   -40 degC sea-level day: the step 2.7 cooler core (UA and the cross-flow
%   effectiveness held constant, 0.72 kg/s air, oil flow of step 3.2) with
%   the step 2.7 heat into the oil (14.9 kW) and the LUB-04 duty (18 kW);
%   below 60 degC the thermostatic valve holds the inlet (it must modulate);
%   plus the ambient at which the inlet reaches 73 degC.
%   Phase 2 files and results are not changed; the reversal of step 2.4
%   Decision 2A is logged in requirements/changes_phase3.csv.
%   Output R: tables R.oil (oil, T_in, item, value) and R.cooler.
%   Source: Phase 3 report, Section 3.3 ("Oil grade").

if nargin < 1 || isempty(out_csv)
    out_csv = fullfile('calc', 'interfaces', 'oil_grade_check.csv');
end
gi = gd_inputs();
M = gd_meshes(gi);
ref = struct('KA', gi.KA, 'mode', 'ref', 'oil', gi.oil(1), 'ZNT10', gi.ZNT_ref, 'fpb_share', gi.fpb_share);
r0 = arrayfun(@(k) gd_rate(setfield(M(k), 'Kgam', 1), M(k).T1, M(k).n1, ref), 2:3);
ls = gd_loadshare(M(2), M(3), M(2).Ts, r0(1).c_ga * M(2).g.b, r0(2).c_ga * M(3).g.b, gi);
M(2).Kgam = ls.Kgam_p99;  M(3).Kgam = ls.Kgam_p99;
Xmp = [1 2 2];
T_in = [60 100 132];
tmp = tempname;
rows = {};
for oi = 1:2
    oil = gi.oil(oi);
    for T = T_in
        for k = 1:3
            o = ref;  o.oil = oil;
            r = gd_rate(M(k), M(k).T1, M(k).n1, o);
            s = gd_scuffing(M(k), r, M(k).n1, oil, T, Xmp(k), gi);
            rows(end + 1, :) = {oil.name, T, ['S_S ' M(k).name], s.S_S}; %#ok<AGROW>
            rows(end + 1, :) = {oil.name, T, ['lambda_C ' M(k).name], s.lambdaC}; %#ok<AGROW>
        end
        if_override('clear');
        ov = {'T_brg', [T + 10, 142]};
        if oi == 2, ov(end + 1, :) = {'oil', struct('nu40', oil.nu40, 'nu100', oil.nu100)}; end %#ok<AGROW>
        if_override('set', 'sb_inputs', ov);
        evalc('B = run_step25(tmp);');
        if_override('clear');
        for k = 1:numel(B.B)
            rows(end + 1, :) = {oil.name, T, ['L10m ' B.B(k).name], B.B(k).L10m}; %#ok<AGROW>
        end
        rows(end + 1, :) = {oil.name, T, 'L10m planet', B.PB.L10m}; %#ok<AGROW>
    end
end
if exist(tmp, 'dir'), rmdir(tmp, 's'); end
R.oil = cell2table(rows, 'VariableNames', {'oil', 'T_in', 'item', 'value'});

% cooler: the step 2.7 core at maximum continuous power
li = lb_inputs();
os = os_inputs();
st = load(fullfile('calc', 'results', 'step32', 'step32.mat'));
o = oil_props(115, li.oil);
m_oil = st.S.cool.Q0 / 6e4 * o.rho;                    % kg/s
Cc = lb_cooler(18e3, m_oil, li.v_face_design, li);
C_oil = m_oil * o.cp;  C_air = li.m_air * 1007;
Cmin = min(C_oil, C_air);  Cr = Cmin / max(C_oil, C_air);
N = Cc.UA / Cmin;
ep = 1 - exp(N^0.22 / Cr * (exp(-Cr * N^0.78) - 1));
crow = {};
for Q = [14.9e3 18e3]
    rise = Q / (ep * Cmin) - Q / C_oil;                % inlet (cooler outlet) above ambient [K]
    for Ta = [53 -20 -40]
        crow(end + 1, :) = {Q / 1e3, Ta, Ta + rise, max(Ta + rise, os.T_thermostat)}; %#ok<AGROW>
    end
    crow(end + 1, :) = {Q / 1e3, 73 - rise, 73, 73}; %#ok<AGROW>
end
R.cooler = cell2table(crow, 'VariableNames', {'Q_kW', 'T_amb', 'T_in_full_cooler', 'T_in'});
R.cooler_par = struct('UA', Cc.UA, 'C_oil', C_oil, 'C_air', C_air, 'eps', ep);

fid = fopen(out_csv, 'w');
fprintf(fid, 'kind,oil,T_C,item,value\n');   % T_C: oil inlet (grade rows) or ambient (cooler rows)
for i = 1:height(R.oil)
    fprintf(fid, 'grade,%s,%g,%s,%.6g\n', R.oil.oil{i}, R.oil.T_in(i), R.oil.item{i}, R.oil.value(i));
end
fprintf(fid, 'cooler,-,,UA W/K,%.6g\ncooler,-,,C_oil W/K,%.6g\ncooler,-,,C_air W/K,%.6g\ncooler,-,,eps,%.6g\n', ...
        Cc.UA, C_oil, C_air, ep);
for i = 1:height(R.cooler)
    c = R.cooler(i, :);
    if c.T_in_full_cooler == 73
        fprintf(fid, 'cooler,-,73,ambient for this inlet at %g kW,%.4g\n', c.Q_kW, c.T_amb);
    else
        fprintf(fid, 'cooler,-,%g,inlet with the whole cooler at %g kW,%.4g\n', c.T_amb, c.Q_kW, c.T_in_full_cooler);
        fprintf(fid, 'cooler,-,%g,inlet with the thermostat at %g kW,%.4g\n', c.T_amb, c.Q_kW, c.T_in);
    end
end
fclose(fid);
end
