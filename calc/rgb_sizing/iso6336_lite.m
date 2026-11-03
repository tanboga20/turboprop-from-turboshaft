function r = iso6336_lite(g, T1, n1, f)
%ISO6336_LITE  Forces, stresses and safety factors of one mesh, simplified ISO 6336.
%   r = iso6336_lite(g, T1, n1, f)
%
%   Inputs
%     g    pair geometry from gear_geometry
%     T1   torque on gear 1                                         [N m]
%     n1   speed of gear 1                                          [rpm]
%     f    factor struct
%            KA, Kv, KHb, KHa   application, dynamic, face and transverse
%                               load factors                        [-]
%            Kgam               load sharing between planets        [-]
%            ZNT, YNT           life factors, contact and bending   [-]
%            ZNT2, YNT2         optional: life factors of gear 2 when they
%                               differ (the nitrided ring in the static check) [-]
%            fZCa               optional: f_ZCa of ISO 6336-2:2019, Table 3,
%                               for helical pairs (default 1)       [-]
%            ZLvR               lubricant, speed and roughness      [-]
%            ZE                 elasticity factor                   [sqrt(MPa)]
%            sHlim1, sFlim1     contact and bending endurance limits, gear 1 [MPa]
%            sHlim2, sFlim2     the same for gear 2                 [MPa]
%            YM1, YM2           reversed bending, 0.7 for a planet  [-]
%
%   Output struct r
%     Ft, Fr, Fa              tangential, radial and axial force    [N]
%     v                       pitch-line velocity                   [m/s]
%     Z_H, Z_eps, Z_beta      zone, contact ratio and helix factors [-]
%     Z_B, Z_D                single pair tooth contact factors of gear 1 and gear 2 [-]
%     sigma_H                 contact stress at the pitch point     [MPa]
%     S_H1, S_H2, S_H         pitting safety of gear 1 (stress Z_B sigma_H), gear 2
%                             (Z_D sigma_H) and the smaller one     [-]
%     K_Fbeta                 face load factor for bending          [-]
%     Y_eps, Y_beta           contact ratio and helix factors for bending [-]
%     Y_FS1, Y_FS2            tooth form and stress correction factors [-]
%     sigma_F1, sigma_F2      tooth root stresses                   [MPa]
%     S_F1, S_F2              bending safeties                      [-]
%
%   Static check (LD-01): call again with 1.375*T1 and a copy of f with the
%   static life factors (ZNT 1.6, YNT 2.5; a nitrided gear 2: ZNT2 1.3, YNT2 1.6).
%
%   Source: Phase 1 report, Section 3 ("Method: gears" and "Check against the
%   standards"). The formulas follow ISO 6336-1, -2 and -3:2019 in simplified
%   form: no profile shift, assumed K factors, and the tooth form and stress
%   correction factor Y_FS with Y_eps (load at the tip) instead of Y_F Y_S of
%   Method B. Tested by test_rgb_sizing (TC1-TC3).

% Step 1: forces and pitch-line velocity
u = g.z2 / g.z1;
Ft = 2000 * T1 / g.d1;                 % T1 in N m, d1 in mm
Fr = Ft * tan(g.alpha_t);
Fa = Ft * tan(g.beta);
v = pi * g.d1 * n1 / 60000;

% Steps 2 and 3: zone, helix and contact ratio factors
Z_H = sqrt(2 * cos(g.beta_b) / (cos(g.alpha_t)^2 * tan(g.alpha_t)));
Z_beta = 1 / sqrt(cos(g.beta));
if g.eps_beta < 1
    Z_eps = sqrt((4 - g.eps_alpha) / 3 * (1 - g.eps_beta) + g.eps_beta / g.eps_alpha);
else
    Z_eps = sqrt(1 / g.eps_alpha);
end

% Step 4: ratio term; the curvatures add in an external pair and subtract in an internal one
if g.internal
    ratio_term = (u - 1) / u;
else
    ratio_term = (u + 1) / u;
end

% Steps 5 and 6: contact stress and pitting safety
sigma_H = Z_H * f.ZE * Z_eps * Z_beta * sqrt(Ft / (g.d1 * g.b) * ratio_term) ...
          * sqrt(f.KA * f.Kgam * f.Kv * f.KHb * f.KHa);
ZNT2 = f.ZNT;
YNT2 = f.YNT;
if isfield(f, 'ZNT2'), ZNT2 = f.ZNT2; end
if isfield(f, 'YNT2'), YNT2 = f.YNT2; end
f_ZCa = 1;
if isfield(f, 'fZCa'), f_ZCa = f.fZCa; end
[Z_B, Z_D] = single_pair_factors(g, f_ZCa);
S_H1 = f.sHlim1 * f.ZNT * f.ZLvR / (Z_B * sigma_H);
S_H2 = f.sHlim2 * ZNT2 * f.ZLvR / (Z_D * sigma_H);
S_H = min(S_H1, S_H2);

% Step 7: face load factor for bending, from K_Hbeta
h = 2.25 * g.mn;                                   % tooth depth
N_F = (g.b / h)^2 / (1 + g.b / h + (g.b / h)^2);
K_Fbeta = f.KHb ^ N_F;

% Steps 8 to 10: bending factors
Y_eps = 0.25 + 0.75 * cos(g.beta_b)^2 / g.eps_alpha;
beta_c = min(g.beta, deg2rad(30));                % ISO 6336-3:2019, 8.3: beta up to 30 deg
Y_beta = (1 - min(g.eps_beta, 1) * rad2deg(beta_c) / 120) / cos(beta_c)^3;
zn = @(z) z / (cos(g.beta_b)^2 * cos(g.beta));     % virtual tooth number
Y_FS1 = 3.47 + 13.2 / zn(g.z1);
if g.internal
    Y_FS2 = 3.47 + 13.2 / zn(400);                 % ring: z = 400, close to a rack
else
    Y_FS2 = 3.47 + 13.2 / zn(g.z2);
end

% Steps 11 and 12: root stresses and bending safeties
K_F = f.KA * f.Kgam * f.Kv * K_Fbeta * f.KHa;
sigma_F1 = Ft / (g.b * g.mn) * Y_FS1 * Y_eps * Y_beta * K_F;
sigma_F2 = Ft / (g.b * g.mn) * Y_FS2 * Y_eps * Y_beta * K_F;
S_F1 = 2 * f.sFlim1 * f.YNT * f.YM1 / sigma_F1;    % 2 = Y_ST of the reference test gear
S_F2 = 2 * f.sFlim2 * YNT2 * f.YM2 / sigma_F2;

r = struct('Ft', Ft, 'Fr', Fr, 'Fa', Fa, 'v', v, 'Z_H', Z_H, 'Z_eps', Z_eps, ...
           'Z_beta', Z_beta, 'Z_B', Z_B, 'Z_D', Z_D, 'sigma_H', sigma_H, ...
           'S_H1', S_H1, 'S_H2', S_H2, ...
           'S_H', S_H, 'K_Fbeta', K_Fbeta, 'Y_eps', Y_eps, 'Y_beta', Y_beta, ...
           'Y_FS1', Y_FS1, 'Y_FS2', Y_FS2, 'sigma_F1', sigma_F1, ...
           'sigma_F2', sigma_F2, 'S_F1', S_F1, 'S_F2', S_F2);
end

function [Z_B, Z_D] = single_pair_factors(g, f_ZCa)
% Single pair tooth contact factors, ISO 6336-2:2019, 6.3. Spur pairs take
% M_1 and M_2 at the inner points of single pair contact (Formulas 17, 18),
% or 1 where these are smaller; helical pairs with eps_beta >= 1 take
% sqrt(f_ZCa) (Formula 19); 0 < eps_beta < 1 interpolates between the two
% (Formulas 20 to 23). An internal pair takes 1.
if g.internal
    Z_B = 1;
    Z_D = 1;
    return
end
if g.eps_beta >= 1
    Z_B = sqrt(f_ZCa);
    Z_D = Z_B;
    return
end
t1 = sqrt(g.da1^2 / g.db1^2 - 1);
t2 = sqrt(g.da2^2 / g.db2^2 - 1);
M_1 = tan(g.alpha_t) / sqrt((t1 - 2 * pi / g.z1) * (t2 - (g.eps_alpha - 1) * 2 * pi / g.z2));
M_2 = tan(g.alpha_t) / sqrt((t2 - 2 * pi / g.z2) * (t1 - (g.eps_alpha - 1) * 2 * pi / g.z1));
Z_B = max(M_1, 1) + g.eps_beta * (sqrt(f_ZCa) - max(M_1, 1));
Z_D = max(M_2, 1) + g.eps_beta * (sqrt(f_ZCa) - max(M_2, 1));
end
