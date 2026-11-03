function Fm = mf_film(in, gi, M)
%MF_FILM  Film thickness ratio of the three meshes against the flank finish (step 3.4, STR-09).
%   Fm = mf_film(in, gi, M)
%
%   in = mf_inputs, gi = gd_inputs, M = gd_meshes with K_gamma set (from
%   mf_casedepth). The step 2.4 scuffing and film tool (gd_scuffing) at
%   maximum continuous torque gives the film ratio at the pitch point,
%   lambda_C, for MIL-PRF-23699 at the oil inlet temperatures in.T_film, with
%   the roughness of step 2.4 (Rz 0.8 um external, Rz 1.0 um ring, Ra = Rz/6).
%   The film h does not depend on the roughness, so for a finish with the
%   same Ra on both flanks lambda = lambda_C x sigma_2.4 / (sqrt(2) Ra),
%   sigma_2.4 = sqrt(Ra1^2 + Ra2^2) of step 2.4. Also the Ra that gives
%   lambda = 1. Step 2.4 results are not changed.
%   Output Fm: table Fm.T (mesh, oil, T_oil, h_C [um], sigma_24 [um],
%   lambda_C, lambda at each in.Ra_list, Ra for lambda 1 [um]).
%   Source: Phase 3 report, Section 3.4 ("Flank finish").

ref = struct('KA', gi.KA, 'mode', 'ref', 'oil', gi.oil(1), 'ZNT10', gi.ZNT_ref, 'fpb_share', gi.fpb_share);
Xmp = [1 2 2];                                   % as step 2.4: planets mesh with sun and ring
rows = {};
for oi = 1                                        % MIL-PRF-23699 only (oil decision)
    for T = in.T_film
        for k = 1:3
            o = ref;  o.oil = gi.oil(oi);
            r = gd_rate(M(k), M(k).T1, M(k).n1, o);
            s = gd_scuffing(M(k), r, M(k).n1, gi.oil(oi), T, Xmp(k), gi);
            sig = sqrt((M(k).Rz1 / 6)^2 + (M(k).Rz2 / 6)^2);
            lam = s.lambdaC * sig ./ (sqrt(2) * in.Ra_list);
            rows(end + 1, :) = {string(M(k).name), string(gi.oil(oi).name), T, s.hC, sig, s.lambdaC, lam, ...
                                s.hC / sqrt(2)}; %#ok<AGROW>
        end
    end
end
Fm.T = cell2table(rows, 'VariableNames', {'mesh', 'oil', 'T_oil', 'hC_um', 'sigma24_um', 'lambdaC', ...
                                          'lambda_at_Ra', 'Ra_for_lambda1_um'});
Fm.Ra_list = in.Ra_list;
end
