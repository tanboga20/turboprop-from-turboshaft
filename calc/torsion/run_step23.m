function S = run_step23(out_dir, mode)
%RUN_STEP23  Step 2.3 full run: torsional modes of the drive chain (DYN-02) and sudden stoppage (LD-08).
%   run_step23              run from the repo root; writes to calc/results/step23
%   S = run_step23(out_dir)
%   run_step23(out_dir, 'plots')   redraws the plots from out_dir/step23.mat
%
%   Needs calc/torsion and calc/rgb_sizing on the path:
%   addpath('calc/torsion', 'calc/rgb_sizing').
%   1. Builds the PDR design with the step 1.3 tool (gear_data) and the
%      torsional model (torsion_model) with the step 2.1 and 2.2 shafts.
%   2. Natural frequencies, the element that stores most strain energy in
%      each mode, and the DYN-02 check against the propeller orders and the
%      PT speed orders over the steady range.
%   3. Floating shaft study: the torsional mode of the floating shaft
%      against 1 x PT speed for the shafts that step 2.2 allows; it sets the
%      torsional stiffness floor in.kt_min of ptshaft_inputs.
%   4. Sensitivity of the modes to the propeller inertia, the mesh
%      stiffness and the generator inertia.
%   5. Sudden stoppage (LD-08): peak torques for every stopping time of
%      in.t_stop, and the shortest stopping time that keeps the propeller
%      shaft below the LD-01 torque and below the static capacity of the
%      gears.
%
%   Files written to out_dir:
%     summary.txt     every table of the step
%     modes.csv       natural frequencies and energy shares
%     sudden_stop.csv peak torques over the stopping time
%     campbell_en.png, stop_en.png and the _tr versions (Turkish labels)
%     step23.mat      the output struct, for redrawing the plots
%     tests.txt       output of test_step23 (TC30-TC32)
%
%   Source: Phase 2 report, Section 2.3.

if nargin < 1 || isempty(out_dir)
    out_dir = fullfile('calc', 'results', 'step23');
end
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end
if nargin == 2 && strcmp(mode, 'plots')
    S = load(fullfile(out_dir, 'step23.mat')).S;
    plots(out_dir, S, 'en');
    plots(out_dir, S, 'tr');
    return
end
in = torsion_inputs();
g = gear_data(in.design);
g = rmfield(g, 'L');
n_prop = in.n_PT / g.i;
S.in = in;  S.g = g;  S.n_prop = n_prop;

% 1-2. Model, modes, DYN-02
T = torsion_model(in, g);
md = torsion_modes(T, in, n_prop);
S.T = T;  S.md = md;
% 2P band for the watch list
S.watch = arrayfun(@(f) f / (in.P_watch * n_prop / 60 * in.n_steady(1)) - 1, md.f);

% 3. Floating shaft: torsional mode against 1 x PT for tubes of the step 2.2 grid
Ds = 0.054:0.002:0.068;  ts = [0.0015 0.0020 0.0025];
fl = [];
for D = Ds
    for t = ts
        in2 = in;  in2.sh.float = [D, D - 2 * t, in.sh.float(3)];
        T2 = torsion_model(in2, g);
        m2 = torsion_modes(T2, in2, n_prop);
        [~, j] = max(m2.share(:, strcmp({T2.el.name}, 'floating shaft')));
        kt = in.G * pi / 32 * (D^4 - (D - 2 * t)^4) / in.sh.float(3);
        fl = [fl; D, t, kt, m2.f(j)]; %#ok<AGROW>
    end
end
S.float = fl;
f_need = (1 + in.margin) * in.PT_orders(1) * in.n_PT / 60 * in.n_steady(2);
S.f_need = f_need;
S.kt_floor = min(fl(fl(:, 4) >= f_need, 3));

% 4. Sensitivity of the first four modes
cases = {'baseline', in; ...
         'propeller inertia -30%', setfield(in, 'J_prop', 0.7 * in.J_prop); ...
         'propeller inertia +30%', setfield(in, 'J_prop', 1.3 * in.J_prop); ...
         'mesh stiffness -30%', setfield(in, 'c_gamma', 0.7 * in.c_gamma); ...
         'generator inertia x 2', setfield(in, 'J_gen', 2 * in.J_gen); ...
         'PT inertia +30%', setfield(in, 'J_PT', 1.3 * in.J_PT)};
for j = 1:size(cases, 1)
    m2 = torsion_modes(torsion_model(cases{j, 2}, g), cases{j, 2}, n_prop);
    S.sens(j) = struct('name', cases{j, 1}, 'f', m2.f(1:4)', 'ok', m2.ok);
end

% 5. Sudden stoppage
ip = find(strcmp({T.el.name}, 'propeller shaft'));
names = {T.el.name};
for j = 1:numel(in.t_stop)
    ss = sudden_stop(T, in, in.t_stop(j), in.n_PT);
    if j == 1
        S.ss_f1 = ss.f1;
    end
    S.stop(j) = struct('t_stop', in.t_stop(j), 'peak', ss.peak', 'T_qs', ss.T_qs, 'daf', ss.daf);
end
S.stop_names = names;
pk = arrayfun(@(s) s.peak(ip), S.stop);
% static capacity of the gears at the propeller: S_H scales with sqrt(torque), S_F with torque
in13 = rgb_inputs();
t13 = tooth_set_check(in.design(1), in.design(2), in.design(3), in.design(4), in.design(5), in13);
s1 = size_stage1(t13.z1, t13.z2, in13);
s2 = size_stage2(t13, in13);
SH = min([s1.rs.S_H, s2.rs_sp.S_H, s2.rs_pr.S_H]);
SF = min([s1.rs.S_F1, s1.rs.S_F2, s2.rs_sp.S_F1, s2.rs_sp.S_F2, s2.rs_pr.S_F1, s2.rs_pr.S_F2]);
S.T_cap = in.T_LD01 * min(SH^2, SF);
S.SH_static = SH;  S.SF_static = SF;
% peak ~ 1 / t_stop: shortest stopping time for each limit
cfit = mean(pk .* in.t_stop);
S.t_min_LD01 = cfit / in.T_LD01;
S.t_min_cap = cfit / S.T_cap;
S.ip = ip;

save(fullfile(out_dir, 'step23.mat'), 'S');
write_summary(fullfile(out_dir, 'summary.txt'), S);
write_csv(out_dir, S);
plots(out_dir, S, 'en');
plots(out_dir, S, 'tr');
diary(fullfile(out_dir, 'tests.txt'));
test_step23;
diary off
end

function write_summary(file, S)
in = S.in;  md = S.md;  T = S.T;
fid = fopen(file, 'w');
fprintf(fid, 'Step 2.3: torsional vibration of the drive chain (DYN-02) and sudden stoppage (LD-08)\n');
fprintf(fid, 'Design %d/%d | %d/%d/%d, i %.4f; propeller %.1f rpm at 100%%\n', in.design(1:4), ...
        in.design(3) + 2 * in.design(4), S.g.i, S.n_prop);
fprintf(fid, '\n1. Natural frequencies (PT and propeller free, ring fixed)\n');
fprintf(fid, '  %-4s %10s  %-30s %6s  %-30s %6s\n', 'mode', 'f Hz', 'main element', 'share', 'second', 'share');
for k = 1:numel(md.f)
    [s, j] = sort(md.share(k, :), 'descend');
    fprintf(fid, '  %-4d %10.1f  %-30s %6.2f  %-30s %6.2f\n', k, md.f(k), T.el(j(1)).name, s(1), T.el(j(2)).name, s(2));
end
fprintf(fid, '\n2. DYN-02 check over %g-%g%% speed, margin %g%% (frames: 1 propeller, 2 PT)\n', 100 * in.n_steady, ...
        100 * in.margin);
f_top = 3 * max(md.check(:, 5));
c = md.check(md.f(md.check(:, 1)) < f_top, :);
[~, o] = sort(c(:, 6));
fprintf(fid, '  closest five: mode, order, frame, band Hz, margin\n');
for r = o(1:min(5, end))'
    fprintf(fid, '    mode %d, %gx, frame %d, %.1f-%.1f Hz, margin %.1f%%\n', c(r, 1), c(r, 2), c(r, 3), c(r, 4), ...
            c(r, 5), 100 * c(r, 6));
end
fprintf(fid, '  all modes below %.0f Hz clear every band by %g%%: %d\n', f_top, 100 * in.margin, md.ok);
fprintf(fid, '  watch: mode 1 is %.1f%% below the 2P band (2P is not a DYN-02 order)\n', -100 * S.watch(1));

fprintf(fid, '\n3. Floating shaft torsional mode against 1 x PT (needs %.1f Hz)\n', S.f_need);
for r = 1:size(S.float, 1)
    fprintf(fid, '  %2.0f x %.1f mm: kt %6.0f N m/rad, mode %6.1f Hz\n', S.float(r, 1) * 1e3, S.float(r, 2) * 1e3, ...
            S.float(r, 3), S.float(r, 4));
end
fprintf(fid, '  torsional stiffness floor: %.0f N m/rad (ptshaft_inputs kt_min)\n', S.kt_floor);

fprintf(fid, '\n4. Sensitivity of modes 1-4 [Hz]\n');
for s = S.sens
    fprintf(fid, '  %-26s %s  DYN-02 met %d\n', s.name, mat2str(round(s.f, 1)), s.ok);
end

fprintf(fid, '\n5. Sudden stoppage: the PT stops linearly in t_stop from 100%%; modal damping %g%%\n', 100 * in.zeta);
fprintf(fid, '  lowest frequency with the PT held %.1f Hz\n', S.ss_f1);
fprintf(fid, '  %-8s %16s %14s %8s %16s %16s\n', 't_stop s', 'propeller shaft', 'quasi-static', 'DAF', 'first-stage gear', 'floating shaft');
ifs = find(strcmp(S.stop_names, 'floating shaft'));
im = find(strcmp(S.stop_names, 'first-stage mesh'));
for s = S.stop
    fprintf(fid, '  %-8.2f %16.0f %14.0f %8.2f %16.0f %16.0f\n', s.t_stop, s.peak(S.ip), s.T_qs, s.daf, s.peak(im), s.peak(ifs));
end
fprintf(fid, '  static capacity of the gears at the propeller: %.0f N m (lowest static S_H %.3f, S_F %.3f at LD-01)\n', ...
        S.T_cap, S.SH_static, S.SF_static);
fprintf(fid, '  shortest stopping time: %.2f s to stay below LD-01 (%g N m), %.2f s below the static capacity\n', ...
        S.t_min_LD01, in.T_LD01, S.t_min_cap);
fclose(fid);
end

function write_csv(out_dir, S)
fid = fopen(fullfile(out_dir, 'modes.csv'), 'w');
fprintf(fid, 'mode,f_Hz');
fprintf(fid, ',%s', S.T.el.name);
fprintf(fid, '\n');
for k = 1:numel(S.md.f)
    fprintf(fid, '%d,%.2f', k, S.md.f(k));
    fprintf(fid, ',%.4f', S.md.share(k, :));
    fprintf(fid, '\n');
end
fclose(fid);
fid = fopen(fullfile(out_dir, 'sudden_stop.csv'), 'w');
fprintf(fid, 't_stop_s,T_qs_Nm,daf');
fprintf(fid, ',%s', S.stop_names{:});
fprintf(fid, '\n');
for s = S.stop
    fprintf(fid, '%.3f,%.1f,%.3f', s.t_stop, s.T_qs, s.daf);
    fprintf(fid, ',%.1f', s.peak);
    fprintf(fid, '\n');
end
fclose(fid);
end

function plots(out_dir, S, lang)
in = S.in;  md = S.md;
if strcmp(lang, 'tr')
    L = struct('x', 'Güç türbini hızı (%)', 'y', 'Frekans (Hz)', 'band', 'sürekli çalışma aralığı', ...
               'mode', 'burulma modu', 'ptitle', 'Burulma Campbell diyagramı: modlar ve uyarı mertebeleri', ...
               'sx', 'Güç türbininin durma süresi (s)', 'sy', 'Pervane milinde tepe tork (N·m)', ...
               'ld', 'LD-01 sınırı', 'cap', 'dişlilerin statik kapasitesi', 'pk', 'tepe tork', ...
               'qs', 'yarı-statik J_p·ω_p/t', 'stitle', 'Ani durma (LD-08): güç türbini kilitlenirse pervane milindeki tork');
else
    L = struct('x', 'Power turbine speed (%)', 'y', 'Frequency (Hz)', 'band', 'steady range', ...
               'mode', 'torsional mode', 'ptitle', 'Torsional Campbell diagram: modes and excitation orders', ...
               'sx', 'Power turbine stopping time (s)', 'sy', 'Peak torque in the propeller shaft (N·m)', ...
               'ld', 'LD-01 limit', 'cap', 'static capacity of the gears', 'pk', 'peak torque', ...
               'qs', 'quasi-static J_p·ω_p/t', 'stitle', 'Sudden stoppage (LD-08): propeller shaft torque if the power turbine seizes');
end
% Torsional Campbell
fig = figure('Visible', 'off', 'Position', [100 100 900 560]);
pct = linspace(0, 110, 221);
np = S.n_prop * pct / 100;
hold on
f_top = 950;
patch(100 * [in.n_steady(1) in.n_steady(2) in.n_steady(2) in.n_steady(1)], [0 0 f_top f_top], [0.96 0.84 0.43], ...
      'FaceAlpha', 0.45, 'EdgeColor', 'none');
cols = lines(numel(in.P_orders) + numel(in.PT_orders) + 1);
c = 0;
for o = [in.P_orders, in.P_watch]
    c = c + 1;
    y = o * np / 60;
    ls = '-';
    if o == in.P_watch, ls = ':'; end
    plot(pct, y, ls, 'Color', cols(c, :), 'LineWidth', 1.0);
    k = find(y < f_top, 1, 'last');
    text(pct(k), y(k), sprintf(' %gP', o), 'Color', cols(c, :), 'FontSize', 8, 'VerticalAlignment', 'bottom');
end
for o = in.PT_orders
    c = c + 1;
    y = o * in.n_PT * pct / 100 / 60;
    plot(pct, y, '--', 'Color', cols(c, :), 'LineWidth', 1.0);
    k = find(y < f_top, 1, 'last');
    text(pct(k), y(k), sprintf(' %g× PT', o), 'Color', cols(c, :), 'FontSize', 8, 'VerticalAlignment', 'bottom');
end
for k = 1:numel(md.f)
    if md.f(k) < f_top
        yline(md.f(k), '-', sprintf('%.0f Hz: %s', md.f(k), elname(md.main{k}, lang)), 'Color', [0.2 0.2 0.2], ...
              'LineWidth', 1.4, 'FontSize', 8, 'LabelHorizontalAlignment', 'left');
    end
end
xlim([0 110]);  ylim([0 f_top]);  grid on;  box on
xlabel(L.x);  ylabel(L.y);
title(L.ptitle, 'FontWeight', 'normal', 'FontSize', 10);
exportgraphics(fig, fullfile(out_dir, ['campbell_' lang '.png']), 'Resolution', 150);
close(fig);

% Sudden stoppage
fig = figure('Visible', 'off', 'Position', [100 100 760 470]);
t = [S.stop.t_stop];
pk = arrayfun(@(s) s.peak(S.ip), S.stop);
qs = [S.stop.T_qs];
loglog(t, pk, 'o-', 'Color', [0.75 0.22 0.17], 'LineWidth', 1.4, 'MarkerFaceColor', [0.75 0.22 0.17]);
hold on
loglog(t, qs, '--', 'Color', [0.35 0.35 0.35], 'LineWidth', 1.0);
yline(in.T_LD01, '-', L.ld, 'Color', [0.12 0.44 0.70], 'LineWidth', 1.2, 'LabelHorizontalAlignment', 'left');
yline(S.T_cap, '-', L.cap, 'Color', [0.2 0.2 0.2], 'LineWidth', 1.2, 'LabelHorizontalAlignment', 'left');
xline(S.t_min_LD01, ':', sprintf('%.2f s', S.t_min_LD01), 'Color', [0.12 0.44 0.70]);
xline(S.t_min_cap, ':', sprintf('%.2f s', S.t_min_cap), 'Color', [0.2 0.2 0.2]);
grid on;  box on
xlabel(L.sx);  ylabel(L.sy);
legend({L.pk, L.qs}, 'Location', 'southwest', 'FontSize', 8);
title(L.stitle, 'FontWeight', 'normal', 'FontSize', 10);
exportgraphics(fig, fullfile(out_dir, ['stop_' lang '.png']), 'Resolution', 150);
close(fig);
end

function s = elname(name, lang)
% Element names in Turkish for the Turkish plots
if ~strcmp(lang, 'tr')
    s = name;
    return
end
tr = {'propeller shaft', 'pervane mili'; 'generator quill', 'jeneratör tork mili'; ...
      'floating shaft', 'yüzer mil'; 'intermediate shaft', 'ara mil'; ...
      'coupling 2 and input shaft', 'kaplin 2 ve giriş mili'; 'PT stub and coupling 1', 'GT çıkıntısı ve kaplin 1'; ...
      'generator mesh', 'jeneratör kavraması'; 'first-stage mesh', 'ilk kademe kavraması'};
k = find(strcmp(tr(:, 1), name), 1);
if isempty(k)
    s = name;
else
    s = tr{k, 2};
end
end
