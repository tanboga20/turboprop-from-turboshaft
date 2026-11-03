function sc = squirrel_cage(n, l, w, t, E)
%SQUIRREL_CAGE  Radial stiffness and bar stress of a squirrel-cage centring spring.
%   sc = squirrel_cage(n, l, w, t, E)
%
%   Inputs
%     n      number of bars, equally spaced                            [-]
%     l      free length of a bar                                      [m]
%     w      tangential width of a bar                                 [m]
%     t      radial thickness of a bar                                 [m]
%     E      Young's modulus                                           [Pa]
%
%   Output struct sc
%     k      radial stiffness of the cage, the same in every direction [N/m]
%     s_per_m  largest bar bending stress per metre of cage deflection
%            (sigma = s_per_m x delta)                                  [Pa/m]
%
%   Each bar is a fixed-guided beam: its stiffness is E w t^3 / l^3 for
%   radial bending and E t w^3 / l^3 for tangential bending. With n >= 3
%   equally spaced bars the cage stiffness is n / 2 times their sum in any
%   direction. A fixed-guided bar bent by delta has the end moment
%   6 E I delta / l^2, so the outer fibre stress is 3 E h delta / l^2,
%   h = max(w, t).
%
%   Source: Phase 2 report, Section 2.1 ("Centring spring"); Vance,
%   Zeidan and Murphy, Machinery Vibration and Rotordynamics (2010),
%   Section 6.6. Tested by test_step21 (TC23).

k_r = E * w * t^3 / l^3;
k_t = E * t * w^3 / l^3;
k = n / 2 * (k_r + k_t);
s_per_m = 3 * E * max(w, t) / l^2;
sc = struct('k', k, 's_per_m', s_per_m, 'k_bar_r', k_r, 'k_bar_t', k_t);
end
