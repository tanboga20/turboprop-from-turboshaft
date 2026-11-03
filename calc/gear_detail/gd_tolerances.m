function t = gd_tolerances(d, mn, b, A)
%GD_TOLERANCES  Flank tolerances of one gear by the ISO 1328-1:2013 formulae.
%   t = gd_tolerances(d, mn, b, A)
%
%   Inputs: reference diameter d [mm], normal module mn [mm], face width
%   b [mm], tolerance class A [-].
%   Output struct t [um]: f_p (single pitch), F_p (total cumulative pitch),
%   f_fa, f_Ha, F_a (profile form, slope, total), f_fb, f_Hb, F_b (helix
%   form, slope, total).
%
%   Class 5 values times sqrt(2)^(A - 5), rounded to 0.1 um below 10 um and
%   to 1 um above. ISO 1328-1:2013 itself is not in the project library;
%   the formulae are quoted from the literature and marked TBR in Section
%   2.4 of the Phase 2 report. ISO 6336-1:2019 allows f_pb = f_p.

s = sqrt(2)^(A - 5);
rnd = @(v) (v < 10) .* round(v * 10) / 10 + (v >= 10) .* round(v);
t.f_p = rnd((0.001 * d + 0.4 * mn + 5) * s);
t.F_p = rnd((0.002 * d + 0.55 * sqrt(d) + 0.7 * mn + 12) * s);
t.f_fa = rnd((0.55 * mn + 5) * s);
t.f_Ha = rnd((0.4 * mn + 0.001 * d + 4) * s);
t.F_a = rnd(sqrt(((0.55 * mn + 5) * s)^2 + ((0.4 * mn + 0.001 * d + 4) * s)^2));
t.f_fb = rnd((0.07 * sqrt(d) + 0.45 * sqrt(b) + 4) * s);
t.f_Hb = rnd((0.05 * sqrt(d) + 0.35 * sqrt(b) + 4) * s);
t.F_b = rnd(sqrt(((0.07 * sqrt(d) + 0.45 * sqrt(b) + 4) * s)^2 + ((0.05 * sqrt(d) + 0.35 * sqrt(b) + 4) * s)^2));
end
