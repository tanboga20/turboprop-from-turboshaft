function in = rgb_inputs()
%RGB_INPUTS  Inputs and assumptions of the step 1.3 RGB sizing, in one struct.
%   in = rgb_inputs()
%
%   Requirement values are from requirements v1 (IDs in the comments); every
%   other value is an assumption from the Assumptions table of Section 3 of
%   the Phase 1 report. The other functions take their numbers from here.
%   Units: W, N, N m, mm, rpm, MPa, kg, h unless noted.

% Requirements v1
in.P = 895e3;                               % W, take-off = maximum continuous power (SYS-01)
in.n_PT = 22000;                            % rpm, power turbine (SYS-02)
in.n_prop = 1700;                           % rpm, propeller (SYS-02)
in.i_target = in.n_PT / in.n_prop;          % 12.941 (SYS-02)
in.i_tol = 0.005;                           % relative ratio tolerance (SYS-02)
in.T_PT = in.P / (in.n_PT * 2 * pi / 60);   % 388.5 N m
in.T_prop = in.P / (in.n_prop * 2 * pi / 60);   % 5,027 N m
in.K_over = 1.375;                          % transient torque for 20 s (LD-01)
in.overspeed = 1.10;                        % 110% speed for 20 s (SYS-04)
in.mission = [1/30 1.0; 28/30 0.5; 1/30 0.3];   % [time share, torque share], constant speed (A-05)
in.L10_req = 12000;                         % h, bearing life over the mission (STR-02)
in.s0_min = 2.0;                            % bearing static safety at limit load (STR-02)
in.SH_min = 1.2;                            % pitting safety at maximum continuous torque (STR-01)
in.SF_min = 1.5;                            % bending safety (STR-01)
in.m_prop = 76.4;                           % kg, propeller mass (A-04)
in.Ip_prop = 15;                            % kg m^2, propeller polar moment of inertia, estimate (A-04)
in.g = 9.81;                                % m/s^2
in.thrust = 20e3;                           % N, in either direction (LD-03, LD-04)
in.M_gyro = in.Ip_prop * (in.n_prop * 2 * pi / 60) * hypot(2.5, 1.0);   % 7.19 kN m: 2.5 rad/s yaw, 1.0 rad/s pitch (LD-05)
in.nz_gyro = 2.5;                           % normal load factor taken with M_gyro (LD-05)
in.ult_factor = 1.5;                        % shafts: no failure at 1.5 x limit load (STR-03)
in.n_cont_max = 1.01;                       % top of the continuous speed range, 90-101% (DYN-01)
in.ncr_margin = 1.2;                        % bending critical speeds at least 20% above it (DYN-01)

% Tooth counts (search ranges and rules)
in.z1_range = 25:40;                        % first-stage pinion
in.u1_range = [2.6 3.8];                    % first-stage ratio z2/z1
in.zs_range = 18:45;                        % sun
in.zp_range = 15:70;                        % planet; ring zr = zs + 2 zp
in.N_list = [3 4 5];                        % planet counts
in.tip_clear_min = 1.0;                     % modules between neighbouring planet tips

% Gear geometry
in.alpha_n = 20;                            % deg, normal pressure angle, no profile shift
in.modules = [2 2.25 2.5 2.75 3 3.5 4 4.5 5 5.5 6 7 8];   % mm, ISO 54 series from 2 mm
in.beta1 = 15;                              % deg, first stage single helical
in.psi1 = 0.8;                              % b1 = ceil(psi1 d1)
in.psi2 = 0.8;                              % b2 = ceil(psi2 min(d_s, d_p))
in.post_gap_min = 15;                       % mm between neighbouring planet tip circles (carrier post)
in.rim = 3;                                 % planet rim below the root circle, in modules

% Gear rating (ISO 6336:2019 in simplified form; Section 3 of the report says what is simplified)
in.f = struct('KA', 1.25, 'Kv', 1.1, 'KHb', 1.15, 'KHa', 1.0, 'Kgam', 1.0, ...
              'ZNT', 0.85, 'YNT', 0.85, 'ZLvR', 0.95, 'ZE', 189.8, ...
              'sHlim1', 1500, 'sFlim1', 500, 'sHlim2', 1500, 'sFlim2', 500, ...
              'YM1', 1.0, 'YM2', 1.0, 'fZCa', 1.0);   % carburized steel MQ on both gears
% K_A 1.25: ISO 6336-1:2019 Table 4 for a gas turbine with uniform operation (Table 5)
% driving a propeller taken as light shocks, like the fans and axial compressors of Table 7.
% f_ZCa 1.0: ISO 6336-2:2019 Table 3; needs optimised flank modifications on stage 1 (Phase 2).
in.Kgam = [1.00 1.15 1.19];                 % planet load sharing for N_list: AGMA 6123-C16 Table 7, level 3
in.ZNT_static = 1.6;                        % static life factors (LD-01), case-carburized steel
in.YNT_static = 2.5;
in.ring_sHlim = 1250;                       % MPa, nitrided ring, MQ
in.ring_sFlim = 420;
in.ring_ZNT_static = 1.3;                   % static life factors of the nitrided ring
in.ring_YNT_static = 1.6;
in.YM_planet = 0.7;                         % a planet tooth bends both ways

% Planet bearing: cylindrical rollers, the planet bore is the outer race
in.brg_Dw_ratio = 0.138;                    % roller diameter / outer race diameter
in.brg_pitch = 1.2;                         % roller pitch on the pitch circle / roller diameter
in.brg_Lw_ratio = 0.8;                      % roller length / face width

% Shafts: AISI 4340 (AMS 6414), hollow; Goodman line with Marin factors (Shigley, 10th ed.)
in.shaft_su = 1240;                         % MPa, ultimate tensile strength
in.shaft_sy = 1100;                         % MPa, yield strength
in.shaft_E = 205e3;                         % MPa
in.shaft_bore = 0.6;                        % d_i / d_o, the propeller shaft carries the oil tube (PIF-02)
in.shaft_step = 5;                          % mm, d_o steps
in.shaft_d0_stage1 = 20;                    % mm, first d_o tried on the input and intermediate shafts
in.shaft_d0_prop = 60;                      % mm, first d_o tried on the propeller shaft
in.shaft_d_max = 200;                       % mm, size_shaft gives up above this
in.Kf = 2.0;                                % fatigue notch factor in bending (grooves, shoulders)
in.Kfs = 1.6;                               % fatigue notch factor in torsion
in.ka = 1.38 * in.shaft_su^(-0.067);        % surface factor, ground
in.ke = 0.753;                              % reliability factor, 99.9%
in.nf_min = 1.5;                            % Goodman fatigue safety

% Shaft layout and propeller loads
in.span1_extra = 50;                        % mm, first-stage shaft span = b1 + 50
in.prop_span = 300;                         % mm between the propeller shaft bearings
in.prop_overhang = 250;                     % mm, outer bearing to propeller centre of gravity
in.M_1P = 2000;                             % N m, steady 1P bending moment for fatigue, until the LD-07 values arrive

% Main bearings: two roller bearings and a QJ per shaft; the QJ is radially free (P = 1.07 F_a)
in.thrust_spectrum = [1/30 18e3; 28/30 3e3; 1/30 2e3];   % [time share, thrust N]: take-off and climb, loiter, descent
in.DN_max = 2.0e6;                          % bore (mm) x speed (rpm) at 110% speed

% Materials and mass
in.rho_steel = 7.85e-6;                     % kg/mm^3
in.rho_al = 2.68e-6;                        % kg/mm^3, A357 cast aluminium housing
in.housing_wall = 5;                        % mm
in.housing_factor = 1.6;                    % ribs, flanges and bearing seats
in.m_accessory = 6;                         % kg, accessory drives (to be firmed up in 1.4)
in.misc_share = 0.10;                       % seals, jets, tubes, bolts and sensors, share of the subtotal

% Selection
in.m_max = 100;                             % kg, RGB dry mass with the propeller shaft and accessory drives (SYS-06)
in.select_band = 0.5;                       % kg: designs this close to the lightest count as equally light
end
