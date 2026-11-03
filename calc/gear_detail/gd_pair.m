function g = gd_pair(z1, z2, mn, beta_deg, b, x1, x2, internal, tool1, tool2, A, in, ha)
%GD_PAIR  Geometry, contact path and contact factors of one gear pair with profile shift.
%   g = gd_pair(z1, z2, mn, beta_deg, b, x1, x2, internal, tool1, tool2, A, in, ha)
%
%   Gear 1 is the smaller gear of the pair (pinion; the planet in both
%   planetary meshes). An internal gear 2 (the ring) uses the ISO sign
%   convention for x2: a positive x2 thickens its teeth and moves its tip
%   circle inwards. tool1, tool2 are the hob or shaper cutter structs of
%   gd_inputs, A the ISO 1328-1 tolerance class, in the gd_inputs struct,
%   ha = [ha1 ha2] the tip addendum factors (default [1 1]; a ring with
%   ha2 < 1 has shortened teeth).
%
%   Output struct g (mm, rad): z1, z2, u, mn, mt, b, beta, beta_b, alpha_n,
%   alpha_t, alpha_wt; d1, d2, db1, db2, dw1, dw2, da1, da2, dNa1, dNa2,
%   df1, df2 (positive); a_w; eps_alpha, eps_beta, eps_gamma; p_et; g_alpha;
%   rho1A, rho1B, rho1C, rho1D, rho1E (pinion roll lengths at the points A to
%   E of the path of contact) and T1T2 = a_w sin(alpha_wt); rho2 = @(rho1);
%   sap_margin (roll length between the start of active profile and the
%   root form circle of each gear) [mm]; zeta1A, zeta2E (specific sliding at
%   the roots); Z_H, Z_eps, Z_beta, M1, M2, Z_B, Z_D; tol1, tol2
%   (gd_tolerances); r1, r2 (gd_root); h1, h2 (tooth depths).
%
%   Source: Phase 2 report, Section 2.4 ("Geometry"). ISO 21771 geometry;
%   Z factors from ISO 6336-2:2019, Clauses 6, 8 and 9. Tested by
%   test_step24 (TC33, TC34).

if nargin < 13, ha = [1 1]; end
an = deg2rad(in.alpha_n);
beta = deg2rad(beta_deg);
inv = @(a) tan(a) - a;
at = atan(tan(an) / cos(beta));
mt = mn / cos(beta);
bb = atan(tan(beta) * cos(at));
d1 = z1 * mt;
d2 = z2 * mt;
db1 = d1 * cos(at);
db2 = d2 * cos(at);
if internal
    awt = fzero(@(a) inv(a) - inv(at) - 2 * tan(an) * (x1 + x2) / (z1 - z2), at);
    a_w = (d2 - d1) / 2 * cos(at) / cos(awt);
    da2 = d2 - 2 * mn * (ha(2) + x2);
    dNa2 = da2 + 2 * in.tip_chamfer;
else
    awt = fzero(@(a) inv(a) - inv(at) - 2 * tan(an) * (x1 + x2) / (z1 + z2), at);
    a_w = (d1 + d2) / 2 * cos(at) / cos(awt);
    da2 = d2 + 2 * mn * (ha(2) + x2);
    dNa2 = da2 - 2 * in.tip_chamfer;
end
da1 = d1 + 2 * mn * (ha(1) + x1);
dNa1 = da1 - 2 * in.tip_chamfer;
u = z2 / z1;
dw1 = 2 * a_w / (u + 1 - 2 * internal);     % internal: dw1 = 2 a_w / (u - 1)
dw2 = dw1 * u;

% Path of contact in the transverse plane, measured as pinion roll length from T1
T1T2 = a_w * sin(awt);
rho1E = sqrt((dNa1 / 2)^2 - (db1 / 2)^2);
rho2tip = sqrt((dNa2 / 2)^2 - (db2 / 2)^2);
if internal
    rho1A = rho2tip - T1T2;
    rho2 = @(r1) r1 + T1T2;                  % concave ring flank
else
    rho1A = T1T2 - rho2tip;
    rho2 = @(r1) T1T2 - r1;
end
g_alpha = rho1E - rho1A;
p_et = pi * mt * cos(at);
eps_alpha = g_alpha / p_et;
eps_beta = b * sin(beta) / (pi * mn);
rho1B = rho1E - p_et;
rho1C = db1 / 2 * tan(awt);
rho1D = rho1A + p_et;

% Root form circles: hob flank ends where the rack tip rounding starts; the
% ring's form circle is taken 0.3 m inside its root circle (shaped root)
hFfP = @(t) (t.hfP - t.rhofP * (1 - sin(an))) * mn;
rhoFf1 = d1 / 2 * sin(at) - (hFfP(tool1) - x1 * mn) / sin(at);
sap1 = rho1A - max(rhoFf1, 0);

% Root factors (ISO 6336-3 Method B) and root diameters
r1 = gd_root(z1, mn, beta_deg, x1, dNa1, eps_alpha, eps_beta, tool1, false, in.alpha_n);
r2 = gd_root(z2, mn, beta_deg, x2, dNa2, eps_alpha, eps_beta, tool2, internal, in.alpha_n);
df1 = r1.d_f;
df2 = r2.d_f;
if internal
    rho2E = rho2(rho1E);
    rhoFf2 = sqrt(((df2 - 0.6 * mn) / 2)^2 - (db2 / 2)^2);
    sap2 = rhoFf2 - rho2E;
else
    rhoFf2 = d2 / 2 * sin(at) - (hFfP(tool2) - x2 * mn) / sin(at);
    sap2 = rho2(rho1E) - max(rhoFf2, 0);
end

% Specific sliding at the roots (A: pinion root, E: wheel root)
zeta1A = 1 - rho2(rho1A) / (u * rho1A);
zeta2E = 1 - u * rho1E / rho2(rho1E);

% Contact factors, ISO 6336-2:2019
Z_H = sqrt(2 * cos(bb) * cos(awt) / (cos(at)^2 * sin(awt)));
if eps_beta < 1
    Z_eps = sqrt((4 - eps_alpha) / 3 * (1 - eps_beta) + eps_beta / eps_alpha);
else
    Z_eps = sqrt(1 / eps_alpha);
end
Z_beta = 1 / sqrt(cos(beta));
prodC = rho1C * rho2(rho1C);
M1 = sqrt(prodC / (rho1B * rho2(rho1B)));
M2 = sqrt(prodC / (rho1D * rho2(rho1D)));
eb = min(eps_beta, 1);
Z_B = max(M1, 1) - eb * (max(M1, 1) - 1);   % f_ZCa = 1: the profile modifications are designed (Section 2.4)
Z_D = max(M2, 1) - eb * (max(M2, 1) - 1);
if internal, Z_D = 1; end

g = struct('z1', z1, 'z2', z2, 'u', u, 'mn', mn, 'mt', mt, 'b', b, 'beta', beta, 'beta_b', bb, ...
           'alpha_n', an, 'alpha_t', at, 'alpha_wt', awt, 'internal', internal, 'x1', x1, 'x2', x2, ...
           'd1', d1, 'd2', d2, 'db1', db1, 'db2', db2, 'dw1', dw1, 'dw2', dw2, ...
           'da1', da1, 'da2', da2, 'dNa1', dNa1, 'dNa2', dNa2, 'df1', df1, 'df2', df2, 'a_w', a_w, ...
           'eps_alpha', eps_alpha, 'eps_beta', eps_beta, 'eps_gamma', eps_alpha + eps_beta, ...
           'p_et', p_et, 'g_alpha', g_alpha, 'T1T2', T1T2, 'rho1A', rho1A, 'rho1B', rho1B, ...
           'rho1C', rho1C, 'rho1D', rho1D, 'rho1E', rho1E, 'sap1', sap1, 'sap2', sap2, ...
           'zeta1A', zeta1A, 'zeta2E', zeta2E, 'Z_H', Z_H, 'Z_eps', Z_eps, 'Z_beta', Z_beta, ...
           'M1', M1, 'M2', M2, 'Z_B', Z_B, 'Z_D', Z_D, ...
           'tol1', gd_tolerances(d1, mn, b, A), 'tol2', gd_tolerances(d2, mn, b, A), 'A', A, ...
           'r1', r1, 'r2', r2, 'h1', (da1 - df1) / 2, 'h2', abs(df2 - da2) / 2);
g.rho2 = rho2;
end
