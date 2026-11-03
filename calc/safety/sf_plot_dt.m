function sf_plot_dt(D, in, lang, out_dir)
%SF_PLOT_DT  Damage tolerance (D4) in Turkish or English: dt_<lang>.png.
%   For each critical-part location, on its crack plane, against the crack depth on the initial shape (a / c
%   fixed): the LCF stress intensity range (no threshold: growth from the first cycle), the effective HCF range
%   with its threshold (the crossing is a_HCF), and the limit-load K over K_IC / 10; the initial flaw and the
%   detectable depths are marked.
%   sf_plot_dt(D, in, lang, out_dir)   D = sf_dt_all(in)
%   Source: Phase 3 report, Section 3.7 (D4).

tr = strcmp(lang, 'tr');
n = numel(D.loc);
fig = figure('Visible', 'off', 'Position', [100 100 2200 410 * ceil(n / 5)], 'Color', 'w');
tl = tiledlayout(fig, ceil(n / 5), 5, 'TileSpacing', 'compact', 'Padding', 'compact');
for k = 1:n
    R = D.R(k, 1);  L = R.L;  m = in.dt.mat.(L.mat);
    ax = nexttile(tl);  hold(ax, 'on');  grid(ax, 'on');
    r = L.a0 / L.c0;
    if R.through0                                       % through crack: K against the half-length c
        xmax = min(L.b, 3);
        aa = linspace(0.01, xmax, 120);
        Kt = @(c, s) s * sqrt(pi * c * 1e-3);
        Kl = Kt(aa, L.s_lcf) - max(Kt(aa, L.s_lcf_min), 0);
        Kh = Kt(aa, L.s_hmax) - max(Kt(aa, L.s_hmin), 0);
        Km = Kt(aa, L.s_lim);
    else
        xmax = 0.8 * L.t;
        if strcmp(L.kind, 'corner'), xmax = min(xmax, 0.4999 * L.b * r); end
        aa = linspace(0.1, xmax, 120);
        Kl = zeros(size(aa));  Kh = Kl;  Km = Kl;
        for i = 1:numel(aa)
            Kl(i) = max(Kp(L, aa(i), aa(i) / r, L.s_lcf) - max(Kp(L, aa(i), aa(i) / r, L.s_lcf_min), 0));
            Kx = Kp(L, aa(i), aa(i) / r, L.s_hmax);  Kn = Kp(L, aa(i), aa(i) / r, L.s_hmin);
            Kh(i) = max(Kx - max(Kn, 0));
            Km(i) = max(Kp(L, aa(i), aa(i) / r, L.s_lim));
        end
    end
    c1 = [0.15 0.35 0.65];  c2 = [0.80 0.10 0.10];  c3 = [0.4 0.4 0.4];
    plot(ax, aa, Kl, '-', 'Color', c1, 'LineWidth', 1.5);
    plot(ax, aa, Kh, '-', 'Color', c2, 'LineWidth', 1.5);
    plot(ax, aa, Km / 10, '-', 'Color', c3, 'LineWidth', 1.2);
    yline(ax, R.dKth_hcf, '--', 'Color', c2);
    yline(ax, m.KIC / 10, ':', 'Color', c3, 'LineWidth', 1.2);
    if R.through0
        xline(ax, L.c0, '-k');
        for j = 1:size(R.ndt_used, 1), xline(ax, R.ndt_used(j, 2), ':k'); end
    else
        xline(ax, L.a0, '-k');
        for j = 1:size(L.ndt, 1)
            if L.ndt(j, 1) < L.t, xline(ax, L.ndt(j, 1), ':k'); end
        end
    end
    if isfinite(R.a_hcf), plot(ax, R.a_hcf, R.dKth_hcf, 'o', 'MarkerFaceColor', c2, 'MarkerEdgeColor', 'k'); end
    xlim(ax, [0 xmax]);
    yl = ylim(ax);  ylim(ax, [0 max(yl(2), 1.15 * max([R.dKth_hcf m.KIC / 10]))]);
    if tr, ttl = L.tr; else, ttl = L.en; end
    if isfinite(R.a_hcf)
        s = sprintf('a_{HCF} %.2f mm', R.a_hcf);
    else
        s = 'a_{HCF} > 0,8 t';  if ~tr, s = 'a_{HCF} > 0.8 t'; end
    end
    if isinf(R.interval_tbo)
        si = 'no growth from the NDT size';  if tr, si = 'NDT boyundan büyüme yok'; end
    elseif R.interval_tbo == 0
        si = 'NDT before failure not assured';  if tr, si = 'hasardan önce NDT güvencesi yok'; end
    else
        si = sprintf('inspection every %d TBO', R.interval_tbo);  if tr, si = sprintf('her %d TBO''da muayene', R.interval_tbo); end
    end
    if tr, sp = sprintf('düzlem %.0f°', L.theta); else, sp = sprintf('plane %.0f deg', L.theta); end
    s = [sp '; ' s];
    if tr, s = strrep(s, '.', ','); end
    title(ax, {ttl, [s '; ' si]}, 'FontSize', 8.5, 'FontWeight', 'normal');
    if R.through0
        if tr, xlabel(ax, 'boydan boya çatlak yarı boyu c [mm]'); else, xlabel(ax, 'through-crack half-length c [mm]'); end
    else
        if tr, xlabel(ax, 'çatlak derinliği a [mm]'); else, xlabel(ax, 'crack depth a [mm]'); end
    end
    ylabel(ax, 'K [MPa \surdm]');
end
if tr
    lg = {'LCF \DeltaK (yer-hava-yer, eşiksiz)', 'HCF etkin \DeltaK', 'sınır yükte K / 10', 'HCF eşiği', 'K_{IC} / 10'};
    sgtitle(fig, sprintf(['Kritik parçalar: ilk kusur (CM-PIFS-007: 0,762 x 0,381 mm yüzey, 0,381 x 0,381 mm köşe; ' ...
            'gövdede gözenek) ve NDT boyları (noktalı, NASA-STD-5009C)']), 'FontSize', 10);
else
    lg = {'LCF \DeltaK (ground-air-ground, no threshold)', 'HCF effective \DeltaK', 'K at the limit load / 10', ...
          'HCF threshold', 'K_{IC} / 10'};
    sgtitle(fig, sprintf(['Critical parts: initial flaw (CM-PIFS-007: 0.762 x 0.381 mm surface, 0.381 x 0.381 mm ' ...
            'corner; pore in the case) and NDT sizes (dotted, NASA-STD-5009C)']), 'FontSize', 10);
end
lgd = legend(nexttile(tl, 1), lg, 'Orientation', 'horizontal', 'FontSize', 8);
lgd.Layout.Tile = 'south';
set(findall(fig, '-property', 'FontName'), 'FontName', 'Arial');
exportgraphics(fig, fullfile(out_dir, ['dt_' lang '.png']), 'Resolution', 150);
close(fig);
end

function K = Kp(L, a, c, s)
K = zeros(1, 2);  ph = [pi / 2, 0];
for j = 1:2
    [Ft, Fb, Q] = sf_nr(L.kind, a, c, L.t, L.b, ph(j));
    K(j) = s * ((1 + L.g) / 2 * Ft + (1 - L.g) / 2 * Fb) * sqrt(pi * a * 1e-3 / Q);
end
end
