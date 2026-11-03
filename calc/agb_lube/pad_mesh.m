function s = pad_mesh(z1, z2, mn, beta_deg, b_min, T_max, T_sh, n1, in, in14)
%PAD_MESH  Smallest face width of an accessory drive mesh.
%   s = pad_mesh(z1, z2, mn, beta_deg, b_min, T_max, T_sh, n1, in, in14)
%
%   Inputs
%     z1, z2     tooth numbers, z1 the smaller gear                  [-]
%     mn         normal module                                       [mm]
%     beta_deg   helix angle                                         [deg]
%     b_min      first face width tried                              [mm]
%     T_max      maximum rated torque of the pad, on gear 1          [N m]
%     T_sh       shear torque of the pad's shear neck, on gear 1     [N m]
%     n1         speed of gear 1                                     [rpm]
%     in, in14   rgb_inputs (gear factors, STR-01 minima, static life
%                factors) and lube_inputs (k_fatigue)
%
%   Steps the face width up by 1 mm from b_min until the mesh passes three
%   checks with the factors of the main gears:
%     1. STR-01 at T_max: S_H >= 1.2, S_F >= 1.5
%     2. ACC-03 at k_fatigue x T_max (1.5): S_H >= 1, S_F >= 1
%     3. at the shear torque with the static life factors: S_H >= 1, S_F >= 1,
%        so that the shear neck breaks before the gear train
%   Output struct s: b, g (gear_geometry), r, rf, rs (iso6336_lite at the
%   three torques).
%
%   Source: Phase 1 report, Section 4 ("Accessory pads"). Tested by
%   test_step14 (TC14).

fs = in.f;
fs.ZNT = in.ZNT_static;
fs.YNT = in.YNT_static;
b = b_min;
while true
    g = gear_geometry(z1, z2, mn, beta_deg, b, false, in.alpha_n);
    r = iso6336_lite(g, T_max, n1, in.f);
    rf = iso6336_lite(g, in14.k_fatigue * T_max, n1, in.f);
    rs = iso6336_lite(g, T_sh, n1, fs);
    if r.S_H >= in.SH_min && min(r.S_F1, r.S_F2) >= in.SF_min ...
            && rf.S_H >= 1 && min(rf.S_F1, rf.S_F2) >= 1 ...
            && rs.S_H >= 1 && min(rs.S_F1, rs.S_F2) >= 1
        s = struct('b', b, 'g', g, 'r', r, 'rf', rf, 'rs', rs);
        return
    end
    b = b + 1;
end
end
