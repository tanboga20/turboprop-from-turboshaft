function in = damper_inputs()
%DAMPER_INPUTS  Inputs and assumptions of step 2.1: propeller shaft rotor and its damper.
%   in = damper_inputs()
%
%   Requirement values are from requirements v2 (IDs in the comments). The
%   rotor is the step 1.4 ROSS model of the propeller shaft
%   (rotordynamics/prop_shaft_campbell.py); every other value is an
%   assumption from the Assumptions table of Section 2.1 of the Phase 2
%   report. The other step 2.1 functions take their numbers from here.
%   Units: SI (m, kg, N, s, Pa) unless noted; speeds in rpm.

% Requirements v2
in.n_prop = 1700;                       % rpm, 100% propeller speed (SYS-02)
in.n_steady = [1534 1715];              % rpm, steady range 90-101% (SYS-03)
in.n_over = 1870;                       % rpm, 110% transient (SYS-04)
in.margin = 0.20;                       % forward-whirl criticals 20% away from SYS-03 (DYN-01)
in.ratio_max = 2.5;                     % unbalance response peak / response at 1,700 rpm (DYN-05)
in.n_scan = [100 1870];                 % rpm, speeds scanned for the DYN-05 peak: start-up to 110%

% Rotor: hollow AISI 4340 propeller shaft of the selected RGB (31/110 | 45/37/119, N = 4)
in.shaft = struct('d_o', 0.075, 'd_i', 0.045, 'E', 205e9, 'nu', 0.29, 'rho', 7850);
in.stub = 0.06;                         % m, carrier stub inboard of the inner bearing
in.span = 0.30;                         % m, inner to outer bearing (rgb_inputs prop_span)
in.overhang = 0.25;                     % m, outer bearing to propeller (rgb_inputs prop_overhang)
in.el = 0.05;                           % m, target element length
in.carrier = struct('m', 8.6, 'Id', 0.035, 'Ip', 0.061);   % step 1.3 rgb_mass, disc of its diameter
in.prop = struct('m', 76.4, 'Ip', 15, 'Id', 7.5);          % A-04; Id = Ip / 2, thin planar rotor
in.G_bal = 6.3e-3;                      % m/s, balance grade G6.3 of the propeller (ISO 21940-11)
in.g = 9.81;                            % m/s^2

% Supports. Phase 1 (validation) used bearings straight to ground: k from 5e7 to 1e9 N/m, c 1e3 N s/m.
in.k_list = [5e7 1e8 2e8 5e8 1e9];      % N/m, Phase 1 stiffness range
in.k_nom = 1e8;                         % N/m, Phase 1 nominal
in.c_ph1 = 1e3;                         % N s/m, Phase 1 bearing damping
% Phase 2 support chain at each bearing: shaft - rolling bearing - damper journal -
% (centring spring || squeeze film) - housing - ground. Housing values are a range until the
% housing finite element model of step 2.8 gives them.
in.k_brg = 1.0e9;                       % N/m, radial stiffness of a 75 mm bore cylindrical roller bearing
in.m_j = 1.5;                           % kg, outer ring, damper journal sleeve and cage ring
in.m_h = 3.0;                           % kg, housing mass moving with the bearing seat
in.c_h_ratio = 0.02;                    % housing structural damping, as a share of critical (k_h, m_h)
in.kh_list = [5e7 1e8 2e8 5e8];         % N/m, housing stiffness at a bearing seat, stiffer direction
in.aniso_list = [0.5 0.8 1.0];          % kyy / kxx of the housing (0.5 is the Phase 1 case)

% Loads that the centring spring carries in steady running (fatigue case of step 1.3)
in.M_1P = 2000;                         % N m, steady 1P moment until LD-07 values arrive (rgb_inputs)
in.n_g_steady = 1.0;                    % load factor in steady running
in.eps_static_max = 0.4;                % damper journal offset / clearance under steady loads

% Squeeze-film damper: short-bearing theory, circular centred orbits, uncavitated (2 pi) film
in.oil = struct('nu40', 27.6, 'nu100', 5.1, 'rho15', 1003.5, 'alpha_rho', 7.0e-4, 'cp', 2000);  % lube_inputs
in.T_oil = [100 132 149];               % degC: design inlet, continuous maximum and 15 min maximum (LUB-02)
in.dT_film = 5;                         % K, film temperature above the oil inlet
in.R_sfd_min = 0.068;                   % m, smallest damper journal radius: bearing outer diameter 130 mm + sleeve
in.L_sfd_max = 0.040;                   % m, longest damper land that fits beside the bearing
in.c_sfd_min = 0.10e-3;                 % m, smallest radial clearance that can be held in production
in.seal_factor = 2.0;                   % damping of a land with piston-ring end seals / open ends
in.cav_factor = 0.5;                    % damping left if the film cavitates (pi film), sensitivity case

% Squirrel-cage centring spring: AISI 4340 (AMS 6414) bars, fixed-guided
in.cage = struct('E', 205e9, 'S_e', 420e6, 'S_y', 1100e6, 'n_min', 8, 'n_max', 36, ...
                 'l_max', 0.120, 't_min', 0.003);

% Concepts screened in run_step21 (Phase 2 report, Section 2.1, "Concepts")
in.k_rigid = 1e11;                      % N/m, a centring spring this stiff stands for "no damper"
in.sfd_ksc = [1e7 2e7 3e7 5e7 1e8 2e8]; % N/m, centring springs tried with the squeeze film
in.sfd_c = [1e4 3e4 5e4 1e5 2e5];       % N s/m, squeeze-film damping tried
in.car_ksc = [5e6 1e7 2e7 5e7];         % N/m, centring spring of a damper bearing at the carrier
in.aniso_fine = [0.9 0.95];             % kyy / kxx added for the housing-only concept
% Thin-walled propeller shafts [d_o d_i] in m, with the same diameters from the carrier to the flange
in.shafts = [0.075 0.045; 0.090 0.070; 0.100 0.080; 0.110 0.090; 0.120 0.100];
in.shaft_A = [0.120 0.100];             % chosen by Hamit: housing floor 5e7 N/m
in.shaft_B = [0.110 0.090];             % the lighter alternative: housing floor 7e7 N/m
in.k_map = [3e7 5e7 7e7 1e8 1.5e8 2e8 3e8 5e8];   % N/m, housing stiffness grid of the DYN-05 map
in.k_h_nom = 2e8;                       % N/m, housing stiffness the step 2.8 model is asked to reach
in.flange = struct('m', 4.0, 'Id', 0.011, 'Ip', 0.022);  % propeller flange, nut and bolts: 180 mm flange
end
