function tl_plot_thermal(Th, in, lang, out_dir)
%TL_PLOT_THERMAL  Cold-start transient of the part temperatures (E2) in Turkish or English: thermal_<lang>.png.
%   tl_plot_thermal(Th, in, lang, out_dir)   Th = tl_thermal(in)
%   Source: Phase 3 report, Section 3.8 (E2).

tr = strcmp(lang, 'tr');
X = Th.tr;
fig = figure('Visible', 'off', 'Position', [100 100 1000 480], 'Color', 'w');
hold on;  grid on
p = {'oil_in', 'gear2', 'sun', 'ring', 'carrier', 'liner', 'case_f', 'case_p'};
st = {'-k', '-', '-', '-', '-', '--', '-', '--'};
cl = [0 0 0; 0.80 0.10 0.10; 0.90 0.45 0.10; 0.55 0.35 0.65; 0.15 0.55 0.30; 0.45 0.45 0.45; 0.15 0.35 0.65; 0.15 0.35 0.65];
lg = cell(1, numel(p));
for k = 1:numel(p)
    j = find(strcmp(in.th.parts, p{k}));
    plot(X.t / 60, X.(p{k}), st{k}, 'Color', cl(k, :), 'LineWidth', 1.5);
    if tr, lg{k} = in.th.parts_tr{j}; else, lg{k} = in.th.parts_en{j}; end
end
xline(in.th.cold.t_ok / 60, ':k');
d = X.gear2 - X.case_f;  [~, i] = max(d);
xline(X.t(i) / 60, ':r');
xlim([0 X.t(end) / 60]);
if tr
    xlabel('süre [dk]');  ylabel('sıcaklık [°C]');
    title({'-40 °C bekleme sonrası ilk çalışma: rölanti, sonra MCT (yağ girişi soğuk günde 60 °C)', ...
           sprintf('dişliler gövdeden önce ısınır: dişli 2 - birinci kademe gövdesi en çok %.0f K (%.1f dk)', max(d), X.t(i) / 60)}, ...
          'FontSize', 10);
else
    xlabel('time [min]');  ylabel('temperature [degC]');
    title({'Start after a -40 degC soak: ground idle, then MCT (oil in 60 degC on a cold day)', ...
           sprintf('the gears warm before the case: gear 2 - first-stage case at most %.0f K (%.1f min)', max(d), X.t(i) / 60)}, ...
          'FontSize', 10);
end
legend(lg, 'Location', 'southeast', 'FontSize', 8);
set(findall(fig, '-property', 'FontName'), 'FontName', 'Arial');
exportgraphics(fig, fullfile(out_dir, ['thermal_' lang '.png']), 'Resolution', 150);
close(fig);
end
