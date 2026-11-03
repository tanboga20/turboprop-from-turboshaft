function ls = gd_loadshare(Msp, Mpr, Ts, k_sp, k_pr, in, E_given)
%GD_LOADSHARE  Planet load sharing factor K_gamma with a floating sun (Monte Carlo).
%   ls = gd_loadshare(Msp, Mpr, Ts, k_sp, k_pr, in)
%   ls = gd_loadshare(Msp, Mpr, Ts, k_sp, k_pr, in, E)   one given set of path errors
%
%   Inputs
%     Msp, Mpr   sun-planet and planet-ring meshes (gd_meshes)
%     Ts         sun torque                                              [N m]
%     k_sp, k_pr mesh stiffness of one sun-planet and one planet-ring mesh,
%                c_gamma_alpha b                                         [N/um]
%     in         gd_inputs (in.ls: tolerances and support stiffness)
%     E          optional N-by-1 path errors [mm], positive = path longer
%
%   Output struct ls: k_path [N/mm]; Kgam (one value for a given E), or the
%   Monte Carlo statistics Kgam_mean, Kgam_p95, Kgam_p99, Kgam_max and
%   float_p99 (sun centre displacement) [mm]; Kgam_wc for the worst
%   alternating pattern of the error budget; e_budget [mm]; Kgam_all.
%
%   Model (Phase 2 report, Section 2.4, "Load sharing"): each planet is a
%   load path along the sun-planet line of action, with the two meshes and
%   the planet support in series, 1/k_path = 1/k_sp + 1/k_pr + 4 cos^2(alpha)/k_s
%   (the pin carries twice the mesh force and its tangential shift acts on
%   both meshes). A tangential pin position error e shifts the path by
%   2 e cos(alpha); a thicker planet tooth shifts it directly; the ring
%   pitch error is taken as ovality, a cos(2 (psi + phi)) with a up to
%   e_ring_Fp F_p and a random phase (its first harmonic, eccentricity, is
%   absorbed by the floating sun). The sun floats: its two translations and its rotation follow
%   from force and moment balance, so only error patterns that a sun
%   translation cannot absorb load the planets unevenly. Planets losing
%   contact are taken out and the system solved again. Tested by
%   test_step24 (TC37).

N = in.s2.N;
al = Msp.g.alpha_wt;
rb = Msp.g.db2 / 2;                          % sun base radius [mm]
psi = 2 * pi * (0:N-1)' / N;
nvec = [cos(al) * -sin(psi) + sin(al) * cos(psi), cos(al) * cos(psi) + sin(al) * sin(psi)];
k_s = 1 / (1 / (in.ls.k_brg / 1000) + 1 / (in.ls.k_pin / 1000));     % planet support [N/mm]
k_path = 1 / (1 / (k_sp * 1000) + 1 / (k_pr * 1000) + 4 * cos(al)^2 / k_s);
Fsum = Ts * 1000 / rb;                       % total line-of-action force [N]

ring_Fp = Mpr.g.tol2.F_p / 1000;             % mm
e_pin = in.ls.e_pin;
e_pl = in.ls.e_planet;
e_r = in.ls.e_ring_Fp * ring_Fp;            % ovality amplitude
ls.k_path = k_path;
ls.e_budget = [2 * e_pin * cos(al), e_pl, e_r];

if nargin >= 7
    [F, d] = solve(E_given(:), nvec, k_path, Fsum);
    ls.F = F;
    ls.Kgam = max(F) / mean(F);
    ls.float = norm(d);
    return
end

rng(in.ls.seed);
n = in.ls.n_mc;
K = zeros(n, 1);
fl = zeros(n, 1);
for i = 1:n
    E = 2 * cos(al) * e_pin * (2 * rand(N, 1) - 1) + e_pl * (2 * rand(N, 1) - 1) ...
        + e_r * rand * cos(2 * (psi + pi * rand));
    [F, d] = solve(E, nvec, k_path, Fsum);
    K(i) = max(F) / mean(F);
    fl(i) = norm(d);
end
Ks = sort(K);
fs = sort(fl);
ls.Kgam_mean = mean(K);
ls.Kgam_p95 = Ks(ceil(0.95 * n));
ls.Kgam_p99 = Ks(ceil(0.99 * n));
ls.Kgam_max = Ks(end);
ls.float_p99 = fs(ceil(0.99 * n));
ls.Kgam_all = K;
alt = (-1).^(0:N-1)';                        % the pattern a floating sun cannot absorb (N = 4)
[Fw, ~] = solve(sum(ls.e_budget) * alt, nvec, k_path, Fsum);
ls.Kgam_wc = max(Fw) / mean(Fw);
end

function [F, d] = solve(E, nvec, k, Fsum)
% Sun rotation u (at the base radius) and translation d from force and moment balance
N = numel(E);
on = true(N, 1);
for it = 1:N
    A = [ones(N, 1), nvec];
    Aon = A(on, :);
    Mx = k * (Aon' * Aon);
    rhs = [Fsum; 0; 0] + k * Aon' * E(on);
    x = pinv(Mx) * rhs;                      % two opposite planets left: the float across them is free
    F = zeros(N, 1);
    F(on) = k * (Aon * x - E(on));
    if all(F(on) >= 0), break, end
    on = on & (k * (A * x - E) > 0);
end
d = x(2:3);
end
