function R = run_step310(out_dir)
%RUN_STEP310  Step 3.10: HUMS indicators on a synthetic signal and the statistical threshold method (CTL-03).
%   R = run_step310()          results in calc/results/step310, table in maintenance/
%   R = run_step310(out_dir)
%
%   Runs from the repo root with calc/hums, calc/gear_detail, calc/shafts_bearings and
%   calc/accessory on the path. Steps:
%    1. baseline: in.n_base healthy records (seeds 101...), their mean residual variance (the NA4
%       reference) and the indicators FM4, NA4, SER, ENV of each record (hm_indicators)
%    2. thresholds for caution and alarm from the baseline (hm_threshold, log-normal)
%    3. seeded faults: a sun tooth crack (amplitude loss a, phase a rad) and a planet bore spall
%       (impulse b), in.n_seed records per size (seeds 1001..., 2001...); the smallest size whose
%       mean indicator passes the caution and the alarm threshold
%   Writes summary.txt and three plots in English and Turkish to out_dir (calc/results is not
%   committed) and maintenance/hums_thresholds_v1.csv. About 1 minute.
%
%   Source: Phase 3 report, Section 3.10.

if nargin < 1 || isempty(out_dir)
    out_dir = fullfile('calc', 'results', 'step310');
end
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
in = hm_inputs();
R.in = in;

% 1. baseline
nb = in.n_base;
vr = zeros(nb, 1);
for s = 1:nb
    I = hm_indicators(hm_synth(in, 100 + s), in);
    vr(s) = I.var_r;
end
R.var_ref = mean(vr);
names = {'FM4', 'NA4', 'SER', 'ENV'};
B = zeros(nb, 4);
for s = 1:nb
    I = hm_indicators(hm_synth(in, 100 + s), in, R.var_ref);
    B(s, :) = [I.FM4 I.NA4 I.SER I.ENV];
end
R.base = B;

% 2. thresholds
for j = 1:4
    R.T(j) = hm_threshold(B(:, j), in.pfa);
end

% 3. seeded faults
na = numel(in.crack_a);  nbb = numel(in.spall_b);
C = zeros(na, 4, in.n_seed);  P = zeros(nbb, 4, in.n_seed);
for i = 1:na
    q = in;  q.crack.a = in.crack_a(i);  q.crack.beta = in.crack_a(i);
    for s = 1:in.n_seed
        I = hm_indicators(hm_synth(q, 1000 + 10 * i + s), q, R.var_ref);
        C(i, :, s) = [I.FM4 I.NA4 I.SER I.ENV];
    end
end
for i = 1:nbb
    q = in;  q.spall.b = in.spall_b(i);
    for s = 1:in.n_seed
        I = hm_indicators(hm_synth(q, 2000 + 10 * i + s), q, R.var_ref);
        P(i, :, s) = [I.FM4 I.NA4 I.SER I.ENV];
    end
end
R.crack = C;  R.spall = P;
R.det_crack = detect(mean(C, 3), in.crack_a, R.T);
R.det_spall = detect(mean(P, 3), in.spall_b, R.T);

% example records for the plots
R.ex.h = hm_indicators(hm_synth(in, 101), in, R.var_ref);
q = in;  q.crack.a = 0.10;  q.crack.beta = 0.10;
R.ex.c = hm_indicators(hm_synth(q, 1031), q, R.var_ref);
q = in;  q.spall.b = 0.5;
R.ex.s = hm_indicators(hm_synth(q, 2031), q, R.var_ref);
R.names = names;

write_summary(R, out_dir);
write_table(R, fullfile('maintenance', 'hums_thresholds_v1.csv'));
for lang = {'en', 'tr'}
    plots(R, out_dir, lang{1});
end
end

function D = detect(M, sz, T)
% smallest fault size whose mean indicator reaches the caution / alarm threshold (NaN: none)
D = nan(2, 4);
for j = 1:4
    for q = 1:2
        i = find(M(:, j) >= T(j).thr(q), 1);
        if ~isempty(i), D(q, j) = sz(i); end
    end
end
end

function write_summary(R, out_dir)
in = R.in;
fid = fopen(fullfile(out_dir, 'summary.txt'), 'w');
fprintf(fid, 'Step 3.10: HUMS indicators on a synthetic signal (accelerometer over the ring gear)\n\n');
fprintf(fid, 'Sun %.2f Hz, sun relative to the carrier %.2f Hz, planetary mesh %.1f Hz, first-stage mesh %.1f Hz\n', ...
        in.f_sun, in.f_sun * in.zr / (in.zs + in.zr), in.f_sun * in.zr / (in.zs + in.zr) * in.zs, ...
        in.f_sun * in.z2 / in.z1 * in.z1);
fprintf(fid, 'Sun tooth fault frequency %.1f Hz; planet bore defect %.1f Hz (%.4f per sun revolution)\n', ...
        in.N * in.f_sun * in.zr / (in.zs + in.zr), in.k_bore * in.f_sun, in.k_bore);
fprintf(fid, 'Record %d samples at %d Hz (%.2f s), TSA over %d periods of %d points\n\n', in.n, in.fs, ...
        in.n / in.fs, R.ex.h.nrev, in.tsa_pts);
fprintf(fid, 'Baseline: %d healthy records; NA4 reference variance %.4e (m/s^2)^2\n', in.n_base, R.var_ref);
fprintf(fid, '%-4s %8s %8s %10s %10s\n', '', 'mean', 'sd', 'caution', 'alarm');
for j = 1:4
    fprintf(fid, '%-4s %8.3f %8.3f %10.3f %10.3f\n', R.names{j}, mean(R.base(:, j)), std(R.base(:, j)), R.T(j).thr);
end
fprintf(fid, '(log-normal; false alarm probability per record %.0e caution, %.0e alarm; z = %.3f, %.3f)\n\n', ...
        in.pfa, R.T(1).z);
fprintf(fid, 'Sun tooth crack, mean of %d records per size (a = amplitude loss, phase a rad):\n', in.n_seed);
fprintf(fid, '%6s %8s %9s %8s %8s\n', 'a', 'FM4', 'NA4', 'SER', 'ENV');
Mc = mean(R.crack, 3);
for i = 1:numel(in.crack_a), fprintf(fid, '%6.2f %8.3f %9.3f %8.3f %8.3f\n', in.crack_a(i), Mc(i, :)); end
fprintf(fid, '\nPlanet bore spall, mean of %d records per size (b = impulse, m/s^2):\n', in.n_seed);
fprintf(fid, '%6s %8s %9s %8s %8s\n', 'b', 'FM4', 'NA4', 'SER', 'ENV');
Mp = mean(R.spall, 3);
for i = 1:numel(in.spall_b), fprintf(fid, '%6.2f %8.3f %9.3f %8.3f %8.3f\n', in.spall_b(i), Mp(i, :)); end
fprintf(fid, '\nSmallest size that reaches caution / alarm (NaN = not in the sweep):\n');
for j = 1:4
    fprintf(fid, '%-4s crack a %5.2f / %5.2f   spall b %5.2f / %5.2f\n', R.names{j}, R.det_crack(:, j), ...
            R.det_spall(:, j));
end
fclose(fid);
type(fullfile(out_dir, 'summary.txt'));
end

function write_table(R, file)
def = {'kurtosis of the TSA difference signal (TSA minus shaft orders 1-2, mesh harmonics and their first sidebands)', ...
       'kurtosis of the TSA residual signal (TSA minus shaft orders 1-2 and mesh harmonics), normalised by the baseline residual variance', ...
       'sum of the TSA amplitudes at mesh order 45 +- 1..6 over the TSA rms', ...
       'envelope spectrum (7.4-9.4 kHz band) line at the planet bore defect frequency over the local median'};
def_tr = {'TSA fark sinyalinin basıklığı (TSA eksi mil mertebeleri 1-2, kavrama harmonikleri ve ilk yan bantları)', ...
          'TSA artık sinyalinin basıklığı (TSA eksi mil mertebeleri 1-2 ve kavrama harmonikleri), temel artık varyansıyla normalize', ...
          'kavrama mertebesi 45 +- 1..6 TSA genliklerinin toplamı bölü TSA rms', ...
          'zarf spektrumunda (7,4-9,4 kHz bandı) planet iç bilezik hata frekansındaki çizgi bölü yerel medyan'};
target = {'sun tooth crack', 'sun tooth crack, planet bore spall', 'sun tooth crack', 'planet bore spall'};
fid = fopen(file, 'w', 'n', 'UTF-8');
fprintf(fid, 'indicator,definition_en,definition_tr,target_fault,base_mean,base_sd,caution,alarm,crack_a_caution,crack_a_alarm,spall_b_caution,spall_b_alarm,basis\n');
for j = 1:4
    fprintf(fid, '%s,"%s","%s","%s",%.3f,%.3f,%.3f,%.3f,%s,%s,%s,%s,"%s"\n', R.names{j}, def{j}, def_tr{j}, ...
            target{j}, mean(R.base(:, j)), std(R.base(:, j)), R.T(j).thr, num(R.det_crack(1, j)), ...
            num(R.det_crack(2, j)), num(R.det_spall(1, j)), num(R.det_spall(2, j)), ...
            'synthetic baseline (calc/hums/run_step310, 50 records); replaced by the engine test baselines of 3.11 per torque and speed bin (TBR)');
end
fclose(fid);
end

function s = num(v)
if isnan(v), s = ''; else, s = sprintf('%.2f', v); end
end

function plots(R, out_dir, lang)
tr = strcmp(lang, 'tr');
in = R.in;
L = @(en, t) ternary(tr, t, en);
cH = [0.35 0.35 0.35];  cF = [0.80 0.25 0.18];  cT = [0.93 0.60 0.10];  cA = [0.75 0.15 0.15];

% 1. TSA and residual, healthy vs cracked sun tooth
fig = figure('Visible', 'off', 'Position', [100 100 1000 560]);
th = (0:in.tsa_pts - 1)' / in.tsa_pts * 360;
meet = mod(360 * (0:in.N - 1) / in.N - in.crack.phi0 * 180 / pi, 360);
subplot(2, 1, 1);
plot(th, R.ex.h.tsa, 'Color', cH);  hold on;  plot(th, R.ex.c.tsa, 'Color', cF);
xlim([0 360]);  grid on;
ylabel(L('TSA (m/s^2)', 'TSA (m/s^2)'));
legend(L({'healthy', 'sun tooth crack, a = 0.10'}, {'sağlam', 'güneş dişi çatlağı, a = 0,10'}), 'Location', 'northeast');
title(L(sprintf('Time-synchronous average over one turn of the sun relative to the carrier (%d turns)', R.ex.h.nrev), ...
        sprintf('Güneşin taşıyıcıya göre bir turu üzerinden zaman eşzamanlı ortalama (%d tur)', R.ex.h.nrev)));
subplot(2, 1, 2);
r_h = residual(R.ex.h.tsa, in);  r_c = residual(R.ex.c.tsa, in);
plot(th, r_h, 'Color', cH);  hold on;  plot(th, r_c, 'Color', cF);
yl = ylim;
for k = 1:numel(meet), plot(meet(k) * [1 1], yl, ':', 'Color', [0.2 0.2 0.6]); end
xlim([0 360]);  grid on;
xlabel(L('Sun angle relative to the carrier (deg)', 'Güneşin taşıyıcıya göre açısı (derece)'));
ylabel(L('Residual (m/s^2)', 'Artık (m/s^2)'));
title(L(sprintf('Residual signal: NA4 %.1f healthy, %.1f cracked; dotted: the cracked tooth meets each planet', ...
                R.ex.h.NA4, R.ex.c.NA4), ...
        sprintf('Artık sinyal: NA4 sağlam %.1f, çatlak %.1f; noktalı: çatlak diş her planetle buluşuyor', ...
                R.ex.h.NA4, R.ex.c.NA4)));
save_fig(fig, out_dir, 'tsa', lang);

% 2. envelope spectrum, healthy vs planet bore spall
fig = figure('Visible', 'off', 'Position', [100 100 1000 420]);
fb = R.ex.s.f_bore;
plot(R.ex.h.fe, R.ex.h.E, 'Color', cH);  hold on;  plot(R.ex.s.fe, R.ex.s.E, 'Color', cF);
yl = [0 1.1 * max(R.ex.s.E(R.ex.s.fe > 50 & R.ex.s.fe < 3000))];
for k = 1:3, plot(k * fb * [1 1], yl, ':', 'Color', [0.2 0.2 0.6]); end
xlim([0 3000]);  ylim(yl);  grid on;
xlabel(L('Frequency (Hz)', 'Frekans (Hz)'));  ylabel(L('Envelope amplitude (m/s^2)', 'Zarf genliği (m/s^2)'));
legend(L({'healthy', 'planet bore spall, b = 0.5 m/s^2'}, {'sağlam', 'planet iç bilezik oyuğu, b = 0,5 m/s^2'}), 'Location', 'northeast');
title(L(sprintf('Envelope spectrum, %.1f-%.1f kHz band: defect line %.0f Hz and harmonics (dotted); ENV %.1f healthy, %.1f spalled', ...
                in.band / 1e3, fb, R.ex.h.ENV, R.ex.s.ENV), ...
        sprintf('Zarf spektrumu, %.1f-%.1f kHz bandı: hata çizgisi %.0f Hz ve harmonikleri (noktalı); ENV sağlam %.1f, oyuklu %.1f', ...
                in.band / 1e3, fb, R.ex.h.ENV, R.ex.s.ENV)));
save_fig(fig, out_dir, 'envelope', lang);

% 3. indicators against fault size with the thresholds
fig = figure('Visible', 'off', 'Position', [100 100 1000 640]);
panels = {1, 'crack', 'FM4'; 2, 'crack', 'NA4'; 3, 'crack', 'SER'; 4, 'spall', 'ENV'};
for p = 1:4
    subplot(2, 2, p);
    j = panels{p, 1};
    if strcmp(panels{p, 2}, 'crack')
        sz = in.crack_a;  V = squeeze(R.crack(:, j, :));
        xl = L('Sun tooth crack size a (amplitude loss)', 'Güneş dişi çatlak büyüklüğü a (genlik kaybı)');
    else
        sz = in.spall_b;  V = squeeze(R.spall(:, j, :));
        xl = L('Planet bore spall impulse b (m/s^2)', 'Planet iç bilezik oyuğu darbesi b (m/s^2)');
    end
    plot(sz, V, '.', 'Color', [0.55 0.55 0.55]);  hold on;
    h1 = plot(sz, mean(V, 2), '-o', 'Color', cF, 'MarkerFaceColor', cF);
    h2 = plot(sz([1 end]), R.T(j).thr(1) * [1 1], '--', 'Color', cT, 'LineWidth', 1.2);
    h3 = plot(sz([1 end]), R.T(j).thr(2) * [1 1], '--', 'Color', cA, 'LineWidth', 1.2);
    if j == 2, set(gca, 'YScale', 'log'); end
    grid on;  xlabel(xl);  ylabel(R.names{j});
    if p == 1
        legend([h1 h2 h3], L({'mean of 5 records', 'caution', 'alarm'}, {'5 kaydın ortalaması', 'dikkat', 'alarm'}), ...
               'Location', 'northwest');
    end
end
sgtitle(L('Indicators against seeded fault size; thresholds from 50 healthy records (false alarm 1e-3 caution, 1e-6 alarm)', ...
          'Ekilmiş hata büyüklüğüne göre göstergeler; eşikler 50 sağlam kayıttan (yanlış alarm dikkat 1e-3, alarm 1e-6)'));
save_fig(fig, out_dir, 'detection', lang);
end

function r = residual(a, in)
m = numel(a);  A = fft(a);
ords = (0:m - 1)';  ords(ords > m / 2) = ords(ords > m / 2) - m;
mesh = in.zs * (1:floor((m / 2 - 1) / in.zs));
r = real(ifft(A .* ~(ismember(abs(ords), [1 2 mesh]) | ords == 0)));
end

function save_fig(fig, out_dir, name, lang)
exportgraphics(fig, fullfile(out_dir, sprintf('%s_%s.png', name, lang)), 'Resolution', 130);
close(fig);
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end
