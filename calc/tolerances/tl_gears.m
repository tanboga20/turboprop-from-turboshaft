function G = tl_gears(in)
%TL_GEARS  Gear accuracy grades and tolerances per gear (E6, ISO 1328-1:2013).
%   G = tl_gears(in)   in = tl_inputs (calc/gear_detail on the path)
%
%   For each gear: the reference diameter, the class of pitch and helix (the
%   step 2.4 classes: K_v and f_pb unchanged) and of the profile (the sun and
%   planets one class finer, supporting STR-11), the tolerances of
%   gd_tolerances (single and cumulative pitch, profile form and slope,
%   helix form and slope), the runout F_r = in.Fr_share F_p, the tooth
%   thickness (space width for the ring) allowance of E3, and the tolerance
%   of the profile modification amplitude.
%   Source: Phase 3 report, Section 3.8 (E6).

rows = {};
for k = 1:numel(in.gear)
    g = in.gear(k);
    d = g.z * g.mn / cosd(g.beta);
    t = gd_tolerances(d, g.mn, g.b, g.A);
    tp = gd_tolerances(d, g.mn, g.b, g.A_profile);
    tt = in.tt.(g.key);
    Fr = round(in.Fr_share * t.F_p);
    rows(end + 1, :) = {string(g.name), string(g.key), g.z, g.mn, g.beta, g.b, d, g.A, g.A_profile, ...
        t.f_p, t.F_p, tp.f_fa, tp.f_Ha, tp.F_a, t.f_fb, t.f_Hb, t.F_b, Fr, tt(1), tt(1) - tt(2), ...
        in.tip_relief_tol, string(g.finish)}; %#ok<AGROW>
end
G.T = cell2table(rows, 'VariableNames', {'gear', 'key', 'z', 'm_n', 'beta_deg', 'b_mm', 'd_mm', 'class', ...
    'class_profile', 'f_p_um', 'F_p_um', 'f_fa_um', 'f_Ha_um', 'F_a_um', 'f_fb_um', 'f_Hb_um', 'F_b_um', ...
    'F_r_um', 'E_sns_um', 'E_sni_um', 'mod_tol_um', 'finish'});
end
