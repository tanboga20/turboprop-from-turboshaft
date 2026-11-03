function C = dy_couple_check(f)
%DY_COUPLE_CHECK  Two-DOF benchmark of the planet-to-case coupling by receptance (dy_case_frf).
%   C = dy_couple_check(f)
%
%   A planet (m1 on its support k1) meshes through k_m with a ring on the
%   case (m2 on k2), both with 2 % viscous damping. The transmission error
%   TE is a displacement source in the mesh; x1 and x2 move each body away
%   from the other along the line of action, so the mesh force is
%   F = k_m (TE - x1 - x2). Blocked ring: F_b = D TE with D = k_m Z1 /
%   (Z1 + k_m), Z1 = k1 - m1 w^2 + i w c1. Coupled by receptance:
%   F = D TE / (1 + D H) with H = 1 / Z2 (the ring receptance). The direct
%   solve of the 2 x 2 system gives the same force. The formula is
%   evaluated by dy_ring_couple, the code path of dy_case_frf (D from the
%   planet, B = As = Bsr = 0, H = 1 / Z2).
%   Output C: f [Hz], F_formula and F_direct (|F| per unit TE [N/m]).
%   Source: Phase 3 report, Section 3.6 ("Planet and case coupling").

m1 = 1.2;  k1 = 4e8;  km = 1.5e9;  m2 = 3.0;  k2 = 2e9;  z = 0.02;
c1 = 2 * z * sqrt(k1 * m1);  c2 = 2 * z * sqrt(k2 * m2);
C.f = f;  C.F_formula = zeros(size(f));  C.F_direct = C.F_formula;
for k = 1:numel(f)
    w = 2 * pi * f(k);
    Z1 = k1 - m1 * w^2 + 1i * w * c1;  Z2 = k2 - m2 * w^2 + 1i * w * c2;
    Fp = struct('D', km * Z1 / (Z1 + km), 'B', 0, 'As', 0, 'Bsr', 0);
    Rc = dy_ring_couple(Fp, 1 / Z2, 1);
    C.F_formula(k) = Rc.Fc;
    x = [Z1 + km, km; km, Z2 + km] \ [km; km];      % unit TE
    C.F_direct(k) = abs(km * (1 - x(1) - x(2)));
end
end
