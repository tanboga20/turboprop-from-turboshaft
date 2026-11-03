% TEST_STEP25  Compares the step 2.5 tool with calc/tests/step25_test_cases.csv.
%   Run from the repo root:  addpath('calc/shafts_bearings');  test_step25
%   Expected values come from an independent Python implementation
%   (calc/reference/step25_reference.py) of the bearing ratings and lives,
%   the shaft and spline checks and the planet rim model. Every case gives
%   the functions fixed inputs, so the cases do not depend on the gear
%   model. Same 0.1% rule as before.

T = readtable('calc/tests/step25_test_cases.csv', 'TextType', 'string');
in = sb_inputs();
res = struct();

% TC40: ratings
mk = @(type, Z, Dw, Lwe, Dpw, alpha, i) struct('type', type, 'Z', Z, 'Dw', Dw, 'Lwe', Lwe, 'Dpw', Dpw, ...
                                               'alpha', alpha, 'i', i);
brg = struct('crb1', mk('CRB', 14, 11, 16, 65, 0, 1), 'crb2', mk('CRB', 26, 15, 16, 150, 0, 1), ...
             'planet', mk('CRB', 18, 7.5, 56, 45.5, 0, 1), 'qj1', mk('QJ', 13, 12.7, 0, 65, 35, 2), ...
             'qj2', mk('QJ', 21, 19.05, 0, 150, 35, 2));
nm = fieldnames(brg);
for k = 1:numel(nm)
    b = brg.(nm{k});
    r = sb_rating(b, in.b_m.(b.type));
    R.(nm{k}) = r;
    res.TC40.([nm{k} '_C']) = r.C;
    res.TC40.([nm{k} '_C0']) = r.C0;
    res.TC40.([nm{k} '_Cu']) = r.Cu;
end
res.TC40.qj1_f0 = R.qj1.f_0;

% TC41: lives over the mission
t = in.mission(:, 1);
L = sb_life(brg.planet, R.planet, t, [19000 10000 7000], [0 0 0], 5471, 4.23, 0.6);
res.TC41 = struct('planet_kappa', L.kappa, 'planet_a1', L.a_ISO(1), 'planet_a2', L.a_ISO(2), ...
                  'planet_a3', L.a_ISO(3), 'planet_L10', L.L10_mission, 'planet_L10m', L.L10m_mission);
L = sb_life(brg.qj1, R.qj1, t, [0 0 0], [3500 1800 1100], 22000, 4.23, 0.6);
res.TC41.qj1ax_P1 = L.P(1);
res.TC41.qj1ax_a1 = L.a_ISO(1);
res.TC41.qj1ax_L10m = L.L10m_mission;
L = sb_life(brg.qj1, R.qj1, t, [2000 2000 2000], [1000 3000 500], 22000, 4.23, 0.6);
for j = 1:3
    res.TC41.(sprintf('qj1mix_P%d', j)) = L.P(j);
end
res.TC41.qj1mix_L10m = L.L10m_mission;
L = sb_life(brg.qj2, R.qj2, t, [0 0 0], [18000 3000 2000], 1701, 2.0, 0.6);
res.TC41.qj2_kappa = L.kappa;
res.TC41.qj2_a1 = L.a_ISO(1);
res.TC41.qj2_a2 = L.a_ISO(2);
res.TC41.qj2_L10m = L.L10m_mission;
L = sb_life(brg.crb2, R.crb2, t, [20000 20000 20000], [0 0 0], 800, 4.23, 0.6);
res.TC41.crb2slow_kappa = L.kappa;
res.TC41.crb2slow_a1 = L.a_ISO(1);
res.TC41.crb2slow_L10m = L.L10m_mission;

% TC42: shaft sections
s = sb_shaft(50, 30, 2000, 0, 3243, 6891, 0, 4600, in);
res.TC42 = struct('s50_S_e', s.S_e, 's50_n_f', s.n_f, 's50_n_y', s.n_y, 's50_n_u', s.n_u);
s = sb_shaft(120, 100, 30600, 2470, 18000, 23754, 8360, 20000, in);
res.TC42.s120_S_e = s.S_e;
res.TC42.s120_n_f = s.n_f;
res.TC42.s120_n_y = s.n_y;
res.TC42.s120_n_u = s.n_u;

% TC43: splines
sp = struct('fixed', struct('m', 1.5, 'z', 30, 'L', 40, 'Km', 1.3, 'crowned', false), ...
            'crowned', struct('m', 1.5, 'z', 30, 'L', 56, 'Km', 1.5, 'crowned', true));
for c = {'fixed', 'crowned'}
    s = sb_spline(sp.(c{1}), 1378.6, 1.25, 6891, 30, in);
    for q = {'tau', 'p', 'tau_root', 'S_fat', 'S_static', 'p_ratio'}
        res.TC43.([c{1} '_' q{1}]) = s.(q{1});
    end
end

% TC44: planet rim modes
p = struct('R', 30.5, 'h', 8, 'b', 70, 'h_teeth', 2.25, 'E', 206e3, 'rho', 7.83e-6, 'Z', 0, 'Dw', 7.5, ...
           'Lwe', 56, 'F', 19091, 'nel', 144, 'k_mesh', 0, 'alpha', deg2rad(20));
f = sb_planet_rim(p, 3);
res.TC44 = struct('free_f1', f(1), 'free_f3', f(3));
p.Z = 18;
f = sb_planet_rim(p, 3);
for j = 1:3
    res.TC44.(sprintf('rollers_f%d', j)) = f(j);
end
p.k_mesh = 1.41e9;
f = sb_planet_rim(p, 3);
for j = 1:3
    res.TC44.(sprintf('mesh_f%d', j)) = f(j);
end

% Compare
nfail = 0;
nmiss = 0;
for i = 1:height(T)
    tc = char(T.tc(i));
    q = char(T.quantity(i));
    if ~isfield(res, tc) || ~isfield(res.(tc), q)
        fprintf('MISSING %s %s\n', tc, q);
        nmiss = nmiss + 1;
        continue
    end
    v = res.(tc).(q);
    e = T.expected(i);
    ok = abs(v / e - 1) <= 1e-3;
    verdict = 'PASS';
    if ~ok
        nfail = nfail + 1;
        verdict = 'FAIL';
    end
    fprintf('%-5s %-22s %14.6g %14.6g %9.4f%%  %s\n', tc, q, v, e, 100 * (v / e - 1), verdict);
end
fprintf('%d values, %d failures, %d missing\n', height(T), nfail, nmiss);
