function W = dy_web(in, pw, band, frot, fm, Ld)
%DY_WEB  Forced response of the first-stage gear blank to the mesh (DYN-03, DYN-04) and its friction damping ring.
%   W = dy_web(in, pw, band, frot, fm, Ld)
%
%   in = dy_inputs; pw = the blank (r_bore, r_hub, r_rim, r_out, t_web, b,
%   L_hub [mm], E, nu, rho; optional rho_rim, a density factor on the rim
%   piece for the teeth-as-mass bracket); band = [f1 f2] Hz, the 1x mesh
%   band with the speed range; frot [Hz] and fm [Hz], gear speed and mesh
%   frequency at 100%; Ld = mesh loads: Fb = [Fb1 Fb2] [N], dynamic force
%   along the transverse line of action of the 1x and 2x harmonics (k TE_h);
%   alpha (working transverse pressure angle); tbb = tan(beta_b); Fs =
%   [F_t F_r F_a] [N], the static mesh force; dZ = [dZ1 dZ2] [m], the axial
%   shuttle of the contact-line centroid (dy_shuttle); k [N/m], the mesh
%   stiffness.
%   The blank is axisymmetric (rim to r_out, held at its bore), so it is
%   solved one circumferential harmonic at a time (dy_axi_km, n = 0 ...
%   in.n_harm) on a fine 2-D section mesh (in.h_axi). The patch load
%   (in.dpsi_web of the rim face) is split into harmonics. Radial and axial
%   tractions load the family u_r ~ cos n theta; the tangential traction
%   loads the family turned by pi / (2 n) (n = 0: torsion).
%   1. Modes of each harmonic up to in.f_cut x the top of the 2x band, in-
%      plane and out-of-plane (axial share at mid-web > 0.5). A family is in
%      the band of mesh harmonic h if f lies in h x band widened by n frot.
%   2. Excitation of harmonic h: the dynamic force Fb_h along the line of
%      action (radial, tangential and axial parts, uniform on the patch),
%      plus the shuttle moments F_t dZ_h (about the radial axis) and F_r dZ_h
%      (about the tangential axis) as face-linear tractions. The shuttle is
%      bracketed in phase and in antiphase with the TE force (sgn = +1 /
%      -1); sgn = 0 is TE only.
%   3. Response at each in-band family frequency: modal superposition over
%      the modes of step 1 plus the static residual, modal damping
%      in.zeta_web. Outputs:
%      - sig_far: von Mises amplitude on the boundary outside in.r_corner
%        of the sharp corners;
%      - sig_nom: nominal stress at the web roots, linearised over the web
%        thickness half a thickness from the hub and from the rim (x
%        in.Kt_fillet for the drawing fillet);
%      - Win = pi F' Im(-u), the input energy per cycle;
%      - the slip of the ring at the groove line.
%      Ring kinematics: the thin split ring follows the groove radially and
%      is nearly inextensible. Its tangential displacement is v with
%      dv/dtheta = -u_r, so the slip is u_theta - v, per harmonic (V + U / n).
%      For n = 0 the ring follows (the split opens; in torsion its inertia
%      is far below the friction), so n = 0 cannot be damped.
%   4. Ring:
%      - resonance speeds x = f / (h fm +- n frot) inside band / fm; the
%        preload q = rho A (x Omega)^2 R and the macroslip limit
%        mu q R^2 / (E A n^2) at those speeds;
%      - a family slips when its mean slip exceeds that limit at the
%        highest crossing;
%      - rule 1: E_f = 4 mu q I >= k_size W_in at the lowest crossing,
%        standing wave, worst bracket;
%      - if rule 1 needs more than in.ring.m_max, rule 2: the lightest ring
%        with s <= in.ring.s_max for every slipping family on the worst
%        bracket;
%      - s solves s W_in = s^2 W_in + E_f(s) with threshold dissipation
%        (bisection); travelling wave: half the standing peak all round
%        (slip x pi / 4, W_in / 2); zeta_eq = zeta_web / s.
%   5. The static mesh force sits at a fixed azimuth, so the rotating web
%      sees it once per revolution: mean (n = 0) and alternating stress,
%      combined with the largest vibratory stress by Goodman
%      (in.sigma_e.P53, in.su.P53), at the web roots (nominal x Kt) and on
%      the boundary.
%   6. First-order shift of each family by the mesh stiffness along the line
%      of action at the patch (a bound: the pinion is rigid here).
%   With in.ring.h_mass > 0 the fitted ring is a line mass at the groove
%   (radial and axial). With in.web_modes_only only the modes are returned.
%   Output W: modes table, inband table (one row per family and mesh
%   harmonic), ring, check (modal against direct), ref_axial (axial TE load
%   only, for the 3-D check), once_rev, mass, n_dof.
%   Source: Phase 3 report, Section 3.6 ("First-stage gear web").

p = pw;
sec = [p.r_bore p.r_hub (p.b - p.L_hub) / 2 (p.b + p.L_hub) / 2;
       p.r_hub p.r_rim (p.b - p.t_web) / 2 (p.b + p.t_web) / 2;
       p.r_rim p.r_out 0 p.b];
A = dy_axi_mesh(sec, in.h_axi);
X = A.X;  nn = size(X, 2);  T = A.T;  ne = size(T, 2);
r = X(1, :);  z = X(2, :);
rc = (r(T(1, :)) + r(T(2, :)) + r(T(3, :))) / 3;
rho_e = p.rho * ones(1, ne);
if isfield(p, 'rho_rim'), rho_e(rc > p.r_rim / 1000) = p.rho * p.rho_rim; end
v_ = @(a) X(:, T(a, :));  d1 = v_(2) - v_(1);  d2 = v_(3) - v_(1);
ar = abs(d1(1, :) .* d2(2, :) - d1(2, :) .* d2(1, :)) / 2;
W.mass = 2 * pi * sum(rho_e .* ar .* rc);
W.n_dof = 3 * nn;
iu = 1:3:3 * nn;  iv = 2:3:3 * nn;  iw = 3:3:3 * nn;
fixed = abs(r - p.r_bore / 1000) < 1e-9;
zw = [p.b - p.t_web, p.b + p.t_web] / 2000;
rm = (p.r_hub + p.r_rim) / 2000;
sel = abs(r - rm) < 0.004 & z >= zw(1) - 1e-9 & z <= zw(2) + 1e-9;
Rg = p.r_rim / 1000;  zg = p.b / 2000 + in.ring.e;
on_bore = find(abs(r - Rg) < 1e-9 & (z < zw(1) - 1e-9 | z > zw(2) + 1e-9));
[~, k] = min(abs(z(on_bore) - zg));  ig = on_bore(k);      % the fitted ring (its mass)
ige = zeros(1, numel(in.ring.e_list));                     % groove positions tried: slip at each
for k = 1:numel(ige), [~, i] = min(abs(z(on_bore) - (p.b / 2000 + in.ring.e_list(k))));  ige(k) = on_bore(i); end
nge = numel(ige);
% stress points: the boundary outside r_corner of the four sharp corners, and the web-root sections half a
% web thickness from the hub and from the rim (linearised over the thickness)
crn = [[p.r_hub p.r_hub p.r_rim p.r_rim] / 1000; zw(1) zw(2) zw(1) zw(2)];
bnd = unique(A.E(:));
far = bnd(min(pdist2(X(:, bnd)', crn'), [], 2) > in.r_corner);
rs = [p.r_hub + p.t_web / 2, p.r_rim - p.t_web / 2] / 1000;
Lin = cell(1, 2);  Nsec = cell(1, 2);
for s = 1:2
    ns = find(abs(r - rs(s)) <= 0.6 * in.h_axi / 1000 & z >= zw(1) - 1e-9 & z <= zw(2) + 1e-9);
    Ab = [ones(numel(ns), 1), z(ns)' - mean(zw)];
    Lin{s} = [1, -p.t_web / 2000; 1, p.t_web / 2000] * (Ab \ eye(numel(ns)));   % face values from the nodes
    Nsec{s} = ns;
end
spts = unique([far(:); Nsec{1}(:); Nsec{2}(:)]);
[~, ifar] = ismember(far, spts);
isec = cell(1, 2);  for s = 1:2, [~, isec{s}] = ismember(Nsec{s}, spts); end
srow = reshape(6 * (spts(:)' - 1) + (1:6)', [], 1);
% patch load: nodal integrals over the rim face r = r_out of a uniform and of a face-linear traction
dth = deg2rad(in.dpsi_web);
Rp = p.r_out / 1000;  bm = p.b / 1000;
Ap = Rp * dth * bm;  Ip = Rp * dth * bm^3 / 12;
Eo = A.E(:, all(abs(reshape(r(A.E), size(A.E)) - Rp) < 1e-9, 1));
f0 = zeros(nn, 1);  f1 = f0;
gp = [-sqrt(3 / 5), 0, sqrt(3 / 5)];  gw = [5 9 5] / 9;
for e = 1:size(Eo, 2)
    za = z(Eo(1, e));  L = z(Eo(2, e)) - za;
    for q = 1:3
        xi = (gp(q) + 1) / 2;                         % 0 at the first corner, 1 at the second; mid-side node third
        N = [(1 - xi) * (1 - 2 * xi); xi * (2 * xi - 1); 4 * xi * (1 - xi)];
        f0(Eo(:, e)) = f0(Eo(:, e)) + gw(q) / 2 * abs(L) * Rp * N;
        f1(Eo(:, e)) = f1(Eo(:, e)) + gw(q) / 2 * abs(L) * Rp * N * (za + xi * L - bm / 2);
    end
end
f_cut = in.f_cut * 2 * band(2);
nh = 0:in.n_harm;
H = struct('n', {}, 'K', {}, 'M', {}, 'S', {}, 'free', {}, 'phi', {}, 'w', {}, 'B', {}, 'Us', {});
rows = [];
for j = 1:numel(nh)
    n = nh(j);
    [K, M, Sg] = dy_axi_km(A, n, p.E, p.nu, rho_e);
    if in.ring.h_mass > 0                             % the fitted ring as a line mass at the groove, radial and axial
        mr = (pi + pi * (n == 0)) * in.ring.rho * in.ring.h_mass * in.ring.w * Rg;
        M(3 * ig - 2, 3 * ig - 2) = M(3 * ig - 2, 3 * ig - 2) + mr;
        M(3 * ig, 3 * ig) = M(3 * ig, 3 * ig) + mr;
    end
    free = setdiff(1:3 * nn, [iu(fixed), iv(fixed), iw(fixed)]);
    Kf = K(free, free);  Mf = M(free, free);
    % unit load bases of this harmonic: radial uniform / linear, axial uniform, tangential uniform / linear
    cn = dth / (2 * pi);  wt = 2 * pi;
    if n > 0, cn = 2 / (n * pi) * sin(n * dth / 2);  wt = pi; end
    B = zeros(3 * nn, 5);
    B(iu, 1) = f0;  B(iu, 2) = f1;  B(iw, 3) = f0;  B(iv, 4) = f0;  B(iv, 5) = f1;
    B = cn * wt * B(free, :);
    Us = Kf \ B;
    nm = 20;
    while true
        [V, L2] = eigs(Kf, Mf, nm, 'smallestabs');
        [w2, o] = sort(real(diag(L2)));  V = V(:, o);
        if sqrt(w2(end)) / (2 * pi) > f_cut || nm >= 100, break; end
        nm = nm + 20;
    end
    keep = sqrt(w2) / (2 * pi) <= f_cut;
    V = V(:, keep);  w = sqrt(w2(keep));
    V = V ./ sqrt(sum(V .* (Mf * V), 1));
    H(j) = struct('n', n, 'K', Kf, 'M', Mf, 'S', Sg(srow, :), 'free', free, 'phi', V, 'w', w, 'B', B, 'Us', Us);
    for q = 1:numel(w)
        u = zeros(3 * nn, 1);  u(free) = V(:, q);
        ax = sum(u(iw(sel)).^2) / sum(u(iu(sel)).^2 + u(iv(sel)).^2 + u(iw(sel)).^2);
        rows = [rows; w(q) / (2 * pi), n, ax, j, q]; %#ok<AGROW>
    end
end
f = rows(:, 1);  n = rows(:, 2);  ax = rows(:, 3);
oop = ax > 0.5;
inb1 = f >= band(1) - n * frot & f <= band(2) + n * frot;
inb2 = f >= 2 * band(1) - n * frot & f <= 2 * band(2) + n * frot;
W.modes = table(f, n, ax, oop, inb1, inb2, 'VariableNames', {'f', 'n', 'ax', 'out_of_plane', 'inband1', 'inband2'});
W.f_cut = f_cut;
if isfield(in, 'web_modes_only') && in.web_modes_only, return, end

th = linspace(-pi, pi, 361);  th = th(1:end - 1);    % full circle: the tangential load breaks the mirror symmetry
nth = numel(th);
% families: one row per mode and mesh harmonic in band
fam = [find(inb1), ones(sum(inb1), 1); find(inb2), 2 * ones(sum(inb2), 1)];
nf = size(fam, 1);
R = struct('sig_far', zeros(nf, 3), 'sig_nom', zeros(nf, 3), 'Win', zeros(nf, 3), 'I', zeros(nf, 3, nge));
UG = zeros(nf, nth, 3, nge);
sg_list = [0 1 -1];
for k = 1:nf
    om = 2 * pi * f(fam(k, 1));
    for b = 1:3
        o = response(om, fam(k, 2), sg_list(b), [1 1 1], 'modal');
        R.sig_far(k, b) = o.sig_far;  R.sig_nom(k, b) = o.sig_nom;  R.Win(k, b) = o.Win;  R.I(k, b, :) = o.I;
        UG(k, :, b, :) = permute(abs(o.slip), [3 2 4 1]);
    end
end
% check: modal against direct (TE only) at the family with the largest stress, and the axial-only reference
[~, kc] = max(max(R.sig_far(:, 1), in.Kt_fillet * R.sig_nom(:, 1)));
od = response(2 * pi * f(fam(kc, 1)), fam(kc, 2), 0, [1 1 1], 'direct');
W.check = struct('f', f(fam(kc, 1)), 'n', n(fam(kc, 1)), 'h', fam(kc, 2), 'sig0_modal', R.sig_far(kc, 1), ...
                 'sig0_direct', od.sig_far, 'Win_modal', R.Win(kc, 1), 'Win_direct', od.Win, 'I_modal', R.I(kc, 1, 1), 'I_direct', od.I(1));
ko = find(oop(fam(:, 1)) & fam(:, 2) == 1);          % axial TE load only: the out-of-plane family it drives hardest
oa = [];
for k = ko'
    o = response(2 * pi * f(fam(k, 1)), 1, 0, [0 0 1], 'modal');
    if isempty(oa) || o.sig_far > oa.sig_far, oa = o;  ka = k; end
end
W.ref_axial = struct('f', f(fam(ka, 1)), 'n', n(fam(ka, 1)), 'sig_far', oa.sig_far, 'Win', oa.Win);

% resonance speeds of each family inside the band speeds band / fm
x_band = band / fm;
hh = fam(:, 2);  ff = f(fam(:, 1));  nfam = n(fam(:, 1));
xc = [ff ./ (hh * fm + nfam * frot), ff ./ (hh * fm - nfam * frot)];
xc(nfam == 0, 2) = NaN;
xc(xc < x_band(1) | xc > x_band(2)) = NaN;
x_lo = min(xc, [], 2);  x_hi = max(xc, [], 2);
x_lo(isnan(x_lo)) = 1;  x_hi(isnan(x_hi)) = 1;
% families for the ring (dy_ring): both shuttle brackets, slip at each groove position
sig_b = max(R.sig_far(:, 2:3), in.Kt_fillet * R.sig_nom(:, 2:3));
sig_bare = max(sig_b, [], 2);
mesh_df = mesh_shift();
W.fam = struct('f', ff, 'n', nfam, 'h', hh, 'x_lo', x_lo, 'x_hi', x_hi, 'Win', R.Win(:, 2:3), 'I', R.I(:, 2:3, :), ...
               'UG', UG(:, :, 2:3, :), 'th', th, 'Rg', Rg, 'z_groove', z(ige) * 1e3);
W.inband = table(ff, nfam, hh, oop(fam(:, 1)), x_lo, x_hi, R.sig_far(:, 1), R.sig_nom(:, 1), ...
                 max(R.sig_far(:, 2:3), [], 2), max(R.sig_nom(:, 2:3), [], 2), sig_bare, R.Win(:, 1), max(R.Win(:, 2:3), [], 2), ...
                 100 * mesh_df, 'VariableNames', {'f', 'n', 'h', 'oop', 'x_lo', 'x_hi', 'sig_far_te', 'sig_nom_te', ...
                 'sig_far', 'sig_nom', 'sig_bare', 'Win_te', 'Win_J', 'df_mesh_pct'});
W.once_rev = once_rev();

    function o = response(om, h_, sgn, mask, how)
        % patch load of mesh harmonic h_ at om: sgn the shuttle bracket, mask = [radial tangential axial] TE parts
        sr = zeros(nth, numel(spts), 6);
        slip = zeros(nge, nth);  Win_ = 0;
        c = coef(h_, sgn, mask, false);
        for jj = 1:numel(H)
            [sr, slip, Win_] = add_harm(H(jj), c, om, how, sr, slip, Win_);
        end
        o.sig_far = vmmax(sr(:, ifar, :));
        o.sig_nom = nominal(sr);
        o.Win = Win_;
        o.slip = slip;
        o.I = Rg * trapz([th, pi], abs([slip, slip(:, 1)]), 2);
    end
    function c = coef(h_, sgn, mask, static)
        % traction coefficients on the bases: [radial uniform, radial linear, axial, tangential uniform, linear]
        if static
            c = [-Ld.Fs(2) / Ap; 0; Ld.Fs(3) / Ap; Ld.Fs(1) / Ap; 0];
        else
            Fb = Ld.Fb(h_);
            c = [-mask(1) * Fb * sin(Ld.alpha) / Ap; -sgn * Ld.Fs(2) * Ld.dZ(h_) / Ip; mask(3) * Fb * Ld.tbb / Ap; ...
                 mask(2) * Fb * cos(Ld.alpha) / Ap; sgn * Ld.Fs(1) * Ld.dZ(h_) / Ip];
        end
    end
    function [sr, slip, Win_] = add_harm(h_, c, om, how, sr, slip, Win_)
        n_ = h_.n;
        if n_ == 0                                    % one family: radial, axial and torsion together
            [u1, F1] = solve1(h_, c, om, how);
            Win_ = Win_ - pi * real(F1' * imag(u1(h_.free)));
            s1 = reshape(h_.S * u1, 6, []);
            for cc = 1:6, sr(:, :, cc) = sr(:, :, cc) + ones(nth, 1) * s1(cc, :); end
            return                                    % the ring follows n = 0: no slip
        end
        [u1, F1] = solve1(h_, c .* [1; 1; 1; 0; 0], om, how);
        [u2, F2] = solve1(h_, -c .* [0; 0; 0; 1; 1], om, how);
        Win_ = Win_ - pi * real(F1' * imag(u1(h_.free)) + F2' * imag(u2(h_.free)));
        s1 = reshape(h_.S * u1, 6, []);  s2 = reshape(h_.S * u2, 6, []);
        cs = cos(n_ * th)';  sn = sin(n_ * th)';
        for cc = 1:4, sr(:, :, cc) = sr(:, :, cc) + cs * s1(cc, :) + sn * s2(cc, :); end
        for cc = 5:6, sr(:, :, cc) = sr(:, :, cc) + sn * s1(cc, :) - cs * s2(cc, :); end
        slip = slip + (u1(iv(ige)) + u1(iu(ige)) / n_) * sin(n_ * th) - (u2(iv(ige)) + u2(iu(ige)) / n_) * cos(n_ * th);
    end
    function [u, Ff] = solve1(h_, c, om, how)
        Ff = h_.B * c;
        u = zeros(3 * nn, 1);
        if ~any(Ff), return, end
        us = h_.Us * c;
        switch how
            case 'modal'
                g = h_.phi' * Ff;
                u(h_.free) = h_.phi * (g ./ (h_.w.^2 - om^2 + 2i * in.zeta_web * h_.w * om)) + (us - h_.phi * (g ./ h_.w.^2));
            case 'direct'
                u(h_.free) = (h_.K * (1 + 2i * in.zeta_web) - om^2 * h_.M) \ Ff;
            case 'static'
                u(h_.free) = us;
        end
    end
    function v = vmmax(s3)
        v = max(dy_vm_cycle(real(s3), imag(s3)), [], 'all') / 1e6;     % cycle maximum
    end
    function v = nominal(sr)
        % largest von Mises of the linearised web-root faces over theta (real and imaginary parts)
        v = 0;
        for s_ = 1:2
            fr = zeros(nth, 2, 6);  fi = fr;
            for cc = 1:6
                fr(:, :, cc) = real(sr(:, isec{s_}, cc)) * Lin{s_}';
                fi(:, :, cc) = imag(sr(:, isec{s_}, cc)) * Lin{s_}';
            end
            v = max(v, max(dy_vm_cycle(fr, fi), [], 'all') / 1e6);
        end
    end
    function df = mesh_shift()
        % first-order frequency shift by the mesh stiffness along the line of action, averaged over the patch
        % nodes: omega'^2 = omega^2 + k (phi . d)^2 over the pair (the cos family and the turned one)
        nd = norm([sin(Ld.alpha), cos(Ld.alpha), Ld.tbb]);
        pn = unique(Eo(:));
        df = zeros(nf, 1);
        for k_ = 1:nf
            rw = rows(fam(k_, 1), :);  h_ = H(rw(4));
            u = zeros(3 * nn, 1);  u(h_.free) = h_.phi(:, rw(5));
            a1 = mean(-sin(Ld.alpha) * u(iu(pn)) + Ld.tbb * u(iw(pn))) / nd;
            a2 = mean(cos(Ld.alpha) * u(iv(pn))) / nd;
            if h_.n == 0, a1 = a1 + a2;  a2 = 0; end
            df(k_) = sqrt(1 + Ld.k * (a1^2 + a2^2) / h_.w(rw(5))^2) - 1;
        end
    end
    function O = once_rev()
        % static mesh force at a fixed azimuth: mean (n = 0) and alternating stress seen by the rotating web, on
        % the boundary (per point) and at the web roots (nominal, linearised); Goodman in run_step36
        sr = zeros(nth, numel(spts), 6);  slip = zeros(nge, nth);  w_ = 0;
        c = coef(1, 0, [1 1 1], true);
        for jj = 1:numel(H)
            [sr, slip, w_] = add_harm(H(jj), c, 0, 'static', sr, slip, w_);
        end
        sm = mean(sr, 1);  sa = sr - sm;
        O.far_m = vmr(sm(:, ifar, :)) / 1e6;  O.far_a = max(vmr(sa(:, ifar, :)), [], 1) / 1e6;
        O.root_mean = 0;  O.root_alt = 0;
        for s_ = 1:2
            fm_ = zeros(1, 2, 6);  fa_ = zeros(nth, 2, 6);
            for cc = 1:6
                fm_(:, :, cc) = sm(:, isec{s_}, cc) * Lin{s_}';
                fa_(:, :, cc) = sa(:, isec{s_}, cc) * Lin{s_}';
            end
            O.root_mean = max(O.root_mean, max(vmr(fm_), [], 'all') / 1e6);
            O.root_alt = max(O.root_alt, max(vmr(fa_), [], 'all') / 1e6);
        end
        O.far_mean = max(O.far_m);  O.far_alt = max(O.far_a);
    end
end

function v = vmr(s)
% von Mises of real stress arrays (6 components in the third dimension)
v = sqrt(0.5 * ((s(:, :, 1) - s(:, :, 2)).^2 + (s(:, :, 2) - s(:, :, 3)).^2 + (s(:, :, 3) - s(:, :, 1)).^2) + ...
         3 * (s(:, :, 4).^2 + s(:, :, 5).^2 + s(:, :, 6).^2));
end

function s = balance(Win, Ef)
% amplitude ratio s in (0, 1] with s Win = s^2 Win + Ef(s), by bisection (Ef(s) / s grows with s)
g = @(s) s * Win * (1 - s) - Ef(s);
if Ef(1) <= 0, s = 1; return, end
a = 1e-9;  b = 1;
for it = 1:60
    m = (a + b) / 2;
    if g(m) > 0, a = m; else, b = m; end
end
s = (a + b) / 2;
end
