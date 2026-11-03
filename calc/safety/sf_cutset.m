function P = sf_cutset(e, T, uniform)
%SF_CUTSET  Mean rate per hour of one minimal cut set over the inspection interval T.
%   P = sf_cutset(e, T, uniform)   e: struct array of the events of the cut set (fields type, rate, qd, beta)
%
%   The cut set holds exactly one per-hour event ('active' with a constant rate, or 'weibull' with the mean rate
%   H(T) / T and a hazard rising as t^(beta-1), renewed at T), up to two 'latent' events (failed with probability
%   lambda t + q_d at the time t since their common inspection) and any number of 'demand' events (failing with
%   probability q_d when the cut set is demanded). The latent product is averaged with the weight of the
%   per-hour hazard, beta t^(beta-1) / T^beta (uniform for a constant rate), whose moments are T^n beta / (beta + n):
%   one latent event gives lambda T / 2 + q_d (constant rate) or lambda T beta / (beta + 1) + q_d (Weibull); two
%   give lambda_1 lambda_2 T^2 / 3 + (lambda_1 q_d2 + lambda_2 q_d1) T / 2 + q_d1 q_d2 (constant rate). uniform:
%   true takes the uniform weight also for a Weibull event (exposure not tied to its renewal, e.g. the
%   never-inspected case over the life).
%   Source: Phase 3 report, Section 3.7 (D1).

types = {e.type};
act = ismember(types, {'active', 'weibull'});
lat = strcmp(types, 'latent');
dem = strcmp(types, 'demand');
assert(sum(act) == 1, 'sf_cutset: a cut set needs exactly one per-hour event');
assert(sum(lat) <= 2 && all(act | lat | dem), 'sf_cutset: up to two latent events and demand events only');
a = e(act);  L = e(lat);  D = e(dem);
beta = 1;
if strcmp(a.type, 'weibull') && ~uniform, beta = a.beta; end
m = @(n) T^n * beta / (beta + n);
switch numel(L)
    case 0, Eq = 1;
    case 1, Eq = L.rate * m(1) + L.qd;
    case 2, Eq = L(1).rate * L(2).rate * m(2) + (L(1).rate * L(2).qd + L(2).rate * L(1).qd) * m(1) + L(1).qd * L(2).qd;
end
P = a.rate * Eq * prod([D.qd]);
end
