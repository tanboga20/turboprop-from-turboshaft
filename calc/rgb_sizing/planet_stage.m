function s = planet_stage(zs, zp, zr, N, m, b, Ts, ns, in)
%PLANET_STAGE  Planetary stage at one module: both meshes and the planet bearing.
%   s = planet_stage(zs, zp, zr, N, m, b, Ts, ns, in)
%
%   Floating sun (input), N planets, fixed ring, carrier output.
%   Inputs: sun, planet and ring tooth numbers; planet count N; module m and
%   face width b [mm]; sun torque Ts [N m] and speed ns [rpm]; in from
%   rgb_inputs (factors, K_gamma for N, ring material, Y_M of the planet,
%   bearing data, criteria).
%
%   Output struct s
%     m, b, ds, dp, dr          module, face width, pitch diameters    [mm]
%     n_c, n_p_rel              carrier speed, planet speed relative to the carrier [rpm]
%     gap                       post gap between neighbouring planet tip circles [mm]
%     Ft_mesh                   tangential force per mesh, without K_gamma [N]
%     g_sp, r_sp, rs_sp         sun-planet geometry, rating, static rating
%     g_pr, r_pr, rs_pr         planet-ring geometry, rating, static rating
%     eps_alpha_sp, sigma_H_sp, S_H_sp, S_F_sun, S_F_planet_sp
%     eps_alpha_pr, sigma_H_pr, S_H_ring, S_F_planet_pr, S_F_ring
%     m_planet                  planet and its rollers                 [kg]
%     brg                       planet_bearing output for the most heavily loaded planet
%     gears_ok, bearing_ok      STR-01 met in all four ratings; STR-02 met by the bearing
%
%   In the sun-planet mesh the smaller gear is gear 1 of iso6336_lite; in the
%   planet-ring mesh the planet is gear 1 and the nitrided ring gear 2.
%   K_gamma multiplies the load in both meshes and on the planet bearing.
%
%   Source: Phase 1 report, Section 3 ("Module loops", step 2, and "Method:
%   planet bearing"). Tested by test_rgb_sizing (TC5).

kg = in.Kgam(in.N_list == N);
ds = zs * m;
dp = zp * m;
n_c = ns / (1 + zr / zs);
n_s_rel = ns - n_c;
n_p_rel = n_s_rel * zs / zp;
Tp = Ts / N * zp / zs;                      % planet torque per mesh

% Sun-planet mesh; the smaller gear is gear 1
f_sp = in.f;
f_sp.Kgam = kg;
if zs <= zp
    g_sp = gear_geometry(zs, zp, m, 0, b, false, in.alpha_n);
    T1 = Ts / N;
    n1 = n_s_rel;
    f_sp.YM2 = in.YM_planet;
else
    g_sp = gear_geometry(zp, zs, m, 0, b, false, in.alpha_n);
    T1 = Tp;
    n1 = n_p_rel;
    f_sp.YM1 = in.YM_planet;
end
r_sp = iso6336_lite(g_sp, T1, n1, f_sp);
rs_sp = iso6336_lite(g_sp, in.K_over * T1, n1, static_factors(f_sp, in, false));

% Planet-ring mesh; the planet is gear 1, the nitrided ring gear 2
f_pr = in.f;
f_pr.Kgam = kg;
f_pr.YM1 = in.YM_planet;
f_pr.sHlim2 = in.ring_sHlim;
f_pr.sFlim2 = in.ring_sFlim;
g_pr = gear_geometry(zp, zr, m, 0, b, true, in.alpha_n);
r_pr = iso6336_lite(g_pr, Tp, n_p_rel, f_pr);
rs_pr = iso6336_lite(g_pr, in.K_over * Tp, n_p_rel, static_factors(f_pr, in, true));

% Planet bearing on the most heavily loaded planet. A first call sizes the
% rollers so that the centrifugal load can include their mass.
Ft_brg = 2000 * Ts / N * kg / ds;
b0 = planet_bearing(dp, m, b, Ft_brg, 0, 0, n_c, n_p_rel, in);
m_gear = in.rho_steel * pi / 4 * (dp^2 - b0.D_or^2) * b;
m_rollers = b0.Z * in.rho_steel * pi / 4 * b0.D_w^2 * b0.L_w;
brg = planet_bearing(dp, m, b, Ft_brg, m_gear + m_rollers, (ds + dp) / 2, n_c, n_p_rel, in);

s.m = m;  s.b = b;  s.ds = ds;  s.dp = dp;  s.dr = zr * m;
s.n_c = n_c;
s.n_p_rel = n_p_rel;
s.gap = m * ((zs + zp) * sin(pi / N) - (zp + 2));
s.Ft_mesh = r_sp.Ft;
s.g_sp = g_sp;  s.r_sp = r_sp;  s.rs_sp = rs_sp;
s.g_pr = g_pr;  s.r_pr = r_pr;  s.rs_pr = rs_pr;
s.eps_alpha_sp = g_sp.eps_alpha;
s.sigma_H_sp = r_sp.sigma_H;
s.S_H_sp = r_sp.S_H;
if zs <= zp
    s.S_F_sun = r_sp.S_F1;
    s.S_F_planet_sp = r_sp.S_F2;
else
    s.S_F_sun = r_sp.S_F2;
    s.S_F_planet_sp = r_sp.S_F1;
end
s.eps_alpha_pr = g_pr.eps_alpha;
s.sigma_H_pr = r_pr.sigma_H;
s.S_H_ring = r_pr.S_H2;
s.S_F_planet_pr = r_pr.S_F1;
s.S_F_ring = r_pr.S_F2;
s.m_planet = m_gear + m_rollers;
s.brg = brg;
s.gears_ok = rating_ok(r_sp, in) && rating_ok(rs_sp, in) && rating_ok(r_pr, in) && rating_ok(rs_pr, in);
s.bearing_ok = brg.L10_mission >= in.L10_req && brg.s0 >= in.s0_min;
end

function fs = static_factors(f, in, nitrided_ring)
% Life factors of the static check (LD-01); the nitrided ring has lower ones
fs = f;
fs.ZNT = in.ZNT_static;
fs.YNT = in.YNT_static;
if nitrided_ring
    fs.ZNT2 = in.ring_ZNT_static;
    fs.YNT2 = in.ring_YNT_static;
end
end

function ok = rating_ok(r, in)
ok = r.S_H >= in.SH_min && min(r.S_F1, r.S_F2) >= in.SF_min;
end
