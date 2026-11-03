function [mass, D] = rgb_mass(part, in, varargin)
%RGB_MASS  Mass of one RGB part from its main dimensions (rough model).
%   [mass, D] = rgb_mass(part, in, ...)
%
%   Lengths in mm, mass in kg; in comes from rgb_inputs (densities, housing
%   wall and factor). The parts, their arguments and formulas (rho steel
%   density, rho_al aluminium density):
%     rgb_mass('pinion', in, d, b)    rho pi/4 d^2 b x 0.75 (d pitch diameter)
%     rgb_mass('gear2', in, d, b)     x 0.45: web and lightening holes
%     rgb_mass('sun', in, d, b)       x 0.70: bore for the sun shaft
%     [mass, D_h] = rgb_mass('ring', in, d_r, m, b)
%         1.3 rho pi/4 (D_h^2 - (d_r - 2 m)^2) b, outer diameter
%         D_h = d_r + 2.5 m + 7 m (root circle plus a 3.5 m rim); 1.3 for the flange
%     [mass, t] = rgb_mass('carrier', in, d_s, d_p, d_pin, N, b)
%         two plates of diameter d_s + 2 d_p and thickness t = 0.25 b, x 0.55
%         for the windows, and N pins with a 0.5 d_pin bore, b + 2 t long
%     rgb_mass('shaft', in, d_o, d_i, L)    hollow shaft of length L
%     rgb_mass('flange', in, d_o)     propeller flange: diameter 2 d_o, 20 mm thick, x 0.7
%     [mass, D] = rgb_mass('bearing', in, d, k_B)
%         rolling bearing of bore d: outer diameter D = 1.6 d + 20, width
%         0.22 D k_B (k_B = 1.2 for the propeller QJ, else 1), x 0.55
%     rgb_mass('housing', in, a, D_z, L_g)
%         cast housing with a stadium section around both axes (centre
%         distance a, envelope diameter D_z, length L_g):
%         rho_al (P L_g + 2 A_u) wall x factor, P = 2a + pi D_z, A_u = pi/4 D_z^2 + a D_z
%   The second output D is the dimension of the ring, carrier or bearing
%   given above; it is empty for the other parts.
%
%   Source: Phase 1 report, Section 3 ("Method: mass and selection"). Tested
%   by test_rgb_sizing (TC9).

rho = in.rho_steel;
D = [];
switch part
    case 'pinion'
        [d, b] = varargin{:};
        mass = rho * pi / 4 * d^2 * b * 0.75;
    case 'gear2'
        [d, b] = varargin{:};
        mass = rho * pi / 4 * d^2 * b * 0.45;
    case 'sun'
        [d, b] = varargin{:};
        mass = rho * pi / 4 * d^2 * b * 0.7;
    case 'ring'
        [d_r, m, b] = varargin{:};
        D = d_r + 2.5 * m + 7 * m;
        mass = 1.3 * rho * pi / 4 * (D^2 - (d_r - 2 * m)^2) * b;
    case 'carrier'
        [d_s, d_p, d_pin, N, b] = varargin{:};
        t = 0.25 * b;
        d_c = d_s + 2 * d_p;
        mass = 2 * rho * pi / 4 * d_c^2 * t * 0.55 ...
               + N * rho * pi / 4 * (d_pin^2 - (0.5 * d_pin)^2) * (b + 2 * t);
        D = t;
    case 'shaft'
        [d_o, d_i, L] = varargin{:};
        mass = rho * pi / 4 * (d_o^2 - d_i^2) * L;
    case 'flange'
        d_o = varargin{1};
        mass = rho * pi / 4 * (2 * d_o)^2 * 20 * 0.7;
    case 'bearing'
        [d, k_B] = varargin{:};
        D = 1.6 * d + 20;
        mass = 0.55 * rho * pi / 4 * (D^2 - d^2) * (0.22 * D * k_B);
    case 'housing'
        [a, D_z, L_g] = varargin{:};
        P = 2 * a + pi * D_z;               % perimeter of the stadium section
        A_u = pi / 4 * D_z^2 + a * D_z;     % area of one end face
        mass = in.rho_al * (P * L_g + 2 * A_u) * in.housing_wall * in.housing_factor;
    otherwise
        error('rgb_mass: unknown part ''%s''', part);
end
end
