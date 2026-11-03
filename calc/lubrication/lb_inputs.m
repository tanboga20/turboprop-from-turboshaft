function in = lb_inputs()
%LB_INPUTS  Inputs and assumptions of step 2.7: the RGB lubrication system.
%   in = lb_inputs()
%
%   The gear, bearing and accessory designs come from steps 2.4 to 2.6
%   (calc/gear_detail, calc/shafts_bearings, calc/accessory on the path) and
%   the loss model from Phase 1 step 1.4 (calc/agb_lube). Requirement IDs
%   are in the comments; every other value is an assumption listed in
%   Section 2.7 of the Phase 2 report. Units: W, N, mm, rpm, degC, L/min,
%   kPa unless noted.

% Oil (LUB-01): MIL-PRF-23699, data sheet values, Walther line between 40 and 100 degC
in.oil = struct('nu40', 27.6, 'nu100', 5.1, 'rho15', 1003.5, 'alpha_rho', 7.0e-4, 'cp', 2000);
in.oil7808 = struct('nu40', 11.5, 'nu100', 3.0, 'rho15', 950, 'alpha_rho', 7.0e-4, 'cp', 2000);
in.nu_cold = [11000 13000];                 % cSt at -40 degC (23699) and -54 degC (7808), data sheets (LUB-02)

% Operating points (A-05 mission, LUB-02, LUB-04): torque share, oil in [degC], generator torque [N m], thrust [N]
in.ops = struct('name', {'MC', 'MC hot', 'loiter', 'descent'}, 'f_T', {1.0, 1.0, 0.5, 0.3}, ...
                'T_in', {100, 132, 100, 100}, 'T_gen', {41.8, 41.8, 41.8, 41.8}, 'thrust', {18e3, 18e3, 3e3, 2e3});
in.dT_oil = 30;                             % K, design oil temperature rise through the RGB
in.Q_rear_sump = 1204;                      % W, PT rear sump: bearing 900 W + heat from the exhaust (step 2.2, LUB-10)
in.P_rear_brg = 900;                        % W, of which the PT rear bearing loss

% Loss model factors (step 1.4)
in.Ra = 0.3;                                % um, ground flanks (OSG and PCU pairs)
in.Ra_sf = 0.13;                            % um, superfinished flanks (Rz 0.8, decision 1): main gears and the generator gear
in.XL = 1.0;
in.mu_mist = 0.023;                         % cP, air-oil mist
in.f0 = struct('roller', 3, 'ball', 2);     % Palmgren speed factors, jet lubrication
in.f1 = struct('roller', 0.0003, 'ball', 0.0005);

% Oil feed: jets at the supply pressure (LUB-03), flow split and minimum jet size (LUB-05 3 um filter)
in.dp_jet = 400;                            % kPa across the jets
in.Cd_jet = 0.70;
in.d_jet_min = 0.6;                         % mm, with the 3 um filter and a last-chance strainer at each jet (TBR)
in.d_jet_max = 2.0;                         % mm, larger flows get more jets
in.Q_min_brg = 0.20;                        % L/min, smallest flow to any rolling bearing
in.Q_spline = 0.15;                         % L/min to each quill spline through the shaft bore (pad splines run on splash)
in.Q_pcu = 5.0;                             % L/min, PCU supply until the propeller supplier's value (PIF-02)
in.leak = 0.10;                             % share lost in leaks and seals
in.into_mesh = 0.3;                         % share of a mesh's flow on the into-mesh side, the rest out of mesh

% Pumps (pump pack on the intermediate shaft, step 2.6)
in.pump_margin = 1.3;
in.eta_vol = 0.85;
in.dp_supply = 550;                         % kPa
in.dp_scav = 200;                           % kPa
in.eta_supply = 0.25;                       % NASA TM-83716 values
in.eta_scav = 0.20;
in.k_scav = 2.5;                            % scavenge capacity / supply into that sump (aerated oil)

% Cooler (LUB-04, LUB-09): plate-fin aluminium core, offset strip fins on both sides
in.Q_cooler = 18e3;                         % W, LUB-04 duty
in.T_amb = 53;                              % degC, LUB-04 hot day
in.T_oil_out = 100;                         % degC, oil leaving the cooler = RGB oil inlet (planet bearing life, step 2.5)
in.m_air = 0.72;                            % kg/s (LUB-09)
in.p_air = 101.325;                         % kPa
in.fin_air = struct('s', 1.6, 'h', 6.35, 't', 0.10, 'l', 3.2);   % mm: spacing, height, thickness, strip length
in.fin_oil = struct('s', 1.0, 'h', 2.0, 't', 0.10, 'l', 2.0);
in.t_plate = 0.4;                           % mm, parting sheets
in.k_al = 170;                              % W/(m K), fin alloy
in.k_oil = 0.135;                           % W/(m K), MIL-PRF-23699 near 110 degC
in.rho_core = 1100;                         % kg/m^3, dry core density of a plate-fin cooler
in.k_tanks = 1.35;                          % cooler mass / core mass (headers, tanks, bypass valve)
in.v_face = [4 5 6 7 8 10];                 % m/s, air face velocities scanned
in.v_face_design = 6;
in.dp_ducts = 300;                          % Pa, inlet and exit ducts, screens at the design flow (TBR)
in.eta_fan = 0.55;                          % fan and motor (option C of decision 5)
% Option A of decision 5 (cooler in the engine inlet): core air flow and power sensitivities (TBR)
in.core_mdot = 4.5;                         % kg/s, T700-class core
in.dPdT = 0.8;                              % % power per K of inlet temperature rise at constant turbine temperature
in.dPdp = 1.5;                              % % power per % of inlet total pressure loss

% Tank (LUB-06) and system volumes (step 1.4)
in.t_dwell = 5;                             % s
in.V_gulp = 1.0;  in.V_circuit = 1.2;  in.consumption = 0.02;  in.mission_h = 30;
in.V_feather = 0.5;  in.V_unusable = 0.3;  in.expansion = 0.10;

% Windmilling (SAF-04): propeller windmills at this share of its speed if feathering fails (TBR)
in.f_windmill = 0.4;
% step 3.3 sensitivity runs may override inputs (calc/interfaces/if_override; no effect otherwise)
if exist('if_override', 'file') == 2, in = if_override(in, mfilename); end
end
