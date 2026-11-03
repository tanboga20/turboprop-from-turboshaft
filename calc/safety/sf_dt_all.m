function D = sf_dt_all(in)
%SF_DT_ALL  Damage tolerance of all critical-part locations (D4), with the design studies and the sensitivity.
%   D = sf_dt_all(in)   in = sf_inputs
%   D.design: sf_dt_design (thread options, carrier bosses, 1P); the locations take its adopted designs.
%   D.loc: locations (sf_locations); D.R: results of sf_dt, one row per location and case (base, C x2,
%   dK_th -20%, K_IC -20%, steel threshold 2.0 at every R (steel parts only; reported, not the basis)); D.T:
%   summary table.
%   Source: Phase 3 report, Section 3.7 (D4).

D.design = sf_dt_design(in);
D.coupling = sf_coupling(in);                % H4: the adopted diaphragm coupling option
over = D.design.over;  over.cpl = D.coupling.cpl;
Lc = sf_locations(in, over);
opt = struct('cyc_tbo', in.dt.cyc_tbo, 'target', in.dt.target, 'a_emb', in.dt.ut_fbh / 2);
sv = in.dt.sens;
cases = {'base', sprintf('C x%g', sv.C), sprintf('dKth x%g', sv.dKth), sprintf('KIC x%g', sv.KIC), ...
         sprintf('steel dKth %g', sv.dKth_steel)};
rows = {};
for k = 1:numel(Lc)
    L = Lc(k);
    m0 = in.dt.mat.(L.mat);
    for j = 1:numel(cases)
        m = m0;
        switch j
            case 2, m.C = m0.C * sv.C;
            case 3, m.dKth = @(R) sv.dKth * m0.dKth(R);
            case 4, m.KIC = m0.KIC * sv.KIC;
            case 5
                if ~any(strcmp(L.mat, {'S4340', 'P53', 'C155'})), continue, end
                m.dKth = @(R) sv.dKth_steel + 0 * R;
        end
        R = sf_dt(L, m, opt);
        D.R(k, j) = R;
        Lr = R.L;
        rows(end + 1, :) = {string(L.part), string(L.en), string(L.tr), string(m0.name), string(cases{j}), ...
            L.a0, L.c0, Lr.theta, Lr.s_lcf, Lr.s_lcf_min, Lr.s_hmax, Lr.s_hmin, Lr.s_lim, R.dK_lcf0(1), R.dK_lcf0(2), ...
            max(R.dKh0), R.dKth_hcf, R.N, R.mode, R.a_f, R.c_f, R.a_hcf, R.a_c, R.a_fail, R.N >= in.dt.target, ...
            string(L.ndt_method), R.a_det, R.N_insp, R.af_det(1), R.af_det(2), R.mode_det, R.interval_tbo, ...
            R.ndt_ratio, R.through0, any(R.ndt_through), R.emb.a0, R.emb.a_hcf, R.emb.margin, R.emb.N, ...
            string(L.env_en), string(L.env_tr)}; %#ok<AGROW>
    end
end
D.loc = Lc;
D.cases = cases;
D.T = cell2table(rows, 'VariableNames', {'part', 'location_en', 'location_tr', 'material', 'case', 'a0_mm', 'c0_mm', ...
    'plane_deg', 's_lcf_MPa', 's_lcf_min_MPa', 's_hcf_max_MPa', 's_hcf_min_MPa', 's_lim_MPa', 'dK_lcf_deep', ...
    'dK_lcf_surf', 'dK_hcf0', 'dKth_hcf', 'N_cycles', 'end_mode', 'a_end_mm', 'c_end_mm', 'a_hcf_mm', 'a_c_mm', ...
    'a_fail_initial_shape_mm', 'meets_target', 'ndt', 'a_det_mm', 'N_det_to_fail', 'a_end_det_mm', 'c_end_det_mm', ...
    'end_mode_det', 'interval_tbo', 'ndt_ratio', 'anomaly_through', 'ndt_through_pair', 'embedded_a0_mm', ...
    'embedded_a_hcf_mm', 'embedded_hcf_margin', 'embedded_N', 'environment_en', 'environment_tr'});
D.env_note = in.dt.env_note;
end
