% TEST_STEP14  Compares the step 1.4 tool with calc/tests/step14_test_cases.csv.
%   Run from the repo root:  addpath('calc/rgb_sizing', 'calc/agb_lube');  test_step14
%   Covers TC10-TC17; a TC missing from res would be skipped. TC10-TC13, TC15
%   and TC16 have their inputs here; TC14 and TC17 use the baseline inputs of
%   rgb_inputs.m and lube_inputs.m, with which the expected values were computed.

T = readtable('calc/tests/step14_test_cases.csv', 'TextType', 'string');
in = rgb_inputs();
in14 = lube_inputs();
res = struct();

% TC10: oil properties at 40, 100 and 132 degC
for Tc = [40 100 132]
    o = oil_props(Tc, in14.oil);
    res.TC10.(sprintf('nu_%d', Tc)) = o.nu;
    res.TC10.(sprintf('rho_%d', Tc)) = o.rho;
    res.TC10.(sprintf('eta_%d', Tc)) = o.eta;
end
res.TC10.A = o.A;
res.TC10.B = o.B;
eta115 = oil_props(115, in14.oil).eta;

% TC11: helical external mesh 31/110, mn 2, beta 15, b 52; 388.5 N m at 22,000 rpm, oil at 115 degC
g = gear_geometry(31, 110, 2, 15, 52, false, 20);
res.TC11 = mesh_loss(g, 388.5, 22000, eta115, 0.3, 1.0);

% TC12: internal spur mesh planet 37 / ring 119, m 2, b 60; 200 N m at 5,000 rpm
g = gear_geometry(37, 119, 2, 0, 60, true, 20);
res.TC12 = mesh_loss(g, 200, 5000, eta115, 0.3, 1.0);

% TC13: windage of a 230 mm gear at 6,200 rpm and a 64 mm pinion at 22,000 rpm (b 52 mm,
% mist 0.023 cP); bearing friction at d_m 62 mm, 22,000 rpm, 3.9 cSt, 7 kN and in the
% low-speed branch (d_m 50 mm, 100 rpm, 5 cSt, 1 kN), f0 3, f1 0.0003
res.TC13.P_wind_gear = windage_loss(230, 52, 6200, 0.023);
res.TC13.P_wind_pinion = windage_loss(64, 52, 22000, 0.023);
b = bearing_loss(62, 22000, 3.9, 7000, 3, 0.0003);
res.TC13.M0 = b.M0;
res.TC13.M1 = b.M1;
res.TC13.P_brg = b.P;
b = bearing_loss(50, 100, 5, 1000, 3, 0.0003);
res.TC13.M0_low = b.M0;
res.TC13.P_brg_low = b.P;

% TC14: accessory pads of the selected design, oil pump torque 3.5 N m
d = in14.design;
t = tooth_set_check(d(1), d(2), d(3), d(4), d(5), in);
L = rgb_layout(t, size_stage1(t.z1, t.z2, in), size_stage2(t, in), in);
A = accessory_pads(L, in, in14, 3.5);
res.TC14 = struct('gen_n', A.gen.n, 'gen_ratio', A.gen.ratio, 'gen_b', A.gen.b, ...
                  'gen_S_H', A.gen.r.S_H, 'gen_S_F', min(A.gen.r.S_F1, A.gen.r.S_F2), ...
                  'gen_S_H_fatigue', A.gen.rf.S_H, 'gen_S_F_static', min(A.gen.rs.S_F1, A.gen.rs.S_F2), ...
                  'gen_d_shear', A.gen.d_shear, 'gen_T_shear', A.gen.T_shear, ...
                  'osg_n', A.osg.n, 'osg_T_shear', A.osg.T_shear, 'osg_S_H_static', A.osg.rs.S_H, ...
                  'pcu_z2', A.pcu.z2, 'pcu_n', A.pcu.n, 'pump_d_shear', A.pump.d_shear, ...
                  'mass_total', A.mass.total);

% TC15: oil system for 14 kW at a 6,200 rpm pump speed
res.TC15 = lube_sizing(14000, 6200, in14);

% TC16: shaft break. 0.084 kg m^2, 417.3 N m, 25 ms, tau 0.10 s; 0.060 kg m^2, 534 N m, 40 ms, tau 0.05 s
r = shaft_break(0.084, 417.3, 22000, 0.025, 0.10, in14);
res.TC16 = struct('peak', r.peak, 't_peak', r.t_peak, 't_det', r.t_det, 'T_time', r.T_time);
r = shaft_break(0.060, 534, 22000, 0.040, 0.05, in14);
res.TC16.peak_low_J = r.peak;
res.TC16.t_det_low_J = r.t_det;

% TC17: losses of the selected design at maximum continuous power, pumps 2,000 W
R = rgb_losses(L, A, in14.ops(1), 2000, in, in14);
res.TC17 = struct('mesh_s1', R.L.mesh_s1, 'mesh_sp', R.L.mesh_sp, 'mesh_pr', R.L.mesh_pr, ...
                  'brg_inp', R.L.brg_inp, 'brg_planet', R.L.brg_planet, 'wind_gear2', R.L.wind_gear2, ...
                  'pcu_osg', R.L.pcu_osg, 'L_mech', R.L_mech, 'Q_oil', R.Q_oil, 'P_PT', R.P_PT, 'eta', R.eta);

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
    if strcmp(char(T.unit(k)), 'count')
        ok = (got == ref);
    else
        ok = abs(got - ref) <= 1e-3 * abs(ref);
    end
    fprintf('%-5s %-21s %12.6g %12.6g  %s\n', tc, q, got, ref, tags{ok + 1});
    nfail = nfail + ~ok;
end
fprintf('%d values, %d failures\n', nrun, nfail);
