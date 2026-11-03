function in = torsion_inputs()
%TORSION_INPUTS  Inputs and assumptions of step 2.3: torsional vibration and sudden stoppage.
%   in = torsion_inputs()
%
%   The drive chain from the power turbine (PT) to the propeller: PT rotor,
%   floating shaft with its diaphragm couplings (step 2.2), RGB input shaft,
%   first-stage mesh, first-stage gear with the generator branch,
%   intermediate shaft, planetary stage (sun, four planets, carrier, fixed
%   ring), propeller shaft (step 2.1) and propeller. Gear data come from the
%   step 1.3 tool for the design in in.design. Requirement values are from
%   requirements v2 (IDs in the comments); every other value is an
%   assumption from the Assumptions table of Section 2.3 of the Phase 2
%   report. Units: SI (m, kg, N, s, rad) unless noted; speeds in rpm.

in.design = [31 110 45 37 4];           % z1 z2 zs zp N, the PDR design (lube_inputs in14.design)
in.n_PT = 22000;                        % rpm, 100% (SYS-02)
in.n_steady = [0.90 1.01];              % share of 100% speed, steady range (SYS-03)
in.margin = 0.10;                       % modes 10% away from the excitation orders (DYN-02)
in.P_orders = [1 4 5 10];               % propeller orders of DYN-02: 1P, blade passing for 4 and 5 blades, 2 x 5P
in.P_watch = 2;                         % 2P: not in DYN-02 (no torque at 2P from identical blades), reported
in.PT_orders = [1 2];                   % orders of the PT speed
in.G = 79.5e9;                          % Pa, shear modulus of steel
in.c_gamma = 20e9;                      % N/m per m of face width: mesh stiffness, ISO 6336-1 typical
                                        % value 20 N/(mm um) for steel gears
in.zeta = 0.02;                         % modal damping for the time simulations

% Inertias [kg m^2]
in.J_PT = 0.084;                        % PT rotor with its shafts (NASA TM-100991; step 1.4)
in.J_coupling = 0.0006;                 % one diaphragm coupling with its flanges (step 2.2 size)
in.J_prop = 15;                         % propeller, rigid (A-04); blade flexibility is TBD (LD-07)
in.J_gen = 0.012;                       % AC generator rotor, 52 kW at 12,000 rpm (estimate)

% Shafts: outer and inner diameter [m], torsional length [m]
in.sh.stub = [0.050 0.030 0.08];        % PT rear stub to coupling 1
in.sh.float = [0.066 0.063 0.55];       % floating shaft (step 2.2, after the step 2.3 stiffness floor)
in.sh.input = [0.040 0.024 0.10];       % coupling 2 to the input pinion (step 1.3 input shaft)
in.sh.mid = [0.045 0.027 0.15];         % first-stage gear to the sun spline (step 1.3 intermediate shaft)
in.sh.prop = [0.120 0.100 0.61];        % carrier to propeller flange (step 2.1 shaft A)
in.k_diaphragm = 9.3e5;                 % N m/rad, torsional stiffness of one diaphragm pack (step 2.2:
                                        % 4 pi G t / (1/b^2 - 1/a^2) with 3 x 0.3 mm, a 50, b 27.5 mm)
% Generator branch: accessory gear (57 teeth) on the first-stage gear, quill shaft with a shear neck
in.gen = struct('z', 57, 'b', 0.010, 'neck_d', 0.01048, 'neck_L', 0.015, 'body_d', 0.016, 'body_L', 0.065);

% Sudden stoppage (LD-08): the PT stops linearly in t_stop; no propeller aerodynamic torque (conservative)
in.t_stop = [0.02 0.05 0.1 0.2 0.5 1.0 2.0];   % s, stopping times tried
in.T_LD01 = 6915;                       % N m at the propeller (LD-01)
in.T_prop = 895e3 / (1700 * pi / 30);   % N m, 5,027 at the propeller (SYS-01)
end
