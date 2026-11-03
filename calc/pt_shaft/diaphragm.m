function c = diaphragm(a, b, t, in, n_rpm, n_pack)
%DIAPHRAGM  Stresses, stiffness and safeties of one flat diaphragm coupling.
%   c = diaphragm(a, b, t, in, n_rpm)
%   c = diaphragm(a, b, t, in, n_rpm, n_pack)
%
%   Inputs
%     a, b, t   rim radius, hub radius and thickness of the diaphragm     [m]
%     in        ptshaft_inputs (material in.dia, misalignment in.mis, torques)
%     n_rpm     speed for the steady centrifugal stress, normally 100%   [rpm]
%     n_pack    number of diaphragms in the pack, clamped together at rim
%               and hub: each bends as one diaphragm, they share the
%               torque and add their stiffness; 1 if left out          [-]
%
%   Output struct c
%     k_ax, k_th        axial and angular stiffness (annular_plate)       [N/m, N m/rad]
%     F_ax, M_mis       axial force and bending moment the coupling puts on
%                       the shafts at the continuous misalignment         [N, N m]
%     tau_MC, tau_lim   torque shear at the hub radius, T_MC and LD-01    [Pa]
%     sig_ax            bending stress from the continuous axial offset   [Pa]
%     sig_th            bending stress from the continuous tilt; it
%                       alternates once per revolution                    [Pa]
%     sig_cf, sig_cf_brk  hoop stress at the hub from rotation, at n_rpm
%                       and at the shaft-break peak speed                 [Pa]
%     n_f               Goodman fatigue safety (von Mises)               [-]
%     n_static          yield safety at the LD-01 torque, transient
%                       misalignment and 110% speed                       [-]
%     n_burst           tensile strength / hoop stress at the break speed [-]
%     n_buck            shear buckling safety at the LD-01 torque        [-]
%     mass              diaphragm mass                                    [kg]
%     ok                all criteria met
%
%   Torque shear tau = T / (2 pi r^2 t) is largest at the hub. Rotating
%   annular disc with free edges: sigma_theta(b) = (3 + nu) / 4 rho w^2
%   (a^2 + (1 - nu) / (3 + nu) b^2). Shear buckling of the annulus is taken
%   as that of a long clamped strip of width a - b, k_s = 8.98 (Timoshenko
%   and Gere, Theory of Elastic Stability, Section 9.7). Steady: torque at
%   T_MC, axial offset, rotation; alternating: tilt and T_alt x T_MC.
%
%   Source: Phase 2 report, Section 2.2 ("Diaphragm couplings"). Tested by
%   test_step22 (TC25, TC26).

if nargin < 6
    n_pack = 1;
end
m = in.dia;
p = annular_plate(a, b, t, m.E, m.nu);
c.n_pack = n_pack;
c.k_ax = n_pack * p.k_ax;
c.k_th = n_pack * p.k_th;
th = in.mis.theta * pi / 180;
thx = in.mis.theta_max * pi / 180;
c.F_ax = c.k_ax * in.mis.axial;
c.M_mis = c.k_th * th;

tq = @(T) T / (2 * pi * b^2 * t * n_pack);
c.tau_MC = tq(in.T_MC);
c.tau_lim = tq(in.T_lim);
c.sig_ax = p.s_ax * in.mis.axial;
c.sig_th = p.s_th * th;
hoop = @(n) (3 + m.nu) / 4 * m.rho * (n * pi / 30)^2 * (a^2 + (1 - m.nu) / (3 + m.nu) * b^2);
c.sig_cf = hoop(n_rpm);
c.sig_cf_brk = hoop(in.n_break);

% Fatigue: radial bending (axial offset) and hoop (rotation) act on perpendicular faces
s_r = c.sig_ax;  s_t = c.sig_cf;
sm = sqrt(s_r^2 + s_t^2 - s_r * s_t + 3 * c.tau_MC^2);
sa = sqrt(c.sig_th^2 + 3 * (in.T_alt * c.tau_MC)^2);
c.n_f = 1 / (sa / m.Se + sm / m.su);

% Static at limit: LD-01 torque, transient misalignment, 110% speed
s_r = p.s_ax * in.mis.axial_max + p.s_th * thx;
s_t = hoop(in.n_over);
c.n_static = m.sy / sqrt(s_r^2 + s_t^2 - s_r * s_t + 3 * c.tau_lim^2);
c.n_burst = m.su / c.sig_cf_brk;

D = m.E * t^3 / (12 * (1 - m.nu^2));
tau_cr = 8.98 * pi^2 * D / (t * (a - b)^2);
c.n_buck = tau_cr / c.tau_lim;
c.mass = n_pack * m.rho * pi * (a^2 - b^2) * t;
c.ok = c.n_f >= m.n_f_min && c.n_static >= 1.0 && c.n_burst >= 1.5 && c.n_buck >= m.n_buck_min;
end
