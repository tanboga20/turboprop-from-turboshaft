function R = lb_losses(D, op, P_pumps, in)
%LB_LOSSES  Power losses of the detailed RGB and the heat they put into its oil, at one operating point.
%   R = lb_losses(D, op, P_pumps, in)
%
%   D is the design (lb_design: meshes M of gd_meshes, accessory meshes A
%   of ad_meshes, gd_inputs gi, sb_inputs sb, ad_inputs ad, planet
%   centrifugal load Fc), op one entry of in.ops, P_pumps the oil pump
%   power [W], in = lb_inputs. The step 1.4 loss model on the step 2.4 to
%   2.6 design: mesh losses (Ohlendorf loss factor with Schlenk friction,
%   mesh_loss; superfinished flanks in.Ra_sf, the ground OSG and PCU
%   pairs in.Ra), Palmgren bearing friction (bearing_loss, d_m = roller or
%   ball pitch diameter), windage (windage_loss), oil pumps, and the power
%   that the PCU and OSG return to the oil. Mean planet load (K_gamma 1).
%   Bearing loads follow the transmitted torque; the propeller bearings
%   carry the 1 g weight with the 1P moment and the thrust of op.
%
%   Output struct R: L (losses by item [W]), L_mech (RGB losses with the
%   pumps, without the PCU and OSG power and the PT rear sump: SYS-05),
%   Q_oil (heat into the RGB oil: L_mech, PCU and OSG power, PT rear sump:
%   LUB-04) [W], P_PT, P_prop, P_gen [W], T_PT [N m], eta [-], oil.
%   Source: Phase 2 report, Section 2.7 ("Heat balance"). Tested by
%   test_step27 (TC49).

M = D.M;  A = D.A;  gi = D.gi;  sb = D.sb;  ad = D.ad;
oil = oil_props(op.T_in + in.dT_oil / 2, in.oil);
nu = oil.nu;  eta = oil.eta;
w = @(n) n * 2 * pi / 60;
n_PT = gi.n_PT;  n_mid = M(1).ns;  n_c = M(2).nc;  n_pr = M(2).n1;
f0 = in.f0;  f1 = in.f1;
ml = @(g, T, n) mesh_loss(g, T, n, eta, in.Ra_sf, in.XL).P_loss;      % superfinished flanks
mlg = @(g, T, n) mesh_loss(g, T, n, eta, in.Ra, in.XL).P_loss;        % ground flanks
bl = @(dm, n, P, typ) bearing_loss(dm, n, nu, P, f0.(typ), f1.(typ)).P;
L = struct();

% Propeller and planetary stage, mean load per planet
P_prop = op.f_T * gi.P;
N = gi.s2.N;
Tp = op.f_T * M(2).T1;                              % torque on a planet per mesh
L.mesh_sp = N * ml(M(2).g, Tp, n_pr);
L.mesh_pr = N * ml(M(3).g, Tp, n_pr);
gsp = M(2).g;
F_gear = 2 * 2000 * Tp / gsp.dw1;
L.brg_planet = N * bl(D.planet_Dpw, n_pr, hypot(F_gear, D.Fc), 'roller');
W = sb.m_prop * sb.g;
a = sb.prop_overhang;  Lp = sb.prop_span;
R_out = W * (1 + a / Lp) + sb.M_1P * 1e3 / Lp;
R_inn = W * a / Lp + sb.M_1P * 1e3 / Lp;
L.brg_prop = bl(sb.brg(7).Dpw, n_c, op.thrust, 'ball') + bl(sb.brg(6).Dpw, n_c, R_out, 'roller') ...
           + bl(sb.brg(5).Dpw, n_c, R_inn, 'roller');
t_c = 15;                                           % mm, carrier plate thickness for its windage
L.wind_planetary = N * windage_loss(gsp.d1, gsp.b, n_pr, in.mu_mist) ...
                 + windage_loss(gsp.d2, gsp.b, M(2).ns_rel, in.mu_mist) ...
                 + windage_loss(gsp.d2 + 2 * gsp.d1, gsp.b + 2 * t_c, n_c, in.mu_mist);
P_sun = P_prop + L.mesh_sp + L.mesh_pr + L.brg_planet + L.brg_prop + L.wind_planetary;

% Accessories on the first-stage gear and the intermediate shaft (step 2.6)
n_gen = A(1).n1;  n_osg = A(2).n2;  n_pcu = A(3).n2;
P_gen = op.T_gen * w(n_gen);
T_osg1 = ad.T_osg * A(2).g.z1 / A(2).g.z2;
L.mesh_gen = ml(A(1).g, op.T_gen + T_osg1, n_gen);
L.mesh_osg = mlg(A(2).g, T_osg1, n_gen);
L.mesh_pcu = mlg(A(3).g, ad.T_pcu * A(3).g.z1 / A(3).g.z2, n_mid);
Ft = [2000 * (op.T_gen + T_osg1) / A(1).g.d1, 2000 * ad.T_osg / A(2).g.d2, 2000 * ad.T_pcu / A(3).g.d2];
n_sh = [n_gen, n_osg, n_pcu];
L.brg_acc = 0;
for k = 1:3                                         % two ball bearings per shaft, each half the mesh force
    L.brg_acc = L.brg_acc + 2 * bl(ad.brg(k).Dpw, n_sh(k), Ft(k) / 2, 'ball');
end
L.wind_acc = windage_loss(A(1).g.d1, A(1).g.b, n_gen, in.mu_mist) ...
           + windage_loss(A(2).g.d2, A(2).g.b, n_osg, in.mu_mist) ...
           + windage_loss(A(3).g.d2, A(3).g.b, n_pcu, in.mu_mist);
L.pumps = P_pumps;
L.pcu_osg = ad.T_pcu * w(n_pcu) + ad.T_osg * w(n_osg);

% Intermediate shaft: bearing loads follow the first-stage torque
P_mid = P_sun + L.mesh_pcu + L.pcu_osg + L.pumps + P_gen + L.mesh_gen + L.mesh_osg + L.brg_acc + L.wind_acc;
f_s1 = P_mid / w(n_PT) / gi.T_PT;
L.brg_mid = 2 * bl(sb.brg(3).Dpw, n_mid, D.R_mid * f_s1, 'roller') + bl(sb.brg(4).Dpw, n_mid, D.Fa1 * f_s1, 'ball');
L.wind_gear2 = windage_loss(M(1).g.d2, M(1).g.b, n_mid, in.mu_mist);
P_mid = P_mid + L.brg_mid + L.wind_gear2;

% First stage and input shaft
f_s1 = P_mid / w(n_PT) / gi.T_PT;
L.mesh_s1 = ml(M(1).g, P_mid / w(n_PT), n_PT);
L.brg_inp = 2 * bl(sb.brg(1).Dpw, n_PT, D.R_in * f_s1, 'roller') ...
          + bl(sb.brg(2).Dpw, n_PT, D.Fa1 * f_s1 + 278, 'ball');
L.wind_pinion = windage_loss(M(1).g.d1, M(1).g.b, n_PT, in.mu_mist);
P_PT = P_mid + L.mesh_s1 + L.brg_inp + L.wind_pinion;

% PT rear sump (LUB-10, step 2.2): bearing loss and heat from the exhaust
L.rear_sump = in.Q_rear_sump;
L = orderfields(L, {'mesh_s1', 'mesh_sp', 'mesh_pr', 'mesh_gen', 'mesh_osg', 'mesh_pcu', 'brg_inp', ...
                    'brg_mid', 'brg_prop', 'brg_planet', 'brg_acc', 'wind_pinion', 'wind_gear2', ...
                    'wind_planetary', 'wind_acc', 'pumps', 'pcu_osg', 'rear_sump'});
c = struct2cell(L);
Q_oil = sum([c{:}]);
L_mech = Q_oil - L.pcu_osg - L.rear_sump;
R = struct('L', L, 'L_mech', L_mech, 'Q_oil', Q_oil, 'P_PT', P_PT, 'P_prop', P_prop, 'P_gen', P_gen, ...
           'T_PT', P_PT / w(n_PT), 'eta', 1 - L_mech / P_PT, 'oil', oil);
end
