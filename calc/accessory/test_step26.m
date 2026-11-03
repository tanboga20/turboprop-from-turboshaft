% TEST_STEP26  Compares the step 2.6 tool with calc/tests/step26_test_cases.csv.
%   Run from the repo root:
%     addpath('calc/accessory', 'calc/gear_detail', 'calc/shafts_bearings');  test_step26
%   Expected values come from an independent Python implementation
%   (calc/reference/step26_reference.py), built on the step 2.4 and 2.5
%   references: the accessory gear ratings, the shear necks, the deep
%   groove ball bearing life and the PCU gear blank modes. Same 0.1% rule.

T = readtable('calc/tests/step26_test_cases.csv', 'TextType', 'string');
in = ad_inputs();
gi = gd_inputs();
A = ad_meshes(in, gi);
res = struct();

% TC45: accessory gear pairs at the STR-01 load
opt = struct('KA', in.KA, 'mode', 'ref', 'oil', gi.oil(1), 'ZNT10', gi.ZNT_ref, 'fpb_share', gi.fpb_share);
nm = {'gen', 'osg', 'pcu'};
for k = 1:3
    r = gd_rate(A(k), A(k).T1, A(k).n1, opt);
    for q = {'Kv', 'KHb', 'S_H1', 'S_H2', 'S_F1', 'S_F2'}
        res.TC45.([nm{k} '_' q{1}]) = r.(q{1});
    end
end

% TC46: shear necks
T46 = struct('gen', in.T_gen_max, 'osg', in.T_osg);
for c = {'gen', 'osg'}
    s = ad_neck(T46.(c{1}), in);
    for q = {'d', 'T_nom', 'T_lo', 'T_hi', 'n_f'}
        res.TC46.([c{1} '_' q{1}]) = s.(q{1});
    end
end

% TC47: deep groove ball bearing life
b = struct('type', 'DGBB', 'Z', 8, 'Dw', 11.0, 'Lwe', 0, 'Dpw', 43.5, 'alpha', 0, 'i', 1);
r = sb_rating(b, 1.3);
res.TC47 = struct('C', r.C, 'C0', r.C0);
n_gen = A(1).n1;
cases = {'gen', 477.3, 190.0; 'radial', 2000, 100; 'axial', 0, 1500};
for k = 1:3
    L = sb_life(b, r, 1, cases{k, 2}, cases{k, 3}, n_gen, 4.23, 0.6);
    res.TC47.([cases{k, 1} '_P']) = L.P;
    res.TC47.([cases{k, 1} '_a']) = L.a_ISO;
    res.TC47.([cases{k, 1} '_L10m']) = L.L10m_mission;
end

% TC48: PCU gear blank modes
g = A(3).g;
pw = struct('r_in', in.pcu.hub_d / 2, 'r_out', g.df2 / 2 - 3.5 * g.mn, 't', g.b, 'b_rim', g.b, 's_rim', 3.5 * g.mn, ...
            's_mass', 3.5 * g.mn + 0.5 * g.h2, 'E', gi.mat.Eh.E, 'nu', 0.3, 'rho', gi.rho_steel, 'ne', 40);
fw = gd_modes('web', pw, 0:3);
for n = 0:3
    res.TC48.(sprintf('pcu_web_n%d', n)) = fw(n + 1, 1);
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
