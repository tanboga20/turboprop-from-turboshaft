function r = bearing_loss(d_m, n, nu, P1, f0, f1)
%BEARING_LOSS  Friction loss of one rolling bearing (Palmgren).
%   r = bearing_loss(d_m, n, nu, P1, f0, f1)
%
%   Inputs
%     d_m   mean bearing diameter (d + D)/2; for a planet bearing the
%           roller pitch diameter                                    [mm]
%     n     speed of the rotating ring relative to the other ring   [rpm]
%     nu    kinematic oil viscosity at the operating temperature     [cSt]
%     P1    load that sets the load term: radial load of a roller
%           bearing, axial load of a QJ                              [N]
%     f0    speed factor (bearing type and lubrication)              [-]
%     f1    load factor                                              [-]
%
%   Output struct r
%     M0    speed-dependent friction torque                          [N mm]
%           1e-7 f0 (nu n)^(2/3) d_m^3 if nu n >= 2000, else 160e-7 f0 d_m^3
%     M1    load-dependent friction torque, f1 P1 d_m                [N mm]
%     P     power loss (M0 + M1) omega                               [W]
%
%   Source: Palmgren's method as given by Harris (Rolling Bearing Analysis),
%   which NASA TM-83716 used for the no-load bearing losses; Phase 1 report,
%   Section 4 ("Power losses and efficiency"). Tested by test_step14 (TC13).

if nu * n >= 2000
    M0 = 1e-7 * f0 * (nu * n)^(2/3) * d_m^3;
else
    M0 = 160e-7 * f0 * d_m^3;
end
M1 = f1 * P1 * d_m;
r = struct('M0', M0, 'M1', M1, 'P', (M0 + M1) / 1000 * n * 2 * pi / 60);
end
