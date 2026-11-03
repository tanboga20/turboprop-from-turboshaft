function tl_plot_stack(B, K, in, lang, out_dir)
%TL_PLOT_STACK  Stack-up figures (E3) in Turkish or English: backlash_<lang>.png and kgamma_<lang>.png.
%   Backlash: the first-stage normal backlash (worst-case minimum and maximum, MC -3 sigma minimum) over the
%   cold-start transient and at the steady states, and the planetary meshes. K_gamma: the distribution with
%   the drawing tolerances as +-3 sigma normal, P90, P99 and the STR-07 limit.
%   tl_plot_stack(B, K, in, lang, out_dir)
%   Source: Phase 3 report, Section 3.8 (E3).

tr = strcmp(lang, 'tr');
fig = figure('Visible', 'off', 'Position', [100 100 1300 500], 'Color', 'w');
subplot(1, 2, 1);  hold on;  grid on
s = B.s1_tr;
plot(s.t / 60, 1000 * s.j_min_wc, '-', 'Color', [0.80 0.10 0.10], 'LineWidth', 1.6);
plot(s.t / 60, 1000 * s.j_min_mc, '--', 'Color', [0.80 0.10 0.10], 'LineWidth', 1.2);
plot(s.t / 60, 1000 * s.j_max_wc, '-', 'Color', [0.15 0.35 0.65], 'LineWidth', 1.6);
plot(B.pl_tr.t / 60, 1000 * B.pl_tr.j_pr_min, '-', 'Color', [0.15 0.55 0.30], 'LineWidth', 1.2);
plot(B.pl_tr.t / 60, 1000 * B.pl_tr.j_sp_min, '--', 'Color', [0.15 0.55 0.30], 'LineWidth', 1.2);
yline(0, 'k-');
[~, i] = min(s.j_min_wc);
plot(s.t(i) / 60, 1000 * s.j_min_wc(i), 'o', 'MarkerFaceColor', [0.8 0.1 0.1], 'MarkerEdgeColor', 'k');
xlim([0 s.t(end) / 60]);
if tr
    xlabel('-40 °C beklemeden sonra süre [dk]');  ylabel('normal boşluk [\mum]');
    title({'Diş boşluğu, ilk çalışma geçişinde', sprintf('birinci kademe en az %.0f \\mum (en kötü durum), en çok %.0f \\mum (tüm durumlar)', ...
           1000 * s.j_min_wc_min, 1000 * s.j_max_all)}, 'FontSize', 10);
    legend({'birinci kademe, en az (en kötü durum)', 'birinci kademe, en az (MC -3\sigma)', 'birinci kademe, en çok (en kötü durum)', ...
            'planet-halka, en az', 'güneş-planet, en az'}, 'Location', 'southeast', 'FontSize', 8);
else
    xlabel('time after the -40 degC soak [min]');  ylabel('normal backlash [\mum]');
    title({'Backlash in the cold-start transient', sprintf('first stage at least %.0f \\mum (worst case), at most %.0f \\mum (all states)', ...
           1000 * s.j_min_wc_min, 1000 * s.j_max_all)}, 'FontSize', 10);
    legend({'first stage, min (worst case)', 'first stage, min (MC -3\sigma)', 'first stage, max (worst case)', ...
            'planet-ring, min', 'sun-planet, min'}, 'Location', 'southeast', 'FontSize', 8);
end
subplot(1, 2, 2);  hold on;  grid on
histogram(K.all, 60, 'Normalization', 'pdf', 'FaceColor', [0.15 0.35 0.65], 'EdgeColor', 'none');
row = K.T(K.T.distribution == "normal" & K.T.torque_share == 1, :);
xline(row.P90, '--k');  xline(row.P99, '-k');  xline(K.limit, 'r-', 'LineWidth', 1.5);
if tr
    xlabel('K_\gamma (%100 tork)');  ylabel('olasılık yoğunluğu');
    title({'Planet yük paylaşımı, resim toleransları \pm3\sigma normal', ...
           sprintf('P90 %s, P99 %s (STR-07 sınırı %s)', strrep(sprintf('%.3f', row.P90), '.', ','), ...
           strrep(sprintf('%.3f', row.P99), '.', ','), strrep(sprintf('%.2f', K.limit), '.', ','))}, 'FontSize', 10);
    legend({'örnekler', 'P90 (STR-02)', 'P99', 'STR-07 sınırı'}, 'Location', 'northeast', 'FontSize', 8);
else
    xlabel('K_\gamma (100% torque)');  ylabel('probability density');
    title({'Planet load sharing, drawing tolerances as \pm3\sigma normal', ...
           sprintf('P90 %.3f, P99 %.3f (STR-07 limit %.2f)', row.P90, row.P99, K.limit)}, 'FontSize', 10);
    legend({'samples', 'P90 (STR-02)', 'P99', 'STR-07 limit'}, 'Location', 'northeast', 'FontSize', 8);
end
set(findall(fig, '-property', 'FontName'), 'FontName', 'Arial');
exportgraphics(fig, fullfile(out_dir, ['stack_' lang '.png']), 'Resolution', 150);
close(fig);
end
