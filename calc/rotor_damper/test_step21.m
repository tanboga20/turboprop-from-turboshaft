% TEST_STEP21  Compares the step 2.1 tool with calc/tests/step21_test_cases.csv.
%   Run from the repo root:  addpath('calc/rotor_damper');  test_step21
%   The expected values come from ROSS and closed forms (rotordynamics/step21_reference.py):
%   TC18 beam element, TC19 Campbell and TC20 unbalance of the Phase 1 model, TC21 shaft A on
%   housing supports, TC22 squeeze-film damping, TC23 squirrel cage. Same rule as steps 1.3
%   and 1.4: a value passes when the relative difference is at most 0.1%.

T = readtable('calc/tests/step21_test_cases.csv', 'TextType', 'string');
in = damper_inputs();
res = struct();

% TC18: simply supported 75/45 mm beam, 1.0 m, 40 elements; pinned ends by stiff springs
mat = struct('E', 205e9, 'nu', 0.29, 'rho', 7850);
ne = 40;
n = 2 * (ne + 1);
K = zeros(n);  M = zeros(n);
for k = 1:ne
    e = beam_timoshenko(1.0 / ne, 0.075, 0.045, mat);
    d = 2 * k - 1:2 * k + 2;
    K(d, d) = K(d, d) + e.K;
    M(d, d) = M(d, d) + e.Mt + e.Mr;
end
K(1, 1) = K(1, 1) + 1e15;
K(n - 1, n - 1) = K(n - 1, n - 1) + 1e15;
w = sort(sqrt(eig(K, M)));
res.TC18 = struct('f1', w(1) / (2 * pi), 'f2', w(2) / (2 * pi));

% TC19: Phase 1 model, bearings 1e8 N/m and 1e3 N s/m to ground, no flange
in1 = in;
in1.flange = [];
direct = @(k, c, an) support('direct', k, an * k, c, c);
cb = rotor_campbell(rotor_model(in1, [direct(1e8, 1e3, 1), direct(1e8, 1e3, 1)]), 0:50:3000, 6);
r = struct();
for j = 1:4
    r.(sprintf('f0_mode%d', j)) = cb.f(1, j);
    r.(sprintf('f1700_mode%d', j)) = cb.f(cb.rpm == 1700, j);
end
for kk = {'5e7', '1e8', '1e9'}
    c = rotor_campbell(rotor_model(in1, [direct(str2double(kk{1}), 1e3, 1), ...
                                         direct(str2double(kk{1}), 1e3, 1)]), 0:50:3000, 6);
    r.(['cross_k' kk{1}]) = min(c.cross(:, 2));
end
res.TC19 = r;

% TC20: unbalance response of the same model, G6.3 at the propeller
U = in.prop.m * in.G_bal / (in.n_prop * pi / 30);
sp = [1462 1700];
R = rotor_model(in1, [direct(1e8, 1e3, 1), direct(1e8, 1e3, 1)]);
ub = rotor_unbalance(R, sp, R.n_prop, U);
res.TC20.iso_1700 = ub.a_node(2) * 1e6;
R = rotor_model(in1, [direct(1e8, 1e3, 0.5), direct(1e8, 1e3, 0.5)]);
ub = rotor_unbalance(R, sp, R.n_prop, U);
res.TC20.aniso_1462 = ub.a_node(1) * 1e6;
res.TC20.aniso_1700 = ub.a_node(2) * 1e6;
R = rotor_model(in1, [direct(1e8, 3e4, 0.5), direct(1e8, 3e4, 0.5)]);
ub = rotor_unbalance(R, sp, R.n_prop, U);
res.TC20.aniso_c3e4_1462 = ub.a_node(1) * 1e6;

% TC21: shaft A 120/100 mm with the flange, bearings in series with housing seats 2e8 / 1e8 N/m
inA = in;
inA.shaft.d_o = 0.120;  inA.shaft.d_i = 0.100;  inA.shaft_over = [];
ch = @(k) 2 * in.c_h_ratio * sqrt(k * in.m_h);
s = support('chain', in.k_brg, in.m_j, in.k_rigid, 0, in.m_h, 2e8, 1e8, ch(2e8), ch(1e8));
R = rotor_model(inA, [s, s]);
cb = rotor_campbell(R, 1700, 4);
for j = 1:4
    res.TC21.(sprintf('f1700_mode%d', j)) = cb.f(1, j);
end
rpm = 100:2:1870;
ub = rotor_unbalance(R, rpm, R.n_prop, U);
res.TC21.a1700 = ub.a_node(rpm == 1700) * 1e6;
res.TC21.a_max = max(ub.a_node) * 1e6;
res.TC21.ratio = max(ub.a_node) / ub.a_node(rpm == 1700);

% TC22: squeeze-film land R 68 mm, L 40 mm, c 0.10 mm, 2.5 mPa s, sealed (x2)
res.TC22.C = sfd_coeffs(0.068, 0.040, 0.10e-3, 2.5e-3, 0, 2).C;

% TC23: squirrel cage, 24 bars 80 x 6 x 5 mm
sc = squirrel_cage(24, 0.080, 0.006, 0.005, 205e9);
res.TC23 = struct('k', sc.k, 's_per_m', sc.s_per_m);

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
    fprintf('%-5s %-18s %14.6g %14.6g %9.4f%%  %s\n', tc, q, v, e, 100 * (v / e - 1), verdict);
end
fprintf('%d values, %d failures, %d missing\n', height(T), nfail, nmiss);
