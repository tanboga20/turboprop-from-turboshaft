function B = tl_backlash(in, Th, M)
%TL_BACKLASH  Backlash stack-ups with temperature (E3a first stage, E3b planetary meshes).
%   B = tl_backlash(in, Th, M)   in = tl_inputs, Th = tl_thermal(in), M = gd_meshes(gd_inputs)
%
%   Normal backlash j_bn = -(E_sn1 + E_sn2) cos(alpha_n) + 2 da sin(alpha_wt) cos(beta_b) [mm], with the
%   effective centre-distance change da = a alpha_case dT_case - r_w1 alpha_g dT_1 - r_w2 alpha_g dT_2 (the bore
%   centres follow the case; the gears grow with their own temperatures), the bore-position tolerance and the
%   runout eccentricities (F_r / 2, random phase). Tolerances are +-3 sigma normal (the tooth thickness band
%   about its middle); worst case takes every limit together. Bearing radial play is not credited (the mesh
%   force pushes the gears apart).
%   Planetary: centre distance on the steel carrier; sun-planet external, planet-ring internal (da = growth of
%   the ring pitch radius, including the inward displacement of the ring bore by the seat fit at that state,
%   minus the carrier and planet growth); the sun floats, so the two backlashes of a planet path add.
%   B.s1: table of the first-stage backlash per state; B.s1_tr: worst-case and MC P0.135 minimum over the
%   cold-start transient; B.pl: planetary backlash per state.
%   Source: Phase 3 report, Section 3.8 (E3).

cte = in.cte;  T0 = in.T_ref;
g = M(1).g;
an = g.alpha_n;  awt = g.alpha_wt;  bb = g.beta_b;  a = g.a_w;
rw = [g.dw1 g.dw2] / 2;
k_j = 2 * sin(awt) * cos(bb);                      % backlash per unit centre-distance change
tp = in.tt.pinion / 1000;  tg = in.tt.gear2 / 1000;     % [E_sns T_sn] mm
Fr = [S_fr(in, 'pinion', M), S_fr(in, 'gear2', M)] / 1000;
fa = in.s1.fa / 1000;
% Monte Carlo samples (normal, tolerance = +-3 sigma); the same samples at every state
rng(in.s1.seed);
n = in.s1.n_mc;
E1 = (tp(1) - tp(2) / 2) + tp(2) / 6 * randn(n, 1);
E2 = (tg(1) - tg(2) / 2) + tg(2) / 6 * randn(n, 1);
dA = fa / 3 * randn(n, 1) + Fr(1) / 2 * cos(2 * pi * rand(n, 1)) + Fr(2) / 2 * cos(2 * pi * rand(n, 1));
j_tol = -(E1 + E2) * cos(an) + k_j * dA;
wc_min = -(tp(1) + tg(1)) * cos(an) - k_j * (fa + sum(Fr) / 2);
wc_max = -((tp(1) - tp(2)) + (tg(1) - tg(2))) * cos(an) + k_j * (fa + sum(Fr) / 2);
th = @(Tc, T1, T2) k_j * (a * cte.A357 * (Tc - T0) - rw(1) * cte.P53 * (T1 - T0) - rw(2) * cte.P53 * (T2 - T0));
st = in.th.states;
n_s = numel(st);
row = zeros(n_s, 6);
for s = 1:n_s
    T = Th.map(st{s}, :);
    dj = th(T.case_f, T.pinion, T.gear2);
    js = sort(j_tol + dj);
    row(s, :) = [T.case_f, T.gear2, dj, wc_min + dj, js(ceil(0.00135 * n)), wc_max + dj];
end
B.s1 = array2table(row, 'VariableNames', {'T_case', 'T_gear', 'dj_thermal', 'j_min_wc', 'j_min_mc', 'j_max_wc'}, ...
                   'RowNames', st);
B.s1_nom20 = [wc_min, mean(j_tol), wc_max];
% cold-start transient
X = Th.tr;
dj_t = th(X.case_f, X.pinion, X.gear2);
[djm, i] = min(dj_t);
js = sort(j_tol);
B.s1_tr = struct('t', X.t, 'dj', dj_t, 'j_min_wc', wc_min + dj_t, 'j_min_mc', js(ceil(0.00135 * n)) + dj_t, ...
                 'j_max_wc', wc_max + dj_t, 'dj_min', djm, 't_min', X.t(i), 'j_min_wc_min', wc_min + djm, ...
                 'j_min_mc_min', js(ceil(0.00135 * n)) + djm, 'j_max_all', max([wc_max + dj_t; row(:, 6)]));
% planetary meshes (sun-planet M(2): planet / sun; planet-ring M(3): planet / ring)
a2 = M(2).g.a_w;  aw = M(2).g.alpha_wt;
r_p = M(2).g.dw1 / 2;  r_s = M(2).g.dw2 / 2;  r_r = M(3).g.dw2 / 2;
ts = in.tt.sun / 1000;  tpl = in.tt.planet / 1000;  tr_ = in.tt.ring / 1000;
Fr_pl = [S_fr(in, 'sun', M), S_fr(in, 'planet', M), S_fr(in, 'ring', M)] / 1000;
pl = zeros(n_s, 6);
for s = 1:n_s
    T = Th.map(st{s}, :);
    pl(s, :) = planetary(in, T.case_p, T.ring, T.carrier, T.sun, T.planet, a2, aw, an, r_s, r_p, r_r, ts, tpl, tr_, Fr_pl);
end
% planetary meshes over the cold-start transient
P = zeros(numel(X.t), 6);
for k = 1:numel(X.t)
    P(k, :) = planetary(in, X.case_p(k), X.ring(k), X.carrier(k), X.sun(k), X.planet(k), a2, aw, an, r_s, r_p, r_r, ...
                        ts, tpl, tr_, Fr_pl);
end
B.pl_tr = struct('t', X.t, 'j_sp_min', P(:, 2), 'j_pr_min', P(:, 3), 'j_pr_min_min', min(P(:, 3)), ...
                 'j_sp_min_min', min(P(:, 2)));
B.pl = array2table(pl, 'VariableNames', {'u_ring_fit', 'j_sp_min', 'j_pr_min', 'j_path_min', 'j_sp_max', 'j_pr_max'}, ...
                   'RowNames', st);
end

function r = planetary(in, Tc, Tr, Tcar, Ts_, Tp, a2, aw, an, r_s, r_p, r_r, ts, tpl, tr_, Fr_pl)
% [ring-fit bore change, min sun-planet, min planet-ring, min path, max sun-planet, max planet-ring] [mm]
cte = in.cte;  T0 = in.T_ref;
u = ring_bore(in, Tc, Tr);
da_sp = a2 * cte.steel * (Tcar - T0) - r_s * cte.P53 * (Ts_ - T0) - r_p * cte.P53 * (Tp - T0);
da_pr = r_r * cte.steel * (Tr - T0) + u - a2 * cte.steel * (Tcar - T0) - r_p * cte.P53 * (Tp - T0);
j_sp = -(ts(1) + tpl(1)) * cos(an) + 2 * sin(aw) * (da_sp - (Fr_pl(1) + Fr_pl(2)) / 2);
j_pr = (tr_(1) - tr_(2) - tpl(1)) * cos(an) + 2 * sin(aw) * (da_pr - (Fr_pl(2) + Fr_pl(3)) / 2);
j_spx = -(ts(1) - ts(2) + tpl(1) - tpl(2)) * cos(an) + 2 * sin(aw) * (da_sp + (Fr_pl(1) + Fr_pl(2)) / 2);
j_prx = (tr_(1) - (tpl(1) - tpl(2))) * cos(an) + 2 * sin(aw) * (da_pr + (Fr_pl(2) + Fr_pl(3)) / 2);
r = [u, j_sp, j_pr, j_sp + j_pr, j_spx, j_prx];
end

function Fr = S_fr(in, key, M) %#ok<INUSD>
g = in.gear(strcmp({in.gear.key}, key));
d = g.z * g.mn / cosd(g.beta);
t = gd_tolerances(d, g.mn, g.b, g.A);
Fr = round(in.Fr_share * t.F_p);
end

function u = ring_bore(in, T_case, T_ring)
% inward displacement of the ring gear bore (pitch radius) by the seat fit at the state, smallest interference
se = in.seat;
hi_b = se.bore_dev(2);                                   % case bore limit deviations [um]
[lo_r, hi_r] = tl_iso286(2 * se.r, se.cls_ring);
d_min = ((2 * se.r + lo_r / 1000) - (2 * se.r + hi_b / 1000)) / 2;     % smallest radial interference at 20 degC
d_T = d_min + se.r * (in.cte.steel * (T_ring - in.T_ref) - in.cte.A357 * (T_case - in.T_ref));
R = tl_lame(se.r_ring_in, se.r, se.r + se.t_case, in.E.steel, in.nu.steel, in.E.A357, in.nu.A357, d_T);
u = R.u_a;
end
