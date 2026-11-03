function S = dy_case_stage(S, in, gi, M, hi, P, pp, bandsP, out_dir)
%DY_CASE_STAGE  Step 3.6 case stage: the planetary case coupled to the planets, its brackets and Goodman, sensitivities.
%   S = dy_case_stage(S, in, gi, M, hi, P, pp, bandsP, out_dir)
%
%   Called by run_step36 and run_step36_case. in = dy_inputs, gi = gd_inputs,
%   M = gd_meshes(gi), hi = hs_inputs, P = dy_planet_frf output, pp = the
%   planet data of run_step36, bandsP = the 1x, 2x and 3x planetary bands.
%   Adds to S: case (dy_case_frf), planet_coupled (K_v,FE and S_F with the
%   planet coupled to the ring and case), couple_check (dy_couple_check),
%   planet_sens, case_sens, case_F; writes case_modes.csv, case_bands.csv,
%   case_brackets.csv, case_corners.csv, case_qs.csv and case_fillets.csv to
%   out_dir.
%   Source: Phase 3 report, Section 3.6 ("Case").

% 3. case: coupled to the planets through the ring-seat receptance; steady stress from a static MCT solve
stin = st_inputs();  Lst = st_loads(stin, gi);
in.cs.W1 = Lst.W1;  in.cs.thrust = stin.thrust;      % step 3.5 operating loads at MCT (1 g reactions, thrust)
Cc = dy_case_frf(in, hi.case, hi.mat(1), P, M(3).g.alpha_wt, bandsP, M(3).g.z2);
fprintf('\n== Planetary case (harmonic model, %d dof, %.3f kg), coupled to the planets by receptance, mesh phasing of %d teeth\n', ...
        Cc.n_dof, Cc.mass, M(3).g.z2);
for h = 1:3
    B = Cc.band(h);
    fprintf(['   %dx: %d-%d modes; mesh peak %.2f MPa at %.0f Hz (%s; mass layer %.2f), rim fixed %.2f (blocked ring %.2f); ', ...
             'steady %.1f, planet pass %.1f MPa; Goodman node by node, slide: base %.2f, worst %.2f (%s), flange %.2f; ', ...
             'rim %.2f, mass %.2f; with the 35.4 MPa bound %.2f; ring force coupled %.0f / blocked %.0f N; ', ...
             'coupled K_v,FE %.3f / %.3f\n'], h, B.n_modes, B.sig_pk, B.f_pk, B.worst, B.sig_mass, B.sig_base, B.sig_blocked, ...
            B.sig_steady, B.sig_pass, B.sf_base, B.sf_worst, B.worst_sf, B.sf_flange, B.sf_rim, B.sf_mass, B.sf_bound, ...
            B.F_coupled, B.F_blocked, B.Kv_sp, B.Kv_pr);
end
disp(Cc.brackets);
fprintf('   planet pass, max over the A357 nodes: rim %.1f, slide %.1f, mass %.1f MPa\n', ...
        max(Cc.brackets.sig_pass(contains(Cc.brackets.bracket, 'rim'))), ...
        max(Cc.brackets.sig_pass(contains(Cc.brackets.bracket, 'slide'))), ...
        max(Cc.brackets.sig_pass(contains(Cc.brackets.bracket, 'mass'))));
for j = 1:numel(Cc.var)
    v = Cc.var(j);
    for k = 1:numel(v.reentrant)
        e = v.reentrant(k);
        fprintf('   %s, re-entrant corner (%.1f, %.1f): raw mesh / pass / mean %.1f / %.1f / %.1f MPa, Kt x 2-4 mm %.1f / %.1f / %.1f MPa\n', ...
                v.label, e.rz, e.raw, e.fillet);
    end
    c = v.corner;
    for k = 1:numel(c.sf)
        fprintf('   %s, seat corner (%.1f, %.1f): mesh %.1f, pass %.1f, mean %.1f MPa, Goodman %.2f\n', v.label, c.rz(k, :), ...
                c.sa_mesh(k), c.sa_pass(k), c.sm(k), c.sf(k));
    end
end
qs = Cc.qs;  [qmin, iq] = min(qs.f_lowest ./ qs.f_3pass);
fprintf('   quasi-static planet pass: lowest n = 4k mode / (3 n f_c) at least %.1f (n %d)\n', qmin, qs.n(iq));
S.planet_coupled = struct('Kv_sp', [Cc.band.Kv_sp], 'Kv_pr', [Cc.band.Kv_pr]);
S.planet_coupled.SF_sp = pp.SF24(1) * pp.Kv24(1) ./ S.planet_coupled.Kv_sp;
S.planet_coupled.SF_pr = pp.SF24(2) * pp.Kv24(2) ./ S.planet_coupled.Kv_pr;
fprintf('   planet coupled to the ring and case: S_F %s (sun-planet) / %s (planet-ring), 1x 2x 3x\n', ...
        mat2str(round(S.planet_coupled.SF_sp, 2)), mat2str(round(S.planet_coupled.SF_pr, 2)));
S.couple_check = dy_couple_check([3000 5000 6500 7500 9000 12000]);
fprintf('   two-DOF check of the coupling: formula %s, direct %s N/m\n', mat2str(round(S.couple_check.F_formula)), ...
        mat2str(round(S.couple_check.F_direct)));
S.case = Cc;
% planet and case sensitivities (linear): planet 2x at TE2 = in.TE2_sens, and excitation x2
k2 = in.TE2_sens / in.TE_planet(2);
S.planet_sens = struct('Kv2_sp', 1 + (P.h(2).Kv_sp - 1) * k2, 'Kv2_pr', 1 + (P.h(2).Kv_pr - 1) * k2);
S.planet_sens.SF2_sp = pp.SF24(1) * pp.Kv24(1) / S.planet_sens.Kv2_sp;
S.planet_sens.SF2_pr = pp.SF24(2) * pp.Kv24(2) / S.planet_sens.Kv2_pr;
S.planet_sens.Kv_x2 = 1 + 2 * ([max([P.h.Kv_sp]), max([P.h.Kv_pr])] - 1);
S.planet_sens.SF_x2 = pp.SF24 .* pp.Kv24 ./ S.planet_sens.Kv_x2;
S.case_sens.sig_x2 = 2 * [Cc.band.sig_pk];   % linear in the excitation
fprintf('planet at TE2 %.2f um: K_v,FE %.3f / %.3f, S_F %.2f / %.2f; excitation x2: K_v %s, S_F %s; case x2 %s MPa\n', ...
        in.TE2_sens, S.planet_sens.Kv2_sp, S.planet_sens.Kv2_pr, S.planet_sens.SF2_sp, S.planet_sens.SF2_pr, ...
        mat2str(round(S.planet_sens.Kv_x2, 3)), mat2str(round(S.planet_sens.SF_x2, 2)), mat2str(round(S.case_sens.sig_x2, 1)));
S.case_F = arrayfun(@(h) max(P.h(h).Fd_pr), 1:3);    % largest ring-mesh force of one planet per band [N]
Cc = S.case;
writetable(Cc.modes, fullfile(out_dir, 'case_modes.csv'));
writetable(table((1:3)', [Cc.band.sig_base]', [Cc.band.sig_blocked]', [Cc.band.sig_pk]', [Cc.band.f_pk]', {Cc.band.worst}', ...
                 [Cc.band.sig_mass]', [Cc.band.sig_flange]', [Cc.band.sig_steady]', [Cc.band.sig_pass]', [Cc.band.sf_base]', ...
                 [Cc.band.sf_worst]', {Cc.band.worst_sf}', [Cc.band.sf_flange]', [Cc.band.sf_rim]', [Cc.band.sf_mass]', ...
                 [Cc.band.sf_bound]', [Cc.band.F_coupled]', [Cc.band.F_blocked]', [Cc.band.Kv_sp]', [Cc.band.Kv_pr]', ...
                 'VariableNames', {'h', 'sig_base', 'sig_blocked', 'sig_env', 'f_pk', 'worst', 'sig_mass', 'sig_flange', ...
                 'sig_steady', 'sig_pass', 'sf_base', 'sf_worst', 'worst_sf', 'sf_flange', 'sf_rim', 'sf_mass', 'sf_bound', ...
                 'F_coupled', 'F_blocked', 'Kv_sp_coupled', 'Kv_pr_coupled'}), fullfile(out_dir, 'case_bands.csv'));
Bt = Cc.brackets;  Bt.pass_r_mm = Bt.pass_rz_mm(:, 1);  Bt.pass_z_mm = Bt.pass_rz_mm(:, 2);  Bt.pass_rz_mm = [];
writetable(Bt, fullfile(out_dir, 'case_brackets.csv'));
rr = {};
for j = 1:numel(Cc.var)
    v = Cc.var(j);
    for k = 1:numel(v.reentrant)
        e = v.reentrant(k);
        rr(end + 1, :) = {v.label, 'reentrant', e.rz(1), e.rz(2), e.raw(1), e.raw(2), e.raw(3), e.fillet(1), e.fillet(2), ...
                          e.fillet(3), NaN}; %#ok<AGROW>
    end
    c = v.corner;
    for k = 1:numel(c.sf)
        rr(end + 1, :) = {v.label, 'seat', c.rz(k, 1), c.rz(k, 2), c.sa_mesh(k), c.sa_pass(k), c.sm(k), NaN, NaN, NaN, c.sf(k)}; %#ok<AGROW>
    end
end
writetable(cell2table(rr, 'VariableNames', {'bracket', 'corner', 'r_mm', 'z_mm', 'mesh', 'pass', 'mean', 'mesh_fillet', ...
                                            'pass_fillet', 'mean_fillet', 'sf'}), fullfile(out_dir, 'case_corners.csv'));
writetable(Cc.qs, fullfile(out_dir, 'case_qs.csv'));
if isfield(in.cs, 'fillets'), writetable(dy_case_fillets(Cc, in), fullfile(out_dir, 'case_fillets.csv')); end
end
