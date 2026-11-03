function K = tl_kgamma(in)
%TL_KGAMMA  Planet load sharing factor with the drawing tolerances as +-3 sigma normal (E3b, STR-07, STR-02).
%   K = tl_kgamma(in)   in = tl_inputs (calc/gear_detail on the path)
%
%   The step 2.4 load-sharing model (gd_loadshare: floating sun, planet paths
%   along the sun-planet line of action) solved for each sample of path errors
%   E = 2 cos(alpha) e_t + e_planet + ovality: the tangential pin position
%   error e_t from the 0.010 mm position zone (radius 0.005 mm as +-3 sigma
%   per direction), the planet tooth thickness of the matched set (+-3 um as
%   +-3 sigma) and the ring ovality as in step 2.4 (uniform amplitude up to
%   e_ring_Fp F_p, random phase). Step 2.4 drew the first two uniformly over
%   their tolerances; both are reported. At 100% and 50% torque.
%   K.T: table [case, torque share, mean, P90, P99]; K.all: samples (normal, 100%).
%   Source: Phase 3 report, Section 3.8 (E3b).

gi = gd_inputs();
M = gd_meshes(gi);
ref = struct('KA', gi.KA, 'mode', 'ref', 'oil', gi.oil(1), 'ZNT10', gi.ZNT_ref, 'fpb_share', gi.fpb_share);
r0 = arrayfun(@(k) gd_rate(setfield(M(k), 'Kgam', 1), M(k).T1, M(k).n1, ref), 2:3); %#ok<SFLD>
k_sp = r0(1).c_ga * M(2).g.b;
k_pr = r0(2).c_ga * M(3).g.b;
al = M(2).g.alpha_wt;
N = gi.s2.N;
psi = 2 * pi * (0:N-1)' / N;
e_r = gi.ls.e_ring_Fp * M(3).g.tol2.F_p / 1000;
n = in.ls.n_mc;
rows = {};
for dist = ["normal", "uniform (step 2.4)"]
    rng(in.ls.seed);
    for share = [1 0.5]
        Kg = zeros(n, 1);
        for i = 1:n
            if dist == "normal"
                et = in.ls.pin_tp / 2 / 3 * randn(N, 1);
                ep = in.ls.planet_set / 3 * randn(N, 1);
            else
                et = in.ls.pin_tp / 2 * (2 * rand(N, 1) - 1);
                ep = in.ls.planet_set * (2 * rand(N, 1) - 1);
            end
            E = 2 * cos(al) * et + ep + e_r * rand * cos(2 * (psi + pi * rand));
            ls = gd_loadshare(M(2), M(3), share * M(2).Ts, k_sp, k_pr, gi, E);
            Kg(i) = ls.Kgam;
        end
        Ks = sort(Kg);
        rows(end + 1, :) = {dist, share, mean(Kg), Ks(ceil(in.ls.pct_life / 100 * n)), Ks(ceil(0.99 * n))}; %#ok<AGROW>
        if dist == "normal" && share == 1, K.all = Kg; end
    end
end
K.T = cell2table(rows, 'VariableNames', {'distribution', 'torque_share', 'mean', 'P90', 'P99'});
K.limit = in.ls.Kgam_lim;
end
