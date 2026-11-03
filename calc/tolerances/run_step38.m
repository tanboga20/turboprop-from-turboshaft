function S = run_step38(out_dir, parts)
%RUN_STEP38  Step 3.8: datums and geometric tolerances, thermal map, stack-ups, fits, splines, gear grades.
%   S = run_step38()                 full run, results in calc/results/step38
%   S = run_step38(out_dir)
%   S = run_step38(out_dir, parts)   parts: any of 'thermal', 'gears', 'datums', 'stack', 'fits', 'splines'
%
%   Run from the repo root with calc/tolerances and calc/gear_detail on the
%   path. Writes the tables (EN and TR text) to manufacturing/, the figures
%   in Turkish and English to docs/figures/step38 and step38.mat to
%   out_dir. A part that is not run keeps its result from an earlier
%   step38.mat.
%   Source: Phase 3 report, Section 3.8.

if nargin < 1 || isempty(out_dir)
    out_dir = fullfile('calc', 'results', 'step38');
end
if nargin < 2, parts = {'thermal', 'gears', 'datums', 'stack', 'fits', 'splines'}; end
if ischar(parts), parts = {parts}; end
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
fig_dir = fullfile('docs', 'figures', 'step38');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end
mat = fullfile(out_dir, 'step38.mat');
S = struct();
if exist(mat, 'file'), X = load(mat);  S = X.S; end
in = tl_inputs();
S.in = in;
diary(fullfile(out_dir, ['summary_' strjoin(parts, '_') '.txt']));
c_diary = onCleanup(@() diary('off'));
fprintf('\n== Step 3.8 (%s, %s)\n', strjoin(parts, ', '), datestr(now, 'yyyy-mm-dd HH:MM'));

if any(strcmp(parts, 'thermal')) || ~isfield(S, 'th')
    Th = tl_thermal(in);
    fprintf('\n== E2 Thermal map (lumped, TBR) [degC]\n');
    disp(Th.map);
    d = Th.tr.gear2 - Th.tr.case_f;  [dm, i] = max(d);
    fprintf('   cold start: oil feeds the jets at %.1f degC after %.1f min; gear 2 leads the first-stage case by up to %.1f K at %.1f min\n', ...
            in.th.cold.T_ok, in.th.cold.t_ok / 60, dm, Th.tr.t(i) / 60);
    S.th = Th;
    M = Th.map;  M = addvars(M, string(in.th.states'), string(in.th.states_tr'), 'Before', 1, ...
                             'NewVariableNames', {'state_en', 'state_tr'});
    writetable(M, fullfile('manufacturing', 'thermal_map_v1.csv'));
    for lang = {'en', 'tr'}
        tl_plot_thermal(Th, in, lang{1}, out_dir);
        copyfile(fullfile(out_dir, ['thermal_' lang{1} '.png']), fig_dir);
    end
end

if any(strcmp(parts, 'gears')) || ~isfield(S, 'gears')
    G = tl_gears(in);
    fprintf('\n== E6 Gear accuracy (ISO 1328-1:2013) [um]\n');
    disp(G.T(:, 1:21));
    S.gears = G;
    writetable(G.T, fullfile('manufacturing', 'gear_accuracy_v1.csv'));
end

if any(strcmp(parts, 'datums'))
    D = tl_datums(in, S.gears);
    fprintf('\n== E1 Datums and geometric tolerances (ASME Y14.5-2018) [mm]\n');
    disp(D.T(:, {'part', 'feature_en', 'characteristic', 'tolerance_mm', 'datums'}));
    S.datums = D;
    writetable(D.T, fullfile('manufacturing', 'gdt_v1.csv'));
end

if any(strcmp(parts, 'stack'))
    M = gd_meshes(gd_inputs());
    B = tl_backlash(in, S.th, M);
    fprintf('\n== E3a First-stage normal backlash [mm] (tolerances +-3 sigma normal; worst case all limits)\n');
    disp(B.s1);
    fprintf('   at 20 degC: worst-case min %.4f, mean %.4f, worst-case max %.4f\n', B.s1_nom20);
    fprintf('   cold-start transient: thermal change down to %.4f at %.1f min; min %.4f (worst case), %.4f (MC -3 sigma); max over all %.4f\n', ...
            B.s1_tr.dj_min, B.s1_tr.t_min / 60, B.s1_tr.j_min_wc_min, B.s1_tr.j_min_mc_min, B.s1_tr.j_max_all);
    fprintf('\n== E3b Planetary backlash [mm] (ring bore change from the seat fit)\n');
    disp(B.pl);
    fprintf('   cold-start transient minima: sun-planet %.4f, planet-ring %.4f\n', B.pl_tr.j_sp_min_min, B.pl_tr.j_pr_min_min);
    K = tl_kgamma(in);
    fprintf('\n== E3b K_gamma (STR-07 limit %.2f at P99, STR-02 P90)\n', K.limit);
    disp(K.T);
    A = tl_axial(in, S.th);
    fprintf('\n== E3c Axial [mm]: shaft stretch at the limit pull %.4f\n', A.stretch);
    disp(A.T);
    fprintf(['   transient minima: lip margin %.3f, tube gap %.3f; never touching: lip %.3f, tube %.3f; ' ...
             'largest travel to catch: lip %.3f, tube %.3f; planet float %.2f-%.2f, sun float %.2f-%.2f\n'], ...
            A.tr.lip_margin_min, A.tr.tube_gap_min, A.min_lip, A.min_tube, A.max_lip_travel, A.max_tube_travel, ...
            A.planet_float, A.sun_float);
    S.backlash = B;  S.kgam = rmfield(K, 'all');  S.kgam_all = K.all;  S.axial = A;
    T1 = B.s1;  T1 = addvars(T1, string(in.th.states'), string(in.th.states_tr'), 'Before', 1, ...
                            'NewVariableNames', {'state_en', 'state_tr'});
    writetable(T1, fullfile('manufacturing', 'stack_backlash_v1.csv'));
    T2 = A.T;  T2 = addvars(T2, string(in.th.states'), string(in.th.states_tr'), 'Before', 1, ...
                           'NewVariableNames', {'state_en', 'state_tr'});
    writetable(T2, fullfile('manufacturing', 'stack_axial_v1.csv'));
    writetable(K.T, fullfile('manufacturing', 'stack_kgamma_v1.csv'));
    for lang = {'en', 'tr'}
        tl_plot_stack(B, K, in, lang{1}, out_dir);
        copyfile(fullfile(out_dir, ['stack_' lang{1} '.png']), fig_dir);
    end
end

if any(strcmp(parts, 'fits'))
    F = tl_fits(in, S.th);
    fprintf('\n== E4 Bearing fits and operating clearance [um] (ISO 286 classes, bearings ISO 492 P5)\n');
    disp(F.brg(:, {'bearing', 'state', 'shaft_class', 'housing_class', 'inner_int_min_um', 'inner_int_max_um', ...
                   'outer_int_min_um', 'outer_int_max_um', 'outer_raceway_change_um', 'clearance_min_um', 'clearance_max_um'}));
    fn = fieldnames(F.clear_tr);
    for k = 1:numel(fn)
        fprintf('   %s: smallest clearance in the cold-start transient %.1f um at %.1f min\n', fn{k}, F.clear_tr.(fn{k}));
    end
    fprintf('\n== E4 Liners in the A357 bosses\n');
    disp(F.liner);
    p = F.pin;
    fprintf(['\n== E4 Planet pins %s: bore %+d/%+d, pin %+d/%+d um; radial interference %.1f-%.1f um; pressure %.0f-%.0f MPa; ' ...
             'plate hoop %.0f-%.0f MPa; holding %.1f-%.1f kN (axial load %.1f kN); change -40 / 157 degC %+.1f / %+.1f um\n'], ...
            p.fit, p.bore, p.pin, p.delta_um, p.p, p.hoop_plate, p.F_hold / 1e3, p.F_ax / 1e3, p.dT_change_um);
    fprintf('\n== E4 Ring gear seat: %s; radial interference at 20 degC %.0f-%.0f um (MCT needs %.1f, LD-02 %.1f)\n', ...
            F.seat_cls, F.seat_d20, F.seat_need, F.seat_need_02);
    disp(F.seat);
    fprintf(['   cold-soak hoop %.1f MPa against %.0f; part-power Goodman of the shell at the 50%% cruise %.2f / %.2f ' ...
             '(smallest / largest fit; MCT without the fit %.3f); assembly: case above %.0f degC (A357-T6 limit %.0f degC)\n'], ...
            F.seat_cold_hoop, F.seat_allow, F.seat_goodman_cruise, F.seat_goodman_mct_nofit, F.T_assy, F.T_age);
    S.fits = F;
    writetable(F.brg, fullfile('manufacturing', 'fits_bearings_v1.csv'));
    writetable(F.liner, fullfile('manufacturing', 'fits_liners_v1.csv'));
    Ts = F.seat;  Ts = addvars(Ts, string(in.th.states'), string(in.th.states_tr'), 'Before', 1, ...
                              'NewVariableNames', {'state_en', 'state_tr'});
    writetable(Ts, fullfile('manufacturing', 'fits_ring_seat_v1.csv'));
    for lang = {'en', 'tr'}
        tl_plot_fits(F, in, lang{1}, out_dir);
        copyfile(fullfile(out_dir, ['fits_' lang{1} '.png']), fig_dir);
    end
end

if any(strcmp(parts, 'splines'))
    P = tl_splines(in, S.th);
    fprintf('\n== E5 Splines (ISO 4156-1): circular clearance [um] (negative: interference)\n');
    disp(P.T);
    S.splines = P;
    writetable(P.T, fullfile('manufacturing', 'fits_splines_v1.csv'));
end

if all(isfield(S, {'datums', 'gears', 'fits', 'splines', 'axial'}))
    Tt = tl_drawing_table(in, S.datums, S.gears, S.fits, S.splines, S.axial);
    fprintf('\n== Tolerance and fits table for the 3.9 drawings: %d callouts (manufacturing/tolerances_v1.csv)\n', height(Tt));
    S.table = Tt;
    writetable(Tt, fullfile('manufacturing', 'tolerances_v1.csv'));
end

save(mat, 'S');
end
