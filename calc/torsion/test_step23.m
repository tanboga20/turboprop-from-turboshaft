% TEST_STEP23  Compares the step 2.3 tool with calc/tests/step23_test_cases.csv.
%   Run from the repo root:  addpath('calc/torsion', 'calc/rgb_sizing');  test_step23
%   Expected values come from an independent Python implementation
%   (calc/reference/step23_reference.py): its own model assembly and eigensolution, speed
%   ratios from gear kinematics, and a direct time integration (Radau) of the sudden stoppage
%   in place of the modal superposition used here. Same 0.1% rule as before.

T = readtable('calc/tests/step23_test_cases.csv', 'TextType', 'string');
in = torsion_inputs();
g = gear_data(in.design);
M = torsion_model(in, g);
md = torsion_modes(M, in, in.n_PT / g.i);
res = struct();

% TC30: natural frequencies of modes 1-6
for k = 1:6
    res.TC30.(sprintf('f%d', k)) = md.f(k);
end

% TC31: speed ratios in rigid rotation
r = M.ratio;
nm = M.names;
res.TC31 = struct('ratio_gear2', r(strcmp(nm, 'gear 2')), 'ratio_generator', r(strcmp(nm, 'generator')), ...
                  'ratio_carrier', r(strcmp(nm, 'carrier')), 'ratio_planet', r(strcmp(nm, 'planet 1')));

% TC32: sudden stoppage in 0.2 s
ss = sudden_stop(M, in, 0.2, in.n_PT);
res.TC32 = struct('peak_prop_shaft_0p2s', max(abs(ss.T_prop_shaft)), 'T_qs_0p2s', ss.T_qs);

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
