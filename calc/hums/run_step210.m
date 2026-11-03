function R = run_step210(out_dir)
%RUN_STEP210  Step 2.10: condition monitoring of the RGB, fault frequencies and sensor positions (CTL-03).
%   R = run_step210()          results in calc/results/step210
%   R = run_step210(out_dir)
%
%   Runs from the repo root with calc/hums, calc/housing, calc/gear_detail,
%   calc/shafts_bearings and calc/accessory on the path. Steps:
%    1. the characteristic frequencies of every shaft, mesh, local gear
%       fault and bearing at 100% speed (hm_frequencies), with the lowest
%       and highest over the steady speed range (90-101%, SYS-03)
%    2. close pairs that a spectrum cannot tell apart (within 2%), which
%       need time-synchronous averaging on their own tachometer
%    3. the static transfer compliance from the bearing seats and the ring
%       gear seat to the outside of the case (hm_sensors) and the two
%       accelerometer positions it gives
%   Writes summary.txt, fault_frequencies.csv and two plots in English and
%   Turkish to out_dir (calc/results is not committed). About 2 minutes.
%
%   Source: Phase 2 report, Section 2.10.

if nargin < 1 || isempty(out_dir)
    out_dir = fullfile('calc', 'results', 'step210');
end
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
gi = gd_inputs();  sb = sb_inputs();  ad = ad_inputs();  hs = hs_inputs();
F = hm_frequencies(gi, sb, ad, 1);
Flo = hm_frequencies(gi, sb, ad, gi.speed_range(1));
Fhi = hm_frequencies(gi, sb, ad, gi.speed_range(2));
R = struct('F', F, 'speed_range', gi.speed_range);

% 1. one table of every line: [component, kind, Hz at 100%, low, high]
T = {};
for k = 1:numel(F.shaft)
    T(end + 1, :) = {F.shaft(k).name, 'shaft 1x', F.shaft(k).Hz, Flo.shaft(k).Hz, Fhi.shaft(k).Hz}; %#ok<AGROW>
end
for k = 1:numel(F.mesh)
    T(end + 1, :) = {F.mesh(k).name, 'mesh', F.mesh(k).Hz, Flo.mesh(k).Hz, Fhi.mesh(k).Hz}; %#ok<AGROW>
end
for k = 1:numel(F.gearfault)
    T(end + 1, :) = {F.gearfault(k).name, 'gear fault', F.gearfault(k).Hz, Flo.gearfault(k).Hz, Fhi.gearfault(k).Hz}; %#ok<AGROW>
end
kinds = {'cage', 'inner', 'outer', 'spin'};
for k = 1:numel(F.bearing)
    for q = 1:4
        T(end + 1, :) = {F.bearing(k).name, ['bearing ' kinds{q} ' (' F.bearing(k).frame ' frame)'], ...
                         F.bearing(k).(kinds{q}), Flo.bearing(k).(kinds{q}), Fhi.bearing(k).(kinds{q})}; %#ok<AGROW>
    end
end
R.table = T;
fid = fopen(fullfile(out_dir, 'fault_frequencies.csv'), 'w');
fprintf(fid, 'component,kind,Hz_100pct,Hz_90pct,Hz_101pct\n');
for k = 1:size(T, 1)
    fprintf(fid, '"%s","%s",%.2f,%.2f,%.2f\n', T{k, :});
end
fclose(fid);

% 2. close pairs (within 2 % at 100 %) between different components
f = [T{:, 3}];
P = zeros(0, 2);
for i = 1:numel(f)
    for j = i + 1:numel(f)
        if ~strcmp(T{i, 1}, T{j, 1}) && abs(f(i) - f(j)) / max(f(i), f(j)) < 0.02
            P(end + 1, :) = [i j]; %#ok<AGROW>
        end
    end
end
R.pairs = P;

% 3. sensor positions from the static transfer compliance
mat = hs.mat(1);
S = hm_sensors(hs.case, mat, 0.010);
R.sensors = S;
[~, i1] = max(S.c(3, :) .* (S.z >= 36 & S.z <= 106));      % on the case wall over the ring gear
[~, i2] = max(S.c(2, :) .* (S.z >= 412));                  % on the outer bearing boss
R.pos = [S.z(i1) S.r(i1); S.z(i2) S.r(i2)];

write_summary(R, out_dir);
for lang = {'en', 'tr'}
    plots(R, out_dir, lang{1});
end
end

function write_summary(R, out_dir)
F = R.F;  T = R.table;
fid = fopen(fullfile(out_dir, 'summary.txt'), 'w');
fprintf(fid, 'Step 2.10: RGB characteristic frequencies at 100%% speed (range %.0f-%.0f%%) and sensor positions\n\n', ...
        100 * R.speed_range);
for s = F.shaft, fprintf(fid, '%-34s %9.1f rpm %9.2f Hz\n', s.name, s.rpm, s.Hz); end
fprintf(fid, '\n');
for s = F.mesh, fprintf(fid, '%-46s mesh %9.1f Hz\n', s.name, s.Hz); end
for s = F.gearfault, fprintf(fid, '%-46s      %9.2f Hz\n', s.name, s.Hz); end
fprintf(fid, '\nBearings (Hz): shaft, cage, inner race defect, outer race defect, rolling element spin\n');
for b = F.bearing
    fprintf(fid, '  %-28s Z %2d  %8.2f %8.2f %9.1f %9.1f %8.1f  (%s frame)\n', b.name, b.Z, b.shaft, b.cage, ...
            b.inner, b.outer, b.spin, b.frame);
end
fprintf(fid, '\nLines within 2%% of each other (need their own synchronous average):\n');
for k = 1:size(R.pairs, 1)
    i = R.pairs(k, 1);  j = R.pairs(k, 2);
    fprintf(fid, '  %s, %s %.2f Hz  /  %s, %s %.2f Hz\n', T{i, 1}, T{i, 2}, T{i, 3}, T{j, 1}, T{j, 2}, T{j, 3});
end
S = R.sensors;
fprintf(fid, '\nStatic transfer compliance to the top of the case, largest (um/kN): %s from %s\n', ...
        mat2str(round(max(S.c, [], 2)' * 1e9, 2)), strjoin(S.src, ', '));
fprintf(fid, 'Accelerometer 1 on the case wall over the ring gear: z %.0f mm, r %.1f mm\n', R.pos(1, :));
fprintf(fid, 'Accelerometer 2 on the outer propeller bearing boss: z %.0f mm, r %.1f mm\n', R.pos(2, :));
fclose(fid);
type(fullfile(out_dir, 'summary.txt'));
end

function plots(R, out_dir, lang)
tr = strcmp(lang, 'tr');
F = R.F;
% characteristic frequency map
fig = figure('Visible', 'off', 'Position', [100 100 1000 520]);
hold on
rows = [{F.shaft.name}, {F.mesh.name}, {F.gearfault.name}, {F.bearing.name}];
if tr
    rows = {'giriş mili (pinyon)', 'ara mil (güneş, pompalar)', 'taşıyıcı ve pervane mili', 'planet, pimi etrafında', ...
            'jeneratör mili', 'OSG mili', 'PCU mili', 'birinci kademe ve jeneratör (z 31 / 110 / 57)', ...
            'planet kademesi (güneş-planet-halka)', 'OSG çifti (z 21 / 30)', 'PCU çifti (z 20 / 73)', ...
            'güneş dişi (bağıl turda N kez)', 'planet dişi (güneş ve halka)', 'halka dişi (taşıyıcı turunda N planet)', ...
            'planet geçişi', 'giriş makaralı', 'giriş QJ', 'ara mil makaralı', 'ara mil QJ', 'pervane iç makaralı', ...
            'pervane dış makaralı', 'pervane QJ', 'planet (tam dolu)', 'jeneratör mili yatağı', 'OSG mili yatağı', ...
            'PCU mili yatağı'};
end
y = 0;
c = struct('shaft', [0.12 0.44 0.70], 'mesh', [0.75 0.22 0.17], 'gear', [0.93 0.55 0.13], 'brg', [0.18 0.55 0.34]);
for s = F.shaft, y = y + 1; plot(s.Hz, y, 'o', 'Color', c.shaft, 'MarkerFaceColor', c.shaft); end
for s = F.mesh, y = y + 1; plot(s.Hz, y, 's', 'Color', c.mesh, 'MarkerFaceColor', c.mesh); end
for s = F.gearfault, y = y + 1; plot(s.Hz, y, 'd', 'Color', c.gear, 'MarkerFaceColor', c.gear); end
mk = {'v', '^', '>', 'x'};
for b = F.bearing
    y = y + 1;
    v = [b.cage b.inner b.outer b.spin];
    for q = 1:4
        plot(v(q), y, mk{q}, 'Color', c.brg, 'MarkerFaceColor', c.brg);
    end
end
set(gca, 'XScale', 'log', 'YTick', 1:y, 'YTickLabel', rows, 'YDir', 'reverse', 'FontSize', 8);
xlim([5 20000]);  ylim([0.5 y + 0.5]);  grid on;  box on
if tr
    xlabel('Frekans (Hz), %100 hızda');
    title('RGB karakteristik frekansları: mil, kavrama, yerel dişli hatası, rulman (kafes, iç, dış, yuvarlanma elemanı)', ...
          'FontWeight', 'normal', 'FontSize', 10);
else
    xlabel('Frequency (Hz) at 100% speed');
    title('RGB characteristic frequencies: shaft, mesh, local gear fault, bearing (cage, inner, outer, rolling element)', ...
          'FontWeight', 'normal', 'FontSize', 10);
end
exportgraphics(fig, fullfile(out_dir, ['freq_map_' lang '.png']), 'Resolution', 150);
close(fig);
% sensor compliance along the case
S = R.sensors;
fig = figure('Visible', 'off', 'Position', [100 100 900 420]);
cc = [0.12 0.44 0.70; 0.75 0.22 0.17; 0.18 0.55 0.34];
hold on
for q = 1:3
    plot(S.z, S.c(q, :) * 1e9, '-', 'Color', cc(q, :), 'LineWidth', 1.5);
end
for k = 1:2
    xline(R.pos(k, 1), '--k');
end
grid on;  box on;  xlim([0 450]);
if tr
    xlabel('z (mm), gövdenin üst çizgisi boyunca, flanştan pervaneye');  ylabel('Radyal yer değiştirme / yük (µm/kN)');
    legend({'iç pervane yatağından', 'dış pervane yatağından', 'halka dişliden (planet kavramaları)', 'ivmeölçer 1 ve 2'}, ...
           'Location', 'northwest');
    title('Kaynaklardan gövde yüzeyine statik aktarım: ivmeölçer yerleri', 'FontWeight', 'normal', 'FontSize', 10);
else
    xlabel('z (mm) along the top line of the case, flange to propeller');  ylabel('Radial displacement / load (µm/kN)');
    legend({'from the inner propeller bearing', 'from the outer propeller bearing', 'from the ring gear (planetary meshes)', ...
            'accelerometers 1 and 2'}, 'Location', 'northwest');
    title('Static transfer from the sources to the case surface: accelerometer positions', 'FontWeight', 'normal', 'FontSize', 10);
end
exportgraphics(fig, fullfile(out_dir, ['sensors_' lang '.png']), 'Resolution', 150);
close(fig);
end
