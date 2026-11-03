function S = run_step26(out_dir, mode)
%RUN_STEP26  Step 2.6: the accessory drives of the RGB (ACC-02, ACC-03).
%   S = run_step26()                  full run, results in calc/results/step26
%   S = run_step26(out_dir)           results in out_dir
%   S = run_step26(out_dir, 'plots')  redraw the plots from step26.mat
%
%   Runs from the repo root with calc/accessory, calc/gear_detail and
%   calc/shafts_bearings on the path. Steps:
%    1. shear necks of the generator, OSG, PCU and oil pump quills
%    2. the three accessory gear pairs by ISO 6336 Methods B and C (step 2.4
%       tools): STR-01 at the maximum rated pad torque x K_A, ACC-03 at 1.5
%       x that torque in fatigue, and static at the top of the neck shear
%       band, so the neck breaks before the gears
%    3. the first-stage gear root with the generator load on its other flank
%       (mean stress factor Y_M, ISO 6336-3 Annex B)
%    4. accessory shaft bearings (deep groove ball bearings): L10m and s0
%    5. DYN-04: web modes of the three accessory gear blanks against the 1x
%       and 2x mesh frequencies in the rotating frame
%    6. pad interface table, generator overhung moment, gear blank masses
%   Writes summary.txt, pads.csv, two plots in English and Turkish and
%   step26.mat to out_dir (calc/results is not committed).
%
%   Source: Phase 2 report, Section 2.6.

if nargin < 1 || isempty(out_dir)
    out_dir = fullfile('calc', 'results', 'step26');
end
if nargin < 2, mode = 'full'; end
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
if strcmp(mode, 'plots')
    L = load(fullfile(out_dir, 'step26.mat'));
    make_plots(L.S, out_dir);
    S = L.S;
    return
end

in = ad_inputs();
gi = gd_inputs();
sbi = sb_inputs();
A = ad_meshes(in, gi);
S = struct('in', in, 'A', A);
oil = gi.oil(1);
ref = @(KA) struct('KA', KA, 'mode', 'ref', 'oil', oil, 'ZNT10', gi.ZNT_ref, 'fpb_share', gi.fpb_share);
st = struct('KA', 1, 'mode', 'static', 'oil', oil, 'ZNT10', gi.ZNT_ref, 'fpb_share', gi.fpb_share);
n_mid = gi.n_PT * gi.s1.z1 / gi.s1.z2;

% 1. Shear necks
S.pads = {'generator', 'OSG', 'PCU', 'oil pump'};
T_max = [in.T_gen_max, in.T_osg, in.T_pcu, in.T_pump];
for k = 1:4
    N(k) = ad_neck(T_max(k), in); %#ok<AGROW>
end
S.N = N;
S.T_max = T_max;

% 2. Gear ratings
for k = 1:3
    m = A(k);
    ratio = m.T1 / m.T_pad;                            % torque on gear 1 per unit pad torque
    R1(k) = gd_rate(m, m.T1, m.n1, ref(in.KA));        %#ok<AGROW>
    R2(k) = gd_rate(m, in.k_fatigue * m.T1, m.n1, ref(1)); %#ok<AGROW>
    R3(k) = gd_rate(m, N(k).T_hi * ratio, m.n1, st);   %#ok<AGROW>
end
S.R1 = R1;  S.R2 = R2;  S.R3 = R3;
smin = @(R) [min([R.S_H1; R.S_H2]); min([R.S_F1; R.S_F2])];
S.S1 = smin(R1);  S.S2 = smin(R2);  S.S3 = smin(R3);

% 3. First-stage gear root with the generator on its other flank
M = gd_meshes(gi);
r0 = gd_rate(M(1), M(1).T1, M(1).n1, ref(gi.KA));
w_gen = 2000 * in.T_gen_max / A(1).g.d1 / A(1).g.b;   % N/mm on the generator face width
w_main = 2000 * gi.T_PT / M(1).g.d1 / M(1).g.b;
Rr = -w_gen / w_main;
Mm = 0.8 - 0.15 * r0.Y_S2;                            % case-hardened, long life (ISO 6336-3 Annex B)
YM = 1 / (1 - Rr * (1 - Mm) / (1 + Mm));
S.gear2 = struct('R', Rr, 'Y_M', YM, 'S_F2', r0.S_F2, 'S_F2_YM', r0.S_F2 * YM);

% 4. Accessory shaft bearings: the gear midway between two bearings
nu = oil_nu(sbi.oil, sbi.T_brg(1));
gears = {A(1).g, 1; A(2).g, 2; A(3).g, 2};           % the gear on each accessory shaft (gear 1 or 2 of its pair)
n_sh = [A(1).n1, A(2).n2, A(3).n2];
T_life = [in.T_gen_cont, in.T_osg, in.T_pcu];
T_stat = [N(1).T_hi, N(2).T_hi, N(3).T_hi];
for k = 1:3
    b = in.brg(k);
    r = sb_rating(b, sbi.b_m.QJ);
    g = gears{k, 1};
    dw = 2 * g.a_w / (g.u + 1) * (gears{k, 2} == 1) + 2 * g.a_w * g.u / (g.u + 1) * (gears{k, 2} == 2);
    F = @(T) brg_loads(T, dw, g, b.span);
    [Fr, Fa] = F(T_life(k));
    Lk = sb_life(b, r, 1, Fr, Fa, n_sh(k), nu, sbi.e_C);
    [Fr0, Fa0] = F(T_stat(k));
    P0 = max(Fr0, 0.6 * Fr0 + 0.5 * Fa0);
    B(k) = struct('name', b.name, 'd', b.d, 'D', b.D, 'B', b.B, 'C', r.C, 'C0', r.C0, 'n', n_sh(k), ...
                  'Fr', Fr, 'Fa', Fa, 'P', Lk.P, 'kappa', Lk.kappa, 'a_ISO', Lk.a_ISO, 'L10m', Lk.L10m_mission, ...
                  's0', r.C0 / P0, 'DN', b.d * n_sh(k) * sbi.n_over); %#ok<AGROW>
end
S.B = B;

% 5. DYN-04: web modes of the accessory gear blanks (solid discs on their hubs)
rho = gi.rho_steel;
blank = {A(1).g.df1, A(1).g.h1, A(1).g.mn, A(1).g.b, in.gen.hub_d, A(1).n1, A(1).n1 * A(1).g.z1 / 60; ...
         A(2).g.df2, A(2).g.h2, A(2).g.mn, A(2).g.b, in.osg.hub_d, A(2).n2, A(2).n1 * A(2).g.z1 / 60; ...
         A(3).g.df2, A(3).g.h2, A(3).g.mn, A(3).g.b, in.pcu.hub_d, A(3).n2, A(3).n1 * A(3).g.z1 / 60};
nn = 0:8;
sp = gi.speed_range;
for k = 1:3
    [df, h, mn, bb, hub, n_rot, fm] = blank{k, :};
    pw = struct('r_in', hub / 2, 'r_out', df / 2 - 3.5 * mn, 't', bb, 'b_rim', bb, 's_rim', 3.5 * mn, ...
                's_mass', 3.5 * mn + 0.5 * h, 'E', gi.mat.Eh.E, 'nu', 0.3, 'rho', rho, 'ne', 40);
    fw = gd_modes('web', pw, nn);
    f = fw(:, 1)';
    frot = n_rot / 60;
    mg = inf(1, numel(nn));
    for j = 1:numel(nn)
        for hh = 1:2
            lo = hh * sp(1) * fm;  hi = hh * sp(2) * fm;
            for fe = f(j) + [-1 1] * nn(j) * frot
                mg(j) = min(mg(j), max((lo - fe) / lo, (fe - hi) / hi));
            end
        end
    end
    D(k) = struct('gear', S.pads{k}, 'n', nn, 'f', f, 'margin', mg, 'fm', fm, 'frot', frot, ...
                  'band', [sp(1) * fm sp(2) * fm; 2 * sp(1) * fm 2 * sp(2) * fm], 'p', pw); %#ok<AGROW>
end
S.D = D;

% 6. Pad interface, generator overhung moment, gear blank masses
S.n = [A(1).n1, A(2).n2, A(3).n2, n_mid];
S.ratio = S.n / gi.n_PT;
S.rot = [1, -1, 1, -1];                               % +1 turns with the power turbine, -1 against it
S.T_cont = [in.T_gen_cont, in.T_osg, in.T_pcu, in.T_pump];
S.M_overhung = in.m_gen * 9.81 * in.nz_man * in.x_cg_gen / 1e3;
disc = @(g, which, bore) rho * pi / 4 * (((g.(['da' which]) + g.(['df' which])) / 2)^2 - bore^2) * g.b;
S.mass = struct('gen_gear', disc(A(1).g, '1', in.gen.bore), 'osg_gear', disc(A(2).g, '2', in.osg.bore(2)), ...
                'pcu_gear', disc(A(3).g, '2', in.pcu.bore(2)));

save(fullfile(out_dir, 'step26.mat'), 'S');
write_summary(S, out_dir);
write_csv(S, out_dir);
make_plots(S, out_dir);
end

function [Fr, Fa] = brg_loads(T, dw, g, span)
% Reactions of the more loaded bearing, the gear midway; the axial force goes to that bearing
Ft = 2000 * T / dw;
Frg = Ft * tan(g.alpha_wt);
Fa = Ft * tan(g.beta);
Fr = hypot(Ft / 2, Frg / 2 + Fa * dw / 2 / span);
end

function nu = oil_nu(oil, T)
% Walther line through the data sheet viscosities at 40 and 100 degC
A = log10(log10(oil.nu40 + 0.7) / log10(oil.nu100 + 0.7)) / log10(313 / 373);
Bc = log10(log10(oil.nu40 + 0.7)) - A * log10(313);
nu = 10^(10^(A * log10(T + 273) + Bc)) - 0.7;
end

function write_summary(S, out_dir)
in = S.in;  A = S.A;
fid = fopen(fullfile(out_dir, 'summary.txt'), 'w');
fprintf(fid, 'Step 2.6: accessory drives (ACC-02, ACC-03)\n\n');
fprintf(fid, '%-10s %8s %8s %5s %8s %8s %7s %9s %9s %9s %6s\n', 'pad', 'n rpm', 'n/n_PT', 'rot', 'T cont', 'T max', ...
        'neck', 'T_sh lo', 'T_sh nom', 'T_sh hi', 'n_f');
for k = 1:4
    q = S.N(k);
    fprintf(fid, '%-10s %8.0f %8.5f %5d %8.2f %8.2f %7.1f %9.1f %9.1f %9.1f %6.2f\n', S.pads{k}, S.n(k), S.ratio(k), ...
            S.rot(k), S.T_cont(k), S.T_max(k), q.d, q.T_lo, q.T_nom, q.T_hi, q.n_f);
end
fprintf(fid, 'CT7-9 ratios: generator %.5f, OSG %.5f; shear band low / maximum rated torque: %s\n\n', ...
        in.ratio_ct7.gen, in.ratio_ct7.osg, mat2str(round([S.N.k_lo], 2)));
for k = 1:3
    g = A(k).g;  r = S.R1(k);
    fprintf(fid, '%-9s z %d/%d, m %.1f, beta %.0f, x %+.2f/%+.2f, b %.0f mm, a_w %.3f mm, eps %.3f/%.3f, sliding %.2f/%.2f\n', ...
            A(k).name, g.z1, g.z2, g.mn, rad2deg(g.beta), g.x1, g.x2, g.b, g.a_w, g.eps_alpha, g.eps_beta, g.zeta1A, g.zeta2E);
    fprintf(fid, '  STR-01 (T1 %.3f N m x K_A %.2f): K_v %.3f, K_Hb %.3f, S_H %.2f/%.2f, S_F %.2f/%.2f\n', ...
            A(k).T1, in.KA, r.Kv, r.KHb, r.S_H1, r.S_H2, r.S_F1, r.S_F2);
    fprintf(fid, '  ACC-03 fatigue at %.1f x: S_H %.2f, S_F %.2f;  static at the neck shear torque %.1f N m: S_H %.2f, S_F %.2f\n', ...
            in.k_fatigue, S.S2(1, k), S.S2(2, k), S.N(k).T_hi, S.S3(1, k), S.S3(2, k));
end
q = S.gear2;
fprintf(fid, '\nFirst-stage gear root with the generator on its other flank: R %.3f, Y_M %.3f, S_F %.3f -> %.3f\n', ...
        q.R, q.Y_M, q.S_F2, q.S_F2_YM);
fprintf(fid, '\nAccessory shaft bearings (deep groove, 110 degC):\n');
for k = 1:3
    b = S.B(k);
    fprintf(fid, '  %-16s %d/%d/%d: C %.1f kN, C0 %.1f kN, n %.0f rpm, Fr %.0f N, Fa %.0f N, P %.0f N, kappa %.2f, a_ISO %.2f, L10m %.3g h, s0 %.1f, DN %.3g\n', ...
            b.name, b.d, b.D, b.B, b.C / 1e3, b.C0 / 1e3, b.n, b.Fr, b.Fa, b.P, b.kappa, b.a_ISO, b.L10m, b.s0, b.DN);
end
fprintf(fid, '\nDYN-04, accessory gear blanks (solid discs; margin from the 1x and 2x ranges in the rotating frame):\n');
for k = 1:3
    d = S.D(k);
    [mm, j] = min(d.margin);
    fprintf(fid, '  %-9s hub %.0f mm, t %.0f mm: mesh %.0f Hz, f(n=0..8) %s Hz; lowest margin %.1f%% (n=%d)\n', ...
            d.gear, 2 * d.p.r_in, d.p.t, d.fm, mat2str(round(d.f)), 100 * mm, d.n(j));
end
fprintf(fid, '\nGenerator overhung moment on its pad at %.2f g: %.1f N m (limit load, for step 2.8)\n', in.nz_man, S.M_overhung);
fprintf(fid, 'Gear blank masses [kg]: generator %.3f, OSG gear %.3f, PCU gear %.3f\n', ...
        S.mass.gen_gear, S.mass.osg_gear, S.mass.pcu_gear);
fclose(fid);
type(fullfile(out_dir, 'summary.txt'));
end

function write_csv(S, out_dir)
fid = fopen(fullfile(out_dir, 'pads.csv'), 'w');
fprintf(fid, 'pad,n_rpm,ratio_to_PT,rotation,T_cont_Nm,T_max_Nm,neck_mm,T_shear_lo_Nm,T_shear_nom_Nm,T_shear_hi_Nm,n_f_neck\n');
for k = 1:4
    q = S.N(k);
    fprintf(fid, '%s,%.1f,%.5f,%d,%.3f,%.3f,%.1f,%.1f,%.1f,%.1f,%.2f\n', S.pads{k}, S.n(k), S.ratio(k), S.rot(k), ...
            S.T_cont(k), S.T_max(k), q.d, q.T_lo, q.T_nom, q.T_hi, q.n_f);
end
fclose(fid);
end

function make_plots(S, out_dir)
for lang = {'en', 'tr'}
    plots(S, out_dir, lang{1});
end
end

function plots(S, out_dir, lang)
in = S.in;
tr = strcmp(lang, 'tr');
if tr
    pn = {'jeneratör', 'OSG', 'PCU'};
    L = struct('SH', 'Yüzey güvenliği S_H', 'SF', 'Diş kökü güvenliği S_F', ...
               'c', {{'STR-01, azami tork × K_A', 'ACC-03, 1,5 × azami tork', 'statik, kesme torkunda'}}, ...
               'r1', 'S_H 1,2', 'r2', 'S_F 1,5', 'r3', '1,0', ...
               't1', 'Aksesuar dişlileri: üç yükleme durumunda en düşük güvenlik (logaritmik eksen)', ...
               'fr', 'Doğal frekans (Hz)', 'nd', 'Düğüm çapı sayısı n', 'b1', '1× bandı', 'b2', '2× bandı', ...
               't2', 'DYN-04: aksesuar dişli gövdelerinin modları (dönen eksende, ±n·f_{dönüş})');
else
    pn = {'generator', 'OSG', 'PCU'};
    L = struct('SH', 'Pitting safety S_H', 'SF', 'Tooth root safety S_F', ...
               'c', {{'STR-01, maximum torque × K_A', 'ACC-03, 1.5 × maximum torque', 'static, at the shear torque'}}, ...
               'r1', 'S_H 1.2', 'r2', 'S_F 1.5', 'r3', '1.0', ...
               't1', 'Accessory gears: lowest safety in three load cases (log scale)', ...
               'fr', 'Natural frequency (Hz)', 'nd', 'Nodal diameters n', 'b1', '1× band', 'b2', '2× band', ...
               't2', 'DYN-04: accessory gear blank modes (rotating frame, ±n·f_{rot})');
end
blue = [0.12 0.44 0.70];  lblue = [0.55 0.75 0.90];  gold = [0.85 0.60 0.10];  grey = [0.45 0.45 0.45];
red = [0.75 0.22 0.17];

% 1. Safety factors
fig = figure('Visible', 'off', 'Position', [100 100 1050 420]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact');
for q = 1:2
    nexttile;
    Y = [S.S1(q, :); S.S2(q, :); S.S3(q, :)]';
    b = bar(Y, 'grouped');
    b(1).FaceColor = blue;  b(2).FaceColor = lblue;  b(3).FaceColor = gold;
    hold on
    yline(1, ':', 'Color', grey, 'LineWidth', 1.2);
    if q == 1
        yline(1.2, '--', 'Color', grey, 'LineWidth', 1.2);  title(L.SH, 'FontWeight', 'normal');
    else
        yline(1.5, '--', 'Color', grey, 'LineWidth', 1.2);  title(L.SF, 'FontWeight', 'normal');
    end
    set(gca, 'XTickLabel', pn, 'YScale', 'log');  ylim([0.5 200]);  grid on
    if q == 1
        legend(L.c, 'Location', 'northwest', 'FontSize', 8);
    end
end
title(tl, L.t1, 'FontSize', 10);
exportgraphics(fig, fullfile(out_dir, ['pads_' lang '.png']), 'Resolution', 150);
close(fig);

% 2. Blank modes
fig = figure('Visible', 'off', 'Position', [100 100 1050 400]);
tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact');
for k = 1:3
    nexttile;  hold on
    d = S.D(k);
    nmax = max(d.n);
    for hh = 1:2
        lo = d.band(hh, 1) * 0.9;  hi = d.band(hh, 2) * 1.1;
        patch([0 nmax nmax 0], [lo - 0 * d.frot, lo - nmax * d.frot, hi + nmax * d.frot, hi], [0.96 0.84 0.43], ...
              'EdgeColor', 'none', 'FaceAlpha', 0.7 / hh);
    end
    plot(d.n, d.f, 'o-', 'Color', red, 'MarkerFaceColor', red);
    set(gca, 'YScale', 'log');  grid on;  box on
    xlim([0 nmax]);  ylim([500 2e5]);
    xlabel(L.nd);
    if k == 1, ylabel(L.fr); end
    title(sprintf('%s (%.0f Hz)', pn{k}, d.fm), 'FontWeight', 'normal');
    text(0.2, d.band(1, 2) * 1.15, L.b1, 'FontSize', 7);
    text(0.2, d.band(2, 2) * 1.15, L.b2, 'FontSize', 7);
end
title(tl, L.t2, 'FontSize', 10);
exportgraphics(fig, fullfile(out_dir, ['modes_' lang '.png']), 'Resolution', 150);
close(fig);
end
