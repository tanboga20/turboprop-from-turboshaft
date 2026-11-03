function md = torsion_modes(T, in, n_prop)
%TORSION_MODES  Torsional natural frequencies, energy shares and the DYN-02 margin check.
%   md = torsion_modes(T, in, n_prop)
%
%   Inputs
%     T        torsion_model output
%     in       torsion_inputs (orders, margin, steady range, PT speed)
%     n_prop   propeller speed at 100%                                [rpm]
%
%   Output struct md
%     f          natural frequencies of the elastic modes, lowest first  [Hz]
%     Phi        mode shapes, mass-normalised, one column per mode
%     share      modal strain energy share of each element, modes x elements [-]
%     main       name of the element with the largest share in each mode
%     check      rows [mode, order, frame (1 propeller, 2 PT), f_low, f_high,
%                margin] for every mode and order: f_low and f_high are the
%                order's frequency over the steady range [Hz]; margin is the
%                distance of the mode from that band over the band edge
%                (negative inside the band)                            [-]
%     ok         every mode below 3 x the highest excitation clears every
%                band by in.margin (DYN-02)
%
%   Generalised eigenproblem K phi = w^2 M phi; the rigid-body mode
%   (frequency near zero) is dropped. The strain energy of element e in
%   mode k is k_e (a_e' phi_k)^2 / 2.
%
%   Source: Phase 2 report, Section 2.3 ("Torsional modes"). Tested by
%   test_step23 (TC30, TC31).

[V, D] = eig(T.K, T.M);
w2 = diag(D);
[w2, o] = sort(w2);
V = V(:, o);
keep = w2 > 1e-6 * max(w2);
w2 = w2(keep);
V = V(:, keep);
for k = 1:size(V, 2)
    V(:, k) = V(:, k) / sqrt(V(:, k)' * T.M * V(:, k));
end
md.f = sqrt(w2) / (2 * pi);
md.Phi = V;
ne = numel(T.el);
E = zeros(numel(md.f), ne);
for e = 1:ne
    E(:, e) = T.el(e).k * (T.el(e).a' * V).^2 / 2;
end
md.share = E ./ sum(E, 2);
[~, im] = max(md.share, [], 2);
md.main = {T.el(im).name}';

% DYN-02: each mode against each order band over the steady range
n_lo = in.n_steady(1);  n_hi = in.n_steady(2);
check = [];
for k = 1:numel(md.f)
    for o = in.P_orders
        band = o * n_prop / 60 * [n_lo n_hi];
        check = [check; k, o, 1, band, margin_of(md.f(k), band)]; %#ok<AGROW>
    end
    for o = in.PT_orders
        band = o * in.n_PT / 60 * [n_lo n_hi];
        check = [check; k, o, 2, band, margin_of(md.f(k), band)]; %#ok<AGROW>
    end
end
md.check = check;
f_top = 3 * max(check(:, 5));
md.ok = all(check(md.f(check(:, 1)) < f_top, 6) >= in.margin);
end

function m = margin_of(f, band)
% Relative distance of f from the band; negative inside it
if f < band(1)
    m = (band(1) - f) / band(1);
elseif f > band(2)
    m = (f - band(2)) / band(2);
else
    m = -min(f - band(1), band(2) - f) / band(2);
end
end
