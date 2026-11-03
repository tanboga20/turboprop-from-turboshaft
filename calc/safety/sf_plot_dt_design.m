function sf_plot_dt_design(Z, in, lang, out_dir)
%SF_PLOT_DT_DESIGN  D4 design studies in Turkish or English: dt_design_<lang>.png.
%   Left: the P103 thread options, a_HCF against the design rule (1.25 x the deepest MPI pair) with the
%   inspection interval for the MPI and the eddy current sizes. Middle: the 1P moment, a_HCF of the P103 seat, the thread and the case junction against
%   M_1P with the largest M_1P for which the base-case conclusions hold. Right: the carrier rim ligament, a_HCF
%   and the interval against the ligament width.
%   sf_plot_dt_design(Z, in, lang, out_dir)   Z = sf_dt_design(in)
%   Source: Phase 3 report, Section 3.7 (D4).

tr = strcmp(lang, 'tr');
fig = figure('Visible', 'off', 'Position', [100 100 1500 460], 'Color', 'w');
tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
c1 = [0.15 0.35 0.65];  c2 = [0.80 0.10 0.10];  c3 = [0.30 0.60 0.30];  c4 = [0.55 0.35 0.70];
% thread options
ax = nexttile(tl);  hold(ax, 'on');  grid(ax, 'on');
T = Z.thread;  n = height(T);
b = bar(ax, 1:n, T.a_hcf_mm, 0.6, 'FaceColor', c1);
b.FaceColor = 'flat';  b.CData = repmat(c1, n, 1);  b.CData(T.adopted, :) = c3;
need = in.dt.rule_ndt * max(in.dt.ndt.MPI.surf(:, 1));
yline(ax, need, '--', 'Color', c2, 'LineWidth', 1.2);
for k = 1:n
    s = sprintf('MPI %d / ET %d TBO', T.interval_tbo(k), T.interval_tbo_ET(k));
    text(ax, k, T.a_hcf_mm(k) + 0.08, s, 'HorizontalAlignment', 'center', 'FontSize', 8);
end
if tr, lab = T.option_tr; else, lab = T.option_en; end
set(ax, 'XTick', 1:n, 'XTickLabel', cellfun(@(s) strrep(s, ' rolled', ''), cellstr(lab), 'UniformOutput', false), ...
    'XTickLabelRotation', 15, 'FontSize', 8);
ylim(ax, [0 max(T.a_hcf_mm) * 1.25]);
if tr
    ylabel(ax, 'a_{HCF} [mm]');
    title(ax, {'P103 KM24 dişi: seçenekler', ['kural: a_{HCF} >= 1,25 x ' strrep(sprintf('%.2f', max(in.dt.ndt.MPI.surf(:, 1))), '.', ',') ' mm (MPI)']}, ...
          'FontWeight', 'normal', 'FontSize', 9);
else
    ylabel(ax, 'a_{HCF} [mm]');
    title(ax, {'P103 KM24 thread: options', sprintf('rule: a_{HCF} >= 1.25 x %.2f mm (MPI)', max(in.dt.ndt.MPI.surf(:, 1)))}, ...
          'FontWeight', 'normal', 'FontSize', 9);
end
% 1P moment
ax = nexttile(tl);  hold(ax, 'on');  grid(ax, 'on');
M = Z.m1p;  locs = unique(M.location_en, 'stable');  col = {c1, c3, c2, c4};
for j = 1:numel(locs)
    k = M.location_en == locs(j);
    if tr, nm = M.location_tr(find(k, 1)); else, nm = locs(j); end
    plot(ax, M.M_1P_Nm(k), M.a_hcf_mm(k), '-o', 'Color', col{j}, 'MarkerFaceColor', col{j}, 'LineWidth', 1.3, ...
         'DisplayName', nm);
end
xline(ax, Z.m1p_limit, '--k', 'HandleVisibility', 'off');
if tr
    xlabel(ax, 'M_{1P} [N m]');  ylabel(ax, 'a_{HCF} [mm]');
    title(ax, {'1P momenti duyarlılığı', sprintf('temel sonuçlar M_{1P} <= %.0f N m''ye kadar geçerli (ICD-10 notu)', ...
          floor(Z.m1p_limit / 10) * 10)}, 'FontWeight', 'normal', 'FontSize', 9);
else
    xlabel(ax, 'M_{1P} [N m]');  ylabel(ax, 'a_{HCF} [mm]');
    title(ax, {'1P moment sensitivity', sprintf('base-case results hold up to M_{1P} = %.0f N m (ICD-10 note)', ...
          floor(Z.m1p_limit / 10) * 10)}, 'FontWeight', 'normal', 'FontSize', 9);
end
legend(ax, 'Location', 'northeast', 'FontSize', 7);
% carrier ligament
ax = nexttile(tl);  hold(ax, 'on');  grid(ax, 'on');
B = Z.boss;
yyaxis(ax, 'left');
plot(ax, B.ligament_mm, B.a_hcf_mm, '-o', 'Color', c1, 'MarkerFaceColor', c1, 'LineWidth', 1.3);
yline(ax, max(in.dt.ndt.MPI.corner(:, 1)), ':', 'Color', c1);
if tr, ylabel(ax, 'a_{HCF} [mm]'); else, ylabel(ax, 'a_{HCF} [mm]'); end
ax.YColor = c1;
yyaxis(ax, 'right');
stairs(ax, B.ligament_mm, B.interval_tbo, '-', 'Color', c2, 'LineWidth', 1.3);
ylim(ax, [-0.2 max(2, max(B.interval_tbo) + 1)]);
ax.YColor = c2;
if tr
    ylabel(ax, 'muayene aralığı [TBO]');  xlabel(ax, 'pim deliği dış bağ kalınlığı b [mm]');
    title(ax, {'P103 taşıyıcısı: yerel çıkıntılar (seçilmedi; pim deliklerinde ET)', 'a_{HCF} bağ genişliğiyle değil, geçme çevresel gerilmesiyle (yüksek R) belirlenir'}, ...
          'FontWeight', 'normal', 'FontSize', 9);
else
    ylabel(ax, 'inspection interval [TBO]');  xlabel(ax, 'rim ligament b at the pin bore [mm]');
    title(ax, {'P103 carrier: local rim bosses (not adopted; ET of the pin bores)', 'a_{HCF} is set by the press-fit hoop (high R), not the ligament'}, ...
          'FontWeight', 'normal', 'FontSize', 9);
end
set(findall(fig, '-property', 'FontName'), 'FontName', 'Arial');
exportgraphics(fig, fullfile(out_dir, ['dt_design_' lang '.png']), 'Resolution', 150);
close(fig);
end
