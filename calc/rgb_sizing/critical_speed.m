function n_cr = critical_speed(model, d_o, d_i, L, m_d, a, in)
%CRITICAL_SPEED  First bending critical speed of a hollow shaft on rigid bearings.
%   n_cr = critical_speed('simply_supported', d_o, d_i, L, m_d, [], in)
%   n_cr = critical_speed('overhung', d_o, d_i, L, m_d, a, in)
%
%   'simply_supported': shaft between two bearings with span L and a disc
%   of mass m_d (the gear) at mid-span; the shaft's own mass is added with
%   Dunkerley's formula.
%   'overhung': a disc of mass m_d (the propeller) a distance a outboard of
%   the outer bearing, span L between the bearings; the shaft's own mass
%   and the gyroscopic effect are neglected.
%   d_o, d_i, L, a in mm, m_d in kg; E (shaft_E) and the steel density come
%   from rgb_inputs. n_cr in rpm. DYN-01 asks for
%   n_cr >= ncr_margin x n_cont_max x running speed.
%
%   Source: Phase 1 report, Section 3 ("Critical speed"). Tested by
%   test_rgb_sizing (TC8).

E = in.shaft_E;                             % N/mm^2
I = pi / 64 * (d_o^4 - d_i^4);              % mm^4
switch model
    case 'simply_supported'
        k = 48 * E * I / L^3 * 1e3;         % N/m, stiffness at mid-span
        w_d = sqrt(k / m_d);
        m_sh = in.rho_steel * pi / 4 * (d_o^2 - d_i^2) * L;
        w_s = (pi / (L / 1000))^2 * sqrt(E * 1e6 * I * 1e-12 / (m_sh / (L / 1000)));
        w = 1 / sqrt(1 / w_d^2 + 1 / w_s^2);
    case 'overhung'
        k = 3 * E * I / (a^2 * (L + a)) * 1e3;   % N/m, stiffness at the disc
        w = sqrt(k / m_d);
    otherwise
        error('critical_speed: unknown model ''%s''', model);
end
n_cr = w * 60 / (2 * pi);
end
