function S = run_step24(out_dir, mode)
%RUN_STEP24  Step 2.4: detail rating of the RGB gears (ISO 6336 Methods B and C).
%   S = run_step24()                  full run, results in calc/results/step24
%   S = run_step24(out_dir)           results in out_dir
%   S = run_step24(out_dir, 'plots')  redraw the plots from step24.mat
%
%   Runs from the repo root (calc/gear_detail on the path). Steps:
%    1. the three meshes with their geometry and Method B root factors
%    2. planet load sharing K_gamma (Monte Carlo, floating sun) at 100% and
%       50% torque; the 99th percentile at 100% is the design value
%    3. STR-01 rating at maximum continuous torque, K_A 1.25, 1e10 cycles
%    4. LD-01 (20 s) and LD-02 (15 min) at 137.5% torque as limited life;
%       LD-08 sudden stoppage: static capacity and shortest stopping time
%    5. life over the mission spectrum (Palmgren-Miner, ISO 6336-6 form)
%    6. flank modifications: tip relief, helix correction, crowning
%    7. scuffing and film thickness: both oils, three oil temperatures
%    8. DYN-04: ring, planet rim and first-stage gear web modes
%    9. SYS-07 idler variant of the first stage
%   Writes summary.txt, two CSV files, plots in English and Turkish and
%   step24.mat to out_dir (calc/results is not committed).
%
%   Source: Phase 2 report, Section 2.4.

if nargin < 1 || isempty(out_dir)
    out_dir = fullfile('calc', 'results', 'step24');
end
if nargin < 2, mode = 'full'; end
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
if strcmp(mode, 'plots')
    L = load(fullfile(out_dir, 'step24.mat'));
    make_plots(L.S, out_dir);
    S = L.S;
    return
end

in = gd_inputs();
% Helix correction torque: the share of MCT that gives the best lowest margin over MCT and the mission
fr = 0.5:0.05:1.0;
for j = 1:numel(fr)
    Ej(j) = evaluate(setfield(in, 'corr_frac', fr(j))); %#ok<AGROW>
end
[~, jb] = max([Ej.score]);
in.corr_frac = fr(jb);
S.corr_scan = struct('frac', fr, 'score', [Ej.score], 'SH', reshape([Ej.SHmin], 1, []), ...
                     'SF', reshape([Ej.SFmin], 1, []), 'SHs', [Ej.SHs], 'SFs', [Ej.SFs]);
% Design options for the planetary stage (Section 2.4, decision card)
var = struct('name', {'A superfinish', 'B compliant pins', 'C face +6 mm', 'ground flanks'}, 'in', []);
var(1).in = in;
var(2).in = in;  var(2).in.ls.k_brg = 0.5e9;  var(2).in.ls.k_pin = 1e12;
var(3).in = in;  var(3).in.s2.b = in.s2.b + 6;
var(3).in.carrier.L_pin = in.carrier.L_pin + 6;  var(3).in.carrier.L_post = in.carrier.L_post + 6;
var(4).in = in;  var(4).in.Rz_flank = in.Rz_ground;  var(4).in.Rz_flank_ring = 3.0;
for j = 1:numel(var)
    best = -Inf;
    for f = fr
        e = evaluate(setfield(var(j).in, 'corr_frac', f));
        if e.score > best, best = e.score;  var(j).E = e;  var(j).frac = f; end
    end
end
S.var = rmfield(var, 'in');
S.in = in;
M = gd_meshes(in);
oil = in.oil(1);
ref = struct('KA', in.KA, 'mode', 'ref', 'oil', oil, 'ZNT10', in.ZNT_ref, 'fpb_share', in.fpb_share);

% 2. Load sharing
r0 = arrayfun(@(k) gd_rate(setfield(M(k), 'Kgam', 1), M(k).T1, M(k).n1, ref), 2:3);
k_sp = r0(1).c_ga * M(2).g.b;
k_pr = r0(2).c_ga * M(3).g.b;
ls100 = gd_loadshare(M(2), M(3), M(2).Ts, k_sp, k_pr, in);
ls50 = gd_loadshare(M(2), M(3), 0.5 * M(2).Ts, k_sp, k_pr, in);
Kg = ls100.Kgam_p99;
M(2).Kgam = Kg;
M(3).Kgam = Kg;
S.ls100 = rmfield(ls100, 'Kgam_all');
S.ls50 = rmfield(ls50, 'Kgam_all');
S.Kgam_hist = ls100.Kgam_all;
kb_list = [0.25 0.5 1 2.5 5] * 1e9;
S.kb_list = kb_list;
S.kb_p99 = zeros(size(kb_list));
for j = 1:numel(kb_list)
    in2 = in;  in2.ls.k_brg = kb_list(j);  in2.ls.n_mc = 5000;
    a = gd_loadshare(M(2), M(3), M(2).Ts, k_sp, k_pr, in2);
    S.kb_p99(j) = a.Kgam_p99;
end

% 3. STR-01 rating at maximum continuous torque
for k = 1:3
    R(k) = gd_rate(M(k), M(k).T1, M(k).n1, ref); %#ok<AGROW>
end
S.M = M;
S.R = R;

% Ground flanks for comparison (the superfinish decision)
inG = in;  inG.Rz_flank = in.Rz_ground;  inG.Rz_flank_ring = 3.0;
MG = gd_meshes(inG);
for k = 1:3
    MG(k).Kgam = M(k).Kgam;
    RG(k) = gd_rate(MG(k), MG(k).T1, MG(k).n1, ref); %#ok<AGROW>
end
S.RG = RG;

% 4. Over-torque and sudden stoppage
for k = 1:3
    m = M(k);
    rate = [m.n1, m.n1 * m.cyc2] / 60;           % flank load cycles per second, gear 1 and 2
    o = struct('KA', 1.0, 'mode', 'cycles', 'oil', oil, 'ZNT10', in.ZNT_ref, 'fpb_share', in.fpb_share);
    o.NL = max(rate * 20, 1);
    R01(k) = gd_rate(m, in.K_over * m.T1, m.n1, o); %#ok<AGROW>
    o.NL = rate * in.t_LD02;
    R02(k) = gd_rate(m, in.K_over * m.T1, m.n1, o); %#ok<AGROW>
end
S.R01 = R01;
S.R02 = R02;
% LD-08: propeller (carrier) torque at which the lowest static safety is 1.0
u1 = in.s1.z2 / in.s1.z1;
Tc100 = M(2).Ts * (1 + in.s2.zr / in.s2.zs);
st = struct('KA', 1.0, 'mode', 'static', 'oil', oil, 'ZNT10', in.ZNT_ref, 'fpb_share', in.fpb_share);
smin = @(Tc) static_min(M, Tc / Tc100, st, in, k_sp, k_pr);
T_cap = fzero(@(Tc) smin(Tc) - 1, [Tc100, 20 * Tc100]);
[~, Rcap, Kg_cap] = smin(T_cap);
S.T_cap = T_cap;
S.Rcap = Rcap;
S.Kg_cap = Kg_cap;
cfit = in.T_stop_prop * 0.2;                     % peak x stopping time from step 2.3 [N m s]
S.t_min_cap = cfit / T_cap;
S.T_stop_list = cfit ./ in.t_stop_list;
S.Tc100 = Tc100;

% 5. Mission spectrum life (Miner); K factors and K_gamma at each torque level
lev = in.mission;
S.life = spectrum_life(M, lev, in, oil, k_sp, k_pr);

% 6. Flank modifications at maximum continuous torque
for k = 1:3
    g = M(k).g;
    fm(k).Ca = R(k).Ca; %#ok<AGROW>
    if g.eps_beta >= 1.2
        Lroll = (g.g_alpha - g.p_et) / 2;
    else
        Lroll = g.g_alpha - g.p_et;
    end
    fm(k).L_roll = Lroll;                            % relief length on the path of contact [mm]
    fm(k).d_Ca1 = 2 * sqrt((g.db1 / 2)^2 + (g.rho1E - Lroll)^2);   % pinion: relief starts at this diameter
    r2s = g.rho2(g.rho1A + Lroll);
    fm(k).d_Ca2 = 2 * sqrt((g.db2 / 2)^2 + r2s^2);
    fm(k).f_corr = 0.9 * R(k).fsh;                   % helix slope correction over b [um]
    fm(k).C_beta = 0.5 * M(k).f_ma;                  % central crowning [um]
    fm(k).KHb = R(k).KHb;
end
S.fm = fm;

% 7. Scuffing and film thickness
Xmp = [1, 2, 2];
To = in.T_oil;
cases = struct('name', {'MCT 100C', 'MCT 132C', 'LD-02 149C', 'MCT 100C', 'MCT 132C'}, ...
               'oil', {1, 1, 1, 2, 2}, 'T', {To(1), To(2), To(3), To(1), To(2)}, 'load', {1, 1, in.K_over, 1, 1}, ...
               'KA', {in.KA, in.KA, 1.0, in.KA, in.KA});
for c = 1:numel(cases)
    for k = 1:3
        o = ref;  o.KA = cases(c).KA;  o.oil = in.oil(cases(c).oil);
        rr = gd_rate(M(k), cases(c).load * M(k).T1, M(k).n1, o);
        sc(c, k) = gd_scuffing(M(k), rr, M(k).n1, in.oil(cases(c).oil), cases(c).T, Xmp(k), in); %#ok<AGROW>
    end
end
S.sc_cases = cases;
S.sc = sc;
for k = 1:3                                          % ground flanks, MIL-PRF-23699 at 132 C
    o = ref;
    rr = gd_rate(MG(k), MG(k).T1, MG(k).n1, o);
    scG(k) = gd_scuffing(MG(k), rr, MG(k).n1, oil, 132, Xmp(k), in); %#ok<AGROW>
end
S.scG = scG;

% 8. DYN-04
S.dyn = dyn04(M, in);

% 9. SYS-07 idler variant
S.idler = idler_variant(in, M(1));

save(fullfile(out_dir, 'step24.mat'), 'S');
write_summary(S, out_dir);
write_csv(S, out_dir);
make_plots(S, out_dir);
end

function write_csv(S, out_dir)
% ratings.csv: one row per gear flank and load case; scuffing.csv: one row per mesh and case
gear = {'pinion', 'gear 2'; 'planet (sun mesh)', 'sun'; 'planet (ring mesh)', 'ring'};
cs = {'MCT', S.R; 'LD-01 20 s', S.R01; 'LD-02 15 min', S.R02; 'MCT ground flanks', S.RG};
fid = fopen(fullfile(out_dir, 'ratings.csv'), 'w');
fprintf(fid, 'case,mesh,gear,sigma_H_MPa,S_H,sigma_F_MPa,S_F,K_v,K_Hbeta,K_Halpha,K_gamma\n');
for c = 1:size(cs, 1)
    R = cs{c, 2};
    for k = 1:3
        for i = 1:2
            fprintf(fid, '%s,%s,%s,%.1f,%.4f,%.1f,%.4f,%.4f,%.4f,%.4f,%.4f\n', cs{c, 1}, S.M(k).name, gear{k, i}, ...
                    R(k).(sprintf('sigma_H%d', i)), R(k).(sprintf('S_H%d', i)), R(k).(sprintf('sigma_F%d', i)), ...
                    R(k).(sprintf('S_F%d', i)), R(k).Kv, R(k).KHb, R(k).KHa, S.M(k).Kgam);
        end
    end
end
fclose(fid);
fid = fopen(fullfile(out_dir, 'scuffing.csv'), 'w');
fprintf(fid, 'oil,case,mesh,mu,theta_fl_max_C,theta_M_C,theta_B_max_C,theta_S_C,S_S,lambda_C,lambda_min\n');
for c = 1:numel(S.sc_cases)
    for k = 1:3
        a = S.sc(c, k);
        fprintf(fid, '%s,%s,%s,%.4f,%.1f,%.1f,%.1f,%.0f,%.3f,%.3f,%.3f\n', S.in.oil(S.sc_cases(c).oil).name, ...
                S.sc_cases(c).name, S.M(k).name, a.mu, max(a.theta_fl), a.theta_M, a.theta_Bmax, a.theta_S, ...
                a.S_S, a.lambdaC, a.lambda_min);
    end
end
fclose(fid);
end

function E = evaluate(in)
% Lowest safeties of the three meshes at MCT and over the mission, for one set of inputs
M = gd_meshes(in);
oil = in.oil(1);
ref = struct('KA', in.KA, 'mode', 'ref', 'oil', oil, 'ZNT10', in.ZNT_ref, 'fpb_share', in.fpb_share);
r0 = arrayfun(@(k) gd_rate(setfield(M(k), 'Kgam', 1), M(k).T1, M(k).n1, ref), 2:3);
k_sp = r0(1).c_ga * M(2).g.b;
k_pr = r0(2).c_ga * M(3).g.b;
ls = gd_loadshare(M(2), M(3), M(2).Ts, k_sp, k_pr, setfield(in, 'ls', setfield(in.ls, 'n_mc', 4000)));
M(2).Kgam = ls.Kgam_p99;
M(3).Kgam = ls.Kgam_p99;
for k = 1:3
    R(k) = gd_rate(M(k), M(k).T1, M(k).n1, ref); %#ok<AGROW>
end
L = spectrum_life(M, in.mission, in, oil, k_sp, k_pr);
E.Kg = ls.Kgam_p99;
E.SHmin = [R.S_H];
E.SFmin = [R.S_F];
E.SHs = min([L.SH_spec]);
E.SFs = min([L.SF_spec]);
E.SH_spec = reshape([L.SH_spec], 2, []);
E.SF_spec = reshape([L.SF_spec], 2, []);
E.score = min([E.SHmin / in.SH_min, E.SFmin / in.SF_min, E.SHs / in.SH_min, E.SFs / in.SF_min]);
end

function [s, R, Kg] = static_min(M, scale, st, in, k_sp, k_pr)
% Lowest static safety of all gears when every torque is scaled by 'scale'
ls = gd_loadshare(M(2), M(3), scale * M(2).Ts, k_sp, k_pr, setfield(in, 'ls', setfield(in.ls, 'n_mc', 2000)));
Kg = ls.Kgam_p99;
for k = 1:3
    o = st;
    if k > 1, o.Kgam = Kg; else, o.Kgam = 1; end
    R(k) = gd_rate(M(k), scale * M(k).T1, M(k).n1, o); %#ok<AGROW>
end
s = min([R.S_H1, R.S_H2, R.S_F1, R.S_F2]);
end

function L = spectrum_life(M, lev, in, oil, k_sp, k_pr)
% Hours to D = 1 for pitting and root of every gear, and the stress safety for the design life
nl = size(lev, 1);
for k = 1:3
    m = M(k);
    rate = [m.n1, m.n1 * m.cyc2] * 60;               % flank cycles per hour, gear 1 and 2
    sH = zeros(nl, 2);  sF = zeros(nl, 2);
    for j = 1:nl
        o = struct('KA', in.KA, 'mode', 'ref', 'oil', oil, 'ZNT10', in.ZNT_ref, 'fpb_share', in.fpb_share, 'Kgam', m.Kgam);
        if k > 1
            ls = gd_loadshare(M(2), M(3), lev(j, 2) * M(2).Ts, k_sp, k_pr, setfield(in, 'ls', setfield(in.ls, 'n_mc', 4000)));
            o.Kgam = ls.Kgam_p99;
        end
        r = gd_rate(m, lev(j, 2) * m.T1, m.n1, o);
        sH(j, :) = [r.sigma_H1, r.sigma_H2];
        sF(j, :) = [r.sigma_F1, r.sigma_F2];
        HGs = r.HGs;  HGr = r.HGr;  FGs = r.FGs;  FGr = r.FGr;
    end
    types = {m.mat1.type, m.mat2.type};
    for i = 1:2
        dH = @(s) sum(lev(:, 1) * rate(i) ./ nn('H', types{i}, HGs(i), HGr(i), s * sH(:, i)));
        dF = @(s) sum(lev(:, 1) * rate(i) ./ nn('F', types{i}, FGs(i), FGr(i), s * sF(:, i)));
        L(k).life_H(i) = 1 / dH(1);                  %#ok<AGROW>  hours
        L(k).life_F(i) = 1 / dF(1);                  %#ok<AGROW>
        L(k).SH_spec(i) = fzero(@(s) log(dH(s) * in.life_h), [0.3 5]);   %#ok<AGROW>
        L(k).SF_spec(i) = fzero(@(s) log(dF(s) * in.life_h), [0.3 10]);  %#ok<AGROW>
        L(k).cycles(i) = rate(i) * in.life_h;        %#ok<AGROW>
    end
    L(k).name = m.name;
end

    function N = nn(kind, type, Gs, Gr, s)
        [~, N] = gd_sn(kind, type, Gs, Gr, in.ZNT_ref, [], s);
    end
end

function d = dyn04(M, in)
% Gear rim and web modes against the mesh frequency bands (1x and 2x, 90-101% speed, 10% margin)
E = in.mat.Eh.E;  rho = in.rho_steel;
fm2 = M(2).n1 * M(2).g.z1 / 60;                     % planetary mesh frequency at 100%
fm1 = in.n_PT * in.s1.z1 / 60;
sp = in.speed_range;
band = @(fm, h) [h * sp(1) * fm * 0.9, h * sp(2) * fm * 1.1];
% ring (free thin ring), mesh phasing selection rule (l z_r +- n) mod N = 0
g3 = M(3).g;
sR = in.ring_rim * in.s2.m;
pr = struct('R', g3.df2 / 2 + sR / 2, 'h', sR, 'b', in.s2.b, 'h_teeth', 0.5 * g3.h2, 'E', E, 'rho', rho);
n_r = 2:12;
d.ring.n = n_r;
d.ring.f = gd_modes('ring', pr, n_r)';
for l = 1:2
    d.ring.excited(l, :) = mod(l * in.s2.zr - n_r, in.s2.N) == 0 | mod(l * in.s2.zr + n_r, in.s2.N) == 0;
end
% planet rim (free thin ring between the bore and the root)
g2 = M(2).g;
h = (g2.df1 - M(2).D_or) / 2;
pp = struct('R', (g2.df1 + M(2).D_or) / 4, 'h', h, 'b', in.s2.b, 'h_teeth', 0.5 * g2.h1, 'E', E, 'rho', rho);
d.planet.n = 2:4;
d.planet.f = gd_modes('ring', pp, 2:4)';
d.planet.rim = h;
% first-stage gear web with its rim; rotating frame: excitation at l fm +- n f_rot
g1 = M(1).g;
pw = struct('r_in', in.gear2_hub_d / 2, 'r_out', g1.df2 / 2 - in.gear2_rim * in.s1.mn, 't', in.gear2_web, ...
            'b_rim', in.s1.b, 's_rim', in.gear2_rim * in.s1.mn, 's_mass', in.gear2_rim * in.s1.mn + 0.5 * g1.h2, ...
            'E', E, 'nu', 0.3, 'rho', rho, 'ne', 40);
d.web.n = 0:12;
fw = gd_modes('web', pw, d.web.n);
d.web.f = fw(:, 1)';
d.web.f2 = fw(:, 2)';
d.web.p = pw;
d.fm1 = fm1;  d.fm2 = fm2;
d.frot2 = in.n_PT / (in.s1.z2 / in.s1.z1) / 60;
d.band1 = [band(fm2, 1); band(fm2, 2)];
d.band_s1 = [band(fm1, 1); band(fm1, 2)];
% margins (positive = outside the band)
mrg = @(f, b) max((b(1) - f) / b(1), (f - b(2)) / b(2));
for l = 1:2
    d.ring.ok(l, :) = arrayfun(@(f) mrg(f, d.band1(l, :)) >= 0, d.ring.f) | ~d.ring.excited(l, :);
    d.planet.ok(l, :) = arrayfun(@(f) mrg(f, d.band1(l, :)) >= 0, d.planet.f);
    bshift = @(n) [d.band_s1(l, 1) - n * d.frot2, d.band_s1(l, 2) + n * d.frot2];
    d.web.ok(l, :) = arrayfun(@(j) mrg(d.web.f(j), bshift(d.web.n(j))) >= 0, 1:numel(d.web.n));
end
end

function I = idler_variant(in, M1)
% SYS-07: two load-sharing idlers between pinion and gear; same module, helix and face width
zi_list = 41:2:61;
s = in.s1;
for j = 1:numel(zi_list)
    zi = zi_list(j);
    gpi = gd_pair(s.z1, zi, s.mn, s.beta, s.b, s.x1, -s.x1, false, in.hob, in.hob, in.A_s1, in);
    gig = gd_pair(zi, s.z2, s.mn, s.beta, s.b, -s.x1, s.x2, false, in.hob, in.hob, in.A_s1, in);
    a1 = gpi.a_w;  a2 = gig.a_w;
    ra_i = gpi.da2 / 2;
    % idlers sit symmetrically about the pinion-gear line; their tips need 3 mm between them
    h_min = ra_i + 1.5;
    amax = a1 + a2;                                  % idealised; limited by the idler spacing below
    % offset where the idler centre is h_min from the line of centres
    lo = max(abs(a2 - a1), (gpi.da1 + gig.da2) / 2 + 3);   % pinion and gear tips 3 mm apart
    aa = linspace(lo, amax, 4000);
    hv = arrayfun(@(x) heron(a1, a2, x), aa);
    ok = aa(hv >= h_min);
    if isempty(ok)
        a12_min = NaN;  a12_max = NaN;
    else
        a12_min = min(ok);  a12_max = max(ok);
    end
    I.zi(j) = zi;
    I.a_pi(j) = a1;
    I.a_ig(j) = a2;
    I.offset_min(j) = a12_min;
    I.offset_max(j) = a12_max;
    % rating: half the torque per mesh with K_gamma 1.10, the idler tooth bends both ways
    Mi = M1;
    Mi.g = gpi;  Mi.Kgam = 1.10;  Mi.reversed2 = true;  Mi.cyc2 = s.z1 / zi;
    Mi.kv.mstar = Mi.kv.mstar(1) * [1, (zi / s.z1)^2];
    Mi.k_sh = 0.023 * (s.b / gpi.d1)^2;
    Mi.f_ma = sqrt(gpi.tol1.f_Hb^2 + gpi.tol2.f_Hb^2);
    r1 = gd_rate(Mi, in.T_PT / 2, in.n_PT, struct('KA', in.KA, 'mode', 'ref', 'oil', in.oil(1), 'ZNT10', in.ZNT_ref, 'fpb_share', in.fpb_share));
    Mg = M1;
    Mg.g = gig;  Mg.Kgam = 1.10;  Mg.reversed1 = true;  Mg.cyc2 = zi / s.z2;
    Mg.k_sh = 0.023 * (s.b / gig.d1)^2;
    Mg.f_ma = sqrt(gig.tol1.f_Hb^2 + gig.tol2.f_Hb^2);
    Mg.kv.mstar = M1.kv.mstar(1) * [(zi / s.z1)^2, M1.kv.mstar(2) / M1.kv.mstar(1)];
    Mg.sR1 = Inf;
    r2 = gd_rate(Mg, in.T_PT / 2 * zi / s.z1, in.n_PT * s.z1 / zi, struct('KA', in.KA, 'mode', 'ref', 'oil', in.oil(1), 'ZNT10', in.ZNT_ref, 'fpb_share', in.fpb_share));
    I.SH(j) = min([r1.S_H, r2.S_H]);
    I.SF(j) = min([r1.S_F, r2.S_F]);
    I.SF_idler(j) = min(r1.S_F2, r2.S_F1);
end
end

function h = heron(a, b, c)
% height of the triangle with sides a, b on the base c
s = (a + b + c) / 2;
A = sqrt(max(s * (s - a) * (s - b) * (s - c), 0));
h = 2 * A / c;
end

function write_summary(S, out_dir)
in = S.in;
M = S.M;  R = S.R;
fid = fopen(fullfile(out_dir, 'summary.txt'), 'w');
fprintf(fid, 'Step 2.4: RGB gear detail rating (ISO 6336 Methods B and C)\n\n');
fprintf(fid, 'Load sharing (floating sun, N = %d): K_gamma mean %.3f, P95 %.3f, P99 %.3f (design), worst alternating %.3f; 50%% torque P99 %.3f; sun float P99 %.1f um\n', ...
        in.s2.N, S.ls100.Kgam_mean, S.ls100.Kgam_p95, S.ls100.Kgam_p99, S.ls100.Kgam_wc, S.ls50.Kgam_p99, 1000 * S.ls100.float_p99);
fprintf(fid, '  path stiffness %.0f N/mm; error budget 2e_pin cos a %.1f, planet %.1f, ring ovality %.1f um\n\n', ...
        S.ls100.k_path, 1000 * S.ls100.e_budget);
names = {'pinion', 'gear 2'; 'planet', 'sun'; 'planet', 'ring'};
for k = 1:3
    g = M(k).g;  r = R(k);
    fprintf(fid, '%s: z %d/%d, x %.2f/%.2f, a_w %.3f mm, eps_alpha %.3f, eps_beta %.3f, SAP margins %.2f/%.2f mm, spec. sliding %.2f/%.2f\n', ...
            M(k).name, g.z1, g.z2, g.x1, g.x2, g.a_w, g.eps_alpha, g.eps_beta, g.sap1, g.sap2, g.zeta1A, g.zeta2E);
    fprintf(fid, '  Ft %.0f N, v %.2f m/s, c'' %.2f, c_ga %.2f, K_v %.3f (%s, N %s), K_Hb %.3f, K_Fb %.3f, K_Ha %.3f, K_gamma %.3f\n', ...
            r.Ft, r.v, r.c_prime, r.c_ga, r.Kv, r.kv.regime, mat2str(r.kv.N, 3), r.KHb, r.KFb, r.KHa, M(k).Kgam);
    fprintf(fid, '  pitting: sigma_H %.0f/%.0f MPa, Z_L %.3f Z_v %.3f Z_R %.3f, limit %.0f/%.0f, S_H %.3f (%s) / %.3f (%s); ground flanks S_H %.3f\n', ...
            r.sigma_H1, r.sigma_H2, r.ZL, r.Zv, r.ZR, r.sHG1, r.sHG2, r.S_H1, names{k, 1}, r.S_H2, names{k, 2}, S.RG(k).S_H);
    fprintf(fid, '  root: Y_F %.3f/%.3f, Y_S %.3f/%.3f, Y_beta %.3f, sigma_F %.0f/%.0f MPa, Y_M %.3f/%.3f, limit %.0f/%.0f, S_F %.3f / %.3f\n', ...
            r.Y_F1, r.Y_F2, r.Y_S1, r.Y_S2, r.Y_beta, r.sigma_F1, r.sigma_F2, r.YM1(2), r.YM2(2), r.sFG1, r.sFG2, r.S_F1, r.S_F2);
    fprintf(fid, '  LD-01 (20 s): S_H %.3f/%.3f S_F %.3f/%.3f;  LD-02 (15 min): S_H %.3f/%.3f S_F %.3f/%.3f\n', ...
            S.R01(k).S_H1, S.R01(k).S_H2, S.R01(k).S_F1, S.R01(k).S_F2, S.R02(k).S_H1, S.R02(k).S_H2, S.R02(k).S_F1, S.R02(k).S_F2);
    L = S.life(k);
    fprintf(fid, '  mission life: pitting %.3g/%.3g h, root %.3g/%.3g h; spectrum safety for %d h: S_H %.3f/%.3f, S_F %.3f/%.3f; cycles %.3g/%.3g\n', ...
            L.life_H, L.life_F, in.life_h, L.SH_spec, L.SF_spec, L.cycles);
    f = S.fm(k);
    fprintf(fid, '  modifications: tip relief %.1f um over %.2f mm of the path (from d %.2f / %.2f mm), helix correction %.1f um, crowning %.1f um\n\n', ...
            f.Ca, f.L_roll, f.d_Ca1, f.d_Ca2, f.f_corr, f.C_beta);
end
fprintf(fid, 'LD-08 sudden stoppage: static capacity %.0f N m at the propeller (%.2f x MCT), K_gamma %.3f; shortest stopping time %.2f s\n', ...
        S.T_cap, S.T_cap / S.Tc100, S.Kg_cap, S.t_min_cap);
fprintf(fid, '  lowest static safeties at the capacity: S_H %.3f, S_F %.3f\n\n', min([S.Rcap.S_H]), min([S.Rcap.S_F]));
fprintf(fid, 'Scuffing (flash temperature) and film thickness, superfinished flanks (target S_S >= %.1f):\n', in.SS_min);
for c = 1:numel(S.sc_cases)
    for k = 1:3
        s = S.sc(c, k);
        fprintf(fid, '  %-14s %-11s %-12s: mu %.4f, theta_fl max %.1f, theta_M %.1f, theta_B max %.1f, theta_S %.0f C, S_S %.2f; lambda C %.2f, min %.2f\n', ...
                in.oil(S.sc_cases(c).oil).name, S.sc_cases(c).name, M(k).name, s.mu, max(s.theta_fl), s.theta_M, s.theta_Bmax, s.theta_S, s.S_S, s.lambdaC, s.lambda_min);
    end
end
for k = 1:3
    s = S.scG(k);
    fprintf(fid, '  ground flanks, MIL-PRF-23699 132C %-12s: S_S %.2f, lambda C %.2f\n', M(k).name, s.S_S, s.lambdaC);
end
d = S.dyn;
fprintf(fid, '\nDYN-04: planetary mesh %.0f Hz, first stage %.0f Hz at 100%%\n', d.fm2, d.fm1);
fprintf(fid, '  ring (rim %.1f mm) n %s: %s Hz; excited by 1x: %s, 2x: %s; all clear: %d\n', in.ring_rim * in.s2.m, ...
        mat2str(d.ring.n), mat2str(round(d.ring.f)), mat2str(d.ring.n(d.ring.excited(1, :))), mat2str(d.ring.n(d.ring.excited(2, :))), all(d.ring.ok(:)));
fprintf(fid, '  planet rim %.2f mm: n 2-4 %s Hz, clear: %d\n', d.planet.rim, mat2str(round(d.planet.f)), all(d.planet.ok(:)));
fprintf(fid, '  first-stage gear web %.0f mm: n 0-12 %s Hz; inside the 1x band: n %s; 2x: n %s\n', in.gear2_web, ...
        mat2str(round(d.web.f)), mat2str(d.web.n(~d.web.ok(1, :))), mat2str(d.web.n(~d.web.ok(2, :))));
I = S.idler;
fprintf(fid, '\nSYS-07 idler variant (two idlers): z_i %s\n  offset range min %s\n  max %s mm\n  S_H %s\n  S_F %s\n', ...
        mat2str(I.zi), mat2str(round(I.offset_min, 1)), mat2str(round(I.offset_max, 1)), mat2str(round(I.SH, 3)), mat2str(round(I.SF, 3)));
fclose(fid);
type(fullfile(out_dir, 'summary.txt'));
end

function make_plots(S, out_dir)
for lang = {'en', 'tr'}
    plots(S, out_dir, lang{1});
end
end

function plots(S, out_dir, lang)
in = S.in;  R = S.R;
tr = strcmp(lang, 'tr');
if tr
    gn = {'pinyon', 'dişli 2', 'planet (güneş tarafı)', 'güneş', 'planet (halka tarafı)', 'halka'};
    L = struct('SH', 'Yüzey yorulması (pitting) güvenliği S_H', 'SF', 'Diş kökü güvenliği S_F', ...
               'req', 'STR-01 alt sınırı', 'grd', 'yalnız taşlanmış yüzey', 'sup', 'süperfinish (tasarım)', ...
               'st', 'Azami sürekli torkta STR-01 (ISO 6336 Yöntem B ve C, K_A 1,25, 10^{10} çevrim)', ...
               'px', 'Kavrama çizgisi üzerinde konum, A''dan E''ye (mm)', 'tB', 'Temas sıcaklığı θ_B (°C)', ...
               'lam', 'Yağ filmi oranı λ', 'thS', 'sıvanma sıcaklığı', ...
               'pt', 'Temas sıcaklığı ve yağ filmi (azami sürekli tork, yağ girişi 132 °C)', ...
               'kg', 'Yük paylaşım katsayısı K_γ', 'cnt', 'Dağılım (%)', 'kb', 'Planet yatağı radyal rijitliği (N/m)', ...
               'kgt', 'Planet yük paylaşımı (yüzer güneş, 4 planet, Monte Carlo)', 'p99', 'P99 (tasarım)', ...
               'fr', 'Doğal frekans (Hz)', 'ring', 'halka jantı', 'planet', 'planet jantı', ...
               'web', 'birinci kademe dişlisi gövdesi', ...
               'b1', 'kavrama frekansı bandı (1×, %90–101 hız, ±%10)', 'b2', '2× bandı', ...
               'exc', 'kavrama frekansıyla (1×) uyarılan mod', 'exc2', 'yalnız 2× ile uyarılan halka modu', ...
               'nexc', 'faz kuralıyla 1× ve 2× uyarmayan halka modu', ...
               'dt', 'DYN-04: dişli jantı ve gövde modları ile kavrama frekansları', ...
               'ot', 'Planet kademesi için tasarım seçenekleri (en düşük güvenlikler)');
    on = {'A süperfinish', 'B esnek pim', 'C +6 mm genişlik', 'taşlanmış yüzey'};
    mn = {'birinci kademe', 'güneş-planet', 'planet-halka'};
    lg5 = {'S_H azami sürekli tork', 'S_H görev boyu', 'S_F azami sürekli tork', 'S_F görev boyu'};
else
    gn = {'pinion', 'gear 2', 'planet (sun side)', 'sun', 'planet (ring side)', 'ring'};
    L = struct('SH', 'Pitting safety S_H', 'SF', 'Tooth root safety S_F', ...
               'req', 'STR-01 minimum', 'grd', 'ground flanks only', 'sup', 'superfinished (design)', ...
               'st', 'STR-01 at maximum continuous torque (ISO 6336 Methods B and C, K_A 1.25, 10^{10} cycles)', ...
               'px', 'Position on the path of contact, A to E (mm)', 'tB', 'Contact temperature θ_B (°C)', ...
               'lam', 'Film thickness ratio λ', 'thS', 'scuffing temperature', ...
               'pt', 'Contact temperature and oil film (maximum continuous torque, oil in at 132 °C)', ...
               'kg', 'Load sharing factor K_γ', 'cnt', 'Share (%)', 'kb', 'Planet bearing radial stiffness (N/m)', ...
               'kgt', 'Planet load sharing (floating sun, four planets, Monte Carlo)', 'p99', 'P99 (design)', ...
               'fr', 'Natural frequency (Hz)', 'ring', 'ring rim', 'planet', 'planet rim', ...
               'web', 'first-stage gear web', ...
               'b1', 'mesh frequency band (1×, 90–101% speed, ±10%)', 'b2', '2× band', ...
               'exc', 'mode excited by the mesh frequency (1×)', 'exc2', 'ring mode excited by 2× only', ...
               'nexc', 'ring mode excited by neither (phasing rule)', ...
               'dt', 'DYN-04: gear rim and web modes against the mesh frequencies', ...
               'ot', 'Design options for the planetary stage (lowest safeties)');
    on = {'A superfinish', 'B compliant pins', 'C face +6 mm', 'ground flanks'};
    mn = {'first stage', 'sun-planet', 'planet-ring'};
    lg5 = {'S_H at MCT', 'S_H over the mission', 'S_F at MCT', 'S_F over the mission'};
end
blue = [0.12 0.44 0.70];  red = [0.75 0.22 0.17];  grey = [0.45 0.45 0.45];  gold = [0.85 0.60 0.10];

% 1. Safety factors at MCT
SH = [R(1).S_H1 R(1).S_H2 R(2).S_H1 R(2).S_H2 R(3).S_H1 R(3).S_H2];
SF = [R(1).S_F1 R(1).S_F2 R(2).S_F1 R(2).S_F2 R(3).S_F1 R(3).S_F2];
SHg = [S.RG(1).S_H1 S.RG(1).S_H2 S.RG(2).S_H1 S.RG(2).S_H2 S.RG(3).S_H1 S.RG(3).S_H2];
fig = figure('Visible', 'off', 'Position', [100 100 1000 430]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact');
nexttile;
b = bar(SH, 0.6, 'FaceColor', blue);  hold on
plot(1:6, SHg, 'v', 'Color', red, 'MarkerFaceColor', red);
yline(in.SH_min, '--', L.req, 'Color', grey, 'LabelHorizontalAlignment', 'left');
text(b.XEndPoints, b.YEndPoints, compose('%.2f', SH), 'HorizontalAlignment', 'center', ...
     'VerticalAlignment', 'bottom', 'FontSize', 8);
set(gca, 'XTick', 1:6, 'XTickLabel', gn, 'XTickLabelRotation', 25);  ylim([0 2.4]);  grid on
legend({L.sup, L.grd}, 'Location', 'northwest');  title(L.SH, 'FontWeight', 'normal');
nexttile;
b = bar(SF, 0.6, 'FaceColor', gold);  hold on
yline(in.SF_min, '--', L.req, 'Color', grey, 'LabelHorizontalAlignment', 'left');
text(b.XEndPoints, b.YEndPoints, compose('%.2f', SF), 'HorizontalAlignment', 'center', ...
     'VerticalAlignment', 'bottom', 'FontSize', 8);
set(gca, 'XTick', 1:6, 'XTickLabel', gn, 'XTickLabelRotation', 25);  ylim([0 3.2]);  grid on
title(L.SF, 'FontWeight', 'normal');
title(tl, L.st, 'FontSize', 10);
exportgraphics(fig, fullfile(out_dir, ['safety_' lang '.png']), 'Resolution', 150);
close(fig);

% 2. Contact temperature and film along the path
fig = figure('Visible', 'off', 'Position', [100 100 1000 380]);
tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact');
for k = 1:3
    nexttile;
    a = S.sc(2, k);  c7 = S.sc(5, k);
    yyaxis left
    plot(a.g, a.theta_B, '-', 'Color', red, 'LineWidth', 1.4);  hold on
    plot(c7.g, c7.theta_B, '--', 'Color', red, 'LineWidth', 1.0);
    yline(a.theta_S, '-', [L.thS ' 23699'], 'Color', grey, 'FontSize', 7);
    yline(c7.theta_S, '--', [L.thS ' 7808'], 'Color', grey, 'FontSize', 7);
    ylim([120 240]);  ylabel(L.tB);
    set(gca, 'YColor', red);
    yyaxis right
    lam = a.lambda;  lam(a.X < 0.05) = NaN;      % unloaded ends of the path
    plot(a.g, lam, '-', 'Color', blue, 'LineWidth', 1.2);
    ylim([0 2]);  ylabel(L.lam);  set(gca, 'YColor', blue);
    grid on;  title(mn{k}, 'FontWeight', 'normal');
    if k == 1
        legend({'θ_B MIL-PRF-23699', 'θ_B MIL-PRF-7808', '', '', 'λ MIL-PRF-23699'}, ...
               'Location', 'south', 'FontSize', 7);
    end
end
title(tl, L.pt, 'FontSize', 10);
xlabel(tl, L.px, 'FontSize', 9);
exportgraphics(fig, fullfile(out_dir, ['path_' lang '.png']), 'Resolution', 150);
close(fig);

% 3. Load sharing
fig = figure('Visible', 'off', 'Position', [100 100 1000 380]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact');
nexttile;
histogram(S.Kgam_hist, 1:0.01:1.7, 'Normalization', 'probability', 'FaceColor', blue, 'EdgeColor', 'none');
hold on
yt = ylim;
plot([1 1] * S.ls100.Kgam_p99, yt, '-', 'Color', red, 'LineWidth', 1.4);
text(S.ls100.Kgam_p99, yt(2) * 0.9, [' ' L.p99 sprintf(' %.3f', S.ls100.Kgam_p99)], 'Color', red, 'FontSize', 8);
xlabel(L.kg);  ylabel(L.cnt);  grid on
set(gca, 'YTickLabel', compose('%.0f', 100 * get(gca, 'YTick')));
nexttile;
semilogx(S.kb_list, S.kb_p99, 'o-', 'Color', blue, 'MarkerFaceColor', blue, 'LineWidth', 1.2);  hold on
plot(in.ls.k_brg, S.ls100.Kgam_p99, 's', 'Color', red, 'MarkerFaceColor', red, 'MarkerSize', 8);
xlabel(L.kb);  ylabel([L.kg ' (P99)']);  grid on
title(tl, L.kgt, 'FontSize', 10);
exportgraphics(fig, fullfile(out_dir, ['loadshare_' lang '.png']), 'Resolution', 150);
close(fig);

% 4. DYN-04 modes
d = S.dyn;
fig = figure('Visible', 'off', 'Position', [100 100 900 540]);
hold on
bandc = [0.96 0.84 0.43];
patch([0.5 2.5 2.5 0.5], d.band1(1, [1 1 2 2]), bandc, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
patch([0.5 2.5 2.5 0.5], d.band1(2, [1 1 2 2]), bandc, 'EdgeColor', 'none', 'FaceAlpha', 0.35);
nmax = max(d.web.n);
for l = 1:2
    patch([2.5 3.5 3.5 2.5], [d.band_s1(l, 1) - nmax * d.frot2, d.band_s1(l, 1) - nmax * d.frot2, ...
          d.band_s1(l, 2) + nmax * d.frot2, d.band_s1(l, 2) + nmax * d.frot2], bandc, ...
          'EdgeColor', 'none', 'FaceAlpha', 0.7 / l);
end
e1 = d.ring.excited(1, :);  e2 = d.ring.excited(2, :) & ~e1;  e0 = ~e1 & ~e2;
h1 = plot(ones(1, sum(e1)), d.ring.f(e1), 'o', 'Color', red, 'MarkerFaceColor', red);
h3 = plot(ones(1, sum(e2)), d.ring.f(e2), 's', 'Color', blue, 'MarkerFaceColor', blue);
h2 = plot(ones(1, sum(e0)), d.ring.f(e0), 'o', 'Color', red);
for j = 1:numel(d.ring.n)
    text(1.08, d.ring.f(j), sprintf('n=%d', d.ring.n(j)), 'FontSize', 7);
end
plot(2 * ones(size(d.planet.f)), d.planet.f, 'o', 'Color', red, 'MarkerFaceColor', red);
for j = 1:numel(d.planet.n)
    text(2.08, d.planet.f(j), sprintf('n=%d', d.planet.n(j)), 'FontSize', 7);
end
plot(3 * ones(size(d.web.f)), d.web.f, 'o', 'Color', red, 'MarkerFaceColor', red);
for j = 1:numel(d.web.n)
    text(3.08, d.web.f(j), sprintf('n=%d', d.web.n(j)), 'FontSize', 7);
end
set(gca, 'YScale', 'log', 'XTick', 1:3, 'XTickLabel', {L.ring, L.planet, L.web});
xlim([0.5 3.5]);  ylim([200 3e4]);  grid on;  box on
ylabel(L.fr);
legend([h1 h3 h2], {L.exc, L.exc2, L.nexc}, 'Location', 'northwest', 'FontSize', 8);
text(0.55, d.band1(1, 2) * 1.04, L.b1, 'FontSize', 7);
text(0.55, d.band1(2, 2) * 1.04, L.b2, 'FontSize', 7);
title(L.dt, 'FontWeight', 'normal', 'FontSize', 10);
exportgraphics(fig, fullfile(out_dir, ['dyn04_' lang '.png']), 'Resolution', 150);
close(fig);

% 5. Design options
fig = figure('Visible', 'off', 'Position', [100 100 780 400]);
V = S.var;
Y = zeros(numel(V), 4);
for j = 1:numel(V)
    Y(j, :) = [min(V(j).E.SHmin), V(j).E.SHs, min(V(j).E.SFmin), V(j).E.SFs];
end
b = bar(Y, 'grouped');
b(1).FaceColor = blue;  b(2).FaceColor = [0.55 0.75 0.90];  b(3).FaceColor = gold;  b(4).FaceColor = [0.95 0.80 0.50];
hold on
yline(in.SH_min, '--', 'S_H 1.2', 'Color', grey);
yline(in.SF_min, ':', 'S_F 1.5', 'Color', grey);
set(gca, 'XTickLabel', on);  ylim([0 2.3]);  grid on
legend(lg5, 'Location', 'northwest', 'FontSize', 8);
title(L.ot, 'FontWeight', 'normal', 'FontSize', 10);
exportgraphics(fig, fullfile(out_dir, ['options_' lang '.png']), 'Resolution', 150);
close(fig);
end
