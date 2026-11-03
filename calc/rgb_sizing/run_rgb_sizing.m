function R = run_rgb_sizing(out_dir)
%RUN_RGB_SIZING  Full step 1.3 search of layout O: every valid design, the selection, tables and plot.
%   run_rgb_sizing              run from the repo root; writes to calc/results/step13
%   R = run_rgb_sizing(out_dir)
%
%   Sizes stage 1 for every first-stage tooth pair and stage 2 for every
%   valid tooth-count set (tooth_sets), then the shafts, bearings, critical
%   speeds and mass of every set with both stages (rgb_layout). A design is
%   valid if both stages are found and it meets the DN limit and DYN-01.
%   Selection: the lightest valid design is found; among the designs within
%   select_band of it, those whose sun-planet and planet-ring meshes are
%   both hunting-tooth come first, then the smallest ratio error, then the
%   lower mass. The selection is made for each planet count and over all.
%
%   Files written to out_dir:
%     designs.csv      every valid design, one row each
%     selected.txt     full tables of the selected design for each N and overall
%     mass_vs_u1.png   mass of the lightest design for each first-stage ratio, per N
%     tests.txt        output of test_rgb_sizing (TC1-TC9)
%   Output struct R: in, n_sets and n_designs (per N), designs (struct array
%   of rgb_layout outputs), best_N (selected design for each N), best (overall).
%
%   Source: Phase 1 report, Section 3 ("Method: mass and selection" and
%   "MATLAB tool").

if nargin < 1
    out_dir = fullfile('calc', 'results', 'step13');
end
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end
in = rgb_inputs();
tic

% Every valid tooth-count set; stage 1 depends only on the first-stage pair
S = tooth_sets(in);
designs = {};
key = [];
for k = 1:numel(S)
    t = S(k);
    if ~isequal(key, [t.z1, t.z2])
        key = [t.z1, t.z2];
        s1 = size_stage1(t.z1, t.z2, in);
    end
    if isempty(s1), continue, end
    s2 = size_stage2(t, in);
    if isempty(s2), continue, end
    L = rgb_layout(t, s1, s2, in);
    if ~isempty(L) && L.checks_ok
        designs{end + 1} = L;               %#ok<AGROW>
    end
end
D = [designs{:}];
N_of = arrayfun(@(d) d.t.N, D);

% Selection for each planet count and over all
R.in = in;
R.n_sets = arrayfun(@(N) sum([S.N] == N), in.N_list);
R.n_designs = arrayfun(@(N) sum(N_of == N), in.N_list);
R.designs = D;
R.best_N = {};
for j = 1:numel(in.N_list)
    DN = D(N_of == in.N_list(j));
    if isempty(DN)
        R.best_N{j} = [];
    else
        R.best_N{j} = DN(select_design(DN, in));
    end
end
R.best = D(select_design(D, in));
t_run = toc;

% Files
write_csv(fullfile(out_dir, 'designs.csv'), D);
fid = fopen(fullfile(out_dir, 'selected.txt'), 'w');
fprintf(fid, 'Step 1.3 RGB sizing, layout O: selected designs\n');
fprintf(fid, 'Valid tooth sets %d; valid designs %d\n', numel(S), numel(D));
for j = 1:numel(in.N_list)
    if isempty(R.best_N{j})
        fprintf(fid, '\n=== N = %d: no valid design ===\n', in.N_list(j));
    else
        write_design(fid, R.best_N{j}, in, sprintf('Selected design for N = %d (%d valid designs)', ...
                     in.N_list(j), R.n_designs(j)));
    end
end
write_design(fid, R.best, in, 'Selected design over all planet counts');
fclose(fid);
try
    plot_mass(D, in, fullfile(out_dir, 'mass_vs_u1.png'));
catch err
    warning('run_rgb_sizing: mass_vs_u1.png not written (%s)', err.message);
end
test_line = run_tests(fullfile(out_dir, 'tests.txt'));

% Summary
fprintf('Valid tooth sets: %d (N = %d: %d, N = %d: %d, N = %d: %d)\n', numel(S), ...
        [in.N_list; R.n_sets]);
fprintf('Valid designs: %d (N = %d: %d, N = %d: %d, N = %d: %d), in %.1f s\n', numel(D), ...
        [in.N_list; R.n_designs], t_run);
for j = 1:numel(in.N_list)
    if ~isempty(R.best_N{j})
        fprintf('N = %d: %s\n', in.N_list(j), one_line(R.best_N{j}, in));
    end
end
fprintf('Over all: N = %d, %s\n', R.best.t.N, one_line(R.best, in));
fprintf('Tests: %s\n', test_line);
fprintf('Files written to %s\n', out_dir);
end

function k = select_design(D, in)
% Index into D of the selected design (rule in the header)
m = arrayfun(@(d) d.mass.total, D);
near = find(m <= min(m) + in.select_band);
key = zeros(numel(near), 3);
for j = 1:numel(near)
    t = D(near(j)).t;
    key(j, :) = [~(t.hunt_sp && t.hunt_pr), abs(t.i / in.i_target - 1), m(near(j))];
end
[~, order] = sortrows(key);
k = near(order(1));
end

function s = one_line(L, in)
% One-line summary of a design
t = L.t;
s = sprintf(['%.1f kg (SYS-06: %g), z %d/%d mn %g | %d/%d/%d m %g, u1 %.3f, i2 %.3f, ' ...
             'ratio error %+.2f%%, hunting teeth in both planet meshes: %s'], ...
            L.mass.total, in.m_max, t.z1, t.z2, L.s1.mn, t.zs, t.zp, t.zr, L.s2.m, t.u1, t.i2, ...
            t.ratio_error, yes_no(t.hunt_sp && t.hunt_pr));
end

function s = yes_no(x)
if x, s = 'yes'; else, s = 'no'; end
end

function write_csv(file, D)
% Every valid design, one row each
fid = fopen(file, 'w');
fprintf(fid, ['z1,z2,zs,zp,zr,N,u1,i2,ratio_error_pct,hunt_sp,hunt_pr,mn1,b1,a1,S_H1,S_F1,' ...
              'm2,b2,post_gap,S_H_sp,S_H_ring,S_F2,L10_planet_h,s0_planet,' ...
              'd_o_input,d_o_inter,d_o_prop,mass_kg\n']);
for k = 1:numel(D)
    t = D(k).t;  s1 = D(k).s1;  s2 = D(k).s2;
    fprintf(fid, ['%d,%d,%d,%d,%d,%d,%.6f,%.6f,%.4f,%d,%d,%g,%g,%.3f,%.4f,%.4f,' ...
                  '%g,%g,%.2f,%.4f,%.4f,%.4f,%.0f,%.3f,%g,%g,%g,%.3f\n'], ...
            t.z1, t.z2, t.zs, t.zp, t.zr, t.N, t.u1, t.i2, t.ratio_error, t.hunt_sp, t.hunt_pr, ...
            s1.mn, s1.b, s1.g.a, s1.r.S_H, min(s1.r.S_F1, s1.r.S_F2), ...
            s2.m, s2.b, s2.gap, s2.S_H_sp, s2.S_H_ring, ...
            min([s2.S_F_sun, s2.S_F_planet_sp, s2.S_F_planet_pr, s2.S_F_ring]), ...
            s2.brg.L10_mission, s2.brg.s0, D(k).inp.sh.d_o, D(k).mid.sh.d_o, D(k).prop.sh.d_o, ...
            D(k).mass.total);
end
fclose(fid);
end

function write_design(fid, L, in, heading)
% Full table of one design
t = L.t;  s1 = L.s1;  g1 = s1.g;  r1 = s1.r;  rs1 = s1.rs;  s2 = L.s2;  b = s2.brg;
ns = in.n_PT / t.u1;
fprintf(fid, '\n=== %s ===\n', heading);
fprintf(fid, 'Tooth counts: z1/z2 %d/%d; zs/zp/zr %d/%d/%d; N %d\n', t.z1, t.z2, t.zs, t.zp, t.zr, t.N);
fprintf(fid, ['Ratios: u1 %.4f, i2 %.4f, i %.4f (target %.4f, error %+.3f%%); hunting teeth: ' ...
              'sun-planet %s, planet-ring %s\n'], t.u1, t.i2, t.i, in.i_target, t.ratio_error, ...
        yes_no(t.hunt_sp), yes_no(t.hunt_pr));

fprintf(fid, ['\nStage 1, helical, beta %g deg: mn %g mm, b1 %g mm, d1/d2 %.2f/%.2f mm, a %.2f mm, ' ...
              'eps_alpha %.3f, eps_beta %.3f, v %.1f m/s\n'], in.beta1, s1.mn, s1.b, g1.d1, g1.d2, ...
        g1.a, g1.eps_alpha, g1.eps_beta, r1.v);
fprintf(fid, '  at 100%% torque: Ft %.0f N, Fr %.0f N, Fa %.0f N; S_H %.3f, S_F %.3f / %.3f\n', ...
        r1.Ft, r1.Fr, r1.Fa, r1.S_H, r1.S_F1, r1.S_F2);
fprintf(fid, '  static check (LD-01): S_H %.3f, S_F %.3f / %.3f\n', rs1.S_H, rs1.S_F1, rs1.S_F2);

fprintf(fid, ['\nStage 2, planetary, spur: m %g mm, b2 %g mm, d_s/d_p/d_r %.1f/%.1f/%.1f mm, ' ...
              'post gap %.1f mm, K_gamma %.2f\n'], s2.m, s2.b, s2.ds, s2.dp, s2.dr, s2.gap, ...
        in.Kgam(in.N_list == t.N));
fprintf(fid, ['  speeds: sun %.0f rpm, carrier %.1f rpm, planet relative to the carrier %.0f rpm; ' ...
              'sun-planet pitch line velocity %.1f m/s\n'], ns, s2.n_c, s2.n_p_rel, s2.r_sp.v);
fprintf(fid, ['  sun-planet: eps_alpha %.3f, S_H %.3f, S_F sun %.3f, S_F planet %.3f; ' ...
              'static S_H %.3f, S_F %.3f\n'], s2.eps_alpha_sp, s2.S_H_sp, s2.S_F_sun, ...
        s2.S_F_planet_sp, s2.rs_sp.S_H, min(s2.rs_sp.S_F1, s2.rs_sp.S_F2));
fprintf(fid, ['  planet-ring: eps_alpha %.3f, S_H ring %.3f, S_F planet %.3f, S_F ring %.3f; ' ...
              'static S_H %.3f, S_F %.3f\n'], s2.eps_alpha_pr, s2.S_H_ring, s2.S_F_planet_pr, ...
        s2.S_F_ring, s2.rs_pr.S_H, min(s2.rs_pr.S_F1, s2.rs_pr.S_F2));
fprintf(fid, ['  planet bearing: D_or %.1f mm, D_w %.2f mm, Z %d, L_w %.1f mm, d_pin %.1f mm; ' ...
              'C %.1f kN, C0 %.1f kN\n'], b.D_or, b.D_w, b.Z, b.L_w, b.d_pin, b.C / 1e3, b.C0 / 1e3);
fprintf(fid, ['                  gear load %.2f kN, centrifugal load %.2f kN; L10 %.0f h at 100%% ' ...
              'torque, %.0f h over the mission; s0 %.2f\n'], b.F_gear / 1e3, b.F_c / 1e3, ...
        b.L10_100, b.L10_mission, b.s0);

fprintf(fid, '\nShafts: d_o / d_i [mm], bending moment for fatigue [N m], n_f, n_yield, n_ult\n');
x = {L.inp, L.mid, L.prop};
M = [L.inp.M, L.mid.M, L.prop.M_alt];
names = {'input', 'intermediate', 'propeller'};
for j = 1:3
    sh = x{j}.sh;
    fprintf(fid, '  %-13s %3g / %4.1f   M %6.0f   n_f %.2f   n_yield %.2f   n_ult %.2f\n', ...
            names{j}, sh.d_o, sh.d_i, M(j), sh.n_f, sh.n_yield, sh.n_ult);
end
fprintf(fid, '  propeller shaft at limit load (LD-01 torque with LD-05): M_lim %.0f N m\n', L.prop.M_lim);

fprintf(fid, '\nMain bearings: P_eq, C_req, C0_req [kN]; DN at 110%% speed\n');
brgs = {L.inp.roller, L.inp.QJ, L.mid.roller, L.mid.QJ, L.prop.QJ, L.prop.roller_out, L.prop.roller_in};
names = {'input roller', 'input QJ', 'intermediate roller', 'intermediate QJ', ...
         'propeller QJ', 'propeller outer roller', 'propeller inner roller'};
for j = 1:numel(brgs)
    br = brgs{j};
    fprintf(fid, '  %-23s P_eq %6.2f   C_req %6.1f   C0_req %6.1f   DN %.2e\n', ...
            names{j}, br.P_eq / 1e3, br.C_req / 1e3, br.C0_req / 1e3, br.DN);
end

fprintf(fid, '\nCritical speeds [rpm], DYN-01 asks for at least %g x %g x the running speed\n', ...
        in.ncr_margin, in.n_cont_max);
n_run = [in.n_PT, ns, in.n_prop];
names = {'input', 'intermediate', 'propeller'};
for j = 1:3
    fprintf(fid, '  %-13s n_cr %8.0f   limit %6.0f\n', names{j}, x{j}.n_cr, ...
            in.ncr_margin * in.n_cont_max * n_run(j));
end

m = L.mass;
fprintf(fid, ['\nMass [kg]: pinion %.2f, first-stage gear %.2f, sun %.2f, planets %.2f, ring %.2f, ' ...
              'carrier %.2f, shafts %.2f, bearings %.2f, housing %.2f, accessory drives %.2f, ' ...
              'other %.2f; total %.1f (SYS-06: %g)\n'], m.pinion, m.gear2, m.sun, m.planets, m.ring, ...
        m.carrier, m.shafts, m.bearings, m.housing, m.accessory, m.misc, m.total, in.m_max);
fprintf(fid, 'Housing envelope: a %.1f mm, D_z %.1f mm, L_g %.1f mm\n', L.env.a, L.env.D_z, L.env.L_g);
end

function plot_mass(D, in, file)
% Mass of the lightest design for each first-stage ratio, one series per N.
% The y axis stops 20 kg above the SYS-06 limit, so that the range the
% selection works in stays readable; the title counts the points above it.
fig = figure('Visible', 'off');
hold on
marks = {'o', 's', '^'};
u_all = arrayfun(@(d) d.t.u1, D);
y_top = in.m_max + 20;
m_low = inf;
n_off = 0;
for j = 1:numel(in.N_list)
    pick = arrayfun(@(d) d.t.N == in.N_list(j), D);
    if ~any(pick), continue, end
    m = arrayfun(@(d) d.mass.total, D(pick));
    [u1, ~, idx] = unique(u_all(pick));
    m_min = accumarray(idx(:), m(:), [], @min);
    m_low = min(m_low, min(m_min));
    n_off = n_off + sum(m_min > y_top);
    plot(u1, m_min, marks{j}, 'DisplayName', sprintf('N = %d', in.N_list(j)));
end
plot([min(u_all), max(u_all)], [in.m_max, in.m_max], 'k--', 'DisplayName', 'SYS-06 limit');
ylim([10 * floor(m_low / 10), y_top]);
xlabel('First-stage ratio u_1');
ylabel('Mass of the lightest design (kg)');
title({'Lightest valid design for each first-stage ratio', ...
       sprintf('%d points above %g kg are off the chart', n_off, y_top)});
legend('Location', 'best');
grid on
box on
print(fig, file, '-dpng', '-r150');
close(fig);
end

function last = run_tests(file)
% Runs test_rgb_sizing, saves its output and returns its last line
txt = evalc('test_rgb_sizing');
fid = fopen(file, 'w');
fprintf(fid, '%s', txt);
fclose(fid);
lines = strsplit(strtrim(txt), char(10));
last = strtrim(lines{end});
end
