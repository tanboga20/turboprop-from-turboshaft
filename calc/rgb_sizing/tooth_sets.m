function S = tooth_sets(in)
%TOOTH_SETS  All valid tooth-count sets of layout O.
%   S = tooth_sets(in)
%
%   Tries every set in the ranges of rgb_inputs (z1, z2 from u1_range, N,
%   zs, zp) and keeps those that tooth_set_check finds valid. To keep the
%   search fast, only the planets that bring the overall ratio within the
%   tolerance are passed to tooth_set_check.
%   Output: struct array S, one element per valid set, with the fields of
%   tooth_set_check; for example sum([S.N] == 4) is the number of sets with
%   four planets.
%
%   Source: Phase 1 report, Section 3 ("Method: gears", tooth counts).
%   Tested by test_rgb_sizing (TC4c, the number of valid sets per N).

sets = {};
for z1 = in.z1_range
    for z2 = ceil(in.u1_range(1) * z1) : floor(in.u1_range(2) * z1)
        if gcd(z1, z2) ~= 1, continue, end       % hunting tooth pair in stage 1 (required)
        u1 = z2 / z1;
        for N = in.N_list
            for zs = in.zs_range
                zp = in.zp_range;
                i = u1 * (1 + (zs + 2 * zp) / zs);
                for zpk = zp(abs(i / in.i_target - 1) <= in.i_tol)
                    c = tooth_set_check(z1, z2, zs, zpk, N, in);
                    if c.valid
                        sets{end + 1} = c;           %#ok<AGROW>
                    end
                end
            end
        end
    end
end
S = [sets{:}];
end
