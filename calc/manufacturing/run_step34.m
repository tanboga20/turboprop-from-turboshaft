function S = run_step34(out_dir)
%RUN_STEP34  Step 3.4: materials, processes and the bill of materials (numbers).
%   S = run_step34()          results in calc/results/step34, BOM in manufacturing/bom_v1.csv
%   S = run_step34(out_dir)
%
%   Run from the repo root with calc/manufacturing, calc/gear_detail,
%   calc/shafts_bearings and calc/assembly on the path, after run_step32
%   (calc/results/step32/step32.mat). Computes the case depth check of the
%   flanks and the planet bearing raceways (mf_casedepth), the film ratio
%   against the flank finish (mf_film), the bottom-up fastener mass against
%   the step 3.1 allowance (mf_fasteners), the steel seat liners not yet in
%   the roll-up (mf_liners) and the bill of materials (mf_bom); writes
%   manufacturing/bom_v1.csv, CSV tables and plots in Turkish and English
%   (casedepth_*.png, bom_*.png) and step34.mat. The material, process and
%   route tables are text: manufacturing/make_mfg.py.
%   Source: Phase 3 report, Section 3.4.

if nargin < 1 || isempty(out_dir)
    out_dir = fullfile('calc', 'results', 'step34');
end
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
in = mf_inputs();
gi = gd_inputs();  sb = sb_inputs();  ai = as_inputs();
st = load(fullfile('calc', 'results', 'step32', 'step32.mat'));
Mx = st.S.mass;  W = st.S.lubmass;

C = mf_casedepth(in, gi, sb);
fprintf('\n== Case depth (K_gamma %.3f; planet bearing Fr %.0f / %.0f N, Qmax %.0f / %.0f N, Z %d)\n', ...
        C.Kgam, C.Fr, C.Qmax, C.Z);
disp(C.T(:, {'contact', 'case', 'p0_MPa', 'b_mm', 'z_tau_mm', 'cd_needed_mm', 'margin'}));
fprintf('ISO 6336-5 upper bound 0.4 m_n: first stage %.2f mm, planetary %.2f mm\n', C.iso_max);
Fm = mf_film(in, gi, C.M);
fprintf('\n== Film ratio at the pitch point, MIL-PRF-23699, against Ra of both flanks (%s um)\n', num2str(in.Ra_list));
disp(Fm.T);
F = mf_fasteners(in, Mx.modelled);
fprintf('\n== Fasteners: %d, %.2f kg bottom-up, %.2f kg with x%.1f; allowance %.2f kg; allowance - estimate %.2f kg\n', ...
        F.n, F.sum, F.with_k, in.k_fast, F.allowance, F.diff);
Ln = mf_liners(in);
fprintf('== Seat liners: %.2f kg not in the roll-up; fit change at %s degC [mm]:\n', Ln.kg, num2str(in.T_fit));
disp([Ln.T table(Ln.dfit, 'VariableNames', {'dfit_mm'})]);
B = mf_bom(Mx, W, ai, F, Ln);
fprintf('\n== BOM: %d lines; roll-up %.2f kg (step 3.2 %.2f); bottom-up estimate %.2f kg (SYS-06 110 kg TBR)\n', ...
        height(B.T), B.rollup, Mx.total, B.bottom_up);
fprintf('input drive (SYS-11) %.2f kg; RGB + input drive %.2f kg\n', Mx.drive, Mx.total_with_drive);

if ~isfolder(fullfile(pwd, 'manufacturing')), mkdir(fullfile(pwd, 'manufacturing')); end   % (exist finds calc/manufacturing on the path)
writetable(B.T, fullfile('manufacturing', 'bom_v1.csv'));
T = C.T;  T.cd_min_mm = T.cd_spec_mm(:, 1);  T.cd_max_mm = T.cd_spec_mm(:, 2);  T.cd_spec_mm = [];
writetable(T, fullfile(out_dir, 'casedepth.csv'));
Tf = Fm.T;
for j = 1:numel(in.Ra_list)
    Tf.(matlab.lang.makeValidName(sprintf('lambda_Ra_%g', in.Ra_list(j)))) = Tf.lambda_at_Ra(:, j);
end
Tf.lambda_at_Ra = [];
writetable(Tf, fullfile(out_dir, 'film.csv'));
writetable(F.T, fullfile(out_dir, 'fasteners.csv'));
writetable([Ln.T array2table(Ln.dfit, 'VariableNames', compose('dfit_%gC_mm', in.T_fit))], fullfile(out_dir, 'liners.csv'));
S = struct('in', in, 'casedepth', rmfield(C, 'M'), 'film', Fm, 'fasteners', F, 'liners', Ln, 'bom', B);
save(fullfile(out_dir, 'step34.mat'), 'S');
for lang = {'tr', 'en'}
    plot_casedepth(C, in, lang{1}, out_dir);
    plot_bom(B, Mx, F, Ln, lang{1}, out_dir);
end
end

function plot_casedepth(C, in, lang, out_dir)
% needed case depth (bar) against the specified band (shaded) for every contact at LD-02
tr = strcmp(lang, 'tr');
T = C.T(C.T.case == "LD-02", :);
fig = figure('Visible', 'off', 'Position', [100 100 1000 480]);
hold on;  grid on
n = height(T);
for k = 1:n
    s = T.cd_spec_mm(k, :);
    patch([s(1) s(2) s(2) s(1)], k + [-0.35 -0.35 0.35 0.35], [0.80 0.88 0.96], 'EdgeColor', 'none');
end
barh(1:n, T.cd_needed_mm, 0.45, 'FaceColor', [0.15 0.35 0.65]);
plot(T.z_tau_mm, 1:n, 'k|', 'MarkerSize', 12, 'LineWidth', 1.5);
names = T.contact;
if tr
    names = replace(names, ["first stage", "pinion", "gear 2", "sun-planet", "planet-ring", "planet (sun mesh)", ...
                            "planet (ring mesh)", "sun", "ring", "planet bore (outer race)", "planet pin (inner race)"], ...
                    ["birinci kademe", "pinyon", "dişli 2", "güneş-planet", "planet-halka", "planet (güneş tarafı)", ...
                     "planet (halka tarafı)", "güneş", "halka", "planet deliği (dış bilezik)", "planet pimi (iç bilezik)"]);
end
set(gca, 'YTick', 1:n, 'YTickLabel', names, 'YDir', 'reverse', 'FontSize', 9);
xlim([0 1.6]);
if tr
    xlabel('derinlik [mm]');
    title(sprintf('LD-02 yükünde gereken sertleştirme derinliği (çubuk, %g × en büyük kayma gerilmesi derinliği |) ve belirtilen aralık (gölge)', in.k_cd));
else
    xlabel('depth [mm]');
    title(sprintf('Case depth needed at LD-02 load (bar, %g x depth of the largest shear stress |) and the specified band (shaded)', in.k_cd));
end
set(findall(fig, '-property', 'FontName'), 'FontName', 'Arial');
exportgraphics(fig, fullfile(out_dir, ['casedepth_' lang '.png']), 'Resolution', 150);
close(fig);
end

function plot_bom(B, Mx, F, Ln, lang, out_dir)
% RGB mass by material of the BOM lines in the roll-up, and the bottom-up comparison
tr = strcmp(lang, 'tr');
T = B.T(ismember(B.T.basis, {'CATIA', 'weighed 3.2', 'allowance 3.1'}), :);
keys = {'A357', 'P53', 'S43', 'N13', 'Ti64', 'supplier', 'A286', 'C321', 'C155', 'oil'};
lab_en = {'A357-T6 castings', 'Pyrowear 53 gears', 'AISI 4340 parts', '32CrMoV13 ring', 'Ti-6Al-4V', ...
          'bought parts', 'fastener allowance', 'CRES 321 tubes', '15-5PH jets', 'mist oil'};
lab_tr = {'A357-T6 dökümler', 'Pyrowear 53 dişliler', 'AISI 4340 parçalar', '32CrMoV13 halka', 'Ti-6Al-4V', ...
          'satın alınan parçalar', 'bağlantı elemanı payı', 'CRES 321 borular', '15-5PH memeler', 'sis yağı'};
kg = cellfun(@(k) sum(T.kg(strcmp(T.material, k))), keys);
[kg, o] = sort(kg, 'descend');
lab = lab_en;  if tr, lab = lab_tr; end
lab = lab(o);
fig = figure('Visible', 'off', 'Position', [100 100 1000 520]);
subplot(1, 2, 1);
barh(kg, 'FaceColor', [0.15 0.35 0.65]);
set(gca, 'YTick', 1:numel(kg), 'YTickLabel', lab, 'YDir', 'reverse', 'FontSize', 9);
for k = 1:numel(kg), text(kg(k) + 0.5, k, sprintf('%.1f', kg(k)), 'FontSize', 8); end
xlim([0 max(kg) * 1.25]);  grid on
if tr, xlabel('kütle [kg]'); title(sprintf('Malzemeye göre RGB kütlesi (%.2f kg)', B.rollup));
else,  xlabel('mass [kg]');  title(sprintf('RGB mass by material (%.2f kg)', B.rollup)); end
subplot(1, 2, 2);
v = [Mx.total, Mx.total - Mx.bolts + F.with_k, B.bottom_up];
bar(v, 0.55, 'FaceColor', [0.30 0.60 0.85]);
hold on;  yline(110, 'r-', 'LineWidth', 1.5);  yline(100, 'k--', 'LineWidth', 1.2);
for k = 1:3, text(k, v(k) + 0.6, sprintf('%.2f', v(k)), 'HorizontalAlignment', 'center', 'FontWeight', 'bold'); end
ylim([95 115]);  grid on
if tr
    set(gca, 'XTickLabel', {'toplama (3.2)', 'cıvatalar alttan', '+ yuva gömlekleri'});
    ylabel('kuru kütle [kg]');  title('SYS-06: toplama ve alttan tahmin (3.5 için)');
    legend({'', 'SYS-06 110 kg (TBR)', 'v3 100 kg'}, 'Location', 'southoutside', 'NumColumns', 2);
else
    set(gca, 'XTickLabel', {'roll-up (3.2)', 'fasteners bottom-up', '+ seat liners'});
    ylabel('dry mass [kg]');  title('SYS-06: roll-up and bottom-up estimate (for 3.5)');
    legend({'', 'SYS-06 110 kg (TBR)', 'v3 100 kg'}, 'Location', 'southoutside', 'NumColumns', 2);
end
set(findall(fig, '-property', 'FontName'), 'FontName', 'Arial');
exportgraphics(fig, fullfile(out_dir, ['bom_' lang '.png']), 'Resolution', 150);
close(fig);
end
