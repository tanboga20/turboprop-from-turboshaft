function s = gd_scuffing(M, r, n1, oil, T_oil, Xmp, in, npts)
%GD_SCUFFING  Flash and contact temperature, scuffing safety and film thickness along the path of contact.
%   s = gd_scuffing(M, r, n1, oil, T_oil, Xmp, in)
%
%   Inputs
%     M      mesh (gd_meshes);  r  its gd_rate result at the load case
%     n1     speed of gear 1 relative to the carrier                   [rpm]
%     oil    gd_inputs oil struct;  T_oil  oil inlet temperature       [degC]
%     Xmp    multiple mating factor of the pair, (1 + n_p) / 2 averaged
%            over the two gears                                         [-]
%     in     gd_inputs;  npts  points on the path (default 81)
%
%   Output struct s: g [mm] (path coordinate from A), rho1, vr1, vr2 [m/s],
%   X (load sharing factor X_CP), w [N/mm], p [MPa], bH [mm], mu (mean
%   friction coefficient), theta_fl, theta_B [degC], theta_M, theta_S,
%   theta_Bmax, S_S, h_min [um], lambda; at the pitch point: lambdaC,
%   hC [um]; lambda_min.
%
%   Method (Phase 2 report, Section 2.4, "Scuffing and film"): load sharing
%   X_CP of ISO 6336-1:2019 10.5.2 for adequate profile modification
%   (Figure 23 spur, Figure 32 helical with eps_beta >= 1.2); local Hertz
%   stress and half width by Formulae (101) to (103); Blok's flash
%   temperature for a moving semi-elliptic heat source,
%   theta_fl = 0.785 mu w |sqrt(v_r1) - sqrt(v_r2)| / (B_M sqrt(b_H)) (SI);
%   friction, bulk temperature and scuffing temperature in the form of the
%   flash temperature method of ISO/TR 13989-1 (now ISO/TS 6336-20, not in
%   the project library: coefficients TBR); minimum film thickness by
%   Dowson and Higginson. Tested by test_step24 (TC38).

if nargin < 8, npts = 81; end
g = M.g;
ga = g.g_alpha;
pet = g.p_et;
x = linspace(0, ga, npts)';
rho1 = g.rho1A + x;
rho2 = g.rho2(rho1);
w1 = n1 * pi / 30;
w2 = w1 / g.u;
vr1 = w1 * rho1 / 1000;
vr2 = w2 * rho2 / 1000;
if g.internal
    rho_t = rho1 .* rho2 ./ (rho2 - rho1);
else
    rho_t = rho1 .* rho2 ./ (rho1 + rho2);
end
rho_n = rho_t / cos(g.beta_b);

% Load sharing along the path, adequate profile modification
X = zeros(npts, 1);
if g.eps_beta >= 1.2
    ea = g.eps_alpha;
    Xmax = 1 / ea + (ea - 1) / (ea * (ea + 1));
    gAB = (ga - pet) / 2;
    gDE = gAB + pet;
    X = Xmax * min([x / gAB, ones(npts, 1), (ga - x) / (ga - gDE)], [], 2);
else
    gB = ga - pet;
    gD = pet;
    X = min([x / gB, ones(npts, 1), (ga - x) / (ga - gD)], [], 2);
end
X = max(X, 0);

% Local load, Hertz stress and half width
E = M.mat1.E;
Er = 2 / ((1 - M.mat1.nu^2) / M.mat1.E + (1 - M.mat2.nu^2) / M.mat2.E);
Kload = r.K;                                 % K_A K_gamma K_v K_Hbeta K_Halpha
w = r.Ft * Kload * X / (g.b * cos(g.alpha_t));
p = sqrt(Er * w ./ (2 * pi * rho_n));
bH = 4 * rho_n .* p / Er;

% Oil at the inlet temperature
[nu, dens] = oil_at(oil, T_oil);
eta_oil = nu * dens / 1000;                  % mPa s

% Mean friction coefficient
vt = w1 * g.dw1 / 2 / 1000;                  % pitch line velocity
vSC = 2 * vt * sin(g.alpha_wt);
rC = g.rho1C;
rho_nC = (rC * g.rho2(rC) / (g.internal * (g.rho2(rC) - rC) + ~g.internal * (rC + g.rho2(rC)))) / cos(g.beta_b);
eg = g.eps_gamma;
if eg <= 2
    KBg = 1;
elseif eg < 3.5
    KBg = 1 + 0.2 * sqrt((eg - 2) * (5 - eg));
else
    KBg = 1.3;
end
wBt = r.Ft * Kload / g.b;
Ra = ((M.Rz1 + M.Rz2) / 2) / 6;              % Ra ~ Rz / 6
XR = 2.2 * (Ra / rho_nC)^0.25;
mu = 0.045 * (wBt * KBg / (vSC * rho_nC))^0.2 * eta_oil^-0.05 * XR * oil.XL;

% Flash temperature (Blok), SI units
BM = sqrt(in.lambda_steel * in.rho_steel * 1e9 * in.c_steel);   % N/(m s^0.5 K)
th_fl = 0.785 * mu * (w * 1000) .* abs(sqrt(vr1) - sqrt(vr2)) ./ (BM * sqrt(bH / 1000));
th_fl(X <= 0) = 0;
th_flm = trapz(x, th_fl) / ga;
th_M = T_oil + 0.47 * in.XS * Xmp * th_flm;
th_B = th_M + th_fl;
th_S = 80 + (0.85 + 1.4 * in.XW) * oil.XL * oil.S_FZG^2;
S_S = (th_S - T_oil) / (max(th_B) - T_oil);

% Film thickness (Dowson-Higginson line contact) at the bulk temperature
[nuM, densM] = oil_at(oil, th_M);
eta0 = nuM * 1e-6 * densM;                   % Pa s
alpha = oil.alpha100 + (oil.alpha150 - oil.alpha100) * (th_M - 100) / 50;
ue = (vr1 + vr2) / 2;
R = rho_n / 1000;
wl = max(w, 1e-9) * 1000;                    % N/m
hmin = 2.65 * (eta0 * ue).^0.7 * alpha^0.54 .* R.^0.43 * (Er * 1e6)^-0.03 .* wl.^-0.13 * 1e6;   % um
sig = sqrt((M.Rz1 / 6)^2 + (M.Rz2 / 6)^2);
lam = hmin / sig;
[~, iC] = min(abs(rho1 - rC));
loaded = X > 0.05;

s = struct('g', x, 'rho1', rho1, 'vr1', vr1, 'vr2', vr2, 'X', X, 'w', w, 'p', p, 'bH', bH, ...
           'mu', mu, 'eta_oil', eta_oil, 'BM', BM, 'theta_fl', th_fl, 'theta_flm', th_flm, ...
           'theta_M', th_M, 'theta_B', th_B, 'theta_Bmax', max(th_B), 'theta_S', th_S, 'S_S', S_S, ...
           'h_min', hmin, 'lambda', lam, 'hC', hmin(iC), 'lambdaC', lam(iC), ...
           'lambda_min', min(lam(loaded)), 'T_oil', T_oil, 'p_max', max(p));
end

function [nu, rho] = oil_at(oil, T)
% Kinematic viscosity (ISO 6336-1:2019 Formulae (151) to (153)) and density
A = log10(log10(oil.nu40 + 0.7) / log10(oil.nu100 + 0.7)) / log10(313 / 373);
B = log10(log10(oil.nu40 + 0.7)) - A * log10(313);
nu = 10^(10^(A * log10(T + 273) + B)) - 0.7;
rho = oil.rho15 * (1 - 7.0e-4 * (T - 15));
end
