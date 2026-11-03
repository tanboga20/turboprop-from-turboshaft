function P = cx_export(out_dir)
%CX_EXPORT  Write the design values the CATIA part scripts read (cad/params/*.txt).
%   P = cx_export()          writes to cad/params
%   P = cx_export(out_dir)
%
%   Runs from the repo root with calc/gear_detail, calc/shafts_bearings,
%   calc/accessory and calc/housing on the path. One "key = value" file per
%   part, read by LoadParams in cad/scripts/catlib.vbs: gear data from the
%   step 2.4 and 2.6 designs (tooth numbers, modules, helix, profile shifts,
%   face widths, rims, webs, bores), the planet bearing bore, the shafts and
%   the carrier of step 2.5, the case section of step 2.8 as a profile of
%   lines and fillet arcs (rows [type r1 z1 r2 z2 cr cz], type 0 line, 1
%   arc about (cr, cz)) with its flange bolt holes. Lengths in mm, angles in
%   degrees, numbers with a "." decimal point. Output P: struct of the
%   written parameter sets.
%   Step 3.1 adds the complete model (calc/assembly on the path): the
%   first-stage case, the accessory cover, the revolved parts (shafts,
%   accessory gears, bearing, nut and seal envelopes, quills, retention
%   tube, propeller flange placeholder), the planet roller sets and the
%   instance list of the three-module assembly (as_export), the pinion
%   journals at the bearing seats and the carrier shaft end and plate
%   scallops.
%   Source: Phase 2 report, Section 2.9 ("CATIA models"); Phase 3 report,
%   Section 3.1.

if nargin < 1 || isempty(out_dir)
    out_dir = fullfile('cad', 'params');
end
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
gi = gd_inputs();
M = gd_meshes(gi);
ad = ad_inputs();
A = ad_meshes(ad, gi);
hs = hs_inputs();
sb = sb_inputs();
s1 = gi.s1;  s2 = gi.s2;
as_in = as_inputs();
L = as_layout(as_in, as_geom(as_in, gi, ad, sb), gi, ad, sb);

P.pinion = struct('z', s1.z1, 'mn', s1.mn, 'beta', s1.beta, 'hand_right', 1, 'x', s1.x1, 'b', s1.b, ...
                  'alpha_n', gi.alpha_n, 'bore', gi.d_bore_pinion, 'd_tip', M(1).g.da1, 'd_root', M(1).g.df1, ...
                  'lj_f', L.pinion.lj_f, 'lj_r', L.pinion.lj_r, 'lj_seat', L.pinion.lj_seat, ...
                  'r_seat', L.pinion.r_seat, 'r_end', L.pinion.r_end);
P.gear2 = struct('z', s1.z2, 'mn', s1.mn, 'beta', s1.beta, 'hand_right', 0, 'x', s1.x2, 'b', s1.b, ...
                 'alpha_n', gi.alpha_n, 'rim', gi.gear2_rim * s1.mn, 'web', gi.gear2_web, 'hub_d', gi.gear2_hub_d, ...
                 'bore', sb.shafts(2).d_o, 'hub_len', 40, 'd_tip', M(1).g.da2, 'd_root', M(1).g.df2);
P.sun = struct('z', s2.zs, 'm', s2.m, 'x', s2.xs, 'b', s2.b, 'alpha_n', gi.alpha_n, 'bore', gi.sun_bore, ...
               'd_tip', M(2).g.da2, 'd_root', M(2).g.df2);
P.planet = struct('z', s2.zp, 'm', s2.m, 'x', s2.xp, 'b', s2.b, 'alpha_n', gi.alpha_n, 'bore', M(2).D_or, ...
                  'd_tip', M(2).g.da1, 'd_root', M(2).g.df1);
P.ring = struct('z', s2.zr, 'm', s2.m, 'x', s2.xr, 'ha', s2.ha_r, 'b', s2.b, 'alpha_n', gi.alpha_n, ...
                'rim', gi.ring_rim * s2.m, 'd_tip', M(3).g.da2, 'd_root', M(3).g.df2);
c = gi.carrier;
P.carrier = struct('a', M(2).g.a_w, 'n_planets', s2.N, 'L_pin', c.L_pin, 'post_w', c.post_w, 'post_t', c.post_t, ...
                   'd_pin', M(2).D_or - 2 * 7.5, 'plate_t', as_in.carr.plate_t, 'plate_d', 2 * (M(2).g.a_w + 30), ...
                   'ze', L.carrier.ze, 'n_sc', L.carrier.n_sc, 'r_sc', L.carrier.r_sc, 'R_sc', L.carrier.R_sc, ...
                   'pin_bore', as_in.carr.pin_bore);
P.gen_gear = struct('z', ad.gen.z, 'mn', s1.mn, 'beta', s1.beta, 'hand_right', 1, 'x', ad.gen.x, 'b', ad.gen.b, ...
                    'alpha_n', gi.alpha_n, 'hub_d', ad.gen.hub_d, 'bore', ad.gen.bore, 'a_w', A(1).g.a_w);
P.osg = struct('z1', ad.osg.z(1), 'z2', ad.osg.z(2), 'm', ad.osg.m, 'x1', ad.osg.x(1), 'x2', ad.osg.x(2), ...
               'b', ad.osg.b, 'a_w', A(2).g.a_w, 'hub_d', ad.osg.hub_d, 'bore', ad.osg.bore(2));
P.pcu = struct('z1', ad.pcu.z(1), 'z2', ad.pcu.z(2), 'm', ad.pcu.m, 'x1', ad.pcu.x(1), 'x2', ad.pcu.x(2), ...
               'b', ad.pcu.b, 'a_w', A(3).g.a_w, 'hub_d', ad.pcu.hub_d, 'bore', ad.pcu.bore(2));
seg = case_profile(hs.case.rects, hs.case.rf)';
P.case = struct('n_segs', size(seg, 2), 'segs', seg(:)', 'n_bolts', hs.flange.n, 'pcd', 290, 'd_hole', 6.6, ...
                'flange_t', 12);
P.layout = struct('a_s1', M(1).g.a_w, 'a_planet', M(2).g.a_w);

names = fieldnames(P);
for k = 1:numel(names)
    s = P.(names{k});
    fid = fopen(fullfile(out_dir, [names{k} '.txt']), 'w');
    fprintf(fid, '# %s: written by calc/cad_export/cx_export.m, do not edit\n', names{k});
    fn = fieldnames(s);
    for j = 1:numel(fn)
        v = s.(fn{j});
        fprintf(fid, '%s = %s\n', fn{j}, strjoin(compose('%.6g', v), ' '));
    end
    fclose(fid);
end
as_export(L, out_dir);
end

function seg = case_profile(sec, rf)
% Closed profile of the case section with its cast fillets: rows [type r1 z1 r2 z2 cr cz]
[~, ~, C, Q] = hs_section(sec, rf, [], 1e3);
pts = zeros(0, 5);                                     % [r z arc-to-next cr cz]
for i = 1:size(Q, 1)
    k = find(all(abs(C(:, 1:2) - Q(i, :)) < 1e-9, 2) & C(:, 5) > 0, 1);
    if isempty(k)
        pts(end + 1, :) = [Q(i, :), 0, 0, 0]; %#ok<AGROW>
    else
        pts(end + 1, :) = [C(k, 6:7), 1, C(k, 3:4)]; %#ok<AGROW>
        pts(end + 1, :) = [C(k, 8:9), 0, 0, 0]; %#ok<AGROW>
    end
end
n = size(pts, 1);
seg = zeros(n, 7);
for j = 1:n
    q = pts(mod(j, n) + 1, :);
    seg(j, :) = [pts(j, 3), pts(j, 1:2), q(1:2), pts(j, 4:5)];
end
end
