% TEST_STEP33  Compares the closed-form sensitivities of step 3.3 with calc/tests/step33_test_cases.csv.
%   Run from the repo root after run_step33 (it writes requirements/icd_sensitivity_v1.csv):
%     addpath('calc/interfaces');  test_step33
%   Expected values come from an independent Python implementation
%   (calc/reference/step33_reference.py) of the closed forms: the LD-08
%   torque peak and ring gear margin, the LUB-08 oil volume, the STR-02
%   planet bearing speed margin, the DYN-05 seat stiffness with the mount in
%   series, the LD-06 generator pad moment and the ICD-34 installed dry
%   engine mass (RGB and SYS-11 input drive from step32.mat, tank from as_inputs). The rows that rerun the tools
%   of steps 2.2, 2.5 and 3.2 are covered by those steps' tests.

T = readtable('calc/tests/step33_test_cases.csv', 'TextType', 'string');
S = readtable(fullfile('requirements', 'icd_sensitivity_v1.csv'), 'TextType', 'string');
pick = @(id, q, v, col) S.(col)(S.id == id & startsWith(S.quantity, q) & abs(S.value - v) < 1e-6 * max(1, abs(v)));
res = struct();
for t = [0.15 0.20 0.22 0.30 0.50]
    res.TC74.(matlab.lang.makeValidName(sprintf('T_%g', t))) = pick("LD-08", "PT stopping", t, 'result');
    res.TC74.(matlab.lang.makeValidName(sprintf('margin_%g', t))) = pick("LD-08", "PT stopping", t, 'margin');
end
for t = [5 10 20 30]
    res.TC75.(sprintf('V_%g', t)) = pick("LUB-08", "negative-g", t, 'result');
    res.TC75.(sprintf('margin_%g', t)) = pick("LUB-08", "negative-g", t, 'margin');
end
for nl = [5500 6000 6500 7000]
    res.TC76.(sprintf('margin_%g', nl)) = pick("STR-02", "planet bearing", nl, 'margin');
end
for km = [1e8 2e8 5e8 1e9]
    res.TC77.(matlab.lang.makeValidName(sprintf('k_%g', km))) = pick("DYN-05", "engine mount", km, 'result');
    res.TC77.(matlab.lang.makeValidName(sprintf('margin_k_%g', km))) = pick("DYN-05", "engine mount", km, 'margin');
end
for nz = [2.5 3.17 4.0 5.0]
    res.TC77.(matlab.lang.makeValidName(sprintf('M_pad_%g', nz))) = pick("LD-06", "manoeuvre load factor: generator", nz, 'result');
end
% TC78 (ICD-34): installed dry engine mass estimate against the PT6A-67A (229.5 kg)
st = load(fullfile('calc', 'results', 'step32', 'step32.mat'));
ai = as_inputs();
res.TC78.m_installed = 437 * 0.45359237 + st.S.mass.total + st.S.mass.drive + ai.ext(2).m;   % T700-GE-700 core, SYS-11
res.TC78.over_PT6A67A = res.TC78.m_installed - 229.5;
% TC79 (oil decision): cooler inlet temperatures and ambient limits of run_oilgrade (oil_grade_check.csv)
G = readtable(fullfile('calc', 'interfaces', 'oil_grade_check.csv'), 'TextType', 'string');
cv = @(t, it) G.value(G.kind == "cooler" & G.T_C == t & startsWith(G.item, it));
for q = [14.9 18]
    for ta = [53 -20 -40]
        res.TC79.(matlab.lang.makeValidName(sprintf('Tin_%g_%g', q, ta))) = cv(ta, sprintf('inlet with the whole cooler at %g kW', q));
    end
    res.TC79.(matlab.lang.makeValidName(sprintf('Tamb73_%g', q))) = cv(73, sprintf('ambient for this inlet at %g kW', q));
end

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
    fprintf('%-5s %-18s %14.6g %14.6g (tol %.1f%%)  %s\n', tc, q, v, e, 100 * T.tol(i), verdict);
end
fprintf('%d values, %d failures, %d missing\n', height(T), nfail, nmiss);
