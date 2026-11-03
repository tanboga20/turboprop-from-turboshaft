% TEST_STEP24  Compares the step 2.4 tool with calc/tests/step24_test_cases.csv.
%   Run from the repo root:  addpath('calc/gear_detail');  test_step24
%   Expected values come from an independent Python implementation
%   (calc/reference/step24_reference.py): the root values from a numerical
%   simulation of the generating cut (hob rack and shaper cutter) instead of
%   the closed forms of ISO 6336-3; the planet load sharing from a full
%   static model with the planet degrees of freedom instead of the series
%   load path; the web modes from a Rayleigh-Ritz model with the rim and,
%   for the bare web, the exact Bessel-function solution; the remaining
%   factors re-coded from the standard. Same 0.1% rule as before.

T = readtable('calc/tests/step24_test_cases.csv', 'TextType', 'string');
in = gd_inputs();
M = gd_meshes(in);
res = struct();

% TC33: Method B tooth root values
G = {M(1).g.r1, M(1).g.r2, M(2).g.r2, M(2).g.r1, M(3).g.r2};
nm = {'pinion', 'gear2', 'sun', 'planet', 'ring'};
for i = 1:5
    r = G{i};
    res.TC33.([nm{i} '_sFn']) = r.s_Fn;
    res.TC33.([nm{i} '_rhoF']) = r.rho_F;
    res.TC33.([nm{i} '_hFe']) = r.h_Fe;
    res.TC33.([nm{i} '_YF']) = r.Y_F;
    res.TC33.([nm{i} '_YS']) = r.Y_S;
end

% TC34: geometry and contact factors
res.TC34 = struct('s1_a_w', M(1).g.a_w, 's1_eps_alpha', M(1).g.eps_alpha, 's1_eps_beta', M(1).g.eps_beta, ...
                  'sp_eps_alpha', M(2).g.eps_alpha, 'pr_eps_alpha', M(3).g.eps_alpha, ...
                  's1_Z_H', M(1).g.Z_H, 's1_Z_eps', M(1).g.Z_eps, 'sp_Z_eps', M(2).g.Z_eps, ...
                  'sp_Z_B', M(2).g.Z_B, 'sp_Z_D', M(2).g.Z_D, 'pr_Z_B', M(3).g.Z_B);

% TC35, TC36: K factors and safety factors at MCT and in the static case, K_gamma 1.30 on the planetary meshes
ref = struct('KA', 1.25, 'mode', 'ref', 'oil', in.oil(1), 'ZNT10', 0.85, 'fpb_share', 0.5);
st = struct('KA', 1.0, 'mode', 'static', 'oil', in.oil(1), 'ZNT10', 0.85, 'fpb_share', 0.5);
mk = {'s1', 'sp', 'pr'};
for k = 1:3
    m = M(k);
    if k > 1, m.Kgam = 1.30; end
    r = gd_rate(m, m.T1, m.n1, ref);
    res.TC35.([mk{k} '_c_prime']) = r.c_prime;
    res.TC35.([mk{k} '_c_ga']) = r.c_ga;
    res.TC35.([mk{k} '_Kv']) = r.Kv;
    res.TC35.([mk{k} '_KHb']) = r.KHb;
    res.TC35.([mk{k} '_KFb']) = r.KFb;
    res.TC36.([mk{k} '_S_H1']) = r.S_H1;
    res.TC36.([mk{k} '_S_H2']) = r.S_H2;
    res.TC36.([mk{k} '_S_F1']) = r.S_F1;
    res.TC36.([mk{k} '_S_F2']) = r.S_F2;
    rs = gd_rate(m, in.K_over * m.T1, m.n1, st);
    res.TC36.([mk{k} '_static_S_H1']) = rs.S_H1;
    res.TC36.([mk{k} '_static_S_F1']) = rs.S_F1;
    res.TC36.([mk{k} '_static_S_F2']) = rs.S_F2;
    if k <= 2
        sc = gd_scuffing(m, r, m.n1, in.oil(1), 132, [1 2 2] * (k == (1:3))', in);
        res.TC38.([mk{k} '_theta_fl_max']) = max(sc.theta_fl);
        res.TC38.([mk{k} '_theta_M']) = sc.theta_M;
        res.TC38.([mk{k} '_S_S']) = sc.S_S;
        res.TC38.([mk{k} '_lambda_C']) = sc.lambdaC;
    end
end

% TC37: load sharing, given mesh stiffness and path errors at MCT
E1 = [0.010; -0.005; 0.003; -0.008];
a = gd_loadshare(M(2), M(3), M(2).Ts, 1200, 1400, in, E1);
b = gd_loadshare(M(2), M(3), M(2).Ts, 1200, 1400, in, 0.012 * [1; -1; 1; -1]);
c = gd_loadshare(M(2), M(3), 0.3 * M(2).Ts, 1200, 1400, in, 0.004 * [1; -1; 1; -1]);
res.TC37 = struct('Kgam_E1', a.Kgam, 'Kgam_alt12', b.Kgam, 'Kgam_alt4_30pct', c.Kgam, 'float_E1_um', 1000 * a.float);

% TC39: modes
pr = struct('R', 125.5, 'h', 8, 'b', 60, 'h_teeth', 2.25, 'E', 206e3, 'rho', 7.83e-6);
fr = gd_modes('ring', pr, [3 5 6]);
res.TC39 = struct('ring_n3', fr(1), 'ring_n5', fr(2), 'ring_n6', fr(3));
pw = struct('r_in', 35, 'r_out', 104, 't', 8, 'b_rim', 52, 's_rim', 7, 's_mass', 9.25, ...
            'E', 206e3, 'nu', 0.3, 'rho', 7.83e-6, 'ne', 40);
fw = gd_modes('web', pw, 0:4);
for n = 0:4
    res.TC39.(sprintf('web_n%d', n)) = fw(n + 1, 1);
end
pw.bare = true;
fb = gd_modes('web', pw, 0:3);
for n = 0:3
    res.TC39.(sprintf('bare_n%d', n)) = fb(n + 1, 1);
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
