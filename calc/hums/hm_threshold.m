function T = hm_threshold(x, pfa)
%HM_THRESHOLD  Statistical alert thresholds of a condition indicator from a healthy population.
%   T = hm_threshold(x, pfa)
%
%   x: indicator values of the healthy records (one operating condition); pfa: false alarm
%   probabilities per record, e.g. [1e-3 1e-6] for caution and alarm. The indicators are positive
%   and skewed, so ln(x) is taken as normal: mu and sigma (n - 1) of ln(x), z = sqrt(2) erfcinv(2 pfa)
%   (one-sided), threshold = exp(mu + z sigma). The engine test (3.11) fills x for each torque and
%   speed bin with at least 30 records; until then the thresholds come from the synthetic baseline.
%   Output T: mu, sigma (of ln x), z, thr (one per pfa), n.
%
%   Source: Phase 3 report, Section 3.10. Tested by test_step310 (TC121).

y = log(x(:));
T.n = numel(y);
T.mu = mean(y);
T.sigma = std(y);
T.z = sqrt(2) * erfcinv(2 * pfa);
T.thr = exp(T.mu + T.z * T.sigma);
end
