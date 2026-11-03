function sf_plot_fire(Fz, in, lang, out_dir)
%SF_PLOT_FIRE  Fire assessment (D5) in Turkish or English: fire_<lang>.png.
%   Left: flame-side temperature of each wall in the standard flame at its upper tolerance, 5 min with the oil-side
%   h of its basis, against the A357 solidus. Right: the smallest oil-side h for 5 min per wall against its basis.
%   sf_plot_fire(Fz, in, lang, out_dir)   Fz = sf_fire_all(in)
%   Source: Phase 3 report, Section 3.7 (D5).

tr = strcmp(lang, 'tr');
fw = in.fire;  T = Fz.T;  nw = height(T);
fig = figure('Visible', 'off', 'Position', [100 100 1400 520], 'Color', 'w');
subplot(1, 2, 1);  hold on;  grid on
cl = [0.15 0.35 0.65; 0.80 0.10 0.10; 0.30 0.60 0.30; 0.55 0.35 0.70];
for w = 1:nw
    W = Fz.hist{w};
    if tr, nm = T.wall_tr(w); else, nm = T.wall(w); end
    plot(W.t / 60, W.T_hot, '-', 'Color', cl(w, :), 'LineWidth', 1.6, 'DisplayName', sprintf('%s, h %.0f', nm, T.h_basis_W_m2K(w)));
end
yline(fw.T_solidus, 'r--', 'LineWidth', 1.2, 'HandleVisibility', 'off');
yline(fw.oil.ait, 'k:', 'LineWidth', 1.2, 'HandleVisibility', 'off');
ylim([0 650]);  xlim([0 5]);
if tr
    xlabel('süre [dk]');  ylabel('alev tarafı sıcaklığı [°C]');
    title({sprintf('Standart alev üst toleransta (%g °C, %g kW/m^2), batma %g °C', fw.T_f, fw.q0 / 1e3, fw.T_sink), ...
           sprintf('kesikli: A357 katılaşma %g °C (eriyik); noktalı: yağ kendiliğinden tutuşma %g °C', fw.T_solidus, fw.oil.ait)}, 'FontSize', 9);
else
    xlabel('time [min]');  ylabel('flame-side temperature [degC]');
    title({sprintf('Standard flame at its upper tolerance (%g degC, %g kW/m^2), sink %g degC', fw.T_f, fw.q0 / 1e3, fw.T_sink), ...
           sprintf('dashed: A357 solidus %g degC (molten); dotted: oil auto-ignition %g degC', fw.T_solidus, fw.oil.ait)}, 'FontSize', 9);
end
legend('Location', 'southeast', 'FontSize', 7);
subplot(1, 2, 2);  hold on;  grid on
b = bar(1:nw, [T.h_min_W_m2K, T.h_basis_W_m2K], 0.7);
b(1).FaceColor = [0.80 0.10 0.10];  b(2).FaceColor = [0.15 0.35 0.65];
for w = 1:nw, text(w - 0.15, T.h_min_W_m2K(w) + 20, sprintf('%.0f', T.h_min_W_m2K(w)), 'HorizontalAlignment', 'center', 'FontSize', 8); end
set(gca, 'XTick', 1:nw);
if tr
    set(gca, 'XTickLabel', T.wall_tr);  ylabel('yağ tarafı h [W/m^2K]');
    legend({'5 dk için gereken en küçük h', 'esas (en düşük akışta film ya da filmsiz değer)'}, 'Location', 'northeast', 'FontSize', 8);
    title('5 dk yangına dayanım için gereken yağ soğutması', 'FontSize', 10);
else
    set(gca, 'XTickLabel', T.wall);  ylabel('oil-side h [W/m^2K]');
    legend({'smallest h for 5 min', 'basis (film at the lowest flow, or the no-film value)'}, 'Location', 'northeast', 'FontSize', 8);
    title('Oil cooling needed for 5 min fire resistance', 'FontSize', 10);
end
xtickangle(15);
set(findall(fig, '-property', 'FontName'), 'FontName', 'Arial');
exportgraphics(fig, fullfile(out_dir, ['fire_' lang '.png']), 'Resolution', 150);
close(fig);
end
