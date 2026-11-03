function in = gd_inputs()
%GD_INPUTS  Inputs and assumptions of the step 2.4 gear detail rating, in one struct.
%   in = gd_inputs()
%
%   The design is the PDR baseline: first stage 31/110, m_n 2, beta 15 deg,
%   b 52 mm; planetary stage 45/37/119, m 2, four planets, floating sun, fixed
%   nitrided ring, carrier output. Step 2.5 widened the planetary stage from
%   60 to 70 mm and thickened the planet rim to 4 modules and the carrier
%   posts to 60 mm (planet bearing life, Phase 2 report Section 2.5).
%   Requirement IDs are in the comments; every other value is an assumption
%   listed in Section 2.4 of the Phase 2 report. Units: mm, N, N m, MPa, um,
%   rpm, degC unless noted.

% Power, speeds and loads
in.P = 895e3;                               % W (SYS-01)
in.n_PT = 22000;                            % rpm (SYS-02)
in.T_PT = in.P / (in.n_PT * pi / 30);       % 388.5 N m
in.speed_range = [0.90 1.01];               % steady speed range (SYS-03)
in.KA = 1.25;                               % application factor (STR-01)
in.K_over = 1.375;                          % LD-01 transient torque, 20 s and the LD-02 test, 15 min
in.t_LD02 = 15 * 60;                        % s, LD-02 over-torque test duration
in.mission = [1/30 1.0; 28/30 0.5; 1/30 0.3];   % [time share, torque share] (A-05)
in.life_h = 20000;                          % h, design service life of the gears (STR-05)
in.SH_min = 1.2;                            % STR-01
in.SF_min = 1.5;                            % STR-01
in.T_stop_prop = 26129;                     % N m, propeller shaft peak in a 0.2 s PT seizure (step 2.3, LD-08)
in.t_stop_list = [0.10 0.15 0.20 0.30 0.50 0.76 1.0];   % s, stopping times for the LD-08 map

% Tooth counts, modules, face widths (PDR baseline)
in.s1 = struct('z1', 31, 'z2', 110, 'mn', 2, 'beta', 15, 'b', 52, 'x1', 0.20, 'x2', -0.20);
in.s2 = struct('zs', 45, 'zp', 37, 'zr', 119, 'm', 2, 'b', 70, 'N', 4, ...
               'xs', 0, 'xp', 0, 'xr', 0, 'ha_r', 0.9);
% ring x_r in the ISO sign convention; x_s = x_r = -x_p keeps both centre distances at 82 mm;
% ha_r is the ring tip addendum factor (tip shortening below 1)
in.alpha_n = 20;                            % deg

% Tools. Hob for the external gears (ISO 53 profile A with protuberance, so
% the ground flank has no residual undercut); shaper cutter for the ring.
in.hob = struct('hfP', 1.25, 'rhofP', 0.38, 'spr', 0);           % in modules
in.shaper = struct('z0', 38, 'x0', 0, 'haP0', 1.25, 'rhoa0', 0.25, 'spr', 0);
in.tip_chamfer = 0.10;                      % mm radial chamfer at the tips: d_Na = d_a - 2 x 0.10

% Accuracy (ISO 1328-1:2013 tolerance class A)
in.A_s1 = 4;                                % first stage: ground, 74 m/s pitch line velocity
in.A_s2 = 5;                                % planetary set (the ring is shaped and honed)

% Materials (ISO 6336-5:2016 Table 1, quality ME). Eh: case-carburized Pyrowear 53 (AMS 6308) for the
% pinion, gear 2, sun and planets (tempered above the 145-175 degC bulk temperatures of section 7);
% NT: gas-nitrided 32CrMoV13 (EN 1.8523) for the ring.
in.mat.Eh = struct('type', 'Eh', 'sHlim', 1650, 'sFlim', 525, 'HV', 700, 'E', 206e3, 'nu', 0.3);
in.mat.NT = struct('type', 'NT', 'sHlim', 1450, 'sFlim', 468, 'HV', 750, 'E', 206e3, 'nu', 0.3);
in.rho_steel = 7.83e-6;                     % kg/mm^3

% Surface roughness, mean peak-to-valley Rz [um]. Baseline: isotropic superfinish of all flanks
% after grinding (external gears) or honing (ring); ground flanks Rz 2.0 (Ra 0.33) for comparison.
in.Rz_flank = 0.8;                          % superfinished flanks (Ra about 0.13 um)
in.Rz_flank_ring = 1.0;                     % superfinished ring flanks
in.Rz_ground = 2.0;                         % ground flanks, for the comparison runs
in.Rz_root = 10;                            % protuberance-hobbed or shaped roots, not ground

% Life factor Z_NT and Y_NT at 1e10 cycles (STR-01): the lower value of ISO 6336-2 Table 5 and
% ISO 6336-3, for critical service
in.ZNT_ref = 0.85;

% Shafts and blanks for K_Hbeta (f_sh) and K_v
% first-stage pinion centred between its bearings (span b1 + 50 mm): s = 0 in ISO 6336-1 Formula (59)
in.d_bore_pinion = 24;                      % mm, input shaft bore under the pinion (step 2.2)
in.gear2_rim = 3.5;                         % rim thickness under the root of the first-stage gear, modules
in.gear2_web = 8;                           % mm, web thickness of the first-stage gear
in.gear2_hub_d = 70;                        % mm, hub outer diameter (intermediate shaft 50 mm + hub, step 2.5)
in.sun_bore = 48;                           % mm, sun bore with the internal spline of the quill shaft (torque in at one end)
in.planet_rim = 4.0;                        % planet rim under the root, modules (bore = outer race; 8 mm from step 2.5)
in.ring_rim = 4;                            % ring rim under the root, modules (Y_B = 1 needs 3.5)

% Carrier (two plates joined by N posts; pins straddle-mounted)
in.carrier = struct('L_pin', 82, 'post_w', 32, 'post_t', 60, 'L_post', 82, 'E', 206e3, 'f_pin_par', 5);
% post_w: tangential width, post_t: radial thickness of a post [mm]; posts sit at the carrier radius;
% 32 mm leaves 3 mm to the planet tips, 60 mm leaves 5 mm to the sun and ring tips (step 2.5 raised
% post_t from 50 mm to keep the LD-08 capacity with the longer posts of the 70 mm face);
% f_pin_par: parallelism of a planet pin to the sun axis over the pin length L_pin [um]

% Flank modifications (designed in run_step24): helix correction at full torque plus crowning
in.helix_mod = 'correction+crowning';       % ISO 6336-1 Table 12, case 5: B1 = 0.1, B2 = 0.5
in.corr_frac = 1.0;                         % helix correction designed at this share of MCT (run_step24 chooses it)
in.fpb_share = 0.5;                         % 50% of f_pb in K_Halpha: profile modifications match the load

% Planet load sharing (Monte Carlo)
in.ls = struct('e_pin', 0.005, 'e_planet', 0.003, 'e_ring_Fp', 0.25, ...
               'k_brg', 2.5e9, 'k_pin', 6.0e9, 'n_mc', 20000, 'seed', 24);
% e_pin: tangential pin position error, +-mm (uniform; true position 0.010 mm); e_planet: tooth
% thickness spread of the matched planet set, +-mm; e_ring_Fp: largest ring ovality amplitude as a
% share of the ring F_p; k_brg, k_pin: planet bearing and pin radial stiffness [N/m]

% Lubricant (LUB-01, LUB-02). MIL-PRF-7808 values are the Grade 3 specification minimums.
in.oil(1) = struct('name', 'MIL-PRF-23699', 'nu40', 27.6, 'nu100', 5.1, 'rho15', 1003.5, ...
                   'alpha100', 1.00e-8, 'alpha150', 0.85e-8, 'S_FZG', 8, 'XL', 1.0);
in.oil(2) = struct('name', 'MIL-PRF-7808', 'nu40', 11.5, 'nu100', 3.0, 'rho15', 950, ...
                   'alpha100', 0.90e-8, 'alpha150', 0.78e-8, 'S_FZG', 7, 'XL', 1.0);
in.T_oil = [100 132 149];                   % degC: design, maximum continuous, 15 min (LUB-02)
in.XS = 1.2;                                % jet lubrication factor for the bulk temperature
in.XW = 1.0;                                % structural factor of the scuffing temperature
in.lambda_steel = 40;                       % W/(m K)
in.c_steel = 470;                           % J/(kg K)
in.SS_min = 1.5;                            % scuffing safety on (theta_S - theta_oil)
end
