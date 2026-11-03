function d = sfd_coeffs(R, L, c, eta, eps, seal)
%SFD_COEFFS  Damping of a short squeeze-film damper land, circular centred orbits.
%   d = sfd_coeffs(R, L, c, eta, eps, seal)
%
%   Inputs
%     R      journal radius                                            [m]
%     L      axial length of the land                                  [m]
%     c      radial clearance                                          [m]
%     eta    dynamic viscosity of the oil in the film                  [Pa s]
%     eps    orbit radius / clearance (0 for small motions)            [-]
%     seal   damping of the land with end seals / with open ends: 1 for
%            open ends; piston-ring seals raise it (damper_inputs)      [-]
%
%   Output struct d
%     C      direct damping, uncavitated (2 pi) film                   [N s/m]
%     C_pi   direct damping if the film cavitates (pi film)            [N s/m]
%     B      R L^3 / c^3, the geometric part of C                      [m]
%
%   Short-bearing (L/D small) solution of the Reynolds equation with open
%   ends: the tangential film force of a circular centred orbit of radius
%   e = eps c is C e omega with C = pi eta R L^3 / (c^3 (1 - eps^2)^1.5).
%   The uncavitated film has no radial force, so no stiffness; the
%   centring spring gives the stiffness.
%
%   Source: Phase 2 report, Section 2.1 ("Damper"); San Andres, Squeeze
%   film dampers: operation, models and technical issues (Texas A&M,
%   lecture notes, 2010); Vance, Rotordynamics of Turbomachinery (1988),
%   Chapter 6. Tested by test_step21 (TC22).

B = R * L^3 / c^3;
C = seal * pi * eta * B / (1 - eps^2)^1.5;
d = struct('C', C, 'C_pi', C / 2, 'B', B);
end
