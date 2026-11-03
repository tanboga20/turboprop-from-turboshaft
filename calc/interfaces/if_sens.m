function T = if_sens()
%IF_SENS  Sensitivity of the design margins to the interface values of the ICD (step 3.3).
%   T = if_sens()
%
%   Every interface value the design assumed (TBD with an aircraft,
%   propeller, core or supplier partner, or set by this design for a
%   partner) is moved up and down; the margin it drives is recomputed with
%   the tool of the step that uses it, through if_override (no tool is
%   changed), or by the closed form where the relation is direct:
%     LD-07  1P moment -> propeller bearing L10m (min of three) and the
%            propeller shaft fatigue safety (run_step25)
%     PIF-01 propeller mass and overhang -> the same (run_step25)
%     LD-06  manoeuvre load factor -> propeller bearing static safety at the
%            limit load (run_step25) and the generator pad moment (m g nz x)
%     LD-08  PT stopping time -> ring gear capacity / propeller torque peak
%            (24,386 N m against 26,129 x 0.2 / t, step 2.4)
%     ENV-04 exhaust gas temperature -> PT shaft temperature in the tunnel
%            against 150 degC (tunnel_thermal, step 2.2)
%     PIF-02 pitch oil flow, ground idle speed -> manifold pressure and the
%            regulating valve spill (os_solve, step 3.2)
%     LUB-08 negative-g duration -> usable oil needed against the 5.69 L
%     STR-02 planet bearing speed limit of the supplier -> margin at 110%
%            speed (planet 5,471 rpm at 100%)
%     suction line length and bore -> cold pump inlet pressure (os_inlet)
%     bleed air temperature -> LUB-07 mist time at 75% MCP (os_mist)
%     engine mount stiffness -> propeller bearing seat stiffness against
%            the DYN-05 floor (bolted flange k 6.56e7 N/m in series, step 2.8)
%     accessory unit diameters -> largest diameter the step 3.1 layout takes
%   Output T: table (id, quantity, unit, value, base (1 = assumed value),
%   result, result unit, limit, margin = result over or under the limit in
%   the sense of the requirement).
%   Source: Phase 3 report, Section 3.3 ("Sensitivity").

rows = {};
    function add(id, q, unit, v, base, res, ru, lim, marg)
        rows(end + 1, :) = {id, q, unit, v, base, res, ru, lim, marg};
    end
% ---------------------------------------------------------------- propeller loads (run_step25)
sb0 = sb_inputs();
cases = {'LD-07', '1P moment', 'N m', 'M_1P', [1000 2000 4000 6000]; ...
         'PIF-01', 'propeller mass', 'kg', 'm_prop', [60 76.4 95]; ...
         'PIF-01', 'propeller overhang', 'mm', 'prop_overhang', [200 250 300]; ...
         'LD-06', 'manoeuvre load factor', 'g', 'nz_man', [2.5 3.17 4.0 5.0]};
for c = 1:size(cases, 1)
    [id, q, u, f, vals] = cases{c, :};
    for v = vals
        if_override('set', 'sb_inputs', {f, v});
        S = run_step25(tempname);
        if_override('clear');
        L = min([S.B(5:7).L10m]);  s0 = min([S.B(5:7).s0_lim]);
        b = abs(v - sb0.(f)) < 1e-9;
        add(id, [q ': propeller bearing L10m (min)'], u, v, b, L, 'h', sb0.L10_req, L / sb0.L10_req);
        add(id, [q ': propeller shaft n_f'], u, v, b, S.SH(4).n_f, '-', sb0.nf_min, S.SH(4).n_f / sb0.nf_min);
        add(id, [q ': propeller bearing s0 (LD-01)'], u, v, b, s0, '-', sb0.s0_lim, s0 / sb0.s0_lim);
    end
end
ad = ad_inputs();
for nz = [2.5 3.17 4.0 5.0]
    M = ad.m_gen * 9.81 * nz * ad.x_cg_gen / 1000;
    add('LD-06', 'manoeuvre load factor: generator pad moment', 'g', nz, abs(nz - ad.nz_man) < 1e-9, M, 'N m', NaN, NaN);
end
% ---------------------------------------------------------------- PT stopping time (closed form, step 2.4)
gi = gd_inputs();
cap = 24386;                                          % N m, ring gear root (step 2.5, LD-08)
for t = [0.15 0.20 0.22 0.30 0.50]
    T = gi.T_stop_prop * 0.2 / t;
    add('LD-08', 'PT stopping time: propeller torque peak', 's', t, abs(t - 0.22) < 1e-9, T, 'N m', cap, cap / T);
end
% ---------------------------------------------------------------- tunnel temperature (step 2.2)
pin = ptshaft_inputs();
for Tg = [650 700 750 800]
    th = tunnel_thermal(0.066, pin.L, 0.0075, Tg, pin);
    add('ENV-04', 'exhaust gas temperature: PT shaft in the tunnel', 'degC', Tg, Tg == 700, th.T_shaft_max, 'degC', ...
        pin.tun.T_shaft_max, pin.tun.T_shaft_max / th.T_shaft_max);
end
% ---------------------------------------------------------------- oil system (step 3.2)
oin = os_inputs();  li = lb_inputs();  D = lb_design();
R0 = lb_losses(D, li.ops(1), 2392.6, li);
ai = as_inputs();  gi2 = gd_inputs();  ad2 = ad_inputs();  sb2 = sb_inputs();
L31 = as_layout(ai, as_geom(ai, gi2, ad2, sb2), gi2, ad2, sb2);
Qp100 = 5.8 * 6200 * li.eta_vol / 1000;
o100 = oil_props(100, li.oil);
for q = [2.5 5 7.5 10 15]
    li2 = li;  li2.Q_pcu = q;
    F = lb_flows(R0.L, 4, li2, R0.oil);
    N = os_network(oin, L31, F, li2, R0.oil);
    Cc = lb_cooler(18e3, F.Q_need / 6e4 * o100.rho, li2.v_face_design, li2);
    cool = struct('dp0', Cc.dp_oil / 1e3, 'Q0', F.Q_need, 'nu0', oil_props(100 + li.dT_oil / 2, li.oil).nu);
    S1 = os_solve(oin, N, li2, oin.ops(1), os_oil(100, li), Qp100, cool);
    S2 = os_solve(oin, N, li2, oin.ops(2), os_oil(100, li), Qp100, cool);
    add('PIF-02', 'pitch oil flow: spill of the regulating valve at MC', 'L/min', q, q == 5, S1.Q_prv, 'L/min', 0, NaN);
    add('PIF-02', 'pitch oil flow: manifold at ground idle', 'L/min', q, q == 5, S2.p_m, 'kPa', 34.5, S2.p_m / 34.5);
end
F = lb_flows(R0.L, 4, li, R0.oil);
N = os_network(oin, L31, F, li, R0.oil);
Cc = lb_cooler(18e3, F.Q_need / 6e4 * o100.rho, li.v_face_design, li);
cool = struct('dp0', Cc.dp_oil / 1e3, 'Q0', F.Q_need, 'nu0', oil_props(100 + li.dT_oil / 2, li.oil).nu);
for n = [0.3 0.4 0.5 0.6 0.7]
    op = oin.ops(2);  op.n = n;
    S2 = os_solve(oin, N, li, op, os_oil(100, li), Qp100, cool);
    add('SYS-03', 'ground idle speed: manifold pressure', 'share of 100%', n, n == 0.6, S2.p_m, 'kPa', 34.5, S2.p_m / 34.5);
end
for t = [5 10 20 30]
    V = Qp100 * t / 60;
    add('LUB-08', 'negative-g duration: usable oil needed', 's', t, false, V, 'L', oin.V_usable, oin.V_usable / V);
end
for Ls = [150 300 450]
    for dsu = [20 25 32]
        o2 = oin;  o2.line.suction = [Ls dsu 1 + 2 * (Ls > 150)];
        I = os_inlet(o2, li, Qp100);
        add('LUB-02', sprintf('suction line bore %g mm: cold pump inlet (sea level, -40 degC)', dsu), 'mm', Ls, ...
            Ls == 150 && dsu == 32, I.p_in_cold, 'kPa abs', oin.p_inlet_min, I.p_in_cold / oin.p_inlet_min);
    end
end
for Ta = [50 100 150 200]
    o2 = oin;  o2.mist.T_air = Ta;
    X = os_mist(o2, li, D, 31.898, 24.938);
    t = X.t.t_s(strcmp(X.t.point, '75% MCP') & X.t.uplift == 1 & strcmp(X.t.measure, 'mist 20 SCFM'));
    add('LUB-07', 'bleed air temperature: mist time at 75% MCP (20 SCFM)', 'degC', Ta, Ta == 100, t, 's', 360, t / 360);
end
% ---------------------------------------------------------------- planet bearing speed limit (STR-02)
n110 = 5471.5 * 1.10;
for nl = [5500 6000 6500 7000]
    add('STR-02', 'planet bearing speed limit of the supplier: margin at 110% speed', 'rpm', nl, nl == 6000, n110, 'rpm', nl, nl / n110);
end
% ---------------------------------------------------------------- engine mount stiffness (DYN-05, step 2.8)
k_case = 6.56e7;  k_floor = 5e7;
for km = [1e8 2e8 5e8 1e9 Inf]
    k = 1 / (1 / k_case + 1 / km);
    add('DYN-05', 'engine mount stiffness: propeller bearing seat stiffness', 'N/m', km, isinf(km), k, 'N/m', k_floor, k / k_floor);
end
% ---------------------------------------------------------------- accessory unit envelopes (step 3.1 margins)
mg = containers.Map(L31.ang.margin(:, 1), L31.ang.margin(:, 2));
Dg = 200 + 2 * min(mg('generator unit to accessory cover'), mg('generator unit to PCU unit'));
Do = 90 + 2 * mg('OSG unit to planetary case flange');
Dp = 120 + 2 * min([mg('generator unit to PCU unit') mg('PCU unit to PT tunnel keep-out')]);
add('ACC-02', 'generator unit: largest diameter the layout takes', 'mm', 200, true, Dg, 'mm', 200, Dg / 200);
add('ACC-02', 'OSG unit: largest diameter the layout takes', 'mm', 90, true, Do, 'mm', 90, Do / 90);
add('ACC-02', 'PCU unit: largest diameter the layout takes', 'mm', 120, true, Dp, 'mm', 120, Dp / 120);
T = cell2table(rows, 'VariableNames', {'id', 'quantity', 'unit', 'value', 'base', 'result', 'result_unit', 'limit', 'margin'});
end
