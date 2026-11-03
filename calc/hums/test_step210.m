% TEST_STEP210  Checks the step 2.10 fault frequencies against calc/tests/step210_test_cases.csv.
%   Run from the repo root:
%     addpath('calc/hums', 'calc/gear_detail', 'calc/shafts_bearings', 'calc/accessory');  test_step210
%   The expected values come from calc/reference/step210_reference.py, which re-codes the
%   kinematics and the bearing formulas from the design data; every row to 0.1%.

T = readtable('calc/tests/step210_test_cases.csv', 'TextType', 'string');
F = hm_frequencies(gd_inputs(), sb_inputs(), ad_inputs(), 1);
res = struct();
for i = 1:numel(F.shaft), res.(sprintf('shaft%d_Hz', i)) = F.shaft(i).Hz; end
for i = 1:numel(F.mesh), res.(sprintf('mesh%d_Hz', i)) = F.mesh(i).Hz; end
for i = 1:numel(F.gearfault), res.(sprintf('gearfault%d_Hz', i)) = F.gearfault(i).Hz; end
kinds = {'cage', 'inner', 'outer', 'spin'};
for j = 1:numel(F.bearing)
    for q = 1:4
        res.(sprintf('brg%d_%s_Hz', j, kinds{q})) = F.bearing(j).(kinds{q});
    end
end
nfail = 0;
for i = 1:height(T)
    q = char(T.quantity(i));
    v = res.(q);
    e = T.expected(i);
    ok = abs(v / e - 1) <= T.tol(i);
    if ~ok
        nfail = nfail + 1;
        fprintf('%-5s %-18s %12.4f %12.4f  FAIL\n', T.tc(i), q, v, e);
    end
end
fprintf('%d values, %d failures\n', height(T), nfail);
