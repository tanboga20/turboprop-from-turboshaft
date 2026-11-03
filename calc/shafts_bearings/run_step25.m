function S = run_step25(out_dir, mode)
%RUN_STEP25  Step 2.5: bearings, shafts, splines and propeller retention.
%   S = run_step25()                  full run, results in calc/results/step25
%   S = run_step25(out_dir)           results in out_dir
%   S = run_step25(out_dir, 'plots')  redraw the plots from step25.mat
%
%   Runs from the repo root with calc/shafts_bearings and calc/gear_detail
%   on the path. Steps:
%    1. gear forces of the current gear design (gd_inputs) and the planet
%       load sharing factor at each mission step: the 99th percentile for
%       the static checks, in.planet.Kgam_pct for the planet bearing life
%    2. bearing loads: input and intermediate shafts (gear centred between
%       two roller bearings, a radially free QJ for the axial force),
%       propeller shaft (weight, 1P moment, thrust), planet bearing (two
%       mesh forces, K_gamma, centrifugal load)
%    3. ratings, L10m over the mission, static safety at LD-01, LD-05 and
%       LD-08 for every bearing; the planet bearing in one row, full
%       complement
%    4. DYN-04: planet modes as a free ring, on the loaded rollers, and on
%       the rollers with the two mesh springs
%    5. shafts, quill splines, propeller retention options
%    6. mass of the planetary stage against the step 2.4 design
%   Writes summary.txt, bearings.csv, three plots in English and Turkish
%   and step25.mat to out_dir (calc/results is not committed).
%
%   Source: Phase 2 report, Section 2.5.

if nargin < 1 || isempty(out_dir)
    out_dir = fullfile('calc', 'results', 'step25');
end
if nargin < 2, mode = 'full'; end
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
if strcmp(mode, 'plots')
    L = load(fullfile(out_dir, 'step25.mat'));
    make_plots(L.S, out_dir);
    S = L.S;
    return
end

in = sb_inputs();
S = struct('in', in);

% 1. Gear forces and K_gamma at each mission step and at LD-01
gi = gd_inputs();
M = gd_meshes(gi);
ref = struct('KA', 1, 'mode', 'ref', 'oil', gi.oil(1), 'Kgam', 1);
r2 = gd_rate(M(2), M(2).T1, M(2).n1, ref);
r3 = gd_rate(M(3), M(3).T1, M(3).n1, ref);
k_sp = r2.c_ga * M(2).g.b;
k_pr = r3.c_ga * M(3).g.b;
lev = [in.mission(:, 2); in.K_over];
Kg = zeros(size(lev));  Kl = Kg;  Km = Kg;
for j = 1:numel(lev)
    ls = gd_loadshare(M(2), M(3), lev(j) * M(2).Ts, k_sp, k_pr, gi);
    Kg(j) = ls.Kgam_p99;
    Ks = sort(ls.Kgam_all);
    Kl(j) = Ks(ceil(in.planet.Kgam_pct / 100 * numel(Ks)));
    Km(j) = ls.Kgam_mean;
end
T_prop = M(2).Ts * (1 + gi.s2.zr / gi.s2.zs);         % propeller torque at 100% [N m]
k08 = in.T_LD08_prop / T_prop;                        % LD-08 / MCT
ls08 = gd_loadshare(M(2), M(3), k08 * M(2).Ts, k_sp, k_pr, gi);
S.Kg = Kg;  S.Kl = Kl;  S.Km = Km;  S.Kg08 = ls08.Kgam_p99;  S.k08 = k08;  S.T_prop = T_prop;

g1 = M(1).g;
Ft = 2000 * gi.T_PT / g1.dw1;
Fr = Ft * tan(g1.alpha_wt);
Fa = Ft * tan(g1.beta);
S.F1 = [Ft Fr Fa];

% 2. Bearing loads in the three mission steps (columns) and the limit cases
t = in.mission(:, 1);
sh = in.mission(:, 2)';
L1 = in.span1;
R_gear = @(r) [hypot(Ft / 2, Fr / 2 + Fa * r / L1), hypot(Ft / 2, Fr / 2 - Fa * r / L1)];
Rin = R_gear(g1.dw1 / 2);                             % input shaft rollers A and B at 100%
Rmid = R_gear(g1.dw2 / 2);                            % intermediate shaft rollers
W = in.m_prop * in.g;
a = in.prop_overhang;  Lp = in.prop_span;
R_out = @(n, Mm) n * W * (1 + a / Lp) + Mm * 1e3 / Lp;
R_inn = @(n, Mm) n * W * a / Lp + Mm * 1e3 / Lp;
n_in = gi.n_PT;  n_mid = M(1).ns;  n_prop = M(1).nc;
cases = struct();
cases(1).Fr = max(Rin) * sh;  cases(1).Fa = 0 * sh;  cases(1).n = n_in;
cases(1).P0 = [in.K_over * max(Rin), k08 * max(Rin)];
cases(2).Fr = 0 * sh;  cases(2).Fa = (Fa + 278) * sh;  cases(2).n = n_in;     % + diaphragm coupling thrust (step 2.2)
cases(2).P0 = 0.58 * [in.K_over * Fa + 278, k08 * Fa];
cases(3).Fr = max(Rmid) * sh;  cases(3).Fa = 0 * sh;  cases(3).n = n_mid;
cases(3).P0 = [in.K_over * max(Rmid), k08 * max(Rmid)];
cases(4).Fr = 0 * sh;  cases(4).Fa = Fa * sh;  cases(4).n = n_mid;
cases(4).P0 = 0.58 * [in.K_over * Fa, k08 * Fa];
cases(5).Fr = R_inn(1, in.M_1P) * ones(size(sh));  cases(5).Fa = 0 * sh;  cases(5).n = n_prop;
cases(5).P0 = [R_inn(in.nz_gyro, in.M_gyro), NaN];          % LD-08 adds no load on these
cases(6).Fr = R_out(1, in.M_1P) * ones(size(sh));  cases(6).Fa = 0 * sh;  cases(6).n = n_prop;
cases(6).P0 = [R_out(in.nz_gyro, in.M_gyro), NaN];
cases(7).Fr = 0 * sh;  cases(7).Fa = in.thrust;  cases(7).n = n_prop;
cases(7).P0 = [0.58 * in.thrust_lim, NaN];
S.cases = cases;

% 3. Ratings and lives
nu = arrayfun(@(T) oil_nu(in.oil, T), in.T_brg);
S.nu = nu;
for k = 1:numel(in.brg)
    b = in.brg(k);
    r = sb_rating(b, in.b_m.(b.type));
    c = cases(k);
    Lk = sb_life(b, r, t, c.Fr, c.Fa, c.n, nu(1), in.e_C);
    Lh = sb_life(b, r, t, c.Fr, c.Fa, c.n, nu(2), in.e_C);
    B(k) = struct('name', b.name, 'type', b.type, 'd', b.d, 'D', b.D, 'B', b.B, 'Z', b.Z, 'Dw', b.Dw, ...
                  'Lwe', b.Lwe, 'Dpw', b.Dpw, 'C', r.C, 'C0', r.C0, 'Cu', r.Cu, 'n', c.n, ...
                  'DN', b.d * c.n * in.n_over, 'kappa', Lk.kappa, 'a_ISO', Lk.a_ISO(1), ...
                  'L10', Lk.L10_mission, 'L10m', Lk.L10m_mission, 'L10m_hot', Lh.L10m_mission, ...
                  's0_lim', r.C0 / c.P0(1), 's0_08', r.C0 / c.P0(2)); %#ok<AGROW>
end
S.B = B;
% Planet bearing: one row, full complement, in the planet bore of the gear design
pb = in.planet;
gsp = M(2).g;
rho = gi.rho_steel;
w_c = M(1).nc * pi / 30;
r_c = (gsp.d1 + gsp.d2) / 2 / 1000;                    % m
Dor = M(2).D_or;
Dpw = Dor - pb.Dw;
Z = floor(pi * Dpw / (pb.Dw * (1 + pb.pitch_gap)));
bj = struct('name', 'planet', 'type', 'CRB', 'd', Dpw - pb.Dw, 'D', Dor, 'B', gsp.b, 'Z', Z, 'Dw', pb.Dw, ...
            'Lwe', gsp.b - pb.L_ends, 'Dpw', Dpw, 'alpha', 0, 'i', 1);
r = sb_rating(bj, in.b_m.CRB);
m_gear = rho * pi / 4 * (((gsp.da1 + gsp.df1) / 2)^2 - Dor^2) * gsp.b;
m_roll = Z * rho * pi / 4 * pb.Dw^2 * bj.Lwe;
Fc = (m_gear + m_roll) * r_c * w_c^2;
Ftm = 2000 * M(2).T1 / gsp.dw1;
Fb = @(K) hypot(2 * Ftm * sh .* K(1:3)', Fc);
Lp1 = sb_life(bj, r, t, Fb(Kl), 0 * sh, M(2).n1, nu(1), in.e_C);
Lp2 = sb_life(bj, r, t, Fb(Kl), 0 * sh, M(2).n1, nu(2), in.e_C);
Lp99 = sb_life(bj, r, t, Fb(Kg), 0 * sh, M(2).n1, nu(1), in.e_C);
Lpm = sb_life(bj, r, t, Fb(Km), 0 * sh, M(2).n1, nu(1), in.e_C);
P0_01 = hypot(2 * Ftm * in.K_over * Kg(4), Fc * in.n_over^2);
P0_08 = hypot(2 * Ftm * k08 * S.Kg08, Fc);
P100 = Fb(Kl);
S.PB = struct('Z', Z, 'Dw', pb.Dw, 'Lwe', bj.Lwe, 'Dpw', Dpw, 'D_or', Dor, 'd_pin', bj.d, 'C', r.C, 'C0', r.C0, ...
              'Cu', r.Cu, 'n', M(2).n1, 'Fc', Fc, 'm', m_gear + m_roll, 'P100', P100(1), 'kappa', Lp1.kappa, ...
              'a_ISO', Lp1.a_ISO(1), 'L10', Lp1.L10_mission, 'L10m', Lp1.L10m_mission, ...
              'L10m_hot', Lp2.L10m_mission, 'L10m_p99', Lp99.L10m_mission, 'L10m_mean', Lpm.L10m_mission, ...
              's0_lim', r.C0 / P0_01, 's0_08', r.C0 / P0_08, 'DN', bj.d * M(2).n1 * in.n_over);

% 4. DYN-04: planet modes in three models
fm = M(2).n1 * gsp.z1 / 60;
sp = gi.speed_range;
S.dyn.fm = fm;
S.dyn.band = [sp(1) * fm * 0.9, sp(2) * fm * 1.1; 2 * sp(1) * fm * 0.9, 2 * sp(2) * fm * 1.1];
pr = struct('R', (gsp.df1 + Dor) / 4, 'h', (gsp.df1 - Dor) / 2, 'b', gsp.b, 'h_teeth', 0.5 * gsp.h1, ...
            'E', 206e3, 'rho', rho, 'Z', 0, 'Dw', pb.Dw, 'Lwe', bj.Lwe, 'F', P100(1), 'nel', 144, ...
            'k_mesh', 0, 'alpha', gsp.alpha_wt);
S.dyn.f(1, :) = sb_planet_rim(pr, 3);
pr.Z = Z;
S.dyn.f(2, :) = sb_planet_rim(pr, 3);
pr.k_mesh = r2.c_ga * gsp.b * 1e6;                    % N/m
S.dyn.f(3, :) = sb_planet_rim(pr, 3);
S.dyn.k_mesh = pr.k_mesh;
S.dyn.rim = pr.h;
% separation from the 1x and 2x mesh frequency ranges at 90-101% speed, as a share of the
% nearest range edge (negative = inside a range); DYN-04 asks for at least 10%
rng = S.dyn.band ./ [0.9 1.1];
S.dyn.margin = arrayfun(@(f) min(max((rng(:, 1) - f) ./ rng(:, 1), (f - rng(:, 2)) ./ rng(:, 2))), S.dyn.f);

% 5. Shafts: torque at MCT, LD-01 and LD-08 (step 2.3 dynamic values for 0.22 s)
T_in08 = 2158 * 0.2 / 0.22;                           % floating shaft = input shaft (step 2.3)
T_mid08 = 7580 * 0.2 / 0.22;                          % first-stage gear and sun quill (step 2.3)
spec = {gi.T_PT, 0, 278, T_in08, 0, 278; ...
        M(1).Ts, 0, Fa, T_mid08, 0, k08 * Fa; ...
        M(1).Ts, 0, 0, T_mid08, 0, 0; ...
        T_prop, in.M_1P + W * a / 1e3, in.thrust(1), in.T_LD08_prop, ...
        in.nz_gyro * W * a / 1e3 + in.M_gyro, in.thrust_lim};
for k = 1:numel(in.shafts)
    s = in.shafts(k);
    SH(k) = sb_shaft(s.d_o, s.d_i, spec{k, 1}, spec{k, 2}, spec{k, 3}, spec{k, 4}, spec{k, 5}, spec{k, 6}, in); %#ok<AGROW>
end
S.SH = SH;
S.T08 = [T_in08 T_mid08 T_mid08 in.T_LD08_prop];

% Quill splines
for k = 1:numel(in.spl)
    SP(k) = sb_spline(in.spl(k), M(1).Ts, gi.KA, T_mid08, in.shafts(3).d_i, in); %#ok<AGROW>
end
S.SP = SP;

% Propeller retention: axial catcher lip (thrust bearing failure) and internal retention tube
% (propeller shaft failure), both at ultimate load (1.5 x LD-04 negative thrust; the tube also
% carries the LD-05 moment)
c = in.ret.catcher;
F_ult = in.ult * in.thrust_lim;
S.ret.catcher_tau = F_ult / (pi * c.d_lip * c.h_lip);
S.ret.catcher_S = 0.577 * c.sy / S.ret.catcher_tau;
m_lip = F_ult / (pi * c.d_lip) * c.b / 2;             % N mm per mm of circumference, load at mid-width
S.ret.catcher_sigma = 6 * m_lip / c.h_lip^2;
S.ret.catcher_Sb = c.sy / S.ret.catcher_sigma;
tb = in.ret.tube;
A_t = pi / 4 * (tb.d_o^2 - tb.d_i^2);
W_t = pi / 32 * (tb.d_o^4 - tb.d_i^4) / tb.d_o;
M_ret = in.ult * (in.nz_gyro * W * a / 1e3 + in.M_gyro);
S.ret.tube_sigma = M_ret * 1e3 / W_t + F_ult / A_t;
S.ret.tube_Sy = tb.sy / (S.ret.tube_sigma / in.ult);
S.ret.tube_Su = tb.su / S.ret.tube_sigma;
S.ret.tube_mass = A_t * tb.L * tb.rho;

% 6. Mass of the planetary stage (sun, planets with rollers and pins, ring, carrier posts)
gi24 = gi;
gi24.s2.b = 60;  gi24.planet_rim = 3.75;
gi24.carrier.L_pin = 72;  gi24.carrier.L_post = 72;  gi24.carrier.post_t = 50;
S.mass = [stage_mass(gi24, pb), stage_mass(gi, pb)];

save(fullfile(out_dir, 'step25.mat'), 'S');
write_summary(S, out_dir);
write_csv(S, out_dir);
make_plots(S, out_dir);
end

function nu = oil_nu(oil, T)
% Walther line through the data sheet viscosities at 40 and 100 degC
A = log10(log10(oil.nu40 + 0.7) / log10(oil.nu100 + 0.7)) / log10(313 / 373);
Bc = log10(log10(oil.nu40 + 0.7)) - A * log10(313);
nu = 10^(10^(A * log10(T + 273) + Bc)) - 0.7;
end

function m = stage_mass(gi, pb)
% Steel mass of the planetary stage parts that change with the face width, rim and posts [kg]
M = gd_meshes(gi);
gsp = M(2).g;  gpr = M(3).g;
rho = gi.rho_steel;  b = gi.s2.b;  N = gi.s2.N;  c = gi.carrier;
Dor = M(2).D_or;
Dpw = Dor - pb.Dw;
Z = floor(pi * Dpw / (pb.Dw * (1 + pb.pitch_gap)));
m_sun = rho * pi / 4 * (((gsp.da2 + gsp.df2) / 2)^2 - gi.sun_bore^2) * b;
m_pl = rho * pi / 4 * (((gsp.da1 + gsp.df1) / 2)^2 - Dor^2) * b;
m_roll = Z * rho * pi / 4 * pb.Dw^2 * (b - pb.L_ends);
m_pin = rho * pi / 4 * ((Dpw - pb.Dw)^2 - 16^2) * c.L_pin;          % 16 mm oil bore
D_ring = gpr.df2 + 2 * gi.ring_rim * gi.s2.m;
m_ring = rho * pi / 4 * (D_ring^2 - ((gpr.da2 + gpr.df2) / 2)^2) * b;
m_post = N * c.post_w * c.post_t * c.L_post * rho;
m = struct('sun', m_sun, 'planets', N * (m_pl + m_roll + m_pin), 'ring', m_ring, 'posts', m_post);
m.total = m.sun + m.planets + m.ring + m.posts;
end

function write_summary(S, out_dir)
in = S.in;
fid = fopen(fullfile(out_dir, 'summary.txt'), 'w');
fprintf(fid, 'Step 2.5: bearings, shafts, splines, propeller retention\n\n');
fprintf(fid, 'Gear forces, first stage at MCT: Ft %.0f N, Fr %.0f N, Fa %.0f N; LD-08 = %.2f x MCT\n', S.F1, S.k08);
fprintf(fid, 'K_gamma at 100/50/30/137.5%% torque: P99 %s, P%d %s, mean %s; LD-08 P99 %.3f\n', ...
        mat2str(round(S.Kg', 3)), in.planet.Kgam_pct, mat2str(round(S.Kl', 3)), mat2str(round(S.Km', 3)), S.Kg08);
fprintf(fid, 'Oil viscosity at the bearings (%d / %d degC): %.2f / %.2f mm2/s\n\n', in.T_brg, S.nu);
fprintf(fid, '%-24s %5s %4s %4s %4s %9s %9s %8s %7s %6s %6s %10s %10s %10s %7s %7s\n', 'bearing', 'type', 'd', 'D', 'B', ...
        'C [kN]', 'C0 [kN]', 'Cu [kN]', 'n', 'kappa', 'a_ISO', 'L10 [h]', 'L10m [h]', 'L10m hot', 's0 lim', 's0 08');
for k = 1:numel(S.B)
    b = S.B(k);
    fprintf(fid, '%-24s %5s %4d %4d %4d %9.1f %9.1f %8.2f %7.0f %6.2f %6.2f %10.3g %10.3g %10.3g %7.2f %7.2f\n', ...
            b.name, b.type, b.d, b.D, b.B, b.C / 1e3, b.C0 / 1e3, b.Cu / 1e3, b.n, b.kappa, b.a_ISO, ...
            b.L10, b.L10m, b.L10m_hot, b.s0_lim, b.s0_08);
end
p = S.PB;
fprintf(fid, ['planet (one row, full complement): bore %.1f mm, pin %.1f mm, Z %d, Dw %.1f, Lwe %.0f mm, n %.0f rpm, DN %.3g\n' ...
              '  C %.1f kN, C0 %.1f kN, Cu %.2f kN; Fc %.0f N, P100 %.0f N (P%d); kappa %.2f, a_ISO %.2f\n' ...
              '  L10 %.3g h, L10m %.3g h (P%d K_gamma; hot %.3g h; P99 %.3g h; mean %.3g h); s0 %.2f (LD-01) / %.2f (LD-08)\n'], ...
        p.D_or, p.d_pin, p.Z, p.Dw, p.Lwe, p.n, p.DN, p.C / 1e3, p.C0 / 1e3, p.Cu / 1e3, p.Fc, p.P100, in.planet.Kgam_pct, ...
        p.kappa, p.a_ISO, p.L10, p.L10m, in.planet.Kgam_pct, p.L10m_hot, p.L10m_p99, p.L10m_mean, p.s0_lim, p.s0_08);
d = S.dyn;
fprintf(fid, '\nDYN-04 planet (rim %.1f mm): mesh %.0f Hz; bands 1x %.0f-%.0f, 2x %.0f-%.0f Hz (90-101%% speed, +-10%%)\n', ...
        d.rim, d.fm, d.band(1, :), d.band(2, :));
nm = {'free ring', 'on the loaded rollers', 'rollers + mesh springs'};
for j = 1:3
    fprintf(fid, '  %-24s %s Hz, margins %s\n', nm{j}, mat2str(round(d.f(j, :))), mat2str(round(100 * d.margin(j, :))));
end
fprintf(fid, '\nShafts (Goodman n_f, yield and rupture at LD-08 + LD-05):\n');
for k = 1:numel(S.SH)
    s = S.SH(k);
    fprintf(fid, '  %-18s %3d/%3d mm: sigma_a %.1f, sigma_m %.1f, S_e %.0f MPa, n_f %.2f; tau_lim %.0f MPa, sigma_lim %.0f MPa, n_y %.2f, n_u %.2f\n', ...
            in.shafts(k).name, s.d_o, s.d_i, s.sigma_a, s.sigma_m, s.S_e, s.n_f, s.tau_lim, s.sigma_lim, s.n_y, s.n_u);
end
fprintf(fid, '\nQuill splines:\n');
for k = 1:numel(S.SP)
    p = S.SP(k);
    fprintf(fid, '  %-38s D %.1f mm, L %d mm: tau %.1f MPa (S %.2f), p %.1f MPa (%.2f of %d), root tau %.1f MPa; LD-08 tau %.0f MPa (S %.2f), p %.0f MPa\n', ...
            in.spl(k).name, p.D, in.spl(k).L, p.tau, p.S_fat, p.p, p.p_ratio, p.p_allow, p.tau_root, p.tau_lim, p.S_static, p.p_lim);
end
fprintf(fid, ['\nPropeller retention at ultimate load: catcher lip shear %.1f MPa (S %.1f), bending %.0f MPa (S %.1f);\n' ...
              '  retention tube %d/%d mm Ti-6Al-4V: sigma %.0f MPa, S_y %.2f, S_u %.2f, mass %.2f kg\n'], ...
        S.ret.catcher_tau, S.ret.catcher_S, S.ret.catcher_sigma, S.ret.catcher_Sb, in.ret.tube.d_o, in.ret.tube.d_i, ...
        S.ret.tube_sigma, S.ret.tube_Sy, S.ret.tube_Su, S.ret.tube_mass);
m = S.mass;
fprintf(fid, '\nPlanetary stage mass, step 2.4 -> 2.5 [kg]: sun %.2f -> %.2f, planets %.2f -> %.2f, ring %.2f -> %.2f, posts %.2f -> %.2f; total %.2f -> %.2f (%+.2f)\n', ...
        m(1).sun, m(2).sun, m(1).planets, m(2).planets, m(1).ring, m(2).ring, m(1).posts, m(2).posts, ...
        m(1).total, m(2).total, m(2).total - m(1).total);
fclose(fid);
type(fullfile(out_dir, 'summary.txt'));
end

function write_csv(S, out_dir)
fid = fopen(fullfile(out_dir, 'bearings.csv'), 'w');
fprintf(fid, 'bearing,type,d,D,B,Z,Dw,Lwe,Dpw,C_kN,C0_kN,Cu_kN,n_rpm,kappa,a_ISO,L10_h,L10m_h,L10m_hot_h,s0_lim,s0_LD08\n');
for k = 1:numel(S.B)
    b = S.B(k);
    fprintf(fid, '%s,%s,%g,%g,%g,%d,%g,%g,%g,%.2f,%.2f,%.3f,%.0f,%.3f,%.3f,%.0f,%.0f,%.0f,%.2f,%.2f\n', b.name, b.type, ...
            b.d, b.D, b.B, b.Z, b.Dw, b.Lwe, b.Dpw, b.C / 1e3, b.C0 / 1e3, b.Cu / 1e3, b.n, b.kappa, b.a_ISO, ...
            b.L10, b.L10m, b.L10m_hot, b.s0_lim, b.s0_08);
end
p = S.PB;
fprintf(fid, 'planet,CRB,%.1f,%.1f,%g,%d,%g,%g,%g,%.2f,%.2f,%.3f,%.0f,%.3f,%.3f,%.0f,%.0f,%.0f,%.2f,%.2f\n', ...
        p.d_pin, p.D_or, p.Lwe + S.in.planet.L_ends, p.Z, p.Dw, p.Lwe, p.Dpw, p.C / 1e3, p.C0 / 1e3, p.Cu / 1e3, ...
        p.n, p.kappa, p.a_ISO, p.L10, p.L10m, p.L10m_hot, p.s0_lim, p.s0_08);
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
    bn = {'giriş, makaralı', 'giriş, QJ', 'ara mil, makaralı', 'ara mil, QJ', 'pervane iç, makaralı', ...
          'pervane dış, makaralı', 'pervane, QJ', 'planet'};
    L = struct('L10', 'Değiştirilmiş anma ömrü L_{10m} (saat)', 's0', 'Statik güvenlik s_0', ...
               'req', 'STR-02: 12.000 saat', 'cold', 'yatakta 110 °C (tasarım)', 'hot', 'yatakta 142 °C', ...
               's0l', 'sınır yük (LD-01, LD-03…05)', 's08', 'ani durma (LD-08)', 's0r', 's_0 = 2 (sınır)', ...
               's0f', 's_0 = 1 (LD-08)', 'bt', 'Rulmanlar: ISO 281 ömrü (görev spektrumu) ve statik güvenlik', ...
               'kb', 'Yük paylaşımının esası', 'kt', 'Planet rulmanı ömrü (K_γ esasına göre)', ...
               'kn', {{'ortalama', sprintf('P%d (tasarım)', in.planet.Kgam_pct), 'P99'}}, ...
               'fr', 'Doğal frekans (Hz)', 'mt', 'DYN-04: planet modları, üç model', ...
               'mn', {{'serbest halka', 'yüklü makaralar', 'makaralar + kavramalar'}}, ...
               'b1', '1× bandı', 'b2', '2× bandı', ...
               'st', 'Miller, kamalı bağlantılar ve pervane tutuşu: güvenlik katsayıları', ...
               'sn', {{'giriş mili', 'ara mil', 'güneş ara mili', 'pervane mili', 'kamalı, sabit', 'kamalı, bombeli', ...
                       'tutma borusu', 'yakalama tırnağı'}}, ...
               'sl', {{'yorulma (n_f, S_{fat})', 'akma, sınır yük (n_y, S_{st})', 'kopma, nihai yük (n_u)', ...
                       'yüzey basıncı (izin / p)'}}, 'one', 'alt sınır 1,0', 'nf', 'n_f alt sınırı 1,5');
else
    bn = {'input, roller', 'input, QJ', 'intermediate, roller', 'intermediate, QJ', 'propeller inner, roller', ...
          'propeller outer, roller', 'propeller, QJ', 'planet'};
    L = struct('L10', 'Modified rating life L_{10m} (h)', 's0', 'Static safety s_0', ...
               'req', 'STR-02: 12,000 h', 'cold', '110 °C at the bearing (design)', 'hot', '142 °C at the bearing', ...
               's0l', 'limit load (LD-01, LD-03…05)', 's08', 'sudden stoppage (LD-08)', 's0r', 's_0 = 2 (limit)', ...
               's0f', 's_0 = 1 (LD-08)', 'bt', 'Bearings: ISO 281 life over the mission and static safety', ...
               'kb', 'Load sharing basis', 'kt', 'Planet bearing life by the K_γ basis', ...
               'kn', {{'mean', sprintf('P%d (design)', in.planet.Kgam_pct), 'P99'}}, ...
               'fr', 'Natural frequency (Hz)', 'mt', 'DYN-04: planet modes in three models', ...
               'mn', {{'free ring', 'loaded rollers', 'rollers + meshes'}}, ...
               'b1', '1× band', 'b2', '2× band', ...
               'st', 'Shafts, splines and propeller retention: safety factors', ...
               'sn', {{'input shaft', 'intermediate shaft', 'sun quill', 'propeller shaft', 'spline, fixed', ...
                       'spline, crowned', 'retention tube', 'catcher lip'}}, ...
               'sl', {{'fatigue (n_f, S_{fat})', 'yield at limit (n_y, S_{st})', 'rupture at ultimate (n_u)', ...
                       'flank pressure (allowable / p)'}}, 'one', 'minimum 1.0', 'nf', 'n_f minimum 1.5');
end
blue = [0.12 0.44 0.70];  red = [0.75 0.22 0.17];  grey = [0.45 0.45 0.45];  gold = [0.85 0.60 0.10];
lblue = [0.55 0.75 0.90];

% 1. Bearings: life and static safety
B = S.B;  p = S.PB;
Lc = [[B.L10m], p.L10m];  Lh = [[B.L10m_hot], p.L10m_hot];
s1 = [[B.s0_lim], p.s0_lim];  s8 = [[B.s0_08], p.s0_08];
fig = figure('Visible', 'off', 'Position', [100 100 1050 440]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact');
nexttile;
y = 1:numel(Lc);
barh(y, Lc, 0.6, 'FaceColor', blue);  hold on
plot(Lh, y, 'v', 'Color', red, 'MarkerFaceColor', red);
xline(in.L10_req, '--', 'Color', grey, 'LineWidth', 1.2);
set(gca, 'XScale', 'log', 'YTick', y, 'YTickLabel', bn, 'YDir', 'reverse');
xlim([1e3 1e8]);  grid on;  xlabel(L.L10);
legend({L.cold, L.hot, L.req}, 'Location', 'southeast', 'FontSize', 8);
nexttile;
bh = barh(y, [s1; s8]', 0.8, 'grouped');
bh(1).FaceColor = blue;  bh(2).FaceColor = gold;  hold on
xline(2, '--', 'Color', grey, 'LineWidth', 1.2);
xline(1, ':', 'Color', grey, 'LineWidth', 1.2);
set(gca, 'XScale', 'log', 'YTick', y, 'YTickLabel', {}, 'YDir', 'reverse');
xlim([0.5 1000]);  grid on;  xlabel(L.s0);
legend({L.s0l, L.s08, L.s0r, L.s0f}, 'Location', 'northeast', 'FontSize', 8);
title(tl, L.bt, 'FontSize', 10);
exportgraphics(fig, fullfile(out_dir, ['bearings_' lang '.png']), 'Resolution', 150);
close(fig);

% 2. Planet bearing basis and DYN-04 planet modes
d = S.dyn;
fig = figure('Visible', 'off', 'Position', [100 100 1050 430]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact');
nexttile;
Lk = [p.L10m_mean, p.L10m, p.L10m_p99];
b = bar(Lk, 0.55, 'FaceColor', blue);  hold on
yline(in.L10_req, '--', L.req, 'Color', grey, 'LabelHorizontalAlignment', 'left');
text(b.XEndPoints, b.YEndPoints, compose('%.0f', Lk), 'HorizontalAlignment', 'center', ...
     'VerticalAlignment', 'bottom', 'FontSize', 8);
set(gca, 'XTickLabel', L.kn);  ylim([0 1.2 * max(Lk)]);  grid on
xlabel(L.kb);  ylabel(L.L10);  title(L.kt, 'FontWeight', 'normal');
nexttile;  hold on
bandc = [0.96 0.84 0.43];
patch([0.5 3.5 3.5 0.5], d.band(1, [1 1 2 2]), bandc, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
patch([0.5 3.5 3.5 0.5], d.band(2, [1 1 2 2]), bandc, 'EdgeColor', 'none', 'FaceAlpha', 0.35);
for j = 1:3
    plot(j * ones(1, 3), d.f(j, :), 'o', 'Color', red, 'MarkerFaceColor', red);
    for q = 1:3
        text(j + 0.08, d.f(j, q), sprintf('%.0f', d.f(j, q)), 'FontSize', 7);
    end
end
text(0.55, d.band(1, 2) * 1.04, L.b1, 'FontSize', 7);
text(0.55, d.band(2, 2) * 1.04, L.b2, 'FontSize', 7);
set(gca, 'YScale', 'log', 'XTick', 1:3, 'XTickLabel', L.mn);
xlim([0.5 3.5]);  ylim([1500 2e4]);  grid on;  box on
ylabel(L.fr);  title(L.mt, 'FontWeight', 'normal');
exportgraphics(fig, fullfile(out_dir, ['planet_' lang '.png']), 'Resolution', 150);
close(fig);

% 3. Shafts, splines and retention
SH = S.SH;  SP = S.SP;
Y = [[SH.n_f]', [SH.n_y]', [SH.n_u]', NaN(4, 1);
     [SP.S_fat]', [SP.S_static]', NaN(2, 1), 1 ./ [SP.p_ratio]';
     NaN, NaN, S.ret.tube_Su, NaN;
     NaN, S.ret.catcher_Sb, NaN, NaN];
fig = figure('Visible', 'off', 'Position', [100 100 1050 430]);
b = bar(Y, 'grouped');
b(1).FaceColor = blue;  b(2).FaceColor = lblue;  b(3).FaceColor = gold;  b(4).FaceColor = [0.95 0.80 0.50];
hold on
h1 = yline(1, '--', 'Color', grey, 'LineWidth', 1.2);
h2 = yline(in.nf_min, ':', 'Color', grey, 'LineWidth', 1.2);
set(gca, 'XTick', 1:size(Y, 1), 'XTickLabel', L.sn, 'XTickLabelRotation', 20, 'YScale', 'log');
ylim([0.5 30]);  grid on
legend([b h1 h2], [L.sl, {L.one, L.nf}], 'Location', 'northoutside', 'NumColumns', 3, 'FontSize', 8);
title(L.st, 'FontWeight', 'normal', 'FontSize', 10);
exportgraphics(fig, fullfile(out_dir, ['shafts_' lang '.png']), 'Resolution', 150);
close(fig);
end
