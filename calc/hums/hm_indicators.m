function I = hm_indicators(S, in, var_ref)
%HM_INDICATORS  Condition indicators of one record: TSA of the sun, FM4, NA4, sideband energy, envelope.
%   I = hm_indicators(S, in)            NA4 normalised by the record's own residual variance
%   I = hm_indicators(S, in, var_ref)   NA4 normalised by the mean residual variance of the baseline
%
%   S: a record from hm_synth (t, x, th_s); in: hm_inputs. Steps:
%    - tachometer: once-per-revolution pulse times of the intermediate shaft (sun) from th_s
%    - TSA over one revolution of the sun relative to the carrier ((zs + zr) / zr sun revolutions,
%      in.tsa_pts points); in its order spectrum the planetary mesh is order zs (45)
%    - regular signal: shaft orders 1 and 2, the mesh harmonics h zs and their first sidebands
%      h zs +- 1; difference signal d = TSA - regular; FM4 = n sum (d - mean)^4 / (sum (d - mean)^2)^2
%    - residual signal r = TSA - (orders 1, 2 and h zs); NA4 = mean((r - mean)^4) / var_ref^2
%    - sideband energy: sum of the amplitudes of orders zs +- 1..n_side over the rms of the TSA (with
%      sequential planet phasing, 45 mod 4 = 1, the four planets cancel at order zs itself, so the
%      usual ratio to the mesh line is unstable; the rms is the sideband level factor's normaliser)
%    - envelope: band-pass in.band by zeroing the FFT outside it (positive frequencies doubled, i.e.
%      the analytic signal), |.| minus its mean, one-sided amplitude spectrum; ENV = largest line
%      within 1.5% of the planet bore defect frequency over the median of the spectrum from 0.5 to
%      1.5 times that frequency
%   Output I: tsa, nrev, FM4, NA4, var_r (residual variance), SER, ENV, f_bore, env spectrum (fe, E).
%
%   Source: Phase 3 report, Section 3.10. Tested by test_step310 (TC120).

t = S.t;  x = S.x;
k = (ceil(S.th_s(1) / (2 * pi)):floor(S.th_s(end) / (2 * pi)))';
tach = interp1(S.th_s, t, 2 * pi * k);
period = (in.zs + in.zr) / in.zr;
[a, nrev] = hm_tsa(t, x, tach, period, in.tsa_pts);
I.tsa = a;  I.nrev = nrev;

m = numel(a);
A = fft(a);
ords = (0:m - 1)';
ords(ords > m / 2) = ords(ords > m / 2) - m;          % signed order of each bin
mesh = in.zs * (1:floor((m / 2 - 1) / in.zs));
reg = unique([1 2 mesh mesh - 1 mesh + 1]);
res = unique([1 2 mesh]);
keep_reg = ismember(abs(ords), reg) | ords == 0;
keep_res = ismember(abs(ords), res) | ords == 0;
d = real(ifft(A .* ~keep_reg));
r = real(ifft(A .* ~keep_res));
d = d - mean(d);  r = r - mean(r);
I.FM4 = m * sum(d.^4) / sum(d.^2)^2;
I.var_r = mean(r.^2);
if nargin < 3 || isempty(var_ref), var_ref = I.var_r; end
I.NA4 = mean(r.^4) / var_ref^2;
amp = abs(A) / m;
z = in.zs;
I.SER = sum(amp(z + 1 + [-(1:in.n_side) (1:in.n_side)])) / sqrt(mean((a - mean(a)).^2));

n = numel(x);
X = fft(x);
f = (0:n - 1)' * S.fs / n;
H = zeros(n, 1);
H(f >= in.band(1) & f <= in.band(2) & (0:n - 1)' < n / 2) = 2;
env = abs(ifft(X .* H));
env = env - mean(env);
E = abs(fft(env)) / n * 2;
nh = floor(n / 2);
fe = f(1:nh);  E = E(1:nh);
f_b = in.k_bore * mean(diff(tach)) .^ -1;              % defect frequency at the mean sun speed
pk = max(E(fe >= 0.985 * f_b & fe <= 1.015 * f_b));
fl = median(E(fe >= 0.5 * f_b & fe <= 1.5 * f_b));
I.ENV = pk / fl;
I.f_bore = f_b;
I.fe = fe;  I.E = E;
end
