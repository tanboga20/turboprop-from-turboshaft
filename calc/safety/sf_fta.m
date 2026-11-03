function F = sf_fta(in)
%SF_FTA  Fault tree of propeller release (SAF-01): cut-set probabilities per engine flight hour, sensitivity.
%   F = sf_fta(in)   in = sf_inputs
%
%   A quantified cut set holds exactly one per-hour event (active or weibull), up to two latent standby events and
%   any demand events (sf_cutset). A latent event is failed with probability lambda_l t + q_d at the time t since
%   its inspection (q_d: failure on engagement); a demand event fails with probability q_d. The cut set rate is the
%   mean over the inspection interval T of h(t) prod(lambda_l t + q_d) prod(q_demand), with h(t) the hazard of
%   the per-hour event: constant (weight uniform: lambda T / 2 for one latent event, lambda_1 lambda_2 T^2 / 3 for
%   two sharing one inspection) or Weibull with slope beta renewed at T (the QJ1024, replaced at each TBO: H(T) / T
%   is the cumulative hazard per hour, and E4 + E5 is exactly f lambda_l beta H(T) / (beta + 1) + f H(T) q_d / T).
%   The lip demand terms come from sf_lip (R7, the run-down rub) and sf_qj (R4, the branches given a QJ1024 axial loss;
%   also the demand of the shoulder-ring failure E8); the E7 rate is lambda_oil x p_qj of sf_qj (phases i-iii). Critical parts (CS-E 515) are not quantified under
%   CS-E 510(c) (the CS-E 510(a)(2) instances that rely on CS-E 515); multi-fastener joints are qualitative under
%   CS-E 510(a)(3) (basis in the event text).
%   Criterion (SAF-01): each cut set at most in.target_h; the sum against the extremely remote band in.ft.band
%   (and against in.target_h). The same cut sets with the standby paths never inspected over the life
%   (in.ft.life, uniform exposure) show which inspections the criterion rests on: those become Airworthiness
%   Limitations items (CS-E 510(e)(1)).
%   Sensitivity: each assumed rate and q_d x10, one at a time, and E4 at an all-causes rate; for each case the
%   largest cut set and, where it exceeds the target, the inspection interval of its latent path that brings it
%   back (NaN where the demand failure alone already reaches the target).
%   Retention tube in the post-failure phase (axial anchors, no torque): axial stress at the ultimate limit thrust
%   and a bound with the propeller weight and gyroscopic moment on the tube, against F_ty and F_tu.
%   F.T: cut-set table; F.sens: sensitivity table; F.tube: tube check; F.lip: sf_lip (P116 sizing, rubbing, E7
%   phases).
%   Source: Phase 3 report, Section 3.7 (D1).

ft = in.ft;
[ev, X] = events(in);
F.lip = X.Lp;  F.qj = X.Q;
[P, id, kind, den, dtr] = cutsets(ev, ft, ft.T_insp, false);
P0 = cutsets(ev, ft, ft.life, true);
ali = P0 > in.target_h & ~isnan(P0);
F.T = table(id, kind, P, P <= in.target_h | isnan(P), P0, ali, den, dtr, ...
            'VariableNames', {'cut_set', 'kind', 'P_per_h', 'meets_1e8', 'P_never_inspected_per_h', ...
            'inspection_is_ALI', 'events_en', 'events_tr'});
F.ev = ev;
F.lam_qj = X.lam_qj;
F.H_tbo_qj = X.H;
F.F_tbo_qj = X.F_tbo;
F.q = arrayfun(@(e) e.rate * ft.T_insp / 2 + e.qd, ev(strcmp({ev.type}, 'latent')));
F.P_max = max(P);
F.P_total = sum(P, 'omitnan');
F.margin = in.target_h / F.P_max;
% sensitivity, one assumption at a time; a G1b input ('qj') rebuilds the lip and QJ demand terms (sf_lip, sf_qj)
ns = size(ft.sens, 1);
case_ = strings(ns, 1);  Pmax = nan(ns, 1);  which = strings(ns, 1);  Psum = nan(ns, 1);  T_back = nan(ns, 1);
P_E4R4 = nan(ns, 1);
for s = 1:ns
    nm = ft.sens{s, 1};  f = ft.sens{s, 3};
    if strcmp(ft.sens{s, 2}, 'qj')
        i2 = in;
        if strcmp(nm, 'f_axial'), i2.ft.qj.f_axial = i2.ft.qj.f_axial * f; else, i2.qj.(nm) = i2.qj.(nm) * f; end
        e2 = events(i2);  case_(s) = sprintf('%s x%g', nm, f);
    else
        e2 = ev;  k = strcmp({e2.id}, nm);
        switch ft.sens{s, 2}
            case 'rate', e2(k).rate = e2(k).rate * f;  case_(s) = sprintf('%s rate x%g', nm, f);
            case 'qd',   e2(k).qd = e2(k).qd * f;      case_(s) = sprintf('%s q_d x%g', nm, f);
            case 'set'                                  % all causes: the bearing rate times f_axial (once)
                e2(k).rate = f * ft.qj.f_axial;  e2(k).type = 'active';
                case_(s) = sprintf('%s = %g /h x f_axial (all causes)', nm, f);
        end
    end
    [Ps, ids] = cutsets(e2, ft, ft.T_insp, false);
    [Pmax(s), j] = max(Ps);  which(s) = ids(j);  Psum(s) = sum(Ps, 'omitnan');
    P_E4R4(s) = Ps(ids == "E4 + R4");
    c = ft.cuts{j};  el = e2(strcmp({e2.id}, c{2}));
    if Pmax(s) > in.target_h && strcmp(el.type, 'latent')   % interval of the latent path that restores the target
        ea = e2(strcmp({e2.id}, c{1}));
        Tb = (in.target_h / ea.rate - el.qd) / (el.rate * wfac(ea));
        if Tb > 0, T_back(s) = Tb; end
    end
end
note = strings(ns, 1);
note(Pmax <= in.target_h) = "met";
k = Pmax > in.target_h & ~isnan(T_back);
note(k) = "met with the latent path inspected every " + compose('%.0f', T_back(k)) + " h";
note(Pmax > in.target_h & isnan(T_back)) = "not met: a demand failure alone reaches the target, inspection cannot restore it";
F.sens = table(case_, which, Pmax, Psum, T_back, P_E4R4, note, 'VariableNames', {'case', 'largest_cut_set', 'P_max_per_h', ...
               'P_sum_per_h', 'T_insp_back_h', 'P_E4_R4', 'note'});
% retention tube in the post-failure phase
t = ft.tube;
A = pi / 4 * (t.D^2 - t.d^2);  Z = pi / 32 * (t.D^4 - t.d^4) / t.D;
s_ax = t.fu * t.F_lim / A;
s_b = t.fu * (t.F_lim / A + (t.M_w + t.M_gyro) * 1e3 / Z);
F.tube = table(["axial only (anchors carry no torque): 1.5 x LD-04 limit thrust"; ...
                "bound: 1.5 x (limit thrust + propeller weight at n_z 2.5 + gyroscopic moment)"], ...
               ["yalnız eksenel (bağlantılar tork taşımaz): 1,5 x LD-04 sınır itkisi"; ...
                "sınır: 1,5 x (sınır itkisi + n_z 2,5'te pervane ağırlığı + jiroskopik moment)"], ...
               [s_ax; s_b], t.Fty ./ ([s_ax; s_b] / t.fu), t.Ftu ./ [s_ax; s_b], ...
               'VariableNames', {'case_en', 'case_tr', 's_ultimate_MPa', 'RF_yield_limit', 'RF_ultimate'});
end

function [ev, X] = events(in)
% the events with their computed rates and demand terms
ft = in.ft;  q = ft.qj;
X.H = log(1 / 0.9) * (in.tbo_h / q.L10m)^q.slope;           % cumulative hazard over one TBO
X.F_tbo = 1 - exp(-X.H);                                     % failure probability within one TBO
X.lam_qj = X.H / in.tbo_h;                                   % mean hazard over the TBO, per hour
X.Lp = sf_lip(in);
X.Q = sf_qj(in, X.Lp);
ev = ft.ev;
k = strcmp({ev.id}, 'E4');  ev(k).rate = X.lam_qj * q.f_axial;  ev(k).beta = q.slope;
k = strcmp({ev.id}, 'E7');  ev(k).rate = ft.oil.lam * X.Q.p_qj;
k = strcmp({ev.id}, 'R4');  ev(k).qd = X.Q.R4;
k = strcmp({ev.id}, 'R7');  ev(k).qd = X.Lp.q_rub7;
end

function c = wfac(e)
% factor on lambda_l T of a single latent event paired with the per-hour event e
c = 0.5;
if strcmp(e.type, 'weibull'), c = e.beta / (e.beta + 1); end
end

function [P, id, kind, den, dtr] = cutsets(ev, ft, T, uniform)
nc = numel(ft.cuts);
id = strings(nc, 1);  kind = strings(nc, 1);  P = nan(nc, 1);  den = strings(nc, 1);  dtr = strings(nc, 1);
for k = 1:nc
    c = ft.cuts{k};
    e = arrayfun(@(s) ev(strcmp({ev.id}, s)), string(c));
    id(k) = strjoin(string(c), ' + ');
    den(k) = strjoin(string({e.en}), ' AND ');
    dtr(k) = strjoin(string({e.tr}), ' VE ');
    if numel(c) == 1
        kind(k) = string(e.type);
        continue
    end
    kind(k) = "dual path";
    if any(strcmp({e.type}, 'demand')), kind(k) = "dual path, demand"; end
    P(k) = sf_cutset(e, T, uniform);
end
end
