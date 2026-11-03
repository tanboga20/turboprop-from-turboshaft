function in = sb_inputs()
%SB_INPUTS  Inputs and assumptions of step 2.5: shafts, splines, bearings and propeller retention.
%   in = sb_inputs()
%
%   Gear forces come from the step 2.4 design (calc/gear_detail on the
%   path); requirement IDs are in the comments; every other value is an
%   assumption listed in Section 2.5 of the Phase 2 report.
%   Units: mm, N, N m, MPa, rpm, degC unless noted.

% Requirements
in.L10_req = 12000;                         % h, L10m over the mission (STR-02)
in.s0_lim = 2.0;                            % static safety at limit loads (STR-02)
in.s0_fail = 1.0;                           % static safety in the LD-08 failure case (no gross brinelling)
in.mission = [1/30 1.0; 28/30 0.5; 1/30 0.3];   % [time share, torque share] (A-05)
in.thrust = [18e3 3e3 2e3];                 % N, propeller thrust in the three mission steps (step 1.3)
in.thrust_lim = 20e3;                       % N, both directions (LD-03, LD-04)
in.K_over = 1.375;                          % LD-01
in.T_LD08_prop = 26129 * 0.2 / 0.22;        % N m, propeller shaft peak for the 0.22 s stop (steps 2.3, 2.4)
in.ult = 1.5;                               % ultimate factor on limit loads (STR-03)
in.n_over = 1.10;                           % SYS-04

% Propeller and its loads (A-04, LD-05, LD-06, LD-07)
in.m_prop = 76.4;                           % kg
in.g = 9.81;
in.M_1P = 2000;                             % N m, steady 1P moment until LD-07 values arrive
in.M_gyro = 7190;                           % N m (LD-05)
in.nz_gyro = 2.5;                           % load factor with the gyroscopic moment (LD-05)
in.nz_man = 3.17;                           % manoeuvre (LD-06)

% Layout (step 1.3 and 2.1): gears centred between their roller bearings
in.span1 = 102;                             % mm, roller bearing span of the input and intermediate shafts
in.prop_span = 300;                         % mm, inner to outer propeller shaft bearing
in.prop_overhang = 250;                     % mm, outer bearing to propeller centre of gravity

% Bearings: internal geometry of aerospace bearings in ISO dimension series envelopes
% type 'CRB' cylindrical roller, 'QJ' four-point contact ball (radially free in its housing)
% Z rolling elements, Dw roller/ball diameter, Lwe effective roller length, Dpw pitch diameter,
% i rows: a four-point contact bearing is rated as a double-row angular contact bearing (i = 2),
% which goes with the double-row X, Y and Y0 factors used in sb_life and run_step25
mk = @(name, shaft, type, d, D, B, Z, Dw, Lwe, Dpw, alpha) struct('name', name, 'shaft', shaft, ...
    'type', type, 'd', d, 'D', D, 'B', B, 'Z', Z, 'Dw', Dw, 'Lwe', Lwe, 'Dpw', Dpw, 'alpha', alpha, ...
    'i', 1 + strcmp(type, 'QJ'));
in.brg(1) = mk('input roller', 'input', 'CRB', 45, 85, 23, 14, 11, 16, 65, 0);      % NU 2209 envelope
in.brg(2) = mk('input QJ', 'input', 'QJ', 45, 85, 19, 13, 12.7, 0, 65, 35);         % QJ 209 envelope
in.brg(3) = mk('intermediate roller', 'mid', 'CRB', 50, 90, 23, 15, 11, 16, 70, 0); % NU 2210 envelope
in.brg(4) = mk('intermediate QJ', 'mid', 'QJ', 50, 90, 20, 14, 12.7, 0, 70, 35);    % QJ 210 envelope
in.brg(5) = mk('propeller inner roller', 'prop', 'CRB', 120, 180, 28, 26, 15, 16, 150, 0);   % NU 1024 envelope
in.brg(6) = mk('propeller outer roller', 'prop', 'CRB', 120, 180, 28, 26, 15, 16, 150, 0);
in.brg(7) = mk('propeller QJ', 'prop', 'QJ', 120, 180, 28, 21, 19.05, 0, 150, 35);  % QJ 1024 envelope
in.b_m = struct('CRB', 1.1, 'QJ', 1.3);     % ISO 281 rating factors (ISO 281 not in the library: TBR)

% Planet bearing: the planet bore (gd_meshes: root circle minus the 8 mm rim) is the outer race and
% the pin is the inner race; one row, full complement (no cage)
in.planet = struct('Dw', 7.5, 'pitch_gap', 0.03, 'L_ends', 14, 'Kgam_pct', 90);
% pitch_gap: free circumferential gap per roller as a share of Dw; L_ends: face width minus the
% effective roller length (lips, chamfers, end clearance) [mm]; Kgam_pct: percentile of the
% Monte Carlo K_gamma for the life (the static checks use the 99th percentile, as the gears)

% Lubricant at the bearings (LUB-01, LUB-02) and cleanliness (LUB-05, 3 um filter)
in.oil = struct('nu40', 27.6, 'nu100', 5.1);
in.T_brg = [110 142];                       % degC: oil in at 100 and 132 degC plus 10 K at the bearing
in.e_C = 0.6;                               % ISO 281 contamination factor, high cleanliness (TBR)

% Shafts: material and notch factors (Phase 1 method: Goodman with Marin factors)
in.sh_mat = struct('su', 1240, 'sy', 1100, 'E', 205e3);   % AISI 4340 (AMS 6414); gear shafts' cores similar
in.Kf = 2.0;                                % bending notch factor at bearing seats and shoulders
in.Kfs = 1.6;                               % torsion notch factor
in.ka_exp = [1.38 -0.067];                  % ground surface
in.ke = 0.753;                              % reliability 99.9%
in.nf_min = 1.5;
in.shafts = struct('name', {'input shaft', 'intermediate shaft', 'sun quill', 'propeller shaft'}, ...
                   'd_o', {40, 50, 50, 120}, 'd_i', {24, 30, 30, 100});

% Splines of the sun quill (ISO 4156 30 deg involute, flat root)
in.spl = struct('name', {'quill to intermediate shaft (fixed)', 'quill to sun (crowned)'}, ...
                'm', {1.5, 1.5}, 'z', {30, 30}, 'L', {40, 56}, 'Km', {1.3, 1.5}, 'crowned', {false, true});
in.spl_tau_fat = 0.25;                      % share of su for the tooth shear stress at MCT x K_A
in.spl_pc_lim = [100 60];                   % MPa, mean flank pressure limits, fixed / crowned (TBR); the sun-quill splines are
                                            % not oil-fed: a feed through F204 is on the 3.9 list

% Propeller retention, second load path options (SAF-01)
in.ret.tube = struct('d_o', 90, 'd_i', 80, 'L', 600, 'rho', 4.43e-6, 'sy', 830, 'su', 900);  % Ti-6Al-4V
in.ret.catcher = struct('d_lip', 140, 'h_lip', 4, 'b', 8, 'sy', 830);   % axial catcher lip in the nose cover
% step 3.3 sensitivity runs may override inputs (calc/interfaces/if_override; no effect otherwise)
if exist('if_override', 'file') == 2, in = if_override(in, mfilename); end
end
