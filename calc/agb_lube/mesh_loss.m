function r = mesh_loss(g, T1, n1, eta, Ra, XL)
%MESH_LOSS  Load-dependent power loss of one gear mesh (Ohlendorf loss factor, Schlenk friction).
%   r = mesh_loss(g, T1, n1, eta, Ra, XL)
%
%   Inputs
%     g     pair geometry from gear_geometry (calc/rgb_sizing); gear 1 is
%           the smaller gear, gear 2 the ring in an internal pair
%     T1    torque on gear 1                                         [N m]
%     n1    speed of gear 1; in a planetary stage, relative to the carrier [rpm]
%     eta   dynamic oil viscosity at the oil temperature             [mPa s]
%     Ra    mean arithmetic flank roughness of the two gears         [um]
%     XL    lubricant factor (1 for mineral oil)                     [-]
%
%   Output struct r
%     eps1, eps2   addendum contact ratios of gear 1 and gear 2      [-]
%     H_V          gear loss factor                                  [-]
%     F_bt         normal force in the transverse plane              [N]
%     v_sum        sum of the rolling velocities at the pitch point  [m/s]
%     rho_red      reduced radius of curvature at the pitch point, normal plane [mm]
%     mu_mz        mean coefficient of friction                      [-]
%     P_mesh       power through the mesh, T1 x omega1              [W]
%     P_loss       mesh loss, P_mesh mu_mz H_V                       [W]
%
%   Formulas (ISO/TR 14179-2 method, as given by Fernandes et al., Mech. Sci.
%   6, 81-88, 2015):
%     H_V = pi (u +- 1) / (z1 u cos beta_b) (1 - eps_alpha + eps1^2 + eps2^2),
%           + for an external pair, - for an internal one, u = z2/z1
%     mu_mz = 0.048 ((F_bt/b) / (v_sum rho_red))^0.2 eta^-0.05 Ra^0.25 XL
%   F_bt/b in N/mm, v_sum in m/s, rho_red in mm, eta in mPa s, Ra in um.
%   Only the sliding (load-dependent) loss; windage and churning are in
%   windage_loss.
%
%   Source: Phase 1 report, Section 4 ("Power losses and efficiency").
%   Tested by test_step14 (TC11, TC12).

at = g.alpha_t;
bb = g.beta_b;
u = g.z2 / g.z1;

% Addendum contact ratios: from the pitch point to the tip circle of each gear.
% The ring's tip circle is inside its pitch circle, so its sign is reversed.
t1 = sqrt((g.da1 / g.db1)^2 - 1);
t2 = sqrt((g.da2 / g.db2)^2 - 1);
eps1 = g.z1 / (2 * pi) * (t1 - tan(at));
if g.internal
    eps2 = g.z2 / (2 * pi) * (tan(at) - t2);
    sgn = -1;
else
    eps2 = g.z2 / (2 * pi) * (t2 - tan(at));
    sgn = 1;
end
H_V = pi * (u + sgn) / (g.z1 * u * cos(bb)) * (1 - g.eps_alpha + eps1^2 + eps2^2);

% Mean friction coefficient at the pitch point
Ft = 2000 * T1 / g.d1;
F_bt = Ft / cos(at);
v = pi * g.d1 * n1 / 60000;
v_sum = 2 * v * sin(at);
r1 = g.d1 / 2 * sin(at) / cos(bb);                 % radii of curvature in the normal plane
r2 = g.d2 / 2 * sin(at) / cos(bb);
rho_red = r1 * r2 / (r2 + sgn * r1);
mu_mz = 0.048 * ((F_bt / g.b) / (v_sum * rho_red))^0.2 * eta^(-0.05) * Ra^0.25 * XL;

P_mesh = T1 * n1 * 2 * pi / 60;
r = struct('eps1', eps1, 'eps2', eps2, 'H_V', H_V, 'F_bt', F_bt, 'v_sum', v_sum, ...
           'rho_red', rho_red, 'mu_mz', mu_mz, 'P_mesh', P_mesh, 'P_loss', P_mesh * mu_mz * H_V);
end
