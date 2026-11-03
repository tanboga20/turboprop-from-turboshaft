function s = size_stage1(z1, z2, in)
%SIZE_STAGE1  Smallest module the helical first stage passes with.
%   s = size_stage1(z1, z2, in)
%
%   Steps up the module list of rgb_inputs with the helix angle beta1 and the
%   face width b1 = ceil(psi1 d1). The first module at which pinion and gear
%   meet S_H >= SH_min and S_F >= SF_min at the power turbine torque and
%   speed, and again in the static check (LD-01), is returned.
%   Output struct s: mn, b, g (gear_geometry), r and rs (iso6336_lite at 100%
%   torque and in the static check); s is empty if no module passes.
%
%   Source: Phase 1 report, Section 3 ("Module loops", step 1). Checked in
%   the full run.

fs = in.f;
fs.ZNT = in.ZNT_static;
fs.YNT = in.YNT_static;
for mn = in.modules
    d1 = z1 * mn / cos(deg2rad(in.beta1));
    b = ceil(in.psi1 * d1);
    g = gear_geometry(z1, z2, mn, in.beta1, b, false, in.alpha_n);
    r = iso6336_lite(g, in.T_PT, in.n_PT, in.f);
    rs = iso6336_lite(g, in.K_over * in.T_PT, in.n_PT, fs);
    if rating_ok(r, in) && rating_ok(rs, in)
        s = struct('mn', mn, 'b', b, 'g', g, 'r', r, 'rs', rs);
        return
    end
end
s = [];
end

function ok = rating_ok(r, in)
ok = r.S_H >= in.SH_min && min(r.S_F1, r.S_F2) >= in.SF_min;
end
