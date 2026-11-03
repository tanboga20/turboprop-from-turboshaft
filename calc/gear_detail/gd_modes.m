function f = gd_modes(kind, p, n_list)
%GD_MODES  Natural frequencies of gear rims and webs for the DYN-04 check.
%   f = gd_modes('ring', p, n_list)   in-plane bending modes of a free thin ring
%   f = gd_modes('web', p, n_list)    out-of-plane modes of a gear web with its rim
%
%   'ring': p has R (mean radius of the rim), h (radial rim thickness), b
%   (axial width), h_teeth (equivalent thickness of the tooth layer, adds
%   mass only) [mm], E [MPa], rho [kg/mm^3]. f(n) for n in n_list [Hz]:
%   f = n (n^2 - 1) / sqrt(n^2 + 1) sqrt(E I / (m R^4)) / (2 pi), the
%   inextensional ring modes (Hoppe), with I = b h^3 / 12 and m the mass
%   per unit length of rim plus teeth.
%
%   'web': p has r_in (hub radius, clamped), r_out (web outer radius where
%   the rim sits), t (web thickness), b_rim (axial rim width), s_rim (rim
%   radial thickness, stiffness), s_mass (rim plus tooth layer, mass),
%   E, nu, rho, ne (elements). Kirchhoff annular plate, Fourier harmonic
%   w = W(r) cos(n theta), Hermite cubic elements in r; the rim is a ring
%   on the web edge with mass, rotary inertia, out-of-plane bending and
%   torsional stiffness (its cross-section rotation equals the web slope);
%   p.bare = true leaves the rim out. f is length(n_list)-by-2: the first
%   two frequencies of each n [Hz].
%
%   Source: Phase 2 report, Section 2.4 ("Gear rims and webs, DYN-04").
%   Tested by test_step24 (TC39) against the exact Bessel solution of a
%   bare annular plate and a Rayleigh-Ritz model with the rim
%   (calc/reference/step24_reference.py).

switch kind
    case 'ring'
        I = p.b * p.h^3 / 12;                     % mm^4
        m = p.rho * p.b * (p.h + p.h_teeth);      % kg/mm
        c = sqrt(p.E * 1e6 * I * 1e-12 / (m * 1e3 * (p.R / 1000)^4));   % SI
        n = n_list(:);
        f = n .* (n.^2 - 1) ./ sqrt(n.^2 + 1) * c / (2 * pi);
    case 'web'
        f = zeros(numel(n_list), 2);
        for j = 1:numel(n_list)
            [K, Mm] = web_matrices(p, n_list(j));
            lam = sort(real(eig(K, Mm)));
            lam = lam(lam > 0);
            f(j, :) = sqrt(lam(1:2))' / (2 * pi);
        end
end
end

function [K, M] = web_matrices(p, n)
% SI units inside
r0 = p.r_in / 1000;  r1 = p.r_out / 1000;  t = p.t / 1000;
E = p.E * 1e6;  nu = p.nu;  rho = p.rho * 1e9;
D = E * t^3 / (12 * (1 - nu^2));
ne = p.ne;
nodes = linspace(r0, r1, ne + 1);
ndof = 2 * (ne + 1);
K = zeros(ndof);
M = zeros(ndof);
[gp, gw] = gauss4();
for e = 1:ne
    a = nodes(e);  L = nodes(e + 1) - a;
    idx = 2 * e - 1:2 * e + 2;
    Ke = zeros(4);  Me = zeros(4);
    for q = 1:4
        xi = gp(q);
        r = a + L * xi;
        [N, dN, d2N] = hermite(xi, L);
        A = d2N + dN / r - n^2 * N / r^2;          % Laplacian of W
        B1 = dN / r - n^2 * N / r^2;
        C = (dN / r - N / r^2);
        % strain energy density (times r): D [ A'A - (1-nu)( d2N'B1 + B1'd2N - 2 n^2 C'C ) ] r
        Ke = Ke + D * (A' * A - (1 - nu) * (d2N' * B1 + B1' * d2N - 2 * n^2 * (C' * C))) * r * L * gw(q);
        Me = Me + rho * t * (N' * N) * r * L * gw(q);
    end
    K(idx, idx) = K(idx, idx) + Ke;
    M(idx, idx) = M(idx, idx) + Me;
end
if isfield(p, 'bare') && p.bare               % bare annular plate (test case)
    K = K(3:end, 3:end);
    M = M(3:end, 3:end);
    return
end
% Rim on the web edge: W = W(r1), Phi = W'(r1); ring centroid radius Rc
Rc = r1 + p.s_rim / 2000;
b = p.b_rim / 1000;  s = p.s_rim / 1000;  sm = p.s_mass / 1000;
Ib = s * b^3 / 12;                           % out-of-plane bending (about the radial axis)
J = b * s^3 * (1 / 3 - 0.21 * (s / b) * (1 - (s / b)^4 / 12));
G = E / (2 * (1 + nu));
mr = rho * b * sm;                           % kg/m
Ir = rho * (sm * b^3 + b * sm^3) / 12;       % rotary inertia per unit length about the tangential axis
% rim centroid: Wc = W + (Rc - r1) Phi; curvature n^2 Wc / Rc^2 - Phi / Rc, twist (n / Rc)(Phi - Wc / Rc)
Tm = [1, Rc - r1; 0, 1];
ab = [n^2 / Rc^2, -1 / Rc];
at = [-n / Rc^2, n / Rc];
Kr = Tm' * (E * Ib * (ab' * ab) + G * J * (at' * at)) * Tm * Rc;
Mr = Tm' * diag([mr, Ir]) * Tm * Rc;
o = ndof - 1:ndof;
K(o, o) = K(o, o) + Kr;
M(o, o) = M(o, o) + Mr;
% clamp at the hub
K = K(3:end, 3:end);
M = M(3:end, 3:end);
end

function [N, dN, d2N] = hermite(xi, L)
N = [1 - 3 * xi^2 + 2 * xi^3, L * (xi - 2 * xi^2 + xi^3), 3 * xi^2 - 2 * xi^3, L * (-xi^2 + xi^3)];
dN = [-6 * xi + 6 * xi^2, L * (1 - 4 * xi + 3 * xi^2), 6 * xi - 6 * xi^2, L * (-2 * xi + 3 * xi^2)] / L;
d2N = [-6 + 12 * xi, L * (-4 + 6 * xi), 6 - 12 * xi, L * (-2 + 6 * xi)] / L^2;
end

function [x, w] = gauss4()
x = [-0.861136311594053, -0.339981043584856, 0.339981043584856, 0.861136311594053];
w = [0.347854845137454, 0.652145154862546, 0.652145154862546, 0.347854845137454];
x = (x + 1) / 2;
w = w / 2;
end
