function C = sf_coupling(in)
%SF_COUPLING  Diaphragm coupling options (H4): stresses, step 2.2 rules and D4 at the thinnest section.
%   C = sf_coupling(in)   in = sf_inputs; calc/pt_shaft on the path
%
%   The CM-PIFS-007 anomaly is kept (a through crack in the thin diaphragm) and the stresses are lowered. Options, in
%   order (design decision, delegated by Hamit): 0 the step 2.2 design (no pre-stretch,
%   0.25 deg); 1 an axial pre-stretch at assembly with a measured selective shim, so that the diaphragm sits at the
%   middle of its running axial travel per coupling (cold idle 0, continuous 0.75, transient 1.5 mm: pre-stretch
%   0.75 mm, so -0.75 / 0 / +0.75 mm); 2 option 1 with an angular budget of 0.1 deg per coupling (transient 0.2 deg);
%   3 option 2 as a fail-safe laminated pack of three thinner discs, N - 1 discs carrying the limit torque. For each
%   option the stresses come from the step 2.2 model (diaphragm, annular_plate): Goodman n_f >= 1.5, buckling n_buck
%   >= 2.0 (with N - 1 discs for the laminated pack), static n_static >= 1.0; and D4 at the hub radius as a through
%   crack (sf_dt) with the base and the dKth x 0.8 constants: the HCF threshold half-length over the 0.381 mm anomaly
%   and the anomaly life. The lightest option that passes all is adopted (C.adopted, C.cpl for sf_locations).
%   Source: Phase 3 report, Section 3.7 (H4).

ip = ptshaft_inputs();
g = in.dt.cpl_geo;  o = in.dt.cpl_opt;
d = in.dt;
opt = struct('cyc_tbo', d.cyc_tbo, 'target', d.target, 'a_emb', d.ut_fbh / 2);
m0 = d.mat.C155;  mw = m0;  mw.dKth = @(R) d.sens.dKth * m0.dKth(R);
rows = {};  C.adopted = 0;
for k = 1:numel(o)
    q = ip;
    q.mis.theta = o(k).theta;  q.mis.theta_max = 2 * o(k).theta;
    q.mis.axial = o(k).axial;  q.mis.axial_max = o(k).axial_max;
    c = diaphragm(g.a, g.b, o(k).t, q, d.pt.rpm, o(k).n);
    p = annular_plate(g.a, g.b, o(k).t, q.dia.E, q.dia.nu);
    if o(k).failsafe, cf = diaphragm(g.a, g.b, o(k).t, q, d.pt.rpm, o(k).n - 1); n_buck = cf.n_buck;  n_st = cf.n_static;
    else, n_buck = c.n_buck;  n_st = c.n_static; end
    cp = d.cpl;
    cp.t = o(k).t * 1e3;  cp.s_ax = c.sig_ax / 1e6;  cp.s_th = c.sig_th / 1e6;  cp.s_thx = 2 * cp.s_th;
    cp.s_cf = c.sig_cf / 1e6;  cp.tau_mc = c.tau_MC / 1e6;  cp.tau_01 = c.tau_lim / 1e6;
    cp.s_tr = p.s_ax * q.mis.axial_max / 1e6;
    cp.s_cold = -o(k).pre * p.s_ax / 1e6;               % the cold position of the pre-stretched pack, worst face
    Lc = sf_locations(in, struct('cpl', cp));
    L = Lc(9);
    R = sf_dt(L, m0, opt);  Rw = sf_dt(L, mw, opt);
    ok = c.n_f >= q.dia.n_f_min && n_buck >= q.dia.n_buck_min && n_st >= 1.0 && R.N >= d.target && Rw.N >= d.target;
    if ok && C.adopted == 0, C.adopted = k;  C.cpl = cp; end
    rows(end + 1, :) = {string(o(k).en), string(o(k).tr), o(k).t * 1e3, o(k).n, o(k).theta, o(k).axial * 1e3, cp.s_ax, cp.s_th, ...
        cp.s_tr, cp.tau_mc, c.n_f, n_buck, n_st, R.a_hcf, R.a_hcf / L.c0, R.N, Rw.a_hcf, Rw.a_hcf / L.c0, Rw.N, ...
        c.mass, o(k).d_mass, ok}; %#ok<AGROW>
end
C.T = cell2table(rows, 'VariableNames', {'option_en', 'option_tr', 't_mm', 'n_discs', 'theta_deg', 'axial_cont_mm', ...
    's_ax_MPa', 's_th_MPa', 's_tr_MPa', 'tau_mc_MPa', 'n_f', 'n_buck', 'n_static', 'c_hcf_mm', 'c_hcf_over_anomaly', ...
    'N_anomaly', 'c_hcf_w_mm', 'c_hcf_w_over_anomaly', 'N_anomaly_w', 'mass_kg', 'added_mass_kg', 'passes'});
assert(C.adopted > 0, 'sf_coupling: no option passes; a thicker single diaphragm is the next step');
C.stack = in.dt.cpl_stack;
C.stack_sum = sum([C.stack{:, 3}]);
C.mass_added = o(C.adopted).d_mass;
end
