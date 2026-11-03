function Th = tl_thermal(in)
%TL_THERMAL  Thermal map of the RGB parts (E2): steady states and the cold-start transient (lumped, TBR).
%   Th = tl_thermal(in)   in = tl_inputs
%
%   Steady states from in.th.T; the LD-02 case temperatures from 15 min of
%   first-order lag (in.th.tau.case) from the MCT state towards the oil
%   minus in.th.dT_case. Cold-start transient: oil in from the -40 degC soak
%   to the jet-feed temperature at ground idle (step 3.2), then MCT with the
%   oil rising at the MCT heat over the oil and metal capacity up to
%   132 degC; each part follows its target (oil plus its MCT offset, or its
%   idle offset before take-off) with a first-order lag. The gears lead the
%   case: the backlash minimum of E3 falls in this transient.
%   Th.map: table of the states; Th.tr: transient (t [s] and a column per part).
%   Source: Phase 3 report, Section 3.8 (E2).

th = in.th;
P = th.parts;
T = th.T;
% LD-02: 15 min at 149 degC oil from the MCT state; parts with NaN follow their lag
i_mct = 4;  i_02 = 5;
for j = find(isnan(T(i_02, :)))
    tau = taus(P{j}, th.tau);
    Tt = 149 - th.dT_case - (P{j} == "P111") * 5;
    T(i_02, j) = Tt + (T(i_mct, j) - Tt) * exp(-15 * 60 / tau);
end
Th.T = T;
Th.map = array2table(T, 'VariableNames', P, 'RowNames', th.states);
% cold-start transient
c = th.cold;
dt = 1;
t = (0:dt:c.t_end)';
oil = zeros(size(t));
for k = 1:numel(t)
    if t(k) <= c.t_ok
        oil(k) = c.T0 + (c.T_ok - c.T0) * t(k) / c.t_ok;
    else
        oil(k) = min(c.T_ok + c.rate_mct * (t(k) - c.t_ok), c.T_oil_max);
    end
end
off_idle = T(2, :) - T(2, 1);  off_idle(2:6) = c.dT_gear_idle;   % small gear offsets at a cold idle
off_mct = T(i_mct, :) - T(i_mct, 1);
X = zeros(numel(t), numel(P));
X(1, :) = c.T0;
X(:, 1) = oil;
for k = 2:numel(t)
    if t(k) <= c.t_ok, off = off_idle; else, off = off_mct; end
    for j = 2:numel(P)
        tgt = max(oil(k) + off(j), c.T0);           % no part below the soak (the air around it is at T0)
        X(k, j) = X(k - 1, j) + dt / taus(P{j}, th.tau) * (tgt - X(k - 1, j));
    end
end
Th.tr = array2table([t X], 'VariableNames', [{'t'}, P]);
end

function tau = taus(p, ta)
switch p
    case {'pinion', 'gear2', 'sun', 'planet', 'ring'}, tau = ta.gear;
    case {'brg_in', 'brg_out'}, tau = ta.brg;
    case {'carrier', 'tube'}, tau = ta.carrier;
    case 'liner', tau = ta.liner;
    case {'case_p', 'case_f'}, tau = ta.case;
    case 'P111', tau = ta.P111;
    otherwise, tau = 1;
end
end
