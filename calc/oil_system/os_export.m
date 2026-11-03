function H = os_export(in, N, L, out_dir)
%OS_EXPORT  Oil system hardware for CATIA: parts (cad/params/oil_revolved.txt) and instances (oil_assembly.txt).
%   H = os_export(in, N, L, out_dir)
%
%   in = os_inputs, N = os_network, L = as_layout. Every part is revolved
%   about its own Z axis and placed with its Z axis along a direction:
%     jets: a nozzle 6 mm across and 10 mm long per jet bore, its tip at the
%       jet position, aimed at the target (module lubrication);
%     galleries and drillings: the oil volume as a rod along each straight
%       piece of the routes (they lie inside the castings: the clash check
%       lists them as passages, and they are cut into the case drawings in
%       step 3.9);
%     carrier transfer sleeve (two grooves: lube oil, pitch oil), pitch oil
%       tube on the axis, pressure regulating and thermostatic valves at the
%       manifold, filter, two chip detectors, oil debris monitor, sampling
%       valve; the tank beside the accessory cover (equipment, TBD).
%   Writes out_dir/oil_revolved.txt (format of revolved.txt) and
%   out_dir/oil_assembly.txt (i<k> = part module rot x y z Xx Xy Xz Yx Yy Yz
%   Zx Zy Zz: the part's axes in the RGB frame) and out_dir/oil_network.txt
%   (the galleries and jets, for the Python reference). Output H: part names,
%   instance cell array.
%   Source: Phase 3 report, Section 3.2 ("Hardware").

P = struct('name', {}, 'desc', {}, 'rz', {});
I = {};
    function addp(name, desc, rz)
        if ~any(strcmp({P.name}, name))
            P(end + 1) = struct('name', name, 'desc', desc, 'rz', rz);
        end
    end
    function put(part, module, pos, zdir)
        zdir = zdir(:)' / norm(zdir);
        t = cross(zdir, [0 0 1]);
        if norm(t) < 1e-6, t = [1 0 0]; else, t = t / norm(t); end
        x = t;  y = cross(zdir, x);
        I(end + 1, :) = {part, module, [0 pos x y zdir]};
    end
rod = @(r, len) [0, 0, r, 0, r, len, 0, len];
ring = @(r1, r2, z1, z2) [r1, z1, r2, z1, r2, z2, r1, z2];
z = L.z;  a = L.ang;
% jets (nozzles; the planet pin and quill feeds are orifices drilled in the part, no nozzle)
B = N.branch;
for k = 1:numel(B)
    if ~B(k).catia, continue, end
    for j = 1:numel(B(k).jet)
        jj = B(k).jet(j);
        if ~jj.nozzle, continue, end
        nm = sprintf('oil_jet_%03d', round(jj.d * 100));
        addp(nm, sprintf('Oil jet nozzle, bore %.2f mm, with last-chance strainer', jj.d), ring(jj.d / 2, 3, 0, 10));
        put(nm, 'lubrication', jj.pos - 10 * jj.aim, jj.aim);
    end
end
% external tubes (route) and drillings (feed) of each branch: one part of rods (the oil volume) in RGB
% coordinates, built by cad/scripts/oilroutes.vbs from oil_routes.txt
R = struct('name', {}, 'desc', {}, 'rods', {});
for k = 1:numel(B)
    if ~B(k).catia, continue, end
    rods = zeros(0, 7);
    rt = B(k).route;
    for s = 1:size(rt, 1) - 1
        if norm(rt(s + 1, :) - rt(s, :)) >= 1, rods(end + 1, :) = [rt(s, :) rt(s + 1, :) B(k).d_gal / 2]; end %#ok<AGROW>
    end
    for j = 1:numel(B(k).jet)
        fd = B(k).jet(j).feed;
        for s = 1:size(fd, 1) - 1
            if norm(fd(s + 1, :) - fd(s, :)) >= 1, rods(end + 1, :) = [fd(s, :) fd(s + 1, :) in.d_branch / 2]; end %#ok<AGROW>
        end
    end
    nm = sprintf('oil_route_%02d', k);
    R(end + 1) = struct('name', nm, 'desc', sprintf('Oil route (oil volume): %s; tube %.0f mm, drillings %.0f mm bore', ...
                        B(k).name, B(k).d_gal, in.d_branch), 'rods', rods); %#ok<AGROW>
    put(nm, 'lubrication', [0 0 0], [0 0 1]);
end
% carrier transfer sleeve and pitch oil tube
t = in.transfer;
addp('oil_transfer_sleeve', 'Carrier oil transfer sleeve: lube oil and pitch oil grooves, piston-ring seals', ...
     [t.r_in, t.z(1), 60, t.z(1), 60, t.z(1) + 2, t.r_out, t.z(1) + 2, t.r_out, t.z(2), t.r_in, t.z(2)]);
put('oil_transfer_sleeve', 'lubrication', [0 0 0], [0 0 1]);
pt = in.pitch;
addp('oil_pitch_tube', 'Pitch oil transfer tube on the propeller axis (PIF-02 TBD)', ...
     ring(pt.d_tube(1) / 2, pt.d_tube(2) / 2, pt.z_tube(1), pt.z_tube(2)));
put('oil_pitch_tube', 'lubrication', [0 0 0], [0 0 1]);
% manifold valves and filter: on the outward normal of the case wall at the manifold
M = N.M;
nM = [M(1:2) 0] / norm(M(1:2));
addp('oil_prv', 'Pressure regulating valve, 550 kPa', rod(15, 50));
put('oil_prv', 'lubrication', M, nM);
addp('oil_thermostat', 'Thermostatic cooler loop valve, closes the loop below 60 degC', rod(20, 60));
put('oil_thermostat', 'lubrication', M + [0 0 45], nM);
addp('oil_filter', 'Oil filter, 3 um, bypass valve and impending-bypass indicator (LUB-05)', rod(35, 120));
put('oil_filter', 'lubrication', M + [0 0 -50], nM);
% chip detectors (first-stage sump bottom, planetary case bottom), oil debris monitor, sampling valve
addp('oil_chip_detector', 'Magnetic chip detector with electrical indication (LUB-05)', rod(10, 25));
put('oil_chip_detector', 'lubrication', N.chip{1}, [0 1 0]);
put('oil_chip_detector', 'lubrication', N.chip{2}, [0 1 0]);
addp('oil_odm', 'Oil debris monitor in the scavenge line (CTL-03, decision 7)', rod(25, 100));
put('oil_odm', 'lubrication', N.odm, [0 0 1]);
addp('oil_sample_valve', 'Oil sampling valve (MNT-02)', rod(8, 30));
put('oil_sample_valve', 'lubrication', N.sample, [0 1 0]);
% oil tank beside the accessory cover (airframe side of SYS-06, position TBD)
addp('oil_tank', 'RGB oil tank envelope, 6.8 L (step 2.7), within 150 mm of the pump inlet (TBD)', rod(100, 220));
put('oil_tank', 'equipment', N.tank, [0 0 1]);
% LUB-07 emergency air-oil mist system (Hamit's decision): 6 min at 75% MCP, a sub-product of its
% own (module lub07_mist): accumulator and shut-off/mixing valve on the left of the
% first-stage case, a tie-in tube to the oil manifold (the existing tubes and jets carry the mist), and the
% bleed-air line towards the core along the tunnel (bleed tap on the compressor TBD in installation C)
ma = in.mist_hw;
% positions from the manifold: the tie-in enters the outer end of the regulating valve body at its own height
% (the filter hangs below it, the thermostatic valve above); the mixing valve stands ma.offset to the side
% (tangential), the accumulator below it, the bleed line leaves the valve side outwards and runs to the core
tM = [-nM(2) nM(1) 0];
Pv = M + 50 * nM;                                      % outer end of the regulating valve body
P1 = Pv + ma.offset * tM;
addp('lub07_valve', 'LUB-07 mist system: shut-off and air-oil mixing valve, opened by the low-oil-pressure switch', ...
     rod(ma.valve(1) / 2, ma.valve(2)));
put('lub07_valve', 'lub07_mist', P1 - [0 0 ma.valve(2)], [0 0 1]);
addp('lub07_accumulator', 'LUB-07 mist system: emergency oil accumulator, 0.28 L (6 min at 1 mL/min per contact x 1.5)', ...
     rod(ma.acc(1) / 2, ma.acc(2)));
put('lub07_accumulator', 'lub07_mist', P1 - [0 0 ma.valve(2) + 30 + ma.acc(2)], [0 0 1]);   % clear of the filter end
pb = P1 + [0 0 -ma.valve(2) / 2] + ma.valve(1) / 2 * nM;
R(end + 1) = struct('name', 'lub07_lines', 'desc', ...
    'LUB-07 mist system: tie-in to the oil manifold and bleed-air line towards the core (bleed tap TBD)', ...
    'rods', [P1, Pv, ma.d_tie / 2; P1 - [0 0 ma.valve(2) + 30], P1 - [0 0 ma.valve(2)], ma.d_tie / 2; ...
             pb, pb + 40 * nM, ma.d_bleed / 2; pb + 40 * nM, [pb(1:2) + 40 * nM(1:2), ma.z_bleed_end], ma.d_bleed / 2]);
put('lub07_lines', 'lub07_mist', [0 0 0], [0 0 1]);

% files
num = @(v) strjoin(compose('%.6g', v(:)'), ' ');
fid = fopen(fullfile(out_dir, 'oil_revolved.txt'), 'w');
fprintf(fid, '# oil_revolved: written by calc/oil_system/os_export.m, do not edit\n');
fprintf(fid, 'names = %s\n', strjoin({P.name}, ' '));
for k = 1:numel(P)
    fprintf(fid, '%s.desc = %s\n%s.rz = %s\n', P(k).name, P(k).desc, P(k).name, num(P(k).rz));
end
fclose(fid);
fid = fopen(fullfile(out_dir, 'oil_routes.txt'), 'w');
fprintf(fid, '# oil_routes: written by calc/oil_system/os_export.m, do not edit\n');
fprintf(fid, '# rod<i> = x1 y1 z1 x2 y2 z2 r [mm], RGB coordinates\n');
fprintf(fid, 'names = %s\n', strjoin({R.name}, ' '));
for k = 1:numel(R)
    fprintf(fid, '%s.desc = %s\n%s.n = %d\n', R(k).name, R(k).desc, R(k).name, size(R(k).rods, 1));
    for s = 1:size(R(k).rods, 1)
        fprintf(fid, '%s.rod%d = %s\n', R(k).name, s, num(R(k).rods(s, :)));
    end
end
fclose(fid);
fid = fopen(fullfile(out_dir, 'oil_assembly.txt'), 'w');
fprintf(fid, '# oil_assembly: written by calc/oil_system/os_export.m, do not edit\n');
fprintf(fid, '# i<k> = part module rotation x y z, then the part axes X, Y, Z in the RGB frame\n');
fprintf(fid, 'n = %d\n', size(I, 1));
for k = 1:size(I, 1)
    fprintf(fid, 'i%d = %s %s %s\n', k, I{k, 1}, I{k, 2}, num(I{k, 3}));
end
fclose(fid);
% the network itself (read by calc/reference/step32_reference.py): per branch the gallery and its jets
fid = fopen(fullfile(out_dir, 'oil_network.txt'), 'w');
fprintf(fid, '# oil_network: written by calc/oil_system/os_export.m, do not edit\n');
fprintf(fid, '# branch<k> = L_gal d_gal n_bend rotating r_rot n_jets; jet<k>_<j> = d L_drill Q_design r_xy Q_nom nozzle\n');
fprintf(fid, 'n_branch = %d\nd_pcu = %.6g\nd_leak = %.6g\nd_branch = %.6g\n', numel(B), N.d_pcu, N.d_leak, in.d_branch);
for k = 1:numel(B)
    fprintf(fid, 'branch%d = %s\n', k, num([B(k).L_gal B(k).d_gal B(k).n_bend B(k).rotating B(k).r_rot numel(B(k).jet)]));
    for j = 1:numel(B(k).jet)
        jj = B(k).jet(j);
        fprintf(fid, 'jet%d_%d = %s\n', k, j, num([jj.d jj.L_drill jj.Q_design norm(jj.pos(1:2)) jj.Q_nom ...
                                                  jj.nozzle * B(k).catia]));
    end
end
fclose(fid);
H = struct('parts', {[{P.name} {R.name}]}, 'inst', {I});
end
