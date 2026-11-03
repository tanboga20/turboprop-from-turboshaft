function S = run_step21(out_dir, mode)
%RUN_STEP21  Step 2.1 full run: propeller shaft rotor model, damper concepts and DYN-05.
%   run_step21              run from the repo root; writes to calc/results/step21
%   S = run_step21(out_dir)
%   run_step21(out_dir, 'plots')   redraws the plots from out_dir/step21.mat
%
%   Needs calc/rotor_damper, calc/rgb_sizing (rgb_inputs, shaft_check) and
%   calc/agb_lube (oil_props) on the path:
%   addpath('calc/rotor_damper', 'calc/rgb_sizing', 'calc/agb_lube').
%   1. Validation: the Phase 1 ROSS model of the propeller shaft (bearings
%      straight to ground) rebuilt with rotor_model; crossings, frequencies,
%      unbalance response and the damping sweep of the Phase 1 printout.
%   2. Concepts over the housing envelope (in.kh_list x in.aniso_list): the
%      housing alone, a squeeze-film damper with a squirrel cage at both
%      bearings, a damper bearing at the carrier, and thin-walled stiffer
%      propeller shafts. DYN-05 ratio = largest propeller orbit from
%      in.n_scan(1) to 110% speed over the orbit at 1,700 rpm.
%   3. The steady offset of a squeeze-film damper journal under the 1 g
%      weight and the 1P moment, and the damping that a land can then give.
%   4. Shafts A and B: the DYN-05 ratio over a grid of housing stiffness
%      in the two directions (in.k_map), and the lowest stiffness that meets it.
%   5. Shaft A on the nominal housing and on the stiffness floor: Campbell
%      diagram, unbalance response, shaft stresses (DYN-03), bearing forces.
%
%   Files written to out_dir:
%     summary.txt     every table of the step
%     concepts.csv    worst DYN-05 ratio and lowest 1 x crossing per concept
%     ratio_map.csv   DYN-05 ratio of shafts A and B over the housing grid
%     campbell.csv    Campbell diagram of the Phase 1 shaft and shaft A
%     unbalance.csv   propeller orbit over speed, Phase 1 shaft and shaft A
%     campbell_en.png, unbalance_en.png, ratio_map_en.png and the _tr
%                     versions with Turkish labels
%     step21.mat      the output struct, for redrawing the plots
%     tests.txt       output of test_step21 (TC18-TC23)
%   Output struct S: in, val (validation), con (concepts), sfd (offset and
%   damping), map, fin (final design).
%
%   Source: Phase 2 report, Section 2.1.

if nargin < 1 || isempty(out_dir)
    out_dir = fullfile('calc', 'results', 'step21');
end
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end
if nargin == 2 && strcmp(mode, 'plots')
    S = load(fullfile(out_dir, 'step21.mat')).S;
    plots(out_dir, S, 'en');
    plots(out_dir, S, 'tr');
    return
end
in = damper_inputs();
r13 = rgb_inputs();
U = in.prop.m * in.G_bal / (in.n_prop * pi / 30);
rpm_u = in.n_scan(1):2:in.n_scan(2);
rpm_c = 0:20:3000;
rpm_s = 0:50:3000;                          % coarser grid for the concept screening
S.in = in;
S.U = U;

% 1. Validation against the Phase 1 ROSS model
in1 = in;
in1.flange = [];
direct = @(k, c, an) support('direct', k, an * k, c, c);
v.k = in.k_list(:);
v.cross = nan(numel(in.k_list), 1);
for j = 1:numel(in.k_list)
    k = in.k_list(j);
    cb = rotor_campbell(rotor_model(in1, [direct(k, in.c_ph1, 1), direct(k, in.c_ph1, 1)]), 0:50:3000, 6);
    v.cross(j) = min(cb.cross(:, 2));
    if k == in.k_nom
        v.f0 = cb.f(1, 1:4);
        v.f1700 = cb.f(cb.rpm == 1700, 1:4);
        v.whirl1700 = cb.whirl(cb.rpm == 1700, 1:4);
    end
end
rpm_v = unique([200:10:2600, 1300:1:1800]);
cases = {'isotropic', 1, in.c_ph1; 'kyy = kxx / 2', 0.5, in.c_ph1; 'kyy = kxx / 2, c 3e4', 0.5, 3e4};
for j = 1:3
    R = rotor_model(in1, [direct(in.k_nom, cases{j, 3}, cases{j, 2}), direct(in.k_nom, cases{j, 3}, cases{j, 2})]);
    ub = rotor_unbalance(R, rpm_v, R.n_prop, U);
    a = ub.a_node;
    [pk, i] = local_peak(rpm_v, a);
    v.ub(j) = struct('name', cases{j, 1}, 'a1700', interp1(rpm_v, a, 1700), 'peak', pk, 'n_peak', rpm_v(i));
end
S.val = v;

% 2. Concepts over the housing envelope
ch = @(k) 2 * in.c_h_ratio * sqrt(k * in.m_h);
chain = @(ksc, c, kh, an) support('chain', in.k_brg, in.m_j, ksc, c, in.m_h, kh, an * kh, ch(kh), ch(an * kh));
con = struct('name', {}, 'par', {}, 'ratio', {}, 'ratio_soft', {}, 'x_min', {}, 'fwd_band', {}, 'mass', {});
band = [(1 - in.margin) * in.n_steady(1), (1 + in.margin) * in.n_steady(2)];
inA = in;
% a. housing only, the step 1.3 shaft
for an = [in.aniso_list, in.aniso_fine]
    for kh = in.kh_list
        [r, x, fb] = envelope(inA, @(k, a) [chain(in.k_rigid, 0, k, a), chain(in.k_rigid, 0, k, a)], ...
                              kh, an, U, rpm_u, rpm_s, band);
        con(end + 1) = struct('name', 'housing only', 'par', [kh an], 'ratio', r, 'ratio_soft', NaN, ...
                              'x_min', x, 'fwd_band', fb, 'mass', NaN); %#ok<AGROW>
    end
end
% b. squeeze film and squirrel cage at both bearings
for ksc = in.sfd_ksc
    for c = in.sfd_c
        [r, x, fb] = envelope(inA, @(k, a) [chain(ksc, c, k, a), chain(ksc, c, k, a)], ...
                              in.kh_list, in.aniso_list, U, rpm_u, rpm_s, band);
        con(end + 1) = struct('name', 'SFD + cage, both bearings', 'par', [ksc c], 'ratio', r, ...
                              'ratio_soft', NaN, 'x_min', x, 'fwd_band', fb, 'mass', NaN); %#ok<AGROW>
    end
end
% c. damper bearing at the carrier, main bearings straight into the housing
for ksc = in.car_ksc
    for c = in.sfd_c([1 2 4])
        f = @(k, a) [chain(in.k_rigid, 0, k, a), chain(in.k_rigid, 0, k, a), ...
                     support('chain', in.k_brg, in.m_j, ksc, c, in.m_h, k, a * k, ch(k), ch(a * k), 'n', 1)];
        [r, x, fb] = envelope(inA, f, in.kh_list, in.aniso_list, U, rpm_u, rpm_s, band);
        con(end + 1) = struct('name', 'damper bearing at carrier', 'par', [ksc c], 'ratio', r, ...
                              'ratio_soft', NaN, 'x_min', x, 'fwd_band', fb, 'mass', NaN); %#ok<AGROW>
    end
end
% d. thin-walled stiffer shafts, no damper, with the propeller flange
for j = 1:size(in.shafts, 1)
    inS = shaft(in, in.shafts(j, :));
    f = @(k, a) [chain(in.k_rigid, 0, k, a), chain(in.k_rigid, 0, k, a)];
    [r, x, fb] = envelope(inS, f, in.kh_list(in.kh_list >= 1e8), in.aniso_list, U, rpm_u, rpm_s, band);
    rs = envelope(inS, f, in.kh_list(in.kh_list < 1e8), in.aniso_list, U, rpm_u, rpm_s, band);
    con(end + 1) = struct('name', 'stiff shaft', 'par', in.shafts(j, :) * 1e3, 'ratio', r, 'ratio_soft', rs, ...
                          'x_min', x, 'fwd_band', fb, 'mass', shaft_mass(inS)); %#ok<AGROW>
end
S.con = con;

% 3. Squeeze-film damper journal offset under steady loads, and the damping a land gives
sfd.M1P = [r13.M_1P, 500];                  % N m: the step 1.3 fatigue value and a strip-theory estimate
Fw = in.prop.m * in.g;
o = oil_props(in.T_oil(2) + in.dT_film, in.oil);
rows = struct('M1P', {}, 'F', {}, 'k_sc', {}, 'offset', {}, 'c_need', {}, 'C', {});
for j = 1:2
    F_out = Fw * (1 + in.overhang / in.span) + sfd.M1P(j) / in.span;
    for ksc = in.sfd_ksc(1:4)
        e = F_out / ksc;
        c_need = e / in.eps_static_max;
        d = sfd_coeffs(in.R_sfd_min, in.L_sfd_max, max(c_need, in.c_sfd_min), o.eta / 1000, 0, in.seal_factor);
        rows(end + 1) = struct('M1P', sfd.M1P(j), 'F', F_out, 'k_sc', ksc, 'offset', e, ...
                               'c_need', c_need, 'C', d.C); %#ok<AGROW>
    end
end
sfd.rows = rows;
o_cold = oil_props(in.T_oil(1) + in.dT_film, in.oil);
sfd.C_best = sfd_coeffs(in.R_sfd_min, in.L_sfd_max, in.c_sfd_min, o_cold.eta / 1000, 0, in.seal_factor).C;
S.sfd = sfd;

% 4. Shafts A and B over the housing stiffness grid (kxx >= kyy)
km = in.k_map;
names = {'A', 'B'};
dd = [in.shaft_A; in.shaft_B];
for s = 1:2
    inS = shaft(in, dd(s, :));
    ratio = nan(numel(km));
    for ix = 1:numel(km)
        for iy = 1:ix
            R = rotor_model(inS, [chain(in.k_rigid, 0, km(ix), km(iy) / km(ix)), ...
                                  chain(in.k_rigid, 0, km(ix), km(iy) / km(ix))]);
            ub = rotor_unbalance(R, rpm_u, R.n_prop, U);
            ratio(ix, iy) = max(ub.a_node) / ub.a_node(rpm_u == in.n_prop);
            ratio(iy, ix) = ratio(ix, iy);
        end
    end
    ok = ratio <= in.ratio_max;
    k_floor = NaN;                          % lowest k such that every pair with both values >= k passes
    for j = 1:numel(km)
        if all(all(ok(j:end, j:end)))
            k_floor = km(j);
            break
        end
    end
    map.(names{s}) = struct('d', dd(s, :), 'ratio', ratio, 'k_floor', k_floor, 'mass', shaft_mass(inS));
end
map.k = km;
S.map = map;

% 5. Shaft A on the nominal housing and on the floor
inA = shaft(in, in.shaft_A);
fin.k_floor = map.A.k_floor;
cfg = {'nominal, isotropic', in.k_h_nom, 1; 'nominal, kyy = kxx / 2', in.k_h_nom, 0.5; ...
       'floor, isotropic', fin.k_floor, 1; 'floor, kyy = kxx / 2', 2 * fin.k_floor, 0.5};
for j = 1:size(cfg, 1)
    R = rotor_model(inA, [chain(in.k_rigid, 0, cfg{j, 2}, cfg{j, 3}), chain(in.k_rigid, 0, cfg{j, 2}, cfg{j, 3})]);
    cb = rotor_campbell(R, rpm_c, 6);
    ub = rotor_unbalance(R, rpm_u, R.n_prop, U);
    i17 = rpm_u == in.n_prop;
    fin.cases(j) = struct('name', cfg{j, 1}, 'kxx', cfg{j, 2}, 'kyy', cfg{j, 2} * cfg{j, 3}, 'cb', cb, ...
                          'a', ub.a_node, 'ratio', max(ub.a_node) / ub.a_node(i17), ...
                          'a1700', ub.a_node(i17), 'sigma_alt', max(ub.sigma_alt), ...
                          'sigma_ss', max(ub.sigma_ss), 'F_brg', max(ub.F_brg, [], 1));
end
% The Phase 1 shaft on the same housings, for the plots
inP = shaft(in, in.shafts(1, :));
for j = 1:size(cfg, 1)
    R = rotor_model(inP, [chain(in.k_rigid, 0, cfg{j, 2}, cfg{j, 3}), chain(in.k_rigid, 0, cfg{j, 2}, cfg{j, 3})]);
    fin.ph1(j) = struct('cb', rotor_campbell(R, rpm_c, 6), 'a', rotor_unbalance(R, rpm_u, R.n_prop, U).a_node);
end
% Shaft strength with the new section: step 1.3 loads and criteria (STR-03)
Fw1 = r13.m_prop * r13.g;
Fwl = r13.m_prop * r13.nz_gyro * r13.g;
a_mm = in.overhang * 1e3;
fin.sh = shaft_check(in.shaft_A(1) * 1e3, in.shaft_A(2) * 1e3, r13.T_prop, r13.M_1P + Fw1 * a_mm / 1e3, ...
                     r13.thrust, r13.K_over * r13.T_prop, Fwl * a_mm / 1e3 + r13.M_gyro, r13.thrust, r13);
fin.sh_ph1 = shaft_check(75, 45, r13.T_prop, r13.M_1P + Fw1 * a_mm / 1e3, r13.thrust, ...
                         r13.K_over * r13.T_prop, Fwl * a_mm / 1e3 + r13.M_gyro, r13.thrust, r13);
fin.mass_A = shaft_mass(inA);
fin.mass_ph1 = shaft_mass(shaft(in, in.shafts(1, :)));
S.fin = fin;
S.rpm_u = rpm_u;
S.rpm_c = rpm_c;

save(fullfile(out_dir, 'step21.mat'), 'S');
write_summary(fullfile(out_dir, 'summary.txt'), S);
write_csv(out_dir, S);
plots(out_dir, S, 'en');
plots(out_dir, S, 'tr');
diary(fullfile(out_dir, 'tests.txt'));
test_step21;
diary off
end

function inS = shaft(in, d)
% The inputs with one thin-walled shaft section [d_o d_i] from the carrier to the flange
inS = in;
inS.shaft.d_o = d(1);
inS.shaft.d_i = d(2);
inS.shaft_over = [];
end

function m = shaft_mass(in)
% Mass of the modelled shaft, carrier stub to flange [kg]
m = in.shaft.rho * pi / 4 * (in.shaft.d_o^2 - in.shaft.d_i^2) * (in.stub + in.span + in.overhang);
end

function [ratio, x_min, fwd_band] = envelope(in, supfun, kh_list, an_list, U, rpm_u, rpm_c, band)
% Worst DYN-05 ratio, lowest 1 x crossing of a mode that is not forward,
% and whether a forward mode crosses 1 x inside the DYN-01 band, over a housing envelope
ratio = 0;
x_min = inf;
fwd_band = false;
for kh = kh_list
    for an = an_list
        R = rotor_model(in, supfun(kh, an));
        ub = rotor_unbalance(R, rpm_u, R.n_prop, U);
        ratio = max(ratio, max(ub.a_node) / ub.a_node(abs(rpm_u - 1700) < 1e-9));
        cb = rotor_campbell(R, rpm_c, 6);
        cr = cb.cross(cb.cross(:, 2) >= rpm_u(1), :);  % below the scan start: damped support modes
        if ~isempty(cr)
            nf = cr(cr(:, 3) <= 0, 2);
            if ~isempty(nf), x_min = min(x_min, min(nf)); end
            fw = cr(cr(:, 3) > 0, 2);
            fwd_band = fwd_band || any(fw > band(1) & fw < band(2));
        end
    end
end
end

function [pk, i] = local_peak(rpm, a)
% Largest interior local maximum of a response curve (the Phase 1 printout's definition)
i = find(a(2:end - 1) > a(1:end - 2) & a(2:end - 1) >= a(3:end)) + 1;
if isempty(i)
    [pk, i] = max(a);
else
    [pk, j] = max(a(i));
    i = i(j);
end
end

function write_summary(file, S)
in = S.in;  v = S.val;
fid = fopen(file, 'w');
fprintf(fid, 'Step 2.1: propeller shaft rotor model, damper concepts, DYN-05\n');
fprintf(fid, 'Propeller unbalance G%.1f: %.1f g mm; DYN-05 ratio = largest orbit %g-%g rpm / orbit at %g rpm\n', ...
        in.G_bal * 1e3, S.U * 1e6, in.n_scan, in.n_prop);

fprintf(fid, '\n1. Validation: Phase 1 ROSS model rebuilt in MATLAB (75/45 mm shaft, bearings to ground)\n');
fprintf(fid, '  1 x crossing of the backward mode [rpm]:');
fprintf(fid, ' k %.0e: %.1f;', [v.k.'; v.cross.']);
fprintf(fid, '\n  k 1e8: modes at 0 rpm %s cpm; at 1700 rpm %s cpm, whirl %s\n', ...
        mat2str(round(v.f0, 1)), mat2str(round(v.f1700, 1)), mat2str(v.whirl1700));
for j = 1:numel(v.ub)
    fprintf(fid, '  unbalance, %-22s %8.2f um at 1700 rpm; peak %8.2f um at %4.0f rpm\n', [v.ub(j).name ':'], ...
            v.ub(j).a1700 * 1e6, v.ub(j).peak * 1e6, v.ub(j).n_peak);
end

fprintf(fid, '\n2. Concepts over the housing envelope (kh %s N/m, kyy/kxx %s unless noted)\n', ...
        mat2str(in.kh_list), mat2str(in.aniso_list));
fprintf(fid, '  %-28s %-22s %10s %10s %12s %9s %8s\n', 'concept', 'parameters', 'ratio', 'ratio 5e7', ...
        'x_min rpm', 'fwd band', 'mass kg');
for c = S.con
    fprintf(fid, '  %-28s %-22s %10.2f %10.2f %12.0f %9d %8.1f\n', c.name, mat2str(c.par, 3), c.ratio, ...
            c.ratio_soft, c.x_min, c.fwd_band, c.mass);
end

fprintf(fid, '\n3. Squeeze-film damper journal under steady loads (1 g weight and the 1P moment, outer bearing)\n');
fprintf(fid, '  %-8s %8s %10s %10s %12s %12s\n', 'M1P N m', 'F N', 'k_sc N/m', 'offset mm', 'c needed mm', 'C N s/m');
for r = S.sfd.rows
    fprintf(fid, '  %-8.0f %8.0f %10.0e %10.3f %12.3f %12.0f\n', r.M1P, r.F, r.k_sc, r.offset * 1e3, ...
            r.c_need * 1e3, r.C);
end
fprintf(fid, ['  C at the best land (R %.0f mm, L %.0f mm, c %.2f mm, sealed, oil %g degC): %.0f N s/m; ' ...
              'a cage of 3e7 N/m needs about 3e4\n'], in.R_sfd_min * 1e3, in.L_sfd_max * 1e3, in.c_sfd_min * 1e3, ...
        in.T_oil(1) + in.dT_film, S.sfd.C_best);

fprintf(fid, '\n4. DYN-05 ratio over housing stiffness [N/m], rows kxx, columns kyy\n');
for s = {'A', 'B'}
    m = S.map.(s{1});
    fprintf(fid, '  shaft %s %.0f/%.0f mm, %.1f kg: lowest housing stiffness in both directions %.1e N/m\n', ...
            s{1}, m.d * 1e3, m.mass, m.k_floor);
    fprintf(fid, '  %9s', '');
    fprintf(fid, ' %8.1e', S.map.k);
    fprintf(fid, '\n');
    for ix = 1:numel(S.map.k)
        fprintf(fid, '  %9.1e', S.map.k(ix));
        fprintf(fid, ' %8.2f', m.ratio(ix, :));
        fprintf(fid, '\n');
    end
end

f = S.fin;
fprintf(fid, '\n5. Shaft A %.0f/%.0f mm (%.1f kg; Phase 1 shaft %.1f kg)\n', in.shaft_A * 1e3, f.mass_A, f.mass_ph1);
for c = f.cases
    cr = c.cb.cross;
    xs = 'none';
    if ~isempty(cr), xs = sprintf('%.0f rpm (whirl %d) ', cr(:, 2:3).'); end
    fprintf(fid, '  %-24s kxx %.1e kyy %.1e: ratio %.2f, orbit at 1700 %.2f um; 1 x crossings %s\n', c.name, ...
            c.kxx, c.kyy, c.ratio, c.a1700 * 1e6, xs);
    fprintf(fid, '  %-24s shaft stress: alternating %.2f MPa, steady %.2f MPa; bearing force %s N\n', '', ...
            c.sigma_alt / 1e6, c.sigma_ss / 1e6, mat2str(round(c.F_brg)));
end
fprintf(fid, '  strength (step 1.3 loads): n_f %.2f (Phase 1 shaft %.2f), n_yield %.2f (%.2f), n_ult %.2f (%.2f)\n', ...
        f.sh.n_f, f.sh_ph1.n_f, f.sh.n_yield, f.sh_ph1.n_yield, f.sh.n_ult, f.sh_ph1.n_ult);
fprintf(fid, '  DYN-03: endurance limit of the section S_e %.0f MPa\n', f.sh.S_e);
fclose(fid);
end

function write_csv(out_dir, S)
c = S.con;
fid = fopen(fullfile(out_dir, 'concepts.csv'), 'w');
fprintf(fid, 'concept,par1,par2,ratio,ratio_soft_housing,x_min_rpm,fwd_in_band,mass_kg\n');
for j = 1:numel(c)
    fprintf(fid, '%s,%g,%g,%.3f,%.3f,%.1f,%d,%.2f\n', c(j).name, c(j).par(1), c(j).par(2), c(j).ratio, ...
            c(j).ratio_soft, c(j).x_min, c(j).fwd_band, c(j).mass);
end
fclose(fid);
fid = fopen(fullfile(out_dir, 'ratio_map.csv'), 'w');
fprintf(fid, 'shaft,kxx_N_per_m,kyy_N_per_m,ratio\n');
for s = {'A', 'B'}
    m = S.map.(s{1});
    for ix = 1:numel(S.map.k)
        for iy = 1:numel(S.map.k)
            fprintf(fid, '%s,%g,%g,%.3f\n', s{1}, S.map.k(ix), S.map.k(iy), m.ratio(ix, iy));
        end
    end
end
fclose(fid);
fid = fopen(fullfile(out_dir, 'campbell.csv'), 'w');
fprintf(fid, 'shaft,case,rpm,mode,cpm,whirl\n');
for j = 1:numel(S.fin.cases)
    for t = {'phase1', 'A'}
        if strcmp(t{1}, 'A'), cb = S.fin.cases(j).cb; else, cb = S.fin.ph1(j).cb; end
        for i = 1:numel(cb.rpm)
            for k = 1:size(cb.f, 2)
                fprintf(fid, '%s,%s,%.0f,%d,%.1f,%d\n', t{1}, S.fin.cases(j).name, cb.rpm(i), k, cb.f(i, k), cb.whirl(i, k));
            end
        end
    end
end
fclose(fid);
fid = fopen(fullfile(out_dir, 'unbalance.csv'), 'w');
fprintf(fid, 'rpm');
for j = 1:numel(S.fin.cases)
    fprintf(fid, ',phase1 %s um,A %s um', S.fin.cases(j).name, S.fin.cases(j).name);
end
fprintf(fid, '\n');
for i = 1:numel(S.rpm_u)
    fprintf(fid, '%.0f', S.rpm_u(i));
    for j = 1:numel(S.fin.cases)
        fprintf(fid, ',%.3f,%.3f', S.fin.ph1(j).a(i) * 1e6, S.fin.cases(j).a(i) * 1e6);
    end
    fprintf(fid, '\n');
end
fclose(fid);
end

function plots(out_dir, S, lang)
% Campbell diagram, unbalance response and DYN-05 map; lang 'en' or 'tr' sets the labels
in = S.in;
T = labels(lang, in, S);
band = [(1 - in.margin) * in.n_steady(1), (1 + in.margin) * in.n_steady(2)];
blue = [0.12 0.44 0.70];  red = [0.75 0.22 0.17];  grey = [0.35 0.35 0.35];
gold = [0.96 0.84 0.43];

% Campbell: Phase 1 shaft and shaft A, nominal housing, kyy = kxx / 2
fig = figure('Visible', 'off', 'Position', [100 100 1100 480]);
for p = 1:2
    subplot(1, 2, p);
    if p == 1, cb = S.fin.ph1(2).cb; else, cb = S.fin.cases(2).cb; end
    hold on
    patch([band(1) band(2) band(2) band(1)], [0 0 12000 12000], gold, 'FaceAlpha', 0.15, 'EdgeColor', 'none');
    patch([in.n_steady(1) in.n_steady(2) in.n_steady(2) in.n_steady(1)], [0 0 12000 12000], gold, ...
          'FaceAlpha', 0.5, 'EdgeColor', 'none');
    hf = [];  hb = [];
    for k = 1:size(cb.f, 2)
        plot(cb.rpm, cb.f(:, k), '-', 'Color', grey, 'LineWidth', 0.6);
        fw = cb.whirl(:, k) > 0;  bw = cb.whirl(:, k) < 0;
        h = plot(cb.rpm(fw), cb.f(fw, k), 'o', 'MarkerSize', 3, 'Color', blue, 'MarkerFaceColor', blue);
        if any(fw), hf = h; end
        h = plot(cb.rpm(bw), cb.f(bw, k), 's', 'MarkerSize', 3, 'Color', red, 'MarkerFaceColor', red);
        if any(bw), hb = h; end
    end
    h1 = plot(cb.rpm, cb.rpm, 'k--', 'LineWidth', 1);
    xline(in.n_over, ':k', '110%', 'LabelVerticalAlignment', 'bottom');
    xlim([0 3000]);  ylim([0 12000]);  grid on;  box on
    xlabel(T.speed);  ylabel(T.freq);
    title(T.camp_title{p}, 'FontWeight', 'normal', 'FontSize', 10);
    if p == 1
        legend([hf hb h1], {T.fwd, T.bwd, T.onex}, 'Location', 'northwest', 'FontSize', 8);
    end
end
sgtitle(T.camp_sup, 'FontSize', 10);
exportgraphics(fig, fullfile(out_dir, ['campbell_' lang '.png']), 'Resolution', 150);
close(fig);

% Unbalance response
fig = figure('Visible', 'off', 'Position', [100 100 820 470]);
hold on
patch([band(1) in.n_scan(2) in.n_scan(2) band(1)], [1e-1 1e-1 1e4 1e4], gold, 'FaceAlpha', 0.15, 'EdgeColor', 'none');
patch([in.n_steady(1) in.n_steady(2) in.n_steady(2) in.n_steady(1)], [1e-1 1e-1 1e4 1e4], gold, ...
      'FaceAlpha', 0.5, 'EdgeColor', 'none');
h1 = semilogy(S.rpm_u, S.fin.ph1(2).a * 1e6, '-', 'Color', red, 'LineWidth', 1.4);
h2 = semilogy(S.rpm_u, S.fin.cases(2).a * 1e6, '-', 'Color', blue, 'LineWidth', 1.4);
h3 = semilogy(S.rpm_u, S.fin.cases(4).a * 1e6, '--', 'Color', blue, 'LineWidth', 1.1);
set(gca, 'YScale', 'log');
xlim(in.n_scan);  ylim([1e-1 1e4]);  grid on;  box on
xlabel(T.speed);  ylabel(T.orbit);
legend([h1 h2 h3], T.ub_leg, 'Location', 'northwest', 'FontSize', 8);
title(T.ub_title, 'FontWeight', 'normal', 'FontSize', 10);
exportgraphics(fig, fullfile(out_dir, ['unbalance_' lang '.png']), 'Resolution', 150);
close(fig);

% DYN-05 ratio map: green cells meet the limit, red cells do not
fig = figure('Visible', 'off', 'Position', [100 100 1050 470]);
for p = 1:2
    subplot(1, 2, p);
    s = char('A' + p - 1);
    m = S.map.(s);
    imagesc(double(m.ratio <= in.ratio_max));
    axis xy equal tight
    colormap(gca, [0.98 0.86 0.86; 0.88 0.96 0.88]);
    caxis([0 1]);
    set(gca, 'XTick', 1:numel(S.map.k), 'XTickLabel', compose('%.2g', S.map.k / 1e8), ...
             'YTick', 1:numel(S.map.k), 'YTickLabel', compose('%.2g', S.map.k / 1e8));
    for ix = 1:numel(S.map.k)
        for iy = 1:numel(S.map.k)
            text(iy, ix, sprintf('%.1f', min(m.ratio(ix, iy), 999)), 'HorizontalAlignment', 'center', ...
                 'FontSize', 7.5);
        end
    end
    xlabel(T.kyy);  ylabel(T.kxx);
    title(sprintf(T.map_title, s, m.d * 1e3, m.k_floor / 1e7), 'FontWeight', 'normal', 'FontSize', 9.5);
end
sgtitle(T.map_sup, 'FontSize', 10);
exportgraphics(fig, fullfile(out_dir, ['ratio_map_' lang '.png']), 'Resolution', 150);
close(fig);
end

function T = labels(lang, in, S)
% Plot labels in English or Turkish
A = in.shaft_A * 1e3;
if strcmp(lang, 'tr')
    T.speed = 'Pervane hızı (rpm)';
    T.freq = 'Doğal frekans (cpm)';
    T.fwd = 'ileri yönlü';  T.bwd = 'geri yönlü';  T.onex = '1× dönme hızı';
    T.camp_title = {'Faz 1 mili 75/45 mm', sprintf('A mili %.0f/%.0f mm', A)};
    T.camp_sup = sprintf(['Campbell diyagramı, gövde yuvası k_{xx} = %.0e N/m, k_{yy} = k_{xx}/2; ' ...
                          'koyu bant sürekli çalışma aralığı, açık bant DYN-01 payı'], in.k_h_nom);
    T.orbit = 'Pervane yörüngesi, büyük yarı eksen (\mum)';
    T.ub_leg = {sprintf('Faz 1 mili, gövde %.0e / %.0e N/m', in.k_h_nom, in.k_h_nom / 2), ...
                sprintf('A mili, aynı gövde (oran %.2f)', S.fin.cases(2).ratio), ...
                sprintf('A mili, taban gövde %.0e / %.0e N/m (oran %.2f)', S.fin.cases(4).kxx, ...
                        S.fin.cases(4).kyy, S.fin.cases(4).ratio)};
    T.ub_title = sprintf('Pervanede G%.1f dengesizlik (%.0f g·mm) cevabı', in.G_bal * 1e3, S.U * 1e6);
    T.kyy = 'k_{yy} gövde (10^8 N/m)';  T.kxx = 'k_{xx} gövde (10^8 N/m)';
    T.map_title = '%s mili %.0f/%.0f mm: taban her yönde %.0f×10^7 N/m';
    T.map_sup = sprintf('DYN-05 oranı (sınır %.1f): yeşil hücre sağlıyor, kırmızı hücre sağlamıyor', in.ratio_max);
else
    T.speed = 'Propeller speed (rpm)';
    T.freq = 'Natural frequency (cpm)';
    T.fwd = 'forward';  T.bwd = 'backward';  T.onex = '1× running speed';
    T.camp_title = {'Phase 1 shaft 75/45 mm', sprintf('Shaft A %.0f/%.0f mm', A)};
    T.camp_sup = sprintf(['Campbell diagram, housing seat k_{xx} = %.0e N/m, k_{yy} = k_{xx}/2; ' ...
                          'dark band steady range, light band DYN-01 margin'], in.k_h_nom);
    T.orbit = 'Propeller orbit, major semi-axis (\mum)';
    T.ub_leg = {sprintf('Phase 1 shaft, housing %.0e / %.0e N/m', in.k_h_nom, in.k_h_nom / 2), ...
                sprintf('Shaft A, same housing (ratio %.2f)', S.fin.cases(2).ratio), ...
                sprintf('Shaft A, floor housing %.0e / %.0e N/m (ratio %.2f)', S.fin.cases(4).kxx, ...
                        S.fin.cases(4).kyy, S.fin.cases(4).ratio)};
    T.ub_title = sprintf('Response to a G%.1f unbalance at the propeller (%.0f g·mm)', in.G_bal * 1e3, S.U * 1e6);
    T.kyy = 'k_{yy} housing (10^8 N/m)';  T.kxx = 'k_{xx} housing (10^8 N/m)';
    T.map_title = 'Shaft %s %.0f/%.0f mm: floor %.0f×10^7 N/m in every direction';
    T.map_sup = sprintf('DYN-05 ratio (limit %.1f): green cells meet it, red cells do not', in.ratio_max);
end
end
