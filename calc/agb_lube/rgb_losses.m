function R = rgb_losses(L, A, op, P_pumps, in, in14)
%RGB_LOSSES  Power losses of the RGB and the heat they put into its oil, at one operating point.
%   R = rgb_losses(L, A, op, P_pumps, in, in14)
%
%   Inputs
%     L         one RGB design from rgb_layout (calc/rgb_sizing)
%     A         accessory_pads output
%     op        operating point (an element of in14.ops): f_T propeller
%               torque share, f_n speed share, T_gen generator torque [N m],
%               T_in oil inlet temperature [degC], thrust [N]
%     P_pumps   shaft power of the oil pumps (lube_sizing)           [W]
%     in, in14  rgb_inputs and lube_inputs
%
%   The power is followed from the propeller back to the power turbine; each
%   loss adds to the power the shaft upstream must deliver:
%     planetary stage  sun-planet and planet-ring meshes (mean load, no
%                      K_gamma), planet bearings, propeller shaft bearings,
%                      windage of planets, sun and carrier
%     intermediate     PCU drive, oil pumps, the accessory train on the
%                      first-stage gear (generator and OSG power, their mesh,
%                      bearing and windage losses), its own bearings, the
%                      first-stage gear's windage
%     first stage      the mesh, input shaft bearings, pinion windage
%   Oil properties at the mean oil temperature T_in + dT_oil/2.
%
%   Output struct R
%     L          loss breakdown [W]: mesh_s1, mesh_sp, mesh_pr, mesh_gen,
%                mesh_osg, mesh_pcu, brg_inp, brg_mid, brg_prop, brg_planet,
%                brg_acc, wind_pinion, wind_gear2, wind_planetary, wind_acc,
%                pumps, pcu_osg (PCU and OSG power, which ends up in the oil)
%     L_mech     the RGB's own losses, oil pumps included (SYS-05)  [W]
%     Q_oil      heat into the RGB oil, L_mech + pcu_osg (LUB-04)  [W]
%     P_PT, P_prop, P_gen   power turbine, propeller and generator power [W]
%     T_PT       power turbine torque                                [N m]
%     eta        mechanical efficiency 1 - L_mech / P_PT             [-]
%     oil        oil_props at the mean oil temperature
%     mu_s1, HV_s1   friction coefficient and loss factor of the first stage [-]
%
%   Source: Phase 1 report, Section 4 ("Power losses and efficiency").
%   Tested by test_step14 (TC17).

t = L.t;
s2 = L.s2;
oil = oil_props(op.T_in + in14.dT_oil / 2, in14.oil);
nu = oil.nu;
eta = oil.eta;
w = @(n) n * 2 * pi / 60;
n_PT = in.n_PT * op.f_n;
n_mid = in.n_PT / t.u1 * op.f_n;
n_c = s2.n_c * op.f_n;
n_pr = s2.n_p_rel * op.f_n;
n_gen = A.gen.n * op.f_n;
n_osg = A.osg.n * op.f_n;
n_pcu = A.pcu.n * op.f_n;
dm = @(d) 1.3 * d + 10;                     % mean diameter of the rgb_mass bearing model, D = 1.6 d + 20
Lo = struct();

% Propeller
P_prop = op.f_T * op.f_n * in.P;
T_prop = P_prop / w(n_c);

% Planetary stage, mean load per planet
N = t.N;
T_s = T_prop / t.i2;
Tp = T_s / N * t.zp / t.zs;
if t.zs <= t.zp
    T1 = T_s / N;  n1 = n_mid - n_c;        % sun is gear 1
else
    T1 = Tp;  n1 = n_pr;                    % planet is gear 1
end
Lo.mesh_sp = N * mesh_loss(s2.g_sp, T1, n1, eta, in14.Ra, in14.XL).P_loss;
Lo.mesh_pr = N * mesh_loss(s2.g_pr, Tp, n_pr, eta, in14.Ra, in14.XL).P_loss;
kg = in.Kgam(in.N_list == N);
P1 = hypot(s2.brg.F_gear / kg * op.f_T, s2.brg.F_c * op.f_n^2);
Lo.brg_planet = N * bearing_loss(s2.brg.D_pw, n_pr, nu, P1, in14.f0_roller, in14.f1_roller).P;
d_pr = L.prop.sh.d_o;
Lo.brg_prop = bearing_loss(dm(d_pr), n_c, nu, op.thrust, in14.f0_ball, in14.f1_ball).P ...
            + bearing_loss(dm(d_pr), n_c, nu, L.prop.R_out_1, in14.f0_roller, in14.f1_roller).P ...
            + bearing_loss(dm(d_pr), n_c, nu, L.prop.R_in_1, in14.f0_roller, in14.f1_roller).P;
[~, t_c] = rgb_mass('carrier', in, s2.ds, s2.dp, s2.brg.d_pin, N, s2.b);
Lo.wind_planetary = N * windage_loss(s2.dp, s2.b, n_pr, in14.mu_mist) ...
                  + windage_loss(s2.ds, s2.b, n_mid - n_c, in14.mu_mist) ...
                  + windage_loss(s2.ds + 2 * s2.dp, s2.b + 2 * t_c, n_c, in14.mu_mist);
P_sun = P_prop + Lo.mesh_sp + Lo.mesh_pr + Lo.brg_planet + Lo.brg_prop + Lo.wind_planetary;

% Accessory train on the first-stage gear: generator and OSG
P_gen = op.T_gen * w(n_gen);
g = A.osg.g;
T_osg1 = in14.T_osg * g.z1 / g.z2;          % OSG torque on its drive gear
Lo.mesh_osg = mesh_loss(g, T_osg1, n_gen, eta, in14.Ra, in14.XL).P_loss;
T_ag = op.T_gen + T_osg1;                   % torque on the accessory drive gear shaft
Lo.mesh_gen = mesh_loss(A.gen.g, T_ag, n_gen, eta, in14.Ra, in14.XL).P_loss;
Ft = [2000 * T_ag / A.gen.g.d1, 2000 * in14.T_osg / A.osg.g.d2, 2000 * in14.T_pcu / A.pcu.g.d2];
d_sh = [A.gen.d_shaft, A.osg.d_shaft, A.pcu.d_shaft];
n_sh = [n_gen, n_osg, n_pcu];
Lo.brg_acc = 0;
for k = 1:3                                 % two ball bearings per shaft, each carries half the mesh force
    Lo.brg_acc = Lo.brg_acc + 2 * bearing_loss(dm(d_sh(k)), n_sh(k), nu, Ft(k) / 2, ...
                                               in14.f0_ball, in14.f1_ball).P;
end
Lo.wind_acc = windage_loss(A.gen.g.d1, A.gen.b, n_gen, in14.mu_mist) ...
            + windage_loss(A.osg.g.d2, A.osg.b, n_osg, in14.mu_mist) ...
            + windage_loss(A.pcu.g.d2, A.pcu.b, n_pcu, in14.mu_mist);

% PCU drive, PCU and OSG power, oil pumps: all on the intermediate shaft side
g = A.pcu.g;
Lo.mesh_pcu = mesh_loss(g, in14.T_pcu * g.z1 / g.z2, n_mid, eta, in14.Ra, in14.XL).P_loss;
Lo.pcu_osg = in14.T_pcu * w(n_pcu) + in14.T_osg * w(n_osg);
Lo.pumps = P_pumps;

% Intermediate shaft: bearing loads follow the first-stage torque
P_mid = P_sun + Lo.mesh_pcu + Lo.pcu_osg + Lo.pumps + P_gen + Lo.mesh_gen + Lo.mesh_osg ...
        + Lo.brg_acc + Lo.wind_acc;
f_s1 = P_mid / w(n_PT) / in.T_PT;
d_mid = L.mid.sh.d_o;
Lo.brg_mid = 2 * bearing_loss(dm(d_mid), n_mid, nu, L.mid.R * f_s1, in14.f0_roller, in14.f1_roller).P ...
           + bearing_loss(dm(d_mid), n_mid, nu, L.mid.F_a * f_s1, in14.f0_ball, in14.f1_ball).P;
Lo.wind_gear2 = windage_loss(L.s1.g.d2, L.s1.b, n_mid, in14.mu_mist);
P_mid = P_mid + Lo.brg_mid + Lo.wind_gear2;

% First stage and input shaft
ml = mesh_loss(L.s1.g, P_mid / w(n_PT), n_PT, eta, in14.Ra, in14.XL);
Lo.mesh_s1 = ml.P_loss;
f_s1 = P_mid / w(n_PT) / in.T_PT;
d_in = L.inp.sh.d_o;
Lo.brg_inp = 2 * bearing_loss(dm(d_in), n_PT, nu, L.inp.R * f_s1, in14.f0_roller, in14.f1_roller).P ...
           + bearing_loss(dm(d_in), n_PT, nu, L.inp.F_a * f_s1, in14.f0_ball, in14.f1_ball).P;
Lo.wind_pinion = windage_loss(L.s1.g.d1, L.s1.b, n_PT, in14.mu_mist);
P_PT = P_mid + Lo.mesh_s1 + Lo.brg_inp + Lo.wind_pinion;

Lo = orderfields(Lo, {'mesh_s1', 'mesh_sp', 'mesh_pr', 'mesh_gen', 'mesh_osg', 'mesh_pcu', ...
                      'brg_inp', 'brg_mid', 'brg_prop', 'brg_planet', 'brg_acc', 'wind_pinion', ...
                      'wind_gear2', 'wind_planetary', 'wind_acc', 'pumps', 'pcu_osg'});
Q_oil = sum(struct2array_(Lo));
L_mech = Q_oil - Lo.pcu_osg;
R = struct('L', Lo, 'L_mech', L_mech, 'Q_oil', Q_oil, 'P_PT', P_PT, 'P_prop', P_prop, ...
           'P_gen', P_gen, 'T_PT', P_PT / w(n_PT), 'eta', 1 - L_mech / P_PT, 'oil', oil, ...
           'mu_s1', ml.mu_mz, 'HV_s1', ml.H_V);
end

function v = struct2array_(s)
% Values of a scalar struct with scalar fields, as a row vector
c = struct2cell(s);
v = [c{:}];
end
