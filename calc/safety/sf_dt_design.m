function Z = sf_dt_design(in)
%SF_DT_DESIGN  Design studies of D4: the P103 thread options, the carrier rim bosses, the 1P moment sensitivity.
%   Z = sf_dt_design(in)   in = sf_inputs
%
%   Thread (rule, with the MPI sizes it was set on): the drawing M120 x 2 thread and the options
%   (a) MJ thread, (b) local 95 mm bore, (c) both against the NDT margin (sf_dt ndt_ratio >= rule_ndt) and an
%   anomaly life >= the target at dKth -20%; the option adopted is in.dt.thread_adopted (design
%   decision, delegated by Hamit: (c), the first that meets the rule), checked to meet it (Z.over.thread); the interval with the
%   eddy current sizes adopted at TBO is listed. Carrier: the pin bore against the rim ligament widened in
%   0.5 mm steps up to b_max by local bosses (not adopted: the interval comes from the eddy current of the pin
%   bores, design decision, delegated by Hamit), with the mass. The press-fit
%   hoop of 3.5 is run as a check. 1P: the P103 seat, the adopted thread, the case junction and the shoulder-ring
%   groove (G1b) at each M_1P of
%   in.dt.m1p_sens, and the largest M_1P for which the base-case conclusions hold (anomaly life >= target,
%   interval >= min(1, base interval) TBO, a_HCF above the initial flaw (for the case: its pore radius), the
%   thread NDT margin >= rule_ndt where the base met it), by
%   bisection to 10 N m.
%   Source: Phase 3 report, Section 3.7 (D4).

d = in.dt;
opt = struct('cyc_tbo', d.cyc_tbo, 'target', d.target);
S4 = d.mat.S4340;
S4w = S4;  S4w.dKth = @(R) d.sens.dKth * S4.dKth(R);
mass_b = @(di) d.mat_rho * pi / 4 * (100^2 - di^2) * d.thread.L_bore;
% thread options
o = d.thread_opt;
rows = {};
Z.over = struct();
adopted = 0;
for k = 1:numel(o)
    ov = struct('thread', struct('Kf', o(k).Kf, 'di', o(k).di), 'ndt_thread', 'MPI');
    Lc = sf_locations(in, ov);
    R = sf_dt(Lc(2), S4, opt);  Rw = sf_dt(Lc(2), S4w, opt);
    ov.ndt_thread = 'ET';  Lc = sf_locations(in, ov);  Re = sf_dt(Lc(2), S4, opt);
    ok = R.ndt_ratio >= d.rule_ndt && Rw.N >= d.target;
    if strcmp(o(k).key, d.thread_adopted)
        assert(ok, 'sf_dt_design: the adopted thread option does not meet the rule');
        adopted = k;
    end
    Zs = pi / 32 * (d.thread.d3^4 - o(k).di^4) / d.thread.d3;
    rows(end + 1, :) = {string(o(k).key), string(o(k).en), string(o(k).tr), o(k).Kf, o(k).di, Zs, R.theta, R.L.s_hmax, ...
        R.L.s_hmin, R.a_hcf, R.ndt_ratio, R.ndt_ratio_shape, R.interval_tbo, Re.interval_tbo, R.N, Rw.N, ok, ...
        mass_b(o(k).di), false}; %#ok<AGROW>
end
Z.thread = cell2table(rows, 'VariableNames', {'key', 'option_en', 'option_tr', 'Kf', 'bore_mm', 'Z_mm3', 'theta_deg', ...
    's_hcf_max_MPa', 's_hcf_min_MPa', 'a_hcf_mm', 'ndt_ratio', 'ndt_ratio_shape', 'interval_tbo', 'interval_tbo_ET', 'N_anomaly', ...
    'N_anomaly_dKth08', 'meets_rule', 'added_mass_kg', 'adopted'});
Z.thread_adopted = adopted;
if adopted
    Z.thread.adopted(adopted) = true;
    Z.over.thread = struct('Kf', o(adopted).Kf, 'di', o(adopted).di);
end
% carrier rim bosses
ca = d.carrier;
Lc = sf_locations(in, Z.over);
R0 = sf_dt(Lc(3), S4, opt);
bb = ca.b:0.5:ca.b_max;
rows = {};
Z.boss_b = NaN;
for b = bb
    ov = Z.over;  ov.carrier_b = b;
    Lc = sf_locations(in, ov);
    R = sf_dt(Lc(3), S4, opt);  Rw = sf_dt(Lc(3), S4w, opt);
    ok = R.interval_tbo >= 1 && Rw.N >= d.target;
    m = ca.n_bores * (b - ca.b) * ca.w_boss * ca.t * ca.rho;
    rows(end + 1, :) = {b, R.a_hcf, R.ndt_ratio, R.N_insp, R.interval_tbo, R.N, Rw.N, ok, m, ca.r_rim + b - ca.b}; %#ok<AGROW>
    if ok && isnan(Z.boss_b), Z.boss_b = b; end
end
Z.boss = cell2table(rows, 'VariableNames', {'ligament_mm', 'a_hcf_mm', 'ndt_ratio', 'N_det_to_fail', 'interval_tbo', ...
    'N_anomaly', 'N_anomaly_dKth08', 'meets_rule', 'added_mass_kg', 'boss_radius_mm'});
Z.boss_needed = R0.interval_tbo < 1;
% press-fit hoop of 3.5 as a check
ov = Z.over;  ov.carrier_hoop = ca.hoop_35;
Lc = sf_locations(in, ov);
R = sf_dt(Lc(3), S4, opt);
Z.hoop35 = struct('a_hcf', R.a_hcf, 'interval_tbo', R.interval_tbo, 'N', R.N);
% 1P moment
locs = [1 2 5 12];
hold_ = @(R, R0, k) R.N >= d.target && R.interval_tbo >= min(1, R0.interval_tbo) && R.a_hcf > R.L.a0 && ...
                    (k ~= 2 || R0.ndt_ratio < d.rule_ndt || R.ndt_ratio >= d.rule_ndt);
Lb = sf_locations(in, Z.over);
for j = 1:numel(locs)
    Rb0(j) = sf_dt(Lb(locs(j)), d.mat.(Lb(locs(j)).mat), opt); %#ok<AGROW>
end
rows = {};
for M = d.m1p_sens
    ov = Z.over;  ov.M_1P = M;
    Lc = sf_locations(in, ov);
    for j = 1:numel(locs)
        L = Lc(locs(j));
        R = sf_dt(L, d.mat.(L.mat), opt);
        rows(end + 1, :) = {M, string(L.en), string(L.tr), R.L.s_hmax, R.L.s_hmin, R.a_hcf, R.ndt_ratio, R.interval_tbo, ...
            R.N, hold_(R, Rb0(j), locs(j))}; %#ok<AGROW>
    end
end
Z.m1p = cell2table(rows, 'VariableNames', {'M_1P_Nm', 'location_en', 'location_tr', 's_hcf_max_MPa', 's_hcf_min_MPa', ...
    'a_hcf_mm', 'ndt_ratio', 'interval_tbo', 'N_anomaly', 'holds'});
Z.m1p_max = zeros(1, numel(locs));
for j = 1:numel(locs)
    f = @(M) hold_(one(in, Z.over, M, locs(j), opt), Rb0(j), locs(j));
    lo = d.M_1P;  hi = 20000;
    if f(hi), Z.m1p_max(j) = hi; continue, end
    while hi - lo > 10
        mid = (lo + hi) / 2;
        if f(mid), lo = mid; else, hi = mid; end
    end
    Z.m1p_max(j) = lo;
end
Z.m1p_locs = string({Lb(locs).en});
Z.m1p_limit = min(Z.m1p_max);
end

function R = one(in, over, M, k, opt)
over.M_1P = M;
Lc = sf_locations(in, over);
R = sf_dt(Lc(k), in.dt.mat.(Lc(k).mat), opt);
end
