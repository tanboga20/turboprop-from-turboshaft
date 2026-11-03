function sf_plot_fta2(G, in, lang, out_dir)
%SF_PLOT_FTA2  Dual-failure trees (D1b) in Turkish or English: fta2_<lang>.png.
%   Cut sets of (a) PT overspeed and (b) the hazardous propeller effect against 1e-8 per hour (each individual
%   failure) on a log scale, the sums of each tree and of all hazardous effects (D1 + D1b) against 1e-7, and the
%   allowances handed to the propeller maker.
%   sf_plot_fta2(G, in, lang, out_dir)   G = sf_fta2(in) with G.sum_all
%   Source: Phase 3 report, Section 3.7 (D1b).

tr = strcmp(lang, 'tr');
fmt = @(p) sprintf('%.1e', p);
if tr, fmt = @(p) strrep(sprintf('%.1e', p), '.', ','); end
fig = figure('Visible', 'off', 'Position', [100 100 1500 760], 'Color', 'w');
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
c1 = [0.15 0.35 0.65];  c2 = [0.80 0.10 0.10];
T = {G.Ta, G.Tb};  s = [G.sum_a, G.sum_b];
if tr
    ttl = {'(a) PT aşırı devri (çevrelenmemiş PT diski)', ...
           '(b) Aşırı sürükleme veya pala kopmasına ya da aşırı dengesizliğe yol açan pervane aşırı devri (14 CFR 35.15(g)(1))'};
    xl = 'motor uçuş saati başına olasılık';
else
    ttl = {'(a) PT overspeed (uncontained PT disc)', ...
           '(b) Excessive drag, or propeller overspeed leading to blade release or excessive unbalance (14 CFR 35.15(g)(1))'};
    xl = 'probability per engine flight hour';
end
for k = 1:2
    ax = nexttile(tl);  hold(ax, 'on');  grid(ax, 'on');
    t = T{k};  n = height(t);
    P = t.P_per_h;
    b = barh(ax, 1:n, P, 0.6, 'FaceColor', c1);
    b.FaceColor = 'flat';  b.CData = repmat(c1, n, 1);  b.CData(P >= 0.999 * in.target_h, :) = repmat(c2, sum(P >= 0.999 * in.target_h), 1);
    xline(ax, in.target_h, '--', 'Color', c2, 'LineWidth', 1.2);
    set(ax, 'XScale', 'log', 'YDir', 'reverse', 'YTick', 1:n, 'FontSize', 8);
    if tr, lab = t.cut_set_tr; else, lab = t.cut_set_en; end
    set(ax, 'YTickLabel', cellfun(@(x) x(1:min(end, 110)), cellstr(lab), 'UniformOutput', false));
    xlim(ax, [1e-12 1e-7]);
    for i = 1:n, text(ax, P(i) * 1.3, i, fmt(P(i)), 'FontSize', 7); end
    if tr, st = sprintf('toplam %s /h', fmt(s(k))); else, st = sprintf('sum %s /h', fmt(s(k))); end
    title(ax, [ttl{k} '; ' st], 'FontSize', 9, 'FontWeight', 'normal');
    xlabel(ax, xl);
end
A = G.allow;
if tr
    sg = sprintf(['D1b: her kesim kümesi <= 1e-8 /h; tüm tehlikeli etkilerin toplamı (D1 + D1b) %s /h <= 1e-7. Pervane üreticisine paylar ' ...
          '(ortalama kullanılamazlık lambda T / 2 + q_d): alt hatve durdurucusu %s (kontrol <= %.0f h), karşı ağırlıklı tüyleme %s; ' ...
          'OSG testi: FADEC tüylemesiyle >= %.0f h, onsuz %.0f h'], fmt(G.sum_all), fmt(A.q_lps), A.T_lps, fmt(A.q_cw), ...
          min(A.T_osg, 1e6), A.T_osg_noFF);
else
    sg = sprintf(['D1b: each cut set <= 1e-8 /h; all hazardous effects (D1 + D1b) %s /h <= 1e-7. Allowances to the propeller ' ...
          'maker (mean unavailability lambda T / 2 + q_d): low-pitch stop %s (check <= %.0f h), counterweight feathering %s; ' ...
          'OSG test: >= %.0f h with the FADEC feather, %.0f h without it'], fmt(G.sum_all), fmt(A.q_lps), A.T_lps, fmt(A.q_cw), ...
          min(A.T_osg, 1e6), A.T_osg_noFF);
end
k = strfind(sg, '. ');  sgtitle(fig, {sg(1:k(1)), sg(k(1) + 2:end)}, 'FontSize', 9);
set(findall(fig, '-property', 'FontName'), 'FontName', 'Arial');
exportgraphics(fig, fullfile(out_dir, ['fta2_' lang '.png']), 'Resolution', 150);
close(fig);
end
