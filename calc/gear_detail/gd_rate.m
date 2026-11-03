function r = gd_rate(M, T1, n1, opt)
%GD_RATE  Pitting and tooth root rating of one mesh, ISO 6336-1, -2, -3:2019 (Methods B and C).
%   r = gd_rate(M, T1, n1, opt)
%
%   Inputs
%     M     one mesh from gd_meshes
%     T1    torque on gear 1 per mesh                                   [N m]
%     n1    speed of gear 1 (relative to the carrier)                   [rpm]
%     opt   struct: KA (application factor), Kgam (mesh load factor,
%           default M.Kgam), mode ('ref': long life at 1e10 cycles,
%           'static', or 'cycles' with NL = [N1 N2] flank load cycles),
%           oil (gd_inputs oil for Z_L), T_corr (torque per mesh on gear 1
%           at which the helix correction is designed, default M.T_corr),
%           Ca (tip relief, um; default: the tooth deflection at T_corr),
%           ZNT10 (life factor at 1e10 cycles), fpb_share (share of f_pb
%           in K_Halpha)
%
%   Output struct r: Ft [N], v [m/s], c_prime, c_ga, c_gb [N/(mm um)],
%   kv (N, NS, regime, Bp, Bf, Bk, Kv), Kv, KHb, KFb, fsh, Fbx, Fby [um],
%   KHa, KFa, Ca [um]; pitting: sigma_H0, sigma_H1, sigma_H2, ZL, Zv, ZR,
%   sHG1, sHG2, S_H1, S_H2 and the static and reference limits HGs, HGr;
%   root: Y_F1, Y_S1, Y_F2, Y_S2, Y_beta, Y_B1, Y_B2, Y_DT, sigma_F1,
%   sigma_F2, Yd1, Yd2 (relative notch sensitivity), YR1, YR2, YM1, YM2,
%   sFG1, sFG2, S_F1, S_F2 and FGs, FGr; S_H = min, S_F = min.
%
%   Source: Phase 2 report, Section 2.4 ("Rating"). Tested by test_step24
%   (TC34 to TC36).

g = M.g;
if ~isfield(opt, 'Kgam'), opt.Kgam = M.Kgam; end
if ~isfield(opt, 'T_corr'), opt.T_corr = M.T_corr; end
if ~isfield(opt, 'fpb_share'), opt.fpb_share = 0.5; end
if ~isfield(opt, 'ZNT10'), opt.ZNT10 = 0.85; end
KA = opt.KA;
Kg = opt.Kgam;
b = g.b;
Ft = 2000 * T1 / g.d1;
v = pi * g.d1 * n1 / 60000;

% Tooth stiffness, ISO 6336-1 Clause 9 (Method B)
k = stiffness(g, M.C_R, Ft * KA * Kg / b);

% Tip relief: the tooth deflection at maximum continuous torque with the
% design K_gamma (unless given)
if isfield(opt, 'Ca')
    Ca = opt.Ca;
else
    Ca = KA * M.Kgam * (2000 * M.T1 / g.d1) / b / k.c0;
end

% Dynamic factor, Method B (6.5)
kv = dynamic_factor(M, g, k, Ft, n1, KA, Kg, Ca);
Kv = kv.Kv;

% Face load factor, Method C (7.5) with the helix correction designed at T_corr
Fm = Ft * KA * Kg * Kv;
Fm_corr = 2000 * opt.T_corr / g.d1 * KA * M.Kgam * Kv;      % the correction is fixed geometry
fsh = M.k_sh * Fm / b;
fsh_corr = M.k_sh * Fm_corr / b;
f_Hb = max(g.tol1.f_Hb, g.tol2.f_Hb);
Fbx = 1.33 * abs(fsh - 0.9 * fsh_corr) + 0.5 * M.f_ma;   % Table 12 case 5 at T_corr: B1 = 0.1, B2 = 0.5
Fbx = max([Fbx, 0.005 * Fm / b, 0.5 * f_Hb]);              % F_betax,min, Formula (58)
yb = min(0.15 * Fbx, 6);
Fby = Fbx - yb;
q = Fby * k.c_gb / (2 * Fm / b);
if q < 1
    KHb = 1 + q;
else
    KHb = sqrt(2 * Fby * k.c_gb / (Fm / b));
end
bh = max(min(b / g.h1, b / g.h2), 3);
NF = bh^2 / (1 + bh + bh^2);
KFb = KHb^NF;

% Transverse load factors, Method B (8.3)
fpb = opt.fpb_share * max(g.tol1.f_p, g.tol2.f_p);
ya = min(0.075 * fpb, 3);
FtH = Ft * KA * Kg * Kv * KHb;
eg = g.eps_gamma;
if eg <= 2
    KHa = eg / 2 * (0.9 + 0.4 * k.c_ga * (fpb - ya) / (FtH / b));
else
    KHa = 0.9 + 0.4 * sqrt(2 * (eg - 1) / eg) * k.c_ga * (fpb - ya) / (FtH / b);
end
KFa = KHa;
KHa = min(max(KHa, 1), eg / (g.eps_alpha * g.Z_eps^2));
KFa = min(max(KFa, 1), eg / (0.25 * g.eps_alpha + 0.75));

% Pitting, ISO 6336-2
u = g.u;
if g.internal, us = (u - 1) / u; else, us = (u + 1) / u; end
ZE = sqrt(1 / (pi * ((1 - M.mat1.nu^2) / M.mat1.E + (1 - M.mat2.nu^2) / M.mat2.E)));
sH0 = g.Z_H * ZE * g.Z_eps * g.Z_beta * sqrt(Ft / (g.d1 * b) * us);
K = KA * Kg * Kv * KHb * KHa;
sH1 = g.Z_B * sH0 * sqrt(K);
sH2 = g.Z_D * sH0 * sqrt(K);
sHlim_soft = min(M.mat1.sHlim, M.mat2.sHlim);
[ZL, Zv, ZR] = film_factors(g, M, sHlim_soft, opt.oil.nu40, v);
HGs = [M.mat1.sHlim * znt_static(M.mat1), M.mat2.sHlim * znt_static(M.mat2)];
HGr = [M.mat1.sHlim, M.mat2.sHlim] * ZL * Zv * ZR;
NL = life_cycles(opt);
sHG = [gd_sn('H', M.mat1.type, HGs(1), HGr(1), opt.ZNT10, NL(1)), ...
       gd_sn('H', M.mat2.type, HGs(2), HGr(2), opt.ZNT10, NL(2))];

% Tooth root, ISO 6336-3
r1 = g.r1;
r2 = g.r2;
beta_d = min(rad2deg(g.beta), 30);
Y_beta = (1 - min(g.eps_beta, 1) * beta_d / 120) / cosd(beta_d)^3;
Y_B1 = rim_factor(M.sR1, g.h1, g.mn, false);
Y_B2 = rim_factor(M.sR2, g.h2, g.mn, g.internal);
Y_DT = 1;
if g.A <= 4
    ean = r1.eps_an;
    if ean > 2.5, Y_DT = 0.7; elseif ean > 2.05, Y_DT = -0.666 * ean + 2.366; end
end
KF = KA * Kg * Kv * KFb * KFa;
sF1 = Ft / (b * g.mn) * r1.Y_F * r1.Y_S * Y_beta * Y_B1 * Y_DT * KF;
sF2 = Ft / (b * g.mn) * r2.Y_F * r2.Y_S * Y_beta * Y_B2 * Y_DT * KF;
[Yd1s, Yd1r] = notch_factors(M.mat1.type, r1);
[Yd2s, Yd2r] = notch_factors(M.mat2.type, r2);
YR1 = rough_factor(M.mat1.type, M.Rz_root1);
YR2 = rough_factor(M.mat2.type, M.Rz_root2);
YX = 1;                                      % m_n <= 5 for Eh and NT
[YM1s, YM1r] = mean_stress(M.reversed1, M.mat1.type, r1.Y_S);
[YM2s, YM2r] = mean_stress(M.reversed2, M.mat2.type, r2.Y_S);
FGs = [M.mat1.sFlim * 2 * ynt_static(M.mat1) * Yd1s * YM1s, M.mat2.sFlim * 2 * ynt_static(M.mat2) * Yd2s * YM2s];
FGr = [M.mat1.sFlim * 2 * Yd1r * YR1 * YX * YM1r, M.mat2.sFlim * 2 * Yd2r * YR2 * YX * YM2r];
sFG = [gd_sn('F', M.mat1.type, FGs(1), FGr(1), opt.ZNT10, NL(1)), ...
       gd_sn('F', M.mat2.type, FGs(2), FGr(2), opt.ZNT10, NL(2))];

r = struct('Ft', Ft, 'v', v, 'c_prime', k.c, 'c_ga', k.c_ga, 'c_gb', k.c_gb, 'kv', kv, 'Kv', Kv, ...
           'KHb', KHb, 'KFb', KFb, 'fsh', fsh, 'Fbx', Fbx, 'Fby', Fby, 'KHa', KHa, 'KFa', KFa, ...
           'Ca', Ca, 'K', K, 'ZE', ZE, 'sigma_H0', sH0, 'sigma_H1', sH1, 'sigma_H2', sH2, ...
           'ZL', ZL, 'Zv', Zv, 'ZR', ZR, 'HGs', HGs, 'HGr', HGr, 'sHG1', sHG(1), 'sHG2', sHG(2), ...
           'S_H1', sHG(1) / sH1, 'S_H2', sHG(2) / sH2, ...
           'Y_F1', r1.Y_F, 'Y_S1', r1.Y_S, 'Y_F2', r2.Y_F, 'Y_S2', r2.Y_S, 'Y_beta', Y_beta, ...
           'Y_B1', Y_B1, 'Y_B2', Y_B2, 'Y_DT', Y_DT, 'sigma_F1', sF1, 'sigma_F2', sF2, ...
           'Yd1', [Yd1s Yd1r], 'Yd2', [Yd2s Yd2r], 'YR1', YR1, 'YR2', YR2, 'YM1', [YM1s YM1r], ...
           'YM2', [YM2s YM2r], 'FGs', FGs, 'FGr', FGr, 'sFG1', sFG(1), 'sFG2', sFG(2), ...
           'S_F1', sFG(1) / sF1, 'S_F2', sFG(2) / sF2);
r.S_H = min(r.S_H1, r.S_H2);
r.S_F = min(r.S_F1, r.S_F2);
end

function k = stiffness(g, CR, w)
% Single stiffness c' and mesh stiffness, ISO 6336-1 Formulae (82) to (94)
C = [0.04723 0.15551 0.25791 -0.00635 -0.11654 -0.00193 -0.24188 0.00529 0.00182];
zn1 = g.z1 / cos(g.beta)^3;
x1 = g.x1;
if g.internal
    inv_zn2 = 0;                             % internal gear: z_n2 = infinity (9.3.2.6 b)
    x2 = 0;
else
    inv_zn2 = cos(g.beta)^3 / g.z2;
    x2 = g.x2;
end
q = C(1) + C(2) / zn1 + C(3) * inv_zn2 + C(4) * x1 + C(5) * x1 / zn1 + C(6) * x2 ...
    + C(7) * x2 * inv_zn2 + C(8) * x1^2 + C(9) * x2^2;
CB = (1 + 0.5 * (1.2 - 1.25)) * (1 - 0.02 * (20 - rad2deg(g.alpha_n)));
k.c0 = 1 / q * 0.8 * CR * CB * cos(g.beta);  % without the low-load correction
k.c = k.c0;
if w < 100
    k.c = k.c0 * (w / 100)^0.25;
end
k.c_ga = k.c * (0.75 * g.eps_alpha + 0.25);
k.c_gb = 0.85 * k.c_ga;
end

function kv = dynamic_factor(M, g, k, Ft, n1, KA, Kg, Ca)
% ISO 6336-1:2019 6.5, Method B; planetary stage by 6.5.8.4 a)
eg = g.eps_gamma;
if eg <= 2
    Cv = [0.32 0.34 0.23 0.90 0.47 0.47];
else
    Cv = [0.32 0.57 / (eg - 0.3) 0.096 / (eg - 1.56) (0.57 - 0.05 * eg) / (eg - 1.44) 0.47 0.12 / (eg - 1.74)];
end
if eg <= 1.5
    Cv7 = 0.75;
elseif eg <= 2.5
    Cv7 = 0.125 * sin(pi * (eg - 2)) + 0.875;
else
    Cv7 = 1;
end
w = KA * Kg * Ft / g.b;
fpb = max(g.tol1.f_p, g.tol2.f_p);
ffa = max(g.tol1.f_fa, g.tol2.f_fa);
yp = min(0.075 * fpb, 3);
yf = min(0.075 * ffa, 3);
Bp = k.c * (fpb - yp) / w;
Bf = k.c * (ffa - yf) / w;
Bk = abs(1 - k.c * Ca / w);
if w < 100
    NS = 0.5 + 0.35 * sqrt(w / 100);
else
    NS = 0.85;
end
if strcmp(M.kv.mode, 'pair')
    mred = prod(M.kv.mstar) / sum(M.kv.mstar);
    nE = 30000 / (pi * g.z1) * sqrt(k.c_ga / mred);
    N = n1 / nE;
else
    p = M.kv;
    mred = [p.mpla * p.msun / (p.N * p.mpla + p.msun), p.mpla];
    nE = 30000 / (pi * p.zsun) * sqrt(k.c_ga ./ mred);
    N = n1 * p.sun_speed ./ nE;
end
Kvs = arrayfun(@(NN) kv_at(NN, NS, Cv, Cv7, Bp, Bf, Bk), N);
[Kv, i] = max(Kvs);
kv = struct('N', N, 'NS', NS, 'nE', nE, 'mred', mred, 'Bp', Bp, 'Bf', Bf, 'Bk', Bk, ...
            'regime', regime(N(i), NS), 'Kv', Kv, 'Kv_all', Kvs);
end

function K = kv_at(N, NS, Cv, Cv7, Bp, Bf, Bk)
sub = @(n) n * (Cv(1) * Bp + Cv(2) * Bf + Cv(3) * Bk) + 1;
res = Cv(1) * Bp + Cv(2) * Bf + Cv(4) * Bk + 1;
sup = Cv(5) * Bp + Cv(6) * Bf + Cv7;
if N <= NS
    K = sub(N);
elseif N <= 1.15
    K = res;
elseif N < 1.5
    K = sup + (res - sup) * (1.5 - N) / 0.35;
else
    K = sup;
end
end

function s = regime(N, NS)
if N <= NS, s = 'subcritical';
elseif N <= 1.15, s = 'main resonance';
elseif N < 1.5, s = 'intermediate';
else, s = 'supercritical';
end
end

function [ZL, Zv, ZR] = film_factors(g, M, sHlim, nu40, v)
% ISO 6336-2:2019 12.3.2, reference stress
if sHlim < 850
    CZL = 0.83;
elseif sHlim <= 1200
    CZL = sHlim / 4375 + 0.6357;
else
    CZL = 0.91;
end
ZL = CZL + 4 * (1 - CZL) / (1.2 + 134 / nu40)^2;
CZv = CZL + 0.02;
Zv = CZv + 2 * (1 - CZv) / sqrt(0.8 + 32 / v);
r1 = g.db1 / 2 * tan(g.alpha_wt);
if g.internal
    r2 = -g.db2 / 2 * tan(g.alpha_wt);
else
    r2 = g.db2 / 2 * tan(g.alpha_wt);
end
rho_red = r1 * r2 / (r1 + r2);
Rz10 = (M.Rz1 + M.Rz2) / 2 * (10 / rho_red)^(1/3);
if sHlim < 850
    CZR = 0.15;
elseif sHlim <= 1200
    CZR = 0.32 - 0.0002 * sHlim;
else
    CZR = 0.08;
end
ZR = (3 / Rz10)^CZR;
end

function NL = life_cycles(opt)
switch opt.mode
    case 'ref',    NL = [1e10 1e10];
    case 'static', NL = [1 1];
    otherwise,     NL = opt.NL;
end
end

function z = znt_static(mat)
if strcmp(mat.type, 'Eh'), z = 1.6; else, z = 1.3; end
end

function y = ynt_static(mat)
if strcmp(mat.type, 'Eh'), y = 2.5; else, y = 1.6; end
end

function Y = rim_factor(sR, ht, mn, internal)
% ISO 6336-3:2019 Clause 9
if internal
    q = sR / mn;
    if q >= 3.5, Y = 1; elseif q > 1.75, Y = 1.15 * log(8.324 / q); else, Y = NaN; end
else
    q = sR / ht;
    if q >= 1.2, Y = 1; elseif q > 0.5, Y = 1.6 * log(2.242 / q); else, Y = NaN; end
end
end

function [Ys, Yr] = notch_factors(type, r)
% Relative notch sensitivity factor, ISO 6336-3:2019 14.2: static and reference
if strcmp(type, 'Eh')
    Ys = 0.44 * r.Y_S + 0.12;
    rho_p = 0.0030;
else
    Ys = 0.20 * r.Y_S + 0.60;
    rho_p = 0.1005;
end
chi = 0.2 * (1 + 2 * r.q_s);
chiT = 0.2 * (1 + 2 * 2.5);
Yr = (1 + sqrt(rho_p * chi)) / (1 + sqrt(rho_p * chiT));
end

function YR = rough_factor(type, Rz)
% Relative surface factor, ISO 6336-3:2019 14.3.2.1 (reference stress)
eh = strcmp(type, 'Eh');
if Rz < 1
    YR = eh * 1.12 + ~eh * 1.025;
elseif eh
    YR = 1.674 - 0.529 * (Rz + 1)^0.1;
else
    YR = 4.299 - 3.259 * (Rz + 1)^0.005;
end
end

function [Ys, Yr] = mean_stress(reversed, type, YS)
% Mean stress influence factor, ISO 6336-3:2019 Annex B, R = -1.2 for a planet
if ~reversed
    Ys = 1;  Yr = 1;
    return
end
R = -1.2;
if strcmp(type, 'Eh')
    Mr = 0.8 - 0.15 * YS;  Ms = 0.7;
else
    Mr = 0.3;  Ms = 0.3;
end
Y = @(Mm) 1 / (1 - R * (1 - Mm) / (1 + Mm));
Ys = Y(Ms);
Yr = Y(Mr);
end
