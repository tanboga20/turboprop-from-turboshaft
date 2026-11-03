function in = tl_inputs()
%TL_INPUTS  Inputs and assumptions of step 3.8: tolerances, fits, stack-ups and the thermal map.
%   in = tl_inputs()
%
%   Drawing standard (decision delegated by Hamit): ASME Y14.5-2018, metric, ISO 286 size
%   tolerances and fits, ISO 1328-1:2013 gear accuracy, ISO 4156 splines (as in step 2.5). Gear, bearing and
%   case data from steps 2.4, 2.5, 3.1-3.6; every other value is an assumption, marked TBR.
%   Units: mm, um, degC, s, N, MPa unless noted.
%   Source: Phase 3 report, Section 3.8.

% Materials: CTE 20-150 degC [1/K], E [MPa], Poisson (step 3.4 mf_inputs)
in.cte = struct('steel', 12.3e-6, 'P53', 11.9e-6, 'M50', 11.7e-6, 'A357', 21.5e-6, 'Ti', 8.8e-6);
in.E = struct('steel', 205e3, 'A357', 72e3, 'Ti', 114e3);
in.nu = struct('steel', 0.29, 'A357', 0.33, 'Ti', 0.34);
in.T_ref = 20;                              % degC, drawing (assembly) temperature

% E2 Thermal map (lumped, TBR): steady part temperatures per state [degC]. MCT and LD-02 gear values are the
% step 2.4 bulk temperatures (theta_M) with 132 and 149 degC oil; bearings oil + 10 K inner ring (step 2.5);
% the cases run cooler than the oil (outside cooled by the nacelle air), TBR until the 3.11 survey
in.th.parts = {'oil_in', 'pinion', 'gear2', 'sun', 'planet', 'ring', 'carrier', 'brg_in', 'brg_out', 'liner', ...
               'case_p', 'case_f', 'P111', 'tube'};
in.th.parts_en = {'oil in', 'input pinion F203', 'gear 2 F202', 'sun P105', 'planets P107', 'ring gear P102', ...
                  'carrier and propeller shaft P103', 'bearing inner rings', 'bearing outer rings', 'steel seat liners', ...
                  'planetary case P101', 'first-stage case F201', 'bearing housing P111', 'retention tube P114'};
in.th.parts_tr = {'yağ girişi', 'giriş pinyonu F203', 'dişli 2 F202', 'güneş P105', 'planetler P107', 'halka dişli P102', ...
                  'taşıyıcı ve pervane mili P103', 'rulman iç bilezikleri', 'rulman dış bilezikleri', 'çelik yuva gömlekleri', ...
                  'planet gövdesi P101', 'birinci kademe gövdesi F201', 'yatak gövdesi P111', 'tutma tüpü P114'};
in.th.states = {'cold soak', 'ground idle', 'cruise 50%', 'MCT, oil 132', 'LD-02, oil 149, 15 min'};
in.th.states_tr = {'soğuk bekleme', 'yer rölantisi', 'seyir %50', 'MCT, yağ 132', 'LD-02, yağ 149, 15 dk'};
%             oil   pin   g2    sun   pl    ring  carr  bin   bout  liner casep casef P111  tube
in.th.T = [  -40   -40   -40   -40   -40   -40   -40   -40   -40   -40   -40   -40   -40   -40;
              60    65    65    66    66    62    63    66    63    62    50    50    48    60;
             110 117.7 117.7 120.2 120.2 112.3   115   117   113   110    98    97    95   110;
             132 144.9 144.9 149.0 149.0 135.8   140   142   137   132   120   118   115   132;
             149 163.5 163.5 170.0 170.0 154.1   157   159   154   149   NaN   NaN   NaN   149];
% LD-02: the cases lag (NaN: from the transient in tl_thermal, 15 min from the MCT state)
in.th.dT_case = 12;                         % K, case below the oil at steady state (outside cooling), TBR
in.th.tau = struct('gear', 60, 'brg', 120, 'carrier', 300, 'liner', 400, 'case', 600, 'P111', 900);   % s, TBR
% cold-start transient (step 3.2 os_coldstart): from the -40 degC soak at ground idle the oil reaches the
% feed temperature 10.6 degC in 9.1 min; then MCT: the oil rises at the MCT heat into the oil over the oil and
% warming metal capacity (12.8 kW / 28.5 kJ/K) up to the cold-day inlet the thermostatic valve holds, about
% 60 degC at -20 and -40 degC ambient at MCT (step 3.2, C-07)
in.th.cold = struct('T0', -40, 'T_ok', 10.6, 't_ok', 9.1 * 60, 'rate_mct', 12.8 / 28.5, 'T_oil_max', 60, ...
                    'dT_gear_idle', 3, 't_end', 3600);
% gear offsets above the oil at MCT (theta_M - oil, step 2.4): first stage 12.9, sun-planet 17.0, ring 3.8 K;
% the carrier, bearings follow the oil with their time constants

% E6 Gear accuracy (ISO 1328-1:2013 classes; step 2.4 used A4 first stage, A5 planetary for K_v and f_pb)
% [name, z, m_n, beta, b, class (pitch, helix), profile class, runout factor]
in.gear = struct('name', {'input pinion F203', 'gear 2 F202', 'sun P105', 'planets P107', 'ring gear P102'}, ...
                 'key', {'pinion', 'gear2', 'sun', 'planet', 'ring'}, ...
                 'z', {31, 110, 45, 37, 119}, 'mn', {2, 2, 2, 2, 2}, 'beta', {15, 15, 0, 0, 0}, ...
                 'b', {52, 52, 70, 70, 70}, 'A', {4, 4, 5, 5, 5}, 'A_profile', {4, 4, 4, 4, 5}, ...
                 'finish', {'ground, superfinished', 'ground, superfinished', 'ground, superfinished', ...
                            'ground, superfinished', 'shaped, honed, superfinished'});
% A_profile: the sun and planets are ground: their profile form and slope to class 4 (one class finer than
% the pitch class 5 of step 2.4) to support STR-11 (TE2 <= 0.15 um; 3.9 LTCA confirms); TBR
in.Fr_share = 0.9;                          % runout F_r as a share of F_p (ISO 1328-2 relation, TBR)
in.tip_relief_tol = 2;                      % um, tolerance of the profile modification amplitude (STR-11 support), TBR
% Tooth thickness allowances (upper deviation E_sns, tolerance T_sn) [um], chosen in E3 for a positive
% backlash in the cold-start transient; TBR
in.tt = struct('pinion', [-70 30], 'gear2', [-90 40], 'sun', [-40 25], 'planet', [-40 25], 'ring', [60 40]);
% ring: internal gear, the space width allowance (+ = wider space, more backlash) [um]

% E3a First-stage stack-up: centre-distance tolerance of the bores (position of the two liner bores,
% +- [um], E1), bearing radial play not credited (the mesh force pushes the gears apart)
in.s1 = struct('fa', 10, 'n_mc', 100000, 'seed', 38);
% E3b Planetary: normal distributions with the tolerance as +-3 sigma; pin true position
% 0.010 mm (+-0.005 radial and tangential), matched planet set +-3 um; ring ovality as in step 2.4
in.ls = struct('pin_tp', 0.010, 'planet_set', 0.003, 'n_mc', 50000, 'seed', 38, 'Kgam_lim', 1.35, ...
               'pct_life', 90);
% E3c Axial: QJ1024 axial internal clearance (four-point contact, TBR), QJ axial deflection and P111
% flange deflection at the 20 kN limit thrust (TBR, 3.9 FE), catcher-lip gap at 20 degC [mm] with its
% tolerance (0.80-1.00 since 3.9: at least 0.6 mm hot, loaded and pulled out, G1b; was 0.40-0.60), the lengths of
% the thermal loops (shaft collar to QJ inner face, lip to QJ outer face) [mm];
% retention tube length and hub-anchor axial clearance at 20 degC
in.ax = struct('qj_play', [0.06 0.10], 'qj_defl', 0.025, 'p111_defl', 0.020, 'lip_gap', [0.80 1.00], ...
               'L_shaft', 35, 'L_cover', 35, 'L_tube', 600, 'tube_gap', [0.50 0.70], 'F_thr', 20e3, ...
               'A_shaft', pi / 4 * (120^2 - 100^2), 'planet_float', [0.20 0.40], 'sun_float', [0.40 0.80]);

% E4 Fits: bearing rings (inner on the shaft, outer in the steel liner), ISO 286 classes; the liners in the
% A357 bosses (interference from step 3.5, Lame); the planet pins in the carrier plates; the ring gear seat.
% Bearing radial internal clearance before mounting [min max] (ISO 5753-1 group, TBR); ring wall ratios for
% the clearance change (thin ring: 0.8 of the fit interference reaches the raceway, TBR)
in.brg = struct('name', {'NU1024 (propeller)', 'QJ1024 (propeller)', 'NU2209 (input)', 'NU2210 (intermediate)', ...
                         'QJ209 (input)', 'QJ210 (intermediate)'}, ...
                'd', {120, 120, 45, 50, 45, 50}, 'D', {180, 180, 85, 90, 85, 90}, ...
                'shaft', {'n6', 'k5', 'm5', 'm5', 'k5', 'k5'}, 'housing', {'J6', 'G6', 'J6', 'J6', 'G6', 'G6'}, ...
                'c0', {[0.100 0.140], [0.0 0.0], [0.060 0.090], [0.060 0.090], [0 0], [0 0]}, ...
                'T_in', {'brg_in', 'brg_in', 'brg_in', 'brg_in', 'brg_in', 'brg_in'}, ...
                'shaft_d_i', {100, 100, 24, 30, 24, 30});
% the QJ bearings are radially free in their housings (step 2.5): G6 gives the radial clearance; their
% axial play is in in.ax; c0 of the roller bearings: one group above the usual, C4 for the 120 mm NU1024 and C3
% for the others, so that the cold-start transient keeps a clearance (E4; values TBR with the supplier)
in.k_ring = 0.8;                            % share of the ring fit interference that reaches the raceway
in.liner = struct('name', {'NU1024', 'NU2209', 'NU2210'}, 'r_i', {90, 42.5, 45}, 't', {3, 2.5, 2.5}, ...
                  'r_boss', {108, 58, 60}, 'delta', {[0.3335 0.3635], [0.0859 0.1059], [0.0930 0.1130]}, ...
                  'case', {'case_p', 'case_f', 'case_f'});
% delta: radial interference of the liner in the boss at 20 degC [min max] mm: the minimum is the step 3.5
% sizing (half its diametral d20, holding the radial load at 149 degC), plus a 0.030 / 0.020 mm band (TBR)
in.pin = struct('d', 38, 'bore', 20, 'r_out', 40, 'fit', {{'H6', 's6'}}, 'L', 10, 'mu', 0.12, 'F_ax', 2000);
% planet pin in a 10 mm carrier plate (hollow pin, bore 20; plate ring about a pin bore r_out 40 mm, step 3.5);
% F_ax: axial force on a pin from the helix-free planetary stage (sliding friction of the planet, TBR)
in.seat = struct('r', 129.5, 'r_ring_in', 121.5, 't_case', 8, 'c_min', 0.002, 'cls_ring', 'h5', 'cls_bore', 'T6', ...
                 'bore_dev', [-262 -230], ...
                 'c_assy', 0.025, 'T_age', 150, 'sy', 240, 'k_cast', 1.25);
% ring gear seat: bore radius, ring rim inner radius (root circle), case wall; c_min: radial interference kept
% at the MCT state [mm]; c_assy: radial clearance for assembly with the heated case [mm]; T_age: A357-T6
% over-ageing limit (step 3.4); bore_dev: limit deviations of the case bore [um] on the h5 ring, chosen for the
% interference the MCT and LD-02 states need (E4); the nearest ISO class T6 (-251 / -219) opens at LD-02
in.seat_fatigue = struct('se', 60 * 0.7, 'su', 310, 'sa_1P', 8.4, 'torque_share', 0.5);
% Goodman inputs of step 3.6 (endurance x gigacycle knock-down, ultimate, 1P amplitude); cruise torque share

% E5 Splines (ISO 4156-1, 30 deg pressure angle, flat root; step 2.5): [name, m, z, fit, parts, materials]
in.spl = struct('name', {'sun quill to intermediate shaft (fixed)', 'sun quill to sun (crowned)', ...
                         'PT shaft coupling to the input pinion', 'generator quill', 'OSG quill', 'PCU quill', ...
                         'oil pump quill'}, ...
                'm', {1.5, 1.5, 1.5, 1.0, 0.8, 0.8, 0.8}, 'z', {30, 30, 24, 22, 14, 14, 14}, ...
                'fit', {'H/k', 'H/f', 'H/h', 'H/f', 'H/f', 'H/f', 'H/f'}, 'cls', {5, 5, 5, 6, 6, 6, 6}, ...
                'T_hub', {'gear2', 'sun', 'pinion', 'gear2', 'gear2', 'gear2', 'gear2'}, ...
                'T_shaft', {'gear2', 'gear2', 'pinion', 'gear2', 'gear2', 'gear2', 'gear2'});
% sizes of the coupling and accessory splines TBR (3.9); the hub and shaft temperatures from E2 (TBR)
end
