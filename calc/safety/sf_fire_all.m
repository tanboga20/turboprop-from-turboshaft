function Fz = sf_fire_all(in)
%SF_FIRE_ALL  Fire assessment of the oil-wetted A357 walls (D5, SAF-05, CS-E 130, 14 CFR 33.17).
%   Fz = sf_fire_all(in)   in = sf_inputs
%
%   Time to zero oil flow after a fire warning (F1.4). Per wall (in.fire.walls), with the flame at its upper
%   tolerance and the hot sink: the oil-side h of the drain film at the lowest flow (Nusselt film, h = 1.88 k /
%   delta) or the fixed no-film value; 5 min with that h, then the zero-flow phase restarted from the end-of-flow
%   profile. Criterion for 5 min with flow: the flame side stays below the solidus and the hot yield at the highest
%   mean temperature carries the operating stress of the wall (time-dependent allowable: a 1/2 h table for 5 min).
%   Reported: the highest flame-side, mean and oil-side temperatures (the oil side against the flash point and the
%   auto-ignition temperature), the film temperature rise over the footprint, the thermal stress of a locally heated
%   zone (E alpha dT / 2, secondary, not added), the smallest passing h, and in the zero-flow phase the times to the
%   loss of strength and to the solidus. Temperatures at or above the solidus are reported as molten (NaN).
%   Source: Phase 3 report, Section 3.7 (D5).

fw = in.fire;  z = in.fire_zone;  o = fw.oil;
Fz.t_zero = z.t_detect + z.t_logic + z.t_feather + z.t_rundown;
Fz.level = "fire resistant";
if Fz.t_zero > fw.t_flow, Fz.level = "fireproof"; end
Q = fw.Q_rgb * fw.n_min / 6e4;                          % m3/s, lowest RGB flow
sy = @(T) interp1(fw.sy_T(:, 1), fw.sy_T(:, 2), min(T, fw.sy_T(end, 1)));
rows = {};
for w = 1:numel(fw.walls)
    wl = fw.walls(w);
    if isnan(wl.h_fixed)
        G = o.rho * Q * wl.share / (2 * pi * wl.ri * 1e-3);           % kg/(m s) per unit width
        delta = (3 * o.nu * G / (o.rho * 9.81))^(1 / 3);
        h = 1.88 * o.k / delta;
    else
        G = 0;  delta = NaN;  h = wl.h_fixed;
    end
    W = sf_fire(fw, wl, h, fw.t_flow);
    Th = max(W.T_hot);  Tm = max(W.T_mean);  Tc = max(W.T_cold);
    if ~isinf(W.t_solidus), Th = fw.T_solidus; end      % reached the solidus: molten
    ok = isinf(W.t_solidus) && sy(Tm) >= wl.s_req;
    dT_film = NaN;
    if G > 0, dT_film = h * (Tc - fw.T_sink) * o.L_fp / (G * o.cp); end
    s_th = fw.E * fw.alpha * (Tm - fw.T_sink) / 2;
    % zero-flow phase from the end-of-flow profile (only when the wall survived the flow phase)
    t_loss = NaN;  t_sol2 = NaN;
    if isinf(W.t_solidus)
        W2 = sf_fire(fw, wl, fw.h_noflow, fw.t_after, struct('r', W.r, 'T', W.T_last));
        k = find(sy(W2.T_mean) < wl.s_req, 1);
        if ~isempty(k), t_loss = W2.t(k); end
        t_sol2 = W2.t_solidus;
    else
        k = find(sy(W.T_mean) < wl.s_req, 1);
        if ~isempty(k), t_loss = W.t(k) - fw.t_flow; end    % negative: lost before the flow stops
    end
    % smallest passing h for the 5 min with flow
    g = @(hh) margin(fw, wl, hh, sy);
    if g(1) >= 0
        h_min = 1;
    elseif g(2e4) < 0
        h_min = Inf;
    else
        h_min = fzero(g, [1 2e4]);
    end
    Wm = sf_fire(fw, wl, max(h_min, 1), fw.t_flow);
    rows(end + 1, :) = {string(wl.name), string(wl.name_tr), wl.t, wl.zone, wl.s_req, wl.share, h, ...
        molten(Th, fw), molten(Tm, fw), Tc, dT_film, sy(Tm), s_th, ok, W.t_solidus, h_min, max(Wm.T_cold), ...
        max(Wm.T_cold) < o.flash, t_loss, t_sol2}; %#ok<AGROW>
    Fz.hist{w} = W;
end
Fz.T = cell2table(rows, 'VariableNames', {'wall', 'wall_tr', 't_mm', 'in_fire_zone', 's_operating_MPa', ...
    'flow_share', 'h_basis_W_m2K', 'T_flame_side_max', 'T_mean_max', 'T_oil_side_max', 'film_rise_K', ...
    'hot_yield_MPa', 's_thermal_secondary_MPa', 'meets_5min', 't_to_solidus_with_flow_s', 'h_min_W_m2K', ...
    'T_oil_side_at_h_min', 'below_flash_at_h_min', 't_strength_lost_after_flow_s', 't_solidus_after_flow_s'});
Fz.Q_min = Q * 6e4;
% the P101 / F201 joint (F3): 2-D, with and without the partition; seals and bolts at the partition case
jn = fw.joint;
rows = {};
for part = [true false]
    J = sf_fire_joint(in, part);
    s_seat = sy(J.T_seat_P101);  s_ins = sy(J.T_insert_F201);
    F_M = jn.p_seat * jn.A_seat;
    F_res = min([F_M, s_seat * jn.A_seat, F_M * s_ins / jn.s_ins]);           % the seat and the insert relax to hot yield
    F_res_w = min([F_M, s_seat * jn.A_washer, F_M * s_ins / jn.s_ins]);       % with the steel washer (3.9 option)
    clamp = F_res - (1 - jn.Phi) * jn.F_A;
    rows(end + 1, :) = {part, J.T_seat_P101, J.T_insert_F201, J.T_face_F201, J.T_oring_F201, J.T_oring_P101, ...
        J.T_P101_max, J.T_F201_max, max(J.T_oring_F201, J.T_oring_P101) <= jn.T_oring, s_seat, s_ins, F_M, F_res, ...
        F_res_w, (1 - jn.Phi) * jn.F_A, clamp, clamp > 0}; %#ok<AGROW>
    if part, Fz.joint = J; end
end
Fz.J = cell2table(rows, 'VariableNames', {'partition', 'T_seat_P101', 'T_insert_F201', 'T_face_F201', ...
    'T_oring_F201', 'T_oring_P101', 'T_P101_max', 'T_F201_max', 'oring_within_rating', 'hot_yield_seat_MPa', ...
    'hot_yield_insert_MPa', 'preload_N', 'residual_preload_N', 'residual_preload_washer_N', 'operating_load_share_N', ...
    'residual_clamp_N', 'clamp_holds'});
end

function T = molten(T, fw)
% at or above the solidus: molten, not a temperature
if T >= fw.T_solidus, T = NaN; end
end

function m = margin(fw, wl, h, sy)
% hot yield at the highest mean temperature minus the operating stress over 5 min; the solidus counts as no strength
W = sf_fire(fw, wl, h, fw.t_flow);
m = sy(max(W.T_mean)) - wl.s_req;
if ~isinf(W.t_solidus), m = -wl.s_req - (fw.t_flow - W.t_solidus); end
end
