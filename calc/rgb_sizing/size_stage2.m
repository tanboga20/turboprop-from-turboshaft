function s = size_stage2(t, in)
%SIZE_STAGE2  Smallest module the planetary stage passes with.
%   s = size_stage2(t, in)
%
%   t is one tooth-count set from tooth_sets (fields zs, zp, zr, N, u1, gap)
%   and in comes from rgb_inputs. The sun torque and speed follow from the
%   first-stage ratio without losses: Ts = T_PT u1, ns = n_PT / u1.
%   Steps up the module list. A module is skipped if the post gap between
%   neighbouring planet tip circles, m * t.gap, is below post_gap_min; else
%   the stage is rated with b2 = ceil(psi2 min(d_s, d_p)). The first module at
%   which the gears (S_H, S_F, static check) and the planet bearing (mission
%   L10, s0) all pass is returned as the planet_stage output; s is empty if
%   no module passes.
%
%   Source: Phase 1 report, Section 3 ("Module loops", step 2). Checked in
%   the full run; planet_stage is tested by TC5.

Ts = in.T_PT * t.u1;
ns = in.n_PT / t.u1;
for m = in.modules
    if m * t.gap < in.post_gap_min
        continue
    end
    b = ceil(in.psi2 * min(t.zs * m, t.zp * m));
    s = planet_stage(t.zs, t.zp, t.zr, t.N, m, b, Ts, ns, in);
    if s.gears_ok && s.bearing_ok
        return
    end
end
s = [];
end
