function ss = sudden_stop(T, in, t_stop, n_PT)
%SUDDEN_STOP  Peak torques when the power turbine seizes and stops in t_stop (LD-08).
%   ss = sudden_stop(T, in, t_stop, n_PT)
%
%   Inputs
%     T        torsion_model output
%     in       torsion_inputs (modal damping zeta)
%     t_stop   time in which the PT speed falls linearly to zero            [s]
%     n_PT     PT speed before the seizure                                  [rpm]
%
%   Output struct ss
%     t                  time grid                                          [s]
%     T_prop_shaft       torque history in the propeller shaft              [N m]
%     peak               largest |torque| in each element (reported with its
%                        lever arm, see torsion_model)                      [N m]
%     names              element names
%     T_qs               quasi-static propeller shaft torque J_prop w_prop / t_stop [N m]
%     daf                peak / quasi-static torque in the propeller shaft   [-]
%     f1                 lowest natural frequency with the PT held          [Hz]
%
%   The PT angle is prescribed. Writing the other rotations as the rigid
%   rotation that follows the PT plus a relative twist x gives
%   M x'' + C x' + K x = -M r a_PT, with r the rigid speed ratios and a_PT
%   = -w0 / t_stop during the stop: a rectangular pulse. Modal superposition
%   with modal damping zeta and the exact step response
%   g(t) = 1 - exp(-zeta w t) (cos(w_d t) + zeta / sqrt(1 - zeta^2) sin(w_d t)),
%   eta = F / w^2 (g(t) - g(t - t_stop) H(t - t_stop)). No propeller
%   aerodynamic torque, no steady torque: the result is the reverse torque
%   that the event adds, which is conservative.
%
%   Source: Phase 2 report, Section 2.3 ("Sudden stoppage"). Tested by
%   test_step23 (TC32).

free = setdiff(1:size(T.M, 1), T.iPT);
M = T.M(free, free);
K = T.K(free, free);
r = T.ratio(free);
w0 = n_PT * pi / 30;
F = M * r * (w0 / t_stop);                  % inertial load of the deceleration
[V, D] = eig(K, M);
w = sqrt(diag(D));
[w, o] = sort(w);
V = V(:, o);
for k = 1:numel(w)
    V(:, k) = V(:, k) / sqrt(V(:, k)' * M * V(:, k));
end
z = in.zeta;
wd = w * sqrt(1 - z^2);
Fk = V' * F;
f1 = w(1) / (2 * pi);
t_end = t_stop + 4 / f1;
dt = min(1 / (200 * f1), t_stop / 200);       % 200 points per period of the lowest mode
t = (0:dt:t_end);
pos = @(tt) max(tt, 0);                      % the step acts from its start time on
g = @(k, tt) (tt > 0) .* (1 - exp(-z * w(k) * pos(tt)) .* (cos(wd(k) * pos(tt)) ...
                                                           + z / sqrt(1 - z^2) * sin(wd(k) * pos(tt))));
eta = zeros(numel(w), numel(t));
for k = 1:numel(w)
    eta(k, :) = Fk(k) / w(k)^2 * (g(k, t) - g(k, t - t_stop));
end
x = V * eta;
xf = zeros(size(T.M, 1), numel(t));
xf(free, :) = x;
ne = numel(T.el);
peak = zeros(ne, 1);
for e = 1:ne
    tq = T.el(e).k * (T.el(e).a' * xf) * T.el(e).arm;
    peak(e) = max(abs(tq));
    if strcmp(T.el(e).name, 'propeller shaft')
        ss.T_prop_shaft = tq;
    end
end
ss.t = t;
ss.peak = peak;
ss.names = {T.el.name}';
ss.T_qs = T.M(T.iProp, T.iProp) * w0 * abs(T.ratio(T.iProp)) / t_stop;
ss.daf = max(abs(ss.T_prop_shaft)) / ss.T_qs;
ss.f1 = f1;
end
