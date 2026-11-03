function P = sf_parts(in, D)
%SF_PARTS  Critical parts list (D3, SAF-02, CS-E 515) with the approved-life basis, the D4 result and the plans.
%   P = sf_parts(in, D)   in = sf_inputs, D = sf_dt_all(in)
%
%   For each critical part and its D4 locations: the LCF life of the ground-air-ground cycle (max principal stress,
%   s_lcf_min to s_lcf) on the minimum S-N curve (Basquin, Morrow mean stress, k_min on the mean stress amplitude),
%   for the record only; the approved life (20,000 flight cycles declared, on the basis that the GAG stress range
%   at each governing feature is below the -3 sigma crack-initiation endurance of the material and process); the
%   D4 anomaly life, the failure size on the initial shape (a / c = 1), the end point (a, c) of the growth from the
%   governing NDT size and the inspection interval; the embedded-flaw (CS-E 515(a)) HCF margin; and the plan items
%   (CM-PIFS-007 3.1 A2, CS-E 515(c), AC 33.70-1 5.i and 9.b): process controls, NDT at manufacture and at TBO,
%   damage limits, the recording and assessment loop, fixed processes, validation, life tracking and the 3.11
%   tests. Parts judged not critical are listed with the reason.
%   Source: Phase 3 report, Section 3.7 (D3).

cp = in.cp;  pl = cp.plan;
rows = {};
for k = 1:numel(cp.list)
    c = cp.list(k);
    if ~c.critical
        rows(end + 1, :) = [{string(c.name), "no", string(c.why_en), string(c.why_tr), "", ""}, num2cell(nan(1, 10)), ...
                            repmat({""}, 1, 10)]; %#ok<AGROW>
        continue
    end
    e = plan(cp, c.name);
    if isempty(c.locs)                                  % a critical part without a D4 location of its own
        rows(end + 1, :) = [{string(c.name), "yes", string(c.why_en), string(c.why_tr), "D4 in 3.9 (solid ring in shear)", ""}, ...
                            num2cell(nan(1, 10)), {string(pl.life), string(e.process), string(e.ndt_mfg), string(e.ndt_tbo), ...
                            string(pl.damage), string(pl.records), string(pl.fixed), string(pl.validation), ...
                            string(cp.emsmp.tracking), string(pl.tests)}]; %#ok<AGROW>
    end
    for j = c.locs
        L = D.loc(j);  R = D.R(j, 1);
        s_max = s1(L.S.lcf_max);  s_min = s1(L.S.lcf_min);
        N_lcf = lcf_min(s_max, s_min, cp.sn.(c.mat), cp.k_min);
        rows(end + 1, :) = {string(c.name), "yes", string(c.why_en), string(c.why_tr), string(L.en), ...
            string(in.dt.mat.(L.mat).name), s_max, s_min, N_lcf, in.dt.approved_cyc, R.N, R.a_fail, R.af_det(1), ...
            R.af_det(2), R.interval_tbo, R.emb.margin, string(pl.life), string(e.process), string(e.ndt_mfg), ...
            string(e.ndt_tbo), string(pl.damage), string(pl.records), string(pl.fixed), string(pl.validation), ...
            string(cp.emsmp.tracking), string(pl.tests)}; %#ok<AGROW>
    end
end
P.T = cell2table(rows, 'VariableNames', {'part', 'critical', 'reason_en', 'reason_tr', 'governing_location', ...
    'material', 's_lcf_MPa', 's_lcf_min_MPa', 'N_lcf_min', 'approved_life_cycles', 'N_anomaly_cycles', ...
    'a_fail_initial_shape_mm', 'a_end_det_mm', 'c_end_det_mm', 'interval_tbo', 'embedded_hcf_margin', 'life_limit', ...
    'process_controls', 'ndt_manufacture', 'ndt_tbo', 'damage_limits', 'recording_loop', 'fixed_processes', ...
    'process_validation', 'life_tracking', 'tests_311'});
P.n_critical = numel(unique(P.T.part(P.T.critical == "yes")));
end

function e = plan(cp, name)
% plan items of a critical part
if startsWith(name, 'PT output shaft'), e = cp.emsmp.pt;
elseif startsWith(name, 'RGB input shaft'), e = cp.emsmp.p53;
elseif startsWith(name, 'P103'), e = cp.emsmp.p103;
elseif startsWith(name, 'P111'), e = cp.emsmp.Ti;
elseif startsWith(name, 'planetary case'), e = cp.emsmp.cast;
elseif startsWith(name, 'Diaphragm couplings'), e = cp.emsmp.cpl;
else, e = cp.emsmp.steel;
end
end

function s = s1(X)
% max principal stress of [sigma_x sigma_h tau]
s = (X(1) + X(2)) / 2 + sqrt(((X(1) - X(2)) / 2)^2 + X(3)^2);
end

function N = lcf_min(smax, smin, sn, kmin)
% cycles to failure on the minimum curve for a smin -> smax cycle
sa = (smax - smin) / 2;  sm = (smax + smin) / 2;
sar = sa / (1 - sm / sn(1));
N = 0.5 * (sar / (kmin * sn(1)))^(1 / sn(2));
end
