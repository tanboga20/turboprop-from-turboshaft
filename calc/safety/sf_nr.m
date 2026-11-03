function [Ft, Fb, Q] = sf_nr(kind, a, c, t, b, phi)
%SF_NR  Newman-Raju boundary-correction factors of a surface or corner crack in a finite plate.
%   [Ft, Fb, Q] = sf_nr(kind, a, c, t, b, phi)
%   kind 'surface' (semi-elliptical, plate width 2b) or 'corner' (quarter-elliptical, plate width b); a crack depth,
%   c half-length (surface) or length along the surface (corner), t thickness [any consistent length unit]; phi the
%   parametric angle [rad] (pi/2 the deepest point, 0 the free surface).
%   K = (S_t Ft + S_b Fb) sqrt(pi a / Q): Ft for remote tension, Fb = H F for remote bending (outer-fibre stress).
%   Equations of J. C. Newman and I. S. Raju, NASA TM-85793 (1984): surface crack eqs. (14)-(36), corner crack
%   eqs. (37)-(52); Q by Rawe, eq. (2). Range a/c 0.2-2 (surface down to 0), a/t < 1, c/b < 0.5.
%   Source: Phase 3 report, Section 3.7 (D4).

r = a / c;  at = a / t;
s = sin(phi);  co = cos(phi);
if r <= 1
    Q = 1 + 1.464 * r^1.65;
    fphi = (r^2 * co^2 + s^2)^0.25;
else
    Q = 1 + 1.464 * (1 / r)^1.65;
    fphi = ((1 / r)^2 * s^2 + co^2)^0.25;
end
switch kind
    case 'surface'
        fw = sqrt(sec(pi * c / (2 * b) * sqrt(at)));
        if r <= 1
            M1 = 1.13 - 0.09 * r;
            M2 = -0.54 + 0.89 / (0.2 + r);
            M3 = 0.5 - 1 / (0.65 + r) + 14 * (1 - r)^24;
            g = 1 + (0.1 + 0.35 * at^2) * (1 - s)^2;
            p = 0.2 + r + 0.6 * at;
            H1 = 1 - 0.34 * at - 0.11 * r * at;
            G21 = -1.22 - 0.12 * r;
            G22 = 0.55 - 1.05 * r^0.75 + 0.47 * r^1.5;
        else
            M1 = sqrt(1 / r) * (1 + 0.04 / r);
            M2 = 0.2 * (1 / r)^4;
            M3 = -0.11 * (1 / r)^4;
            g = 1 + (0.1 + 0.35 * (1 / r) * at^2) * (1 - s)^2;
            p = 0.2 + 1 / r + 0.6 * at;
            G11 = -0.04 - 0.41 / r;
            G12 = 0.55 - 1.93 * (1 / r)^0.75 + 1.38 * (1 / r)^1.5;
            H1 = 1 + G11 * at + G12 * at^2;
            G21 = -2.11 + 0.77 / r;
            G22 = 0.55 - 0.72 * (1 / r)^0.75 + 0.14 * (1 / r)^1.5;
        end
        F = (M1 + M2 * at^2 + M3 * at^4) * g * fphi * fw;
    case 'corner'
        assert(c / b < 0.5, 'sf_nr: corner crack beyond c/b 0.5, outside the range of the equations');
        lam = c / b * sqrt(at);
        fw = 1 - 0.2 * lam + 9.4 * lam^2 - 19.4 * lam^3 + 27.1 * lam^4;
        if r <= 1
            M1 = 1.08 - 0.03 * r;
            M2 = -0.44 + 1.06 / (0.3 + r);
            M3 = -0.5 + 0.25 * r + 14.8 * (1 - r)^15;
            g1 = 1 + (0.08 + 0.4 * at^2) * (1 - s)^3;
            g2 = 1 + (0.08 + 0.15 * at^2) * (1 - co)^3;
            p = 0.2 + r + 0.6 * at;
            H1 = 1 - 0.34 * at - 0.11 * r * at;
            G21 = -1.22 - 0.12 * r;
            G22 = 0.64 - 1.05 * r^0.75 + 0.47 * r^1.5;
        else
            ct = c / t;
            M1 = sqrt(1 / r) * (1.08 - 0.03 / r);
            M2 = 0.375 * (1 / r)^2;
            M3 = -0.25 * (1 / r)^2;
            g1 = 1 + (0.08 + 0.4 * ct^2) * (1 - s)^3;
            g2 = 1 + (0.08 + 0.15 * ct^2) * (1 - co)^3;
            p = 0.2 + 1 / r + 0.6 * at;
            G11 = -0.04 - 0.41 / r;
            G12 = 0.55 - 1.93 * (1 / r)^0.75 + 1.38 * (1 / r)^1.5;
            H1 = 1 + G11 * at + G12 * at^2;
            G21 = -2.11 + 0.77 / r;
            G22 = 0.64 - 0.72 * (1 / r)^0.75 + 0.14 * (1 / r)^1.5;
        end
        F = (M1 + M2 * at^2 + M3 * at^4) * g1 * g2 * fphi * fw;
    otherwise
        error('sf_nr: kind must be ''surface'' or ''corner''');
end
H2 = 1 + G21 * at + G22 * at^2;
H = H1 + (H2 - H1) * s^p;
Ft = F;
Fb = H * F;
end
