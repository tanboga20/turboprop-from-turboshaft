function F = tl_fits(in, Th)
%TL_FITS  Fits at temperature (E4): bearing rings, liners, planet pins, the ring gear seat.
%   F = tl_fits(in, Th)   in = tl_inputs, Th = tl_thermal(in)
%
%   Bearing rings: ISO 286 shaft and housing classes against the bearing bore
%   and outer diameter tolerances (ISO 492 class P5 for aerospace bearings,
%   TBR); the radial internal clearance after mounting and at temperature:
%   c = c0 - k_ring (inner-ring interference) + 2 (change of the outer
%   raceway radius from 20 degC by the liner in the A357 boss, Lame; the liners
%   are finish-bored after shrinking) - alpha (T_in - T_out) D_pw (the inner
%   ring hotter).
%   Liners: radial interference in the A357 boss (step 3.5) at each state:
%   pressure, A357 hoop stress at the bore against sigma_y / 1.25.
%   Planet pins: H6 / s6 press fit of the hollow pin in the carrier plate:
%   interference, pressure, plate hoop stress and the friction holding force.
%   Ring gear seat T6 / h5: radial interference at each state (closed at MCT),
%   cold-soak hoop stress against sigma_y / 1.25, the part-power Goodman of the
%   case shell at the 50% cruise with the fit hoop stress as mean (step 3.6
%   shell parts), assembly by heating the case against the A357-T6 ageing limit.
%   Source: Phase 3 report, Section 3.8 (E4).

cte = in.cte;  T0 = in.T_ref;  st = in.th.states;  ns = numel(st);
% 1. bearing rings and operating clearance
rows = {};
for b = 1:numel(in.brg)
    br = in.brg(b);
    [slo, shi] = tl_iso286(br.d, br.shaft);
    [hlo, hhi] = tl_iso286(br.D, br.housing);
    bore = [p5(br.d) 0];  od = [p5(br.D) 0];          % ISO 492 class P5 [lower upper] um, TBR
    i_in = [slo - bore(2), shi - bore(1)];             % inner-ring interference [min max] um (+ = tight)
    i_out = [od(1) - hhi, od(2) - hlo];                % outer ring in the liner [min max] um (+ = tight)
    Dpw = (br.d + br.D) / 2;
    for s = 1:ns
        T = Th.map(st{s}, :);
        if contains(br.name, 'NU1024'), lin = in.liner(1); case_ = 'case_p'; else, lin = in.liner(2 + contains(br.name, '2210')); case_ = 'case_f'; end
        if startsWith(br.name, 'QJ'), u_out = 0; else, u_out = outer_raceway(in, lin, br, T.liner, T.(case_)); end
        grad = cte.steel * (T.brg_in - T.brg_out) * Dpw * 1000;          % um
        if startsWith(br.name, 'QJ')                   % radially free: report the housing clearance instead
            c_min = -i_out(2);  c_max = -i_out(1);
        else
            c_min = 1000 * br.c0(1) - in.k_ring * max(i_in(2), 0) + 2 * 1000 * u_out - grad;
            c_max = 1000 * br.c0(2) - in.k_ring * max(i_in(1), 0) + 2 * 1000 * u_out - grad;
        end
        rows(end + 1, :) = {string(br.name), string(st{s}), string(br.shaft), slo, shi, string(br.housing), hlo, hhi, ...
                            i_in(1), i_in(2), i_out(1), i_out(2), 1000 * u_out, grad, c_min, c_max}; %#ok<AGROW>
    end
end
F.brg = cell2table(rows, 'VariableNames', {'bearing', 'state', 'shaft_class', 'shaft_lo_um', 'shaft_hi_um', ...
    'housing_class', 'housing_lo_um', 'housing_hi_um', 'inner_int_min_um', 'inner_int_max_um', 'outer_int_min_um', ...
    'outer_int_max_um', 'outer_raceway_change_um', 'gradient_loss_um', 'clearance_min_um', 'clearance_max_um'});
% clearance_* : radial internal clearance in operation (roller bearings); radial clearance in the housing (QJ, radially free)
k = ~startsWith(F.brg.bearing, 'QJ');
F.clear_min = min(F.brg.clearance_min_um(k));
% roller bearings over the cold-start transient (inner ring warmer, the cold A357 boss squeezing the liner)
X = Th.tr;
F.clear_tr = struct();
for b = find(~startsWith({in.brg.name}, 'QJ'))
    br = in.brg(b);
    [slo, shi] = tl_iso286(br.d, br.shaft);
    i_max = shi - p5(br.d);
    if contains(br.name, 'NU1024'), lin = in.liner(1); case_ = 'case_p'; else, lin = in.liner(2 + contains(br.name, '2210')); case_ = 'case_f'; end
    c = zeros(numel(X.t), 1);
    for k2 = 1:numel(X.t)
        u = outer_raceway(in, lin, br, X.liner(k2), X.(case_)(k2));
        c(k2) = 1000 * br.c0(1) - in.k_ring * i_max + 2 * 1000 * u - cte.steel * (X.brg_in(k2) - X.brg_out(k2)) * (br.d + br.D) / 2 * 1000;
    end
    [cm, im] = min(c);
    F.clear_tr.(matlab.lang.makeValidName(strtok(br.name))) = [cm, X.t(im) / 60];   % [um, min]
end
% 2. liners in the A357 bosses
rows = {};
for l = 1:numel(in.liner)
    ln = in.liner(l);
    for s = 1:ns
        T = Th.map(st{s}, :);
        for j = 1:2
            d = ln.delta(j) + (ln.r_i + ln.t) * (cte.steel * (T.liner - T0) - cte.A357 * (T.(ln.case) - T0));
            R = tl_lame(ln.r_i, ln.r_i + ln.t, ln.r_boss, in.E.steel, in.nu.steel, in.E.A357, in.nu.A357, d);
            if j == 1, dmin = d; pmin = R.p; else, dmax = d; pmax = R.p; hoop = R.hoop_o; end
        end
        rows(end + 1, :) = {string(ln.name), string(st{s}), 1000 * dmin, 1000 * dmax, pmin, pmax, hoop, ...
                            in.seat.sy / in.seat.k_cast}; %#ok<AGROW>
    end
end
F.liner = cell2table(rows, 'VariableNames', {'liner', 'state', 'delta_min_um', 'delta_max_um', 'p_min_MPa', ...
    'p_max_MPa', 'A357_hoop_max_MPa', 'allow_MPa'});
% 3. planet pins
pn = in.pin;
[blo, bhi] = tl_iso286(pn.d, pn.fit{1});
[plo, phi] = tl_iso286(pn.d, pn.fit{2});
dI = [plo - bhi, phi - blo] / 2 / 1000;                       % radial interference [min max] mm
for j = 1:2
    R = tl_lame(pn.bore / 2, pn.d / 2, pn.r_out, in.E.steel, in.nu.steel, in.E.steel, in.nu.steel, dI(j));
    P(j) = R; %#ok<AGROW>
end
dT = (cte.M50 - cte.steel) * (pn.d / 2) * ([-40 157] - T0);     % change with temperature (pin M50NiL, plate 4340)
F.pin = struct('fit', sprintf('%s / %s', pn.fit{:}), 'bore', [blo bhi], 'pin', [plo phi], 'delta_um', 1000 * dI, ...
               'p', [P.p], 'hoop_plate', [P.hoop_o], 'F_hold', pn.mu * [P.p] * pi * pn.d * pn.L, 'F_ax', pn.F_ax, ...
               'dT_change_um', 1000 * dT);
% 4. ring gear seat
se = in.seat;
[rlo, rhi] = tl_iso286(2 * se.r, se.cls_ring);
blo = se.bore_dev(1);  bhi = se.bore_dev(2);                   % limit dimensions of the case bore [um]
d20 = [(rlo - bhi), (rhi - blo)] / 2 / 1000;                   % radial interference at 20 degC [min max] mm
rows = zeros(ns, 6);
for s = 1:ns
    T = Th.map(st{s}, :);
    dd = se.r * (cte.steel * (T.ring - T0) - cte.A357 * (T.case_p - T0));
    Rn = tl_lame(se.r_ring_in, se.r, se.r + se.t_case, in.E.steel, in.nu.steel, in.E.A357, in.nu.A357, d20(1) + dd);
    Rx = tl_lame(se.r_ring_in, se.r, se.r + se.t_case, in.E.steel, in.nu.steel, in.E.A357, in.nu.A357, d20(2) + dd);
    rows(s, :) = [1000 * (d20(1) + dd), 1000 * (d20(2) + dd), Rn.p, Rx.p, Rn.hoop_o, Rx.hoop_o];
end
F.seat = array2table(rows, 'VariableNames', {'delta_min_um', 'delta_max_um', 'p_min_MPa', 'p_max_MPa', 'hoop_min_MPa', ...
                     'hoop_max_MPa'}, 'RowNames', st);
F.seat_cls = sprintf('bore %+d / %+d um (limits; nearest ISO class %s) / ring %s', bhi, blo, se.cls_bore, se.cls_ring);
F.seat_d20 = 1000 * d20;
i_mct = strcmp(st, 'MCT, oil 132');  i_cold = strcmp(st, 'cold soak');  i_cr = strcmp(st, 'cruise 50%');
F.seat_mct_min = rows(i_mct, 1);
F.seat_cold_hoop = rows(i_cold, 6);
F.seat_allow = se.sy / se.k_cast;
% the MCT state needs: interference that the 20 degC fit must hold at least
T = Th.map(st{i_mct}, :);
F.seat_need = 1000 * (se.c_min - se.r * (cte.steel * (T.ring - T0) - cte.A357 * (T.case_p - T0)));
T = Th.map(st{strcmp(st, 'LD-02, oil 149, 15 min')}, :);
F.seat_need_02 = 1000 * (se.c_min - se.r * (cte.steel * (T.ring - T0) - cte.A357 * (T.case_p - T0)));
F.seat_min_all = min(rows(:, 1));
% part-power fatigue at the cruise state: step 3.6 shell parts at 1x (mesh, planet pass, steady), mesh and pass
% scaled by the torque share, the steady part by the torque share, plus the fit hoop stress as a mean
sf = in.seat_fatigue;
sp = [6.025 11.85 9.777];                                       % MPa (3.6, slide bracket, shell, 1x)
q = sf.torque_share;
for j = 1:2
    sm = q * sp(3) + rows(i_cr, 4 + j);
    G(j) = 1 / (se.k_cast * ((q * (sp(1) + sp(2)) + sf.sa_1P) / sf.se + sm / sf.su)); %#ok<AGROW>
end
F.seat_goodman_cruise = G;                                        % [min-fit, max-fit]
F.seat_goodman_mct_nofit = 1 / (se.k_cast * ((sp(1) + sp(2) + sf.sa_1P) / sf.se + sp(3) / sf.su));
% assembly: heat the case so the bore clears the largest interference plus the assembly clearance
F.T_assy = T0 + (d20(2) + se.c_assy) / (cte.A357 * se.r);
F.T_age = se.T_age;
end

function v = p5(d)
% lower deviation of the mean bore or outside diameter of a class P5 bearing [um] (ISO 492, TBR)
lim = [50 80 120 180 250 315];
dev = [6 7 8 10 11 13];
v = -dev(find(d <= lim, 1));
end

function u = outer_raceway(in, lin, br, T_liner, T_case)
% change of the outer raceway radius from its 20 degC size [mm] (negative: inward): the liners are finish-bored
% after they are shrunk into the casting (drawing note), so only the change of the boss pressure from 20 degC
% reaches the bearing; the outer ring and the liner act as one steel cylinder (raceway radius to the liner OD)
cte = in.cte;
r_rw = br.D / 2 - 0.4 * (br.D - br.d) / 2;                      % outer raceway radius (ring wall 40% of the section)
b = lin.r_i + lin.t;
d = @(TL, TC) lin.delta(1) + b * (cte.steel * (TL - in.T_ref) - cte.A357 * (TC - in.T_ref));
R = tl_lame(r_rw, b, lin.r_boss, in.E.steel, in.nu.steel, in.E.A357, in.nu.A357, d(T_liner, T_case));
R0 = tl_lame(r_rw, b, lin.r_boss, in.E.steel, in.nu.steel, in.E.A357, in.nu.A357, d(in.T_ref, in.T_ref));
u = R.u_a - R0.u_a;
end
