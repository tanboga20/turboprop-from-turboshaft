% TEST_RGB_SIZING  Compares the step 1.3 tool with calc/tests/step13_test_cases.csv.
%   Run from the repo root:  addpath('calc/rgb_sizing');  test_rgb_sizing
%   Covers TC1-TC9, all 109 values of the CSV; a TC missing from res would be skipped.

T = readtable('calc/tests/step13_test_cases.csv', 'TextType', 'string');

% TC1-TC3 use fixed factors: changing an assumption in rgb_inputs.m does not change them.
f = struct('KA', 1.1, 'Kv', 1.1, 'KHb', 1.15, 'KHa', 1.0, 'Kgam', 1.0, ...
           'ZNT', 0.85, 'YNT', 0.85, 'ZLvR', 0.95, 'ZE', 189.8, ...
           'sHlim1', 1500, 'sFlim1', 500, 'sHlim2', 1500, 'sFlim2', 500, ...
           'YM1', 1.0, 'YM2', 1.0);
% joins g and r into one struct (they must not share a field name)
merge2 = @(g, r) cell2struct([struct2cell(g); struct2cell(r)], [fieldnames(g); fieldnames(r)], 1);
res = struct();

% TC1: spur external pair
g = gear_geometry(30, 90, 3, 0, 70, false, 20);
res.TC1 = merge2(g, iso6336_lite(g, 400, 10000, f));

% TC2: helical external pair and static check (x1.375, ZNT 1.6, YNT 2.5)
g = gear_geometry(31, 94, 2.5, 15, 60, false, 20);
res.TC2 = merge2(g, iso6336_lite(g, 388.5, 22000, f));
fs = f;  fs.ZNT = 1.6;  fs.YNT = 2.5;
rs = iso6336_lite(g, 1.375*388.5, 22000, fs);
res.TC2.S_H_static = rs.S_H;
res.TC2.S_F1_static = rs.S_F1;

% TC3: internal pair (planet 32, ring 92), nitrided ring
g = gear_geometry(32, 92, 3, 0, 60, true, 20);
f3 = f;  f3.sHlim2 = 1250;  f3.sFlim2 = 420;
r = iso6336_lite(g, 200, 5000, f3);
res.TC3 = merge2(g, r);
res.TC3.S_H_ring = r.S_H2;
res.TC3.sigma_F2_ring = r.sigma_F2;
res.TC3.S_F2_ring = r.S_F2;

% TC4-TC9 use the baseline inputs of rgb_inputs.m, with which the expected values were computed.
in = rgb_inputs();

% TC4a, TC4b: tooth-count rules, 31/94 with 28/32/92, N = 5 and N = 4; post gap at m = 3 mm
res.TC4a = tooth_set_check(31, 94, 28, 32, 5, in);
res.TC4a.gap_at_m3 = 3 * res.TC4a.gap;
res.TC4b = tooth_set_check(31, 94, 28, 32, 4, in);
res.TC4b.gap_at_m3 = 3 * res.TC4b.gap;

% TC4c: number of valid sets per planet count in the full search
S = tooth_sets(in);
res.TC4c = struct('n_sets_N3', sum([S.N] == 3), 'n_sets_N4', sum([S.N] == 4), ...
                  'n_sets_N5', sum([S.N] == 5));

% TC5: planetary stage 30/36/102, N 4, m 2.5, b 60, Ts 1200 N m, ns 7000 rpm; K_gamma (1.10)
% and K_A (1.1) are fixed here, so that the test does not change with those assumptions
in5 = in;
in5.Kgam(in5.N_list == 4) = 1.10;
in5.f.KA = 1.1;
s = planet_stage(30, 36, 102, 4, 2.5, 60, 1200, 7000, in5);
res.TC5 = s;
res.TC5.D_or = s.brg.D_or;
res.TC5.D_w = s.brg.D_w;
res.TC5.Z = s.brg.Z;
res.TC5.L_w = s.brg.L_w;
res.TC5.C = s.brg.C / 1e3;                  % kN
res.TC5.C0 = s.brg.C0 / 1e3;                % kN
res.TC5.F_gear = s.brg.F_gear / 1e3;        % kN
res.TC5.F_c = s.brg.F_c / 1e3;              % kN
res.TC5.L10_100 = s.brg.L10_100;
res.TC5.L10_mission = s.brg.L10_mission;
res.TC5.s0 = s.brg.s0;

% TC6: shaft d_o 80, d_i 48 mm; T 5,000 N m, M_alt 2,000 N m, F_a 20 kN; limit T 6,875 N m, M 7,500 N m, F_a 20 kN
res.TC6 = shaft_check(80, 48, 5000, 2000, 20e3, 6875, 7500, 20e3, in);

% TC7: main bearings. A-05 mission with P100 = 10 kN at 7,000 rpm (load follows the torque),
% QJ under combined load, radially free QJ under the thrust spectrum at 1,700 rpm
F = [in.mission(:, 1), 10e3 * in.mission(:, 2), zeros(3, 1)];      % [time share, F_r, F_a]
br = bearing_req('roller', F, 7000, 0, 0, in);
res.TC7.P_eq_roller = br.P_eq / 1e3;        % kN
res.TC7.C_req_roller = br.C_req / 1e3;
br = bearing_req('ball', F, 7000, 0, 0, in);
res.TC7.P_eq_ball = br.P_eq / 1e3;
br = bearing_req('QJ', [1, 8e3, 18e3], 1700, 0, 0, in);
res.TC7.P_QJ_Fr8_Fa18 = br.P / 1e3;
br = bearing_req('QJ', [1, 8e3, 3e3], 1700, 0, 0, in);
res.TC7.P_QJ_Fr8_Fa3 = br.P / 1e3;
th = in.thrust_spectrum;
br = bearing_req('QJ', [th(:, 1), zeros(3, 1), th(:, 2)], 1700, 0, 0, in);
res.TC7.P_eq_QJ_thrust = br.P_eq / 1e3;
res.TC7.C_req_QJ_1700rpm = br.C_req / 1e3;

% TC8: overhung propeller d_o 80, d_i 48, L_p 300, a 250 mm, 76.4 kg;
% simply supported d_o 40, d_i 24, L 100 mm, 1.0 kg disc
res.TC8.n_cr_overhung = critical_speed('overhung', 80, 48, 300, 76.4, 250, in);
res.TC8.n_cr_simply_supported = critical_speed('simply_supported', 40, 24, 100, 1.0, [], in);

% TC9: mass formulas. Ring d_r 240, m 2.5, b 60; carrier d_s 75, d_p 82.5, d_pin 45, N 4, b 60;
% housing a 150, D_z 270, L_g 420; bearing of 60 mm bore
res.TC9.m_ring = rgb_mass('ring', in, 240, 2.5, 60);
res.TC9.m_carrier = rgb_mass('carrier', in, 75, 82.5, 45, 4, 60);
res.TC9.m_housing = rgb_mass('housing', in, 150, 270, 420);
res.TC9.m_bearing_bore60 = rgb_mass('bearing', in, 60, 1);

% Comparison: 0.1% relative, counts exact
tags = {'FAIL', 'OK'};
nrun = 0;  nfail = 0;
for k = 1:height(T)
    tc = char(T.tc(k));  q = char(T.quantity(k));  ref = T.expected(k);
    if ~isfield(res, tc), continue, end        % TC not in res: skipped
    nrun = nrun + 1;
    if ~isfield(res.(tc), q)
        fprintf('%-5s %-21s %12s %12.6g  MISSING\n', tc, q, '-', ref);
        nfail = nfail + 1;
        continue
    end
    got = double(res.(tc).(q));
    if strcmp(char(T.unit(k)), 'count') || any(strcmp(q, {'Z', 'assembly_ok'}))
        ok = (got == ref);
    else
        ok = abs(got - ref) <= 1e-3 * abs(ref);
    end
    fprintf('%-5s %-21s %12.6g %12.6g  %s\n', tc, q, got, ref, tags{ok + 1});
    nfail = nfail + ~ok;
end
fprintf('%d values, %d failures\n', nrun, nfail);
