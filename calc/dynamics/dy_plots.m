function dy_plots(S, lang, out_dir)
%DY_PLOTS  Step 3.6 plots: Campbell diagrams, forced responses and the damping ring, in Turkish or English.
%   dy_plots(S, lang, out_dir)   S = run_step36 output; writes campbell_<lang>.png, response_<lang>.png and
%   ring_<lang>.png.
%   Source: Phase 3 report, Section 3.6.

tr = strcmp(lang, 'tr');
sp = S.speed;
s = linspace(0, 1.1, 50);
blue = [0.15 0.35 0.65];  orange = [0.80 0.45 0.10];  grey = [0.75 0.75 0.75];
fig = figure('Visible', 'off', 'Position', [100 100 1200 520]);
% planetary: planet modes, case modes against the 1x, 2x and 3x planetary mesh lines
subplot(1, 2, 1);  hold on;  grid on
ytop = 1.15 * max(S.speed.bandsP(:));
for f = S.case.f_modes(S.case.f_modes <= ytop)', plot([0 110], [f f], '-', 'Color', grey, 'LineWidth', 0.5); end
for f = S.planet.f_all(S.planet.f_all > 1000 & S.planet.f_all <= ytop), plot([0 110], [f f], '-', 'Color', orange, 'LineWidth', 1.5); end
ls = {'-', '--', ':'};
for h = 1:3, plot(100 * s, h * sp.fmP * s, ls{h}, 'Color', blue, 'LineWidth', 2); end
xline(100 * 0.9, ':k');  xline(100 * 1.01, ':k');
ylim([0 ytop]);  xlim([0 110]);
if tr
    xlabel('hız [%]');  ylabel('frekans [Hz]');
    title({'Planet kademesi', 'planet (turuncu), gövde (gri) modları; kavrama 1x/2x/3x (mavi)'}, 'FontSize', 10);
else
    xlabel('speed [%]');  ylabel('frequency [Hz]');
    title({'Planetary stage', 'planet (orange), case (grey) modes; mesh 1x/2x/3x (blue)'}, 'FontSize', 10);
end
% first stage: web modes (rotating frame: f -+ n f_rot) against the first-stage mesh, in kHz
subplot(1, 2, 2);  hold on;  grid on
red = [0.8 0.1 0.1];
md = S.web.modes(S.web.modes.f <= 28000, :);
for k = 1:height(md)                                   % out of plane solid, in plane dashed; red in a band
    c = orange;  if md.inband1(k) || md.inband2(k), c = red; end
    ls = '-';  if ~md.out_of_plane(k), ls = '--'; end
    plot(100 * s, (md.f(k) + md.n(k) * sp.frot2 * s) / 1000, ls, 'Color', c, 'LineWidth', 0.5);
    plot(100 * s, (md.f(k) - md.n(k) * sp.frot2 * s) / 1000, ls, 'Color', c, 'LineWidth', 0.5);
end
plot(100 * s, sp.fm1 * s / 1000, '-', 'Color', blue, 'LineWidth', 2);
plot(100 * s, 2 * sp.fm1 * s / 1000, '--', 'Color', blue, 'LineWidth', 2);
xline(100 * 0.9, ':k');  xline(100 * 1.01, ':k');
ib = S.web.inband;                                     % in-band crossings: filled where the ring slips
for k = 1:height(ib)
    for x = unique([ib.x_lo(k), ib.x_hi(k)])
        y = ib.h(k) * sp.fm1 * x / 1000;
        if ib.slips(k)
            plot(100 * x, y, 'o', 'MarkerSize', 6, 'MarkerFaceColor', red, 'MarkerEdgeColor', 'k');
        else
            plot(100 * x, y, 'o', 'MarkerSize', 5, 'MarkerEdgeColor', red);
        end
    end
end
% labels: the rule families only (out of plane), in a column right of the mode lines, with leaders to the top crossing
k = find(ib.rule);
xa = 100 * ib.x_hi(k);  ya = ib.h(k) .* sp.fm1 .* ib.x_hi(k) / 1000;
[ya, o] = sort(ya);  xa = xa(o);  k = k(o);
yl = ya;  gap = 1.2;
for i = 2:numel(yl), yl(i) = max(yl(i), yl(i - 1) + gap); end
yl = yl - (mean(yl) - mean(ya));
for i = 1:numel(k)
    plot([xa(i) 112], [ya(i) yl(i)], '-k', 'LineWidth', 0.5);
    text(112.5, yl(i), sprintf('n = %d', ib.n(k(i))), 'FontSize', 8, 'BackgroundColor', 'w', 'Margin', 1);
end
ylim([0 28]);  xlim([0 125]);
hl = [plot(nan, nan, '-', 'Color', orange), plot(nan, nan, '--', 'Color', orange), plot(nan, nan, '-', 'Color', red), ...
      plot(nan, nan, '-', 'Color', blue, 'LineWidth', 2), ...
      plot(nan, nan, 'o', 'MarkerSize', 6, 'MarkerFaceColor', red, 'MarkerEdgeColor', 'k'), ...
      plot(nan, nan, 'o', 'MarkerSize', 5, 'MarkerEdgeColor', red)];
if tr
    xlabel('hız [%]');  ylabel('frekans [kHz]');
    title({'Birinci kademe dişlisi gövdesi: modlar f \pm n f_{dönme}', 'etiketler: kural aileleri (düzlem dışı)'}, 'FontSize', 10);
    legend(hl, {'düzlem dışı', 'düzlem içi', 'bantta', 'kavrama 1x (düz), 2x (kesikli)', 'bant içi kesişme, halka kayıyor', ...
                'bant içi kesişme, halka yapışık'}, 'Location', 'southeast', 'NumColumns', 2, 'FontSize', 7);
else
    xlabel('speed [%]');  ylabel('frequency [kHz]');
    title({'First-stage gear web: modes f \pm n f_{rot}', 'labels: rule families (out of plane)'}, 'FontSize', 10);
    legend(hl, {'out of plane', 'in plane', 'in a band', 'mesh 1x (solid), 2x (dashed)', 'in-band crossing, ring slips', ...
                'in-band crossing, ring sticks'}, 'Location', 'southeast', 'NumColumns', 2, 'FontSize', 7);
end
set(findall(fig, '-property', 'FontName'), 'FontName', 'Arial');
exportgraphics(fig, fullfile(out_dir, ['campbell_' lang '.png']), 'Resolution', 150);
close(fig);

fig = figure('Visible', 'off', 'Position', [100 100 1200 480]);
subplot(1, 2, 1);  hold on;  grid on
cl = lines(3);  hs = gobjects(1, 3);
for h = 1:3
    R = S.planet.h(h);
    hs(h) = plot(R.f, R.Fd_sp, '-', 'Color', cl(h, :), 'LineWidth', 1.5);
    plot(R.f, R.Fd_pr, '--', 'Color', cl(h, :), 'LineWidth', 1.5);
end
if tr
    xlabel('frekans [Hz]');  ylabel('dinamik diş kuvveti [N]');
    title('Planet: dinamik diş kuvveti (güneş düz, halka kesikli)', 'FontSize', 10);
    legend(hs, {'1x', '2x', '3x'});
else
    xlabel('frequency [Hz]');  ylabel('dynamic tooth force [N]');
    title('Planet: dynamic tooth force (sun solid, ring dashed)', 'FontSize', 10);
    legend(hs, {'1x', '2x', '3x'});
end
subplot(1, 2, 2);  hold on;  grid on
for h = 1:3
    plot(S.case.band(h).f, S.case.band(h).sig, '-', 'Color', cl(h, :), 'LineWidth', 1.5);
end
% Goodman allowable mesh stress: sigma_e k_gc (1 / k_cast - sigma_m / sigma_u) - sigma_1P - sigma_pass, with the largest
% steady stress and planet-pass amplitude of the slide bracket (static solve at MCT)
cs = S.in.cs;  se = S.in.sigma_e.A357 * cs.k_gc;
lim = se * (1 / S.in.k_cast - S.case.band(1).sig_steady / S.in.su_A357) - cs.sa_1P - S.case.band(1).sig_pass;
yline(lim, 'r--', 'LineWidth', 1);
ylim([0 1.3 * lim]);                                   % the limit line in view across the plot, the legend below it
lbl = sprintf('%.1f MPa', lim);
if tr
    xlabel('frekans [Hz]');  ylabel('en büyük titreşim gerilmesi [MPa]');
    title({'Planet gövdesi: en büyük titreşim gerilmesi', '(bağlı jant, flanş ankastre, \zeta 0,02)'}, 'FontSize', 10);
    legend({'1x', '2x', '3x', ['Goodman sınırı (MCT sabit gerilmesi, planet geçişi, 1P) = ' strrep(lbl, '.', ',')]}, ...
           'Location', 'east', 'FontSize', 8);
else
    xlabel('frequency [Hz]');  ylabel('largest vibratory stress [MPa]');
    title({'Planetary case: largest vibratory stress', '(bonded rim, flange fixed, \zeta 0.02)'}, 'FontSize', 10);
    legend({'1x', '2x', '3x', ['Goodman limit (MCT steady stress, planet pass, 1P) = ' lbl]}, 'Location', 'east', 'FontSize', 8);
end
set(findall(fig, '-property', 'FontName'), 'FontName', 'Arial');
exportgraphics(fig, fullfile(out_dir, ['response_' lang '.png']), 'Resolution', 150);
close(fig);

% web and ring: largest amplitude ratio of the rule families against the ring section, per groove offset
fig = figure('Visible', 'off', 'Position', [100 100 1200 480]);
subplot(1, 2, 1);  hold on;  grid on
T = S.web.ring_trade;  ev = unique(T.e_mm)';
for e = ev
    k = T.e_mm == e;
    plot(T.mass_kg(k), T.s_max(k), '-o', 'LineWidth', 1.5, 'MarkerSize', 4);
end
yline(S.in.ring.s_max, 'r--');
plot(S.web.ring.mass, S.web.ring.s_max, 'kp', 'MarkerSize', 14, 'MarkerFaceColor', 'y');
if tr
    xlabel('halka kütlesi [kg]');  ylabel('s, en kötü durum');
    title('Sönüm halkası: genlik oranı ve halka kütlesi');
    legend([arrayfun(@(e) sprintf('e = %g mm', e), ev, 'UniformOutput', false), {'kural s = 0,6', 'seçilen halka'}]);
else
    xlabel('ring mass [kg]');  ylabel('s, worst case');
    title('Damping ring: amplitude ratio against ring mass');
    legend([arrayfun(@(e) sprintf('e = %g mm', e), ev, 'UniformOutput', false), {'rule s = 0.6', 'chosen ring'}]);
end
subplot(1, 2, 2);  hold on;  grid on
ib = S.web.inband;  k = find(ib.slips & ib.h == 1);
x = 1:numel(k);
bar(x, [ib.sig_bare(k), ib.sig_ring_MPa(k)]);
sfx = {'i', 'o'};  if tr, sfx = {'i', 'd'}; end
xticks(x);  xticklabels(arrayfun(@(i) sprintf('n%d%s', ib.n(i), sfx{1 + ib.oop(i)}), k, 'UniformOutput', false));
if tr
    xlabel('aile (i: düzlem içi, d: düzlem dışı)');
    ylabel('titreşim gerilmesi [MPa]');  title('Birinci kademe dişlisi gövdesi: çıplak ve halkalı (1x, kayan aileler)');
    legend({'çıplak', 'halkayla'});
else
    xlabel('family (i: in-plane, o: out-of-plane)');
    ylabel('vibratory stress [MPa]');  title('First-stage gear web: bare and with the ring (1x, slipping families)');
    legend({'bare', 'with the ring'});
end
set(findall(fig, '-property', 'FontName'), 'FontName', 'Arial');
exportgraphics(fig, fullfile(out_dir, ['ring_' lang '.png']), 'Resolution', 150);
close(fig);
end
