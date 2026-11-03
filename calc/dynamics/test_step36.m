% TEST_STEP36  Compares the step 3.6 results with calc/tests/step36_test_cases.csv.
%   Run from the repo root after run_step36 (it writes calc/results/step36/step36.mat):
%     addpath('calc/dynamics');  test_step36
%   Expected values come from an independent Python implementation
%   (calc/reference/step36_reference.py) of the closed forms:
%   - mesh frequencies, bands, static and dynamic mesh forces;
%   - the shuttle of the contact-line centroid (counted strip by strip);
%   - the blank mass (Pappus);
%   - the thin-ring bending frequencies (check of the harmonic element);
%   - the ring formulas (resonance speeds, stick limit, families that slip,
%     friction energy, the travelling-wave energy balance), the rim ratio
%     under the groove;
%   - the Goodman factors at the web roots, of the planetary case and of
%     the first-stage case;
%   - the K_v to S_F rescaling and the TE2 sensitivity of the planet, the
%     cycle maximum of von Mises (against a sweep of the cycle), the
%     planet-pass amplitude (half the longest chord, against a brute-force
%     search on a two-harmonic case).
%   Self-checks with expected value 0: the slide ties (u equal at the pairs)
%   and the first-stage case reaction (bolt faces against the applied
%   pinion force). A missing value counts as a failure.
%   The finite element models are checked against the step 2.8 3-D models
%   (web frequencies, bare case mass and modes), the planet modes against an
%   independent exact-tensor model, against the CATIA case volume,
%   between modal and direct solutions, and against the 3-D toolbox model
%   of the web.

T = readtable('calc/tests/step36_test_cases.csv', 'TextType', 'string');
X = load(fullfile('calc', 'results', 'step36', 'step36.mat'));
S = X.S;
sp = S.speed;  W = S.web;  W0 = S.web_bare;  C = S.case;  ib = W.inband;  Ld = S.web_Ld;
res = struct();
res.TC93 = struct('fm1', sp.fm1, 'frot2', sp.frot2, 'band1_lo', sp.band1(1), 'band1_hi', sp.band1(2), 'fmP', sp.fmP, ...
                  'bandP3_lo', sp.bandsP(3, 1), 'bandP3_hi', sp.bandsP(3, 2), ...
                  'Fb1', Ld.Fb(1), 'Fb2', Ld.Fb(2), 'F_t', Ld.Fs(1), 'F_r', Ld.Fs(2), 'F_a', Ld.Fs(3), ...
                  'dZ1', S.shuttle.dZ(1), 'dZ2', S.shuttle.dZ(2), ...
                  'F_dyn_1x', S.planet.h(1).F_te(1), 'F_dyn_2x', S.planet.h(2).F_te(1), 'F_dyn_3x', S.planet.h(3).F_te(1), ...
                  'Fp_1x', S.planet.h(1).F_te(2), 'Fp_2x', S.planet.h(2).F_te(2), 'Fp_3x', S.planet.h(3).F_te(2));
res.TC94 = struct('m_blank', W0.mass, 'm_teeth', S.web_teeth.mass);
i0 = W0.inband;
for k = find(i0.oop & i0.h == 1)'                     % bare out-of-plane 1x families against step 2.8
    q = sprintf('f_n%d', i0.n(k));
    if ~isfield(res.TC94, q), res.TC94.(q) = i0.f(k); end
end
R = S.ring_check;
for k = 1:numel(R.n)
    res.TC95.(sprintf('f_in_n%d', R.n(k))) = R.f_in(k);
    res.TC95.(sprintf('f_out_n%d', R.n(k))) = R.f_out(k);
end
c = W.check;  c3 = S.web_check3d;  ra = W0.ref_axial;
res.TC96 = struct('sig0_modal_2d', c.sig0_modal, 'Win_modal_2d', c.Win_modal, 'I_modal_2d', c.I_modal, ...
                  'sig0_modal_3d', c3.modal.sig0, 'Win_modal_3d', c3.modal.Win, ...
                  'f_3d', c3.f, 'sig0_3d', c3.direct.sig0, 'Win_3d', c3.direct.Win);
g = W.ring;  D = S.ring_data;
res.TC97 = struct('ring_mass', g.mass, 'q100', g.q100, 'n_slip', sum(ib.slips), 'n_slip_trav', sum(ib.slips_trav), ...
                  'n_rule', sum(ib.rule), 'sR_ht', D.sR_ht, 'rim_beyond', D.rim_beyond);
keys = famkeys(ib);
for k = find(ib.slips)'                                % the families that slip
    nk = keys{k};
    res.TC97.(['x_lo_' nk]) = ib.x_lo(k);
    res.TC97.(['x_hi_' nk]) = ib.x_hi(k);
    res.TC97.(['u_stick_hi_' nk]) = ib.u_stick_hi_um(k);
    res.TC97.(['Ef_Win_' nk]) = ib.Ef_over_Win(k);
    res.TC97.(['s_trav_' nk]) = ib.s_trav(k);
end
fb = C.f_bare;
res.TC98 = struct('m_case', C.mass, 'f_case_1', fb(1), 'f_case_2', fb(2), 'f_case_3', fb(3), 'f_case_4', fb(4), ...
                  'sf_bound_1x', C.band(1).sf_bound, 'sf_bound_2x', C.band(2).sf_bound, 'sf_bound_3x', C.band(3).sf_bound, ...
                  'sf_worst_1x', C.band(1).sf_worst, 'sf_worst_2x', C.band(2).sf_worst, 'sf_worst_3x', C.band(3).sf_worst, ...
                  'sf_flange_1x', C.band(1).sf_flange, 'sf_flange_2x', C.band(2).sf_flange, 'sf_flange_3x', C.band(3).sf_flange, ...
                  'sf_fscase', S.fscase.sf, 'sf_root_bare', S.web_sf_root(1), 'sf_root_ring', S.web_sf_root(2), ...
                  'tie_slide', C.tie_res, 'hot_sf_fscase', S.hot.fs, ...
                  'hot_sf_worst_1x', S.hot.case_shell(1), 'hot_sf_worst_2x', S.hot.case_shell(2), 'hot_sf_worst_3x', S.hot.case_shell(3), ...
                  'hot_sf_flange_1x', S.hot.case_flange(1), 'hot_sf_flange_2x', S.hot.case_flange(2), 'hot_sf_flange_3x', S.hot.case_flange(3), ...
                  'kT_star_1x', S.hot.kT_star(1), 'kT_star_2x', S.hot.kT_star(2), 'kT_star_3x', S.hot.kT_star(3), ...
                  'fs_reaction', max(abs(S.fscase.check.reaction + S.fscase.check.applied)) / max(abs(S.fscase.check.applied)));
% planet: modes against an independent exact-tensor model, the K_v to S_F rescaling, the TE2 sensitivity; the
% cycle maximum of von Mises against a sweep of the cycle
P = S.planet;  kd = {'rx', 'y', 'ry', 'spin'};
for k = 1:4
    i = find(strcmp(P.kind, kd{k}), 1);
    res.TC99.(['f_' kd{k}]) = P.f_all(i);
end
for h = 1:3
    res.TC99.(sprintf('SF_sp_%dx', h)) = P.h(h).SF_sp;
    res.TC99.(sprintf('SF_pr_%dx', h)) = P.h(h).SF_pr;
end
res.TC99.Kv2_sens_sp = S.planet_sens.Kv2_sp;  res.TC99.Kv2_sens_pr = S.planet_sens.Kv2_pr;
res.TC99.vm_cycle = dy_vm_cycle([10 -4 2 3 -1 0.5], [-3 6 1 -2 2 1]);
% planet-pass amplitude on a two-harmonic hand case: s_r = 10 cos 4t + 3 cos 8t, tau_rz = 4 sin 4t, one period
tp = (0:29)' * (pi / 2) / 30;
Sp = zeros(30, 1, 6);  Sp(:, 1, 1) = 10 * cos(4 * tp) + 3 * cos(8 * tp);  Sp(:, 1, 4) = 4 * sin(4 * tp);
res.TC99.pass_amp = dy_pass_amp(Sp);
cc = S.couple_check;                                  % two-DOF benchmark of the coupling by receptance
for k = 1:numel(cc.f)
    res.TC99.(sprintf('couple_formula_%d', cc.f(k))) = cc.F_formula(k);
    res.TC99.(sprintf('couple_direct_%d', cc.f(k))) = cc.F_direct(k);
end

nfail = 0;
nmiss = 0;
for i = 1:height(T)
    tc = char(T.tc(i));
    q = matlab.lang.makeValidName(char(T.quantity(i)));
    if ~isfield(res, tc) || ~isfield(res.(tc), q) || isempty(res.(tc).(q))
        fprintf('MISSING %s %s\n', tc, q);
        nmiss = nmiss + 1;
        continue
    end
    v = res.(tc).(q);
    e = T.expected(i);
    if e == 0, ok = abs(v) <= T.tol(i); else, ok = abs(v / e - 1) <= T.tol(i); end
    verdict = 'PASS';
    if ~ok
        nfail = nfail + 1;
        verdict = 'FAIL';
    end
    fprintf('%-5s %-22s %14.6g %14.6g (tol %.1f%%)  %s\n', tc, q, v, e, 100 * T.tol(i), verdict);
end
nfail = nfail + nmiss;                                % a missing value counts as a failure
fprintf('%d values, %d failures (%d of them missing)\n', height(T), nfail, nmiss);

function keys = famkeys(ib)
% n<n>_<o|i><h>: nodal diameters, out of plane or in plane, mesh harmonic; 'b' for a second family alike
keys = cell(height(ib), 1);
pl = 'io';
for k = 1:height(ib)
    keys{k} = sprintf('n%d_%s%d', ib.n(k), pl(ib.oop(k) + 1), ib.h(k));
    if any(strcmp(keys(1:k - 1), keys{k})), keys{k} = [keys{k} 'b']; end
end
end
