% TEST_STEP35  Compares the step 3.5 results with calc/tests/step35_test_cases.csv.
%   Run from the repo root after run_step35 (it writes calc/results/step35/step35.mat):
%     addpath('calc/structures');  test_step35
%   Expected values come from an independent Python implementation
%   (calc/reference/step35_reference.py) of the closed forms: propeller bearing
%   reactions, the Lame shrink fits of the seat liners and the planet pins,
%   VDI 2230 for the flange and the mount ring, the mass closure lines and
%   the NU1024 liner fix.
%   The finite element models are checked by their mass against the CATIA
%   volumes (step 3.1 roll-up) and by the mesh convergence of the case.

T = readtable('calc/tests/step35_test_cases.csv', 'TextType', 'string');
X = load(fullfile('calc', 'results', 'step35', 'step35.mat'));
S = X.S;
L = S.L;
res = struct();
res.TC85 = struct('R_in', L.R_in, 'R_out', L.R_out, 'W1_out', L.W1(2), 'P1_in', L.P1(1), 'T_ring_lim', L.T_ring_lim);
Ln = S.liners.T;
for k = [1 4]
    b = char(Ln.bearing(k));
    res.TC86.(['d20_' b]) = Ln.d20_um(k);
    res.TC86.(['p_cold_' b]) = Ln.p__40C_MPa(k);
    res.TC86.(['p_hot_' b]) = Ln.p_149C_MPa(k);
    res.TC86.(['vm_cold_' b]) = Ln.sig_vm_cold(k);
    res.TC86.(['n_cold_' b]) = Ln.n_cold(k);
end
B = S.bolts;
for f = {'F_Mzul', 'M_A', 'F_Mmin', 'delta_S', 'delta_P', 'Phi_n', 'F_Z', 'dF_cold', 'dF_hot', 'F_A', 'F_Q', 'F_KRmin', ...
         'S_F', 'S_D', 'S_p', 'S_G', 'S_strip', 'F_dowel', 'S_dowel', 'S_dowel_bearing'}
    res.TC87.(f{1}) = B.(f{1});
end
for sz = {'M8', 'M10'}
    Bm = S.mount.(sz{1});
    res.TC88.(['F_A_' sz{1}]) = Bm.F_A;
    res.TC88.(['F_Mmin_' sz{1}]) = Bm.F_Mmin;
    res.TC88.(['F_KRmin_' sz{1}]) = Bm.F_KRmin;
    res.TC88.(['S_G_' sz{1}]) = Bm.S_G;
end
C = S.carrier;
res.TC89 = struct('p', C.press.p, 'hoop', C.press.sig_hoop, 'n_y', C.press.n_y);
Mc = S.mass;
res.TC90 = struct('a', Mc.lines.kg(1), 'b', Mc.lines.kg(2), 'c', Mc.lines.kg(3), 'd', Mc.lines.kg(4), 'e', Mc.lines.kg(5), ...
                  'f', Mc.lines.kg(6), 'pkg_A', Mc.pkg.total_kg(1), 'pkg_B', Mc.pkg.total_kg(2));
res.TC91 = struct('m_case', S.case.m, 'm_carrier', C.m, 'm_fscase', S.fscase_mount.m);
X = S.liner_fix;
res.TC92 = struct('r_boss', X.r_boss, 'dm_kg', X.dm_kg, 'T_hold', X.T_hold, 'n_now', X.n_now);

nfail = 0;
nmiss = 0;
for i = 1:height(T)
    tc = char(T.tc(i));
    q = matlab.lang.makeValidName(char(T.quantity(i)));
    if ~isfield(res, tc) || ~isfield(res.(tc), q) || isempty(res.(tc).(q))
        fprintf('MISSING %s %s\n', tc, q);
        nmiss = nmiss + 1;
        continue
    end
    v = res.(tc).(q);
    e = T.expected(i);
    ok = abs(v / e - 1) <= T.tol(i);
    verdict = 'PASS';
    if ~ok
        nfail = nfail + 1;
        verdict = 'FAIL';
    end
    fprintf('%-5s %-22s %14.6g %14.6g (tol %.1f%%)  %s\n', tc, q, v, e, 100 * T.tol(i), verdict);
end
fprintf('%d values, %d failures, %d missing\n', height(T), nfail, nmiss);
