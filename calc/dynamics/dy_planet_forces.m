function F = dy_planet_forces(P, f)
%DY_PLANET_FORCES  Mesh forces of the planet per unit transmission error, from its modal model (dy_planet_frf).
%   F = dy_planet_forces(P, f)
%
%   P = dy_planet_frf output (P.mod: frequencies, modal loads of the sun and
%   ring TE load cases, patch operators and static residuals); f [Hz]
%   (vector). The planet sits on a rigid sun and a rigid ring (blocked).
%   Output F (complex, per unit TE, [N/m], one value per frequency):
%   D = k_pr - Ar u_r and B = -Ar u_s, the ring-mesh force from the ring and
%   from the sun load case; As_ = k_sp - As u_s and Bsr = -As u_r, the
%   sun-mesh force from the sun and from the ring load case. With a ring
%   seat receptance H along the line of action, the coupled ring-mesh force
%   is (D TE_r + B TE_s) / (1 + D H) (dy_case_frf).
%   Source: Phase 3 report, Section 3.6 ("Planet and case coupling").

m = P.mod;
om = 2 * pi * f(:)';
Hm = 1 ./ (m.w.^2 - om.^2 + 2i * m.zeta * m.w .* om);      % modes x frequencies
qs = Hm .* m.gs - m.gs ./ m.w.^2;  qr = Hm .* m.gr - m.gr ./ m.w.^2;
Asus = m.AsV * qs + m.AsU(1);  Arus = m.ArV * qs + m.ArU(1);
Asur = m.AsV * qr + m.AsU(2);  Arur = m.ArV * qr + m.ArU(2);
F.D = m.k_pr - Arur;  F.B = -Arus;
F.As = m.k_sp - Asus;  F.Bsr = -Asur;
end
