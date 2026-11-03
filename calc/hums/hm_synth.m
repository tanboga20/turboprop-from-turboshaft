function S = hm_synth(in, seed)
%HM_SYNTH  Synthetic accelerometer signal of the RGB over the ring gear, with seeded faults.
%   S = hm_synth(in)          deterministic: no noise, no load scatter, no roller slip
%   S = hm_synth(in, seed)    with noise, load scatter and slip from rng(seed)
%
%   Kinematics (ring fixed): the sun turns at the intermediate shaft speed with a slow wander, the
%   carrier at zs / (zs + zr) of it, the sun relative to the carrier at zr / (zs + zr) of it, the input
%   shaft at z2 / z1 of it. Components:
%    - planetary mesh: each planet i adds harmonics h of zs (theta_rel - 2 pi i / N) (sequential
%      phasing), weighted by a transmission window that peaks when the planet passes the sensor,
%      w = floor + (1 - floor) ((1 + cos(theta_c + 2 pi i / N - sensor)) / 2)^2
%    - sun tooth crack: when the cracked tooth (angle phi0 in the sun frame) meets planet i, that
%      planet's mesh loses amplitude a c and shifts in phase by beta c, with c a Gaussian of
%      width 0.6 tooth pitches in the relative angle
%    - first-stage mesh (z1 times the input shaft angle) and the 1x of the input, intermediate
%      and carrier shafts
%    - planet bore spall: an impact each time a roller passes the defect (k_bore per sun revolution,
%      with slip), weighted by the planet's window and the load zone (1 + cos(spin)) / 2, ringing at
%      the resonance fn: e^(-zeta wn tau) sin(wd tau) for tau < tmax
%    - broadband noise
%   Output S: t, x (m/s^2), th_s (sun angle, rad, for the tachometer), fs.
%
%   Source: Phase 3 report, Section 3.10. Tested by test_step310 (TC119-TC120).

det = nargin < 2;
if ~det, rng(seed); end
fs = in.fs;  n = in.n;
t = (0:n - 1)' / fs;
w0 = 2 * pi * in.f_sun;
e = in.speed_var(1);  fv = in.speed_var(2);
th_s = w0 * (t + e / (2 * pi * fv) * (1 - cos(2 * pi * fv * t)));     % integral of w0 (1 + e sin)
th_c = th_s * in.zs / (in.zs + in.zr);
th_r = th_s * in.zr / (in.zs + in.zr);
th_in = th_s * in.z2 / in.z1;
ld = 1;
if ~det, ld = 1 + in.var_load * randn; end

x = zeros(n, 1);
cr = in.crack;  sg = cr.width * 2 * pi / in.zs;
for i = 0:in.N - 1
    w = window(in, th_c, i);
    d = mod(th_r + cr.phi0 - 2 * pi * i / in.N + pi, 2 * pi) - pi;
    c = exp(-0.5 * (d / sg).^2);
    for h = 1:numel(in.A_pm)
        x = x + ld * w .* in.A_pm(h) .* (1 - cr.a * c) .* ...
            cos(h * in.zs * (th_r - 2 * pi * i / in.N) + in.ph_pm(h) + h * cr.beta * c);
    end
end
for h = 1:numel(in.A_fs)
    x = x + ld * in.A_fs(h) * cos(h * in.z1 * th_in + in.ph_fs(h));
end
x = x + in.A_shaft(1) * cos(th_in + in.ph_shaft(1)) + in.A_shaft(2) * cos(th_s + in.ph_shaft(2)) ...
      + in.A_shaft(3) * cos(th_c + in.ph_shaft(3));

sp = in.spall;
if sp.b > 0
    ph = in.k_bore * th_s / (2 * pi);                    % roller passes counted on the sun angle
    k = (ceil(ph(1)):floor(ph(end)))';
    if ~det, k = k + sp.slip * cumsum(randn(size(k))); end   % slip: each interval +-1% (random walk)
    tk = interp1(ph, t, k);
    tk = tk(~isnan(tk));
    thk_c = interp1(t, th_c, tk);  thk_r = interp1(t, th_r, tk);
    spin = -thk_r * in.zs / in.zp;                       % planet spin relative to the carrier
    amp = sp.b * window(in, thk_c, sp.planet) .* (1 + cos(spin)) / 2;
    wn = 2 * pi * sp.fn;  wd = wn * sqrt(1 - sp.zeta^2);
    m = round(sp.tmax * fs);
    for j = 1:numel(tk)
        i0 = ceil(tk(j) * fs) + 1;
        idx = (i0:min(n, i0 + m))';
        tau = t(idx) - tk(j);
        x(idx) = x(idx) + amp(j) * exp(-sp.zeta * wn * tau) .* sin(wd * tau);
    end
end
if ~det
    x = x + in.noise * randn(n, 1);
end
S = struct('t', t, 'x', x, 'th_s', th_s, 'fs', fs);
end

function w = window(in, th_c, i)
u = (1 + cos(th_c + 2 * pi * i / in.N - in.sensor_deg * pi / 180)) / 2;
w = in.w_floor + (1 - in.w_floor) * u.^2;
end
