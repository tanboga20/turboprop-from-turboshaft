function [a, nrev] = hm_tsa(t, x, tach, period, npts)
%HM_TSA  Time-synchronous average by angular resampling on a once-per-revolution tachometer.
%   [a, nrev] = hm_tsa(t, x, tach, period, npts)
%
%   t, x: the sampled signal; tach: the times of the once-per-revolution pulses of the reference
%   shaft (here the intermediate shaft, i.e. the sun); period: the averaging period in revolutions
%   of that shaft (the sun relative to the carrier turns once every (zs + zr) / zr sun revolutions);
%   npts: points per period. The shaft angle at each sample is interpolated linearly between the
%   pulses, the signal is resampled at npts equal angle steps per period over the whole number of
%   periods the pulses cover, and the periods are averaged. a: the average (npts x 1); nrev: the
%   number of periods averaged.
%
%   Source: Phase 3 report, Section 3.10. Tested by test_step310 (TC120).

tach = tach(:);
k = (0:numel(tach) - 1)';
in = t >= tach(1) & t <= tach(end);
th = interp1(tach, k, t(in));                  % shaft angle in revolutions
nrev = floor((th(end) - th(1)) / period);
g = th(1) + (0:nrev * npts - 1)' * period / npts;
xr = interp1(th, x(in), g);
a = mean(reshape(xr, npts, nrev), 2);
end
