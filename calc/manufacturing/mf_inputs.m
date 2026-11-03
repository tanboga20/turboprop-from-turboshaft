function in = mf_inputs()
%MF_INPUTS  Inputs and assumptions of step 3.4: materials, processes and the bill of materials.
%   in = mf_inputs()
%
%   The materials of the decided parts come from Phase 2 (gears 2.4, shafts
%   and retention tube 2.5, quills 2.6, case 2.8) and step 3.1; the process
%   values (case depths, hardness, fastener and liner sizes) are assumptions
%   listed in Section 3.4 of the Phase 3 report, TBR until the drawings of
%   step 3.9 and the supplier data. Units: mm, MPa, kg, degC.

% Materials: key, designation, specification, density [kg/m^3], E [MPa], Poisson, CTE 20-150 degC [1/K]
% (typical handbook values, TBR), and the highest temperature the condition allows [degC]
mat = @(key, name, spec, rho, E, nu, cte, T_max) struct('key', key, 'name', name, 'spec', spec, 'rho', rho, ...
                                                       'E', E, 'nu', nu, 'cte', cte, 'T_max', T_max);
in.mat = [mat('P53', 'Pyrowear 53, carburized', 'AMS 6308', 7830, 206e3, 0.30, 11.9e-6, 200);
          mat('N13', '32CrMoV13 (EN 1.8523), gas nitrided', 'EN 1.8523; aerospace grade 32CDV13', 7830, 206e3, 0.30, 12.3e-6, 450);
          mat('S43', 'AISI 4340, quenched and tempered to 1240 MPa', 'AMS 6414 (VAR)', 7830, 205e3, 0.29, 12.3e-6, 425);
          mat('M5N', 'M50NiL, carburized', 'AMS 6278', 7830, 202e3, 0.30, 11.7e-6, 315);
          mat('A357', 'A357-T6 sand casting', 'AMS-A-21180', 2680, 72e3, 0.33, 21.5e-6, 150);
          mat('Ti64', 'Ti-6Al-4V, annealed', 'AMS 4928', 4430, 114e3, 0.34, 8.8e-6, 400);
          mat('C321', 'CRES 321 tubing, annealed', 'AMS 5557', 7920, 193e3, 0.30, 16.6e-6, 800);
          mat('C155', '15-5PH, H1025', 'AMS 5659', 7800, 196e3, 0.27, 11.3e-6, 315);
          mat('A286', 'A286 fastener alloy', 'AMS 5737 (bar for bolts)', 7940, 201e3, 0.31, 16.5e-6, 650);
          mat('S129', 'Alloy steel bolts, property class 12.9', 'ISO 898-1 class 12.9 (the VDI 2230 run of step 3.5)', 7850, 205e3, 0.29, 12.3e-6, 300)];
% T_max: P53 tempered about 200-230 degC (step 2.4); N13 and S43 tempered far above the oil temperatures;
% A357-T6 aged at about 155-170 degC (over-ageing above about 150 degC, a 3.5 item); the others from
% their usual service limits

% Case depths and hardness (STR-06): carburized main gears 0.5-0.7 mm effective case depth to 550 HV after
% grinding (step 2.4 named 0.4-0.6 mm; the planet tooth on the ring side needs 0.43 mm at LD-02 with in.k_cd,
% so the band moves up, still below 0.4 m_n = 0.8 mm), surface 58-63 HRC, core at least 30 HRC; nitrided ring at least 650 HV at the surface
% (STR-06) with a nitriding depth (to core + 50 HV) of 0.5-0.7 mm; separate planet pins in carburized M50NiL
% with 1.0-1.5 mm case (TBR, bearing supplier practice)
in.cd = struct('P53', [0.5 0.7], 'N13', [0.5 0.7], 'M5N', [1.0 1.5]);
in.k_cd = 2.0;                              % case depth / depth of the largest shear stress at LD-02 load (TBR)
in.cd_iso = [0.3 0.4];                      % ISO 6336-5 bounds used in step 2.4: Eht >= 0.3 mm, <= 0.4 m_n

% Flank finish (STR-09, Decision 1 of step 2.4): the step 2.4 film used Rz 0.8 um on the external gears
% and Rz 1.0 um on the ring, with Ra = Rz / 6 and lambda = h_min / sqrt(Ra1^2 + Ra2^2). The film itself does
% not depend on the roughness, so lambda scales with the composite Ra
in.Ra_list = [0.05 0.10 0.15 0.20];         % um, the same Ra on both flanks of a mesh
in.T_film = [100 132];                      % degC oil inlet: cooler hot-day design point, LUB-02 continuous limit
% MIL-PRF-23699 only (Hamit's oil decision)

% Planet bearing raceways (step 2.5): full complement, line contact; Stribeck load share of the most loaded roller
in.stribeck = 4.08;                         % line contact, zero clearance
in.F_cf_planet = 3.8e3;                     % N, centrifugal force of planet and rollers at carrier speed (step 2.5)

% Fasteners: one row per joint [n, d (mm), length (mm), washers per fastener, nuts per fastener, inserts];
% counts and sizes TBR until the drawings (3.9), except the 30 x M6 case flange (step 2.8). Mass of a
% fastener: shank pi/4 d^2 L plus head, washer, nut and insert volumes as multiples of d^3
in.fast = struct('name', {'planetary case to first-stage case flange (step 2.8)', ...
                          'first-stage case to accessory cover', ...
                          'engine mount ring on the first-stage case (TBD, engine maker)', ...
                          'propeller bearing housing to the case nose', ...
                          'ring gear retention plate', ...
                          'generator cartridge to the first-stage case', ...
                          'generator mounting studs and nuts (pad, TBD)', ...
                          'OSG adapter and OSG mounting studs', ...
                          'PCU adapter and PCU mounting studs', ...
                          'pump pack', ...
                          'oil manifold, filter, valves and tube clamps', ...
                          'covers, chip detector and sensor bosses'}, ...
                 'n',   {30, 24, 12, 12, 12, 8, 6, 8, 10, 4, 24, 20}, ...
                 'd',   {6, 5, 8, 6, 6, 6, 8, 6, 6, 6, 5, 5}, ...
                 'L',   {26, 20, 30, 20, 18, 20, 35, 25, 25, 25, 16, 14}, ...
                 'wash', {1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0}, ...
                 'nut',  {0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0}, ...
                 'ins',  {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1});
in.c_fast = struct('head', 1.0, 'washer', 0.35, 'nut', 0.9, 'insert', 0.15);   % volumes / d^3
in.rho_fast = 7940;                         % A286
in.k_fast = 1.5;                            % contingency on the bottom-up fastener mass (joints not drawn yet)
in.allow_share = 0.05;                      % step 3.1 allowance: bolts and locking as a share of the modelled mass

% Steel seat liners shrunk into the light-alloy castings (step 2.8 concept): [bearing, count, OD, width,
% liner wall]; the bearing outer ring sits in the liner. The CATIA castings are solid there, so the liner
% adds (rho_steel - rho_A357) x its volume
in.liner = struct('brg', {'NU1024', 'NU2209', 'NU2210', 'QJ209', 'QJ210', '6305', '6202', '6203'}, ...
                  'n',   {2, 2, 2, 1, 1, 2, 1, 2}, ...
                  'D',   {180, 85, 90, 85, 90, 62, 35, 40}, ...
                  'B',   {28, 23, 23, 19, 20, 17, 11, 12}, ...
                  't',   {3.0, 2.5, 2.5, 2.5, 2.5, 2.0, 2.0, 2.0});
in.liner_extra_B = 4;                       % mm, liner longer than the bearing (shoulder and chamfers)
in.T_fit = [-40 20 132 149];                % degC: cold start, assembly, maximum continuous oil, LD-02
end
