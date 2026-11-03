function in = dy_inputs()
%DY_INPUTS  Inputs and assumptions of step 3.6: forced response of the planet, the first-stage gear web and
%the case to the mesh excitation (DYN-04), the damping ring of the first-stage gear.
%   in = dy_inputs()
%
%   Gear and bearing data come from steps 2.4 and 2.5 (gd_inputs, sb_inputs), the models from step 2.8
%   (calc/housing). Every other value is an assumption listed in Section 3.6 of the Phase 3 report.
%   Units: N, m, Pa, Hz in the finite element models; mm, MPa elsewhere.

% Excitation: transmission error (TE) amplitude per mesh harmonic with the step 2.4 flank modifications
% at maximum continuous torque (TBR: the loaded TE is computed in no step; typical modified aerospace gears)
in.TE = [0.5 0.2 0.1];                      % um, 1x, 2x, 3x mesh frequency (first stage)
% planetary meshes: derived requirement TE2 <= 0.15 um at MCT (delegated by Hamit; LTCA of the
% step 2.4 profile modification in 3.9, loaded TE test in 3.11); 0.2 um kept as the sensitivity case
in.TE_planet = [0.5 0.15 0.1];              % um, 1x, 2x, 3x
in.TE2_sens = 0.2;                          % um, sensitivity case of the planetary 2x harmonic
in.c_tilt = 0.25;                           % load asymmetry over the face width (K_Hbeta - 1, step 2.4) that
                                            % excites tilting modes: line load (1 + c (2 z / b - 1))
% Damping
in.zeta = 0.02;                             % modal damping of the planet on its rollers and meshes (TBR)
in.zeta_web = 0.002;                        % structural damping of the bare gear blank (steel, TBR)
% Frequency response
in.n_freq = 41;                             % points over each band (plus the modes inside it)
in.Hmax_planet = 0.004;                     % m (step 2.8)
in.f_cut_planet = 1.5;                      % planet modes kept up to this x the top of the 3x band, plus the static residual
in.KA = 1.25;                               % application factor (STR-01): K_v,FE = 1 + max F_dyn / (K_A F_t)
% step 2.4 rating of the planet meshes (calc/tests/step24_test_cases.csv TC35, TC36): K_v, K_Hbeta - 1 (load
% asymmetry over the face) and the lower tooth-root safety factor of each mesh (sun-planet: sun; planet-ring: planet)
in.planet24 = struct('Kv', [1.154396783 1.161456625], 'c', [0.260734092 0.358889692], 'SF', [1.875906272 1.807289837]);
in.SF_min = 1.5;                            % STR-01 tooth-root safety factor
in.Hmax_web = 0.008;                        % m, the 3-D check of the web model (dy_web_check3d)
in.h_axi = 1;                               % mm, 2-D section mesh of the gear blank (harmonic model, dy_web)
in.n_harm = 30;                             % harmonics of the 10 deg load patch kept (first zero of its series at 36)
in.f_cut = 1.5;                             % web modes kept up to f_cut x the top of the 2x band, plus the static residual
in.dpsi_web = 10;                           % deg, mesh patch on the rim face of the first-stage gear
in.Kt_fillet = 1.4;                         % web-root fillet factor for the 3.9 fillet (R 3 mm on the 8 mm web, bending; TBR)
in.r_corner = 0.002;                        % m, sharp web-to-hub and web-to-rim corners left out of the stress maximum
% Planetary case (step 2.8 axisymmetric section, harmonic model in dy_case_frf): ring gear seat in the bore.
% The four planets load harmonics n = 0 ... n_count with the mesh phasing of the ring teeth; the static planet
% loads give n = 0 (steady) and n = 4, 8, ... (planet pass, alternating); ring seat brackets slide / rim / mass
in.cs = struct('r_seat', 129.5, 'z_seat', [36 106], ...      % mm, case bore and the ring face width on it
               'dpsi', 20, ...                               % deg, patch of one planet-ring mesh on the seat
               'h_axi', 2, ...                               % mm, 2-D section mesh
               'n_count', 30, ...                            % harmonics solved for the mode count and Campbell
               'f_cut', 1.5, ...                             % modes up to f_cut x the top of the 3x band, plus the static residual
               'r_root_ring', 121.5, ...                     % mm, ring gear root circle (bonded-rim bracket)
               'E_ring', 205e9, 'rho_ring', 7830, ...        % ring gear steel
               'f_teeth', (3.46 + 0.86) / 3.46, ...          % teeth as mass on the ring rim (3.46 kg rim, 0.86 kg teeth)
               'm_ring', 3.46 + 0.86, ...                    % kg, ring gear as a mass layer on the seat
               'k_joint', 2.43e11, ...                       % N/m^3, flange joint springs (step 3.5 st_inputs)
               'zeta', [0.02 0.01], ...                      % case damping bracket
               'k_gc', 0.7, ...                              % gigacycle knock-down of the A357 endurance (2.4e11 cycles, TBR)
               'sm', 35.4, ...                               % MPa, steady stress bound: the step 3.5 case peak at limit load
               'sa_1P', 8.4, ...                             % MPa, step 3.5 1P amplitude added to the alternating stress
               'Kt_corner', 1.4, ...                         % cast fillet R5 (hs_inputs case.rf) at the re-entrant corners (TBR, 3.9)
               'flange', [137.5 162.5 0 12], ...             % mm, attachment flange of the 3.6 design change: PCD 308, OD 325
               'fillets', [137.5 12 10 1; 129.5 12 5 -1]);   % mm, modelled fillets [r z R side]: outer R10 at the wall-flange
                                                             % corner (side +1: towards +r), inner R5 cast (side -1: towards -r)
% Hot, cycle-consistent A357 Goodman (dy_hot_check): endurance loss 20 -> 150 degC (cast Al-Si, E319-T7 proxy, Zhu et
% al., Int J Fatigue 28 (2006) 1566-1571; TBR), a factor 0.9 per decade beyond 1e8 cycles (0.70 at 2.4e11) at the cycles of each check
% (planet pass 8.2e9, mesh-only 7.3e11, first-stage mesh 8.2e11), hot ultimate 310 x 200 / 240 MPa (step 3.5 sy_hot)
in.hot = struct('k_T', 0.88, 'k_pass', 0.818, 'k_mesh', 0.666, 'k_fs', 0.662, 'su', 310 * 200 / 240);
% First-stage case (dy_fscase_frf): coarse 3-D modes and forced response in the first-stage 1x band
in.fs_Hmax = 0.012;                         % m, coarse mesh (about one quadratic element through the walls)
in.fs_fcut = 1.3;                           % modes up to this x the band top
in.fs_sm = 28.7;                            % MPa, steady stress bound: step 3.5 first-stage case peak at limit, flange support (st_fscase3d, both bore halves)
% DYN-03 limit: vibratory stress amplitude against the endurance at the mean stress (Goodman, TBR)
in.sigma_e = struct('P53', 550, 'A357', 60);  % MPa, R = -1 endurance: Pyrowear 53 core (about 0.45 su), A357 sand cast
in.su_A357 = 310;                           % MPa, A357-T6 ultimate (hs_inputs, st_inputs)
in.su = struct('P53', 1220);                % MPa, Pyrowear 53 core ultimate strength (Goodman mean-stress line; TBR)
in.k_cast = 1.25;

% Damping ring of the first-stage gear (step 2.4 decision): a split steel ring in a groove in the bore of the
% rim, at an axial offset from the rim mid-plane so that the out-of-plane web modes make it slip. Sizing rule: the
% lightest ring with s <= s_max on the worst bracket for the slipping families within rule_frac of the largest bare
% stress (the ones that set the Goodman factor); for the others s is reported and the Goodman factor checked
in.ring = struct('rho', 7830, 'E', 205e9, 'mu', 0.15, ...   % steel ring on the steel rim, oil-wetted (TBR)
                 'e', 0.016, ...                            % m, axial offset of the groove from the rim mid-plane (fitted ring)
                 'e_list', [0.016 0.018 0.020], ...         % m, offsets tried (>= 4 mm of full rim beyond a 4 mm groove)
                 'e_gain', 0.02, ...                        % kg, a further-out groove is taken only if it saves this much
                 'rule_frac', 0.8, ...                      % s <= s_max applies to the slipping families near the top
                 'mu_range', [0.08 0.10 0.20 0.30], ...     % friction spread reported with the chosen ring
                 'u_pre', 0.1e-6, ...                       % m, contact pre-sliding at mu 0.15 (scales with mu; TBR)
                 'h', (1.5:0.5:9.5) * 1e-3, ...             % m, ring radial thickness tried
                 'w', 4e-3, ...                             % m, ring axial width
                 'h_mass', 0, ...                           % m, ring section in the blank model (0: bare; set by run_step36)
                 'k_size', 2, ...                           % rule 1: E_f >= k_size W_in at the lowest in-band resonance speed
                 'm_max', 0.2, ...                          % kg, heaviest ring
                 's_max', 0.6, ...                          % rule: amplitude ratio s <= s_max on the worst bracket
                 'd_groove', 1.0e-3, ...                    % m, groove depth in the rim bore (rim 7 mm under the teeth;
                 'sR_ht_min', 1.2, ...                      %    rim to tooth height under the groove >= 1.2, ISO 6336-3)
                 'r_root', 0.3e-3, ...                      % m, groove root radius (drawing note)
                 'Ra_groove', 0.8, ...                      % um, groove finish
                 'c_ax', 0.05e-3, ...                       % m, axial clearance each side of the ring in the groove
                 'oversize', 0.01, ...                      % free outside diameter over the groove bottom
                 'gap', 1e-3, ...                           % m, split gap fitted in the groove
                 'material', 'AISI 4340, 38-42 HRC');       % ring (TBR)
end
