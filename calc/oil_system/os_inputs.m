function in = os_inputs()
%OS_INPUTS  Inputs and assumptions of step 3.2: the oil system hardware and its hydraulic network.
%   in = os_inputs()
%
%   Flows, jets, pumps, cooler and tank come from step 2.7 (calc/lubrication),
%   the geometry from step 3.1 (calc/assembly); every other value is an
%   assumption listed in Section 3.2 of the Phase 3 report. TBD marks values
%   of an interface partner (nacelle, propeller, aircraft maker).
%   Units: mm, kPa (gauge unless noted), L/min, degC, s unless noted.

% Operating points: pump speed as a share of 100% PT speed, oil temperature at the RGB inlet, oil grade
in.ops = struct('name', {'MC', 'ground idle', 'cold start'}, ...
                'n', {1.00, 0.60, 0.60}, ...         % ground idle and start: 60% PT speed (TBD, engine maker)
                'T', {100, 100, -40}, ...            % hot idle is the low-pressure case; -40 degC: LUB-02, ENV-01
                'nu_cold', {[], [], 11000});         % cSt, MIL-PRF-23699 data sheet at -40 degC (step 2.7)

% Valves (CT7-9 class values, TBR)
in.p_reg = 550;                             % kPa, pressure regulating valve at the RGB manifold (step 2.7 supply)
in.p_relief = 1100;                         % kPa, pump outlet relief valve (protects the cold lines and the filter)
in.dp_filter_clean = 35;                    % kPa, clean 3 um element at 30 L/min and 100 degC (LUB-05)
in.dp_filter_bypass = 170;                  % kPa, filter bypass valve with impending-bypass indication at 120 kPa
in.dp_cooler_bypass = 240;                  % kPa, cooler core bypass (pressure relief across the core)
in.T_thermostat = 60;                       % degC, below it the thermostatic valve at the RGB skips the whole cooler
                                            % loop (hoses and core): found necessary by the -40 degC cold start
in.dp_strainer = 8;                         % kPa, last-chance strainer at each jet at its design flow (TBR)

% Lines and passages: [length mm, bore mm, number of 90-degree bends]; external lengths are TBD with the nacelle.
% Suction: tank to pump inlet at most 150 mm with a 32 mm bore, an interface requirement from the -40 degC
% start (a 450 x 20 mm line starves the pump)
in.line = struct('suction', [150 32 1], ...
                 'pump_filter', [250 12 2], ...    % cored passage in the accessory cover
                 'filter_cooler', [1500 16 4], ... % hose to the cooler in the nacelle (TBD)
                 'cooler_rgb', [1500 16 4], ...    % hose back to the RGB inlet boss (TBD)
                 'rear_sump', [700 6 4]);          % tube along the tunnel to the PT rear sump (step 2.2)
in.d_gallery = 8;                           % mm, main galleries drilled in the castings
in.d_branch = 5;                            % mm, branch drillings to the jets
in.K_bend = 0.4;                            % loss coefficient of a drilled corner or hose bend (turbulent)
in.K_tee = 1.0;                             % branch tee
in.Cd_inf = 0.70;                           % jet discharge coefficient at high Reynolds number (step 2.7)
in.l_d_jet = 2;                             % jet bore length / diameter (Cd falls at low Reynolds number, Lichtarowicz)

% Carrier oil transfer: stationary sleeve on the case rear wall into the carrier rear plate hub, piston-ring
% seals; radial drillings to the hollow pins (bore 20, step 3.1) and to the mesh jets on the posts
in.transfer = struct('r_in', 36, 'r_out', 49.9, 'z', [12 30], 'r_feed', 40);
% stationary sleeve bolted to the front face of the planetary case rear wall, running 0.1 mm inside the carrier
% rear plate bore (r 50) with piston-ring seals; two grooves: lube oil to the carrier at r_feed, and the
% governed pitch oil (PIF-02), led through a carrier post and the front plate to the axial transfer tube

% Pitch-change oil (PIF-02): transfer ring on the propeller shaft at the nose, tube in the shaft bore
in.pitch = struct('Q', 5.0, 'z_tube', [110 712], 'd_tube', [12 16]);   % L/min TBD (propeller maker); tube on the
                                            % axis inside the retention tube, bore and outside diameter [mm]

% Pump inlet (ENV-02) and tank (LUB-06)
in.alt_ft = 45000;                          % ENV-02 ceiling
in.p_tank_valve = 34.5;                     % kPa, tank pressurising valve above ambient (5 psi, TBR)
in.h_tank = 150;                            % mm, oil level above the pump inlet at the lowest usable level
in.p_inlet_min = 35;                        % kPa absolute, gerotor inlet pressure with aerated oil (TBR)
in.V_usable = 5.69;                         % L, step 1.4 / 2.7 usable oil

% Negative g (LUB-08): -1.27 g; a flexible pick-up keeps the inlet in oil; scavenge stops returning oil
in.g_neg = -1.27;

% Run without oil (LUB-07 goal: 30 min at cruise power after a total loss of oil pressure)
in.t_LUB07 = 30 * 60;                       % s
in.T_dry_start = 110;                       % degC, parts at the moment of the loss
in.T_dry_limit = 230;                       % degC, scuffing and tempering of carburized Pyrowear 53 (TBR)
in.q_drip = [0.02 0.05 0.10];               % L/min per critical contact fed by an emergency reservoir
in.rho_res = 1.4;                           % kg of reservoir structure per litre (A357 pocket, valve, TBR)
in.T_drip = 100;                            % degC, oil in the emergency reservoir
in.G_pc = 30;                               % W/K, parts to case through bearings and shafts without oil (TBR)
in.hA_case = 40;                            % W/K, case to nacelle air: about 0.8 m^2 at 50 W/(m^2 K) (TBR)
in.T_amb_dry = 53;                          % degC, nacelle air on a hot day (LUB-04)
% Emergency air-oil mist (LUB-07 option, literature: NASA TM-2011-217106 mist 0.3 mL/min on a spur mesh for
% 30 min; US 4717000 bleed air with accumulator oil at the jets): all values TBR
in.mist = struct('q', [0.3 1.0], ...                % mL/min of oil per contact
                 'scfm', [10 20], ...               % standard cubic feet per minute of mist air (all jets)
                 'T_air', 100, ...                  % degC, compressor bleed after a cooler (TBD in installation C)
                 'eff', 0.5, ...                    % the air leaves half-way to the parts temperature
                 'uplift', [1.0 1.5], ...           % friction factor on the lubricated mesh and bearing losses
                 'm_acc_per_L', 1.2, 'm_acc_min', 0.6, ...   % kg of accumulator per litre, smallest unit
                 'm_valve', 0.3, 'm_lines', 0.6, 'm_air_line', 1.0);   % kg: shut-off/check valves, mist lines, bleed line
% Option A hardware in CATIA beside the manifold: accumulator and valve [diameter length] mm, tie-in bore,
% bleed line bore, end of the modelled bleed line
in.mist.V_margin = 1.5;                     % accumulator volume margin on 6 min at 1 mL/min per contact
in.tube_wall = [0.9 0.8];                   % mm, wall of the 8 mm and 6 mm bore external tubes (steel)
in.k_fittings = 0.3;                        % fittings, clamps and bosses on the tube mass (TBR)
in.mist_hw = struct('acc', [70 120], 'valve', [40 60], 'offset', 60, 'd_tie', 6, 'd_bleed', 12, 'z_bleed_end', -420);
% offset: tangential distance of the mixing valve from the regulating valve end [mm]
in.mass_margin = 2.34;                      % kg, SYS-06 margin after step 3.1 (110 kg TBR)

% Cold start warm-up: heat from the RGB losses at ground idle and the pump throttling into the oil and part of
% the metal next to it
in.m_metal_warm = 0.3;                      % share of the RGB mass that warms with the oil (TBR)
in.c_metal = 0.5;                           % kJ/(kg K), steel and aluminium mix
in.V_oil_total = 6.8;                       % L, tank (step 2.7) plus the oil in the RGB
in.P_idle = 2.5;                            % kW, RGB losses at ground idle, cold (churning in thick oil; TBR)
in.Q_ok = 0.5;                              % jets at half their design flow count as lubricated
% step 3.3 sensitivity runs may override inputs (calc/interfaces/if_override; no effect otherwise)
if exist('if_override', 'file') == 2, in = if_override(in, mfilename); end
end
