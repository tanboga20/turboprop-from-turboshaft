function brg = planet_bearing(dp, m, b, Ft, mp, rc, nc, n_rel, in)
%PLANET_BEARING  Cylindrical roller bearing inside a planet; the planet bore is the outer race.
%   brg = planet_bearing(dp, m, b, Ft, mp, rc, nc, n_rel, in)
%
%   Inputs
%     dp      planet pitch diameter                                  [mm]
%     m       module                                                 [mm]
%     b       face width                                             [mm]
%     Ft      tangential force of one mesh on the most heavily loaded
%             planet, K_gamma included                               [N]
%     mp      mass of the planet and its rollers; 0 for a first call
%             that only sizes the rollers                            [kg]
%     rc      radius of the planet centres on the carrier            [mm]
%     nc      carrier speed                                          [rpm]
%     n_rel   planet speed relative to the carrier                   [rpm]
%     in      rgb_inputs: rim, bearing ratios, mission, K_over, overspeed
%
%   Output struct brg
%     D_or, D_w, D_pw, d_pin  outer race, roller, roller pitch and pin diameters [mm]
%     Z, L_w                  roller count [-] and roller length     [mm]
%     C, C0                   basic dynamic and static load ratings  [N]
%     F_gear, F_c             gear load of the two meshes, centrifugal load [N]
%     P100                    bearing load at 100% torque            [N]
%     L10_100, L10_mission    basic life at 100% torque and over the A-05 mission [h]
%     s0                      static safety at 137.5% torque and 110% speed [-]
%     DN                      pin diameter x relative speed at 110%  [mm rpm]
%
%   Source: Phase 1 report, Section 3 ("Method: planet bearing" and "Check
%   against the standards"). C and C0 follow ISO 281 (b_m = 1.1, f_c = 88) and
%   ISO 76. f_c = 88 agrees with ISO/TR 1281-1:2021 (87.7 to 88.8 for gamma
%   0.14 to 0.18); b_m and C0 still need ISO 281:2007 and ISO 76:2006 to be
%   checked. Tested by test_rgb_sizing (TC5).

% Roller set that fits inside the planet
D_or = dp - 2.5 * m - 2 * in.rim * m;       % root circle minus the rim
D_w = in.brg_Dw_ratio * D_or;
D_pw = D_or - D_w;
Z = floor(pi * D_pw / (in.brg_pitch * D_w));
L_w = in.brg_Lw_ratio * b;
d_pin = D_pw - D_w;

% Load ratings
C = 1.1 * 88 * L_w^(7/9) * Z^(3/4) * D_w^(29/27);
C0 = 44 * (1 - D_w / D_pw) * Z * L_w * D_w;

% Loads: the tangential forces of the two meshes add on the pin; the
% centrifugal load of the planet is perpendicular to them
wc = nc * 2 * pi / 60;
F_c = mp * rc / 1000 * wc^2;
F_gear = 2 * Ft;
P100 = hypot(F_gear, F_c);

% Life: Palmgren-Miner over the mission steps at constant speed
L10_100 = (C / P100)^(10/3) * 1e6 / (60 * n_rel);
damage = 0;
for j = 1:size(in.mission, 1)
    P = hypot(F_gear * in.mission(j, 2), F_c);
    damage = damage + in.mission(j, 1) / ((C / P)^(10/3) * 1e6 / (60 * n_rel));
end
L10_mission = 1 / damage;

% Static safety at the LD-01 torque and the SYS-04 overspeed
P0 = hypot(F_gear * in.K_over, F_c * in.overspeed^2);
s0 = C0 / P0;

brg = struct('D_or', D_or, 'D_w', D_w, 'D_pw', D_pw, 'd_pin', d_pin, 'Z', Z, 'L_w', L_w, ...
             'C', C, 'C0', C0, 'F_gear', F_gear, 'F_c', F_c, 'P100', P100, ...
             'L10_100', L10_100, 'L10_mission', L10_mission, 's0', s0, ...
             'DN', d_pin * n_rel * in.overspeed);
end
