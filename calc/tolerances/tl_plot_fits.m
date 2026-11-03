function tl_plot_fits(F, in, lang, out_dir)
%TL_PLOT_FITS  Fits at temperature (E4) in Turkish or English: fits_<lang>.png.
%   Left: the ring gear seat radial interference (smallest and largest) and the A357 hoop stress per state,
%   against the MCT and LD-02 needs and sigma_y / 1.25. Right: the smallest radial internal clearance of the
%   roller bearings per state.
%   tl_plot_fits(F, in, lang, out_dir)   F = tl_fits(in, Th)
%   Source: Phase 3 report, Section 3.8 (E4).

tr = strcmp(lang, 'tr');
if tr, st = in.th.states_tr; else, st = in.th.states; end
ns = numel(st);
fig = figure('Visible', 'off', 'Position', [100 100 1300 520], 'Color', 'w');
subplot(1, 2, 1);  hold on;  grid on
x = 1:ns;
yyaxis left
hb = bar(x, [F.seat.delta_min_um, F.seat.delta_max_um - F.seat.delta_min_um], 'stacked', 'BarWidth', 0.5);
hb(1).FaceColor = [0.15 0.35 0.65];  hb(2).FaceColor = [0.65 0.78 0.92];   % smallest; band to the largest
yline(0, 'k-');
if tr, ylabel('radyal sıkılık [\mum]'); else, ylabel('radial interference [\mum]'); end
yyaxis right
plot(x, F.seat.hoop_max_MPa, 'o-', 'LineWidth', 1.5);
yline(F.seat_allow, 'r--');
ylim([0 1.1 * F.seat_allow]);
if tr, ylabel('A357 çevresel gerilme, en çok [MPa]'); else, ylabel('A357 hoop stress, max [MPa]'); end
set(gca, 'XTick', x, 'XTickLabel', st);
xtickangle(20);
if tr
    title({sprintf('Halka dişli yuvası: delik %+d / %+d \\mum, halka h5', in.seat.bore_dev(2), in.seat.bore_dev(1)), ...
           sprintf('MCT''de en az %.0f \\mum, soğukta %.0f MPa (izin %.0f); montaj: gövde %.0f °C''nin üstüne', ...
           F.seat_mct_min, F.seat_cold_hoop, F.seat_allow, F.T_assy)}, 'FontSize', 10);
else
    title({sprintf('Ring gear seat: bore %+d / %+d \\mum, ring h5', in.seat.bore_dev(2), in.seat.bore_dev(1)), ...
           sprintf('at least %.0f \\mum at MCT, %.0f MPa cold (allowed %.0f); assembly: case above %.0f degC', ...
           F.seat_mct_min, F.seat_cold_hoop, F.seat_allow, F.T_assy)}, 'FontSize', 10);
end
subplot(1, 2, 2);  hold on;  grid on
names = unique(F.brg.bearing(~startsWith(F.brg.bearing, 'QJ')), 'stable');
for b = 1:numel(names)
    k = F.brg.bearing == names(b);
    plot(x, F.brg.clearance_min_um(k), 'o-', 'LineWidth', 1.5);
end
yline(0, 'k-');
set(gca, 'XTick', x, 'XTickLabel', st);
xtickangle(20);
if tr
    ylabel('en küçük radyal iç boşluk [\mum]');
    title({'Makaralı rulmanların çalışma boşluğu', '(geçmeler, astarın soğuk A357 göbekte sıkışması, iç bilezik sıcaklık farkı)'}, 'FontSize', 10);
else
    ylabel('smallest radial internal clearance [\mum]');
    title({'Operating clearance of the roller bearings', '(fits, the liner squeezed by the cold A357 boss, inner ring warmer)'}, 'FontSize', 10);
end
legend(names, 'Location', 'southeast', 'FontSize', 8);
set(findall(fig, '-property', 'FontName'), 'FontName', 'Arial');
exportgraphics(fig, fullfile(out_dir, ['fits_' lang '.png']), 'Resolution', 150);
close(fig);
end
