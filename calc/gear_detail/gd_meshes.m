function M = gd_meshes(in)
%GD_MESHES  The three meshes of the RGB with everything gd_rate needs.
%   M = gd_meshes(in)
%
%   M(1) first stage (pinion 31 / gear 110, helical), M(2) sun-planet,
%   M(3) planet-ring. Gear 1 is the pinion in M(1) and the planet in M(2)
%   and M(3). Fields of each mesh:
%     name, g (gd_pair), mat1, mat2 (gd_inputs materials), T1 [N m] and n1
%     [rpm] at 100% (torque on gear 1 per mesh, speed of gear 1 relative to
%     the carrier), Kgam (1 until gd_loadshare sets it), T_corr (torque at
%     which the helix correction is designed, in.corr_frac T1), cyc1, cyc2 (load
%     cycles of a tooth flank per revolution of gear 1), reversed1,
%     reversed2 (true for a planet tooth: both flanks loaded, R = -1.2),
%     kv (struct for K_v: mode 'pair' with mstar [m1* m2*] [kg/mm], or
%     'planetary' with msun, mpla, N and the sun speed factor), k_sh
%     [um per N/mm]: equivalent misalignment from elastic deflections per
%     unit load F_m/b, f_ma [um], C_R, Rz1, Rz2, Rz_root1, Rz_root2 [um],
%     sR1, sR2 (rim thickness under the root) [mm].
%
%   Source: Phase 2 report, Section 2.4 ("Meshes and their data").

rho = in.rho_steel;
mstar = @(dm, q, db) pi / 8 * rho * dm^4 * (1 - q^4) / db^2;   % ISO 6336-1 Formula (25) [kg/mm]

% First stage
s = in.s1;
g = gd_pair(s.z1, s.z2, s.mn, s.beta, s.b, s.x1, s.x2, false, in.hob, in.hob, in.A_s1, in);
dm1 = (g.da1 + g.df1) / 2;
dm2 = (g.da2 + g.df2) / 2;
di2 = g.df2 - 2 * in.gear2_rim * s.mn;
m1 = mstar(dm1, in.d_bore_pinion / dm1, g.db1);
m2 = mstar(dm2, di2 / dm2, g.db2);
bs_b = min(max(in.gear2_web / s.b, 0.2), 1.2);
CR = 1 + log(bs_b) / (5 * exp(max(in.gear2_rim, 1) / 5));
k_sh = 0.023 * (abs(1 + 0 - 0.3) + 0.3) * (s.b / g.d1)^2;     % ISO 6336-1 Formula (59), s = 0
M(1) = mesh('first stage', g, in.mat.Eh, in.mat.Eh, in.T_PT, in.n_PT, 1, s.z1 / s.z2, false, false, ...
            struct('mode', 'pair', 'mstar', [m1 m2]), k_sh, ...
            sqrt(g.tol1.f_Hb^2 + g.tol2.f_Hb^2), CR, in.Rz_flank, in.Rz_flank, ...
            Inf, in.gear2_rim * s.mn, in);  % pinion cut on its shaft: no rim

% Planetary stage: torque and speeds without losses
p = in.s2;
u1 = in.s1.z2 / in.s1.z1;
Ts = in.T_PT * u1;                           % sun torque [N m]
ns = in.n_PT / u1;
nc = ns / (1 + p.zr / p.zs);
ns_rel = ns - nc;
np_rel = ns_rel * p.zs / p.zp;
Tp = Ts / p.N * p.zp / p.zs;                 % torque on the planet per mesh [N m]
gsp = gd_pair(p.zp, p.zs, p.m, 0, p.b, p.xp, p.xs, false, in.hob, in.hob, in.A_s2, in);
gpr = gd_pair(p.zp, p.zr, p.m, 0, p.b, p.xp, p.xr, true, in.hob, in.shaper, in.A_s2, in, [1 p.ha_r]);
dms = (gsp.da2 + gsp.df2) / 2;
dmp = (gsp.da1 + gsp.df1) / 2;
D_or = gsp.df1 - 2 * in.planet_rim * p.m;   % planet bore = bearing outer race
msun = mstar(dms, in.sun_bore / dms, gsp.db2);
mpla = mstar(dmp, D_or / dmp, gsp.db1);
kv = struct('mode', 'planetary', 'msun', msun, 'mpla', mpla, 'N', p.N, 'zsun', p.zs, ...
            'sun_speed', p.zp / p.zs);       % sun speed relative to the carrier per planet rpm

% Elastic misalignments per unit load F_m/b [um per N/mm], Section 2.4
G = in.mat.Eh.E / (2 * (1 + in.mat.Eh.nu));
d_s = gsp.d2;
J_s = pi / 32 * (gsp.df2^4 - in.sun_bore^4);
% sun twist: torque enters at one end, N meshes take it off uniformly over b
k_twist = gsp.db2 / 2 * p.N * d_s / 2 * p.b * p.b / (2 * G * J_s) * 1000;
c = in.carrier;
I_post = c.post_t * c.post_w^3 / 12;
k_post = 1 / (c.L_post^3 / (12 * c.E * I_post) + c.L_post / (5 / 6 * G * c.post_w * c.post_t));
k_carrier = p.b / k_post * (p.b / c.L_pin) * cos(gsp.alpha_wt) * 1000;
f_pin = in.carrier.f_pin_par * p.b / c.L_pin;
sR_planet = in.planet_rim * p.m;
sR_sun = (gsp.df2 - in.sun_bore) / 2;
sR_ring = in.ring_rim * p.m;
M(2) = mesh('sun-planet', gsp, in.mat.Eh, in.mat.Eh, Tp, np_rel, 1, p.N * p.zp / p.zs, true, false, ...
            kv, abs(k_twist - k_carrier), sqrt(gsp.tol1.f_Hb^2 + gsp.tol2.f_Hb^2 + f_pin^2), 1, ...
            in.Rz_flank, in.Rz_flank, sR_planet, sR_sun, in);
M(3) = mesh('planet-ring', gpr, in.mat.Eh, in.mat.NT, Tp, np_rel, 1, p.N * p.zp / p.zr, true, false, ...
            kv, k_carrier, sqrt(gpr.tol1.f_Hb^2 + gpr.tol2.f_Hb^2 + f_pin^2), 1, ...
            in.Rz_flank, in.Rz_flank_ring, sR_planet, sR_ring, in);
for k = 2:3
    M(k).Ts = Ts;  M(k).ns = ns;  M(k).nc = nc;  M(k).ns_rel = ns_rel;
    M(k).k_twist = k_twist;  M(k).k_carrier = k_carrier;  M(k).D_or = D_or;
end
M(1).Ts = Ts;  M(1).ns = ns;  M(1).nc = nc;  M(1).ns_rel = ns_rel;
M(1).k_twist = 0;  M(1).k_carrier = 0;  M(1).D_or = NaN;
end

function m = mesh(name, g, mat1, mat2, T1, n1, cyc1, cyc2, rev1, rev2, kv, k_sh, f_ma, CR, Rz1, Rz2, sR1, sR2, in)
m = struct('name', name, 'g', g, 'mat1', mat1, 'mat2', mat2, 'T1', T1, 'n1', n1, 'Kgam', 1, ...
           'T_corr', in.corr_frac * T1, ...
           'cyc1', cyc1, 'cyc2', cyc2, 'reversed1', rev1, 'reversed2', rev2, 'kv', kv, ...
           'k_sh', k_sh, 'f_ma', f_ma, 'C_R', CR, 'Rz1', Rz1, 'Rz2', Rz2, ...
           'Rz_root1', in.Rz_root, 'Rz_root2', in.Rz_root, 'sR1', sR1, 'sR2', sR2);
end
