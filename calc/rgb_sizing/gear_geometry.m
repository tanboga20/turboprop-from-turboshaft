function g = gear_geometry(z1, z2, mn, beta_deg, b, internal, alpha_n_deg)
%GEAR_GEOMETRY  Geometry of one gear pair without profile shift (x1 = x2 = 0).
%   g = gear_geometry(z1, z2, mn, beta_deg, b, internal, alpha_n_deg)
%
%   Gear 1 is the smaller gear of the pair. In an internal pair (planet and
%   ring), gear 2 is the ring and z2 is its tooth number.
%
%   Inputs
%     z1, z2        tooth numbers                                   [-]
%     mn            normal module                                   [mm]
%     beta_deg      helix angle, 0 for a spur pair                  [deg]
%     b             face width                                      [mm]
%     internal      true for an internal pair, false for an external one
%     alpha_n_deg   normal pressure angle, 20 in this project       [deg]
%
%   Output struct g: copies of z1, z2, mn, b, internal and
%     beta, alpha_t, beta_b   helix, transverse pressure and base helix angles [rad]
%     mt                      transverse module                     [mm]
%     d1, d2                  pitch diameters                       [mm]
%     db1, db2                base diameters                        [mm]
%     da1, da2                tip diameters, addendum = mn          [mm]
%     a                       centre distance                       [mm]
%     eps_alpha, eps_beta     transverse contact ratio, overlap ratio [-]
%
%   Source: Phase 1 report, Section 3 ("Method: gears"), and Section 4 of the
%   step 1.3 MATLAB task guide. Tested by test_rgb_sizing (TC1-TC3).

% Steps 1 and 2: angles and transverse module
beta = deg2rad(beta_deg);
alpha_n = deg2rad(alpha_n_deg);
alpha_t = atan(tan(alpha_n) / cos(beta));
mt = mn / cos(beta);

% Steps 3 and 4: pitch, base and tip diameters
d1 = z1 * mt;
d2 = z2 * mt;
db1 = d1 * cos(alpha_t);
db2 = d2 * cos(alpha_t);
da1 = d1 + 2 * mn;

% Steps 4 to 6: an internal pair changes three signs. The ring's tip circle is
% inside its pitch circle, the centre distance is the difference of the pitch
% radii, and the ring's part of the path of contact g_alpha is subtracted.
if internal
    da2 = d2 - 2 * mn;
    a = (d2 - d1) / 2;
    g_alpha = sqrt((da1/2)^2 - (db1/2)^2) - sqrt((da2/2)^2 - (db2/2)^2) + a * sin(alpha_t);
else
    da2 = d2 + 2 * mn;
    a = (d1 + d2) / 2;
    g_alpha = sqrt((da1/2)^2 - (db1/2)^2) + sqrt((da2/2)^2 - (db2/2)^2) - a * sin(alpha_t);
end

% Steps 7 to 9: contact ratios and base helix angle
eps_alpha = g_alpha / (pi * mt * cos(alpha_t));   % path of contact / transverse base pitch
eps_beta = b * sin(beta) / (pi * mn);             % face width / axial pitch
beta_b = atan(tan(beta) * cos(alpha_t));

g = struct('z1', z1, 'z2', z2, 'mn', mn, 'b', b, 'internal', internal, ...
           'beta', beta, 'alpha_t', alpha_t, 'beta_b', beta_b, 'mt', mt, ...
           'd1', d1, 'd2', d2, 'db1', db1, 'db2', db2, 'da1', da1, 'da2', da2, ...
           'a', a, 'eps_alpha', eps_alpha, 'eps_beta', eps_beta);
end
