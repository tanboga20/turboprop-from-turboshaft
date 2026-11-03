function s = sb_shaft(d_o, d_i, T, M_alt, F_a, T_lim, M_lim, F_lim, in)
%SB_SHAFT  Fatigue, yield and ultimate check of one hollow shaft section (STR-03).
%   s = sb_shaft(d_o, d_i, T, M_alt, F_a, T_lim, M_lim, F_lim, in)
%
%   Inputs: diameters [mm]; steady torque T [N m], rotating bending moment
%   M_alt [N m] and axial force F_a [N] in continuous running; torque,
%   moment and axial force at limit load [N m, N m, N]; in = sb_inputs.
%
%   Output struct s: S_e, sigma_a, sigma_m, tau_lim, sigma_lim [MPa]; n_f
%   (Goodman), n_y (yield at limit), n_u (rupture at 1.5 x limit) [-].
%
%   The Phase 1 method (step 1.3, shaft_check): fully reversed bending with
%   K_f, steady von Mises mean stress with K_fs on torsion, S_e = 0.5 su
%   (at most 700 MPa) times the Marin surface, size and reliability
%   factors. Source: Phase 2 report, Section 2.5 ("Shafts"). Tested by
%   test_step25 (TC42).

m = in.sh_mat;
A = pi / 4 * (d_o^2 - d_i^2);
Wb = pi / 32 * (d_o^4 - d_i^4) / d_o;
Wt = 2 * Wb;
sigma_a = in.Kf * M_alt * 1e3 / Wb;
sigma_m = sqrt((F_a / A)^2 + 3 * (in.Kfs * T * 1e3 / Wt)^2);
if d_o <= 51
    kb = 1.24 * d_o^-0.107;
else
    kb = 1.51 * d_o^-0.157;
end
ka = in.ka_exp(1) * m.su^in.ka_exp(2);
S_e = min(0.5 * m.su, 700) * ka * kb * in.ke;
n_f = 1 / (sigma_a / S_e + sigma_m / m.su);
tau_lim = T_lim * 1e3 / Wt;
sigma_lim = sqrt((M_lim * 1e3 / Wb + F_lim / A)^2 + 3 * tau_lim^2);
s = struct('d_o', d_o, 'd_i', d_i, 'S_e', S_e, 'sigma_a', sigma_a, 'sigma_m', sigma_m, 'n_f', n_f, ...
           'tau_lim', tau_lim, 'sigma_lim', sigma_lim, 'n_y', m.sy / sigma_lim, ...
           'n_u', m.su / (in.ult * sigma_lim));
end
