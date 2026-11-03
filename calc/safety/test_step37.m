% TEST_STEP37  Compares the step 3.7 results with calc/tests/step37_test_cases.csv.
%   Run from the repo root after run_step37 (it writes calc/results/step37/step37.mat):
%     addpath('calc/safety');  test_step37
%   Expected values come from an independent Python implementation
%   (calc/reference/step37_reference.py) of the closed forms:
%   - TC100 the fault tree: QJ1024 failure probability within one TBO and its
%     mean hazard, the dual-path cut sets with the latent exposure (exact
%     mean over the interval), the sum, the cut sets never inspected over
%     the life (ALI basis), the retention tube in the post-failure phase,
%     the nose cover P116 and the lip rub, the E7 phases;
%   - TC101 the FMEA recounted by class (with and without the design
%     features), its consistency checks (0 failed) and the detection counts;
%   - TC102 the Newman-Raju equations against the published FE values
%     (NASA TP-1578 Table I, NASA TM-85793 Table 2; 9%; NASA TM-89070
%     Table 1 corner tension, 15%: the equations lie above it, conservative);
%   - TC103 the factors re-coded, the stress cycles of the six locations, K at
%     the initial flaw, the HCF threshold and critical sizes, the growth life
%     from the detectable size (2%) and the inspection interval;
%   - TC104 the LCF life on the minimum S-N curve;
%   - TC105 the D1b trees: (a) PT overspeed, (b) the hazardous propeller
%     effect, the sums, the allowances and the lowest of the x10 cases;
%   - TC106 the fire wall model (pdepe) against explicit finite volumes;
%   - TC115 the shaft-break run-up of the protection coverage (the PT-side
%     inertia from the step 2.3 model; mismatch and absolute trips);
%   - TC118 G1b: the lip on the clamped annular plate, the 2-D run-down rub
%     (shared and one-sided), the hot yield, the thrust floor, the NJ1024
%     ratings, limp thrust and end play, the R4 branches, the SYS-06 roll-up
%     with the offsets, E4 + R4 at most over the sensitivity set.
%   - TC114 sf_cutset on synthetic cut sets (two latent events sharing one
%     inspection, a Weibull per-hour event with a demand event);
%   - TC113 the D4 design studies: the P103 thread options and the one adopted,
%     the carrier rim ligament, the 3.5 press-fit hoop check, the PT shaft
%     hoop stress, the 1P moment sweep and the largest M_1P that keeps the
%     base-case conclusions (2%), the steel threshold of 2.0 (reported).
%   A missing value counts as a failure.

T = readtable('calc/tests/step37_test_cases.csv', 'TextType', 'string');
X = load(fullfile('calc', 'results', 'step37', 'step37.mat'));
S = X.S;
res = struct();
F = S.fta;
res.TC100 = struct('F_tbo_qj', F.F_tbo_qj, 'lam_qj', F.lam_qj, 'P_max', F.P_max, 'P_total', F.P_total, ...
                   'tube_s_axial', F.tube.s_ultimate_MPa(1), 'tube_s_bound', F.tube.s_ultimate_MPa(2), ...
                   'tube_RF_ult_bound', F.tube.RF_ultimate(2));
for k = 1:height(F.T)
    if ~isnan(F.T.P_per_h(k))
        res.TC100.(['P_' strrep(char(F.T.cut_set(k)), ' + ', '_')]) = F.T.P_per_h(k);
        res.TC100.(['P0_' strrep(char(F.T.cut_set(k)), ' + ', '_')]) = F.T.P_never_inspected_per_h(k);
    end
end
for k = 1:height(F.sens)                              % keyed by the case, not the row
    tag = sprintf('sens_%s_%s', S.in.ft.sens{k, 1}, S.in.ft.sens{k, 2});
    res.TC100.([tag '_P_max']) = F.sens.P_max_per_h(k);
    if ~isnan(F.sens.T_insp_back_h(k)), res.TC100.([tag '_T_back']) = F.sens.T_insp_back_h(k); end
end
Lp = F.lip;
res.TC100.lip_t = Lp.t;  res.TC100.lip_m_cover = Lp.m_cover;  res.TC100.lip_s_ult = Lp.s_ult;
Q = F.qj;
res.TC100.lip_bolt_lim = Lp.bolt_s_lim;  res.TC100.mass_rollup = Q.rollup;
res.TC100.lip_E_rundown = Lp.E_rundown;  res.TC100.lip_T_rundown = Lp.T_max;
res.TC100.q_R4 = Q.R4;  res.TC100.E7_p = Q.p_qj;
% TC118: G1b (the clamped plate, the 2-D rub, the thrust floor, the NJ1024 standby, the R4 branches, the mass)
res.TC118 = struct('lip_s_lim', Lp.s_lim, 'lip_rf_ult', Lp.rf_ult, 'lip_share_ti', Lp.share_ti, ...
                   'lip_T_onesided', Lp.T_max_onesided, 'lip_s_drag', Lp.s_drag, 'lip_sy_hot', Lp.sy_hot, 'q_R7', Lp.q_rub7, ...
                   'floor', Q.floor, 'nj_cont', Q.nj_cont, 'nj_brief', Q.nj_brief, 'limp', Q.limp, 'end_play', Q.end_play, ...
                   'p_nj', Q.p_nj, 'rollup_net', Q.rollup_net, 'R4_branch1', Q.branch(1), 'R4_branch2', Q.branch(2), ...
                   'R4_branch3', Q.branch(3), 'P_E4_R4_max_sens', max(F.sens.P_E4_R4));
% TC115: shaft-break run-up at the two ends of the PT-side inertia, mismatch and absolute trips
Pr = S.protect;
k = [1, find(Pr.T.logic == "mismatch", 1, 'last'), find(Pr.T.logic == "absolute", 1)];
nm = {'pt_only', 'mismatch_max', 'absolute'};
for j = 1:3
    res.TC115.([nm{j} '_t_det']) = Pr.T.t_detect_ms(k(j));
    res.TC115.([nm{j} '_peak']) = Pr.T.peak_pct(k(j));
end
% TC114: sf_cutset on synthetic cut sets
ev = @(type, rate, qd, beta) struct('type', type, 'rate', rate, 'qd', qd, 'beta', beta);
c1 = [ev('active', 1e-6, 0, 1), ev('latent', 2e-6, 1e-4, 1), ev('latent', 3e-6, 2e-3, 1)];
c2 = [ev('weibull', 5e-7, 0, 1.5), ev('latent', 1e-6, 1e-3, 1), ev('demand', NaN, 0.02, 1)];
res.TC114 = struct('two_latent', sf_cutset(c1, 4000, false), 'two_latent_closed', sf_cutset(c1, 4000, false), ...
                   'weibull_demand', sf_cutset(c2, 4000, false), 'weibull_demand_uniform', sf_cutset(c2, 4000, true));
M = S.fmea;
res.TC101 = struct('n_hazardous', M.count(1), 'n_major', M.count(2), 'n_minor', M.count(3), ...
                   'n_unmit_hazardous', M.count_unmit(1), 'n_unmit_major', M.count_unmit(2), ...
                   'n_unmit_minor', M.count_unmit(3), 'n_fails', numel(M.fails), 'n_det_quantity', M.detect(9), ...
                   'n_det_latent', M.detect(10), 'n_det_HUMS', M.detect(3), 'n_latent', M.n_latent);
% D4: Newman-Raju against the published FE values (rows in the range used), re-coded factors, locations
V = S.nr(S.nr.in_D4_range, :);
for k = 1:height(V), res.TC102.(sprintf('nr%02d', k)) = V.equation(k); end
pts = {'surface', 0.381, 0.381, 10, 188.5, pi / 2; 'surface', 0.381, 0.381, 10, 188.5, 0; 'surface', 2, 5, 8, 300, pi / 2; ...
       'corner', 0.381, 0.381, 10, 40, pi / 2; 'corner', 2, 3, 10, 40, 0; 'surface', 3, 2, 10, 200, 0.3};
for k = 1:size(pts, 1)
    [Ft, Fb] = sf_nr(pts{k, :});
    res.TC103.(sprintf('nr_Ft_%d', k)) = Ft;
    res.TC103.(sprintf('nr_Fb_%d', k)) = Fb;
end
D = S.dt;
for k = 1:numel(D.loc)
    R = D.R(k, 1);  L = R.L;  p = sprintf('loc%d_', k);
    res.TC103.([p 'plane']) = L.theta;
    res.TC103.([p 's_lcf']) = L.s_lcf;  res.TC103.([p 's_hmax']) = L.s_hmax;
    if L.s_lcf_min ~= 0, res.TC103.([p 's_lcf_min']) = L.s_lcf_min; end
    res.TC103.([p 's_hmin']) = L.s_hmin;  res.TC103.([p 's_lim']) = L.s_lim;
    res.TC103.([p 'dK_lcf0']) = R.dK_lcf0(1);  res.TC103.([p 'dK_hcf0']) = max(R.dKh0);
    if isfinite(R.a_hcf), res.TC103.([p 'a_hcf']) = R.a_hcf; end
    if isfinite(R.a_c), res.TC103.([p 'a_c']) = R.a_c; end
    res.TC103.([p 'N']) = R.N;  res.TC103.([p 'ndt_ratio']) = R.ndt_ratio;
    if R.N_insp > 0, res.TC103.([p 'N_det']) = R.N_insp; end
    res.TC103.([p 'interval_tbo']) = R.interval_tbo;
    res.TC103.([p 'emb_margin']) = R.emb.margin;  res.TC103.([p 'emb_a_hcf']) = R.emb.a_hcf;
    j = find(S.parts.T.governing_location == string(L.en), 1);
    res.TC104.([p 'N_lcf_min']) = S.parts.T.N_lcf_min(j);
end
% D4 design studies and the steel threshold sensitivity
for k = [1 6], res.TC113.(sprintf('steel2_loc%d_a_hcf', k)) = D.R(k, 5).a_hcf; end
Z = D.design;
for k = 1:height(Z.thread)
    q = ['thr_' char(Z.thread.key(k)) '_'];
    res.TC113.([q 'a_hcf']) = Z.thread.a_hcf_mm(k);  res.TC113.([q 'ratio']) = Z.thread.ndt_ratio(k);
    res.TC113.([q 'interval']) = Z.thread.interval_tbo(k);  res.TC113.([q 'N']) = Z.thread.N_anomaly(k);
    res.TC113.([q 'interval_ET']) = Z.thread.interval_tbo_ET(k);
    res.TC113.([q 'N_w']) = Z.thread.N_anomaly_dKth08(k);
end
res.TC113.thr_adopted = Z.thread_adopted;
res.TC113.thr_mass = Z.thread.added_mass_kg(end);
for b = [11 20]
    i = find(Z.boss.ligament_mm == b, 1);
    res.TC113.(sprintf('carrier_b%d_a_hcf', b)) = Z.boss.a_hcf_mm(i);
    res.TC113.(sprintf('carrier_b%d_interval', b)) = Z.boss.interval_tbo(i);
end
res.TC113.carrier_hoop35_a_hcf = Z.hoop35.a_hcf;
res.TC117 = struct('stack_sum', D.coupling.stack_sum, 'adopted', D.coupling.adopted);
res.TC113.pt_hoop = D.loc(8).S.hmax(2);
tags = {'seat', 'thread', 'case', 'groove'};
for j = 1:4
    loc = Z.m1p_locs(j);
    for M = S.in.dt.m1p_sens
        i = Z.m1p.M_1P_Nm == M & Z.m1p.location_en == loc;
        res.TC113.(sprintf('m1p%d_%s_a_hcf', M, tags{j})) = Z.m1p.a_hcf_mm(i);
    end
    res.TC113.(['m1p_max_' tags{j}]) = Z.m1p_max(j);
end

G = S.fta2;
res.TC105 = struct('lam_break', G.lam_break, 'sum_a', G.sum_a, 'sum_b', G.sum_b, 'sum_all', G.sum_all, ...
                   'spurious', G.spurious, 'q_p_allow', G.allow.q_p, 'q_lps_allow', G.allow.q_lps, 'T_lps', G.allow.T_lps, ...
                   'q_cw_allow', G.allow.q_cw, 'T_osg_noFF', G.allow.T_osg_noFF, 'q_osg', G.q.osg, 'q_ff', G.q.ff);
for k = 1:height(G.Ta), res.TC105.(sprintf('Pa%d', k)) = G.Ta.P_per_h(k); end
for k = 1:height(G.Tb), res.TC105.(sprintf('Pb%d', k)) = G.Tb.P_per_h(k); end
res.TC105.T_osg_range_lo = G.range.T_osg(1);  res.TC105.T_lps_range_lo = G.range.T_lps(1);
Fz = S.fire;
res.TC106.t_zero = Fz.t_zero;
for w = 1:height(Fz.T)
    p = sprintf('w%d_', w);
    res.TC106.([p 'h_basis']) = Fz.T.h_basis_W_m2K(w);
    res.TC106.([p 'h_min']) = Fz.T.h_min_W_m2K(w);
    if isinf(Fz.T.t_to_solidus_with_flow_s(w))
        res.TC106.([p 't_solidus_after_flow']) = Fz.T.t_solidus_after_flow_s(w);
    else
        res.TC106.([p 't_solidus_with_flow']) = Fz.T.t_to_solidus_with_flow_s(w);
    end
end

Jt = Fz.J(Fz.J.partition, :);
res.TC106.joint_seat = Jt.T_seat_P101;  res.TC106.joint_insert = Jt.T_insert_F201;
res.TC106.joint_oring_f = Jt.T_oring_F201;  res.TC106.joint_oring_p = Jt.T_oring_P101;
res.TC106.joint_p101_max = Jt.T_P101_max;  res.TC106.joint_residual_clamp = Jt.residual_clamp_N;
res.TC106.joint_nopart_p101_max = Fz.J.T_P101_max(~Fz.J.partition);

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
