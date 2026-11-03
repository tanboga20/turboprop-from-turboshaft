function Q = sf_qj(in, Lp)
%SF_QJ  QJ1024 axial-loss follow-up (G1b): thrust floor, NJ1024 push-in standby, limp mode, R4 branches, E7 phases.
%   Q = sf_qj(in, Lp)   in = sf_inputs, Lp = sf_lip(in)
%
%   Thrust floor: the gust and manoeuvre swings plus a margin; checked against the A-05 mission steps of step 2.5 (the
%   descent is at +2 kN). NJ1024 (outer propeller roller bearing, inner-ring rib outboard): the SKF axial load
%   capacity F_ap = k1 C0 1e4 / (n (d + D)) - k2 Fr, derated by f_kappa for the kappa 0.3-0.5 film, continuous (k1)
%   and brief (k1_brief), with Fa / Fr <= 0.5; the limp thrust is the continuous rating; the end play is the
%   push-in band edge plus the margin, against the 2 mm seal contact.
%   R4 = P(lip fails before landing | QJ1024 axial loss), no detection credit (c_det = 0): the NJ holds (share
%   1 - p_nj): only the pull-out transients reach the lip (q_trans times f_neg relative to its basis); the NJ fails
%   (p_nj = p_tc + (1 - p_tc) p_limp: a loss in take-off and climb above the NJ brief rating, or during the limp
%   period): the seal crush, the E7 shutdown on low oil pressure, the feather, the run-down rub (q_rub7 of sf_lip)
%   and the feathered drag until landing (q_wear), or the feather fails (q_cw of D1b: windmilling at governed speed,
%   the lip fails).
%   E7 p_qj: phase (i) a QJ1024 loss in the mist run at 4.5 kN on the mist-fed NJ (p_mist), then the pull-out onto
%   the lip after the shutdown; phases (ii) and (iii) as before (q_nomist x t_feather / t_dry, q_static).
%   Source: Phase 3 report, Section 3.7 (D1, G1b).

q = in.qj;  nj = q.nj;
Q.floor = q.swing_gust + q.swing_man + q.margin;
th = in.ft2.b;  %#ok<NASGU>
Q.mission_thrust = [18e3 3e3 2e3];                       % A-05 steps of step 2.5 (take-off, cruise, descent) [N]
Q.floor_ok = all(Q.mission_thrust >= Q.floor);
cap = @(k1) (k1 * nj.C0 * 1e4 / (nj.n * (nj.d + nj.D)) - nj.k2 * nj.Fr) * nj.f_kappa;
Q.nj_cont = min(cap(nj.k1), 0.5 * nj.Fr);
Q.nj_brief = min(cap(nj.k1_brief), 0.5 * nj.Fr * 2);
Q.limp = floor(Q.nj_cont / 100) * 100;                   % limp thrust cap [N]
Q.end_play = nj.band + nj.margin;
Q.end_play_ok = Q.end_play < nj.seal;
% R4 branches
q_cw = max(in.ft2.b.cw.lam * in.ft2.b.cw.T / 2 + in.ft2.b.cw.qd, 0);
p_nj = q.p_tc + (1 - q.p_tc) * q.p_limp;
Q.p_nj = p_nj;
Q.branch = [(1 - p_nj) * q.q_trans * q.f_neg / 1e-3, p_nj * (Lp.q_rub7 + q.q_wear), p_nj * q_cw];
Q.R4 = min(1, sum(Q.branch));
% E7 phases
o = in.ft.oil;
Q.p_i = q.p_mist;
Q.p_ii = o.q_nomist * min(1, o.t_feather / o.t_dry);
Q.p_iii = o.q_static;
Q.p_qj = Q.p_i + Q.p_ii + Q.p_iii;
Q.phases = table(["(i) mist run under positive thrust (push-in onto the mist-fed NJ1024)"; ...
                  "(ii) shutdown and run-down until feathered"; "(iii) feathered, rest of the flight"], ...
                 ["(i) pozitif itki altında sis çalışması (itme sisle yağlanan NJ1024'e)"; ...
                  "(ii) kapatma ve tüylenene kadar yavaşlama"; "(iii) tüylenmiş, uçuşun geri kalanı"], ...
                 [o.t_mist; o.t_feather; NaN], ["push-in (NJ1024 standby; KM24 nut path)"; ...
                  "pull-out (shoulder ring, QJ1024, P111)"; "pull-out (shoulder ring, QJ1024, P111)"], ...
                 [o.F_push; in.ft.lip.rub.F_wm; in.ft.lip.rub.F_f] / 1e3, ...
                 ["mist (LUB-07), NJ rated brief"; "mist (LUB-07), turning"; "dry, stopped or slow"], [Q.p_i; Q.p_ii; Q.p_iii], ...
                 'VariableNames', {'phase_en', 'phase_tr', 'duration_s', 'load_path', 'load_kN', 'qj_state', 'p'});
% mass roll-up (SYS-06)
ms = q.mass;
Q.mass_changes = sum(struct2array(ms)) + (Lp.m_total - 0.4573);   % against the G1 P116 total of 0.4573 kg
Q.rollup = in.ft.sys06.base + in.ft.sys06.thread + Lp.m_total + sum(struct2array(ms));
Q.offsets = sum([q.offsets{:, 2}]);
Q.rollup_net = Q.rollup + Q.offsets * (Q.rollup > in.ft.sys06.limit);
end
