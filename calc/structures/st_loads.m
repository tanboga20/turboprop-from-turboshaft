function L = st_loads(in, gi)
%ST_LOADS  Loads of the step 3.5 structural checks from the gear design and the propeller loads.
%   L = st_loads(in, gi)
%
%   in = st_inputs, gi = gd_inputs (calc/gear_detail on the path).
%   Torques: sun torque T_s of the gear design, propeller torque T_mct =
%   T_s (1 + z_r / z_s), ring reaction torque T_s z_r / z_s at MCT and at
%   LD-01/02 (x 1.375); LD-08 propeller torque for the 0.22 s stop.
%   K_gamma P99 of the planet load sharing at 137.5% and at the LD-08 torque
%   (gd_loadshare, as step 2.5).
%   Propeller bearing reactions on the case (y up, the propeller beyond the
%   outer seat): LD-05 limit (2.5 g and the gyroscopic moment), the 1 g
%   weight and the 1P moment; inner and outer seat act in opposite
%   directions (moment pair). Step 2.8 applied both in the same direction
%   (Section 3.5, "Case").
%   Source: Phase 3 report, Section 3.5 ("Loads").

M = gd_meshes(gi);
Ts = M(2).Ts;
s = gi.s2;
L.T_mct = Ts * (1 + s.zr / s.zs);
L.T_ring_mct = Ts * s.zr / s.zs;
L.T_ring_lim = in.K_over * L.T_ring_mct;
L.k08 = in.T_LD08 / L.T_mct;
ref = struct('KA', 1, 'mode', 'ref', 'oil', gi.oil(1), 'Kgam', 1);
r2 = gd_rate(M(2), M(2).T1, M(2).n1, ref);
r3 = gd_rate(M(3), M(3).T1, M(3).n1, ref);
k_sp = r2.c_ga * M(2).g.b;  k_pr = r3.c_ga * M(3).g.b;
ls1 = gd_loadshare(M(2), M(3), in.K_over * Ts, k_sp, k_pr, gi);
ls8 = gd_loadshare(M(2), M(3), L.k08 * Ts, k_sp, k_pr, gi);
L.cases = struct('name', {'LD-01', 'LD-08'}, 'T', {in.K_over * L.T_mct, in.T_LD08}, 'Kgam', {ls1.Kgam_p99, ls8.Kgam_p99});
W = in.m_prop * in.g;
sp = in.span / 1e3;  a = in.a / 1e3;
L.R_out = -(in.nz * W * (1 + a / sp) + in.M_gyro / sp);
L.R_in = in.nz * W * a / sp + in.M_gyro / sp;
L.W1 = [W * a / sp, -W * (1 + a / sp)];               % [inner outer] N
L.P1 = [in.M_1P / sp, -in.M_1P / sp];
L.f_ma = M(3).f_ma;                                   % um, step 2.4 misalignment of the planet-ring mesh
L.b_ring = s.b;
end
