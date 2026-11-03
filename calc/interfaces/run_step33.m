function T = run_step33(out_dir)
%RUN_STEP33  Step 3.3: sensitivity of the design to the interface values of the ICD.
%   T = run_step33()          writes requirements/icd_sensitivity_v1.csv and plots to calc/results/step33
%   T = run_step33(out_dir)
%
%   Run from the repo root with calc/interfaces, calc/shafts_bearings,
%   calc/gear_detail, calc/accessory, calc/pt_shaft, calc/rotor_damper,
%   calc/oil_system, calc/assembly, calc/lubrication and calc/agb_lube on
%   the path (about 3 minutes: the propeller load cases rerun step 2.5).
%   The ICD itself is requirements/icd_v1.csv (requirements/make_icd.py);
%   this run gives the sensitivity column its numbers and draws the margins
%   of each interface at its assumed value and at the ends of its range, in
%   Turkish and English (margins_<lang>.png).
%   Source: Phase 3 report, Section 3.3.

if nargin < 1 || isempty(out_dir)
    out_dir = fullfile('calc', 'results', 'step33');
end
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
T = if_sens();
writetable(T, fullfile('requirements', 'icd_sensitivity_v1.csv'));
disp(T(:, [1 2 4 5 6 8 9]));
for lang = {'tr', 'en'}
    plot_margins(T, lang{1}, out_dir);
end
save(fullfile(out_dir, 'step33.mat'), 'T');
end

function plot_margins(T, lang, out_dir)
% one row per interface quantity with a limit: the margin at the assumed value (dot) and its range (bar)
tr = strcmp(lang, 'tr');
T = T(~isnan(T.margin) & isfinite(T.margin), :);
[q, ~, j] = unique(strcat(T.id, " ", T.quantity), 'stable');
% leave out the quantities that change by less than 2% over their range (named in the report text)
keep = arrayfun(@(k) sum(j == k) == 1 || max(T.margin(j == k)) / max(min(T.margin(j == k)), 1e-6) > 1.02 || min(T.margin(j == k)) < 0, 1:numel(q));
T = T(keep(j), :);
[q, ~, j] = unique(strcat(T.id, " ", T.quantity), 'stable');
T.margin = max(T.margin, 0.31);                        % below 0.3 (also negative) drawn at the left edge
fig = figure('Visible', 'off', 'Position', [100 100 1200 700]);
hold on;  grid on
for k = 1:numel(q)
    m = T.margin(j == k);
    b = T.margin(j == k & T.base == 1);
    plot([min(m) max(m)], [k k], '-', 'Color', [0.6 0.7 0.85], 'LineWidth', 6);
    if ~isempty(b), plot(b, k, 'o', 'MarkerFaceColor', [0.15 0.35 0.65], 'MarkerEdgeColor', 'k', 'MarkerSize', 7); end
end
xline(1, 'r--', 'LineWidth', 1.5);
text(0.315, numel(q) + 0.8, '< 0.3', 'FontSize', 8);
set(gca, 'YTick', 1:numel(q), 'YTickLabel', q, 'YDir', 'reverse', 'FontSize', 8, 'XScale', 'log');
xlim([0.3 12]);
if tr
    xlabel('pay (sonuç / sınır; 1 = sınırda)');
    title('Arayüz değerlerine duyarlılık: varsayılan değerde pay (nokta) ve aralık boyunca pay (çubuk)');
else
    xlabel('margin (result / limit; 1 = at the limit)');
    title('Sensitivity to the interface values: margin at the assumed value (dot) and over the range (bar)');
end
set(findall(fig, '-property', 'FontName'), 'FontName', 'Arial');
exportgraphics(fig, fullfile(out_dir, ['margins_' lang '.png']), 'Resolution', 150);
close(fig);
end
