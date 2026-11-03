function r = shaft_break(J, Q0, n0, t_delay, tau, in14)
%SHAFT_BREAK  Power turbine overspeed after the drive chain breaks (SAF-03).
%   r = shaft_break(J, Q0, n0, t_delay, tau, in14)
%
%   Inputs
%     J         power turbine rotor inertia, the broken-off part excluded [kg m^2]
%     Q0        turbine torque at the moment of the break             [N m]
%     n0        power turbine speed at the break                      [rpm]
%     t_delay   time from detection to a closed fuel valve (processing
%               plus valve)                                           [s]
%     tau       decay time of the turbine torque once the valve is closed [s]
%     in14      lube_inputs: k_stall, drag, mismatch, residual, t_end, dt
%
%   The load is gone at t = 0, so J dw/dt = Q - Q_drag. Turbine torque line
%   at a fixed gas state: Q = Q0 (k - (k - 1) w/w0), k = k_stall (k Q0 at
%   zero speed, runaway at k/(k - 1) w0). Drag of the rotor itself (windage,
%   bearings): Q_drag = drag Q0 (w/w0)^2. Detection: the power turbine runs
%   mismatch above the speed the propeller would give (the propeller speed is
%   held constant, which is the slowest detection). The fuel valve is closed
%   t_delay later; from then the turbine torque is multiplied by
%   residual + (1 - residual) exp(-(t - t_cut)/tau). Fixed-step RK4.
%
%   Output struct r
%     peak      highest speed / n0                                   [-]
%     t_peak    time of the peak                                     [s]
%     t_det     detection time                                       [s]
%     t_cut     time the fuel valve is closed                        [s]
%     rate0     initial acceleration, Q0 (1 - drag) / J / w0         [1/s]
%     T_time    time constant before the cut, J w0 / ((k - 1) Q0)    [s]
%     t, n      speed history, every 1 ms                            [s, rpm]
%
%   Source: Phase 1 report, Section 4 ("Shaft-break overspeed (SAF-03)").
%   Tested by test_step14 (TC16).

w0 = n0 * pi / 30;
k = in14.k_stall;
dt = in14.dt;
n_steps = round(in14.t_end / dt);
t_det = NaN;
t_cut = Inf;
f = @(t, w, t_cut) Q0 * (gain(t, t_cut, tau, in14.residual) * (k - (k - 1) * w / w0) ...
                       - in14.drag * (w / w0)^2) / J;

t = 0;
w = w0;
w_max = w0;
t_max = 0;
every = round(1e-3 / dt);
t_hist = zeros(1, floor(n_steps / every) + 1);
n_hist = t_hist;
n_hist(1) = n0;
for i = 1:n_steps
    k1 = f(t, w, t_cut);
    k2 = f(t + dt / 2, w + dt / 2 * k1, t_cut);
    k3 = f(t + dt / 2, w + dt / 2 * k2, t_cut);
    k4 = f(t + dt, w + dt * k3, t_cut);
    w = w + dt / 6 * (k1 + 2 * k2 + 2 * k3 + k4);
    t = t + dt;
    if isnan(t_det) && w >= w0 * (1 + in14.mismatch)
        t_det = t;
        t_cut = t_det + t_delay;
    end
    if w > w_max
        w_max = w;
        t_max = t;
    end
    if mod(i, every) == 0
        t_hist(i / every + 1) = t;
        n_hist(i / every + 1) = w * 30 / pi;
    end
end
r = struct('peak', w_max / w0, 't_peak', t_max, 't_det', t_det, 't_cut', t_cut, ...
           'rate0', Q0 * (1 - in14.drag) / J / w0, 'T_time', J * w0 / ((k - 1) * Q0), 't', t_hist, 'n', n_hist);
end

function g = gain(t, t_cut, tau, residual)
% Share of the turbine torque left after the fuel valve closes
if t < t_cut
    g = 1;
else
    g = residual + (1 - residual) * exp(-(t - t_cut) / tau);
end
end
