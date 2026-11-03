function in = as_inputs()
%AS_INPUTS  Inputs and assumptions of step 3.1: completing the RGB model.
%   in = as_inputs()
%
%   The first-stage case, the accessory drives, the bought parts (as
%   envelopes), the carrier plate lightening, a placeholder propeller flange
%   and the mass roll-up. Gear, shaft and bearing sizes come from the Phase 2
%   tools (calc/gear_detail, calc/shafts_bearings, calc/accessory on the
%   path); every other value is an assumption listed in Section 3.1 of the
%   Phase 3 report. TBD marks values that belong to an interface partner
%   and are assumed here (their sensitivity is shown in the report).
%   Coordinates: Z is the propeller axis, z = 0 the attachment flange face of
%   the planetary case, the propeller at +z; the power turbine (PT) axis is
%   a_s1 below the propeller axis (angle 270 deg); angles are measured from
%   +X counter-clockwise looking from the propeller (right hand about +Z).
%   Units: mm, kg, N, N m, MPa, deg unless noted.

% First stage: gears centred between their roller bearings (step 2.5 span), the front roller
% bearings behind the 12 mm front wall of the first-stage case so that the 30 tapped holes of the
% planetary case flange (step 2.8) keep their full thread depth
in.span = 102;                              % mm, roller bearing span of every first-stage shaft (step 2.5)
in.wall_front = 12;                         % mm, front wall of the first-stage case (M6 thread 9 + run-out)
in.wall = 8;                                % mm, cast wall (step 2.8 nose wall)
in.wall_side = 6;                           % mm, side walls of the first-stage case and the cover (SYS-06
                                            % package A; 5-6 mm is usual for A357 sand castings)
in.wall_end = 8;                            % mm, end walls of the first-stage case away from the bolt ring
in.wall_rear = 16;                          % mm, rear (engine-side) wall of the first-stage case: Hamit's mount card A
                                            % (step 3.5): the propeller loads go to mounts on the planetary case flange,
                                            % and the 16 mm wall keeps the first-stage tilt at 7.8 um (f_ma 7.1 um)
in.gap_gear = 8;                            % mm, radial gap between gear tips and the case wall
in.boss = 9;                                % mm, radial metal around a bearing seat
in.gap_ax = 1.5;                            % mm, axial gap bearing to wall face

% Bought parts: bearings of steps 2.5 and 2.6 as solid envelopes [d D B]; mass = envelope volume x
% steel density x fill (rings + rolling elements fill about 70-80% of the envelope: SKF catalogue
% masses of NU 2209, 6305 and NU 1024 give 0.79, 0.68 and 0.74; TBR with the bearing supplier)
in.fill_brg = 0.72;
in.brg = struct('name', {'NU2209', 'QJ209', 'NU2210', 'QJ210', 'NU1024', 'QJ1024', '6305', '6202', '6203'}, ...
                'dDB', {[45 85 23], [45 85 19], [50 90 23], [50 90 20], [120 180 28], [120 180 28], ...
                        [25 62 17], [15 35 11], [17 40 12]});
% Shaft nuts (KM envelopes [d OD B]) for the four-point contact bearings
in.nut = struct('name', {'KM9', 'KM10', 'KM24'}, 'dOB', {[45 65 10], [50 70 11], [120 155 20]});
% Seals (carbon face seal envelopes [d_in d_out B], TBR with the seal supplier); a seal is lighter
% than its envelope (carbon ring, steel mating ring, housing): fill 0.5
in.seal = struct('name', {'prop', 'input', 'gen'}, 'dDB', {[122 160 14], [40 82 10], [27 60 8]});
in.fill_seal = 0.5;

% Accessory drives: pad and unit envelopes [diameter length] (TBD with the accessory suppliers;
% the generator is a 52 kW AC machine of 16 kg, step 2.6)
in.unit = struct('name', {'generator', 'OSG', 'PCU'}, 'DL', {[200 300], [90 120], [120 150]});
in.pump = struct('D', 84, 'L', 40, 'm', 2.2);   % supply + scavenge pump pack (step 2.7 flows), mass TBR
% Installation C: the RGB sits behind the core, the PT shaft comes through a tunnel in the exhaust
% collector (step 2.2), so the engine-side face of the RGB (-z) looks at the tunnel and the collector
in.r_ker = 70;                              % mm, keep-out radius about the PT axis on the engine side:
                                            % diaphragm rim radius 50 (step 2.2) + clamp flange and guard (TBD)
in.L_free = 330;                            % mm, free length between the RGB engine-side face and the
                                            % exhaust collector (TBD, inside SYS-10's 0.60 m)
in.R_exh = 250;                             % mm, radius of the collector and its heat shield about the
                                            % PT axis (TBD, engine maker)
in.gap_pack = 5;                            % mm, smallest gap between units, covers and keep-outs
in.ang_step = 1;                            % deg, grid of the angle search

% Planetary nose: the outer roller seat of the step 2.8 case (z 412-446, 34 mm) holds one 28 mm
% bearing, so the four-point contact propeller bearing goes into a bolted steel housing on the nose
% face, with the shaft nut and the propeller shaft seal in front of it
in.qjh = struct('t', 8, 'flange', [120 8]);   % titanium housing: wall over the bearing, flange [r_out t]
in.rho = struct('steel', 7830, 'A357', 2680, 'Ti', 4430, 'seal', 7830);

% Propeller: placeholder flange (PIF-01 is TBD: the flange of the propeller supplier comes in 3.3)
in.pflange = struct('D', 230, 't', 16, 'hub_D', 140, 'hub_L', 12, 'pcd', 190, 'n', 8, 'd_hole', 17);
in.ret_tube_z0 = 112;                       % mm, the tube starts at the carrier front plate (it cannot
                                            % pass the sun, whose bore is 48 mm)

% Carrier plate lightening: circular scallops in the plate rim between pins and posts, through both
% plates; checked with a plane-stress model of the front plate (the full 3-D check is step 3.5)
in.carr = struct('n_sc', 8, 'r_sc', 122, 'R_sc', 22, 'rho', 7830, 'E', 205e3, 'nu', 0.29, 'sy', 1100, ...
                 'r_shaft', 60, 'Hmax', 2.5, 'pin_bore', 20, 'plate_t', 10);
% r_sc: centre radius, R_sc: scallop radius, Hmax: element size of the plate model, pin_bore: bore of the
% hollow planet pins (SYS-06 package A; it can feed the planet bearing oil, step 3.2) [mm]; plate_t: plate
% thickness, 15 -> 10 mm by Hamit's mass card (package B, step 3.5: LD-08 yield safety 2.41 in 3-D); the inner
% faces of the plates stay where they were, so the planets and the pins do not move

% Mass roll-up (SYS-06: dry RGB with the propeller shaft and the accessory drives, at most 100 kg)
in.m_limit = 100;                           % kg, SYS-06 in requirements v3
in.m_limit_tbr = 110;                       % kg, SYS-06 by Hamit's decision in step 3.1 (TBR, requirements/changes_phase3.csv)
in.allow_share = 0.05;                      % bolts, studs, washers, locking (share of the modelled mass): steps 3.1-3.4
% Hamit's mass card (package B, step 3.5): the share is replaced by the bottom-up fastener list of step 3.4 x 1.5,
% and the parts the CATIA bodies do not hold are added: steel seat liners (3.4), flange dowels and the thicker
% NU1024 bosses (3.5); requirements/changes_phase3.csv
in.fasteners = 1.958092;                    % kg, 170 fasteners in 12 joints, 1.31 kg x 1.5 (calc/manufacturing)
in.extra = struct('name', {'steel bearing seat liners (step 3.4)', 'flange dowel pins 6 x 10 mm (step 3.5)', ...
                           'thicker NU1024 bosses for the liner fit (step 3.5)'}, 'm', {1.281249, 0.088555, 0.435680});
in.allow = struct('name', {'oil jets, tubes and manifolds (step 3.2)', 'HUMS sensors and harness (step 2.10)', ...
                           'filter housing and valves (step 2.7)'}, 'm', {1.5, 0.8, 0.9});
% Input drive (SYS-11, Hamit's decision, TBR): the PT output shaft, its two couplings and the
% shaft tunnel, a mass line of its own beside SYS-06. Shaft and couplings as modelled in step 2.2; the
% tunnel estimated from the step 2.2 thermal design: Inconel 625 liner, ceramic-fibre blanket in a sealed
% foil, CRES skin, between the diaphragms, plus end rings and supports
in.drive = struct('shaft', 1.31, 'couplings', 2 * 1.2);        % kg: AISI 4340 66 x 1.5 x 550 mm; 2 x m_half
in.tunnel = struct('L', 550, 'r_in', 43, 't_liner', 0.5, 'rho_liner', 8440, 't_ins', 15, 'rho_ins', 128, ...
                   't_skin', 0.3, 'rho_skin', 7920, 'm_ends', 0.3);
% r_in: shaft radius 33 + 10 mm gap (step 2.2); rho_ins: blanket density (TBR); m_ends: end rings, supports [kg]
in.m_drive_limit = 6;                       % kg, SYS-11 (TBR): modelled shaft and couplings + tunnel, rounded up
in.ext = struct('name', {'oil cooler (step 2.7)', 'oil tank, empty (step 2.7)'}, 'm', {4.4, 1.6});
% ext: RGB oil system parts mounted on the airframe or nacelle, outside the SYS-06 basis of Phases 1
% and 2 (shown separately)
% step 3.3 sensitivity runs may override inputs (calc/interfaces/if_override; no effect otherwise)
if exist('if_override', 'file') == 2, in = if_override(in, mfilename); end
end
