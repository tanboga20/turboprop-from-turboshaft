function s = tube_shaft(D, t, L, in, k_theta, M_bend)
%TUBE_SHAFT  Strength, stiffness and first bending critical speed of the floating drive shaft.
%   s = tube_shaft(D, t, L, in, k_theta, M_bend)
%
%   Inputs
%     D, t      outer diameter and wall thickness of the tube           [m]
%     L         diaphragm-to-diaphragm length                           [m]
%     in        ptshaft_inputs
%     k_theta   angular stiffness of each diaphragm coupling            [N m/rad]
%     M_bend    bending moment that the couplings' misalignment puts on
%               the shaft ends; it rotates with the shaft, so it is
%               fully reversed in the shaft                              [N m]
%
%   Output struct s
%     A, I, J, m         section and mass of the tube                    [m^2, m^4, m^4, kg]
%     tau_MC, tau_lim    shear stress at T_MC and at the LD-01 torque     [Pa]
%     twist_100          twist over the torque meter's measuring length at
%                        T_100                                          [deg]
%     tau_cr, n_buck     torsional buckling stress (Donnell, long tube) and
%                        its safety at the LD-01 torque                  [Pa, -]
%     n_f                Goodman fatigue safety                          [-]
%     n_yield            yield safety at the LD-01 torque (von Mises)    [-]
%     n_cr               first bending critical speed                    [rpm]
%     kt                 torsional stiffness G J / L                     [N m/rad]
%     ok                 all criteria of in met; the critical speed must clear the
%                        DYN-01 limit by the design margin in.ncr_extra, and kt
%                        must reach in.kt_min (step 2.3)
%
%   Fatigue: steady shear from T_MC, alternating shear from T_alt x T_MC,
%   both with the notch factor Kt_shaft; fully reversed bending from M_bend;
%   S_e = 0.5 su ka kb ke (Shigley, 10th ed.), von Mises equivalent stresses.
%   Critical speed: 20 Timoshenko elements (beam_timoshenko), the half
%   couplings as end masses on radial springs k_rad and rotational springs
%   k_theta; non-rotating first mode (the tube's own gyroscopic effect is
%   negligible). Torsional buckling: tau_cr = 0.78 E (t/r)^1.25 / sqrt(L/r)
%   (Donnell, long thin tube, Roark 8th ed. Table 15.2 case 15).
%
%   Source: Phase 2 report, Section 2.2 ("Floating shaft"). Tested by
%   test_step22 (TC24).

m = in.shaft;
r = D / 2;
d = D - 2 * t;
A = pi / 4 * (D^2 - d^2);
I = pi / 64 * (D^4 - d^4);
J = 2 * I;
G = m.E / (2 * (1 + m.nu));
c = r / J;                                   % shear stress per unit torque
s.A = A;  s.I = I;  s.J = J;
s.m = m.rho * A * L;
s.tau_MC = in.T_MC * c;
s.tau_lim = in.T_lim * c;
s.twist_100 = in.T_100 * in.tm.L_meas / (G * J) * 180 / pi;
s.kt = G * J / L;

rm = (D - t) / 2;                             % mean radius
s.tau_cr = 0.78 * m.E * (t / rm)^1.25 / sqrt(L / rm);
s.n_buck = s.tau_cr / s.tau_lim;

% Fatigue (Goodman, von Mises)
dmm = D * 1e3;
if dmm <= 51
    kb = 1.24 * dmm^(-0.107);
else
    kb = 1.51 * dmm^(-0.157);
end
S_e = 0.5 * m.su * in.ka * kb * in.ke;
tau_m = in.Kt_shaft * s.tau_MC;
tau_a = in.Kt_shaft * in.T_alt * s.tau_MC;
sig_a = M_bend * r / I;
s.S_e = S_e;
s.n_f = 1 / (sqrt(sig_a^2 + 3 * tau_a^2) / S_e + sqrt(3) * tau_m / m.su);
s.n_yield = m.sy / (sqrt(3) * s.tau_lim);

% First bending mode: tube, end masses, radial and rotational end springs
ne = 20;
mat = struct('E', m.E, 'nu', m.nu, 'rho', m.rho);
e = beam_timoshenko(L / ne, D, d, mat);
nd = 2 * (ne + 1);
K = zeros(nd);  M = zeros(nd);
for k = 1:ne
    q = 2 * k - 1:2 * k + 2;
    K(q, q) = K(q, q) + e.K;
    M(q, q) = M(q, q) + e.Mt + e.Mr;
end
for q = [1, nd - 1]                           % end translations
    K(q, q) = K(q, q) + in.k_rad;
    M(q, q) = M(q, q) + in.m_half;
end
for q = [2, nd]                               % end rotations
    K(q, q) = K(q, q) + k_theta;
end
w = sort(sqrt(abs(eig(K, M))));
s.n_cr = w(1) * 30 / pi;
lim_hi = in.ncr_extra * (1 + in.margin) * in.n_steady(2);
s.ok = s.n_cr >= lim_hi && s.n_f >= in.n_f_min && s.n_buck >= in.n_buck_min ...
       && s.n_yield >= 1.5 && s.twist_100 >= in.tm.theta_min && s.kt >= in.kt_min;
end
