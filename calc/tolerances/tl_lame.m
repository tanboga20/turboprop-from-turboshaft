function R = tl_lame(a, b, c, Ei, nui, Eo, nuo, delta)
%TL_LAME  Shrink fit of two thick cylinders (Lame): contact pressure, inner-bore change, outer hoop stress.
%   R = tl_lame(a, b, c, Ei, nui, Eo, nuo, delta)
%   inner cylinder a..b (E_i, nu_i) in an outer cylinder b..c (E_o, nu_o), radial interference delta at the
%   interface [mm] (negative: clearance, no pressure). Lengths in mm, E in MPa.
%   R.p contact pressure [MPa]; R.u_a radial displacement of the inner bore [mm] (negative: inward);
%   R.hoop_o hoop stress of the outer cylinder at its bore [MPa]; R.hoop_i hoop stress of the inner cylinder
%   at its bore [MPa]; R.flex radial interference per MPa [mm/MPa].
%   Source: Phase 3 report, Section 3.8 (E4).

flex = b / Eo * ((c^2 + b^2) / (c^2 - b^2) + nuo) + b / Ei * ((b^2 + a^2) / (b^2 - a^2) - nui);
p = max(delta, 0) / flex;
R.p = p;
R.flex = flex;
R.u_a = -2 * p * b^2 * a / (Ei * (b^2 - a^2));
R.hoop_o = p * (c^2 + b^2) / (c^2 - b^2);
R.hoop_i = -2 * p * b^2 / (b^2 - a^2);
end
