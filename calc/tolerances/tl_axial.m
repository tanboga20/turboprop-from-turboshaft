function A = tl_axial(in, Th)
%TL_AXIAL  Axial stack-ups (E3c): catcher-lip gap and the retention tube anchor clearance with temperature.
%   A = tl_axial(in, Th)   in = tl_inputs, Th = tl_thermal(in)
%
%   Catcher lip: the gap between the shaft collar and the lip in the nose
%   cover, g = g0 + alpha_Ti dT_P111 L_cover - alpha_steel dT_shaft L_shaft,
%   must stay above the QJ1024 axial play plus the QJ and P111 deflections at
%   the 20 kN limit thrust in every state and in the cold-start transient
%   (never touching in service); the largest travel before the lip catches
%   is g_max + play_max + deflections.
%   Retention tube: the clearance at its hub anchor closes by the difference
%   of the steel shaft and titanium tube growth over the tube length and by
%   the stretch of the shaft under the limit pull (F L / (E A)); it must stay
%   open in service (the standby path unloaded); the largest travel before
%   the tube takes the propeller is c_max plus the opening at that state.
%   A.T: table per state; A.tr: minima over the transient. Lengths in mm.
%   Source: Phase 3 report, Section 3.8 (E3c).

ax = in.ax;  cte = in.cte;  T0 = in.T_ref;
lip = @(T_cov, T_sh, g0) g0 + cte.Ti * (T_cov - T0) * ax.L_cover - cte.steel * (T_sh - T0) * ax.L_shaft;
defl = ax.qj_defl + ax.p111_defl;
stretch = ax.F_thr * ax.L_tube / (in.E.steel * ax.A_shaft);
tube = @(T_sh, T_tu, c0) c0 - (cte.steel * (T_sh - T0) - cte.Ti * (T_tu - T0)) * ax.L_tube;
st = in.th.states;
r = zeros(numel(st), 6);
for s = 1:numel(st)
    T = Th.map(st{s}, :);
    gmin = lip(T.P111, T.carrier, ax.lip_gap(1));  gmax = lip(T.P111, T.carrier, ax.lip_gap(2));
    cmin = tube(T.carrier, T.tube, ax.tube_gap(1)) - stretch;  cmax = tube(T.carrier, T.tube, ax.tube_gap(2));
    r(s, :) = [gmin, gmin - ax.qj_play(2) - defl, gmax + ax.qj_play(2) + defl, cmin, cmax + stretch, ...
               (cte.steel * (T.carrier - T0) - cte.Ti * (T.tube - T0)) * ax.L_tube];
end
A.T = array2table(r, 'VariableNames', {'lip_gap_min', 'lip_margin_min', 'lip_catch_travel_max', 'tube_gap_min', ...
                  'tube_catch_travel_max', 'tube_closing'}, 'RowNames', st);
X = Th.tr;
g_tr = lip(X.P111, X.carrier, ax.lip_gap(1)) - ax.qj_play(2) - defl;
c_tr = tube(X.carrier, X.tube, ax.tube_gap(1)) - stretch;
A.tr = struct('lip_margin_min', min(g_tr), 'tube_gap_min', min(c_tr));
A.stretch = stretch;
A.min_lip = min([r(:, 2); A.tr.lip_margin_min]);
A.min_tube = min([r(:, 4); A.tr.tube_gap_min]);
A.max_lip_travel = max(r(:, 3));
A.max_tube_travel = max(r(:, 5));
A.planet_float = ax.planet_float;  A.sun_float = ax.sun_float;
end
