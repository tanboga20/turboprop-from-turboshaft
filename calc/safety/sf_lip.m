function Lp = sf_lip(in)
%SF_LIP  Catcher lip and nose cover P116: LD-04 strength (clamped annular plate) and mass, run-down rub (2-D r-z).
%   Lp = sf_lip(in)   in = sf_inputs
%
%   Strength (LD-04 pull-out, limit 20 kN, ultimate 1.5 x): the lip disc as an annular plate clamped at the skirt
%   (r_root) and free at its bore (r_in), loaded by the collar as a line load at the bore (axisymmetric plate theory:
%   slope theta = K (r ln r / 2 - r / 4) + A r / 2 + B / r with K = W / (2 pi D); theta(r_root) = 0, M_r(r_in) = 0);
%   the larger of M_r at the root and M_t at the bore, sigma = 6 M / t^2. The disc thickness is the smallest 0.1 mm
%   step with yield at limit and a reserve factor of at least rf_ult on F_tu at ultimate (a fitting factor); the
%   envelope follows it (skirt r 84-94, z 512-519; disc r 66-84 from z 519 - t to 519). Bolts in tension with a
%   prying factor. Mass of the disc and the skirt.
%   Run-down rub (after an E7 shutdown, or an NJ1024 failure, the pull-out drag puts the collar on the lip): a
%   transient 2-D r-z model (explicit finite volumes, axisymmetric) of the lip disc and the collar, in contact over
%   r 66-72; frictional heat mu p v(r) at the contact, speed and drag falling linearly over t_feather; the split
%   between the bodies solved by the shared contact (and a one-sided case with all the heat in the lip); the outer
%   edge of the lip at the P111 face and the collar bore at the shaft held at T0 (the dry side of the face seal). The
%   hottest contact temperature against the temperature at which the hot yield of the lip still carries the drag;
%   q_rub7 is a residual when it holds, 1 when it does not.
%   Source: Phase 3 report, Section 3.7 (D1, G1b).

L = in.ft.lip;  g = L.geom;  r = L.rub;  th = L.thermal;
Fl = in.ft.tube.F_lim;  Fu = Fl * in.ft.tube.fu;
a = g.r_root * 1e-3;  b = g.r_in * 1e-3;  nu = 0.34;
M1 = plate(a, b, nu);                                    % moment per unit length for W = 1 N
sig = @(F, t) 6 * F * M1 / (t * 1e-3)^2 / 1e6;           % MPa
t = g.t_min;
while sig(Fl, t) > g.Fty || sig(Fu, t) * g.rf_ult > g.Ftu, t = t + 0.1; end
t = round(t * 10) / 10;
Lp.t = t;  Lp.s_lim = sig(Fl, t);  Lp.s_ult = sig(Fu, t);  Lp.rf_ult = g.Ftu / Lp.s_ult;
Lp.t_req = t;
Lp.tau = Fu / (2 * pi * g.r_in * t);
Lp.rz = [84 512; 94 512; 94 519; 66 519; 66 519 - t; 84 519 - t];
A_disc = pi * (g.r_root^2 - g.r_in^2);
A_skirt = pi * (g.r_out^2 - g.r_root^2) - g.n_bolt * pi / 4 * g.d_hole^2;
m_disc = A_disc * t * g.rho;  m_skirt = A_skirt * 7 * g.rho;
Lp.m_disc = m_disc;  Lp.m_cover = m_disc + m_skirt;  Lp.m_total = Lp.m_cover + L.m_collar + L.m_fast;
Lp.cover_ok = Lp.m_cover <= L.m_cover_max;
bo = g.bolt;
Fb = @(F) F * bo.prying / g.n_bolt;
Lp.bolt_s_lim = Fb(Fl) / bo.As;  Lp.bolt_s_ult = Fb(Fu) / bo.As;
Lp.bolt_ok = Lp.bolt_s_lim <= bo.Fty && Lp.bolt_s_ult <= bo.Ftu;
% run-down rub: 2-D model, the shared contact and the one-sided case
[Lp.T_max, Lp.E_rundown, Lp.share_ti] = rub(L, t, false);
Lp.T_max_onesided = rub(L, t, true);
Lp.T_rundown = Lp.T_max;
Lp.s_drag = sig(r.F_wm, t);
Lp.sy_hot = interp1(th.sy_T(:, 1), th.sy_T(:, 2), min(Lp.T_max, th.sy_T(end, 1)));
Lp.rundown_ok = Lp.sy_hot >= Lp.s_drag;
Lp.T_cap = interp1(th.sy_T(:, 2), th.sy_T(:, 1), min(Lp.s_drag, th.sy_T(1, 2)));   % where the hot yield meets the drag
Lp.q_rub7 = r.q_resid;
if ~Lp.rundown_ok, Lp.q_rub7 = 1; end
end

function M = plate(a, b, nu)
% annular plate clamped at r = a, free at r = b, unit total line load at the bore: largest |M| per unit length
K = 1 / (2 * pi);                                        % W / (2 pi) with W = 1 (D cancels)
th = @(r, A, B) K * (r .* log(r) / 2 - r / 4) + A * r / 2 + B ./ r;
dth = @(r, A, B) K * (log(r) / 2 + 1 / 4) + A / 2 - B ./ r.^2;
% theta(a) = 0; dth(b) + nu theta(b) / b = 0
Mx = [a / 2, 1 / a; 1 / 2 + nu / 2, -1 / b^2 + nu / b^2];
rhs = [-K * (a * log(a) / 2 - a / 4); -K * (log(b) / 2 + 1 / 4) - nu * K * (log(b) / 2 - 1 / 4)];
x = Mx \ rhs;  A = x(1);  B = x(2);
Mr_a = abs(dth(a, A, B));                                % D = 1: M_r = -(theta' + nu theta / r), theta(a) = 0
Mt_b = abs(nu * dth(b, A, B) + th(b, A, B) / b);
M = max(Mr_a, Mt_b);
end

function [Tmax, E, share] = rub(L, t, onesided)
% transient 2-D r-z rub of the lip disc and the collar [degC, J, -]
r = L.rub;  th = L.thermal;  g = L.geom;
dr = th.dr;  nz = th.nz;
ti = r.ti;  st = r.steel;                                 % [k rho c]
% lip: r 66-84 mm, nz layers over t; collar: r 60-72 mm, nz layers over its height
rl = (g.r_in * 1e-3 + dr / 2):dr:(g.r_root * 1e-3);  nl = numel(rl);  dzl = t * 1e-3 / nz;
rc = (60e-3 + dr / 2):dr:(72e-3);  nc = numel(rc);  dzc = th.collar_h / nz;
Tl = th.T0 * ones(nz, nl);  Tc = th.T0 * ones(nz, nc);
band_l = rl <= 72e-3;  band_c = rc >= g.r_in * 1e-3;     % contact r 66-72 mm
w0 = r.n0 * pi / 30;  dt = th.dt;  n = round(r.t_feather / dt);
A_band = pi * ((72e-3)^2 - (g.r_in * 1e-3)^2);
E = 0;  Eti = 0;  Tmax = th.T0;
al = ti(1) / (ti(2) * ti(3));  ac = st(1) / (st(2) * st(3));
for i = 1:n
    x = (i - 0.5) / n;
    w = w0 * (1 - (1 - r.n_f) * x);  F = r.F_wm * (1 - (1 - r.F_f / r.F_wm) * x);
    q = r.mu * F / A_band * w * rl(band_l);              % W/m2 at the lip contact nodes
    Tl = step2d(Tl, rl, dr, dzl, al, 'outer', th.T0, dt);
    Tc = step2d(Tc, rc, dr, dzc, ac, 'inner', th.T0, dt);
    if onesided
        Tl(end, band_l) = Tl(end, band_l) + q * dt / (ti(2) * ti(3) * dzl);
        Eti = Eti + sum(q .* 2 * pi .* rl(band_l) * dr) * dt;
    else
        % shared contact: the heat goes into both contact layers, which then share one temperature
        Cl = ti(2) * ti(3) * dzl;  Cc = st(2) * st(3) * dzc;
        Tc_b = interp1(rc, Tc(1, :), rl(band_l), 'linear', 'extrap');
        Tm = (Cl * Tl(end, band_l) + Cc * Tc_b + q * dt) / (Cl + Cc);
        Eti = Eti + sum((Tm - Tl(end, band_l)) * Cl .* 2 * pi .* rl(band_l) * dr);
        Tl(end, band_l) = Tm;
        Tc(1, band_c) = interp1(rl(band_l), Tm, rc(band_c), 'linear', 'extrap');
    end
    E = E + sum(q .* 2 * pi .* rl(band_l) * dr) * dt;
    Tmax = max([Tmax, max(Tl(:)), max(Tc(:))]);
end
share = Eti / E;
end

function T = step2d(T, r, dr, dz, al, fixed, T0, dt)
% explicit axisymmetric conduction step (zero-flux faces, T0 held at the outer edge of the lip or the collar bore)
[nz, nr] = size(T);
Tp = [T(:, 1), T, T(:, end)];
rr = [r(1) - dr, r, r(end) + dr];
lap_r = zeros(nz, nr);
for j = 1:nr
    rp = (rr(j + 1) + rr(j + 2)) / 2;  rm = (rr(j + 1) + rr(j)) / 2;
    lap_r(:, j) = (rp * (Tp(:, j + 2) - Tp(:, j + 1)) - rm * (Tp(:, j + 1) - Tp(:, j))) / (r(j) * dr^2);
end
Tz = [T(1, :); T; T(end, :)];
lap_z = (Tz(3:end, :) - 2 * T + Tz(1:end - 2, :)) / dz^2;
T = T + al * dt * (lap_r + lap_z);
if strcmp(fixed, 'outer'), T(:, end) = T0; else, T(:, 1) = T0; end
end
