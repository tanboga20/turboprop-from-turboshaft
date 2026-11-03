function S = os_solve(in, N, li, op, oil, Qp100, cool)
%OS_SOLVE  Pressures and flows of the oil network at one operating point.
%   S = os_solve(in, N, li, op, oil, Qp100, cool)
%
%   in = os_inputs, N = os_network, li = lb_inputs, op = one of in.ops,
%   oil = oil_props at the operating temperature (nu, rho; for the cold
%   start nu is the data sheet value), Qp100 [L/min] the pump delivery at
%   100% speed (step 2.7), cool = struct with the cooler oil pressure drop
%   dp0 [kPa] at flow Q0 [L/min] and nu0 [cSt] (laminar: dp scales with
%   Q nu).
%   Model (one-dimensional, incompressible):
%     pipes and drillings: Darcy friction, f = 64/Re below Re 2300 and
%       Blasius above, plus K_bend per bend (turbulent only);
%     jets: Q = Cd A sqrt(2 dp / rho), 1/Cd = 1/Cd_inf + 20 (1 + 2.25 l/d) / Re
%       (Lichtarowicz) with Re of the jet, after a last-chance strainer (in.dp_strainer at
%       the flow the jet passes at the step 2.7 jet pressure drop, quadratic in Q);
%     carrier jets: the centrifugal pressure rise rho w^2 (r^2 - r_feed^2) / 2
%       adds to the pressure at each jet; the transfer sleeve is a K = 1.5 loss;
%     PCU supply and leaks: orifices sized for their design flow at p_reg;
%     manifold: the pressure regulating valve holds p_reg when the pump can
%       deliver more than the network takes, else the manifold pressure falls
%       until the network takes the pump flow; supply side: suction-free
%       positive displacement pump (op.n x Qp100), filter (laminar element,
%       bypass), cooler (laminar, bypass), hoses; the pump relief valve caps
%       the outlet pressure (the rest of the flow returns to the inlet).
%   Output S: p_m (manifold), p_out (pump outlet), Q_pump, Q_net (into the
%   network), Q_prv (back through the regulating valve), Q_relief, bypass
%   flags, table S.jets (branch, jet, d, Q, Q_design, p_jet [kPa ahead of
%   the jet], v [m/s]), branch flows S.Qb, and dp of the supply items.
%   Source: Phase 3 report, Section 3.2 ("Network").

rho = oil.rho;  nu = oil.nu;                           % kg/m^3, cSt
B = N.branch;
w = 2 * pi * 1700 / 60 * op.n;                         % carrier speed (1,700 rpm propeller at 100%)
% orifice coefficients of the PCU supply and the leak path from their design flow at p_reg
% PCU supply and leaks as orifices (Cd(Re) like the jets, no strainer), sized for their flow at p_reg
opcu = struct('d', N.d_pcu, 'Q_nom', Inf);
oleak = struct('d', N.d_leak, 'Q_nom', Inf);
loop = op.T >= in.T_thermostat;                        % cooler loop in use

    function dp = pipe(Q, Lmm, dmm, nb)
        % kPa through a pipe of length L and bore d [mm] at Q [L/min]
        A = pi / 4 * (dmm * 1e-3)^2;
        v = Q / 6e4 / A;
        Re = max(v * dmm * 1e-3 / (nu * 1e-6), 1e-9);
        if Re < 2300
            f = 64 / Re;  K = 0;
        else
            f = 0.316 * Re^-0.25;  K = in.K_bend * nb;
        end
        dp = (f * Lmm / dmm + K) * rho * v^2 / 2 / 1e3;
    end
    function dp = jetdp(Q, j)
        % kPa through the strainer and the jet orifice at Q [L/min]
        A = pi / 4 * (j.d * 1e-3)^2;
        v = Q / 6e4 / A;
        Re = max(v * j.d * 1e-3 / (nu * 1e-6), 1e-9);
        Cd = 1 / (1 / in.Cd_inf + 20 * (1 + 2.25 * in.l_d_jet) / Re);   % Lichtarowicz et al. (1965)
        dp = rho / 2 * (v / Cd)^2 / 1e3 + in.dp_strainer * (Q / j.Q_nom)^2;   % Q_nom Inf: no strainer
    end
    function Q = jetflow(p_hub, b, j)
        % flow of one jet line (drilling, strainer, orifice) from its hub pressure
        boost = 0;
        if b.rotating
            r = norm(j.pos(1:2)) * 1e-3;
            boost = rho * w^2 * (r^2 - (b.r_rot * 1e-3)^2) / 2 / 1e3;
        end
        pa = p_hub + boost;
        if pa <= 0, Q = 0; return, end
        g = @(Q) pipe(Q, j.L_drill, in.d_branch, 1) + jetdp(Q, j) - pa;
        Q = fzero(g, [0 1e3]);
    end
    function [Qb, ph] = branchflow(pm, b)
        % flow into one branch from the manifold pressure pm
        Kin = 0;
        if b.rotating, Kin = 1.5; end
        sumjets = @(ph) sum(arrayfun(@(j) jetflow(ph, b, j), b.jet));
        h = @(ph) pm - pipe(sumjets(ph), b.L_gal, b.d_gal, b.n_bend) ...
                  - Kin * rho / 2 * (sumjets(ph) / 6e4 / (pi / 4 * (b.d_gal * 1e-3)^2))^2 / 1e3 - ph;
        if h(0) <= 0
            ph = 0;  Qb = 0;
        else
            ph = fzero(h, [0 pm]);
            Qb = sumjets(ph);
        end
    end
    function D = demand(pm)
        D = 0;
        for kk = 1:numel(B)
            D = D + branchflow(pm, B(kk));
        end
        D = D + orif(pm, opcu) + orif(pm, oleak);
    end

% supply side pressure drops at the delivered flow Q
    function Q = orif(p, o)
        if p <= 0, Q = 0; return, end
        Q = fzero(@(Q) jetdp(Q, o) - p, [0 1e3]);
    end
    function [dp, byf, byc] = supply(Q)
        lf = in.line;
        dpf = in.dp_filter_clean * (Q / 30) * (nu / 5.1);   % laminar element, rated at 100 degC (nu 5.1 cSt)
        byf = dpf > in.dp_filter_bypass;
        dpf = min(dpf, in.dp_filter_bypass);
        dpc = cool.dp0 * (Q / cool.Q0) * (nu / cool.nu0);
        byc = dpc > in.dp_cooler_bypass;
        dpc = min(dpc, in.dp_cooler_bypass);
        dp = pipe(Q, lf.pump_filter(1), lf.pump_filter(2), lf.pump_filter(3)) + dpf;
        if loop
            dp = dp + pipe(Q, lf.filter_cooler(1), lf.filter_cooler(2), lf.filter_cooler(3)) + dpc ...
                 + pipe(Q, lf.cooler_rgb(1), lf.cooler_rgb(2), lf.cooler_rgb(3));
        else
            byc = false;                               % thermostat closed: the loop carries no flow
        end
    end

Qp = Qp100 * op.n;
D_reg = demand(in.p_reg);
if D_reg <= Qp
    pm = in.p_reg;  Qnet = D_reg;
else
    pm = fzero(@(p) demand(p) - Qp, [1e-6 in.p_reg]);
    Qnet = Qp;
end
[dps, byf, byc] = supply(Qp);
pout = pm + dps;
Qrel = 0;
if pout > in.p_relief
    % the relief valve passes the rest: find the delivered flow that meets the relief pressure
    pmOf = @(Q) fzero(@(p) demand(p) - Q, [0 in.p_reg]);
    gRel = @(Q) pmOf(min(Q, D_reg)) + supply(Q) - in.p_relief;
    Qd = fzero(gRel, [1e-6 Qp]);
    Qrel = Qp - Qd;
    if Qd <= D_reg
        Qnet = Qd;  pm = pmOf(Qd);
    end
    [dps, byf, byc] = supply(Qd);
    pout = pm + dps;
end
% jet table
rows = {};
Qb = zeros(1, numel(B));
for k = 1:numel(B)
    [Qb(k), ph] = branchflow(pm, B(k));
    for j = 1:numel(B(k).jet)
        jj = B(k).jet(j);
        q = jetflow(ph, B(k), jj);
        boost = 0;
        if B(k).rotating
            boost = rho * w^2 * ((norm(jj.pos(1:2)) * 1e-3)^2 - (B(k).r_rot * 1e-3)^2) / 2 / 1e3;
        end
        pj = ph + boost - pipe(q, jj.L_drill, in.d_branch, 1) - in.dp_strainer * (q / jj.Q_nom)^2;
        rows(end + 1, :) = {B(k).name, jj.name, jj.d, q, jj.Q_design, pj, q / 6e4 / (pi / 4 * (jj.d * 1e-3)^2)}; %#ok<AGROW>
    end
end
S.jets = cell2table(rows, 'VariableNames', {'branch', 'jet', 'd', 'Q', 'Q_design', 'p_jet', 'v'});
S.Qb = Qb;
S.p_m = pm;  S.p_out = pout;  S.Q_pump = Qp;  S.Q_net = Qnet;
S.Q_prv = max(Qp - Qrel - Qnet, 0);  S.Q_relief = Qrel;
S.bypass_filter = byf;  S.bypass_cooler = byc;
S.Q_pcu = orif(pm, opcu);  S.Q_leak = orif(pm, oleak);  S.loop = loop;
end
