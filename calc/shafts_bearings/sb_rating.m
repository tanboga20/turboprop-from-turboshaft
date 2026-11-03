function r = sb_rating(b, b_m)
%SB_RATING  Basic dynamic and static load ratings and fatigue load limit of one rolling bearing.
%   r = sb_rating(b, b_m)
%
%   Inputs
%     b     bearing struct (sb_inputs): type 'CRB' or 'QJ', Z, Dw, Lwe
%           (rollers), Dpw, alpha [deg], i (rows; 2 for a four-point
%           contact bearing, rated as a double-row bearing); mm
%     b_m   rating factor for contemporary material and quality       [-]
%
%   Output struct r: gamma, f_c, C, C0, Cu [N], d_m [mm], and for the
%   ball bearing f_0 (the static factor that ISO 76 tabulates) [-].
%
%   Dynamic rating, ISO 281 in the form derived in ISO/TR 1281-1:2021:
%     roller  C = b_m f_c (i Lwe cos a)^(7/9) Z^(3/4) Dw^(29/27), f_c by
%             Formula (34) with lambda nu = 0.83 (Table 2);
%     ball    C = b_m f_c (i cos a)^0.7 Z^(2/3) Dw^1.8 (Dw <= 25.4 mm), f_c
%             by Formula (15), groove radii 0.52 Dw, lambda = 0.95 (Table 1).
%   Static rating at the ISO 76 contact stress: roller C0 = 44 (1 - gamma)
%   i Z Lwe Dw cos a (4,000 MPa); ball C0 from the Hertz point contact at
%   the inner raceway reaching 4,200 MPa with the Stribeck load Qmax = 5
%   Fr / (i Z cos a). Fatigue load limit by the simplified ISO 281 forms:
%   roller C0 / 8.2, ball C0 / 22, reduced by (100/d_m)^0.3 or ^0.5 above
%   d_m = 100 mm. ISO 281 and ISO 76 are not in the project library: b_m
%   and the C_u forms are TBR.
%   Source: Phase 2 report, Section 2.5 ("Bearings"). Tested by test_step25
%   (TC40).

a = deg2rad(b.alpha);
g = b.Dw * cos(a) / b.Dpw;
d_m = b.Dpw;
switch b.type
    case 'CRB'
        q = (1 - g) / (1 + g);
        f_c = 551.13373 * 0.377 * 0.83 * g^(2/9) * (1 - g)^(29/27) / (1 + g)^(1/4) ...
              * (1 + (1.04 * q^(143/108))^(9/2))^(-2/9);
        C = b_m * f_c * (b.i * b.Lwe * cos(a))^(7/9) * b.Z^(3/4) * b.Dw^(29/27);
        C0 = 44 * (1 - g) * b.i * b.Z * b.Lwe * b.Dw * cos(a);
        Cu = C0 / 8.2;
        if d_m > 100, Cu = Cu * (100 / d_m)^0.3; end
        f_0 = NaN;
    otherwise
        fr = 0.52;                           % groove radius / Dw, inner and outer
        q = (1 - g) / (1 + g);
        f_c = 98.0665 * 0.41 * 0.95 * (2 * fr / (2 * fr - 1))^0.41 * g^0.3 * (1 - g)^1.39 / (1 + g)^(1/3) ...
              * (1 + (1.04 * q^1.72)^(10/3))^(-3/10);
        C = b_m * f_c * (b.i * cos(a))^0.7 * b.Z^(2/3) * b.Dw^1.8;
        Q4200 = hertz_ball_load(b.Dw, g, fr, 4200);
        C0 = b.i * b.Z * cos(a) * Q4200 / 5;
        f_0 = C0 / (b.i * b.Z * b.Dw^2 * cos(a));
        Cu = C0 / 22;
        if d_m > 100, Cu = Cu * (100 / d_m)^0.5; end
end
r = struct('gamma', g, 'f_c', f_c, 'C', C, 'C0', C0, 'Cu', Cu, 'd_m', d_m, 'f_0', f_0);
end

function Q = hertz_ball_load(Dw, g, fr, sigma)
% Ball load that gives the contact stress sigma at the inner raceway
% (Hamrock-Brewe approximations of the elliptic integrals)
Ep = 2 / (2 * (1 - 0.3^2) / 206e3);
rho = [2 / Dw, 2 / Dw, 2 * g / (Dw * (1 - g)), -1 / (fr * Dw)];
Rx = 1 / (rho(1) + rho(3));
Ry = 1 / (rho(2) + rho(4));
k = 1.0339 * (Ry / Rx)^0.636;
E = 1.0003 + 0.5968 * Rx / Ry;
R = 1 / (1 / Rx + 1 / Ry);
s1 = @(Q) 3 * Q / (2 * pi * (6 * k^2 * E * Q * R / (pi * Ep))^(1/3) * (6 * E * Q * R / (pi * k * Ep))^(1/3));
Q = (sigma / s1(1))^3;
end
