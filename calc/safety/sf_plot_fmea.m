function sf_plot_fmea(M, in, lang, out_dir)
%SF_PLOT_FMEA  FMEA summary (D2) in Turkish or English: failure modes per item group by CS-E 510 class, and the
%   detection means; fmea_<lang>.png.
%   sf_plot_fmea(M, in, lang, out_dir)   M = sf_fmea(in)
%   Source: Phase 3 report, Section 3.7 (D2).

tr = strcmp(lang, 'tr');
f = in.fmea;
fig = figure('Visible', 'off', 'Position', [100 100 1300 520], 'Color', 'w');
subplot(1, 2, 1);
G = M.by_group{:, :};
ng = size(G, 1);
b = barh(1:ng, G, 'stacked');
cols = [0.80 0.10 0.10; 0.95 0.60 0.15; 0.60 0.75 0.90];
for k = 1:3, b(k).FaceColor = cols(k, :); end
set(gca, 'YDir', 'reverse', 'YTick', 1:ng);
hold on;  grid on
for g = 1:ng
    if M.unmit_by_group(g) > 0
        s = sprintf('%d', M.unmit_by_group(g));
        text(sum(G(g, :)) + 0.3, g, ['(' s ')'], 'FontSize', 8, 'Color', [0.6 0 0]);
    end
end
xlim([0 max(sum(G, 2)) + 3]);
if tr
    set(gca, 'YTickLabel', f.groups_tr);
    legend(f.classes_tr, 'Location', 'southeast');
    xlabel('hata modu sayısı');
    title({'FMEA: CS-E 510 sınıfına göre hata modları (tasarım özellikleriyle)', ...
           '(parantezde: önlemsiz tehlikeli olanlar)'}, 'FontSize', 10);
else
    set(gca, 'YTickLabel', f.groups_en);
    legend(f.classes, 'Location', 'southeast');
    xlabel('number of failure modes');
    title({'FMEA: failure modes by CS-E 510 class (with the design features)', ...
           '(in brackets: hazardous before mitigation)'}, 'FontSize', 10);
end
subplot(1, 2, 2);
[d, o] = sort(M.detect, 'descend');
barh(1:numel(d), d, 'FaceColor', [0.15 0.35 0.65]);
set(gca, 'YDir', 'reverse', 'YTick', 1:numel(d));
grid on
if tr
    set(gca, 'YTickLabel', f.detect_tr(o));
    xlabel('bu yolu anan hata modu sayısı');
    title(sprintf('Algılama yolları (%d hata modu)', M.n), 'FontSize', 10);
else
    set(gca, 'YTickLabel', f.detect_en(o));
    xlabel('failure modes that name this means');
    title(sprintf('Detection means (%d failure modes)', M.n), 'FontSize', 10);
end
set(findall(fig, '-property', 'FontName'), 'FontName', 'Arial');
exportgraphics(fig, fullfile(out_dir, ['fmea_' lang '.png']), 'Resolution', 150);
close(fig);
end
