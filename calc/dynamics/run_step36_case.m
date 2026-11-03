function S = run_step36_case(out_dir, stages)
%RUN_STEP36_CASE  Rerun the case stages of step 3.6 on a saved step36.mat (the planet and web results kept).
%   S = run_step36_case()                  the planetary case on calc/results/step36 (about 30 minutes)
%   S = run_step36_case(out_dir)
%   S = run_step36_case(out_dir, stages)   stages: any of 'case', 'fscase', 'fs_post', 'hot' (default {'case'})
%
%   'fs_post' reapplies the first-stage case strength check (dy_fscase_sf) to
%   the saved S.fscase without a re-solve (its inputs do not enter the solve).
%
%   Run from the repo root with calc/dynamics, calc/gear_detail,
%   calc/shafts_bearings, calc/housing and calc/structures on the path. Loads
%   step36.mat, recomputes the planetary case stage (dy_case_stage) and/or
%   the first-stage case stage (dy_fscase_stage) with the current code and
%   inputs, rewrites their CSV tables, the plots and step36.mat (to
%   out_dir), and writes its own log (summary_<stages>.txt). The planet,
%   web and ring results are those of the last run_step36. Two stages can
%   run in parallel MATLAB processes on copies of step36.mat.
%   Source: Phase 3 report, Section 3.6.

if nargin < 1 || isempty(out_dir)
    out_dir = fullfile('calc', 'results', 'step36');
end
if nargin < 2 || isempty(stages), stages = {'case'}; end
if ischar(stages), stages = {stages}; end
X = load(fullfile(out_dir, 'step36.mat'));  S = X.S;
diary(fullfile(out_dir, ['summary_' strjoin(stages, '_') '.txt']));
c_diary = onCleanup(@() diary('off'));
fprintf('\n== Stage rerun (run_step36_case: %s, %s)\n', strjoin(stages, ', '), datestr(now, 'yyyy-mm-dd HH:MM'));
in = dy_inputs();  gi = gd_inputs();  M = gd_meshes(gi);  hi = hs_inputs();
if any(strcmp(stages, 'case'))
    pp = struct('SF24', in.planet24.SF, 'Kv24', in.planet24.Kv);
    S = dy_case_stage(S, in, gi, M, hi, S.planet, pp, S.speed.bandsP, out_dir);
end
if any(strcmp(stages, 'fscase'))
    Ld = S.web_Ld;
    if ~isfield(Ld, 'rw'), Ld.rw = [M(1).g.dw1, M(1).g.dw2] / 2000; end   % working pitch radii [m]
    S = dy_fscase_stage(S, in, Ld, S.speed.band1);
end
if any(strcmp(stages, 'fs_post'))
    sf_was = S.fscase.sf;
    [S.fscase.sf, S.fscase.sf_hot] = dy_fscase_sf(S.fscase, in, st_inputs());
    fprintf('   first-stage case strength reapplied (steady bound %.1f MPa): peak %.2f MPa, Goodman %.2f (was %.2f), hot %.2f\n', ...
            in.fs_sm, S.fscase.sig_pk, S.fscase.sf, sf_was, S.fscase.sf_hot);
end
if any(ismember(stages, {'case', 'fscase', 'fs_post', 'hot'}))
    S.hot = dy_hot_check(S, in);
    fprintf(['   hot A357 Goodman (planet pass / mesh-only cycles, %.0f%% hot loss): slide shell %s (coded %s), flange %s ' ...
             '(coded %s), break-even hot loss k_T* %s; first-stage case %.2f (coded %.2f)\n'], 100 * (1 - in.hot.k_T), ...
            mat2str(round(S.hot.case_shell, 2)), mat2str(round(S.hot.case_shell_coded, 2)), mat2str(round(S.hot.case_flange, 2)), ...
            mat2str(round(S.hot.case_flange_coded, 2)), mat2str(round(S.hot.kT_star, 3)), S.hot.fs, S.hot.fs_coded);
end
if ~isfield(S, 'ring_rule_met')
    S.ring_rule_met = S.web.ring.s_max <= in.ring.s_max && S.web.ring.sf_ring >= 1;
end
save(fullfile(out_dir, 'step36.mat'), 'S');
if any(strcmp(stages, 'case'))
    for lang = {'tr', 'en'}
        dy_plots(S, lang{1}, out_dir);
    end
end
end
