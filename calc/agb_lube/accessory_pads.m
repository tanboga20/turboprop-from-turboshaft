function A = accessory_pads(L, in, in14, T_pump)
%ACCESSORY_PADS  Accessory pads driven by the power turbine: speeds, drive gears, shear necks, mass.
%   A = accessory_pads(L, in, in14, T_pump)
%
%   L is one RGB design from rgb_layout (calc/rgb_sizing), in and in14 come
%   from rgb_inputs and lube_inputs, T_pump is the oil pump torque [N m]
%   (lube_sizing), used only for the pump's shear neck.
%
%   Drive train (ACC-02):
%     generator  accessory drive gear z_ag meshing with the first-stage gear
%                (helical, the first-stage module and helix angle); speed
%                n_PT z1/z_ag, whatever z2 is. The generator sits on its shaft.
%     OSG        spur pair z_osg from the accessory drive gear shaft
%     PCU        spur pair from the intermediate shaft; the gear's tooth
%                number is chosen to give propeller speed
%     oil pump   on the front end of the intermediate shaft, quill drive
%   Each pad has a quill shaft with a shear neck: diameter for k_shear x the
%   maximum rated torque, at least d_neck_min; shear torque pi d^3 tau_u / 16.
%
%   Output struct A
%     gen, osg, pcu   pad_mesh output plus n [rpm], ratio (n / n_PT),
%                     z1, z2, T_max [N m], d_shear [mm], T_shear [N m],
%                     d_shaft (accessory shaft outer diameter) [mm];
%                     gen and osg also ratio_ct7 (CT7-9 value)
%     pump            n [rpm], T [N m], d_shear [mm], T_shear [N m]
%     mass            breakdown [kg]: gen_gear, osg_gears, pcu_gears,
%                     acc_shafts, acc_bearings, quills, adapters, housing, total
%
%   Source: Phase 1 report, Section 4 ("Accessory pads"). Tested by
%   test_step14 (TC14).

t = L.t;
n_mid = in.n_PT / t.u1;
n_c = L.s2.n_c;

% Generator: accessory drive gear on the first-stage gear
n_gen = in.n_PT * t.z1 / in14.z_ag;
[d_sh, T_sh] = neck(in14.T_gen_max, in, in14);
gen = pad_mesh(in14.z_ag, t.z2, L.s1.mn, in.beta1, in14.b_ag_min, in14.T_gen_max, T_sh, n_gen, in, in14);
gen.n = n_gen;  gen.ratio = n_gen / in.n_PT;  gen.ratio_ct7 = in14.ratio_gen_ct7;
gen.z1 = in14.z_ag;  gen.z2 = t.z2;  gen.T_max = in14.T_gen_max;
gen.d_shear = d_sh;  gen.T_shear = T_sh;  gen.d_shaft = acc_shaft_d(d_sh);

% Overspeed governor: spur pair from the accessory drive gear shaft
za = in14.z_osg(1);
zb = in14.z_osg(2);
[d_sh, T_sh] = neck(in14.T_osg, in, in14);
osg = pad_mesh(za, zb, in14.m_osg, 0, in14.b_pad_min, in14.T_osg * za / zb, T_sh * za / zb, n_gen, in, in14);
osg.n = n_gen * za / zb;  osg.ratio = osg.n / in.n_PT;  osg.ratio_ct7 = in14.ratio_osg_ct7;
osg.z1 = za;  osg.z2 = zb;  osg.T_max = in14.T_osg;
osg.d_shear = d_sh;  osg.T_shear = T_sh;  osg.d_shaft = acc_shaft_d(d_sh);

% Propeller control unit: spur pair from the intermediate shaft at propeller speed
zc = in14.z_pcu1;
zd = round(zc * n_mid / n_c);
[d_sh, T_sh] = neck(in14.T_pcu, in, in14);
pcu = pad_mesh(zc, zd, in14.m_pcu, 0, in14.b_pad_min, in14.T_pcu * zc / zd, T_sh * zc / zd, n_mid, in, in14);
pcu.n = n_mid * zc / zd;  pcu.ratio = pcu.n / in.n_PT;
pcu.z1 = zc;  pcu.z2 = zd;  pcu.T_max = in14.T_pcu;
pcu.d_shear = d_sh;  pcu.T_shear = T_sh;  pcu.d_shaft = acc_shaft_d(d_sh);

% Oil pump on the intermediate shaft
[d_sh, T_sh] = neck(T_pump, in, in14);
pump = struct('n', n_mid, 'T', T_pump, 'd_shear', d_sh, 'T_shear', T_sh);

% Mass of the drives (the accessories themselves are not in SYS-06)
m.gen_gear = rgb_mass('gear2', in, gen.g.d1, gen.b);
m.osg_gears = rgb_mass('pinion', in, osg.g.d1, osg.b) + rgb_mass('gear2', in, osg.g.d2, osg.b);
m.pcu_gears = rgb_mass('pinion', in, pcu.g.d1, pcu.b) + rgb_mass('gear2', in, pcu.g.d2, pcu.b);
m.acc_shafts = 0;
m.acc_bearings = 0;
for d_o = [gen.d_shaft, osg.d_shaft, pcu.d_shaft]   % generator, OSG and PCU shafts
    m.acc_shafts = m.acc_shafts + rgb_mass('shaft', in, d_o, 0.5 * d_o, in14.acc_shaft_L);
    m.acc_bearings = m.acc_bearings + 2 * rgb_mass('bearing', in, d_o, 1);
end
m.quills = 0;
for dn = [gen.d_shear, osg.d_shear, pcu.d_shear, pump.d_shear]
    m.quills = m.quills + rgb_mass('shaft', in, 1.4 * dn, 0, in14.quill_L);
end
m.adapters = sum(in14.m_pad_adapter);
m.housing = in14.m_acc_housing;
m.total = m.gen_gear + m.osg_gears + m.pcu_gears + m.acc_shafts + m.acc_bearings ...
          + m.quills + m.adapters + m.housing;

A = struct('gen', gen, 'osg', osg, 'pcu', pcu, 'pump', pump, 'mass', m);
end

function [d, T_sh] = neck(T_max, in, in14)
% Shear neck diameter [mm] and its shear torque [N m]
tau_u = in14.tau_u_ratio * in.shaft_su;
d = max((16 * in14.k_shear * T_max * 1000 / (pi * tau_u))^(1/3), in14.d_neck_min);
T_sh = pi * d^3 * tau_u / 16 / 1000;
end

function d_o = acc_shaft_d(d_neck)
% Hollow accessory shaft (bore 0.5 d_o) around a quill with this neck: 1.6 x the neck, 5 mm steps, at least 15 mm
d_o = max(5 * ceil(1.6 * d_neck / 5), 15);
end
