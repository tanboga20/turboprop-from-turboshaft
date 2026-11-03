function R = as_angles(in, G, Lfs, Lcov)
%AS_ANGLES  Angular positions of the accessory shafts around the RGB.
%   R = as_angles(in, G, Lfs, Lcov)
%
%   in = as_inputs, G = as_geom; Lfs, Lcov: axial lengths of the
%   first-stage case and of the accessory cover [mm] (for the mass proxy).
%   Three angles are chosen: the generator shaft on the first-stage gear
%   (theta_g, at a_gen from the propeller axis), the OSG gear around the
%   generator shaft (theta_o, the direction from the generator axis, at
%   a_osg) and the PCU gear around the propeller axis (theta_p, at a_pcu).
%   Rules (each as a margin >= 0, mm):
%     gear tips inside the first-stage case clear each other (gap_gear);
%     the generator cartridge bore and the PT bearing bore leave a ligament;
%     the OSG unit on the propeller-side face clears the planetary case
%     flange; on the engine side the generator unit clears the accessory
%     cover and the PCU unit, every unit and the cover clear the tunnel
%     keep-out r_ker about the PT axis, and a unit longer than L_free clears
%     the exhaust collector R_exh;
%     every pad lies above the horizontal through the propeller axis
%     (MNT-02 access from the upper cowl, away from the oil sump at the
%     bottom of the first-stage case; TBR with the nacelle).
%   Among the feasible sets the lightest case and cover win (mass proxy:
%   wall area of the outlines times the wall thickness, A357).
%   Output R: theta_g, theta_o, theta_p [deg], positions Gp, Op, Pp, PT,
%   margin table R.margin (name, value), mass proxies, the feasible range
%   of theta_g and its sensitivity to R_exh when L_free is too short.
%   Source: Phase 3 report, Section 3.1 ("Accessory positions").

st = in.ang_step;
tg = 0:st:180;
to = 0:5:355;
tp = 0:st:180;
PT = [0, -G.a_s1];
gp = in.gap_gear;  pk = in.gap_pack;
rbp = G.brg('NU2209');  rbp = rbp(2) / 2;
rg = G.r_unit('generator');  ro = G.r_unit('OSG');  rp = G.r_unit('PCU');
Lg = G.L_unit('generator');
best = struct('m', inf);
for i = 1:numel(tg)
    Gp = G.a_gen * [cosd(tg(i)) sind(tg(i))];
    mg = gen_margins(Gp);
    if min([mg{:, 2}]) < 0, continue, end
    % OSG direction: lightest feasible first-stage case for this generator position
    bo = struct('m', inf);
    for j = 1:numel(to)
        Op = Gp + G.a_osg * [cosd(to(j)) sind(to(j))];
        mo = osg_margins(Op);
        if min([mo{:, 2}]) < 0, continue, end
        Hf = as_hull(fs_circles(Gp, Op));
        m = shell_mass(Hf, Lfs);
        if m < bo.m, bo = struct('m', m, 'to', to(j), 'Op', Op, 'mo', {mo}, 'Hf', Hf); end
    end
    if isinf(bo.m), continue, end
    for k = 1:numel(tp)
        Pp = G.a_pcu * [cosd(tp(k)) sind(tp(k))];
        mp = pcu_margins(Gp, Pp);
        if min([mp{:, 2}]) < 0, continue, end
        Hc = as_hull(cov_circles(Pp));
        m = bo.m + shell_mass(Hc, Lcov);
        if m < best.m - 1e-9
            best = struct('m', m, 'm_fs', bo.m, 'm_cov', m - bo.m, 'tg', tg(i), 'to', bo.to, 'tp', tp(k), ...
                          'Gp', Gp, 'Op', bo.Op, 'Pp', Pp, 'Hf', bo.Hf, 'Hc', Hc, ...
                          'margin', {[mg; bo.mo; mp]});
        end
    end
end
assert(~isinf(best.m), 'as_angles: no feasible accessory positions');
R = best;
R.theta_g = best.tg;  R.theta_o = best.to;  R.theta_p = best.tp;
R.PT = PT;
% feasible generator angles (with some OSG and PCU position) and their sensitivity to the collector
R.tg_feasible = feasible_tg(in.R_exh, in.L_free);
R.sens = struct('R_exh', [150 200 250 300], 'tg_range', []);
for r = R.sens.R_exh
    R.sens.tg_range(end + 1, :) = minmax_or_nan(feasible_tg(r, 0));   % L_free 0: generator beside the collector
end

    function c = fs_circles(Gp, Op)
        c = [0 0 G.R_fs.prop(2); PT G.R_fs.pt(2); Gp G.R_fs.gen(2); Op G.R_fs.osg(2)];
    end
    function c = cov_circles(Pp)
        c = [0 0 G.R_cov.prop(2); Pp G.R_cov.pcu(2)];
    end
    function m = shell_mass(H, L)
        m = in.rho.A357 * 1e-9 * (in.wall_side * H.perim * L + 2 * in.wall_end * H.area);
    end
    function mg = gen_margins(Gp)
        dPT = norm(Gp - PT);
        mg = {'gen gear tip to pinion tip', dPT - (G.r_tip.gen + G.r_tip.pinion + gp); ...
              'gen cartridge bore to PT bearing bore', dPT - (G.r_tip.gen + 2 + rbp + 5); ...
              'generator unit to PT tunnel keep-out', dPT - (rg + in.r_ker + pk); ...
              'generator pad above the propeller axis', Gp(2)};
        if Lg + 8 > in.L_free
            mg(end + 1, :) = {'generator unit to exhaust collector', dPT - (rg + in.R_exh + pk)};
        end
    end
    function mo = osg_margins(Op)
        mo = {'OSG unit to planetary case flange', norm(Op) - (G.R_flange + ro + pk); ...
              'OSG gear tip to pinion tip', norm(Op - PT) - (G.r_tip.osg + G.r_tip.pinion + gp); ...
              'OSG gear tip to first-stage gear tip', norm(Op) - (G.r_tip.osg + G.r_tip.gear2 + gp); ...
              'OSG pad above the propeller axis', Op(2)};
    end
    function mp = pcu_margins(Gp, Pp)
        Hc = cov_circles(Pp);
        mp = {'generator unit to accessory cover', dist_hull2(Gp, Hc) - (rg + pk); ...
              'generator unit to PCU unit', norm(Gp - Pp) - (rg + rp + pk); ...
              'PCU unit to PT tunnel keep-out', norm(Pp - PT) - (rp + in.r_ker + pk); ...
              'accessory cover to PT tunnel keep-out', dist_hull2(PT, Hc) - (in.r_ker + pk); ...
              'PCU pad above the propeller axis', Pp(2)};
    end
    function r = feasible_tg(Rexh, Lfree)
        r = [];
        for ii = 1:numel(tg)
            Gq = G.a_gen * [cosd(tg(ii)) sind(tg(ii))];
            ok = Gq(2) >= 0 && norm(Gq - PT) >= rg + in.r_ker + pk;
            if Lg + 8 > Lfree, ok = ok && norm(Gq - PT) >= rg + Rexh + pk; end
            if ok, r(end + 1) = tg(ii); end %#ok<AGROW>
        end
    end
end

function d = dist_hull2(p, c)
% distance from point p to the convex hull of two circles c = [x y r; x y r]: the hull is the union of
% the circles with linearly blended centres and radii, so the distance is a 1-D minimum over the blend
t = linspace(0, 1, 2001)';
cc = (1 - t) * c(1, 1:2) + t * c(2, 1:2);
rr = (1 - t) * c(1, 3) + t * c(2, 3);
d = min(sqrt(sum((cc - p).^2, 2)) - rr);
end

function v = minmax_or_nan(r)
if isempty(r), v = [NaN NaN]; else, v = [min(r) max(r)]; end
end
