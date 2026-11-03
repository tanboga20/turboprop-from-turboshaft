function S = lube_sizing(Q_heat, n_pump, in14)
%LUBE_SIZING  First sizing of the RGB oil system: flows, pumps, tank, cooler, jets.
%   S = lube_sizing(Q_heat, n_pump, in14)
%
%   Inputs
%     Q_heat   heat into the RGB oil at the design point (rgb_losses) [W]
%     n_pump   oil pump speed (intermediate shaft)                    [rpm]
%     in14     lube_inputs
%
%   Output struct S (flows in L/min, volumes in L, powers in W)
%     Q_lube     oil flow that carries Q_heat with a dT_oil temperature rise
%     Q_need     Q_lube plus the PCU supply, plus leaks
%     cap, V_d   supply pump capacity (pump_margin x Q_need) and displacement [cm^3/rev]
%     cap_s      total scavenge capacity, k_scav x cap
%     P_sup, P_scv, P_pumps, T_pump   pump shaft powers and torque [N m],
%                with the pump efficiencies of NASA TM-83716
%     V_dwell, V_cons, V_usable, V_tank   tank volumes: de-aeration dwell,
%                consumption over the longest mission, usable, total with
%                the unusable oil and the expansion space (LUB-06)
%     T_hot      oil temperature into the cooler at the LUB-04 duty  [degC]
%     m_air      cooling air flow                                    [kg/s]
%     lmtd, UA   log mean temperature difference [K] and the cooler's UA [W/K]
%     m_cooler   cooler mass                                         [kg]
%     v_jet      oil jet velocity at dp_jet                          [m/s]
%     oil        oil_props at the mean oil temperature
%
%   Source: Phase 1 report, Section 4 ("Oil system: separate, like the
%   CT7-9"). Tested by test_step14 (TC15).

oil = oil_props(in14.T_in + in14.dT_oil / 2, in14.oil);
rho = oil.rho;
cp = oil.cp;

% Flows and pumps
Q_lube = Q_heat / (rho * cp * in14.dT_oil) * 60e3;
Q_need = (Q_lube + in14.Q_pcu) * (1 + in14.leak);
cap = in14.pump_margin * Q_need;
V_d = cap * 1000 / (n_pump * in14.eta_vol);
cap_s = in14.k_scav * cap;
P_sup = in14.dp_supply * cap / 60e3 / in14.eta_supply;
P_scv = in14.dp_scav * cap_s / 60e3 / in14.eta_scav;

% Tank (LUB-06)
V_dwell = cap * in14.t_dwell / 60;
V_cons = in14.consumption * in14.mission_h;
V_usable = in14.V_gulp + in14.V_circuit + V_dwell + V_cons + in14.V_feather;
V_tank = (V_usable + in14.V_unusable) / (1 - in14.expansion);

% Air-oil cooler at the LUB-04 duty; the oil leaves it at T_in
m_oil = Q_lube / 60e3 * rho;
T_hot = in14.T_in + in14.Q_cooler / (m_oil * cp);
m_air = in14.Q_cooler / (in14.cp_air * in14.dT_air);
dT1 = T_hot - (in14.T_amb + in14.dT_air);   % counterflow ends
dT2 = in14.T_in - in14.T_amb;
lmtd = (dT1 - dT2) / log(dT1 / dT2);
UA = in14.Q_cooler / (in14.F_cross * lmtd);

S = struct('Q_lube', Q_lube, 'Q_need', Q_need, 'cap', cap, 'V_d', V_d, 'cap_s', cap_s, ...
           'P_sup', P_sup, 'P_scv', P_scv, 'P_pumps', P_sup + P_scv, ...
           'T_pump', (P_sup + P_scv) / (n_pump * 2 * pi / 60), ...
           'V_dwell', V_dwell, 'V_cons', V_cons, 'V_usable', V_usable, 'V_tank', V_tank, ...
           'T_hot', T_hot, 'm_air', m_air, 'lmtd', lmtd, 'UA', UA, ...
           'm_cooler', in14.Q_cooler / in14.q_cooler, ...
           'v_jet', in14.Cd_jet * sqrt(2 * in14.dp_jet / rho), 'oil', oil);
end
