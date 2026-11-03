function R = os_mist(in, li, D, m_parts, m_case)
%OS_MIST  Emergency air-oil mist after a loss of oil (LUB-07): run time or steady temperature, system mass.
%   R = os_mist(in, li, D, m_parts, m_case)
%
%   in = os_inputs, li = lb_inputs, D = lb_design, m_parts and m_case [kg]
%   as in os_lub07. Two operating points: A-05 cruise (loiter point, 50%
%   torque) and 75% of maximum continuous power (the US Army loss-of-oil
%   rule, NASA TM X-71892); oil at 100 degC before the loss.
%   Heat: the mesh and bearing losses of the lubricated gearbox (step 2.7
%   loss model; churning and windage drop out without oil) times a friction
%   uplift in.mist.uplift (1 = lubricated friction; higher values for
%   boundary friction, TBR).
%   Cooling: the case path of os_lub07 (parts to case G_pc, case to nacelle
%   air hA) and, with mist, the mist air (in.mist.scfm of air at
%   in.mist.T_air, leaving at a share in.mist.eff of the way to the parts
%   temperature). The oil of the mist (in.mist.q per contact on all 31
%   contacts: 12 meshes, 19 bearings) lubricates; its heat pickup is negligible
%   and left out.
%   Run time: two-lump time march to in.T_dry_limit (230 degC), or the
%   steady parts temperature when it stays below the limit.
%   System mass: accumulator oil for 6 and 30 min at the mist rate plus the
%   accumulator, valve, mist lines and the air line from the compressor bleed
%   (masses in.mist.m_*, TBR; the bleed port on the core is TBD in
%   installation C).
%   Output R: table R.t (point, uplift, measure, time [s] or Inf, steady T
%   [degC]), R.P (losses [kW] per point and uplift), table R.mass.
%   Source: Phase 3 report, Section 3.2 ("Running without oil").

ms = in.mist;
n_c = 31;
ops = [li.ops(3), li.ops(1)];
ops(2).f_T = 0.75;  ops(2).name = '75% MCP';  ops(2).thrust = 10e3;
ops(1).name = 'A-05 cruise (50% torque)';
rows = {};
for i = 1:2
    Rl = lb_losses(D, ops(i), 0, li);
    L = Rl.L;
    P0 = (L.mesh_s1 + L.mesh_sp + L.mesh_pr + L.mesh_gen + L.mesh_osg + L.mesh_pcu + ...
          L.brg_inp + L.brg_mid + L.brg_prop + L.brg_planet + L.brg_acc) / 1000;   % kW
    for u = ms.uplift
        P = P0 * u;
        mdot_air = ms.scfm(:) * 0.000471947 * 1.225;   % kg/s of standard air
        for k = 0:numel(mdot_air)
            if k == 0
                ma = 0;  lab = 'no measures';
            else
                ma = mdot_air(k);  lab = sprintf('mist %g SCFM', ms.scfm(k));
            end
            [t, Tss] = march(P, ma, m_parts, m_case, in, ms);
            rows(end + 1, :) = {ops(i).name, u, lab, P, t, Tss}; %#ok<AGROW>
        end
    end
end
R.t = cell2table(rows, 'VariableNames', {'point', 'uplift', 'measure', 'P_kW', 't_s', 'T_steady'});
% mass of the emergency system
q = ms.q * 1e-3 * n_c;                                 % L/min for all contacts (0.3 and 1 mL/min each)
dur = [6 30];
rr = {};
for d = dur
    for qq = q
        V = qq * d;                                    % L
        m = V * li.oil.rho15 / 1000 + max(V * ms.m_acc_per_L, ms.m_acc_min) + ms.m_valve + ms.m_lines + ms.m_air_line;
        rr(end + 1, :) = {d, qq * 1000 / n_c, V, m}; %#ok<AGROW>
    end
end
R.mass = cell2table(rr, 'VariableNames', {'minutes', 'mL_min_per_contact', 'V_L', 'mass_kg'});
end

function [t, Tss] = march(P, mair, m1, m2, in, ms)
% time march of parts (1) and case (2); steady parts temperature from the same balance
G = in.G_pc / 1000;  hA = in.hA_case / 1000;  ca = 1.005 * ms.eff * mair;
% steady: P = ca (T1 - Ta) + G (T1 - T2), G (T1 - T2) = hA (T2 - Tamb)
Gs = 1 / (1 / G + 1 / hA);
Tss = (P + ca * ms.T_air + Gs * in.T_amb_dry) / (ca + Gs);
T1 = in.T_dry_start;  T2 = in.T_dry_start;  t = 0;
while T1 < in.T_dry_limit && t < 7200
    q12 = G * (T1 - T2);
    T1 = T1 + (P - q12 - ca * (T1 - ms.T_air)) / (m1 * 0.46);
    T2 = T2 + (q12 - hA * (T2 - in.T_amb_dry)) / (m2 * 0.90);
    t = t + 1;
end
if T1 < in.T_dry_limit, t = Inf; end
end
