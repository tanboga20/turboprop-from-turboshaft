function sh = shaft_check(d_o, d_i, T, M_alt, F_a, T_lim, M_lim, F_a_lim, in)
%SHAFT_CHECK  Fatigue and static safeties of a hollow shaft section.
%   sh = shaft_check(d_o, d_i, T, M_alt, F_a, T_lim, M_lim, F_a_lim, in)
%
%   Inputs
%     d_o, d_i   outer and inner diameter                              [mm]
%     T, F_a     steady torque and axial force in continuous running   [N m, N]
%     M_alt      bending moment; the shaft rotates under loads fixed in
%                space, so it sees fully reversed bending              [N m]
%     T_lim, M_lim, F_a_lim   torque, bending moment and axial force at
%                limit load                                            [N m, N m, N]
%     in         rgb_inputs: shaft material, notch and Marin factors, criteria
%
%   Output struct sh
%     d_o, d_i               diameters                                 [mm]
%     S_e                    corrected endurance limit                 [MPa]
%     sigma_a, sigma_m       alternating bending stress and von Mises
%                            mean stress                               [MPa]
%     n_f                    Goodman fatigue safety                    [-]
%     sigma_lim              von Mises stress at limit load            [MPa]
%     n_yield, n_ult         sigma_y / sigma_lim and sigma_u / (1.5 sigma_lim) [-]
%     ok                     n_f >= nf_min, n_yield >= 1 and n_ult >= 1 (STR-03)
%
%   S_e = S_e' k_a k_b k_e with S_e' = 0.5 sigma_u, at most 700 MPa; the
%   size factor k_b uses d_o. The notch factors act in fatigue only.
%
%   Source: Phase 1 report, Section 3 ("Shafts"); Marin factors and the
%   Goodman line from Shigley, 10th edition. Tested by test_rgb_sizing (TC6).

A = pi / 4 * (d_o^2 - d_i^2);
W_b = pi / 32 * (d_o^4 - d_i^4) / d_o;      % section modulus in bending
W_t = 2 * W_b;                              % in torsion

% Fatigue: fully reversed bending, steady torque and axial force
sigma_a = in.Kf * M_alt * 1e3 / W_b;
sigma_m = sqrt((F_a / A)^2 + 3 * (in.Kfs * T * 1e3 / W_t)^2);
if d_o <= 51
    k_b = 1.24 * d_o^(-0.107);
else
    k_b = 1.51 * d_o^(-0.157);
end
S_e = min(0.5 * in.shaft_su, 700) * in.ka * k_b * in.ke;
n_f = 1 / (sigma_a / S_e + sigma_m / in.shaft_su);

% Limit load: no yield; no failure at 1.5 x limit load
sigma_lim = sqrt((M_lim * 1e3 / W_b + F_a_lim / A)^2 + 3 * (T_lim * 1e3 / W_t)^2);
n_yield = in.shaft_sy / sigma_lim;
n_ult = in.shaft_su / (in.ult_factor * sigma_lim);

sh = struct('d_o', d_o, 'd_i', d_i, 'S_e', S_e, 'sigma_a', sigma_a, 'sigma_m', sigma_m, ...
            'n_f', n_f, 'sigma_lim', sigma_lim, 'n_yield', n_yield, 'n_ult', n_ult, ...
            'ok', n_f >= in.nf_min && n_yield >= 1 && n_ult >= 1);
end
