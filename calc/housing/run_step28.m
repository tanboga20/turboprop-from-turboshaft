function S = run_step28(out_dir, mode)
%RUN_STEP28  Step 2.8: housing stiffness, modes and stress; planet and gear web modes in 3-D (STR-04, DYN-04, DYN-05).
%   S = run_step28()                  full run, results in calc/results/step28
%   S = run_step28(out_dir)           results in out_dir
%   S = run_step28(out_dir, 'plots')  redraw the plots from step28.mat
%   S = run_step28(out_dir, 'quick')  coarse meshes, to check the script in a few minutes
%
%   Runs from the repo root with calc/housing, calc/gear_detail and
%   calc/shafts_bearings on the path (MATLAB PDE Toolbox). Steps:
%    1. the axisymmetric RGB case in two materials: mass, propeller bearing
%       seat stiffness against the step 2.1 floor and target, modes up to
%       in.f_max against the planetary mesh bands, von Mises stress at the
%       LD-05 limit load with the LD-03/04 thrust
%    2. the planet in 3-D: free, on its loaded rollers, and with its two
%       meshes, against the 1x and 2x planetary mesh bands
%    3. the first-stage gear blank in 3-D (the web check step 2.4 handed
%       on): its out-of-plane web modes and their nodal diameters against
%       the first-stage mesh band, widened by n times the gear speed for a
%       mode with n nodal diameters, next to the plate model of step 2.4
%   Writes summary.txt, the mode charts and 3-D pictures (stress, seat
%   deflection, mode shapes) in English and Turkish and step28.mat to
%   out_dir (calc/results is not committed). A run takes about 25 minutes.
%
%   Source: Phase 2 report, Section 2.8.

if nargin < 1 || isempty(out_dir)
    out_dir = fullfile('calc', 'results', 'step28');
end
if nargin < 2, mode = 'full'; end
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
if strcmp(mode, 'plots')
    L = load(fullfile(out_dir, 'step28.mat'));
    make_plots(L.S, out_dir);
    S = L.S;
    return
end

in = hs_inputs();
if strcmp(mode, 'quick')
    in.Hmax = 2 * in.Hmax;  in.planet.Hmax = 2 * in.planet.Hmax;  in.web.Hmax = 2 * in.web.Hmax;
end
S = struct('in', in);

% 1. Housing: limit loads on the propeller bearing seats (LD-05, 2.5 g, with the step 2.5 layout)
W = in.m_prop * in.g;
R_out = in.nz * W * (1 + in.a / in.span) + in.M_gyro * 1e3 / in.span;
R_in = -(in.nz * W * in.a / in.span + in.M_gyro * 1e3 / in.span);
L = struct('R_in', R_in, 'R_out', -R_out, 'F_ax', in.F_ax);
S.loads = L;
opt = struct('Hmax', in.Hmax, 'f_max', in.f_max, 'n_seg', in.n_seg, 'stl', fullfile(out_dir, 'case.stl'));
for k = 1:numel(in.mat)
    h = hs_housing(in.case, in.mat(k), L, opt);
    h.mat = in.mat(k).name;
    housing_plots(h, k == 1, out_dir);                 % 3-D pictures now, then drop the meshes
    H(k) = rmfield(h, 'fe'); %#ok<AGROW>
end
S.H = H;
save(fullfile(out_dir, 'step28_housing.mat'), 'S');    % checkpoint before the planet models
mrg = @(f, b) max((b(1) - f) / b(1), (f - b(2)) / b(2));    % separation from a band (negative = inside)
for k = 1:numel(H)
    f = H(k).f;
    S.H(k).inband = [sum(f >= in.f_bands(1, 1) & f <= in.f_bands(1, 2)), ...
                     sum(f >= in.f_bands(2, 1) & f <= in.f_bands(2, 2))];
end

% 2. Planet in 3-D
gi = gd_inputs();
M = gd_meshes(gi);
gsp = M(2).g;
sb = sb_inputs();
pb = sb.planet;
Dpw = M(2).D_or - pb.Dw;
Z = floor(pi * Dpw / (pb.Dw * (1 + pb.pitch_gap)));
ref = struct('KA', 1, 'mode', 'ref', 'oil', gi.oil(1), 'Kgam', 1);
r2 = gd_rate(M(2), M(2).T1, M(2).n1, ref);
Ftm = 2000 * M(2).T1 / gsp.dw1;
pp = struct('D_or', M(2).D_or, 'd_root', gsp.df1, 'b', gsp.b, 'h_teeth', 0.5 * gsp.h1, 'E', gi.mat.Eh.E * 1e6, ...
            'nu', 0.3, 'rho', gi.rho_steel * 1e9, 'Z', Z, 'Lwe', gsp.b - pb.L_ends, 'F', 2 * Ftm * 1.22, ...
            'k_mesh', r2.c_ga * gsp.b * 1e6, 'alpha', gsp.alpha_wt, 'psi_mesh', 4 * pi / gsp.z1, ...
            'Hmax', in.planet.Hmax);
sup = {'free', 'rollers', 'rollers+meshes'};
for j = 1:3
    p = hs_planet3d(pp, sup{j}, in.planet.f_max);
    p.margin = arrayfun(@(f) min(mrg(f, in.f_bands(1, :) ./ [0.9 1.1]), mrg(f, in.f_bands(2, :) ./ [0.9 1.1])), p.f);
    if j == 3, planet_plots(p, out_dir); end
    P(j) = rmfield(p, 'fe'); %#ok<AGROW>
end
S.P = P;
S.planet = pp;

% 3. First-stage gear web in 3-D; the teeth as mass (rim to mid-tooth) or left out (rim to the root)
g1 = M(1).g;
pw = struct('r_bore', sb.shafts(2).d_o / 2, 'r_hub', gi.gear2_hub_d / 2, 'r_rim', g1.df2 / 2 - gi.gear2_rim * gi.s1.mn, ...
            'r_out', g1.df2 / 2, 't_web', gi.gear2_web, 'b', gi.s1.b, 'L_hub', in.web.L_hub, ...
            'E', gi.mat.Eh.E * 1e6, 'nu', 0.3, 'rho', gi.rho_steel * 1e9);
fm1 = gi.n_PT * gi.s1.z1 / 60;
frot = gi.n_PT * gi.s1.z1 / gi.s1.z2 / 60;
band = [0.9 * gi.speed_range(1) * fm1, 1.1 * gi.speed_range(2) * fm1];
for v = 1:2
    if v == 2, pw.r_out = g1.df2 / 2 + 0.25 * g1.h2; end
    w = hs_gear_web(pw, in.web.f_max, in.web.Hmax);
    keep = w.ax > 0.5;                                  % out-of-plane web modes
    w.f = w.f(keep);  w.n = w.n(keep);  w.ax = w.ax(keep);
    w.inband = w.f >= band(1) - w.n * frot & w.f <= band(2) + w.n * frot;
    w.r_out = pw.r_out;
    Wb(v) = w; %#ok<AGROW>
end
p24 = struct('r_in', gi.gear2_hub_d / 2, 'r_out', g1.df2 / 2 - gi.gear2_rim * gi.s1.mn, 't', gi.gear2_web, ...
             'b_rim', gi.s1.b, 's_rim', gi.gear2_rim * gi.s1.mn, 's_mass', gi.gear2_rim * gi.s1.mn + 0.5 * g1.h2, ...
             'E', gi.mat.Eh.E, 'nu', 0.3, 'rho', gi.rho_steel, 'ne', 40);
fw = gd_modes('web', p24, 0:12);
S.web = struct('model', Wb, 'band', band, 'frot', frot, 'fm1', fm1, 'plate_n', 0:12, 'plate_f', fw(:, 1)');

save(fullfile(out_dir, 'step28.mat'), 'S');
write_summary(S, out_dir);
make_plots(S, out_dir);
end

function write_summary(S, out_dir)
in = S.in;
fid = fopen(fullfile(out_dir, 'summary.txt'), 'w');
fprintf(fid, 'Step 2.8: housing and planet finite element models\n\n');
fprintf(fid, 'Limit loads on the propeller bearing seats: inner %.0f N, outer %.0f N (radial, opposite), axial %.0f N\n\n', ...
        S.loads.R_in, S.loads.R_out, S.loads.F_ax);
for k = 1:numel(S.H)
    h = S.H(k);
    fprintf(fid, '%s case: %.2f kg, %d nodes; seat stiffness inner %.3g, outer %.3g N/m (floor %.0e, target %.0e)\n', ...
            h.mat, h.m, h.n_nodes, h.k_in, h.k_out, in.k_floor, in.k_target);
    fprintf(fid, '  modes below %.0f Hz (%d): %s\n', in.f_max, numel(h.f), mat2str(round(h.f)));
    fprintf(fid, '  modes in the planetary 1x / 2x bands: %d / %d\n', h.inband);
    fprintf(fid, '  von Mises at limit %.0f MPa: n_y %.2f, n_u %.2f\n\n', h.sig, h.n_y, h.n_u);
end
nm = {'free', 'on the loaded rollers', 'rollers and meshes'};
fprintf(fid, 'Planet in 3-D (%d dof): bands 1x %d-%d, 2x %d-%d Hz\n', S.P(1).n_dof, in.f_bands');
for j = 1:numel(S.P)
    fprintf(fid, '  %-22s %s Hz, margins %s %%\n', nm{j}, mat2str(round(S.P(j).f)), mat2str(round(100 * S.P(j).margin)));
end
w = S.web;
fprintf(fid, '\nFirst-stage gear web in 3-D: mesh %.0f Hz at 100%%, 1x band %.0f-%.0f Hz widened by n x %.1f Hz\n', ...
        w.fm1, w.band, w.frot);
lab = {'teeth left out (rim to the root)', 'teeth as mass (rim to mid-tooth)'};
for v = 1:numel(w.model)
    m = w.model(v);
    fprintf(fid, '  %s, %.2f kg: out-of-plane modes %s Hz, n %s\n', lab{v}, m.m, mat2str(round(m.f)), mat2str(m.n));
    fprintf(fid, '    in the band: %s Hz, n %s\n', mat2str(round(m.f(m.inband))), mat2str(m.n(m.inband)));
end
fprintf(fid, '  plate model of step 2.4, first family n 0-12: %s Hz\n', mat2str(round(w.plate_f)));
fclose(fid);
type(fullfile(out_dir, 'summary.txt'));
end

function make_plots(S, out_dir)
for lang = {'en', 'tr'}
    plots(S, out_dir, lang{1});
    if isfield(S, 'web'), web_plot(S.web, out_dir, lang{1}); end
end
end

function web_plot(w, out_dir, lang)
% Out-of-plane web modes against the first-stage mesh band, by nodal diameter
tr = strcmp(lang, 'tr');
fig = figure('Visible', 'off', 'Position', [100 100 900 480]);
hold on
n = 0:12;
patch([n, fliplr(n)], [w.band(1) - n * w.frot, fliplr(w.band(2) + n * w.frot)] / 1000, [0.96 0.84 0.43], ...
      'EdgeColor', 'none', 'FaceAlpha', 0.6);
c = [0.12 0.44 0.70; 0.75 0.22 0.17];
mk = {'o', 's'};
for v = 1:numel(w.model)
    m = w.model(v);
    plot(m.n, m.f / 1000, mk{v}, 'Color', c(v, :), 'MarkerFaceColor', c(v, :), 'MarkerSize', 6);
end
plot(w.plate_n, w.plate_f / 1000, 'k--', 'LineWidth', 1);
xlim([-0.5 12.5]);  ylim([0 16]);  grid on;  box on
if tr
    xlabel('Düğüm çapı sayısı n');  ylabel('Doğal frekans (kHz)');
    legend({'1× kavrama bandı (±n·dönme)', '3B, dişler yok', '3B, dişler kütle olarak', '2.4 plaka modeli'}, 'Location', 'northwest');
    title('DYN-04: birinci kademe dişlisi gövdesinin eksenel modları', 'FontWeight', 'normal', 'FontSize', 10);
else
    xlabel('Nodal diameters n');  ylabel('Natural frequency (kHz)');
    legend({'1× mesh band (± n·rotation)', '3-D, teeth left out', '3-D, teeth as mass', 'step 2.4 plate model'}, 'Location', 'northwest');
    title('DYN-04: out-of-plane modes of the first-stage gear web', 'FontWeight', 'normal', 'FontSize', 10);
end
exportgraphics(fig, fullfile(out_dir, ['web_modes_' lang '.png']), 'Resolution', 150);
close(fig);
end

function plots(S, out_dir, lang)
in = S.in;
tr = strcmp(lang, 'tr');
if tr
    L = struct('fr', 'Doğal frekans (Hz)', 'b1', '1× bandı', 'b2', '2× bandı', ...
               't1', 'DYN-04: gövde ve planet modları, planet kademesinin kavrama bantlarına karşı', ...
               'x', {{'gövde A357', 'gövde WE43', 'planet, serbest', 'planet, makaralar', 'planet, makaralar + kavramalar'}});
else
    L = struct('fr', 'Natural frequency (Hz)', 'b1', '1× band', 'b2', '2× band', ...
               't1', 'DYN-04: housing and planet modes against the planetary mesh bands', ...
               'x', {{'case A357', 'case WE43', 'planet, free', 'planet, rollers', 'planet, rollers + meshes'}});
end
red = [0.75 0.22 0.17];  blue = [0.12 0.44 0.70];
fig = figure('Visible', 'off', 'Position', [100 100 1000 450]);
hold on
bandc = [0.96 0.84 0.43];
nx = numel(S.H) + numel(S.P);
patch([0.5 nx + 0.5 nx + 0.5 0.5], in.f_bands(1, [1 1 2 2]), bandc, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
patch([0.5 nx + 0.5 nx + 0.5 0.5], in.f_bands(2, [1 1 2 2]), bandc, 'EdgeColor', 'none', 'FaceAlpha', 0.35);
for k = 1:numel(S.H)
    plot(k * ones(size(S.H(k).f)), S.H(k).f, '_', 'Color', blue, 'MarkerSize', 14, 'LineWidth', 1.5);
end
for j = 1:numel(S.P)
    plot((numel(S.H) + j) * ones(size(S.P(j).f)), S.P(j).f, 'o', 'Color', red, 'MarkerFaceColor', red);
end
text(0.6, in.f_bands(1, 2) * 1.04, L.b1, 'FontSize', 8);
text(0.6, in.f_bands(2, 2) * 1.04, L.b2, 'FontSize', 8);
set(gca, 'XTick', 1:nx, 'XTickLabel', L.x, 'XTickLabelRotation', 15, 'YScale', 'log');
xlim([0.5 nx + 0.5]);  ylim([300 15000]);  grid on;  box on
ylabel(L.fr);  title(L.t1, 'FontWeight', 'normal', 'FontSize', 10);
exportgraphics(fig, fullfile(out_dir, ['modes_' lang '.png']), 'Resolution', 150);
close(fig);
end

function housing_plots(h, all_views, out_dir)
% Stress at limit load, and for the first material the seat deflection and two mode shapes, both languages
umax = @(u) max(sqrt(u.ux.^2 + u.uy.^2 + u.uz.^2));
sc = @(u, L) L / umax(u);                                   % deformation drawn as L metres at most
fe = h.fe;  nm = h.mat;
for lang = {'en', 'tr'}
    tr = strcmp(lang{1}, 'tr');
    u = fe.Rlim.Displacement;
    if tr
        t = sprintf('%s gövde: sınır yükte von Mises gerilmesi (LD-05 ve 20 kN itki), keskin köşeli model; şekil değiştirme %.0f kat', ...
                    nm, sc(u, 0.012));
    else
        t = sprintf('%s case: von Mises stress at limit load (LD-05 and 20 kN thrust), sharp-corner model; deformation x%.0f', ...
                    nm, sc(u, 0.012));
    end
    hs_plot3d(fe.mesh_s, fe.Rlim.VonMisesStress / 1e6, u, sc(u, 0.012), t, 'von Mises (MPa)', ...
              fullfile(out_dir, sprintf('stress_%s_%s.png', nm, lang{1})), [-35 20]);
    if ~all_views, continue, end
    u = fe.Rseat.Displacement;
    if tr
        t = sprintf('%s gövde: dış pervane yatağı yuvasına 10 kN radyal yük, direngenlik %.2g N/m', nm, h.k_out);
        cl = 'Yer değiştirme (µm)';
    else
        t = sprintf('%s case: 10 kN radial load on the outer propeller bearing seat, stiffness %.2g N/m', nm, h.k_out);
        cl = 'Displacement (µm)';
    end
    hs_plot3d(fe.mesh_s, 1e6 * sqrt(u.ux.^2 + u.uy.^2 + u.uz.^2), u, sc(u, 0.012), t, cl, ...
              fullfile(out_dir, sprintf('seat_%s_%s.png', nm, lang{1})), [-35 20]);
    for q = 1:min(2, numel(h.f))
        ms = fe.Rm.ModeShapes;
        u = struct('ux', ms.ux(:, q), 'uy', ms.uy(:, q), 'uz', ms.uz(:, q));
        if tr
            t = sprintf('%s gövde: %d. mod, %.0f Hz', nm, q, h.f(q));  cl = 'Göreli genlik';
        else
            t = sprintf('%s case: mode %d, %.0f Hz', nm, q, h.f(q));  cl = 'Relative amplitude';
        end
        hs_plot3d(fe.mesh_m, [], u, sc(u, 0.015), t, cl, ...
                  fullfile(out_dir, sprintf('mode%d_%s_%s.png', q, nm, lang{1})), [-35 20]);
    end
end
end

function planet_plots(p, out_dir)
% The first three modes of the planet on its rollers and meshes, both languages
umax = @(u) max(sqrt(u.ux.^2 + u.uy.^2 + u.uz.^2));
fe = p.fe;
for lang = {'en', 'tr'}
    for q = 1:min(3, numel(p.f))
        ms = fe.Rm.ModeShapes;
        i = fe.first + q - 1;
        u = struct('ux', ms.ux(:, i), 'uy', ms.uy(:, i), 'uz', ms.uz(:, i));
        if strcmp(lang{1}, 'tr')
            t = sprintf('Planet, makaralar ve kavramalarla: %d. mod, %.0f Hz', q, p.f(q));  cl = 'Göreli genlik';
        else
            t = sprintf('Planet on its rollers and meshes: mode %d, %.0f Hz', q, p.f(q));  cl = 'Relative amplitude';
        end
        hs_plot3d(fe.mesh, [], u, 0.006 / umax(u), t, cl, fullfile(out_dir, sprintf('planet_mode%d_%s.png', q, lang{1})), [30 25]);
    end
end
end
