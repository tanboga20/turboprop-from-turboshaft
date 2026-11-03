% TEST_STEP310  Checks the step 3.10 HUMS signal, TSA, indicators and thresholds against
%   calc/tests/step310_test_cases.csv.
%   Run from the repo root:
%     addpath('calc/hums', 'calc/gear_detail', 'calc/shafts_bearings', 'calc/accessory');  test_step310
%   The expected values come from calc/reference/step310_reference.py, which re-codes the deterministic
%   synthetic signal (crack a 0.10 and spall b 1 together), the TSA, FM4, NA4, the sideband energy, the
%   envelope indicator and the log-normal thresholds.

T = readtable('calc/tests/step310_test_cases.csv', 'TextType', 'string');
in = hm_inputs();
in.crack.a = 0.10;  in.crack.beta = 0.10;  in.spall.b = 1;
S = hm_synth(in);
I = hm_indicators(S, in);
Th = hm_threshold(1:20, [1e-3 1e-6]);
ph = in.k_bore * S.th_s / (2 * pi);
res = struct('x_rms', sqrt(mean(S.x.^2)), 'x_1000', S.x(1000), 'x_50000', S.x(50000), ...
             'x_100001', S.x(100001), 'n_impacts', floor(ph(end)) - ceil(ph(1)) + 1, ...
             'nrev', I.nrev, 'FM4', I.FM4, 'NA4', I.NA4, 'SER', I.SER, 'ENV', I.ENV, 'f_bore', I.f_bore, ...
             'thr_caution', Th.thr(1), 'thr_alarm', Th.thr(2));
nfail = 0;
for i = 1:height(T)
    q = char(T.quantity(i));
    v = res.(q);
    e = T.expected(i);
    ok = abs(v - e) <= T.tol(i) * max(abs(e), 1);
    if ~ok
        nfail = nfail + 1;
        fprintf('%-5s %-12s %14.8g %14.8g  FAIL\n', T.tc(i), q, v, e);
    end
end
fprintf('%d values, %d failures\n', height(T), nfail);
