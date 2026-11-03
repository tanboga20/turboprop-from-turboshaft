function W = sf_fire(fw, wall, h_in, T_end, T_start)
%SF_FIRE  Transient temperature through a cylindrical A357 wall in the standard flame (D5), 1-D radial, pdepe.
%   W = sf_fire(fw, wall, h_in, T_end)            the fire with oil flow, from the sink temperature
%   W = sf_fire(fw, wall, h_in, T_end, T_start)   a later phase restarted from a profile (struct with r, T)
%   fw     in.fire: flame (T_f, q0, T0), material (k, rho, cp(T)), oil sink T_sink, solidus, hot yield table
%   wall   struct: t [mm], ri [mm] (oil on the bore, flame round the outside)
%   h_in   heat transfer coefficient on the oil side [W/m2K]
%   T_end  duration of the phase [s]
%
%   pdepe with m = 1 (x = r from ri to ri + t). Flame side: the cold-wall flux q0 of the calibration scaled as a
%   radiation exchange with the flame, q = q0 (T_f^4 - T^4) / (T_f^4 - T0^4) (kelvin), which keeps more of the flux
%   than a convective law as the wall heats (conservative). Oil side: h_in (T - T_sink). A flame round the whole
%   case; under a local burner lateral conduction offsets part of this. The run stops at the solidus of the flame
%   side (no latent heat): later temperatures are not computed.
%   W.t, W.T_hot (flame side), W.T_cold (oil side), W.T_mean (area mean through the wall), W.t_solidus (time the
%   flame side reaches the solidus, Inf if never), W.r, W.T_last (profile at the end, for a restart).
%   Source: Phase 3 report, Section 3.7 (D5).

ri = wall.ri * 1e-3;  ro = ri + wall.t * 1e-3;
x = linspace(ri, ro, 41);
t = linspace(0, T_end, 301);
TK = @(T) T + 273.15;
qf = @(T) fw.q0 * (TK(fw.T_f)^4 - TK(T).^4) / (TK(fw.T_f)^4 - TK(fw.T0)^4);
pde = @(x, t, u, dudx) deal(fw.rho * fw.cp(u), fw.k * dudx, 0);
if nargin < 5
    ic = @(x) fw.T_sink;
else
    ic = @(xx) interp1(T_start.r, T_start.T, xx);
end
bc = @(xl, ul, xr, ur, t) deal(-h_in * (ul - fw.T_sink), 1, -qf(ur), 1);
opts = odeset('RelTol', 1e-6, 'AbsTol', 1e-4);
U = pdepe(1, pde, ic, bc, x, t, opts);
W.t = t(:);
W.T_hot = U(:, end);
W.T_cold = U(:, 1);
W.T_mean = trapz(x, U .* x, 2) / trapz(x, x);
W.r = x;
k = find(W.T_hot >= fw.T_solidus, 1);
if isempty(k)
    W.t_solidus = Inf;
else
    k = max(k, 2);
    W.t_solidus = interp1(W.T_hot(k - 1:k), t(k - 1:k), fw.T_solidus);
    keep = W.t <= W.t_solidus;                          % stop at the solidus
    W.t = W.t(keep);  W.T_hot = W.T_hot(keep);  W.T_cold = W.T_cold(keep);  W.T_mean = W.T_mean(keep);
    U = U(keep, :);
end
W.T_last = U(end, :);
end
