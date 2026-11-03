% TEST_STEP32  Compares the step 3.2 tool with calc/tests/step32_test_cases.csv.
%   Run from the repo root after run_step32 (it writes cad/params/oil_network.txt):
%     addpath('calc/oil_system', 'calc/assembly', 'calc/lubrication', 'calc/agb_lube', ...
%             'calc/gear_detail', 'calc/shafts_bearings', 'calc/accessory');  test_step32
%   Expected values come from an independent Python implementation
%   (calc/reference/step32_reference.py), which re-solves the oil network
%   read from oil_network.txt: the maximum continuous power point with every
%   jet flow, ground idle, the -40 degC start and the warm-up, the pump inlet
%   and negative g, and the run without oil (LUB-07). Each row carries its
%   own relative tolerance.

T = readtable('calc/tests/step32_test_cases.csv', 'TextType', 'string');
S = run_step32();
res = struct();
M = S.ops(1);
res.TC67 = struct('p_m', M.p_m, 'p_out', M.p_out, 'Q_net', M.Q_net, 'Q_prv', M.Q_prv, 'p_jet_min', min(M.jets.p_jet));
for i = 1:height(M.jets)
    res.TC67.(sprintf('Q_jet%02d', i)) = M.jets.Q(i);
end
I = S.ops(2);
res.TC68 = struct('p_m', I.p_m, 'Q_net', I.Q_net, 'ratio_min', min(I.jets.Q ./ I.jets.Q_design));
C = S.ops(3);
res.TC69 = struct('Q_relief', C.Q_relief, 'bypass_filter', double(C.bypass_filter), 'T_ok', S.cold.T_ok, ...
                  't_ok', S.cold.t_ok);
res.TC70 = struct('p_in', S.inlet.p_in, 'p_in_negg', S.inlet.p_in_negg, 'p_in_cold', S.inlet.p_in_cold, ...
                  't_negg', S.inlet.t_negg);
W = S.lub07;
for k = 1:height(W.res)
    q = W.res.q_Lmin(k);
    res.TC71.(matlab.lang.makeValidName(sprintf('V_%g', q))) = W.res.V_L(k);
    res.TC71.(matlab.lang.makeValidName(sprintf('mass_%g', q))) = W.res.mass_kg(k);
end
lab = {'A', 'B', 'C'};
for k = 1:3
    res.TC71.(['t_' lab{k} '_parts']) = W.t.t_parts_only(k);
    res.TC71.(['t_' lab{k} '_case']) = W.t.t_with_case(k);
end

Xm = S.mist.t;
pts = {'cruise', '75'};  air = [0 10 20];
for i = 1:2
    for k = 1:3
        r = (i - 1) * 6 + k;                               % uplift 1 rows: no measures, 10, 20 SCFM
        res.TC72.(sprintf('t_%s_%d', pts{i}, air(k))) = Xm.t_s(r);
        res.TC72.(sprintf('Tss_%s_%d', pts{i}, air(k))) = Xm.T_steady(r);
    end
end
for k = 1:height(S.mist.mass)
    res.TC72.(matlab.lang.makeValidName(sprintf('mass_%d_%g', S.mist.mass.minutes(k), S.mist.mass.mL_min_per_contact(k)))) = ...
        S.mist.mass.mass_kg(k);
end

Wm = S.lubmass;
res.TC73 = struct('jets', Wm.jets, 'tubes', Wm.tubes, 'lub_hw', Wm.lub_hw, 'V_acc', Wm.V_acc, 'mist', Wm.mist);

nfail = 0;
nmiss = 0;
for i = 1:height(T)
    tc = char(T.tc(i));
    q = matlab.lang.makeValidName(char(T.quantity(i)));
    if ~isfield(res, tc) || ~isfield(res.(tc), q)
        fprintf('MISSING %s %s\n', tc, q);
        nmiss = nmiss + 1;
        continue
    end
    v = res.(tc).(q);
    e = T.expected(i);
    if e == 0
        ok = abs(v) <= T.tol(i);
    else
        ok = abs(v / e - 1) <= T.tol(i);
    end
    verdict = 'PASS';
    if ~ok
        nfail = nfail + 1;
        verdict = 'FAIL';
    end
    fprintf('%-5s %-16s %14.6g %14.6g (tol %.1f%%)  %s\n', tc, q, v, e, 100 * T.tol(i), verdict);
end
fprintf('%d values, %d failures, %d missing\n', height(T), nfail, nmiss);
