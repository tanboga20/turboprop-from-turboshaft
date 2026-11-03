% TEST_STEP34  Compares the step 3.4 results with calc/tests/step34_test_cases.csv.
%   Run from the repo root after run_step34 (it writes calc/results/step34/step34.mat):
%     addpath('calc/manufacturing');  test_step34
%   Expected values come from an independent Python implementation
%   (calc/reference/step34_reference.py) of the closed forms: Hertz half
%   width and case depth of the flanks and planet bearing raceways, the
%   bottom-up fastener mass, the seat liners, the film ratio against the
%   flank finish and the BOM sums. The contact stresses, K_gamma and film
%   thickness come from the tested step 2.4 tools.

T = readtable('calc/tests/step34_test_cases.csv', 'TextType', 'string');
L = load(fullfile('calc', 'results', 'step34', 'step34.mat'));
S = L.S;
C = S.casedepth.T;
row = @(name) C(C.case == "LD-02" & C.contact == name, :);
res = struct();
nm = {'pinion', "first stage: pinion"; 'planet_sun', "sun-planet: planet (sun mesh)"; 'sun', "sun-planet: sun"; ...
      'planet_ring', "planet-ring: planet (ring mesh)"; 'ring', "planet-ring: ring"};
for k = 1:size(nm, 1)
    r = row(nm{k, 2});
    res.TC80.(['b_' nm{k, 1}]) = r.b_mm;
    res.TC80.(['need_' nm{k, 1}]) = r.cd_needed_mm;
    res.TC80.(['margin_' nm{k, 1}]) = r.margin;
end
for k = {'bore', "planet bore (outer race)"; 'pin', "planet pin (inner race)"}'
    r = row(k{2});
    res.TC80.(['p0_' k{1}]) = r.p0_MPa;
    res.TC80.(['need_' k{1}]) = r.cd_needed_mm;
    res.TC80.(['margin_' k{1}]) = r.margin;
end
res.TC80.Z = S.casedepth.Z;
F = S.fasteners;
res.TC81 = struct('sum', F.sum, 'with_k', F.with_k, 'diff', F.diff);
Ln = S.liners;
res.TC82 = struct('kg', Ln.kg, 'kg_NU1024', Ln.T.kg_added(1), 'dfit_NU1024__40', Ln.dfit(1, 1), 'dfit_NU1024_132', Ln.dfit(1, 3));
Fm = S.film.T;
j = find(abs(S.film.Ra_list - 0.10) < 1e-9);
for k = {'sun_planet_100', "sun-planet", 100; 'sun_planet_132', "sun-planet", 132; ...
         'planet_ring_100', "planet-ring", 100; 'first_stage_100', "first stage", 100}'
    r = Fm(Fm.mesh == k{2} & Fm.T_oil == k{3}, :);
    res.TC83.(['lambda24_' k{1}]) = r.lambdaC;
    res.TC83.(['lambda_Ra01_' k{1}]) = r.lambda_at_Ra(j);
end
r = Fm(Fm.mesh == "sun-planet" & Fm.T_oil == 100, :);
res.TC83.Ra_lambda1_sun_planet_100 = r.Ra_for_lambda1_um;
res.TC84 = struct('rollup', S.bom.rollup, 'bottom_up', S.bom.bottom_up);

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
    fprintf('%-5s %-28s %14.6g %14.6g (tol %.1f%%)  %s\n', tc, q, v, e, 100 * T.tol(i), verdict);
end
fprintf('%d values, %d failures, %d missing\n', height(T), nfail, nmiss);
