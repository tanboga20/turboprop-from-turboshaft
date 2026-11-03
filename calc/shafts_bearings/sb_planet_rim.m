function f = sb_planet_rim(p, nmodes)
%SB_PLANET_RIM  In-plane modes of a planet rim on its loaded bearing rollers (DYN-04).
%   f = sb_planet_rim(p, nmodes)
%
%   Input struct p: R (mean radius of the rim), h (radial rim thickness),
%   b (face width), h_teeth (equivalent thickness of the tooth layer, mass
%   only) [mm]; E [MPa], rho [kg/mm^3]; Z rollers, Dw, Lwe [mm] (roller
%   set; Z = 0 for the free ring); F [N] radial bearing load; nel (beam
%   elements around the ring); optional k_mesh [N/m] and alpha [rad]: a
%   mesh spring at each of the two mesh points (psi = +-90 deg, the sun and
%   ring side) along the line of action, to ground. nmodes: number of
%   frequencies returned.
%   Output f: the lowest natural frequencies above 10 Hz [Hz] (the
%   rigid-body modes that the supports leave free are left out).
%
%   The rim is a ring of straight Euler-Bernoulli frame elements (axial,
%   bending; consistent mass). The rollers in the loaded zone are radial
%   springs to the rigid pin: roller loads by the Stribeck distribution
%   with zero clearance, Q = Qmax cos(psi)^(10/9), Qmax = 4.08 F / Z; the
%   tangent stiffness of each roller from the Palmgren line-contact
%   deflection delta = 3.84e-5 Q^0.9 / L^0.8 (mm) at the inner and outer
%   race in series. Rollers on the unloaded side stand clear. Step 2.4
%   took the free ring (Z = 0). The supported ring has modes below the
%   free-ring n = 2 mode (the unloaded half of the rim swings on the
%   loaded half), and the mesh springs couple the planet rotation in; the
%   three models bracket the planet modes for DYN-04.
%   Source: Phase 2 report, Section 2.5 ("Planet bearing and rim").
%   Tested by test_step25 (TC44) against an independent Python
%   implementation (free, on the rollers, with the mesh springs); the free
%   ring is 0.7% below the Hoppe closed form of gd_modes (extensible ring).

N = p.nel;
R = p.R / 1000;
phi = 2 * pi * (0:N-1)' / N;
xy = R * [cos(phi), sin(phi)];
E = p.E * 1e6;
A = p.b * p.h * 1e-6;
I = p.b * p.h^3 / 12 * 1e-12;
mA = p.rho * 1e9 * p.b * (p.h + p.h_teeth) * 1e-6;     % kg/m
ndof = 3 * N;
K = zeros(ndof);
M = zeros(ndof);
for e = 1:N
    i1 = e;  i2 = mod(e, N) + 1;
    d = xy(i2, :) - xy(i1, :);
    L = norm(d);
    c = d(1) / L;  s = d(2) / L;
    k = [E*A/L 0 0 -E*A/L 0 0;
         0 12*E*I/L^3 6*E*I/L^2 0 -12*E*I/L^3 6*E*I/L^2;
         0 6*E*I/L^2 4*E*I/L 0 -6*E*I/L^2 2*E*I/L;
         -E*A/L 0 0 E*A/L 0 0;
         0 -12*E*I/L^3 -6*E*I/L^2 0 12*E*I/L^3 -6*E*I/L^2;
         0 6*E*I/L^2 2*E*I/L 0 -6*E*I/L^2 4*E*I/L];
    m = mA * L / 420 * [140 0 0 70 0 0;
                        0 156 22*L 0 54 -13*L;
                        0 22*L 4*L^2 0 13*L -3*L^2;
                        70 0 0 140 0 0;
                        0 54 13*L 0 156 -22*L;
                        0 -13*L -3*L^2 0 -22*L 4*L^2];
    Tr = blkdiag([c s 0; -s c 0; 0 0 1], [c s 0; -s c 0; 0 0 1]);
    idx = [3*i1-2:3*i1, 3*i2-2:3*i2];
    K(idx, idx) = K(idx, idx) + Tr' * k * Tr;
    M(idx, idx) = M(idx, idx) + Tr' * m * Tr;
end
if p.Z > 0
    Qmax = 4.08 * p.F / p.Z;
    for kk = 0:p.Z-1
        psi = 2 * pi * kk / p.Z;                     % load direction at psi = 0
        if cos(psi) <= 0, continue, end
        Q = Qmax * cos(psi)^(10/9);
        kc = Q^0.1 * p.Lwe^0.8 / (0.9 * 3.84e-5) * 1e3;   % N/m, one contact
        kr = kc / 2;                                 % inner and outer contact in series
        [~, j] = min(abs(angle(exp(1i * (phi - psi)))));   % nearest rim node
        n = [cos(phi(j)); sin(phi(j))];
        idx = 3 * j - 2:3 * j - 1;
        K(idx, idx) = K(idx, idx) + kr * (n * n');
    end
end
if isfield(p, 'k_mesh') && p.k_mesh > 0
    for sg = [1 -1]
        [~, j] = min(abs(angle(exp(1i * (phi - sg * pi / 2)))));
        u = [cos(p.alpha); -sg * sin(p.alpha)];     % line of action, mostly along the load
        idx = 3 * j - 2:3 * j - 1;
        K(idx, idx) = K(idx, idx) + p.k_mesh * (u * u');
    end
end
lam = sort(real(eig(K, M)));
lam = lam(lam > (2 * pi * 10)^2);                   % drop the rigid-body modes
f = sqrt(lam(1:nmodes)) / (2 * pi);
end
