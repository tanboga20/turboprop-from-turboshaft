function R = sf_dt(L, mat, opt)
%SF_DT  Surface damage tolerance of one location: crack plane, HCF threshold size, LCF growth, failure size, interval.
%   R = sf_dt(L, mat, opt)
%   L    location (sf_locations): kind ('surface' / 'corner'), t, b, g (inner / outer stress ratio across the wall:
%        the stress is split into a membrane part (1 + g) / 2 and a bending part (1 - g) / 2 of the outer-fibre
%        value), a0, c0 (initial flaw), S (stress states [sigma_x sigma_h tau]: lcf_max, lcf_min, hmax, hmin, lim),
%        ndt (detectable sizes: rows [a c] in mm) [mm, MPa]
%   mat  C [m/cycle per (MPa sqrt m)^m], m, dKth (function of R, MPa sqrt m), KIC [MPa sqrt m]
%   opt  cyc_tbo (flight cycles per TBO), target (cycles), da (relative growth step)
%
%   Crack plane: on a plane at theta to the shaft axis (1 deg steps) the normal stress is
%   sigma_x cos^2 + sigma_h sin^2 + tau sin(2 theta); K is the normal stress times the same geometry factor for
%   every state, so the plane with the smallest HCF threshold size is the one with the largest effective HCF
%   range over its threshold, (s_hi - max(s_lo, 0)) / dKth(R) (ties: the largest LCF range). The LCF cycle and
%   the limit load are taken on that plane (R.L holds the resolved stresses).
%   K at the deepest point (phi = pi/2, grows a) and at the surface point (phi = 0, grows c) by sf_nr. LCF growth
%   by Paris from the first cycle (CM-PIFS-007 3.1 A1 (d): the anomaly is a propagating crack, no long-crack
%   threshold), dK = K_max - max(K_min, 0) of the ground-air-ground cycle. The failure size is the first of: the
%   HCF cycle reaches its threshold (K_max - max(K_min, 0) >= dKth(R_hcf)) at either point (a_HCF), K at the
%   limit load reaches K_IC (a_c), the depth reaches 0.8 t (the range of the K equations).
%   Inspection interval: half the growth life from the detectable size to the failure size, in whole TBOs (the
%   worse of the detectable pairs that apply to the wall, a pair applying where its depth is below t; 0 when the
%   detectable crack already meets a failure condition or no pair applies). NDT margin ndt_ratio (the design rule
%   asks 1.25): a_HCF on the anomaly shape (capped at 0.8 t) over the depth of the deepest pair that applies; for
%   information ndt_ratio_shape, the smallest over the pairs of the HCF threshold depth along the shape of the
%   pair over its depth.
%   Through cracks: a pair deeper than 0.8 t, the NASA-STD-5009C through crack of a thin wall (L.thin) and an
%   anomaly deeper than 0.8 t grow as through cracks of half-length c: K = sigma_n sqrt(pi c) M, M the shell bulging
%   factor sqrt(1 + 1.61 c^2 / (R t)) of a wall of mean radius R (1 for a flat diaphragm); the outer-fibre stress is
%   taken over the whole wall (conservative); failure at the HCF threshold, K_IC at the limit load or c = b.
%   Embedded flaw (CS-E 515(a)): a penny crack of radius a_e (opt.a_emb) with K = 2 / pi sigma sqrt(pi a): the HCF
%   margin dKth / dK_eff, the radius at the HCF threshold pi dKth^2 / (4 dsigma^2) and the LCF cycles to it.
%   Source: Phase 3 report, Section 3.7 (D4).

if nargin < 3, opt = struct(); end
if ~isfield(opt, 'da'), opt.da = 0.002; end
if ~isfield(opt, 'a_emb'), opt.a_emb = 0.4; end
L = plane(L, mat);
R.L = L;
R.theta = L.theta;
Rh = opt_R(L.s_hmin, L.s_hmax);
dKth_h = mat.dKth(max(Rh, 0));
R.R_hcf = Rh;  R.dKth_hcf = dKth_h;  R.dKth_lcf = mat.dKth(0);
% initial flaw
[R.dK_lcf0, R.dKh0] = Ks(L, L.a0, L.c0, mat);
R.Klim0 = max(Kpts(L, L.a0, L.c0, L.s_lim));
% growth from the initial flaw (a through crack of half-length c0 when the anomaly is deeper than 0.8 t)
R.through0 = L.a0 >= 0.8 * L.t;
if R.through0
    [R.N, R.c_f, R.mode] = grow_through(L, L.c0, mat, dKth_h, opt);  R.a_f = L.t;  R.path = [0 L.t L.c0];
    R.a_hcf = scan_through(@(c) Kth(L, c, L.s_hmax) - max(Kth(L, c, L.s_hmin), 0) >= dKth_h, L);
    R.a_c = scan_through(@(c) Kth(L, c, L.s_lim) >= mat.KIC, L);
    R.a_fail = min([R.a_hcf, R.a_c, L.b]);
else
    [R.N, R.a_f, R.c_f, R.mode, R.path] = grow(L, L.a0, L.c0, mat, dKth_h, opt);
    % failure sizes along the initial shape: the HCF threshold size, the critical size
    R.a_hcf = scan(@(a, c) max(Kh(L, a, c)) >= dKth_h, L, L.a0 / L.c0);
    R.a_c = scan(@(a, c) max(Kpts(L, a, c, L.s_lim)) >= mat.KIC, L, L.a0 / L.c0);
    R.a_fail = min([R.a_hcf, R.a_c, 0.8 * L.t]);
end
% embedded flaw (CS-E 515(a)): a penny crack of the UT acceptance size (radius a_e) in the plane of the location
R.emb = embedded(L, mat, dKth_h, opt.a_emb);
R.meets = R.N >= opt.target;
% inspection: growth from each detectable pair that applies to the wall (depth below t); the worse pair governs;
% 0 where the detectable crack already meets a failure condition
% a pair deeper than 0.8 t is a through crack of its length c, with the shell bulging factor; the NASA-STD-5009C
% thickness limit of the method adds a through crack of half-length L.thin
ndt = L.ndt;  thr = ndt(:, 1) >= 0.8 * L.t;
if L.thin > 0, ndt(end + 1, :) = [L.t L.thin];  thr(end + 1) = true; end
L.ndt = ndt;  R.ndt_used = ndt;  R.ndt_through = thr;
nd = size(ndt, 1);
R.N_det = nan(nd, 1);  R.det_af = nan(nd, 2);  R.det_mode = strings(nd, 1);
for k = 1:nd
    if thr(k)
        [R.N_det(k), R.det_af(k, 2), R.det_mode(k)] = grow_through(L, ndt(k, 2), mat, dKth_h, opt);  R.det_af(k, 1) = L.t;
    else
        [R.N_det(k), R.det_af(k, 1), R.det_af(k, 2), R.det_mode(k)] = grow(L, ndt(k, 1), ndt(k, 2), mat, dKth_h, opt);
    end
end
R.det_applies = ~isnan(R.N_det);
% NDT margin: the HCF threshold depth along the shape of each pair over its depth (rule_ndt); the smallest governs
R.a_hcf_det = nan(nd, 1);
for k = find(R.det_applies & ~thr)'
    R.a_hcf_det(k) = scan(@(a, c) max(Kh(L, a, c)) >= dKth_h, L, L.ndt(k, 1) / L.ndt(k, 2));
end
R.ndt_ratio_shape = min(min(R.a_hcf_det, 0.8 * L.t) ./ L.ndt(:, 1));
if ~any(R.det_applies), R.N_det(:) = 0; end
[R.N_insp, R.k_det] = min(R.N_det, [], 'omitnan');
R.a_det = L.ndt(R.k_det, 1);
R.af_det = R.det_af(R.k_det, :);
R.mode_det = R.det_mode(R.k_det);
R.interval_tbo = floor(0.5 * R.N_insp / opt.cyc_tbo);
% NDT margin of the design rule: a_HCF (anomaly shape, capped at 0.8 t) over the depth of the deepest pair that
% applies
if R.through0
    R.ndt_ratio = 0;                                    % the anomaly itself is a through crack
elseif any(R.det_applies)
    R.ndt_ratio = min(R.a_hcf, 0.8 * L.t) / max(L.ndt(R.det_applies, 1));
else
    R.ndt_ratio = 0;
end
end

function L = plane(L, mat)
% crack plane (1 deg steps over -89..90 deg) and the stresses on it
th = (-89:90)' * pi / 180;
sn = @(X) X(:, 1)' .* cos(th).^2 + X(:, 2)' .* sin(th).^2 + X(:, 3)' .* sin(2 * th);   % one column per state
S = L.S;
h = sn([S.hmax; S.hmin]);  hi = max(h, [], 2);  lo = min(h, [], 2);
e = max(hi - max(lo, 0), 0);
R = lo ./ hi;  R(hi <= 0) = 0;
dk = arrayfun(@(r) mat.dKth(max(r, 0)), R);
l = sn([S.lcf_max; S.lcf_min]);  lr = max(max(l, [], 2) - max(min(l, [], 2), 0), 0);
score = round(e ./ dk, 9) + 1e-12 * lr;                 % ties broken by the LCF range
[~, i] = max(score);
L.theta = th(i) * 180 / pi;
L.s_hmax = hi(i);  L.s_hmin = lo(i);
L.s_lcf = max(l(i, :));  L.s_lcf_min = min(l(i, :));
L.s_lim = max(sn(S.lim(:, :)), [], 2);  L.s_lim = L.s_lim(i);
end

function R = opt_R(smin, smax)
R = smin / smax;
end

function K = Kpts(L, a, c, s)
% K at [deepest, surface] points for an outer-fibre stress s; lengths in mm, K in MPa sqrt(m)
K = zeros(1, 2);
ph = [pi / 2, 0];
for j = 1:2
    [Ft, Fb, Q] = sf_nr(L.kind, a, c, L.t, L.b, ph(j));
    K(j) = s * ((1 + L.g) / 2 * Ft + (1 - L.g) / 2 * Fb) * sqrt(pi * a * 1e-3 / Q);
end
end

function dK = Kh(L, a, c)
% effective HCF range at both points: K_max - max(K_min, 0)
Kx = Kpts(L, a, c, L.s_hmax);  Kn = Kpts(L, a, c, L.s_hmin);
dK = Kx - max(Kn, 0);
end

function [dKl, dKh] = Ks(L, a, c, mat) %#ok<INUSD>
dKl = Kl(L, a, c);
dKh = Kh(L, a, c);
end

function dK = Kl(L, a, c)
% LCF range at both points: K_max - max(K_min, 0)
dK = Kpts(L, a, c, L.s_lcf) - max(Kpts(L, a, c, L.s_lcf_min), 0);
end

function K = Kth(L, c, s)
% through crack of half-length c [mm] under the outer-fibre stress s, with the shell bulging factor
M = 1;
if L.R_shell > 0, M = sqrt(1 + 1.61 * c^2 / (L.R_shell * L.t)); end
K = s * sqrt(pi * c * 1e-3) * M;
end

function c_f = scan_through(test, L)
% smallest half-length at which test(c) is true, up to the half-width b; Inf if none
cc = linspace(0.005, L.b, 4000);
k = find(arrayfun(test, cc), 1);
if isempty(k), c_f = Inf; return, end
if k == 1, c_f = cc(1); return, end
lo = cc(k - 1);  hi = cc(k);
for it = 1:40
    mid = (lo + hi) / 2;
    if test(mid), hi = mid; else, lo = mid; end
end
c_f = hi;
end

function [N, c, mode] = grow_through(L, c, mat, dKth_h, opt)
% LCF growth of a through crack by Paris from the first cycle; stops at the first failure condition
N = 0;  mode = "";
for it = 1:200000
    if Kth(L, c, L.s_hmax) - max(Kth(L, c, L.s_hmin), 0) >= dKth_h, mode = "HCF threshold (through)"; break, end
    if Kth(L, c, L.s_lim) >= mat.KIC, mode = "K_IC at the limit load (through)"; break, end
    if c >= L.b, mode = "ligament"; break, end
    dK = Kth(L, c, L.s_lcf) - max(Kth(L, c, L.s_lcf_min), 0);
    if dK <= 0, N = Inf; mode = "no LCF growth"; break, end
    rate = mat.C * dK^mat.m * 1e3;
    dN = opt.da * c / rate;
    cm = c + rate * dN / 2;
    rm = mat.C * (Kth(L, cm, L.s_lcf) - max(Kth(L, cm, L.s_lcf_min), 0))^mat.m * 1e3;
    c = c + rm * dN;  N = N + dN;
end
end

function E = embedded(L, mat, dKth_h, a)
% penny crack of radius a [mm] in the plane of the location: HCF margin, threshold radius, LCF cycles to it
de = L.s_hmax - max(L.s_hmin, 0);  dl = L.s_lcf - max(L.s_lcf_min, 0);
Y = 2 / pi * sqrt(pi * 1e-3);                           % K = Y sigma sqrt(a [mm])
E.a0 = a;
E.margin = dKth_h / max(Y * de * sqrt(a), eps);
E.a_hcf = pi * dKth_h^2 / (4 * max(de, eps)^2) * 1e3;    % mm
if E.a_hcf <= a
    E.N = 0;
elseif dl <= 0
    E.N = Inf;
else
    k = mat.C * (Y * dl)^mat.m;                          % da/dN = k a^(m/2), a in mm with the 1e3 below
    e = 1 - mat.m / 2;
    E.N = (E.a_hcf^e - a^e) / (e * k * 1e3);
end
end

function a_f = scan(test, L, r)
% smallest depth on the shape a / c = r at which test(a, c) is true (bisection after a coarse scan); Inf if none
% below 0.8 t (and, for a corner crack, below c/b = 0.5, the range of sf_nr)
amax = 0.8 * L.t;
if strcmp(L.kind, 'corner'), amax = min(amax, 0.4999 * L.b * r); end
aa = linspace(0.02 * L.t, amax, 200);
k = find(arrayfun(@(a) test(a, a / r), aa), 1);
if isempty(k), a_f = Inf; return, end
if k == 1, a_f = aa(1); return, end
lo = aa(k - 1);  hi = aa(k);
for it = 1:40
    mid = (lo + hi) / 2;
    if test(mid, mid / r), hi = mid; else, lo = mid; end
end
a_f = hi;
end

function [N, a, c, mode, path] = grow(L, a, c, mat, dKth_h, opt)
% LCF growth by Paris from the first cycle (no threshold), point by point; stops at the first failure condition
N = 0;  mode = "";  path = [0 a c];
for it = 1:200000
    if max(Kh(L, a, c)) >= dKth_h, mode = "HCF threshold"; break, end
    if max(Kpts(L, a, c, L.s_lim)) >= mat.KIC, mode = "K_IC at the limit load"; break, end
    if a >= 0.8 * L.t, mode = "depth 0.8 t"; break, end
    rate = mat.C * Kl(L, a, c).^mat.m * 1e3;           % mm per cycle at [deepest, surface]
    if all(rate <= 0), N = Inf; mode = "no LCF growth"; break, end
    dN = min(opt.da * [a c] ./ max(rate, eps));
    % midpoint (second order) step
    am = a + rate(1) * dN / 2;  cm = c + rate(2) * dN / 2;
    rm = mat.C * Kl(L, am, cm).^mat.m * 1e3;
    a = a + rm(1) * dN;  c = c + rm(2) * dN;  N = N + dN;
    assert(a / c <= 1.2 || strcmp(L.kind, 'surface'), 'sf_dt: corner crack beyond a/c 1.2');
    if mod(it, 20) == 0, path(end + 1, :) = [N a c]; end %#ok<AGROW>
end
path(end + 1, :) = [N a c];
end
