% TEST_STEP27  Compares the step 2.7 tool with calc/tests/step27_test_cases.csv.
%   Run from the repo root:
%     addpath('calc/lubrication', 'calc/agb_lube', 'calc/gear_detail', 'calc/shafts_bearings', 'calc/accessory');
%     test_step27
%   Expected values come from an independent Python implementation
%   (calc/reference/step27_reference.py): the heat balance on the gear
%   geometry of the step 2.4 and 2.6 references, the jet schedule for a
%   given set of component heats and the cooler model. Same 0.1% rule.

T = readtable('calc/tests/step27_test_cases.csv', 'TextType', 'string');
in = lb_inputs();
res = struct();

% TC49: heat balance at maximum continuous power with a given pump power
D = lb_design();
R = lb_losses(D, in.ops(1), 2392.6, in);
for q = {'mesh_s1', 'mesh_sp', 'mesh_pr', 'mesh_gen', 'mesh_osg', 'brg_inp', 'brg_mid', 'brg_prop', ...
         'brg_planet', 'brg_acc', 'wind_pinion', 'wind_gear2', 'wind_planetary', 'wind_acc', 'pcu_osg'}
    res.TC49.(q{1}) = R.L.(q{1});
end
res.TC49.L_mech = R.L_mech;
res.TC49.Q_oil = R.Q_oil;
res.TC49.P_PT = R.P_PT;

% TC50: jets for given component heats
Lf = struct('mesh_s1', 2500, 'wind_pinion', 120, 'wind_gear2', 500, 'mesh_sp', 2300, 'mesh_pr', 800, ...
            'wind_planetary', 50, 'brg_planet', 540, 'brg_inp', 1900, 'brg_mid', 470, 'brg_prop', 530, ...
            'mesh_gen', 40, 'mesh_osg', 4, 'mesh_pcu', 1.3, 'wind_acc', 120, 'brg_acc', 80, 'rear_sump', 1204);
F = lb_flows(Lf, 4, in, oil_props(115, in.oil));
nm = {'first', 'planetary', 'planet_brg', 'input_brg', 'mid_brg', 'prop_brg', 'acc_mesh', 'gen_brg', 'splines', 'rear'};
for k = 1:numel(nm)
    res.TC50.([nm{k} '_flow']) = F.comp(k).flow;
    res.TC50.([nm{k} '_d']) = F.comp(k).d;
end
res.TC50.Q_lube = F.Q_lube;
res.TC50.Q_need = F.Q_need;

% TC51: cooler
C = lb_cooler(18e3, 0.33, 6, in);
for q = {'T_oil_in', 'eps', 'NTU', 'UA', 'Re_a', 'j_a', 'f_a', 'h_a', 'L', 'Re_o', 'h_o', 'dp_air', 'dp_oil', ...
         'm_cooler', 'P_fan'}
    res.TC51.(q{1}) = C.(q{1});
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
