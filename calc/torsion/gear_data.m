function g = gear_data(design)
%GEAR_DATA  Radii, face widths, masses and inertias of one layout O design for the torsional model.
%   g = gear_data(design)
%
%   Input
%     design   tooth counts [z1 z2 zs zp N]
%
%   Output struct g (SI units): r1, r2, alpha_t1, b1 (first stage); r_s, r_p,
%   r_r, r_c, alpha_t2, b2, N (planetary); r_ag (accessory gear of 57 teeth
%   on the first-stage gear); J_pinion, J_gear2, J_sun, J_planet, J_carrier,
%   J_ag [kg m^2]; m_planet [kg]; i (overall ratio); L (the rgb_layout struct).
%
%   Builds the design with the step 1.3 tool (calc/rgb_sizing must be on the
%   path). Gear inertias are those of discs between the pitch radius and the
%   shaft radius, J = m (r^2 + r_h^2) / 2, with the step 1.3 masses; the
%   carrier is the disc of the step 2.1 rotor model (Ip 0.061 kg m^2); the
%   accessory gear mass is from step 1.4 (0.386 kg).
%
%   Source: Phase 2 report, Section 2.3 ("Model").

in = rgb_inputs();
t = tooth_set_check(design(1), design(2), design(3), design(4), design(5), in);
s1 = size_stage1(t.z1, t.z2, in);
s2 = size_stage2(t, in);
L = rgb_layout(t, s1, s2, in);
mm = 1e-3;
g.r1 = s1.g.d1 / 2 * mm;
g.r2 = s1.g.d2 / 2 * mm;
g.alpha_t1 = s1.g.alpha_t;
g.b1 = s1.b * mm;
g.r_s = s2.ds / 2 * mm;
g.r_p = s2.dp / 2 * mm;
g.r_r = s2.dr / 2 * mm;
g.r_c = g.r_s + g.r_p;
g.alpha_t2 = s2.g_sp.alpha_t;
g.b2 = s2.b * mm;
g.N = t.N;
g.r_ag = 57 * s1.g.mt / 2 * mm;
disc = @(m, r, rh) m * (r^2 + rh^2) / 2;
g.J_pinion = disc(L.mass.pinion, g.r1, L.inp.sh.d_o / 2 * mm);
g.J_gear2 = disc(L.mass.gear2, g.r2, L.mid.sh.d_o / 2 * mm);
g.J_sun = disc(L.mass.sun, g.r_s, L.mid.sh.d_o / 2 * mm);
g.m_planet = s2.m_planet;
g.J_planet = disc(s2.m_planet, g.r_p, s2.brg.D_or / 2 * mm);
g.J_carrier = 0.061;
g.J_ag = disc(0.386, g.r_ag, 0.010);
g.i = t.i;
g.L = L;
end
