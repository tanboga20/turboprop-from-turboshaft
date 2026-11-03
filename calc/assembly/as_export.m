function as_export(L, out_dir)
%AS_EXPORT  Write the step 3.1 layout for the CATIA scripts (cad/params).
%   as_export(L, out_dir)
%
%   L = as_layout. Files, "key = value" lines read by LoadParams in
%   cad/scripts/catlib.vbs (numbers with a "." decimal point):
%     revolved.txt   names, then per part <name>.desc, .rz (closed r, z
%                    polyline), .teeth (spur: z m x z0 b), .holes (n pcd d)
%     fs_case.txt, acc_cover.txt   outline and cavity (as_hull segs rows
%                    [type x1 y1 x2 y2 cx cy]) with their z ranges, pads
%                    and pockets [x y r z1 z2], holes [cx cy pcd d n z1 z2]
%     rollers.txt    planet roller set
%     assembly.txt   n, then i<k> = part module rot x y z
%   Called by calc/cad_export/cx_export. Source: Phase 3 report, Section 3.1.

num = @(v) strjoin(compose('%.6g', v(:)'), ' ');
fid = fopen(fullfile(out_dir, 'revolved.txt'), 'w');
fprintf(fid, '# revolved: written by calc/cad_export/cx_export.m (calc/assembly/as_export.m), do not edit\n');
fprintf(fid, 'names = %s\n', strjoin({L.rev.name}, ' '));
for k = 1:numel(L.rev)
    r = L.rev(k);
    fprintf(fid, '%s.desc = %s\n', r.name, r.desc);
    fprintf(fid, '%s.rz = %s\n', r.name, num(r.rz));
    fprintf(fid, '%s.module = %s\n', r.name, r.module);
    if ~isempty(r.teeth), fprintf(fid, '%s.teeth = %s\n', r.name, num(r.teeth)); end
    if ~isempty(r.holes), fprintf(fid, '%s.holes = %s\n', r.name, num(r.holes)); end
end
fclose(fid);

cases = {'fs_case', L.fs; 'acc_cover', L.cov};
for k = 1:2
    c = cases{k, 2};
    fid = fopen(fullfile(out_dir, [cases{k, 1} '.txt']), 'w');
    fprintf(fid, '# %s: written by calc/cad_export/cx_export.m (calc/assembly/as_export.m), do not edit\n', cases{k, 1});
    fprintf(fid, 'n_out = %d\nout = %s\nz_out = %s\n', size(c.out.segs, 1), num(c.out.segs'), num(c.z_out));
    fprintf(fid, 'n_cav = %d\ncav = %s\nz_cav = %s\n', size(c.cav.segs, 1), num(c.cav.segs'), num(c.z_cav));
    fprintf(fid, 'n_pads = %d\n', size(c.pads, 1));
    for j = 1:size(c.pads, 1), fprintf(fid, 'pad%d = %s\n', j, num(c.pads(j, :))); end
    fprintf(fid, 'n_pockets = %d\n', size(c.pockets, 1));
    for j = 1:size(c.pockets, 1), fprintf(fid, 'pocket%d = %s\n', j, num(c.pockets(j, :))); end
    fprintf(fid, 'n_holes = %d\n', size(c.holes, 1));
    for j = 1:size(c.holes, 1), fprintf(fid, 'holes%d = %s\n', j, num(c.holes(j, :))); end
    fclose(fid);
end

r = L.rollers;
fid = fopen(fullfile(out_dir, 'rollers.txt'), 'w');
fprintf(fid, '# rollers: written by calc/cad_export/cx_export.m (calc/assembly/as_export.m), do not edit\n');
fprintf(fid, 'n = %d\nr_pitch = %.6g\nr_roller = %.6g\nz0 = %.6g\nL = %.6g\n', r.n, r.r_pitch, r.r_roller, r.z0, r.L);
fclose(fid);

fid = fopen(fullfile(out_dir, 'assembly.txt'), 'w');
fprintf(fid, '# assembly: written by calc/cad_export/cx_export.m (calc/assembly/as_export.m), do not edit\n');
fprintf(fid, '# i<k> = part module rotation[deg] x y z [mm]\n');
fprintf(fid, 'n = %d\n', height(L.inst));
for k = 1:height(L.inst)
    fprintf(fid, 'i%d = %s %s %s\n', k, L.inst.part{k}, L.inst.module{k}, ...
            num([L.inst.rot(k) L.inst.x(k) L.inst.y(k) L.inst.z(k)]));
end
fclose(fid);
end
