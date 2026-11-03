function D = lb_design()
%LB_DESIGN  The step 2.4 to 2.6 design in the form lb_losses takes.
%   D = lb_design()
%
%   Output struct D: M (gd_meshes), A (ad_meshes), gi, sb, ad (the input
%   structs of steps 2.4, 2.5, 2.6); R_in, R_mid [N] (larger radial
%   reaction of the input and intermediate shaft roller bearings at 100%
%   torque, the step 2.5 layout), Fa1 [N] (first-stage axial force at
%   100%), planet_Dpw [mm] and Fc [N] (planet roller pitch diameter and
%   centrifugal load of a planet with its rollers, step 2.5).
%   Source: Phase 2 report, Section 2.7 ("Heat balance").

gi = gd_inputs();
sb = sb_inputs();
ad = ad_inputs();
M = gd_meshes(gi);
A = ad_meshes(ad, gi);
g1 = M(1).g;
Ft = 2000 * gi.T_PT / g1.dw1;
Fr = Ft * tan(g1.alpha_wt);
Fa = Ft * tan(g1.beta);
R_gear = @(r) max(hypot(Ft / 2, Fr / 2 + Fa * r / sb.span1), hypot(Ft / 2, Fr / 2 - Fa * r / sb.span1));
gsp = M(2).g;
pb = sb.planet;
Dor = M(2).D_or;
Dpw = Dor - pb.Dw;
Z = floor(pi * Dpw / (pb.Dw * (1 + pb.pitch_gap)));
rho = gi.rho_steel;
m = rho * pi / 4 * (((gsp.da1 + gsp.df1) / 2)^2 - Dor^2) * gsp.b + Z * rho * pi / 4 * pb.Dw^2 * (gsp.b - pb.L_ends);
D = struct('M', M, 'A', A, 'gi', gi, 'sb', sb, 'ad', ad, 'R_in', R_gear(g1.dw1 / 2), ...
           'R_mid', R_gear(g1.dw2 / 2), 'Fa1', Fa, 'planet_Dpw', Dpw, ...
           'Fc', m * (gsp.d1 + gsp.d2) / 2 / 1000 * (M(1).nc * pi / 30)^2);
end
