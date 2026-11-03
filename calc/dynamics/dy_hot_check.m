function H = dy_hot_check(S, in)
%DY_HOT_CHECK  Hot, cycle-consistent Goodman check of the A357 cases (step 3.6, DYN-03), from the saved results.
%   H = dy_hot_check(S, in)
%
%   S = run_step36 output (S.case with the governing node stresses of the
%   slide bracket per band, sf_worst_parts and sf_flange_parts = [sa_mesh
%   sa_pass sm] [MPa]; S.fscase), in = dy_inputs (in.hot). The coded check
%   holds sa_mesh + sa_pass + sa_1P against the 2.4e11-cycle endurance
%   k_gc se at room temperature. Hot (oil out about 130 degC, fits to
%   149 degC), the endurance falls by in.hot.k_T and the ultimate to
%   in.hot.su. The cycles of the full amplitude S = sa_mesh + sa_pass +
%   sa_1P recur at most four times per revolution (the planet pass, about
%   8e9 cycles in 20,000 h): S against k_T k_pass se; the mesh-only cycles
%   (7e11) sa_mesh against k_T k_mesh se; the first-stage case peak (its 1x
%   band is the first-stage mesh, 8e11 cycles) against k_T k_fs se, with
%   in.fs_sm. Each with the casting factor in.k_cast. DYN-03 takes the lower
%   of the coded and the hot factor. k_T* is the hot endurance loss at
%   which the planet-pass check at the governing node reaches 1.
%   Output H: case_shell, case_flange (per band: hot factor, lower of the
%   pass and mesh-only checks), case_shell_coded, case_flange_coded,
%   kT_star (flange, per band), fs, fs_coded.
%   Source: Phase 3 report, Section 3.6 ("Planetary case", hot check).

h = in.hot;  se = in.sigma_e.A357;  kc = in.k_cast;  s1 = in.cs.sa_1P;
se_p = h.k_T * h.k_pass * se;  se_m = h.k_T * h.k_mesh * se;
g = @(sa, sp, sm) min(1 ./ (kc * ((sa + sp + s1) / se_p + sm / h.su)), 1 ./ (kc * (sa / se_m + sm / h.su)));
B = S.case.band;
for j = 1:numel(B)
    ps = B(j).sf_worst_parts;  pf = B(j).sf_flange_parts;
    H.case_shell(j) = g(ps(1), ps(2), ps(3));
    H.case_flange(j) = g(pf(1), pf(2), pf(3));
    Sa = pf(1) + pf(2) + s1;
    H.kT_star(j) = Sa / (h.k_pass * se * (1 / kc - pf(3) / h.su));
end
H.case_shell_coded = [B.sf_worst];  H.case_flange_coded = [B.sf_flange];
[H.fs_coded, H.fs] = dy_fscase_sf(S.fscase, in, st_inputs());
end
