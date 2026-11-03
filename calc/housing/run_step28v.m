function V = run_step28v(out_dir, mode)
%RUN_STEP28V  Step 2.8 verification: how far the finite element stresses, stiffnesses and modes can be trusted.
%   V = run_step28v()                  full run, results in calc/results/step28
%   V = run_step28v(out_dir)
%   V = run_step28v(out_dir, 'plots')  redraw the plots from step28v.mat
%   V = run_step28v(out_dir, 'quick')  coarse meshes, to check the script in a few minutes
%
%   Runs from the repo root after run_step28 (it takes the 8 mm modes of
%   the A357 case from step28.mat), with calc/housing on the path. Steps:
%    1. local-stress benchmark: the hole in a tension plate in 3-D against
%       the element size on the hole, and in 2-D plane stress (hs_bench_hole)
%    2. mesh convergence of the A357 case, fixed flange: global meshes of
%       in.verify.Hmax, seat stiffness, modes and the sharp-corner stress
%    3. flange support bracketing at 10 mm: fixed (rigid joint and engine)
%       against the bolted joint as springs (bolts only, an opened joint)
%    4. filleted submodels (hs_submodel, R in.case.rf) of the most loaded
%       re-entrant corners at limit load, driven by the 8 mm global model,
%       with the fillet element size falling to the converged peak stress,
%       and the governing corner again on the spring-supported case
%    5. the first section (flat front wall, cylindrical nose) at 10 mm with
%       its filleted corners: the record of the design iteration
%   Writes summary_verify.txt, plots in English and Turkish and step28v.mat.
%   A run takes about 20 minutes.
%
%   Source: Phase 2 report, Section 2.8 ("Verification").

if nargin < 1 || isempty(out_dir)
    out_dir = fullfile('calc', 'results', 'step28');
end
if nargin < 2, mode = 'full'; end
if strcmp(mode, 'plots')
    L = load(fullfile(out_dir, 'step28v.mat'));
    make_plots(L.V, out_dir);
    V = L.V;
    return
end
in = hs_inputs();
if strcmp(mode, 'quick')
    in.verify = struct('Hmax', [0.016 0.012], 'n_corners', 1, 'half', 30, 'n_fac', 6, 'n_sub', 2, ...
                       'Hmax_sub', 4, 'h_sub', [3 2], 'h_hole', [2 1]);
end
vf = in.verify;
V = struct('in', in);
mat = in.mat(1);
allow = min(mat.sy / 1.25, mat.su / (1.5 * 1.25));    % limit stress allowed with a 1.25 casting factor
V.allow = allow;

% 1. Benchmark
V.bench.h = vf.h_hole;
for q = 1:numel(vf.h_hole)
    B = hs_bench_hole(vf.h_hole(q));
    s = interpolateStress(B.fe.R, 0, 0.01002, 0.00002);
    V.bench.Kt3(q) = B.Kt;
    V.bench.Kt3mid(q) = s.sxx / 1e8;
end
V.bench.h2 = [1 0.5 0.25 0.125];
for q = 1:numel(V.bench.h2)
    V.bench.Kt2(q) = plate2d(V.bench.h2(q));
end
V.bench.ref = (2 + (1 - 0.2)^3) / (1 - 0.2);

% Limit load and the boundary conditions a submodel inherits
W = in.m_prop * in.g;
R_out = in.nz * W * (1 + in.a / in.span) + in.M_gyro * 1e3 / in.span;
R_in = -(in.nz * W * in.a / in.span + in.M_gyro * 1e3 / in.span);
L = struct('R_in', R_in, 'R_out', -R_out, 'F_ax', in.F_ax);
A = @(s) 2 * pi * s(2) * s(1) * 1e-6;
bc = struct('type', {'fixed', 'traction', 'traction'}, ...
            'seg', {[129.5 0 153.5 0], [90 132 90 160], [90 412 90 446]}, ...
            't', {[], [0; L.R_in / A(in.case.seat_in); 0], [0; L.R_out / A(in.case.seat_out); L.F_ax / A(in.case.seat_out)]});
so = struct('rf', in.case.rf, 'half', vf.half, 'n_seg', in.n_seg, 'n_fac', vf.n_fac, 'n_sub', vf.n_sub, ...
            'Hmax', vf.Hmax_sub, 'h', vf.h_sub, 'E', mat.E, 'nu', mat.nu, 'bc', bc);

% 2. Global mesh convergence (fixed flange); the 8 mm modes come from run_step28
S28 = load(fullfile(out_dir, 'step28.mat'));
[~, ~, C] = hs_section(in.case.rects, in.case.rf, [], 4);
for q = 1:numel(vf.Hmax)
    opt = struct('Hmax', vf.Hmax(q), 'f_max', in.f_max, 'n_seg', in.n_seg, 'stl', [tempname '.stl'], ...
                 'modal', abs(vf.Hmax(q) - S28.S.in.Hmax) > 1e-9);
    H = hs_housing(in.case, mat, L, opt);
    if ~opt.modal, H.f = S28.S.H(1).f; end
    V.conv(q) = struct('Hmax', vf.Hmax(q), 'n_nodes', H.n_nodes, 'm', H.m, 'k_in', H.k_in, 'k_out', H.k_out, ...
                       'f', H.f(1:min(6, end)), 'peak', corner_peaks(H.fe.Rlim, C));
    Rg = H.fe.Rlim;                                    % the finest (last) drives the submodels
end

% 4. Submodels of the most loaded corners (bearing shoulders and the flange face edges excluded)
pk = V.conv(end).peak;
pk(C(:, 2) < 10 | C(:, 5) < 2, 1) = 0;
[~, o] = sort(pk(:, 1), 'descend');
for q = 1:vf.n_corners
    i = o(q);
    so.th_c = pk(i, 2);
    S = hs_submodel(Rg, in.case.rects, C(i, 1:2), so);
    S.sharp = arrayfun(@(c) c.peak(i, 1), V.conv);
    V.sub(q) = S;
end
[~, ig] = max(arrayfun(@(s) s.sig(end), V.sub));
V.gov = ig;

% 3. Flange support bracketing at 10 mm, and the governing corner on the springs
fl = in.flange;
ks = fl.n * fl.E_bolt * fl.As * 1e-6 / (fl.L_grip * 1e-3) / (fl.A * 1e-6);   % N/m^3, bolts only
V.k_sup = ks;
q10 = numel(vf.Hmax) - 1;                             % the level before the finest (10 mm)
opt = struct('Hmax', vf.Hmax(q10), 'f_max', in.f_max, 'n_seg', in.n_seg, 'stl', [tempname '.stl'], ...
             'support', 'elastic', 'k_sup', [ks ks ks]);
H = hs_housing(in.case, mat, L, opt);
V.brk = struct('Hmax', vf.Hmax(q10), 'k_in', [V.conv(q10).k_in, H.k_in], 'k_out', [V.conv(q10).k_out, H.k_out], ...
               'f', {{V.conv(q10).f, H.f(1:min(6, end))}});
so2 = so;
so2.bc(1).type = 'global';                             % the flange face follows the springs of the global model
so2.th_c = V.sub(ig).at(3);
so2.h = vf.h_sub(end);
Sb = hs_submodel(H.fe.Rlim, in.case.rects, V.sub(ig).corner, so2);
V.brk.sig_h = [V.sub(ig).sig(end), Sb.sig];             % fixed and springs, finest fillet mesh

% 5. The first section, for the record
opt = struct('Hmax', vf.Hmax(q10), 'f_max', in.f_max, 'n_seg', in.n_seg, 'stl', [tempname '.stl'], 'modal', false);
g0 = in.case;  g0.rects = in.case0;
H0 = hs_housing(g0, mat, L, opt);
[~, ~, C0] = hs_section(in.case0, in.case.rf, [], 4);
p0 = corner_peaks(H0.fe.Rlim, C0);
p0(C0(:, 2) < 10 | C0(:, 5) < 2, 1) = 0;
[~, o0] = sort(p0(:, 1), 'descend');
so0 = so;  so0.h = [2 1];
for q = 1:2
    i = o0(q);
    so0.th_c = p0(i, 2);
    S0 = hs_submodel(H0.fe.Rlim, in.case0, C0(i, 1:2), so0);
    V.first.corner(q, :) = C0(i, 1:2);
    V.first.sharp(q) = p0(i, 1);
    V.first.sig(q, :) = S0.sig;
end
V.first.m = H0.m;  V.first.k_in = H0.k_in;  V.first.k_out = H0.k_out;

make_plots(V, out_dir);
fe = arrayfun(@(s) s.fe, V.sub);
sub_pictures(V, fe, out_dir);
V.sub = rmfield(V.sub, 'fe');
save(fullfile(out_dir, 'step28v.mat'), 'V');
write_summary(V, out_dir);
end

function pk = corner_peaks(R, C)
% largest nodal von Mises within 8 mm of each re-entrant corner of the sharp section, and its azimuth
X = R.Mesh.Nodes;
r = hypot(X(1, :), X(2, :)) * 1000;  z = X(3, :) * 1000;  th = atan2(X(2, :), X(1, :));
vm = R.VonMisesStress' / 1e6;
pk = zeros(size(C, 1), 2);
for i = 1:size(C, 1)
    [pk(i, 1), j] = max(vm .* (hypot(r - C(i, 1), z - C(i, 2)) < 8));
    pk(i, 2) = th(j);
end
end

function Kt = plate2d(h)
% the benchmark plate in 2-D plane stress (quarter, rollers), element size h [mm] on the hole
m = createpde('structural', 'static-planestress');
g = decsg([[3 4 0 0.150 0.150 0 0 0 0.050 0.050]', [1 0 0 0.010 0 0 0 0 0 0]'], 'R1-C1', ['R1'; 'C1']');
geometryFromEdges(m, g);
structuralProperties(m, 'YoungsModulus', 206e9, 'PoissonsRatio', 0.3);
eh = nearestEdge(m.Geometry, [0.00707 0.00707]);
generateMesh(m, 'Hmax', 0.004, 'Hedge', {eh, h / 1000});
structuralBC(m, 'Edge', nearestEdge(m.Geometry, [0 0.03]), 'XDisplacement', 0);
structuralBC(m, 'Edge', nearestEdge(m.Geometry, [0.08 0]), 'YDisplacement', 0);
structuralBoundaryLoad(m, 'Edge', nearestEdge(m.Geometry, [0.150 0.025]), 'SurfaceTraction', [100e6; 0]);
R = solve(m);
Kt = max(R.Stress.sxx(findNodes(m.Mesh, 'region', 'Edge', eh))) / 1e8;
end

function write_summary(V, out_dir)
in = V.in;
fid = fopen(fullfile(out_dir, 'summary_verify.txt'), 'w');
fprintf(fid, 'Step 2.8 verification\n\n');
b = V.bench;
fprintf(fid, '1. Hole in a tension plate (d/W 0.2): Kt reference %.3f (Heywood / Howland, plane stress)\n', b.ref);
fprintf(fid, '   3-D, element size on the hole %s mm: largest node %s, near the edge at mid-plane %s\n', ...
        mat2str(b.h), mat2str(round(b.Kt3, 3)), mat2str(round(b.Kt3mid, 3)));
fprintf(fid, '   2-D plane stress, element size %s mm: %s\n\n', mat2str(b.h2), mat2str(round(b.Kt2, 3)));
fprintf(fid, '2. Mesh convergence, A357 case, fixed flange\n');
for c = V.conv
    fprintf(fid, '   Hmax %2.0f mm: %6d nodes, %.3f kg, seat stiffness inner %.4g, outer %.4g N/m, modes %s Hz\n', ...
            c.Hmax * 1000, c.n_nodes, c.m, c.k_in, c.k_out, mat2str(round(c.f)));
end
fprintf(fid, '\n3. Flange support (%.0f mm): fixed against bolted-joint springs %.3g N/m^3 (bolts only)\n', ...
        V.brk.Hmax * 1000, V.k_sup);
fprintf(fid, '   seat stiffness inner %.4g -> %.4g, outer %.4g -> %.4g N/m\n', V.brk.k_in, V.brk.k_out);
fprintf(fid, '   modes %s -> %s Hz\n', mat2str(round(V.brk.f{1})), mat2str(round(V.brk.f{2})));
fprintf(fid, '   governing corner, fillet peak at h %.1f mm: fixed %.1f, springs %.1f MPa\n\n', in.verify.h_sub(end), V.brk.sig_h);
fprintf(fid, '4. Filleted submodels (R %.0f mm) at limit load, driven by the %.0f mm global model; allowed %.0f MPa (casting factor 1.25)\n', ...
        in.case.rf, in.verify.Hmax(end) * 1000, V.allow);
for s = V.sub
    fprintf(fid, '   corner (%.1f, %.1f) mm at %.0f deg: sharp corner, global Hmax %s mm: %s MPa\n', s.corner, s.at(3) * 180 / pi, ...
            mat2str(in.verify.Hmax * 1000), mat2str(round(s.sharp, 1)));
    fprintf(fid, '      fillet, h %s mm: %s MPa (largest in the window %s); n_y %.2f, n_u %.2f\n', mat2str(s.h), ...
            mat2str(round(s.sig, 1)), mat2str(round(s.sig_win, 1)), in.mat(1).sy / s.sig(end), in.mat(1).su / (1.5 * s.sig(end)));
end
f = V.first;
fprintf(fid, '\n5. First section (flat front wall, cylindrical nose), %.0f mm: %.2f kg, seat stiffness inner %.4g, outer %.4g N/m\n', ...
        V.brk.Hmax * 1000, f.m, f.k_in, f.k_out);
for q = 1:size(f.corner, 1)
    fprintf(fid, '   corner (%.1f, %.1f): sharp %.1f MPa, fillet h 2 / 1 mm: %s MPa\n', f.corner(q, :), f.sharp(q), mat2str(round(f.sig(q, :), 1)));
end
fclose(fid);
type(fullfile(out_dir, 'summary_verify.txt'));
end

function make_plots(V, out_dir)
for lang = {'en', 'tr'}
    tr = strcmp(lang{1}, 'tr');
    red = [0.75 0.22 0.17];  blue = [0.12 0.44 0.70];  grey = [0.45 0.45 0.45];
    % benchmark
    b = V.bench;
    fig = figure('Visible', 'off', 'Position', [100 100 760 430]);
    semilogx(b.h, b.Kt3, 'o-', 'Color', blue, 'MarkerFaceColor', blue);  hold on
    semilogx(b.h, b.Kt3mid, 's--', 'Color', blue);
    semilogx(b.h2, b.Kt2, 'd-', 'Color', red, 'MarkerFaceColor', red);
    yline(b.ref, ':', 'Color', grey, 'LineWidth', 1.5);
    set(gca, 'XDir', 'reverse');  grid on;  ylim([2.8 3.5]);
    if tr
        xlabel('Delik yüzeyinde eleman boyutu (mm)');  ylabel('Gerilme yığılma katsayısı K_t');
        legend({'3B, en büyük düğüm', '3B, kenarda orta düzlem', '2B düzlem gerilme', 'Teori (Heywood/Howland) 3,14'}, 'Location', 'southeast');
        title('Delikli plaka testi: yerel gerilme ağ sıklaştıkça teoriye yakınsıyor', 'FontWeight', 'normal', 'FontSize', 10);
    else
        xlabel('Element size on the hole (mm)');  ylabel('Stress concentration factor K_t');
        legend({'3-D, largest node', '3-D, mid-plane at the edge', '2-D plane stress', 'Theory (Heywood/Howland) 3.14'}, 'Location', 'southeast');
        title('Hole-in-plate benchmark: the local stress converges to theory as the mesh is refined', 'FontWeight', 'normal', 'FontSize', 10);
    end
    exportgraphics(fig, fullfile(out_dir, ['verify_bench_' lang{1} '.png']), 'Resolution', 150);
    close(fig);
    % convergence: global quantities and the governing corner
    c = V.conv;  hm = [c.Hmax] * 1000;
    rel = @(v) v / v(end);
    fig = figure('Visible', 'off', 'Position', [100 100 1100 420]);
    subplot(1, 2, 1);
    plot(hm, rel([c.k_out]), 'o-', 'Color', blue, 'MarkerFaceColor', blue);  hold on
    plot(hm, rel([c.k_in]), 's-', 'Color', blue);
    f1 = arrayfun(@(x) x.f(1), c);  f2 = arrayfun(@(x) x.f(min(2, end)), c);
    plot(hm, rel(f1), 'o-', 'Color', red, 'MarkerFaceColor', red);
    plot(hm, rel(f2), 's-', 'Color', red);
    set(gca, 'XDir', 'reverse');  grid on;  ylim([0.9 1.1]);
    s = V.sub(V.gov);
    if tr
        xlabel('Genel ağ boyutu Hmax (mm)');  ylabel('8 mm sonucuna oranı');
        legend({'dış yuva direngenliği', 'iç yuva direngenliği', '1. mod', '2. mod'}, 'Location', 'best');
        title('Genel büyüklükler ağdan pek etkilenmiyor', 'FontWeight', 'normal', 'FontSize', 10);
    else
        xlabel('Global mesh size Hmax (mm)');  ylabel('Ratio to the 8 mm result');
        legend({'outer seat stiffness', 'inner seat stiffness', 'mode 1', 'mode 2'}, 'Location', 'best');
        title('Global quantities hardly depend on the mesh', 'FontWeight', 'normal', 'FontSize', 10);
    end
    subplot(1, 2, 2);
    plot(hm, s.sharp, 'o-', 'Color', grey, 'MarkerFaceColor', grey);  hold on
    plot(s.h, s.sig, 'o-', 'Color', red, 'MarkerFaceColor', red);
    yline(V.allow, '--', 'Color', [0.2 0.2 0.2]);
    set(gca, 'XDir', 'reverse', 'XScale', 'log');  grid on;
    yl = ylim;  ylim([0, max(yl(2), 1.1 * V.allow)]);
    if tr
        xlabel('Eleman boyutu (mm)');  ylabel('von Mises, sınır yükte (MPa)');
        legend({'keskin köşe, genel model', sprintf('R%.0f yuvarlatma, alt model', V.in.case.rf), 'izin verilen (döküm katsayısı 1,25)'}, 'Location', 'best');
        title(sprintf('En yüklü köşe (r %.1f, z %.1f mm): keskin köşe yakınsamaz, yuvarlatma yakınsar', s.corner), 'FontWeight', 'normal', 'FontSize', 10);
    else
        xlabel('Element size (mm)');  ylabel('von Mises at limit load (MPa)');
        legend({'sharp corner, global model', sprintf('R%.0f fillet, submodel', V.in.case.rf), 'allowed (casting factor 1.25)'}, 'Location', 'best');
        title(sprintf('Most loaded corner (r %.1f, z %.1f mm): the sharp corner does not converge, the fillet does', s.corner), ...
              'FontWeight', 'normal', 'FontSize', 10);
    end
    exportgraphics(fig, fullfile(out_dir, ['verify_conv_' lang{1} '.png']), 'Resolution', 150);
    close(fig);
end
end

function sub_pictures(V, fe, out_dir)
% von Mises in the section plane through the peak of each submodel
for q = 1:numel(fe)
    s = V.sub(q);
    w = s.win;
    [rr, zz] = meshgrid(w(1):0.25:w(2), w(3):0.25:w(4));
    t = s.at(3);
    vm = interpolateVonMisesStress(fe(q).R, rr(:) * cos(t) / 1000, rr(:) * sin(t) / 1000, zz(:) / 1000) / 1e6;
    vm = reshape(vm, size(rr));
    for lang = {'en', 'tr'}
        fig = figure('Visible', 'off', 'Position', [100 100 760 640], 'Color', 'w');
        contourf(rr, zz, vm, 24, 'LineStyle', 'none');
        colormap(fig, turbo(256));
        cb = colorbar;  cb.Label.String = 'von Mises (MPa)';
        axis equal;  box on;  hold on
        plot(s.at(1), s.at(2), 'kp', 'MarkerFaceColor', 'w', 'MarkerSize', 12);
        if strcmp(lang{1}, 'tr')
            xlabel('r (mm)');  ylabel('z (mm), flanştan pervaneye');
            title(sprintf('Alt model kesiti (%.0f°), R%.0f yuvarlatma: en büyük %.0f MPa, sınır yükte', rad2deg(t), s.rf, s.sig(end)), ...
                  'FontWeight', 'normal', 'FontSize', 10);
        else
            xlabel('r (mm)');  ylabel('z (mm), flange to propeller');
            title(sprintf('Submodel section (%.0f deg), R%.0f fillet: largest %.0f MPa at limit load', rad2deg(t), s.rf, s.sig(end)), ...
                  'FontWeight', 'normal', 'FontSize', 10);
        end
        exportgraphics(fig, fullfile(out_dir, sprintf('verify_sub%d_%s.png', q, lang{1})), 'Resolution', 150);
        close(fig);
    end
end
end
