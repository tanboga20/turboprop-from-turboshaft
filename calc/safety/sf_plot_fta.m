function sf_plot_fta(F, in, lang, out_dir)
%SF_PLOT_FTA  Fault tree of propeller release (D1) in Turkish or English: fta_<lang>.png.
%   sf_plot_fta(F, in, lang, out_dir)   F = sf_fta(in)
%   Source: Phase 3 report, Section 3.7 (D1).

tr = strcmp(lang, 'tr');
ev = F.ev;
fig = figure('Visible', 'off', 'Position', [100 100 1500 760], 'Color', 'w');
ax = axes(fig, 'Position', [0.01 0.02 0.98 0.96]);  hold(ax, 'on');  axis(ax, 'off');
xlim(ax, [0 12]);  ylim(ax, [0 10]);
col = struct('active', [1 1 1], 'weibull', [1 1 1], 'latent', [0.86 0.92 1.0], 'critical', [1.0 0.88 0.75], 'multi', [0.9 0.9 0.9], ...
             'top', [1.0 0.8 0.8]);
fmt = @(p) sprintf('%.1e', p);
if tr, fmt = @(p) strrep(sprintf('%.1e', p), '.', ','); end
% top event
top = 'Propeller separates from the engine (hazardous)';
lim = sprintf('each cut set <= %s per engine flight hour (SAF-01): largest %s', fmt(in.target_h), fmt(F.P_max));
ptot = sprintf('sum of the quantified cut sets %s /h (extremely remote band <= %s)', fmt(F.P_total), fmt(in.ft.band));
if tr
    top = 'Pervanenin motordan ayrılması (tehlikeli)';
    lim = sprintf('her kesim kümesi <= motor uçuş saati başına %s (SAF-01): en büyüğü %s', fmt(in.target_h), fmt(F.P_max));
    ptot = sprintf('nicel kesim kümelerinin toplamı %s /h (çok uzak bandı <= %s)', fmt(F.P_total), fmt(in.ft.band));
end
box(ax, 6, 9.3, 5.6, 0.9, {top, lim, ptot}, col.top, 8, '-');
gate(ax, 6, 8.3, 'OR', tr);
line(ax, [6 6], [8.85 8.55], 'Color', 'k');
% first level: two dual-path gates, two critical parts, the bolted joints
xs = [2.35 5.7 8.0 9.4 10.8];
line(ax, [xs(1) xs(end)], [7.6 7.6], 'Color', 'k');
line(ax, [6 6], [8.05 7.6], 'Color', 'k');
for x = xs, line(ax, [x x], [7.6 7.3], 'Color', 'k'); end
P = F.T.P_per_h;  cid = F.T.cut_set;
pc = @(ids) sum(P(ismember(cid, ids)));
dual(ax, xs(1), 'E1', 'E6', 'E2', pc(["E1 + E2", "E6 + E2", "E6 + CC1"]), ev, tr, col, fmt, in);
dual(ax, xs(2), 'E4', 'E7', 'E5', pc(["E4 + E5", "E4 + R4", "E7 + E5", "E7 + R7", "E8 + E5", "E8 + R4"]), ev, tr, col, fmt, in);
% demand terms that join the gates
if tr
    d1 = sprintf('+ E6 VE CC1 (aynı montaj hatası tüp somununu da gevşek bırakır, q %s): %s /h', fmt(F.ev(strcmp({F.ev.id}, 'CC1')).qd), fmt(pc("E6 + CC1")));
    d2 = sprintf('+ E4 VE R4, E7 VE R7 (dudak sürtünmeyle hasarlanır, q %s / %s): %s /h', fmt(F.qj.R4), fmt(F.lip.q_rub7), fmt(pc(["E4 + R4", "E7 + R7", "E8 + R4"])));
else
    d1 = sprintf('+ E6 AND CC1 (the same installation error leaves the tube nut loose, q %s): %s /h', fmt(F.ev(strcmp({F.ev.id}, 'CC1')).qd), fmt(pc("E6 + CC1")));
    d2 = sprintf('+ E4 AND R4, E7 AND R7 (lip fails by rubbing, q %s / %s): %s /h', fmt(F.qj.R4), fmt(F.lip.q_rub7), fmt(pc(["E4 + R4", "E7 + R7", "E8 + R4"])));
end
text(ax, 0.2, 2.0, {d1, d2}, 'FontSize', 8, 'Color', [0.7 0 0], 'VerticalAlignment', 'top');
ids = {'C2', 'C3', 'M1'};
for k = 1:3
    e = ev(strcmp({ev.id}, ids{k}));
    note = 'CS-E 515, not quantified';
    if tr, note = 'CS-E 515, nicel değil'; end
    if strcmp(e.type, 'multi'), note = 'qualitative'; if tr, note = 'niteliksel'; end, end
    box(ax, xs(k + 2), 6.25, 1.32, 1.9, [wrap(pick(e, tr), 20), {['(' note ')']}], col.(e.type), 7, '-');
end
% legend boxes
if tr
    lg = {'aktif olay (saat başına oran; E4 Weibull, TBO''da yenilenir: gizli olay ağırlığı beta / (beta + 1))', ...
          'gizli olay: q = oran x T / 2 + q_d (devreye girerken hasar)', ...
          'CS-E 515 kritik parça (CS-E 510(c): birincil hasar nicel değil, D3 / D4)', 'çok cıvatalı bağlantı (niteliksel, CS-E 510(a)(3))'};
    hdr = sprintf('Gizli maruz kalma: TBO / 2 = %s h (TBO arası kontrol yalnız seçenek, alınmadı)', thou(in.ft.T_insp / 2, '.'));
    k = find(F.T.inspection_is_ALI);
    nt = {sprintf(['Tüp ve dudak muayenesi her TBO''da bir Uçuşa Elverişlilik Sınırlamaları maddesidir (CS-E 510(e)(1)): ' ...
          'hiç muayene edilmezse %s kümesi %s /h olur.'], strjoin(F.T.cut_set(k), ', '), strjoin(arrayfun(fmt, F.T.P_never_inspected_per_h(k), 'UniformOutput', false), ', ')), ...
          'Mil veya flanş kırılmasından sonra (E1, E6): tüp bağlantıları tork taşımaz; Np/Nr farkı (CTL-02) veya tork çöküşüyle FADEC motoru kapatır, pervane tüylenir; itme kırık yüzlerden geçer, çekme sürüklemesini tüp taşır (SAF-04).', ...
          'QJ1024 eksenel kaybında (E4) tahrik zinciri sağlam kalır (Np/Nr işareti yok): itmeyi NJ1024 yedeği alır, termokupl uyarısıyla topal modda motorlu iniş; dudak geçici çekmeleri, NJ hasarında ise kapatma ve tüylemeden sonra sürüklemeyi taşır (G1b).'};
else
    lg = {'active event (rate per hour; E4 Weibull, renewed at TBO: latent weight beta / (beta + 1))', ...
          'latent event: q = rate x T / 2 + q_d (failure on engagement)', ...
          'CS-E 515 critical part (CS-E 510(c): primary failure not quantified, D3 / D4)', 'multi-fastener joint (qualitative, CS-E 510(a)(3))'};
    hdr = sprintf('Latent exposure: TBO / 2 = %s h (a check between TBOs is an option only, not taken)', thou(in.ft.T_insp / 2, ','));
    k = find(F.T.inspection_is_ALI);
    nt = {sprintf(['The tube and lip inspection at each TBO is an Airworthiness Limitations item (CS-E 510(e)(1)): ' ...
          'never inspected, the %s set would be %s /h.'], strjoin(F.T.cut_set(k), ', '), strjoin(arrayfun(fmt, F.T.P_never_inspected_per_h(k), 'UniformOutput', false), ', ')), ...
          'After a shaft or flange failure (E1, E6): the tube anchors carry no torque; the Np/Nr mismatch (CTL-02) or the torque collapse makes the FADEC shut down and feather; push-in goes through the fracture faces and the tube carries the pull-out drag (SAF-04).', ...
          'A QJ1024 axial loss (E4) leaves the drive chain intact (no Np/Nr cue): push-in goes onto the NJ1024 standby, the thermocouples alert and the limp mode lands powered; the lip carries the pull-out transients and, after an NJ failure, the drag after the shutdown and feather (G1b).'};
end
cs = {col.active, col.latent, col.critical, col.multi};
for k = 1:4
    rectangle(ax, 'Position', [7.4, 4.2 - 0.45 * k, 0.35, 0.3], 'FaceColor', cs{k}, 'EdgeColor', 'k');
    text(ax, 7.85, 4.35 - 0.45 * k, lg{k}, 'FontSize', 8);
end
text(ax, 7.4, 4.35, hdr, 'FontSize', 8, 'FontWeight', 'bold');
text(ax, 0.2, 1.35, nt, 'FontSize', 8, 'VerticalAlignment', 'top');
set(findall(fig, '-property', 'FontName'), 'FontName', 'Arial');
exportgraphics(fig, fullfile(out_dir, ['fta_' lang '.png']), 'Resolution', 150);
close(fig);
end

function dual(ax, x, a1, a2, l, p, ev, tr, col, fmt, in)
% AND of (a1 OR a2) and the latent standby l, drawn below the first-level line at x
gate(ax, x, 7.05, 'AND', tr);
text(ax, x + 0.35, 7.05, [fmt(p) ' /h'], 'FontSize', 8, 'Color', [0.7 0 0]);
line(ax, [x x], [6.8 6.2], 'Color', 'k');  line(ax, [x - 0.75 x + 0.85], [6.2 6.2], 'Color', 'k');
line(ax, [x - 0.75 x - 0.75], [6.2 5.65], 'Color', 'k');  line(ax, [x + 0.85 x + 0.85], [6.2 5.4], 'Color', 'k');
gate(ax, x - 0.75, 5.4, 'OR', tr);
leaf(ax, ev, l, x + 0.85, 4.6, tr, col, fmt, in);
line(ax, [x - 0.75 x - 0.75], [5.15 4.6], 'Color', 'k');  line(ax, [x - 1.5 x], [4.6 4.6], 'Color', 'k');
line(ax, [x - 1.5 x - 1.5], [4.6 3.8], 'Color', 'k');  line(ax, [x x], [4.6 3.8], 'Color', 'k');
leaf(ax, ev, a1, x - 1.5, 2.9, tr, col, fmt, in);
leaf(ax, ev, a2, x, 2.9, tr, col, fmt, in);
end

function leaf(ax, ev, id, x, y, tr, col, fmt, in)
e = ev(strcmp({ev.id}, id));
if strcmp(e.type, 'latent')
    q = e.rate * in.ft.T_insp / 2 + e.qd;
    s = {sprintf('%s /h, q_d %s', fmt(e.rate), fmt(e.qd)), sprintf('q = %s', fmt(q))};
else
    s = {sprintf('%s /h', fmt(e.rate))};
end
box(ax, x, y, 1.42, 1.6, [{[id ':']}, wrap(pick(e, tr), 22), s], col.(e.type), 7, '-');
end

function s = pick(e, tr)
s = e.en;  if tr, s = e.tr; end
end

function box(ax, x, y, w, h, txt, fc, fs, ls)
rectangle(ax, 'Position', [x - w / 2, y - h / 2, w, h], 'FaceColor', fc, 'EdgeColor', 'k', 'LineStyle', ls, ...
          'Curvature', 0.08);
text(ax, x, y, txt, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', fs);
end

function gate(ax, x, y, kind, tr)
lbl = kind;
if tr, if strcmp(kind, 'AND'), lbl = 'VE'; else, lbl = 'VEYA'; end, end
t = linspace(0, pi, 30);
if strcmp(kind, 'AND')
    xp = [x - 0.25, x - 0.25, x - 0.25 + 0.5 * (1 - cos(t)) / 2, x + 0.25, x + 0.25];
    yp = [y - 0.25, y, y + 0.25 * sin(t), y, y - 0.25];
else
    xp = [x - 0.25 + 0.5 * (1 - cos(t)) / 2, fliplr(x - 0.25 + 0.5 * (1 - cos(t)) / 2)];
    yp = [y - 0.18 + 0.43 * sin(t) .^ 0.8, fliplr(y - 0.25 + 0.07 * sin(t))];
end
patch(ax, xp, yp, 'w', 'EdgeColor', 'k');
text(ax, x, y - 0.02, lbl, 'HorizontalAlignment', 'center', 'FontSize', 7, 'FontWeight', 'bold');
end


function c = wrap(s, n)
w = strsplit(s, ' ');  c = {};  cur = '';
for k = 1:numel(w)
    if isempty(cur), nxt = w{k}; else, nxt = [cur ' ' w{k}]; end
    if numel(nxt) > n && ~isempty(cur), c{end + 1} = cur; cur = w{k}; else, cur = nxt; end %#ok<AGROW>
end
c{end + 1} = cur;
end

function s = thou(n, sep)
s = regexprep(sprintf('%d', round(n)), '(\d)(?=(\d{3})+$)', ['$1' sep]);
end
