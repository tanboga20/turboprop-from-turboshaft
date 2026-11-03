function S = run_step36(out_dir, h_axi)
%RUN_STEP36  Step 3.6: forced response to the mesh excitation (DYN-03, DYN-04), damping ring, Campbell diagrams.
%   S = run_step36()          results in calc/results/step36 (about an hour)
%   S = run_step36(out_dir)
%   S = run_step36(out_dir, h_axi)   section mesh of the web [mm] (default in.h_axi; 2 for a quick run)
%
%   Run from the repo root with calc/dynamics, calc/gear_detail,
%   calc/shafts_bearings, calc/housing and calc/structures on the path. Steps:
%    1. planet on its rollers and meshes (dy_planet_frf, exact spring
%       tensors): dynamic tooth forces and K_v,FE in the 1x, 2x and 3x
%       planetary mesh bands, the rim check, the TE2 sensitivity;
%    2. first-stage gear blank (dy_web, harmonic model): in-plane and
%       out-of-plane families in the 1x and 2x bands with the TE and shuttle
%       excitation, once-per-revolution stress and Goodman, the friction
%       damping ring (dy_ring) sized on both the rim and the teeth-as-mass
%       models; checks: modal against direct, 2-D mesh 2 mm against 1 mm,
%       the 3-D toolbox model on a coarse mesh (dy_web_check3d), the
%       harmonic element on a free ring (dy_axi_ring); sensitivities;
%    3. planetary case (dy_case_frf, harmonic model of the step 2.8
%       section): response to the planet ring forces with the mesh phasing
%       of the planets, over the brackets, Goodman (DYN-03, the housing
%       criterion of DYN-04); 3b. first-stage case (dy_fscase_frf, coarse
%       3-D) in the first-stage 1x band;
%    4. Campbell diagrams and response plots, the ring data for the
%       first-stage gear drawing (cad/params/gear2_ring.txt).
%   Writes CSV tables (web_modes, web_inband, ring_trade, case_modes,
%   planet_modes, planet_kv, case_bands), plots in Turkish and English,
%   summary.txt and step36.mat.
%   Source: Phase 3 report, Section 3.6.

if nargin < 1 || isempty(out_dir)
    out_dir = fullfile('calc', 'results', 'step36');
end
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
diary_file = fullfile(out_dir, 'summary.txt');
if exist(diary_file, 'file'), delete(diary_file); end
diary(diary_file);
c_diary = onCleanup(@() diary('off'));
in = dy_inputs();
if nargin > 1, in.h_axi = h_axi; end
gi = gd_inputs();  M = gd_meshes(gi);  sb = sb_inputs();  hi = hs_inputs();
ref = struct('KA', 1, 'mode', 'ref', 'oil', gi.oil(1), 'Kgam', 1);
S = struct('in', in);

% speeds and bands (step 2.8 convention: speed range and +-10%)
fm1 = gi.n_PT * gi.s1.z1 / 60;                         % first-stage mesh at 100% [Hz]
frot2 = gi.n_PT * gi.s1.z1 / gi.s1.z2 / 60;            % gear 2 speed [Hz]
band1 = [0.9 * gi.speed_range(1) * fm1, 1.1 * gi.speed_range(2) * fm1];
bandsP = hi.f_bands;                                   % planetary mesh 1x and 2x bands
fmP = mean(bandsP(1, :) ./ [0.9 * gi.speed_range(1), 1.1 * gi.speed_range(2)]);   % planetary mesh at 100%
S.speed = struct('fm1', fm1, 'frot2', frot2, 'band1', band1, 'bandsP', bandsP, 'fmP', fmP);
fprintf('Step 3.6: first-stage mesh %.1f Hz at 100%%, gear speed %.2f Hz, 1x band %.0f-%.0f Hz; planetary mesh %.1f Hz\n', ...
        fm1, frot2, band1, fmP);

% 1. planet
gsp = M(2).g;  pb = sb.planet;
Dpw = M(2).D_or - pb.Dw;  Z = floor(pi * Dpw / (pb.Dw * (1 + pb.pitch_gap)));
r2 = gd_rate(M(2), M(2).T1, M(2).n1, ref);
r3 = gd_rate(M(3), M(3).T1, M(3).n1, ref);
Ftm = 2000 * M(2).T1 / gsp.dw1;
pp = struct('D_or', M(2).D_or, 'd_root', gsp.df1, 'b', gsp.b, 'h_teeth', 0.5 * gsp.h1, 'E', gi.mat.Eh.E * 1e6, ...
            'nu', 0.3, 'rho', gi.rho_steel * 1e9, 'Z', Z, 'Lwe', gsp.b - pb.L_ends, 'F', 2 * Ftm * 1.22, ...
            'k_mesh', r2.c_ga * gsp.b * 1e6, 'alpha', gsp.alpha_wt, 'psi_mesh', 4 * pi / gsp.z1);
bandsP = [bandsP; 3 * fmP * [0.9 * gi.speed_range(1), 1.1 * gi.speed_range(2)]];   % add the 3x band
S.speed.bandsP = bandsP;
pp.k_sp = pp.k_mesh;  pp.k_pr = r3.c_ga * M(3).g.b * 1e6;
pp.c_sp = in.planet24.c(1);  pp.c_pr = in.planet24.c(2);
pp.Ft = Ftm;  pp.Kv24 = in.planet24.Kv;  pp.SF24 = in.planet24.SF;
P = dy_planet_frf(in, pp, bandsP);
fprintf('== Planet (%d dof): modes %s Hz (%s)\n', P.n_dof, mat2str(round(P.f_all(P.f_all < 12000))), strjoin(P.kind(P.f_all < 12000), ' '));
for h = 1:3
    R = P.h(h);
    fprintf('   %dx band %.0f-%.0f Hz: modes %s; K_v,FE %.3f (sun-planet) / %.3f (planet-ring), S_F %.2f / %.2f; rim %.2f MPa, Goodman %.1f\n', ...
            h, bandsP(h, :), mat2str(round(R.f_modes)), R.Kv_sp, R.Kv_pr, R.SF_sp, R.SF_pr, R.sig_pk, R.sf_rim);
end
S.planet = P;
S.planet_k = pp.k_mesh;
% 2. first-stage gear web and the damping ring
g1 = M(1).g;
pw = struct('r_bore', sb.shafts(2).d_o / 2, 'r_hub', gi.gear2_hub_d / 2, 'r_rim', g1.df2 / 2 - gi.gear2_rim * gi.s1.mn, ...
            'r_out', g1.df2 / 2 + 0.25 * g1.h2, 't_web', gi.gear2_web, 'b', gi.s1.b, 'L_hub', hi.web.L_hub, ...
            'E', gi.mat.Eh.E * 1e6, 'nu', 0.3, 'rho', gi.rho_steel * 1e9, ...
            'rim', gi.gear2_rim * gi.s1.mn, 'h_t', g1.h2);    % rim under the root and tooth height (groove check)
r1 = gd_rate(M(1), M(1).T1, M(1).n1, ref);
k1 = r1.c_ga * g1.b * 1e6;
Dz = dy_shuttle(g1);                                   % axial shuttle of the contact-line centroid
Ft = 2000 * M(1).T1 / g1.dw1;
Ld = struct('Fb', k1 * in.TE(1:2) * 1e-6, 'alpha', g1.alpha_wt, 'tbb', tan(g1.beta_b), ...
            'Fs', [Ft, Ft * tan(g1.alpha_wt), Ft * tan(g1.beta)], 'dZ', Dz.dZ / 1000, 'k', k1, 'rw', [g1.dw1, g1.dw2] / 2000);
fprintf('\n== First-stage mesh loads: dynamic %s N along the line of action (1x, 2x), static F_t %.0f F_r %.0f F_a %.0f N, shuttle dZ %s mm\n', ...
        mat2str(round(Ld.Fb, 1)), Ld.Fs, mat2str(round(Dz.dZ, 3)));
% the present rim (to a quarter of the tooth) and the teeth-as-mass bracket (rim to the root, rim density scaled)
ptm = pw;  ptm.r_out = g1.df2 / 2;
ptm.rho_rim = (pw.r_out^2 - pw.r_rim^2) / (ptm.r_out^2 - pw.r_rim^2);
in.ring.h_mass = 0;
W0 = dy_web(in, pw, band1, frot2, fm1, Ld);           % bare blank
fprintf('   bare blank solved (%s)\n', datestr(now, 'HH:MM'));
T0 = dy_web(in, ptm, band1, frot2, fm1, Ld);
fprintf('   teeth-as-mass blank solved (%s)\n', datestr(now, 'HH:MM'));
W = W0;  Wt = T0;
hist = [];
for it = 1:3                                           % ring size and groove, then the ring mass in both models
    Rs = ring_select(in, W, Wt, frot2);
    if it > 1 && Rs.h == in.ring.h_mass && Rs.e == in.ring.e, break, end
    hist(end + 1) = Rs.h; %#ok<AGROW>
    in.ring.h_mass = Rs.h;  in.ring.e = Rs.e;
    W = dy_web(in, pw, band1, frot2, fm1, Ld);
    Wt = dy_web(in, ptm, band1, frot2, fm1, Ld);
    fprintf('   ring %g mm at e = %g mm in both models, pass %d (%s)\n', 1000 * Rs.h, 1000 * Rs.e, it, datestr(now, 'HH:MM'));
end
Rs = ring_select(in, W, Wt, frot2);
if Rs.h ~= in.ring.h_mass || Rs.e ~= in.ring.e
    % the ring mass moves the families and the size does not settle: start from the smaller of the last sizes and
    % step it up until the rule holds on the models that carry that ring (a self-consistent size)
    hg = in.ring.h(in.ring.rho * in.ring.h * in.ring.w * 2 * pi * W.fam.Rg <= in.ring.m_max);   % admissible sizes
    h0 = min([Rs.h, hist(end - min(1, numel(hist) - 1):end)]);  in.ring.e = Rs.e;
    for h = hg(hg >= h0 - 1e-9)
        in.ring.h_mass = h;
        W = dy_web(in, pw, band1, frot2, fm1, Ld);
        Wt = dy_web(in, ptm, band1, frot2, fm1, Ld);
        Rs = ring_eval(in, W, Wt, frot2, h, find(in.ring.e_list == Rs.e, 1));
        fprintf('   ring %g mm at e = %g mm carried by the models: s %.3f, Goodman %.2f (%s)\n', 1000 * h, 1000 * Rs.e, ...
                Rs.s_max, Rs.sf, datestr(now, 'HH:MM'));
        if Rs.s_max <= in.ring.s_max && Rs.sf >= 1, break, end
    end
end
S.ring_rule_met = Rs.s_max <= in.ring.s_max && Rs.sf >= 1;
if ~S.ring_rule_met
    fprintf('   RING RULE NOT MET up to the largest ring tried: s %.3f, Goodman %.2f\n', Rs.s_max, Rs.sf);
end
Ar = Rs.h * in.ring.w;
G = dy_ring(in, W, frot2, Ar, Rs.ie, in.ring.mu);
Gt = dy_ring(in, Wt, frot2, Ar, Rs.ie, in.ring.mu);
Gm = arrayfun(@(mu) dy_ring(in, W, frot2, Ar, Rs.ie, mu), in.ring.mu_range);
key = @(T) T.n * 10 + T.h + 100 * T.oop;               % same n, mesh harmonic and plane
jt = near(W.inband.f, key(W.inband), Wt.inband.f, key(Wt.inband));
kt = key(Wt.inband);  ft = Wt.inband.f(jt);  st = Gt.s(jt);
other = kt(jt) ~= key(W.inband) | ft > 1.03 * W.inband.f | ft < 0.8 * W.inband.f;
ft(other) = NaN;  st(other) = NaN;                     % no in-band family of the same kind in the teeth-as-mass model
ib = W.inband;
rule = G.slips & ib.sig_bare >= in.ring.rule_frac * max(ib.sig_bare);
W.inband = [ib, table(G.u_slip, G.u_stick_hi, G.slips, rule, G.A_req, G.EfW, G.s, G.s .* ib.sig_bare, in.zeta_web ./ G.s, ...
                      G.slips_trav, G.s_trav, G.s_trav .* ib.sig_bare / 2, in.zeta_web ./ G.s_trav, G.s_stick, ...
                      [Gm.s], st, ft, ...
                      'VariableNames', {'u_slip_um', 'u_stick_hi_um', 'slips', 'rule', 'A_req_mm2', 'Ef_over_Win', 's', ...
                                        'sig_ring_MPa', 'zeta_eq', 'slips_trav', 's_trav', 'sig_ring_trav_MPa', 'zeta_eq_trav', ...
                                        's_stick', 's_mu', 's_teeth', 'f_teeth'})];
W.ring = struct('h', Rs.h * 1e3, 'w', in.ring.w * 1e3, 'R', W.fam.Rg * 1e3, 'e', Rs.e * 1e3, 'z', pw.b / 2 + Rs.e * 1e3, ...
                'mass', Rs.mass, 'q100', in.ring.rho * Ar * (2 * pi * frot2)^2 * W.fam.Rg, 's_max', Rs.s_max, ...
                'sf_ring', Rs.sf, 'h_mass', in.ring.h_mass * 1e3);
W.ring_trade = Rs.trade;
m0 = W0.modes;                                         % all modes: the ring mass can turn a mixed family out of plane
j0 = near(W.inband.f, W.inband.n, m0.f, m0.n);
S.web_bare = W0;  S.web_teeth = Wt;
S.web_ring_df = W.inband.f ./ m0.f(j0) - 1;           % frequency shift by the ring mass (same family on the bare blank)
fprintf('\n== First-stage gear web (harmonic model, %d dof, %.3f kg): 1x band %.0f-%.0f Hz, 2x band %.0f-%.0f Hz (+-n x %.1f Hz)\n', ...
        W.n_dof, W.mass, band1, 2 * band1, frot2);
disp(W.inband(:, {'f', 'n', 'h', 'oop', 'x_lo', 'x_hi', 'sig_far_te', 'sig_bare', 'u_slip_um', 'u_stick_hi_um', 'slips', 'rule', ...
                  's', 'sig_ring_MPa', 'zeta_eq', 's_trav', 's_stick', 's_mu', 's_teeth', 'df_mesh_pct'}));
disp(W.ring_trade);
fprintf('ring %g x %g mm, groove offset %g mm (z %g mm), %.3f kg, preload at 100%% %.0f N/m: rule families s <= %.3f; its mass shifts the families by %.2f to %.2f%%\n', ...
        W.ring.h, W.ring.w, W.ring.e, W.ring.z, W.ring.mass, W.ring.q100, Rs.s_max, 100 * min(S.web_ring_df), 100 * max(S.web_ring_df));
fprintf('check at %.0f Hz (n %d, %dx): modal %.4f / direct %.4f MPa, W_in %.4g / %.4g J\n', W.check.f, W.check.n, W.check.h, ...
        W.check.sig0_modal, W.check.sig0_direct, W.check.Win_modal, W.check.Win_direct);
O = W.once_rev;
% web DYN-03 margin: the lower of the rim and teeth-as-mass models (bare: the blanks without the ring mass;
% with the ring: the models that carry it, as the ring rule); the rim model alone is kept for reference
S.web_margin_rim = goodman(in, O, max(W.inband.sig_bare));
S.web_margin_ring_rim = goodman(in, O, max(W.inband.sig_ring_MPa));
S.web_margin = min(goodman(in, W0.once_rev, max(W0.inband.sig_bare)), goodman(in, T0.once_rev, max(T0.inband.sig_bare)));
S.web_margin_ring = Rs.sf;
% sensitivities, on both models: mesh excitation x2 (TE and shuttle: slips x2, input energy x4) and zeta_web / 2
% (both x2)
Gx2 = dy_ring(in, W, frot2, Ar, Rs.ie, in.ring.mu, [2 4]);  Gx2t = dy_ring(in, Wt, frot2, Ar, Rs.ie, in.ring.mu, [2 4]);
Gz2 = dy_ring(in, W, frot2, Ar, Rs.ie, in.ring.mu, [2 2]);  Gz2t = dy_ring(in, Wt, frot2, Ar, Rs.ie, in.ring.mu, [2 2]);
sb_ = W.inband.sig_bare;  sbt = Wt.inband.sig_bare;
bare2 = min(goodman(in, W0.once_rev, 2 * max(W0.inband.sig_bare)), goodman(in, T0.once_rev, 2 * max(T0.inband.sig_bare)));
S.web_sens = struct('sf_x2_bare', bare2, ...
                    'sf_x2_ring', min(goodman(in, O, 2 * max(Gx2.s .* sb_)), goodman(in, Wt.once_rev, 2 * max(Gx2t.s .* sbt))), ...
                    's_x2', Gx2.s, 'sf_z_bare', bare2, ...
                    'sf_z_ring', min(goodman(in, O, 2 * max(Gz2.s .* sb_)), goodman(in, Wt.once_rev, 2 * max(Gz2t.s .* sbt))), ...
                    's_z', Gz2.s, 'mu', in.ring.mu_range);
fprintf('sensitivity, web Goodman: excitation x2 %.2f bare / %.2f with the ring (rule families s %s); zeta_web 0.001 %.2f / %.2f\n', ...
        S.web_sens.sf_x2_bare, S.web_sens.sf_x2_ring, mat2str(round(Gx2.s(W.inband.rule)', 2)), S.web_sens.sf_z_bare, S.web_sens.sf_z_ring);
if S.web_sens.sf_x2_ring < 1
    fprintf('   DYN-03 not met with the ring at excitation x2: the ring size would need revisiting (TE governs)\n');
end
gr = @(v) 1 / ((in.Kt_fillet * O.root_alt + v) / in.sigma_e.P53 + in.Kt_fillet * O.root_mean / in.su.P53);
S.web_sf_root = [gr(max(W.inband.sig_bare)), gr(max(W.inband.sig_ring_MPa))];   % web roots alone, bare and with the ring
fprintf('once per revolution (static mesh force): web roots nominal mean %.1f / alternating %.1f MPa (x Kt %.2f), boundary %.1f / %.1f MPa\n', ...
        O.root_mean, O.root_alt, in.Kt_fillet, O.far_mean, O.far_alt);
fprintf('DYN-03 web, Goodman with the largest vibratory stress, lower of the rim and teeth-as-mass models: %.2f bare, %.2f with the ring (rim model alone %.2f / %.2f)\n', ...
        S.web_margin, S.web_margin_ring, S.web_margin_rim, S.web_margin_ring_rim);
fprintf('ring mass for the SYS-06 roll-up: %.3f kg (%g x %g mm at e = %g mm)\n', W.ring.mass, W.ring.h, W.ring.w, W.ring.e);
S.web = W;  S.web_k = k1;  S.web_Ld = Ld;  S.web_pw = pw;  S.shuttle = Dz;
mt = T0.modes;                                         % all modes of the teeth-as-mass model (same n and plane)
S.web_bracket = table(W0.inband.f, W0.inband.n, W0.inband.h, W0.inband.oop, mt.f(near(W0.inband.f, ...
                      W0.inband.n * 10 + 100 * W0.inband.oop, mt.f, mt.n * 10 + 100 * mt.out_of_plane)), ...
                      'VariableNames', {'f', 'n', 'h', 'oop', 'f_teeth_mass'});
S.web_bracket.df = S.web_bracket.f_teeth_mass ./ S.web_bracket.f - 1;
fprintf('teeth as mass only (rim to the root, %.3f kg): in-band families %.1f to %.1f%% from the present model\n', T0.mass, ...
        100 * min(S.web_bracket.df), 100 * max(S.web_bracket.df));
% checks of the web model
in2 = in;  in2.h_axi = 2 * in.h_axi;
W2 = dy_web(in2, pw, band1, frot2, fm1, Ld);
% the same mode on the coarser mesh among all its modes (a family at a band edge may fall outside the
% coarse in-band list); stresses compared where that mode is also in band there
m2 = W2.modes;
jm = near(W.inband.f, W.inband.n, m2.f, m2.n);       % on n alone: a mixed family can change its plane label
j2 = near(W.inband.f, key(W.inband), W2.inband.f, key(W2.inband));
same = abs(W2.inband.f(j2) ./ m2.f(jm) - 1) < 1e-6;
sig2 = W2.inband.sig_bare(j2);  sig2(~same) = NaN;
S.web_conv = struct('h', [in.h_axi in2.h_axi], 'n', W.inband.n, 'f', [W.inband.f, m2.f(jm)], ...
                    'sig0', [W.inband.sig_bare, sig2]);
fprintf('mesh %g / %g mm: in-band f differ by at most %.2f%%, bare stress by %.2f%% (%d of %d families in band on both)\n', ...
        in.h_axi, in2.h_axi, 100 * max(abs(S.web_conv.f(:, 2) ./ S.web_conv.f(:, 1) - 1)), ...
        100 * max(abs(sig2(same) ./ W.inband.sig_bare(same) - 1)), nnz(same), numel(same));
ra = W0.ref_axial;
C3 = dy_web_check3d(in, pw, Ld.Fb(1) * Ld.tbb, ra.n, 2 * band1(2));   % axial TE load on the bare blank
S.web_check3d = C3;
fprintf('3-D check (Hmax %g m, %d nodes, %d modes), axial TE load: n %d at %.0f Hz (2-D %.0f Hz); modal %.3f / direct %.3f MPa (2-D %.3f); W_in %.4g / %.4g J (2-D %.4g)\n', ...
        in.Hmax_web, C3.n_nodes, C3.n_modes, C3.n, C3.f, ra.f, C3.modal.sig0, C3.direct.sig0, ra.sig_far, C3.modal.Win, C3.direct.Win, ra.Win);
S.ring_check = dy_axi_ring(100, 4, 0.5, 2:4, 205e9, 0.3, 7830);
fprintf('free ring R 100, 4 x 4 mm: in-plane %s Hz, out-of-plane %s Hz\n', mat2str(round(S.ring_check.f_in, 1)), ...
        mat2str(round(S.ring_check.f_out, 1)));

% 3. case (dy_case_stage; run_step36_case reruns this stage alone on a saved step36.mat)
S = dy_case_stage(S, in, gi, M, hi, P, pp, bandsP, out_dir);

% 3b. first-stage case in the first-stage 1x band (coarse 3-D, last: the largest model)
S = dy_fscase_stage(S, in, Ld, band1);
S.hot = dy_hot_check(S, in);                           % hot, cycle-consistent Goodman of both cases
fprintf('   hot A357 Goodman: slide shell %s, flange %s (break-even hot loss k_T* %s); first-stage case %.2f\n', ...
        mat2str(round(S.hot.case_shell, 2)), mat2str(round(S.hot.case_flange, 2)), mat2str(round(S.hot.kT_star, 3)), S.hot.fs);

% 4. tables, plots, ring data for the drawing
writetable(W.modes, fullfile(out_dir, 'web_modes.csv'));
wi = W.inband;  wi.s_mu = [];                         % (the mu spread is a matrix column; kept in step36.mat)
writetable(wi, fullfile(out_dir, 'web_inband.csv'));
writetable(W.ring_trade, fullfile(out_dir, 'ring_trade.csv'));
% friction spread: s of the rule families at each mu, the worse of the rim and teeth-as-mass models
ir = find(rule);  mus = unique([in.ring.mu, in.ring.mu_range]);  smu = zeros(numel(mus), numel(ir));
for k = 1:numel(mus)
    Gk = dy_ring(in, W, frot2, Ar, Rs.ie, mus(k));  Gtk = dy_ring(in, Wt, frot2, Ar, Rs.ie, mus(k));
    stk = Gtk.s(jt(ir));  stk(other(ir)) = NaN;
    smu(k, :) = max(Gk.s(ir)', stk', 'omitnan');
end
pl = {'in', 'out'};
S.web_mu = array2table([mus(:), smu], 'VariableNames', ...
                       [{'mu'}, arrayfun(@(j) sprintf('n%d_%s', W.inband.n(j), pl{1 + W.inband.oop(j)}), ir', 'UniformOutput', false)]);
writetable(S.web_mu, fullfile(out_dir, 'ring_mu.csv'));
writetable(table(P.f_all(:), P.kind(:), 'VariableNames', {'f', 'kind'}), fullfile(out_dir, 'planet_modes.csv'));
writetable(table((1:3)', [P.h.Kv_sp]', [P.h.Kv_pr]', [P.h.SF_sp]', [P.h.SF_pr]', [P.h.sig_pk]', [P.h.sf_rim]', ...
                 'VariableNames', {'h', 'Kv_sp', 'Kv_pr', 'SF_sp', 'SF_pr', 'sig_rim', 'sf_rim'}), fullfile(out_dir, 'planet_kv.csv'));
S.ring_data = dy_ring_export(in, W, pw, fullfile('cad', 'params', 'gear2_ring.txt'));
save(fullfile(out_dir, 'step36.mat'), 'S');
for lang = {'tr', 'en'}
    dy_plots(S, lang{1}, out_dir);
end
end

function j = near(fa, na, fb, nb)
% for each family a, the family b with the same n and the nearest frequency
j = zeros(size(fa));
for k = 1:numel(fa)
    c = find(nb == na(k));
    if isempty(c), c = find(mod(nb, 100) == mod(na(k), 100)); end   % no family of that plane: same n
    if isempty(c), c = (1:numel(fb))'; end
    [~, i] = min(abs(fb(c) - fa(k)));
    j(k) = c(i);
end
end

function sf = goodman(in, O, v)
% web DYN-03 safety factor: once-per-revolution alternating plus the vibratory stress v [MPa] against the
% Pyrowear 53 core endurance, mean stress against its ultimate (Goodman); nominal at the web roots x Kt, and per
% point on the boundary
se = in.sigma_e.P53;  su = in.su.P53;  Kt = in.Kt_fillet;
sf = min(min(1 ./ ((O.far_a + v) / se + O.far_m / su)), 1 / ((Kt * O.root_alt + v) / se + Kt * O.root_mean / su));
end

function Rs = ring_select(in, W, Wt, frot)
% lightest ring at each groove offset meeting s <= s_max on the worst bracket (both shuttle phases, the rim and
% the teeth-as-mass models, every in-band crossing) for the families that set the Goodman factor, with the
% Goodman factor >= 1 with the ring; a further-out groove is taken only if it saves in.ring.e_gain
rr = in.ring;
hs = rr.h(rr.rho * rr.h * rr.w * 2 * pi * W.fam.Rg <= rr.m_max);
trade = [];
pick = [];
for ie = 1:numel(rr.e_list)
    found = [];
    for h = hs
        A = h * rr.w;
        G1 = dy_ring(in, W, frot, A, ie, rr.mu);  G2 = dy_ring(in, Wt, frot, A, ie, rr.mu);
        r1 = G1.slips & W.inband.sig_bare >= rr.rule_frac * max(W.inband.sig_bare);
        r2 = G2.slips & Wt.inband.sig_bare >= rr.rule_frac * max(Wt.inband.sig_bare);
        smax = max([G1.s(r1); G2.s(r2); 0]);
        stmax = max([G1.s_trav(r1); G2.s_trav(r2); 0]);
        sf = min(goodman(in, W.once_rev, max(G1.s .* W.inband.sig_bare)), goodman(in, Wt.once_rev, max(G2.s .* Wt.inband.sig_bare)));
        m = rr.rho * A * 2 * pi * W.fam.Rg;
        trade = [trade; rr.e_list(ie) * 1e3, h * 1e3, rr.w * 1e3, m, smax, stmax, sf]; %#ok<AGROW>
        if isempty(found) && smax <= rr.s_max && sf >= 1
            found = struct('mass', m, 'h', h, 'e', rr.e_list(ie), 'ie', ie, 's_max', smax, 'sf', sf);
        end
    end
    if ~isempty(found) && (isempty(pick) || found.mass <= pick.mass - rr.e_gain)
        pick = found;
    end
end
if isempty(pick)                                      % rule out of reach: the heaviest ring at the first offset
    h = max(hs);
    G1 = dy_ring(in, W, frot, h * rr.w, 1, rr.mu);
    r1 = G1.slips & W.inband.sig_bare >= rr.rule_frac * max(W.inband.sig_bare);
    pick = struct('mass', rr.rho * h * rr.w * 2 * pi * W.fam.Rg, 'h', h, 'e', rr.e_list(1), 'ie', 1, ...
                  's_max', max([G1.s(r1); 0]), 'sf', goodman(in, W.once_rev, max(G1.s .* W.inband.sig_bare)));
end
Rs = pick;
Rs.trade = array2table(trade, 'VariableNames', {'e_mm', 'h_mm', 'w_mm', 'mass_kg', 's_max', 's_trav_max', 'sf_goodman'});
end

function Rs = ring_eval(in, W, Wt, frot, h, ie)
% a given ring (thickness h, groove ie) on the models that carry it: the worst s of the rule families and the
% Goodman factor, with the trade table of ring_select
rr = in.ring;
Rs = ring_select(in, W, Wt, frot);
A = h * rr.w;
G1 = dy_ring(in, W, frot, A, ie, rr.mu);  G2 = dy_ring(in, Wt, frot, A, ie, rr.mu);
r1 = G1.slips & W.inband.sig_bare >= rr.rule_frac * max(W.inband.sig_bare);
r2 = G2.slips & Wt.inband.sig_bare >= rr.rule_frac * max(Wt.inband.sig_bare);
Rs.h = h;  Rs.e = rr.e_list(ie);  Rs.ie = ie;  Rs.mass = rr.rho * A * 2 * pi * W.fam.Rg;
Rs.s_max = max([G1.s(r1); G2.s(r2); 0]);
Rs.sf = min(goodman(in, W.once_rev, max(G1.s .* W.inband.sig_bare)), goodman(in, Wt.once_rev, max(G2.s .* Wt.inband.sig_bare)));
end
