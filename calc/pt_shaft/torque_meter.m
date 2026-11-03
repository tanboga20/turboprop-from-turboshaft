function tm = torque_meter(s, in)
%TORQUE_METER  Twist, resolution and temperature error of the phase-shift torque meter (CTL-01).
%   tm = torque_meter(s, in)
%
%   Inputs
%     s    tube_shaft output (the load shaft)
%     in   ptshaft_inputs (in.tm, in.shaft, torques, speed)
%
%   Output struct tm
%     twist_100, twist_lim   twist of the measuring length at T_100 and at
%                            the LD-01 torque                            [deg]
%     res                    angular resolution of the phase measurement at
%                            100% speed, omega x dt                      [deg]
%     err_res                resolution error at T_100, res / twist_100   [-]
%     err_temp               error from the shear modulus change over the
%                            shaft temperature change dT, uncompensated   [-]
%     ok_res                 err_res <= 2% (CTL-01 accuracy +-2%, TBR)
%
%   A reference tube fixed to the load shaft at the PT end runs inside it,
%   unloaded; toothed wheels on both at the RGB end pass magnetic pickups,
%   and the phase between the two signals is the twist of the load shaft.
%   G falls by about 0.026% per K in steels, so the torque meter needs the
%   shaft temperature (or a calibration against it) to stay within 2%.
%
%   Source: Phase 2 report, Section 2.2 ("Torque meter"). Tested by
%   test_step22 (TC27).

G = in.shaft.E / (2 * (1 + in.shaft.nu));
k = in.tm.L_meas / (G * s.J) * 180 / pi;     % deg per N m
tm.twist_100 = in.T_100 * k;
tm.twist_lim = in.T_lim * k;
tm.res = in.n_PT * pi / 30 * in.tm.dt * 180 / pi;
tm.err_res = tm.res / tm.twist_100;
tm.err_temp = abs(in.shaft.dE_dT) * in.tm.dT_shaft;
tm.ok_res = tm.err_res <= 0.02;
end
