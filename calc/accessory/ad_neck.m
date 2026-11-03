function s = ad_neck(T_max, in)
%AD_NECK  Shear neck of an accessory pad quill: diameter, shear torque band and fatigue (ACC-03).
%   s = ad_neck(T_max, in)
%
%   T_max is the maximum rated torque of the pad [N m]; in = ad_inputs.
%   The neck is sized so that its nominal shear torque is in.k_shear x
%   T_max, rounded up to 0.1 mm and at least in.d_neck_min. The shear band
%   takes the ultimate shear strength (in.neck_mat.tau_u_ratio x su) +- in.
%   neck_scatter and the diameter +- in.neck_tol. Fatigue at in.k_fatigue x
%   T_max as a steady torque with an alternating part in.ripple times it:
%   Goodman on von Mises equivalents with K_fs on both parts (the Phase 1
%   shaft method), S_e = 0.5 su (at most 700) x Marin surface, size and
%   reliability factors.
%
%   Output struct s: d [mm]; T_nom, T_lo, T_hi [N m] (shear torque, nominal
%   and band); k_lo (T_lo / T_max); tau_m, tau_a, S_e [MPa]; n_f [-].
%   Source: Phase 2 report, Section 2.6 ("Shear necks"). Tested by
%   test_step26 (TC46).

m = in.neck_mat;
tau_u = m.tau_u_ratio * m.su;
d = (16 * in.k_shear * T_max * 1e3 / (pi * tau_u))^(1/3);
d = max(ceil(10 * d - 1e-9) / 10, in.d_neck_min);
Tsh = @(dd, tu) pi * dd^3 * tu / 16 / 1e3;
T_nom = Tsh(d, tau_u);
T_lo = Tsh(d - in.neck_tol, tau_u * (1 - in.neck_scatter));
T_hi = Tsh(d + in.neck_tol, tau_u * (1 + in.neck_scatter));
tau_m = 16 * in.k_fatigue * T_max * 1e3 / (pi * d^3);
tau_a = in.ripple * tau_m;
if d <= 51
    kb = 1.24 * d^-0.107;
else
    kb = 1.51 * d^-0.157;
end
ka = in.ka_exp(1) * m.su^in.ka_exp(2);
S_e = min(0.5 * m.su, 700) * ka * kb * in.ke;
n_f = 1 / (sqrt(3) * in.Kfs_neck * tau_a / S_e + sqrt(3) * in.Kfs_neck * tau_m / m.su);
s = struct('d', d, 'T_nom', T_nom, 'T_lo', T_lo, 'T_hi', T_hi, 'k_lo', T_lo / T_max, ...
           'tau_m', tau_m, 'tau_a', tau_a, 'S_e', S_e, 'n_f', n_f);
end
