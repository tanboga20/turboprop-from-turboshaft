function in = hm_inputs()
%HM_INPUTS  Inputs of the step 3.10 HUMS study: synthetic accelerometer signal, indicators, thresholds.
%   in = hm_inputs()
%
%   The signal is synthetic: it stands in for the accelerometer on the case wall over the ring gear
%   (step 2.10, z 96 mm) until the engine test of step 3.11 records real baselines. Speeds, tooth
%   numbers and the planet bearing frequency come from the design data (gd_inputs, sb_inputs,
%   hm_frequencies); the amplitudes, the resonance, the noise and the fault sizes are assumptions
%   (TBR) chosen to look like a planetary gearbox signal, not values measured on this RGB.
%
%   Source: Phase 3 report, Section 3.10.

gi = gd_inputs();
F = hm_frequencies(gi, sb_inputs(), ad_inputs(), 1);
in.z1 = gi.s1.z1;  in.z2 = gi.s1.z2;
in.zs = gi.s2.zs;  in.zp = gi.s2.zp;  in.zr = gi.s2.zr;  in.N = gi.s2.N;
in.f_sun = F.shaft(2).Hz;                      % Hz, intermediate shaft (sun) at 100% speed
pb = F.bearing(strcmp({F.bearing.name}, 'planet (full complement)'));
in.k_bore = pb.outer / in.f_sun;               % planet bore defect frequency per sun revolution

% record: 2^17 samples at 51.2 kHz = 2.56 s, 192 revolutions of the sun relative to the carrier
in.fs = 51200;  in.n = 2^17;
in.speed_var = [0.003 0.5];                    % slow speed wander: +-0.3% at 0.5 Hz (TBR)

% healthy signal (amplitudes in m/s^2, TBR)
in.sensor_deg = 0;                             % accelerometer angle; planet i starts at 360 i / N
in.A_pm = [1.0 0.4 0.15];  in.ph_pm = [0 0.7 1.9];   % planetary mesh harmonics 1-3
in.w_floor = 0.2;                              % transmission window: floor + (1 - floor) ((1 + cos)/2)^2
in.A_fs = [0.6 0.2];  in.ph_fs = [0 1.2];      % first-stage mesh harmonics 1-2
in.A_shaft = [0.05 0.08 0.10];  in.ph_shaft = [0.3 1.1 2.0];   % input, intermediate, carrier 1x
in.noise = 0.25;                               % m/s^2 rms, broadband
in.var_load = 0.05;                            % record-to-record scatter of the mesh amplitudes (1 sigma)

% seeded faults
in.crack = struct('a', 0, 'beta', 0, 'phi0', 0.3, 'width', 0.6);   % sun tooth: amplitude loss a,
                                               % phase beta (rad) over a Gaussian of 0.6 tooth pitches
in.spall = struct('b', 0, 'planet', 0, 'fn', 8400, 'zeta', 0.03, 'tmax', 0.006, 'slip', 0.01);
                                               % planet bore spall: impulse b (m/s^2 peak), resonance
                                               % fn (Hz) with damping zeta, roller slip 1% (random)

% processing
in.tsa_pts = 1024;                             % TSA points per sun revolution relative to the carrier
in.n_side = 6;                                 % sidebands each side for the sideband energy ratio
in.band = [7400 9400];                         % Hz, envelope band around the assumed resonance
in.pfa = [1e-3 1e-6];                          % false alarm probability: caution, alarm
in.n_base = 50;                                % healthy records in the baseline population
in.crack_a = [0 0.05 0.10 0.15 0.20 0.30];     % sweep of the crack size (amplitude loss)
in.spall_b = [0 0.25 0.5 1 2 4];               % sweep of the spall impulse (m/s^2)
in.n_seed = 5;                                 % records per fault size
end
