function L = as_layout(in, G, gi, ad, sb)
%AS_LAYOUT  Axial stations, part profiles and placements of the complete RGB (step 3.1).
%   L = as_layout(in, G, gi, ad, sb)
%
%   in = as_inputs, G = as_geom, gi = gd_inputs, ad = ad_inputs, sb =
%   sb_inputs. Builds the first-stage module around the step 2.5 bearing
%   span (front roller bearings behind the 12 mm front wall, the
%   four-point contact bearings and their nuts outboard of the rear roller
%   bearings), the accessory module (generator gear-shaft in a cartridge
%   that withdraws to the engine side, OSG gear on the propeller-side face,
%   PCU gear and pump pack in a cover on the engine-side face) at the angles
%   of as_angles, and the bought parts of the planetary module. Output:
%     L.z        axial stations [mm]
%     L.ang      as_angles result
%     L.rev      revolved parts: name, desc, rz (closed polyline of r, z
%                pairs), rho, fill, teeth [z m x z0 b] (spur, optional),
%                holes [n pcd d] (optional), module
%     L.rollers  planet roller set: n, r_pitch, r_roller, z0, L
%     L.fs, L.cov  case outlines (as_hull) and their pads, pockets and holes
%     L.inst     instances: part, module, rot [deg], x, y, z
%     L.carrier  carrier changes (shaft end, scallops)
%   Gear phases: a gear placed in mesh gets the rotation that puts a tooth
%   of one gear in the tooth space of the other on the line of centres; a
%   helical pair whose gears start at different z is matched in the plane
%   of the smaller gear (CATIA helix: right hand turns counter-clockwise
%   with +z, catlib CutHelicalTeeth).
%   Source: Phase 3 report, Section 3.1 ("Layout").

% ------------------------------------------------------------ first-stage stations
brg = @(n) G.brg(n);
B_crb = brg('NU2210');  B_crb = B_crb(3);              % 23 mm, both shafts
q_mid = brg('QJ210');  q_pt = brg('QJ209');
n_mid = in.nut(2).dOB;  n_pt = in.nut(1).dOB;
z.front = 0;
z.wf = -in.wall_front;                                 % inner face of the front wall
z.bf = z.wf - in.gap_ax - B_crb / 2;                   % front roller bearing centres
z.c = z.bf - in.span / 2;                              % first-stage gear centre
z.br = z.c - in.span / 2;                              % rear roller bearing centres
z.qj_mid = z.br - B_crb / 2 - [q_mid(3) 0];            % [start end] of the four-point contact bearings
z.qj_pt = z.br - B_crb / 2 - [q_pt(3) 0];
z.nut_mid = z.qj_mid(1) - [n_mid(3) 0];
z.nut_pt = z.qj_pt(1) - [n_pt(3) 0];
z.wr = min(z.qj_mid(1), z.qj_pt(1)) - in.gap_ax;       % inner face of the rear wall
z.rear = z.wr - in.wall_front;                         % engine-side face of the first-stage case
z.boss_f = [z.bf - B_crb / 2 - in.gap_ax, -in.wall_end];   % bosses join the thinner end walls
z.boss_r = [z.rear + in.wall_end, z.br + B_crb / 2 + in.gap_ax];
z.g2 = z.c - G.b.s1 / 2;                               % gear and pinion start (z0 of their parts)
% accessories
z.gen = z.c - G.b.gen / 2;                             % generator gear start, centred on the first-stage gear
z.osg = z.boss_f(1) - 12 - G.b.osg;                    % OSG mesh between the generator gear and the front boss
z.cov = z.rear - [76 0];                               % accessory cover
z.pcu = z.rear - 14 - G.b.pcu;                         % PCU mesh, 14 mm behind the case face
z.pump = [z.cov(1) + 12, min(z.cov(1) + 12 + in.pump.L, z.pcu - 2)];   % on the 12 mm rear wall, 2 mm from the PCU mesh
z.prop_out = 412;                                      % outer propeller bearing boss of the step 2.8 case
z.nose = 446;
L.z = z;

% ------------------------------------------------------------ angles
Lfs = z.front - z.rear;
L.ang = as_angles(in, G, Lfs, z.cov(2) - z.cov(1));
a = L.ang;
Gp = a.Gp;  Op = a.Op;  Pp = a.Pp;  PT = a.PT;

% ------------------------------------------------------------ first-stage case and accessory cover
R = G.R_fs;
L.fs.out = as_hull([0 0 R.prop(2); PT R.pt(2); Gp R.gen(2); Op R.osg(2)]);
L.fs.cav = as_hull([0 0 R.prop(1); PT R.pt(1); Gp R.gen(1); Op R.osg(1)]);
L.fs.z_out = [z.rear z.front];
L.fs.z_cav = [z.rear + in.wall_rear, -in.wall_end];   % rear wall: mount card A (step 3.5)
rb = @(n) brg(n) * [0; 0.5; 0];                        % bearing seat radius
r_mid = rb('NU2210');  r_pt = rb('NU2209');  r_gen = rb('6305');  r_osg = rb('6202');  r_pcu = rb('6203');
hb6305 = brg('6305') * [0; 0; 0.5];                   % half width of the generator shaft bearings
r_cart = ceil(G.r_tip.gen + 2);                        % generator cartridge: the gear passes through its bore
% pads (cylinders added) and pockets (cylinders removed): [x y r z1 z2]
L.fs.pads = [0 0 G.R_flange z.wf z.front 125;                              % bolt ring to the planetary case
             PT 80 z.rear z.wr 0;                                          % engine mount ring (TBD)
             0 0 r_mid + in.boss z.boss_f 0;  PT r_pt + in.boss z.boss_f 0;  Gp r_gen + in.boss z.boss_f 0;
             0 0 r_mid + in.boss z.boss_r 0;  PT r_pt + in.boss z.boss_r 0;  Gp r_cart + in.boss z.boss_r 0;
             Op r_osg + in.boss z.wf -in.wall_end 0;                      % OSG bearing seat in the front wall
             Pp r_pcu + in.boss z.rear + in.wall_end z.wr 0];             % PCU bearing seat in the rear wall
% pads [x y r z1 z2 r_in]: r_in > 0 makes an annulus
L.fs.pockets = [0 0 r_mid z.rear z.front;                                  % intermediate shaft seats, through
                PT r_pt z.boss_f;  PT r_pt z.rear z.boss_r(2);             % pinion seats (front blind)
                Gp r_gen z.boss_f(1) z.bf + hb6305 + 2;                      % generator front seat, blind
                Gp r_cart z.rear z.boss_r(2);                              % generator cartridge bore
                Op r_osg z.wf z.front;                                     % OSG bearing in the front wall
                Pp r_pcu z.rear z.wr];                                     % PCU front bearing in the rear wall
% holes [cx cy pcd d n z1 z2]: tapped M6 for the planetary case flange (step 2.8), blind, 10 mm deep (step
% 3.5: through the 12 mm pad they break onto the wall edge); engine-side ring at the PT axis (ICD-24)
L.fs.holes = [0 0 290 5.0 30 z.wf + 2 z.front;
              PT 140 9 12 z.rear z.wr];
Rc = G.R_cov;
L.cov.out = as_hull([0 0 Rc.prop(2); Pp Rc.pcu(2)]);
L.cov.cav = as_hull([0 0 Rc.prop(1); Pp Rc.pcu(1)]);
L.cov.z_out = z.cov;
L.cov.z_cav = [z.cov(1) + 12, z.cov(2) + 1];           % open towards the case; the rear wall holds the PCU bearing
L.cov.pads = zeros(0, 6);
L.cov.pockets = [Pp r_pcu z.cov(1) z.cov(1) + 12];
L.cov.holes = zeros(0, 7);

% ------------------------------------------------------------ revolved parts
rev = struct('name', {}, 'desc', {}, 'rz', {}, 'rho', {}, 'fill', {}, 'teeth', {}, 'holes', {}, 'module', {});
    function add(name, module, desc, rz, rho, fill, teeth, holes)
        if nargin < 7, teeth = []; end
        if nargin < 8, holes = []; end
        rev(end + 1) = struct('name', name, 'desc', desc, 'rz', rz, 'rho', rho, 'fill', fill, 'teeth', teeth, ...
                              'holes', holes, 'module', module);
    end
st = in.rho.steel;
% bearings, nuts, seals: plain annuli [d D B] with z from 0 to B
for k = 1:numel(in.brg)
    d = in.brg(k).dDB;
    add(['brg_' in.brg(k).name], 'bought', sprintf('Bearing envelope %s, %g x %g x %g mm', in.brg(k).name, d), ...
        ring(d(1) / 2, d(2) / 2, 0, d(3)), st, in.fill_brg);
end
for k = 1:numel(in.nut)
    d = in.nut(k).dOB;
    add(['nut_' in.nut(k).name], 'bought', sprintf('Shaft nut envelope %s, M%g, OD %g, %g mm', in.nut(k).name, d), ...
        ring(d(1) / 2, d(2) / 2, 0, d(3)), st, 1);
end
for k = 1:numel(in.seal)
    d = in.seal(k).dDB;
    add(['seal_' in.seal(k).name], 'bought', sprintf('Carbon face seal envelope, %g x %g x %g mm (TBR)', d), ...
        ring(d(1) / 2, d(2) / 2, 0, d(3)), st, in.fill_seal);
end
% shafts (built at their global z)
pin_tip = G.r_tip.pcu_pin;
rj_mid = G.d_shaft.mid / 2;                            % journals at the NU 2210 / QJ 210 bore (25)
add('mid_shaft', 'first_stage', sprintf('Intermediate shaft %g/%g mm, PCU pinion z %d m %g on the stub, quill bores', ...
    G.d_shaft.mid, G.d_shaft.mid_i, ad.pcu.z(1), ad.pcu.m), ...
    [ad.pcu.bore(1) / 2, z.pcu, pin_tip, z.pcu, pin_tip, z.pcu + G.b.pcu, 20, z.pcu + G.b.pcu, ...
     20, z.nut_mid(1), rj_mid, z.nut_mid(1), rj_mid, z.wf, 33, z.wf, 33, 12, 24, 12, 24, -28, ...
     G.d_shaft.mid_i / 2, -28, G.d_shaft.mid_i / 2, -150, ad.pcu.bore(1) / 2, -150], ...
    st, 1, [ad.pcu.z(1) ad.pcu.m ad.pcu.x(1) z.pcu G.b.pcu]);
add('sun_quill', 'planetary', 'Sun quill shaft 50/30 mm, fixed spline in the intermediate shaft, crowned spline in the sun', ...
    [15, -26, 24, -26, 24, 12, 25, 12, 25, 36, 24, 36, 24, 92, 15, 92], st, 1);
pj = brg('NU2209') * [0.5; 0; 0];                      % pinion journals at the NU 2209 / QJ 209 bore (22.5)
L.pinion = struct('lj_f', z.wf - 1 - (z.g2 + G.b.s1), 'lj_r', z.g2 - (z.rear - 8), 'lj_seat', z.g2 - z.nut_pt(1), ...
                  'r_seat', pj, 'r_end', 20);
g_tip = G.r_tip.osg_pin;
d6305 = brg('6305');  d6202 = brg('6202');  d6203 = brg('6203');
sg = d6305(1) / 2;  so = d6202(1) / 2;  sp = d6203(1) / 2;   % accessory shaft journals (12.5, 7.5, 8.5)
add('gen_shaft', 'accessories', sprintf('Generator shaft with the OSG pinion z %d m %g (one piece with the generator gear)', ...
    ad.osg.z(1), ad.osg.m), ...
    [7.5, z.rear, sg, z.rear, sg, z.gen, ad.gen.bore / 2, z.gen, ad.gen.bore / 2, z.gen + G.b.gen, ...
     sg, z.gen + G.b.gen, sg, z.osg, g_tip, z.osg, g_tip, z.osg + G.b.osg, sg, z.osg + G.b.osg, ...
     sg, z.bf + d6305(3) / 2 + 1, 0, z.bf + d6305(3) / 2 + 1, 0, z.c - 30, 7.5, z.c - 30], ...
    st, 1, [ad.osg.z(1) ad.osg.m ad.osg.x(1) z.osg G.b.osg]);
add('gen_cartridge', 'accessories', 'Generator bearing cartridge and pad, withdraws to the engine side with the gear-shaft (MNT-02)', ...
    [r_gen, z.br + d6305(3) / 2 + 1, r_cart, z.br + d6305(3) / 2 + 1, r_cart, z.rear, 80, z.rear, 80, z.rear - 8, ...
     14, z.rear - 8, 14, z.rear - 4, r_gen, z.rear - 4], in.rho.A357, 1);   % A357 with a steel seat liner
osg_tip = G.r_tip.osg;
add('osg_gear', 'accessories', sprintf('OSG gear z %d m %g with its shaft', ad.osg.z(2), ad.osg.m), ...
    [ad.osg.bore(2) / 2, z.osg, osg_tip, z.osg, osg_tip, z.osg + G.b.osg, so, z.osg + G.b.osg, so, 12, ...
     ad.osg.bore(2) / 2, 12], st, 1, [ad.osg.z(2) ad.osg.m ad.osg.x(2) z.osg G.b.osg]);
add('osg_adapter', 'accessories', 'OSG pad adapter with the outer OSG shaft bearing', ...
    [r_osg, 0, 40, 0, 40, 16, 6, 16, 6, 13, r_osg, 13], st, 1);
pcu_tip = G.r_tip.pcu;
add('pcu_gear', 'accessories', sprintf('PCU gear z %d m %g with its shaft', ad.pcu.z(2), ad.pcu.m), ...
    [ad.pcu.bore(2) / 2, z.wr - 1, sp, z.wr - 1, sp, z.pcu + G.b.pcu, pcu_tip, z.pcu + G.b.pcu, ...
     pcu_tip, z.pcu, sp, z.pcu, sp, z.cov(1) - 1, ad.pcu.bore(2) / 2, z.cov(1) - 1], ...
    st, 1, [ad.pcu.z(2) ad.pcu.m ad.pcu.x(2) z.pcu G.b.pcu]);
add('pcu_adapter', 'accessories', 'PCU pad adapter', ring(r_pcu, 45, z.cov(1) - 12, z.cov(1)), st, 1);
add('pump_pack', 'accessories', sprintf('Supply and scavenge pump pack envelope (step 2.7), %g kg (TBR)', in.pump.m), ...
    ring(ad.pcu.bore(1) / 2, in.pump.D / 2, z.pump(1), z.pump(2)), st, NaN);   % bore takes the pump quill
% quills with their shear necks (step 2.6): [r_body r_neck z1 z2 z_neck]
qd = {'gen', ad.gen.bore / 2 - 0.6, 10.5 / 2, z.rear - 28, z.br, z.rear - 14; ...
      'osg', ad.osg.bore(2) / 2 - 0.1, 2.5, z.osg + 2, 40, 22; ...
      'pcu', ad.pcu.bore(2) / 2 - 0.1, 2.5, z.cov(1) - 30, z.pcu, z.cov(1) - 20; ...
      'pump', ad.pcu.bore(1) / 2 - 0.1, 2.5, z.pump(1) + 10, z.pcu + 20, z.pump(2) + 2};
for k = 1:size(qd, 1)
    [nm, rq, rn, q1, q2, qn] = qd{k, :};
    add(['quill_' nm], 'accessories', sprintf('%s pad quill, shear neck %g mm', upper(nm), 2 * rn), ...
        [0, q1, rq, q1, rq, qn - 3, rn, qn - 3, rn, qn + 3, rq, qn + 3, rq, q2, 0, q2], st, 1);
end
% planetary module additions
ze = 550;                                              % propeller flange face (shaft end), PIF-01 TBD
qjh = in.qjh;
add('qj_housing', 'planetary', 'Four-point contact propeller bearing housing on the case nose, Ti-6Al-4V', ...
    [90, z.nose, qjh.flange(1), z.nose, qjh.flange(1), z.nose + qjh.flange(2), 90 + qjh.t, z.nose + qjh.flange(2), ...
     90 + qjh.t, z.nose + 66, 80, z.nose + 66, 80, z.nose + 28, 90, z.nose + 28], in.rho.Ti, 1);
pf = in.pflange;
add('prop_flange', 'planetary', sprintf('Propeller flange placeholder (PIF-01 TBD): %g mm, %d x %g holes on PCD %g', ...
    pf.D, pf.n, pf.d_hole, pf.pcd), ...
    [G.d_shaft.prop / 2, ze - pf.t - pf.hub_L, pf.hub_D / 2, ze - pf.t - pf.hub_L, pf.hub_D / 2, ze - pf.t, ...
     pf.D / 2, ze - pf.t, pf.D / 2, ze, G.d_shaft.prop / 2, ze], st, 1, [], [pf.n pf.pcd pf.d_hole]);
tb = sb.ret.tube;
add('ret_tube', 'planetary', sprintf('Ti-6Al-4V propeller retention tube %g/%g x %g mm', tb.d_o, tb.d_i, tb.L), ...
    ring(tb.d_i / 2, tb.d_o / 2, in.ret_tube_z0, in.ret_tube_z0 + tb.L), in.rho.Ti, 1);
% customer equipment (not RGB mass)
uz = struct('generator', z.rear - 8, 'OSG', 16, 'PCU', z.cov(1) - 12);
usg = struct('generator', -1, 'OSG', 1, 'PCU', -1);
for k = 1:numel(in.unit)
    u = in.unit(k);
    z1 = uz.(u.name);  z2 = z1 + usg.(u.name) * u.DL(2);
    add(['unit_' u.name], 'equipment', sprintf('%s envelope %g x %g mm (TBD, not RGB mass)', u.name, u.DL), ...
        ring(10, u.DL(1) / 2, min(z1, z2), max(z1, z2)), st, 0);      % bore 20 takes the quill
end
L.rev = rev;
L.rollers = struct('n', 18, 'r_pitch', (G.planet_bore + G.d_pin) / 4, 'r_roller', sb.planet.Dw / 2 - 0.005, ...
                   'z0', sb.planet.L_ends / 2, 'L', gi.s2.b - sb.planet.L_ends);
zc0 = 30 - in.carr.plate_t;                            % rear face of the rear plate: its inner face stays at z 30
L.carrier = struct('ze', ze - zc0, 'n_sc', in.carr.n_sc, 'r_sc', in.carr.r_sc, 'R_sc', in.carr.R_sc);

% ------------------------------------------------------------ gear phases
s1 = gi.s1;  s2 = gi.s2;
k2 = tand(s1.beta) / (s1.mn / cosd(s1.beta) * s1.z2 / 2) * 180 / pi;    % helix twist of gear 2 [deg/mm]
kg = tand(s1.beta) / (s1.mn / cosd(s1.beta) * ad.gen.z / 2) * 180 / pi;
% generator gear (right hand) on gear 2 (left hand, rotation 0, start z.g2), matched in the plane z.gen
A_eff = 0 - (z.gen - z.g2 + 2) * k2;
B_eff = mesh_rot(A_eff, a.theta_g, s1.z2, ad.gen.z);
rot_gen = B_eff - 2 * kg;
% OSG pinion on the generator shaft (rotation rot_gen) and the OSG gear
rot_osg = mesh_rot(rot_gen, a.theta_o, ad.osg.z(1), ad.osg.z(2));
% PCU pinion on the intermediate shaft (rotation 0) and the PCU gear
rot_pcu = mesh_rot(0, a.theta_p, ad.pcu.z(1), ad.pcu.z(2));

% ------------------------------------------------------------ instances [part module rot x y z]
I = {};
    function put(part, module, rot, x, y, zz)
        I(end + 1, :) = {part, module, rot, x, y, zz};
    end
P = 'planetary';  F = 'first_stage';  A = 'accessories';  E = 'equipment';
zp0 = 36;                                              % planetary gears start (step 2.9 assembly)
put('case', P, 0, 0, 0, 0);
put('ring', P, phase(s2.zr, 0.756), 0, 0, zp0);
put('carrier', P, 0, 0, 0, zc0);
put('sun', P, phase(s2.zs, 2), 0, 0, zp0);
put('sun_quill', P, 0, 0, 0, 0);
for i = 0:s2.N - 1
    th = 360 * i / s2.N;
    ph = 2.432 + th * (s2.zs + s2.zp) / s2.zp;
    put('planet', P, phase(s2.zp, ph), G.a_planet * cosd(th), G.a_planet * sind(th), zp0);
    put('planet_rollers', P, 0, G.a_planet * cosd(th), G.a_planet * sind(th), zp0);
end
put('brg_NU1024', P, 0, 0, 0, 134);
put('brg_NU1024', P, 0, 0, 0, z.prop_out + 1);
put('brg_QJ1024', P, 0, 0, 0, z.nose);
put('qj_housing', P, 0, 0, 0, 0);
put('nut_KM24', P, 0, 0, 0, z.nose + 28);
put('seal_prop', P, 0, 0, 0, z.nose + 50);
put('ret_tube', P, 0, 0, 0, 0);
put('prop_flange', P, 0, 0, 0, 0);
put('fs_case', F, 0, 0, 0, 0);
put('gear2', F, 0, 0, 0, z.g2);
put('pinion', F, phase(s1.z1, 180 / s1.z1), PT(1), PT(2), z.g2);
put('mid_shaft', F, 0, 0, 0, 0);
for zz = [z.bf z.br]
    put('brg_NU2210', F, 0, 0, 0, zz - B_crb / 2);
    put('brg_NU2209', F, 0, PT(1), PT(2), zz - B_crb / 2);
end
put('brg_QJ210', F, 0, 0, 0, z.qj_mid(1));
put('brg_QJ209', F, 0, PT(1), PT(2), z.qj_pt(1));
put('nut_KM10', F, 0, 0, 0, z.nut_mid(1));
put('nut_KM9', F, 0, PT(1), PT(2), z.nut_pt(1));
put('seal_input', F, 0, PT(1), PT(2), z.rear - 10);
put('acc_cover', A, 0, 0, 0, 0);
put('gen_gear', A, rot_gen, Gp(1), Gp(2), z.gen);
put('gen_shaft', A, rot_gen, Gp(1), Gp(2), 0);
put('gen_cartridge', A, 0, Gp(1), Gp(2), 0);
put('brg_6305', A, 0, Gp(1), Gp(2), z.bf - hb6305);
put('brg_6305', A, 0, Gp(1), Gp(2), z.br - hb6305);
put('seal_gen', A, 0, Gp(1), Gp(2), z.br - hb6305 - 23);
put('quill_gen', A, 0, Gp(1), Gp(2), 0);
put('osg_gear', A, rot_osg, Op(1), Op(2), 0);
put('osg_adapter', A, 0, Op(1), Op(2), 0);
put('brg_6202', A, 0, Op(1), Op(2), z.wf + 0.5);
put('brg_6202', A, 0, Op(1), Op(2), 2);
put('quill_osg', A, 0, Op(1), Op(2), 0);
put('pcu_gear', A, rot_pcu, Pp(1), Pp(2), 0);
put('pcu_adapter', A, 0, Pp(1), Pp(2), 0);
put('brg_6203', A, 0, Pp(1), Pp(2), z.rear);
put('brg_6203', A, 0, Pp(1), Pp(2), z.cov(1));
put('quill_pcu', A, 0, Pp(1), Pp(2), 0);
put('pump_pack', A, 0, 0, 0, 0);
put('quill_pump', A, 0, 0, 0, 0);
put('unit_generator', E, 0, Gp(1), Gp(2), 0);
put('unit_OSG', E, 0, Op(1), Op(2), 0);
put('unit_PCU', E, 0, Pp(1), Pp(2), 0);
L.inst = cell2table(I, 'VariableNames', {'part', 'module', 'rot', 'x', 'y', 'z'});
L.rot = struct('gen', rot_gen, 'osg', rot_osg, 'pcu', rot_pcu);
end

function rz = ring(r1, r2, z1, z2)
rz = [r1, z1, r2, z1, r2, z2, r1, z2];
end

function p = phase(zt, deg)
% the same tooth position, reduced to one pitch
pt = 360 / zt;
p = deg - pt * floor(deg / pt);
end

function rB = mesh_rot(rA, phi, zA, zB)
% Rotation of gear B in mesh with gear A (rotation rA) on the line of centres at angle phi (from A to
% B). Both gears have a tooth space on their +Y axis at rotation 0. Reference: A with a space at phi,
% B with a tooth at phi + 180; A turned on by d turns B back by d zA / zB.
d = rA - (phi - 90);
rB = phase(zB, (phi + 180 - 90 - 180 / zB) - d * zA / zB);
end
