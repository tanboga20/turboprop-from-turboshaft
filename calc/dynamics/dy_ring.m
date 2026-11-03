function G = dy_ring(in, W, frot, Ar, ie, mu, sc)
%DY_RING  Friction damping of a split ring of section Ar in groove ie of the first-stage gear (dy_web families).
%   G = dy_ring(in, W, frot, Ar, ie, mu)
%   G = dy_ring(in, W, frot, Ar, ie, mu, sc)
%
%   W = dy_web output (W.fam: the in-band families with their resonance
%   speeds x_lo, x_hi, and for both shuttle brackets the input energy Win
%   and the groove slip at each groove position; the worse bracket counts); frot [Hz] at 100%; Ar [m^2] ring
%   section; ie = groove position (index into in.ring.e_list); mu friction;
%   sc = [a_u a_W] (default [1 1]) scales the slips and the input energy
%   (excitation x k: [k k^2]; modal damping / k: [k k]).
%   The thin split ring follows the groove radially and is nearly
%   inextensible, so the slip is u_theta - v with dv/dtheta = -u_r (dy_web).
%   It slips where the slip exceeds the macroslip limit
%   u_stick = mu rho (x Omega)^2 R^3 / (E n^2) plus the contact pre-sliding
%   in.ring.u_pre mu / 0.15 (TBR), taken at each in-band
%   crossing speed x (it does not depend on the section). A family slips
%   when its mean slip exceeds u_stick at its highest crossing.
%   Amplitude ratio with the ring: s solves s Win = s^2 Win + E_f(s),
%   E_f(s) = 4 mu q R integral of max(s |slip| - u_stick, 0) dtheta with
%   q = rho A (x Omega)^2 R (threshold dissipation, no microslip;
%   bisection). This is the larger s of the crossings, standing wave.
%   Travelling wave: half the standing peak all round (mean slip x pi / 4),
%   Win / 2. s cannot fall below the stick floor s_stick = u_stick /
%   max |slip at s = 1|, however large the ring.
%   Output G: per family (column vectors) u_slip [um], u_stick_hi [um],
%   slips, slips_trav, A_req [mm^2] (E_f = 2 Win at x_lo, for reference),
%   EfW (full-slip E_f / Win at x_lo), s, s_trav, s_stick; and s_max,
%   s_trav_max over the families that slip.
%   Source: Phase 3 report, Section 3.6 ("Damping ring").

F = W.fam;  rr = in.ring;
Om = 2 * pi * frot;  Rg = F.Rg;
nf = numel(F.f);
th = [F.th, pi];
if nargin < 7, sc = [1 1]; end
us = @(x, n_) mu * rr.rho * (x * Om)^2 * Rg^3 / (rr.E * max(n_, 1)^2) + rr.u_pre * mu / 0.15;
G.u_slip = sc(1) * max(F.I(:, :, ie), [], 2) / (2 * pi * Rg) * 1e6;   % the larger of the two shuttle brackets
G.u_stick_hi = zeros(nf, 1);  G.s = ones(nf, 1);  G.s_trav = G.s;  G.s_stick = zeros(nf, 1);
G.EfW = zeros(nf, 1);  G.A_req = zeros(nf, 1);
for k = 1:nf
    n_ = F.n(k);
    G.u_stick_hi(k) = us(F.x_hi(k), n_) * 1e6;
    if n_ == 0, continue, end                         % the ring follows n = 0
    sk = 0;  stk = 0;  sst = 0;  efw = Inf;  areq = 0;
    for b = 1:2                                       % shuttle in phase / in antiphase: the worse
        Win = sc(2) * F.Win(k, b);  I = sc(1) * F.I(k, b, ie);
        ug = sc(1) * [F.UG(k, :, b, ie), F.UG(k, 1, b, ie)];
        ut = I / (2 * pi * Rg) * pi / 4;
        efw = min(efw, 4 * mu * rr.rho * Ar * (F.x_lo(k) * Om)^2 * Rg * I / Win);
        areq = max(areq, 2 * Win / (4 * mu * rr.rho * (F.x_lo(k) * Om)^2 * Rg * I) * 1e6);
        for x = unique([F.x_lo(k), F.x_hi(k)])
            q = rr.rho * Ar * (x * Om)^2 * Rg;  ux = us(x, n_);
            Ef = @(sc) 4 * mu * q * Rg * trapz(th, max(sc * ug - ux, 0));
            Eft = @(sc) 4 * mu * q * Rg * 2 * pi * max(sc * ut - ux, 0);
            sk = max(sk, balance(Win, Ef));
            stk = max(stk, balance(Win / 2, Eft));
            sst = max(sst, min(ux / max(ug), 1));
        end
    end
    G.s(k) = sk;  G.s_trav(k) = stk;  G.s_stick(k) = sst;  G.EfW(k) = efw;  G.A_req(k) = areq;
end
G.slips = G.u_slip > G.u_stick_hi & F.n > 0;
G.slips_trav = G.u_slip * pi / 4 > G.u_stick_hi & F.n > 0;
G.s_max = max([G.s(G.slips); 0]);
G.s_trav_max = max([G.s_trav(G.slips); 0]);
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
