function in = st_inputs()
%ST_INPUTS  Inputs and assumptions of step 3.5: 3-D structural checks of the case, carrier, liners and flange bolts.
%   in = st_inputs()
%
%   Geometry from the CATIA STEP files of step 3.1 (cad/step); loads from
%   steps 2.5 and 2.8 (calc/shafts_bearings, calc/housing); materials from
%   step 3.4 (calc/manufacturing). Every other value is an assumption listed
%   in Section 3.5 of the Phase 3 report. Units: m, N, Pa in the finite
%   element models; mm, N, MPa, degC elsewhere.

% A357-T6 case (step 2.8, step 3.4): casting factor 1.25 (STR-10)
in.al = struct('E', 72e9, 'nu', 0.33, 'rho', 2680, 'sy', 240, 'su', 310, 'cte', 21.5e-6, ...
               'sf', 60, ...                                   % MPa, fatigue strength at 1e8 cycles, R = -1, sand cast (TBR)
               'sy_hot', 200);                                 % MPa, yield after long exposure at 132-150 degC (over-ageing, TBR)
in.k_cast = 1.25;
in.st = struct('E', 205e9, 'nu', 0.29, 'rho', 7830, 'sy', 1100, 'su', 1240, 'cte', 12.3e-6);   % AISI 4340 (carrier, liners)
in.m50 = struct('E', 202e9, 'nu', 0.30, 'cte', 11.7e-6);                                       % M50NiL pins

% Finite element models
in.Hmax = 0.008;                            % m, global element size (step 2.8: about one quadratic element through the walls)
in.Hmax_fine = 0.005;                       % m, convergence check of the limit case
in.Hmax_carrier = 0.005;                    % m, carrier: the 10 mm plates (mass card B) need more than one element through
                                            % their thickness (8 mm: meshed volume 0.5% under CATIA, 5 mm: 0.2%)
in.case_step = fullfile('cad', 'step', 'case.stp');
in.fs_step = fullfile('cad', 'step', 'fs_case.stp');      % first-stage case: blind flange holes, 16 mm rear wall (mount card A)
in.fs = struct('y_pt', -0.145974, 'r_mount', 0.070, 'r_hole', 0.0045, 'r_seat', 0.0425, 'L_seat', 0.023);
% y_pt: PT (pinion) axis; mount ring holes on PCD 140 about it; pinion bearing bores (NU2209 class) [m]
in.carrier_step = fullfile('cad', 'step', 'carrier.stp');
% points that pick the faces of the case [m] (z from the attachment flange face, propeller at +z)
in.pt = struct('flange', [0.140 0 0], 'seat_in', [0 -0.090 0.146], 'seat_out', [0 -0.090 0.429], ...
               'ring1', [0 -0.1295 0.070], 'ring2', [0 0.1295 0.070]);
in.seat_in = [0.028 0.090];                 % [width radius] m: inner propeller roller bearing seat
in.seat_out = [0.034 0.090];                % outer roller and QJ seat
in.ring_z = [0.017 0.125];                  % m, ring seat (bore 259) loaded by the ring reaction torque
in.k_joint = 2.43e11;                       % N/m^3, bolted flange as springs, bolts only, joint opened (step 2.8)

% Loads (step 2.5 and 2.8): LD-05 limit, 1P fatigue, ring reaction torque
in.m_prop = 76.4;  in.g = 9.81;  in.a = 250;  in.span = 300;  in.nz = 2.5;  in.M_gyro = 7190;
in.F_ax = 20e3;                             % N, LD-03/04 thrust on the outer seat
in.thrust = 18e3;                           % N, take-off/climb thrust (mean of the fatigue case)
in.M_1P = 2000;                             % N m, 1P moment (ICD-11: TBR, sensitivity up to about 4,900)
in.K_over = 1.375;                          % LD-01/LD-02 torque factor
in.T_LD08 = 26129 * 0.2 / 0.22;             % N m, LD-08 propeller torque for the 0.22 s stop (steps 2.3, 2.4)
in.f_ma_ref = 0;                            % um, filled from gd_meshes (step 2.4 manufacturing misalignment of the ring mesh)

% Carrier (step 3.1 CATIA body with integral pins; step 3.4: separate M50NiL pins pressed in)
in.carr = struct('a', 0.082, 'r_pin', 0.019, 'r_bore', 0.010, 'plate_t', 0.010, ...   % 10 mm plates (mass card B)
                 'z_plates', [0.000 0.010; 0.092 0.102], ...   % m, rear and front plate (pins straddle mounted)
                 'z_fix', 0.112, ...                            % m, the shaft from the front plate is held at its spline end (TBR)
                 'delta_pin', 0.030, ...                        % mm, diametral interference of the pin (TBR, LN2 shrink)
                 'r_out_eff', 0.040, ...                        % m, effective outer radius of the plate ring around a pin bore
                 'm_10', 23.103);                               % kg, CATIA carrier rebuilt with 10 mm plates (option B copy, step 3.5)
% Open item for the 3.9 drawings (mass card B): the M50NiL pins are pressed into 10 mm instead of 15 mm of plate;
% the press-fit length, the retention against axial creep and the pin tilt under load are checked on the drawing

% Steel seat liners (step 3.4): Lame compound cylinder, liner in the A357 boss
in.liner = struct('brg', {'NU1024', 'NU2209', 'NU2210', '6305'}, ...
                  'r_i', {90, 42.5, 45, 31}, 't', {3, 2.5, 2.5, 2}, 'r_boss', {108, 58, 60, 45}, ...
                  'B', {32, 27, 27, 21}, 'F_r', {27.4e3, 3.0e3, 6.0e3, 2.0e3});
% r_i: bearing outer ring radius [mm], t: liner wall, r_boss: boss outer radius (CATIA), B: liner length,
% F_r: largest radial bearing load at limit [N] (LD-05 for NU1024; step 2.5 for the others, TBR)
in.T_fit = [-40 20 132 149];                % degC
in.mu_fit = 0.15;                           % friction of the liner in the casting (dry, TBR)
in.p_min = 5;                               % MPa, smallest contact pressure kept at 149 degC (TBR)
in.n_liner_min = 1.25;                      % yield safety of the A357 at the liner bosses with the casting factor (delegated decision)
in.boss_L = [28 34];                        % mm, inner and outer propeller bearing bosses (step 2.8 section)

% Flange bolts, VDI 2230 Part 1: 30 x M6 12.9 on PCD 290 into helical coil inserts in the A357 first-stage case
in.bolt = struct('n', 30, 'd', 6, 'P', 1.0, 'd2', 5.350, 'd3', 4.773, 'As', 20.1, 'Rp02', 1080, ...
                 'pcd', 290, 'L_k', 12, 'dw', 10, 'dh', 6.6, 'DA', 24, 'd_washer', 12, ...
                 'muG', 0.12, 'muK', 0.12, 'alphaA', 1.6, 'nu_util', 0.9, 'fZ', 0.008, ...  % fZ: embedding [mm], 3 interfaces
                 'muT', 0.15, 'qF', 1, 'pG', 300, 'z_prop', 0.679, ...                    % joint friction, interfaces, A357 surface
                 'D_ins', 8.0, 'L_ins', 9.0, 'tauB_al', 185, 'n_load', 0.5);                               % pressure limit [MPa] (TBR); propeller CG
% station [m] (outer seat 0.429 + overhang 0.25); helical coil insert OD and length [mm], A357 shear strength [MPa]
% shear path for the torque: dowel pins in the flange (the friction of 30 x M6 cannot carry it, Section 3.5)
in.dowel = struct('n', 6, 'd', 10, 'su', 1240, 't', 12, 'p_allow', 1.5 * 240 / 1.25);   % bearing on A357 (TBR)
% Engine mount ring on the first-stage case (ICD-24 placeholder: 12 holes on PCD 140 about the PT axis, z -172 mm):
% the same VDI 2230 check with M8 and M10 12.9 into inserts; moment arm from the mount face to the propeller CG
in.mount = struct('n', 12, 'pcd', 140, 'z_prop', 0.679 + 0.172, 'L_k', 12, ...
                  'M8', struct('d', 8, 'P', 1.25, 'd2', 7.188, 'd3', 6.466, 'As', 36.6, 'dw', 13, 'dh', 9, 'DA', 22, 'd_washer', 16, 'D_ins', 10.4, 'L_ins', 12), ...
                  'M10', struct('d', 10, 'P', 1.5, 'd2', 9.026, 'd3', 8.160, 'As', 58.0, 'dw', 16, 'dh', 11, 'DA', 26, 'd_washer', 20, 'D_ins', 13, 'L_ins', 15));
% Mass closure (step 3.4): bottom-up fasteners x1.5 and liners; read from calc/results/step34/step34.mat
in.allow_share = 0.05;                      % step 3.1 fastener share, for the card record
in.mass_gap = 1.09;                         % kg, SYS-06 roll-up 111.09 against 110 TBR
in.card = struct('total', 111.0899093, 'carrier', 25.007731182, 'modelled', 104.180866);   % kg, the step 3.2 roll-up of the mass card
in.carr_tilt_15 = 19.14;                    % um over 70 mm, pin tilt of the 15 mm plate carrier at MCT (step 3.5 before the card)
% step 3.3 sensitivity runs may override inputs (calc/interfaces/if_override; no effect otherwise)
if exist('if_override', 'file') == 2, in = if_override(in, mfilename); end
end
