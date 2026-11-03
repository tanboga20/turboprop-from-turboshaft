function in = ptshaft_inputs()
%PTSHAFT_INPUTS  Inputs and assumptions of step 2.2: power turbine output shaft, couplings, tunnel.
%   in = ptshaft_inputs()
%
%   Installation C drives out of the rear of the core: a floating drive
%   shaft with a diaphragm coupling at each end runs from the power turbine
%   (PT) rear stub, through a tunnel in the exhaust collector, to the RGB
%   input pinion. Requirement values are from requirements v2 (IDs in the
%   comments); torques from step 1.4; every other value is an assumption
%   from the Assumptions table of Section 2.2 of the Phase 2 report.
%   Units: SI (m, kg, N, s, Pa, K or degC) unless noted; speeds in rpm.

% Speeds and torques
in.n_PT = 22000;                        % rpm, 100% (SYS-02)
in.n_steady = [19855 22200];            % rpm, 90-101% (SYS-03)
in.n_over = 24200;                      % rpm, 110% for 20 s (SYS-04)
in.n_break = 1.30 * 22000;              % rpm, peak after a drive-chain break, 1.05 x 123.3% (SAF-03)
in.margin = 0.20;                       % bending criticals 20% away from SYS-03 (DYN-01)
in.ncr_extra = 1.05;                    % design margin on top of DYN-01 for the coupling masses and stiffness
in.T_100 = 895e3 / (22000 * pi / 30);   % N m, 388.5: propeller power only (SYS-01)
in.T_MC = 417.33;                       % N m, maximum continuous with the generator loaded (step 1.4, SYS-08)
in.T_lim = 1.375 * in.T_100;            % N m, 534.2 (LD-01)
in.T_alt = 0.10;                        % alternating torque / T_MC for fatigue, until step 2.3 gives it

% Floating shaft: AISI 4340 (AMS 6414), thin-walled tube between the two diaphragms
in.L = 0.55;                            % m, diaphragm to diaphragm (exhaust collector length, assumption)
in.L_list = [0.45 0.55 0.60 0.65 0.70]; % m, sensitivity
in.shaft = struct('E', 205e9, 'nu', 0.29, 'rho', 7850, 'su', 1240e6, 'sy', 1100e6, ...
                  'dE_dT', -2.6e-4);    % dE/E per K (and the same for G): the torque meter's temperature error
in.D_list = (0.040:0.002:0.090);        % m, outer diameters tried
in.t_list = (0.0015:0.0005:0.0050);     % m, wall thicknesses tried
in.m_half = 1.2;                        % kg, half coupling (diaphragm, spacer flange, bolts) at each shaft end
in.k_rad = 5e8;                         % N/m, radial stiffness of a diaphragm (in-plane), shaft end support
in.n_f_min = 1.5;                       % Goodman fatigue safety (STR-03)
in.n_buck_min = 3.0;                    % torsional buckling safety at limit torque
in.kt_min = 44000;                      % N m/rad, torsional stiffness floor of the floating shaft from step 2.3:
                                        % its torsional mode clears 1 x PT speed by 10% (DYN-02 practice)
in.Kt_shaft = 1.6;                      % fatigue notch factor in torsion at the tube-to-flange transitions (integral
                                        % flanges machined from a forged hollow, no welds: 3.7 G6)
in.ka = 0.84;                           % surface factor, machined (Shigley, 10th ed.)
in.ke = 0.753;                          % reliability factor, 99.9%

% Torque meter (CTL-01): phase shift between the load shaft and an unloaded reference tube
in.tm.theta_min = 0.35;                 % deg, twist of the measuring length at T_100
in.tm.dt = 20e-9;                       % s, timing resolution of the phase measurement
in.tm.L_meas = 0.45;                    % m, measuring length (inside the diaphragms)
in.tm.dT_shaft = 40;                    % K, shaft temperature change between calibration and flight

% Diaphragm couplings: flat 15-5PH (AMS 5659, H1025) annular diaphragm, outer rim and hub clamped
in.dia = struct('E', 196e9, 'nu', 0.27, 'rho', 7800, 'su', 1070e6, 'sy', 1000e6, ...
                'Se', 0.45 * 1070e6 * 0.9 * 0.814);   % polished, size and 99% reliability factors
in.dia.a_list = (0.040:0.005:0.100);    % m, outer (rim) radius tried
in.dia.b_ratio = [0.45 0.50 0.55];      % inner (hub) radius / outer radius tried
in.dia.t_list = (0.0003:0.0001:0.0020); % m, diaphragm thickness tried
in.dia.n_list = [1 2 3 4];             % diaphragms per pack tried
in.dia.n_f_min = 1.5;                   % Goodman fatigue safety, infinite life
in.dia.n_buck_min = 2.0;                % shear buckling safety at limit torque
in.mis = struct('theta', 0.25, 'theta_max', 0.5, 'axial', 0.75e-3, 'axial_max', 1.5e-3);
%   deg and m: continuous and transient angular misalignment and axial offset per coupling; the
%   core's axial growth against the RGB (about 1.5 mm continuous, 3 mm transient: 13e-6/K x 400 K
%   x 0.3 m) is shared by the two couplings

% PT rear bearing (LUB-10, A-02): cylindrical roller bearing in the turbine rear frame
in.brg = struct('d', 0.050, 'D', 0.090, 'B', 0.020, 'C', 78e3, 'C0', 75e3, 'n_ref', 11000, ...
                'k_r', 0.15, 'Z', 14, 'Dw', 0.011);   % NU 210 class (SKF catalogue values)
in.m_PT = 25;                           % kg, PT rotor with its shafts (T700 class, estimate)
in.rear_share = 0.5;                    % share of the PT rotor weight on the rear bearing
in.G_PT = 2.5e-3;                       % m/s, balance grade G2.5 of the PT rotor (ISO 21940-11)
in.n_g_limit = 6.0;                     % limit load factor of the engine mounts for the static check
in.L10_req = 12000;                     % h, 3 x TBO (STR-02)

% Shaft tunnel through the exhaust collector (SYS-10, ENV-04, LUB-10)
in.tun.T_gas = [650 700];               % degC, PT exit gas: maximum continuous, hot-day transient
in.tun.h_gas = 115;                     % W/(m^2 K), cross flow over the tunnel (Re about 1e5)
in.tun.k_ins = 0.06;                    % W/(m K), ceramic-fibre blanket in a sealed foil at 400 degC
in.tun.t_ins = 0.015;                   % m, insulation thickness
in.tun.gap = 0.010;                     % m, radial gap between the shaft and the tunnel liner
in.tun.T_air_in = 60;                   % degC, buffer air from the engine inlet on a 53 degC day
in.tun.m_air_list = [0.003 0.005 0.0075 0.010 0.015];   % kg/s, buffer air flows tried
in.tun.T_shaft_max = 150;               % degC, shaft limit (torque meter calibration, AMS 6414 temper)
in.tun.T_sump_max = 200;                % degC, rear sump wall limit (oil coking)
in.tun.N_seg = 40;                      % segments along the tunnel
in.air = struct('cp', 1007, 'k', 0.029, 'mu', 2.0e-5, 'Pr', 0.71, 'R', 287, 'p', 101325);
in.sump = struct('D', 0.20, 'L', 0.15, 'P_brg', 900);   % m, m, W: rear sump size and bearing heat
% step 3.3 sensitivity runs may override inputs (calc/interfaces/if_override; no effect otherwise)
if exist('if_override', 'file') == 2, in = if_override(in, mfilename); end
end
