% TEST_STEP38  Compares the step 3.8 results with calc/tests/step38_test_cases.csv.
%   Run from the repo root after run_step38 (it writes calc/results/step38/step38.mat):
%     addpath('calc/tolerances', 'calc/gear_detail');  test_step38
%   Expected values come from an independent Python implementation
%   (calc/reference/step38_reference.py) of the closed forms:
%   - TC107 the thermal map: LD-02 case lag, the cold-start transient at a few
%     times and the largest lead of gear 2 over the first-stage case;
%   - TC108 the gear tolerances by the ISO 1328-1 formulae, runout, tooth
%     thickness limits;
%   - TC109 ISO 286-1 limit deviations from the formulae.
%   A missing value counts as a failure.

T = readtable('calc/tests/step38_test_cases.csv', 'TextType', 'string');
X = load(fullfile('calc', 'results', 'step38', 'step38.mat'));
S = X.S;
res = struct();
Th = S.th;
for p = {'case_p', 'case_f', 'P111'}
    res.TC107.(['LD02_' p{1}]) = Th.map{'LD-02, oil 149, 15 min', p{1}};
end
for k = [300 600 900 1800 3600]
    i = find(Th.tr.t == k, 1);
    for p = {'gear2', 'sun', 'carrier', 'case_f', 'case_p'}
        res.TC107.(sprintf('t%d_%s', k, p{1})) = Th.tr.(p{1})(i);
    end
end
[dm, i] = max(Th.tr.gear2 - Th.tr.case_f);
res.TC107.lead_gear2_case_f = dm;
res.TC107.lead_time = Th.tr.t(i);
G = S.gears.T;
for k = 1:height(G)
    g = char(G.key(k));
    res.TC108.([g '_d']) = G.d_mm(k);  res.TC108.([g '_f_p']) = G.f_p_um(k);  res.TC108.([g '_F_p']) = G.F_p_um(k);
    res.TC108.([g '_f_fa']) = G.f_fa_um(k);  res.TC108.([g '_f_Ha']) = G.f_Ha_um(k);
    res.TC108.([g '_F_b']) = G.F_b_um(k);  res.TC108.([g '_F_r']) = G.F_r_um(k);  res.TC108.([g '_E_sni']) = G.E_sni_um(k);
end
cases = {'H6', 180; 'J6', 180; 'K6', 85; 'M6', 90; 'H7', 259; 'n6', 120; 'm5', 45; 'k5', 45; 'p6', 38; 's6', 38; ...
         'h6', 259; 'f6', 45; 'js5', 120; 'G6', 180; 'P6', 259; 'r6', 120};
for k = 1:size(cases, 1)
    [lo, hi] = tl_iso286(cases{k, 2}, cases{k, 1});
    res.TC109.(sprintf('%s_%d_lo', cases{k, 1}, cases{k, 2})) = lo;
    res.TC109.(sprintf('%s_%d_hi', cases{k, 1}, cases{k, 2})) = hi;
end

B = S.backlash;  A = S.axial;  st = S.in.th.states;
res.TC110 = struct('s1_wc_min_20', B.s1_nom20(1), 's1_wc_max_20', B.s1_nom20(3));
for s = 1:numel(st)
    tag = matlab.lang.makeValidName(strrep(strrep(strtok(st{s}, ','), ' ', '_'), '%', ''));
    res.TC110.(['s1_dj_' tag]) = B.s1.dj_thermal(s);
    if B.pl.u_ring_fit(s) ~= 0, res.TC110.(['u_ring_' tag]) = B.pl.u_ring_fit(s); end
    res.TC110.(['j_sp_min_' tag]) = B.pl.j_sp_min(s);
    res.TC110.(['j_pr_min_' tag]) = B.pl.j_pr_min(s);
    res.TC110.(['lip_margin_' tag]) = A.T.lip_margin_min(s);
    res.TC110.(['tube_gap_' tag]) = A.T.tube_gap_min(s);
end
Kt = S.kgam.T;
k = Kt.distribution == "uniform (step 2.4)" & Kt.torque_share == 1;
res.TC110.Kgam_uniform_P99 = Kt.P99(k);
res.TC110.Kgam_uniform_P90 = Kt.P90(k);

F = S.fits;
res.TC111 = struct('seat_d20_min', F.seat_d20(1), 'seat_d20_max', F.seat_d20(2), ...
                   'goodman_cruise_min', F.seat_goodman_cruise(1), 'goodman_cruise_max', F.seat_goodman_cruise(2), ...
                   'T_assy', F.T_assy, 'pin_p_0', F.pin.p(1), 'pin_p_1', F.pin.p(2), ...
                   'pin_hold_0', F.pin.F_hold(1), 'pin_hold_1', F.pin.F_hold(2));
for s = 1:numel(st)
    tag = matlab.lang.makeValidName(strrep(strrep(strtok(st{s}, ','), ' ', '_'), '%', ''));
    res.TC111.(['seat_dmin_' tag]) = F.seat.delta_min_um(s);
    res.TC111.(['seat_hoopmax_' tag]) = F.seat.hoop_max_MPa(s);
end
for s = [1 4]
    tag = matlab.lang.makeValidName(strrep(strrep(strtok(st{s}, ','), ' ', '_'), '%', ''));
    for nm = {'NU1024', 'NU2209', 'NU2210'}
        k = F.liner.liner == nm{1} & F.liner.state == st{s};
        res.TC111.(sprintf('liner_%s_p_%s', nm{1}, tag)) = F.liner.p_min_MPa(k);
        k = startsWith(F.brg.bearing, nm{1}) & F.brg.state == st{s};
        res.TC111.(sprintf('clear_%s_%s', nm{1}, tag)) = F.brg.clearance_min_um(k);
    end
end
Ps = S.splines.T;
tags = {'fixed', 'sun quill to intermediate shaft (fixed)'; 'crowned', 'sun quill to sun (crowned)'; ...
        'coupling', 'PT shaft coupling to the input pinion'; 'gen', 'generator quill'; 'osg', 'OSG quill'};
for k = 1:size(tags, 1)
    r = Ps(Ps.spline == tags{k, 2}, :);
    res.TC112.([tags{k, 1} '_T_lambda']) = r.T_lambda_um(1);
    if r.es_v_um(1) ~= 0, res.TC112.([tags{k, 1} '_es']) = r.es_v_um(1); end
    res.TC112.([tags{k, 1} '_cmax_cold']) = r.clear_max_um(r.state == "cold soak");
    res.TC112.([tags{k, 1} '_cmax_MCT']) = r.clear_max_um(r.state == "MCT, oil 132");
end
res.TC112.n_callouts = height(S.table);

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
    if e == 0, ok = abs(v) <= T.tol(i); else, ok = abs(v / e - 1) <= T.tol(i); end
    verdict = 'PASS';
    if ~ok
        nfail = nfail + 1;
        verdict = 'FAIL';
    end
    fprintf('%-6s %-24s %14.6g %14.6g (tol %.1f%%)  %s\n', tc, q, v, e, 100 * T.tol(i), verdict);
end
nfail = nfail + nmiss;                                % a missing value counts as a failure
fprintf('%d values, %d failures (%d of them missing)\n', height(T), nfail, nmiss);
