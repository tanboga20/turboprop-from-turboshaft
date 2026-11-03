function G = as_geom(in, gi, ad, sb)
%AS_GEOM  Sizes the step 3.1 layout takes from the Phase 2 designs.
%   G = as_geom(in, gi, ad, sb)
%
%   in = as_inputs, gi = gd_inputs, ad = ad_inputs, sb = sb_inputs. Tip
%   radii of every gear (step 2.4 and 2.6 pairs), centre distances, bearing
%   envelopes by name and the radii of the case and cover outlines built
%   from them (gear tip + gap + wall, bearing + boss). Lengths in mm.
%   Source: Phase 3 report, Section 3.1 ("Layout").

M = gd_meshes(gi);
A = ad_meshes(ad, gi);
G.a_s1 = M(1).g.a_w;                        % pinion (PT axis) to propeller axis
G.a_gen = A(1).g.a_w;                       % generator gear to propeller axis
G.a_osg = A(2).g.a_w;                       % OSG gear to generator axis
G.a_pcu = A(3).g.a_w;                       % PCU gear to propeller axis
G.a_planet = M(2).g.a_w;                    % planet axes to propeller axis
G.planet_bore = M(2).D_or;                  % planet bore = outer race of the planet bearing (step 2.5)
G.d_pin = M(2).D_or - 2 * sb.planet.Dw;     % pin = inner race
G.r_tip = struct('pinion', M(1).g.da1 / 2, 'gear2', M(1).g.da2 / 2, 'gen', A(1).g.da1 / 2, ...
                 'osg_pin', A(2).g.da1 / 2, 'osg', A(2).g.da2 / 2, 'pcu_pin', A(3).g.da1 / 2, 'pcu', A(3).g.da2 / 2);
G.b = struct('s1', gi.s1.b, 'gen', ad.gen.b, 'osg', ad.osg.b, 'pcu', ad.pcu.b);
G.brg = containers.Map();
for k = 1:numel(in.brg)
    G.brg(in.brg(k).name) = in.brg(k).dDB;
end
% bearing names on each axis (steps 2.5 and 2.6: two roller bearings and a radially free four-point
% contact bearing on the input and intermediate shafts, a deep groove pair on each accessory shaft)
G.axis_brg = struct('mid', {{'NU2210', 'QJ210'}}, 'pt', {{'NU2209', 'QJ209'}}, 'gen', '6305', 'osg', '6202', ...
                    'pcu', '6203', 'prop', {{'NU1024', 'QJ1024'}});
G.d_shaft = struct('mid', sb.shafts(2).d_o, 'mid_i', sb.shafts(2).d_i, 'pt', sb.shafts(1).d_o, ...
                   'pt_i', sb.shafts(1).d_i, 'prop', sb.shafts(4).d_o, 'prop_i', sb.shafts(4).d_i);
w = in.wall_side;  gp = in.gap_gear;
% outline radii: [cavity outer]; cavity = gear tip + gap (or bearing seat + boss), outer = cavity + wall
v = G.brg('NU2209');
G.R_fs = struct('prop', G.r_tip.gear2 + gp + [0 w], ...
                'pt', v(2) / 2 + in.boss + [0 w], ...
                'gen', G.r_tip.gen + gp + [0 w], ...
                'osg', G.r_tip.osg + gp + [0 w]);
G.R_cov = struct('prop', in.pump.D / 2 + gp + [0 w], 'pcu', G.r_tip.pcu + gp + [0 w]);
G.R_flange = 153.5;                         % planetary case attachment flange (step 2.8 section)
G.r_unit = containers.Map({in.unit.name}, cellfun(@(v) v(1) / 2, {in.unit.DL}, 'UniformOutput', false));
G.L_unit = containers.Map({in.unit.name}, cellfun(@(v) v(2), {in.unit.DL}, 'UniformOutput', false));
end
