function hs_plot_sections(out_dir)
%HS_PLOT_SECTIONS  The first and the final case sections side by side, with their cast fillets (design iteration).
%   hs_plot_sections()            writes to calc/results/step28
%   hs_plot_sections(out_dir)
%
%   Draws the half sections of in.case0 (flat front wall, cylindrical nose)
%   and in.case (conical nose) of hs_inputs with the R in.case.rf fillets of
%   hs_section, the bearing seats and the flange face, and writes
%   sections_en.png and sections_tr.png.
%   Source: Phase 2 report, Section 2.8 ("Design iteration").

if nargin < 1 || isempty(out_dir)
    out_dir = fullfile('calc', 'results', 'step28');
end
in = hs_inputs();
S = {in.case0, in.case.rects};
col = {[0.55 0.55 0.55], [0.12 0.44 0.70]};
for lang = {'en', 'tr'}
    tr = strcmp(lang{1}, 'tr');
    fig = figure('Visible', 'off', 'Position', [100 100 1000 520], 'Color', 'w');
    for k = 1:2
        subplot(1, 2, k);
        P = hs_section(S{k}, in.case.rf, [], 2);
        fill(P(:, 2), P(:, 1), col{k}, 'FaceAlpha', 0.35, 'EdgeColor', col{k}, 'LineWidth', 1.2);
        hold on
        plot([132 160], [90 90], 'r-', 'LineWidth', 3);
        plot([412 446], [90 90], 'r-', 'LineWidth', 3);
        plot([0 0], [129.5 153.5], 'k-', 'LineWidth', 3);
        axis equal;  grid on;  box on
        xlim([-10 460]);  ylim([0 170]);
        if tr
            xlabel('z (mm), flanştan pervaneye');  ylabel('r (mm)');
            t = {'İlk kesit: düz ön duvar, silindirik burun', 'Son kesit: konik burun (8 mm)'};
            text(150, 20, 'kırmızı: rulman yuvaları, siyah: bağlantı flanşı', 'FontSize', 8);
        else
            xlabel('z (mm), flange to propeller');  ylabel('r (mm)');
            t = {'First section: flat front wall, cylindrical nose', 'Final section: conical nose (8 mm)'};
            text(150, 20, 'red: bearing seats, black: attachment flange', 'FontSize', 8);
        end
        title(t{k}, 'FontWeight', 'normal', 'FontSize', 10);
    end
    exportgraphics(fig, fullfile(out_dir, ['sections_' lang{1} '.png']), 'Resolution', 150);
    close(fig);
end
end
