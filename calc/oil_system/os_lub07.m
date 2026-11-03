function R = os_lub07(in, li, D, m_parts, m_case)
%OS_LUB07  Running without oil (LUB-07 goal: 30 min at cruise power after a total loss of oil pressure).
%   R = os_lub07(in, li, D, m_parts, m_case)
%
%   in = os_inputs, li = lb_inputs, D = lb_design; m_parts [kg]: the gears
%   and bearings that take the contact heat, m_case [kg]: the castings and
%   housings (step 3.1 CATIA masses).
%   Heat balance after the loss, two lumps: the parts (steel, c 0.46
%   kJ/(kg K)) take the RGB losses at cruise (the A-05 loiter point, 50%
%   torque, step 2.7 loss model, pumps excluded); a drip feed q to the 11
%   critical contacts (4 planet bearings, 4 sun-planet meshes, the
%   first-stage mesh, the 2 input roller bearings) takes heat m_oil c_oil
%   (T_parts - T_drip) for as long as its reservoir lasts; the parts pass
%   heat to the case through the bearings and shafts (conductance G_pc) and
%   the case (A357, c 0.9) to the nacelle air (hA). Both lumps start at
%   in.T_dry_start; the run-dry time ends when the parts reach
%   in.T_dry_limit. The losses are those of a lubricated gearbox: dry
%   friction would raise them, so every time is an upper bound.
%   Options: A no reservoir; B a reservoir that fits the SYS-06 margin
%   (drip 0.02 L/min per contact while it lasts); C 30 min of drip at
%   0.02 L/min per contact. Each with and without the case path.
%   Output R: P_cruise [kW], the reservoir table R.res (q, volume, mass,
%   over the margin), V_fit, t_fit [s] (how long the margin reservoir
%   drips), and R.t (table: option, t without case path, t with it [s]),
%   Q_drip_heat [kW] (the drip's heat pickup at the limit temperature).
%   Source: Phase 3 report, Section 3.2 ("Running without oil").

Rl = lb_losses(D, li.ops(3), 0, li);
R.P_cruise = Rl.L_mech / 1000;                          % kW
n = 11;
q = in.q_drip(1);                                       % L/min per contact for options B and C
V = in.q_drip * n * in.t_LUB07 / 60;                   % L for 30 min
m = V * li.oil.rho15 / 1000 + V * in.rho_res;
R.res = table(in.q_drip', V', m', (m - in.mass_margin)', 'VariableNames', {'q_Lmin', 'V_L', 'mass_kg', 'over_kg'});
R.V_fit = in.mass_margin ./ (li.oil.rho15 / 1000 + in.rho_res);
R.t_fit = R.V_fit ./ (in.q_drip * n) * 60;              % s
mdot = q * n / 60 * li.oil.rho15 / 1000;                % kg/s of drip oil
R.Q_drip_heat = mdot * li.oil.cp / 1000 * (in.T_dry_limit - in.T_drip);   % kW at the limit
opts = {'A: no reservoir', 0; 'B: reservoir in the SYS-06 margin', R.t_fit(1); 'C: 30 min reservoir', in.t_LUB07};
t = zeros(3, 2);
for k = 1:3
    for c = 1:2
        t(k, c) = dryrun(R.P_cruise, mdot * (opts{k, 2} > 0), opts{k, 2}, m_parts, m_case, (c == 2) * in.G_pc, ...
                         (c == 2) * in.hA_case, in, li);
    end
end
R.t = table(opts(:, 1), t(:, 1), t(:, 2), 'VariableNames', {'option', 't_parts_only', 't_with_case'});
R.m_parts = m_parts;  R.m_case = m_case;
end

function t = dryrun(P, mdot, t_drip, m1, m2, G, hA, in, li)
% explicit time march of the two lumps until the parts reach the limit (or 2 h)
dt = 1;  T1 = in.T_dry_start;  T2 = in.T_dry_start;  t = 0;
C1 = m1 * 0.46;  C2 = m2 * 0.90;                       % kJ/K
while T1 < in.T_dry_limit && t < 7200
    qd = 0;
    if t < t_drip, qd = mdot * li.oil.cp / 1000 * max(T1 - in.T_drip, 0); end
    q12 = G / 1000 * (T1 - T2);
    q2a = hA / 1000 * (T2 - in.T_amb_dry);
    T1 = T1 + dt * (P - qd - q12) / C1;
    T2 = T2 + dt * (q12 - q2a) / C2;
    t = t + dt;
end
end
