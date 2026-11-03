function in14 = lube_inputs()
%LUBE_INPUTS  Inputs and assumptions of step 1.4: accessory pads, RGB losses, lubrication, shaft break.
%   in14 = lube_inputs()
%
%   Requirement values are from requirements v1 (IDs in the comments); the
%   RGB itself comes from the step 1.3 tool (rgb_inputs and rgb_layout).
%   Every other value is an assumption from the Assumptions table of
%   Section 4 of the Phase 1 report. The other step 1.4 functions take their
%   numbers from here. Units: W, N, N m, mm, rpm, degC, L/min, s unless noted.

% RGB design z1 z2 zs zp N: 4 planets with hunting teeth, the design recommended for the PDR
% (the 5-planet design of step 1.3 is [31 112 39 31 5])
in14.design = [31 110 45 37 4];

% Oil: MIL-PRF-23699 STD class (LUB-01, A-08), Mobil Jet Oil II data sheet.
% Viscosity on a Walther line (ASTM D341) through the 40 and 100 degC values.
in14.oil.nu40 = 27.6;                      % cSt
in14.oil.nu100 = 5.1;                      % cSt
in14.oil.rho15 = 1003.5;                   % kg/m^3
in14.oil.alpha_rho = 7.0e-4;               % 1/K, thermal expansion of the density
in14.oil.cp = 2000;                        % J/(kg K), not on the data sheet

% Accessory pads driven by the power turbine (ACC-02; torques and CT7-9 speed ratios from the CT7-9 TCDS)
in14.T_gen_cont = 41.8;                    % N m, AC generator, continuous
in14.T_gen_max = 46.89;                    % N m, AC generator, overload
in14.T_osg = 1.13;                         % N m, overspeed governor
in14.T_pcu = 1.81;                         % N m, propeller control unit
in14.ratio_gen_ct7 = 0.54650;              % CT7-9 generator pad speed / power turbine speed
in14.ratio_osg_ct7 = 0.38091;              % CT7-9 overspeed governor pad
in14.z_ag = 57;                            % accessory drive gear, meshes with the first-stage gear
in14.b_ag_min = 10;                        % mm, first face width tried on the accessory drive gear
in14.z_osg = [28 40];                      % spur pair from the accessory drive gear shaft to the OSG
in14.m_osg = 1.5;                          % mm
in14.z_pcu1 = 20;                          % pinion on the intermediate shaft; its gear gives propeller speed
in14.m_pcu = 1.5;                          % mm
in14.b_pad_min = 6;                        % mm, first face width tried on the small spur pairs
in14.k_fatigue = 1.5;                      % pad drives carry 1.5 x maximum rated torque in fatigue (ACC-03)
in14.k_shear = 4;                          % shear torque of each pad's shear neck / maximum rated torque
in14.tau_u_ratio = 0.67;                   % ultimate shear strength / tensile strength (Shigley)
in14.d_neck_min = 5;                       % mm, smallest shear neck that can be made and inspected
in14.acc_shaft_L = 100;                    % mm, accessory shaft length
in14.quill_L = 80;                         % mm, quill shaft length
in14.m_pad_adapter = [0.40 0.15 0.15 0.15];   % kg: generator, OSG, PCU, oil pump (flange, seal, studs)
in14.m_acc_housing = 1.5;                  % kg, accessory section added to the RGB housing

% Losses
in14.Ra = 0.3;                             % um, mean flank roughness of ground gears
in14.XL = 1.0;                             % lubricant factor of the Schlenk friction formula
in14.mu_mist = 0.023;                      % cP, air-oil mist around the gears (windage)
in14.f0_roller = 3;                        % Palmgren speed factor, jet-lubricated roller bearing
in14.f1_roller = 0.0003;                   % Palmgren load factor, roller bearing
in14.f0_ball = 2;                          % ball bearings (QJ and accessory shafts)
in14.f1_ball = 0.0005;
in14.eta_supply = 0.25;                    % oil pump efficiencies used by NASA TM-83716
in14.eta_scav = 0.20;
in14.dp_supply = 0.55e6;                   % Pa, supply pump pressure rise (LUB-03: 172-965 kPa)
in14.dp_scav = 0.20e6;                     % Pa
in14.k_scav = 2.5;                         % scavenge capacity / supply capacity (aerated oil)

% Operating points: name, propeller torque share, speed share, generator torque [N m],
% oil inlet [degC], thrust [N] (A-05 mission and the 1.3 thrust spectrum)
in14.ops = struct('name', {'MC', 'MC hot', 'loiter', 'descent'}, ...
                  'f_T', {1.0, 1.0, 0.5, 0.3}, 'f_n', {1, 1, 1, 1}, ...
                  'T_gen', {41.8, 41.8, 41.8, 41.8}, 'T_in', {100, 132, 100, 100}, ...
                  'thrust', {18e3, 18e3, 3e3, 2e3});

% Lubrication system
in14.T_in = 100;                           % degC, design oil inlet temperature
in14.dT_oil = 30;                          % K, oil temperature rise through the RGB at the design point
in14.Q_pcu = 5;                            % L/min, PCU supply until the propeller supplier's value (PIF-02)
in14.leak = 0.10;                          % share of the flow lost in leaks and seals
in14.pump_margin = 1.3;                    % pump capacity / need (wear, cold oil, altitude)
in14.eta_vol = 0.85;                       % pump volumetric efficiency
in14.t_dwell = 5;                          % s, tank dwell time with a centrifugal de-aerator
in14.V_gulp = 1.0;                         % L, oil held in the gearbox while running
in14.V_circuit = 1.2;                      % L, lines, filter and cooler
in14.consumption = 0.02;                   % L/h
in14.mission_h = 30;                       % h, longest mission (N-03, LUB-06)
in14.V_feather = 0.5;                      % L, reserve for feathering after shutdown (PIF-03)
in14.V_unusable = 0.3;                     % L
in14.expansion = 0.10;                     % expansion space share of the tank (LUB-06)
in14.Q_cooler = 18e3;                      % W, cooler duty (LUB-04)
in14.T_amb = 53;                           % degC, hottest ground day (ENV-01)
in14.dT_air = 25;                          % K, cooling air temperature rise
in14.F_cross = 0.9;                        % LMTD correction of a cross-flow cooler
in14.q_cooler = 4e3;                       % W/kg, heat rejected per kg of an aircraft plate-fin cooler
in14.cp_air = 1007;                        % J/(kg K)
in14.dp_jet = 0.40e6;                      % Pa, pressure drop across an oil jet
in14.Cd_jet = 0.7;                         % jet discharge coefficient

% Shaft break (SAF-03)
in14.J_PT = 0.084;                         % kg m^2, power turbine with output shaft (NASA TM-100991)
in14.J_PT_low = 0.060;                     % kg m^2, lower bound: rotor without its shaft
in14.k_stall = 2.0;                        % turbine torque at zero speed / torque at the break speed
in14.drag = 0.02;                          % rotor drag (windage, bearings) at the break speed / Q0
in14.mismatch = 0.03;                      % detection: Np above the propeller-equivalent speed by 3%
in14.t_proc = 0.005;                       % s, signal processing
in14.t_valve = 0.020;                      % s, fuel shutoff valve closing
in14.tau_cut = 0.10;                       % s, decay time of the turbine torque after the valve closes
in14.residual = 0;                         % turbine torque left after the decay, share of Q0
in14.t_end = 1.5;                          % s, simulated time
in14.dt = 1e-4;                            % s, RK4 step
end
