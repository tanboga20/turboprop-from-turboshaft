function S = run_step37(out_dir, parts)
%RUN_STEP37  Step 3.7: fault tree, FMEA, critical parts, damage tolerance and fire.
%   S = run_step37()                 full run, results in calc/results/step37
%   S = run_step37(out_dir)
%   S = run_step37(out_dir, parts)   parts: any of 'fta', 'fmea', 'parts', 'dt', 'fire' (default all)
%
%   Run from the repo root with calc/safety on the path. Writes the CSV
%   tables and plots in Turkish and English to out_dir and step37.mat; the
%   committed tables go to safety/ and the figures to docs/figures/step37.
%   A part that is not run keeps its result from an earlier step37.mat.
%   Source: Phase 3 report, Section 3.7.

if nargin < 1 || isempty(out_dir)
    out_dir = fullfile('calc', 'results', 'step37');
end
if nargin < 2, parts = {'fta', 'fmea', 'parts', 'dt', 'fire'}; end
if ischar(parts), parts = {parts}; end
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
fig_dir = fullfile('docs', 'figures', 'step37');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end
mat = fullfile(out_dir, 'step37.mat');
S = struct();
if exist(mat, 'file'), X = load(mat);  S = X.S; end
in = sf_inputs();
S.in = in;
addpath(fullfile('calc', 'torsion'), fullfile('calc', 'rgb_sizing'), fullfile('calc', 'agb_lube'), fullfile('calc', 'pt_shaft'));
diary(fullfile(out_dir, ['summary_' strjoin(parts, '_') '.txt']));
c_diary = onCleanup(@() diary('off'));
fprintf('\n== Step 3.7 (%s, %s)\n', strjoin(parts, ', '), datestr(now, 'yyyy-mm-dd HH:MM'));

if any(strcmp(parts, 'fta'))
    F = sf_fta(in);
    fprintf('\n== D1 Fault tree of propeller release (SAF-01), target %.1e per engine flight hour\n', in.target_h);
    fprintf(['   QJ1024: F(TBO) %.3e, H(TBO) %.3e, mean hazard %.3e /h, axial-loss share %.2f; oil loss %.1e /h x %.2f; ' ...
             'latent exposure %g h\n'], F.F_tbo_qj, F.H_tbo_qj, F.lam_qj, in.ft.qj.f_axial, in.ft.oil.lam, in.ft.oil.p_qj, ...
            in.ft.T_insp / 2);
    fprintf('   standby q = lambda T/2 + q_d: tube %.2e, lip %.2e\n', F.q);
    disp(F.T(:, 1:6));
    fprintf('   retention tube, post-failure phase (Ti-6Al-4V 90/80):\n');
    disp(F.tube(:, [1 3 4 5]));
    fprintf(['   largest cut set %.3e /h (each <= %.0e: margin x%.1f); sum %.3e /h (extremely remote band <= %.0e; ' ...
             'against %.0e: %s)\n'], F.P_max, in.target_h, F.margin, F.P_total, in.ft.band, in.target_h, ...
            string(F.P_total <= in.target_h));
    fprintf('   sensitivity, one assumption at a time:\n');
    disp(F.sens);
    S.fta = F;
    writetable(F.T, fullfile('safety', 'fta_cutsets_v1.csv'));
    writetable(F.sens, fullfile('safety', 'fta_sensitivity_v1.csv'));
    writetable(F.tube, fullfile('safety', 'fta_tube_check_v1.csv'));
    C = cell2table(in.ft.ccf, 'VariableNames', {'cause_en', 'cause_tr', 'feature_en', 'feature_tr', 'independence_en', ...
                                                'independence_tr'});
    writetable(C, fullfile('safety', 'fta_common_cause_v1.csv'));
    I = cell2table(in.ica, 'VariableNames', {'id', 'item_en', 'item_tr', 'interval', 'kind', 'source'});
    writetable(I, fullfile('safety', 'ica_items_v1.csv'));
    Lp = F.lip;  Q = F.qj;
    fprintf(['   nose cover P116: lip disc %.1f mm (clamped plate), lip %.0f / %.0f MPa at limit / ultimate (RF %.2f on F_tu), ' ...
             'bolts %.0f / %.0f MPa (%s); cover %.3f kg, P116 with collar and fasteners %.3f kg\n'], Lp.t, Lp.s_lim, Lp.s_ult, ...
            Lp.rf_ult, Lp.bolt_s_lim, Lp.bolt_s_ult, string(Lp.bolt_ok), Lp.m_cover, Lp.m_total);
    fprintf(['   lip rub in the run-down (2-D r-z): %.1f kJ, %.0f%% into the lip, hottest contact %.0f degC (one-sided %.0f degC, ' ...
             'molten above about 1,600 degC); hot yield %.0f MPa against the drag stress %.0f MPa: %s; q R7 %.1e\n'], ...
            Lp.E_rundown / 1e3, 100 * Lp.share_ti, Lp.T_max, Lp.T_max_onesided, Lp.sy_hot, Lp.s_drag, string(Lp.rundown_ok), Lp.q_rub7);
    fprintf(['   G1b: thrust floor %.1f kN (mission steps %s kN: %s); NJ1024 axial rating %.2f kN continuous, %.2f kN brief; ' ...
             'limp thrust %.1f kN; end play %.2f mm (seal contact %.1f mm); p_nj %.3f; R4 %.2e (branches %s); E7 p %.3f\n'], ...
            Q.floor / 1e3, mat2str(Q.mission_thrust / 1e3), string(Q.floor_ok), Q.nj_cont / 1e3, Q.nj_brief / 1e3, Q.limp / 1e3, ...
            Q.end_play, in.qj.nj.seal, Q.p_nj, Q.R4, mat2str(Q.branch, 3), Q.p_qj);
    fprintf('   SYS-06 roll-up %.2f kg (with the offsets %.2f kg; limit %.0f TBR)\n', Q.rollup, Q.rollup_net, in.ft.sys06.limit);
    disp(Q.phases);
    Tl = table(["lip disc thickness [mm]"; "lip stress at limit [MPa]"; "lip stress at ultimate [MPa]"; "lip reserve factor on F_tu at ultimate"; ...
                "bolt stress at limit [MPa]"; "bolt stress at ultimate [MPa]"; "cover mass [kg]"; "P116 total mass [kg]"; ...
                "run-down rub energy [kJ]"; "hottest contact temperature, shared contact [degC]"; ...
                "hottest temperature, one-sided [degC]"; "lip hot yield there [MPa]"; "lip drag stress [MPa]"; "q R7"; ...
                "thrust floor [kN]"; "NJ1024 continuous axial rating [kN]"; "NJ1024 brief axial rating [kN]"; "limp thrust [kN]"; ...
                "NJ1024 end play [mm]"; "p NJ fails given E4"; "R4"; "E7 p (three phases)"; "SYS-06 roll-up [kg]"; "SYS-06 with offsets [kg]"], ...
               ["dudak diski kalınlığı [mm]"; "sınır yükte dudak gerilmesi [MPa]"; "nihai yükte dudak gerilmesi [MPa]"; "nihai yükte F_tu emniyet katsayısı"; ...
                "sınır yükte cıvata gerilmesi [MPa]"; "nihai yükte cıvata gerilmesi [MPa]"; "kapak kütlesi [kg]"; "P116 toplam kütle [kg]"; ...
                "yavaşlamada sürtünme enerjisi [kJ]"; "ortak temasta en sıcak temas sıcaklığı [degC]"; ...
                "tek taraflı en yüksek sıcaklık [degC]"; "orada dudak sıcak akması [MPa]"; "dudak sürükleme gerilmesi [MPa]"; "q R7"; ...
                "itki tabanı [kN]"; "NJ1024 sürekli eksenel kapasite [kN]"; "NJ1024 kısa süreli eksenel kapasite [kN]"; "topal mod itkisi [kN]"; ...
                "NJ1024 eksenel boşluk [mm]"; "E4'te NJ hasarı olasılığı"; "R4"; "E7 p (üç evre)"; "SYS-06 toplamı [kg]"; "dengelemelerle SYS-06 [kg]"], ...
               [Lp.t; Lp.s_lim; Lp.s_ult; Lp.rf_ult; Lp.bolt_s_lim; Lp.bolt_s_ult; Lp.m_cover; Lp.m_total; Lp.E_rundown / 1e3; ...
                Lp.T_max; Lp.T_max_onesided; Lp.sy_hot; Lp.s_drag; Lp.q_rub7; Q.floor / 1e3; Q.nj_cont / 1e3; Q.nj_brief / 1e3; ...
                Q.limp / 1e3; Q.end_play; Q.p_nj; Q.R4; Q.p_qj; Q.rollup; Q.rollup_net], ...
               'VariableNames', {'quantity_en', 'quantity_tr', 'value'});
    writetable(Tl, fullfile('safety', 'fta_lip_v1.csv'));
    writetable(Q.phases, fullfile('safety', 'fta_e7_phases_v1.csv'));
    Pr = sf_protect(in);
    fprintf('\n== G2 Shaft-break and load-loss protection coverage (SAF-03, CTL-02)\n');
    disp(Pr.T(:, {'fmea', 'break_en', 'between', 'J_PT_side_kgm2', 'logic', 't_detect_ms', 't_valve_closed_ms', 'peak_pct'}));
    fprintf('   PT above 100%% for %.2f-%.2f s after a downstream break; absolute trip at the largest PT-side inertia: peak %.2f%%\n', ...
            Pr.t_above, 100 * Pr.abs.peak);
    S.protect = Pr;
    writetable(Pr.T, fullfile('safety', 'protection_coverage_v1.csv'));
    G = sf_fta2(in);
    G.sum_all = S.fta.P_total + G.sum_D1b;
    fprintf('\n== D1b (a) PT overspeed: drive-chain breaks %.2e /h; sum %.2e /h; allowance per protection element %.2e (range %.2e-%.2e)\n', ...
            G.lam_break, G.sum_a, G.allow.q_p, G.range.q_p);
    disp(G.Ta(:, {'cut_set_en', 'P_per_h'}));
    fprintf('   spurious trips %.1e /h against the aircraft-side allowance %.0e (TBR)\n', G.spurious, in.ft2.a.spur_allow);
    fprintf('   (b) excessive drag, or propeller overspeed leading to blade release or excessive unbalance: sum %.2e /h\n', G.sum_b);
    disp(G.Tb(:, {'cut_set_en', 'P_per_h', 'credits'}));
    fprintf(['   allowances (each from its own cut set): low-pitch stop q %.1e (check at most %.0f h; range %.0f-%.0f h), ' ...
             'counterweight feathering q %.1e, OSG test interval %.0f h with the FADEC feather credited (range %.0f-%.0f h), ' ...
             '%.0f h without it (range %.0f-%.0f h)\n'], G.allow.q_lps, G.allow.T_lps, G.range.T_lps, G.allow.q_cw, ...
            G.allow.T_osg, G.range.T_osg, G.allow.T_osg_noFF, G.range.T_osg_noFF);
    fprintf('   hazardous effects: D1 %.2e + D1b (a) %.2e + (b) %.2e = %.2e /h (band %.0e)\n', S.fta.P_total, G.sum_a, G.sum_b, ...
            G.sum_all, in.ft.band);
    disp(G.sens);
    S.fta2 = G;
    Ta = G.Ta;  Ta.tree = repmat("(a) PT overspeed", height(Ta), 1);
    Tb = G.Tb;  Tb.tree = repmat("(b) excessive drag or propeller overspeed", height(Tb), 1);
    writetable([Ta; Tb], fullfile('safety', 'fta2_cutsets_v1.csv'));
    writetable(G.sens, fullfile('safety', 'fta2_sensitivity_v1.csv'));
    Al = table(["protection element of (a), each"; "in-flight low-pitch stop"; "low-pitch stop check interval [h]"; ...
                "counterweight feathering"; "OSG test interval with the FADEC feather [h]"; "OSG test interval without it [h]"], ...
               ["(a) koruma elemanı, her biri"; "uçuş alt hatve durdurucusu"; "alt hatve durdurucusu kontrol aralığı [h]"; ...
                "karşı ağırlıklı tüyleme"; "FADEC tüylemesiyle OSG test aralığı [h]"; "onsuz OSG test aralığı [h]"], ...
               [G.allow.q_p; G.allow.q_lps; G.allow.T_lps; G.allow.q_cw; G.allow.T_osg; G.allow.T_osg_noFF], ...
               [G.range.q_p(1); G.range.q_lps(1); G.range.T_lps(1); G.range.q_cw(1); G.range.T_osg(1); G.range.T_osg_noFF(1)], ...
               'VariableNames', {'allowance_en', 'allowance_tr', 'base', 'lowest_in_x10_cases'});
    writetable(Al, fullfile('safety', 'fta2_allowances_v1.csv'));
    for lang = {'en', 'tr'}
        sf_plot_fta(F, in, lang{1}, out_dir);
        sf_plot_fta2(G, in, lang{1}, out_dir);
        copyfile(fullfile(out_dir, ['fta_' lang{1} '.png']), fig_dir);
        copyfile(fullfile(out_dir, ['fta2_' lang{1} '.png']), fig_dir);
    end
end

if any(strcmp(parts, 'fmea'))
    M = sf_fmea(in);
    fprintf('\n== D2 FMEA (%s): %d failure modes\n', in.fmea.file, M.n);
    fprintf('   with the design features: hazardous %d, major %d, minor %d\n', M.count);
    fprintf('   before mitigation:        hazardous %d, major %d, minor %d\n', M.count_unmit);
    disp(M.by_group);
    fprintf('   failure modes hazardous before mitigation and what covers them:\n');
    disp(M.haz);
    if isempty(M.fails)
        fprintf('   checks: all passed\n');
    else
        fprintf('   CHECK FAILED: %s\n', M.fails);
    end
    S.fmea = rmfield(M, 'T');
    f = in.fmea;
    Sm = table(string(f.groups_en'), string(f.groups_tr'), M.by_group.hazardous, M.by_group.major, M.by_group.minor, ...
               M.unmit_by_group, 'VariableNames', {'group_en', 'group_tr', 'hazardous', 'major', 'minor', ...
               'hazardous_before_mitigation'});
    writetable(Sm, fullfile('safety', 'fmea_summary_v1.csv'));
    writetable(M.haz, fullfile('safety', 'fmea_hazardous_v1.csv'));
    writetable(M.major, fullfile('safety', 'fmea_major_rates_v1.csv'));
    disp(M.major(:, {'effect_en', 'fmea', 'rate_per_h', 'remote'}));
    for lang = {'en', 'tr'}
        sf_plot_fmea(M, in, lang{1}, out_dir);
        copyfile(fullfile(out_dir, ['fmea_' lang{1} '.png']), fig_dir);
    end
end

if any(strcmp(parts, 'dt')) || any(strcmp(parts, 'parts'))
    V = sf_nr_check();
    fprintf('\n== D4 Newman-Raju equations against the published FE values (TP-1578 Table I, TM-85793 Table 2)\n');
    disp(V);
    fprintf('   largest difference in the D4 range %.1f%% (outside it, corner a/c = 2: %.1f%%)\n', ...
            max(abs(V.diff_pct(V.in_D4_range))), max(abs(V.diff_pct(~V.in_D4_range))));
    writetable(V, fullfile('safety', 'nr_verification_v1.csv'));
    D = sf_dt_all(in);
    fprintf(['\n== D4 Damage tolerance (CM-PIFS-007 3.1 A1): initial flaw %.3f x %.3f mm surface, %.3f x %.3f mm ' ...
             'corner; target %d cycles; %d cycles per TBO\n'], 2 * in.dt.a0_surf(2), in.dt.a0_surf(1), ...
            in.dt.a0_corner, in.dt.target, in.dt.cyc_tbo);
    disp(D.T(:, {'part', 'case', 'plane_deg', 's_lcf_MPa', 's_lcf_min_MPa', 's_hcf_max_MPa', 's_hcf_min_MPa', ...
                 's_lim_MPa', 'dK_lcf_deep', 'dK_hcf0', 'dKth_hcf', 'N_cycles', 'a_hcf_mm', 'a_c_mm', 'ndt', ...
                 'N_det_to_fail', 'a_end_det_mm', 'c_end_det_mm', 'interval_tbo', 'ndt_ratio'}));
    Z = D.design;
    fprintf('\n== D4 design studies\n   P103 KM24 thread (rule a_HCF >= %.2f x the deepest NDT pair):\n', in.dt.rule_ndt);
    disp(Z.thread(:, {'option_en', 'Kf', 'bore_mm', 'theta_deg', 's_hcf_max_MPa', 'a_hcf_mm', 'ndt_ratio', ...
                      'ndt_ratio_shape', 'interval_tbo', 'interval_tbo_ET', 'N_anomaly', 'N_anomaly_dKth08', 'meets_rule', ...
                      'added_mass_kg', 'adopted'}));
    if Z.thread_adopted
        fprintf('   adopted: %s (+%.3f kg)\n', Z.thread.option_en(Z.thread_adopted), Z.thread.added_mass_kg(Z.thread_adopted));
    else
        fprintf('   NO OPTION MEETS THE RULE: decision needed\n');
    end
    fprintf('   carrier pin bore: base interval %d TBO; rim bosses needed: %s\n', Z.boss.interval_tbo(1), string(Z.boss_needed));
    disp(Z.boss);
    fprintf('   check with the 3.5 press-fit hoop %g MPa: a_HCF %.2f mm, interval %d TBO, anomaly life %.3g\n', ...
            in.dt.carrier.hoop_35, Z.hoop35.a_hcf, Z.hoop35.interval_tbo, Z.hoop35.N);
    fprintf('   1P moment:\n');
    disp(Z.m1p(:, {'M_1P_Nm', 'location_en', 's_hcf_max_MPa', 'a_hcf_mm', 'ndt_ratio', 'interval_tbo', 'N_anomaly', 'holds'}));
    for j = 1:numel(Z.m1p_locs), fprintf('   %s: base-case conclusions hold up to %.0f N m\n', Z.m1p_locs(j), Z.m1p_max(j)); end
    fprintf('   ICD-10 note: M_1P <= %.0f N m\n', floor(Z.m1p_limit / 10) * 10);
    fprintf('\n== H4 Diaphragm coupling options (adopted: %s; angular stack %.3f deg)\n', D.coupling.T.option_en(D.coupling.adopted), D.coupling.stack_sum);
    disp(D.coupling.T(:, {'option_en', 'n_f', 'n_buck', 'n_static', 'c_hcf_over_anomaly', 'N_anomaly', 'c_hcf_w_over_anomaly', 'N_anomaly_w', 'passes'}));
    writetable(D.coupling.T, fullfile('safety', 'coupling_options_v1.csv'));
    St = cell2table(D.coupling.stack, 'VariableNames', {'item_en', 'item_tr', 'deg'});
    writetable(St, fullfile('safety', 'coupling_alignment_stack_v1.csv'));
    S.nr = V;
    S.dt = D;
    writetable(D.T, fullfile('safety', 'dt_v1.csv'));
    writetable(Z.thread, fullfile('safety', 'dt_thread_options_v1.csv'));
    writetable(Z.boss, fullfile('safety', 'dt_carrier_boss_v1.csv'));
    writetable(Z.m1p, fullfile('safety', 'dt_m1p_v1.csv'));
    P = sf_parts(in, D);
    fprintf('\n== D3 Critical parts (SAF-02, CS-E 515): %d critical\n', P.n_critical);
    disp(P.T(:, {'part', 'critical', 'governing_location', 's_lcf_MPa', 's_lcf_min_MPa', 'N_lcf_min', 'approved_life_cycles', ...
                 'N_anomaly_cycles', 'a_fail_initial_shape_mm', 'a_end_det_mm', 'c_end_det_mm', 'interval_tbo', 'embedded_hcf_margin'}));
    S.parts = P;
    writetable(P.T, fullfile('safety', 'critical_parts_v1.csv'));
    for lang = {'en', 'tr'}
        sf_plot_dt(D, in, lang{1}, out_dir);
        sf_plot_dt_design(D.design, in, lang{1}, out_dir);
        copyfile(fullfile(out_dir, ['dt_' lang{1} '.png']), fig_dir);
        copyfile(fullfile(out_dir, ['dt_design_' lang{1} '.png']), fig_dir);
    end
end

if any(strcmp(parts, 'fire'))
    Fz = sf_fire_all(in);
    fw = in.fire;
    fprintf(['\n== D5 Fire (SAF-05, CS-E 130, 14 CFR 33.17): flame at its upper tolerance %g degC, %g kW/m2 (ISO 2685); ' ...
             'A357 solidus %g degC; sink %g degC\n'], fw.T_f, fw.q0 / 1e3, fw.T_solidus, fw.T_sink);
    fprintf('   time from the fire warning to zero oil flow %g s: oil parts %s; lowest RGB flow %.1f L/min\n', ...
            Fz.t_zero, Fz.level, Fz.Q_min);
    disp(Fz.T(:, {'wall', 'in_fire_zone', 'h_basis_W_m2K', 'T_flame_side_max', 'T_mean_max', 'T_oil_side_max', ...
                  'hot_yield_MPa', 's_operating_MPa', 'meets_5min', 'h_min_W_m2K', 'T_oil_side_at_h_min', ...
                  't_strength_lost_after_flow_s', 't_solidus_after_flow_s'}));
    fprintf('   (NaN flame side: molten; oil-side temperatures against the flash point %g and auto-ignition %g degC)\n', ...
            fw.oil.flash, fw.oil.ait);
    disp('   P101 / F201 joint at the end of the 5 min (2-D r-z; first row with the partition):');
    disp(Fz.J);
    writetable(Fz.J, fullfile('safety', 'fire_joint_v1.csv'));
    S.fire = Fz;
    writetable(Fz.T, fullfile('safety', 'fire_v1.csv'));
    for lang = {'en', 'tr'}
        sf_plot_fire(Fz, in, lang{1}, out_dir);
        copyfile(fullfile(out_dir, ['fire_' lang{1} '.png']), fig_dir);
    end
end

save(mat, 'S');
end
