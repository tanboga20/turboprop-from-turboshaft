function C = mf_casedepth(in, gi, sb)
%MF_CASEDEPTH  Case depth check of the gear flanks and the planet bearing raceways (step 3.4).
%   C = mf_casedepth(in, gi, sb)
%
%   in = mf_inputs, gi = gd_inputs, sb = sb_inputs (calc/gear_detail and
%   calc/shafts_bearings on the path). For each flank at the pitch point and
%   for the two planet bearing raceways (planet bore and pin) at maximum
%   continuous torque (K_A 1.25) and at LD-02 (137.5%, K_A 1): the Hertz
%   pressure p0 (sigma_H of the step 2.4 rating for the flanks), the contact
%   half width b = 2 p0 R / E*, the depth of the largest shear stress
%   0.786 b and that stress 0.300 p0, and the case depth the specification
%   must give, in.k_cd times that depth. Raceways: planet load = the two
%   mesh tangential forces times K_gamma (P99) with the centrifugal force
%   at right angles, most loaded roller in.stribeck x Fr / Z.
%   Output C: table C.T (contact, case, p0 [MPa], R [mm], b, z_tau, tau_max,
%   cd_needed [mm], cd_spec [min max], margin = spec minimum / needed) and
%   K_gamma, Fr [N], Qmax [N] of the raceways.
%   Source: Phase 3 report, Section 3.4 ("Case depth").

M = gd_meshes(gi);
ref = struct('KA', gi.KA, 'mode', 'ref', 'oil', gi.oil(1), 'ZNT10', gi.ZNT_ref, 'fpb_share', gi.fpb_share);
% load sharing as in step 2.4: P99 of the Monte Carlo model at 100% torque
r0 = arrayfun(@(k) gd_rate(setfield(M(k), 'Kgam', 1), M(k).T1, M(k).n1, ref), 2:3);
ls = gd_loadshare(M(2), M(3), M(2).Ts, r0(1).c_ga * M(2).g.b, r0(2).c_ga * M(3).g.b, gi);
M(2).Kgam = ls.Kgam_p99;  M(3).Kgam = ls.Kgam_p99;
C.Kgam = ls.Kgam_p99;
C.M = M;

Es = @(E1, n1, E2, n2) 1 / ((1 - n1^2) / E1 + (1 - n2^2) / E2);
cases = struct('name', {'MCT', 'LD-02'}, 'f', {1, gi.K_over}, 'KA', {gi.KA, 1.0});
gear = {'pinion', 'gear 2'; 'planet (sun mesh)', 'sun'; 'planet (ring mesh)', 'ring'};
key = {'P53', 'P53'; 'P53', 'P53'; 'P53', 'N13'};
rows = {};
for c = 1:numel(cases)
    for k = 1:3
        g = M(k).g;
        o = ref;  o.KA = cases(c).KA;
        r = gd_rate(M(k), cases(c).f * M(k).T1, M(k).n1, o);
        % relative radius of curvature at the pitch point, normal section
        r1 = g.dw1 / 2 * sin(g.alpha_wt);  r2 = g.dw2 / 2 * sin(g.alpha_wt);
        if g.internal, R = r1 * r2 / (r2 - r1); else, R = r1 * r2 / (r1 + r2); end
        R = R / cos(g.beta_b);
        E = Es(M(k).mat1.E, M(k).mat1.nu, M(k).mat2.E, M(k).mat2.nu);
        for i = 1:2
            p0 = r.(sprintf('sigma_H%d', i));
            rows(end + 1, :) = {sprintf('%s: %s', M(k).name, gear{k, i}), cases(c).name, key{k, i}, p0, R, E}; %#ok<AGROW>
        end
    end
    % planet bearing raceways: planet bore (carburized Pyrowear 53) and pin (carburized M50NiL)
    rs = gd_rate(M(2), cases(c).f * M(2).T1, M(2).n1, ref);
    Fr = hypot(2 * rs.Ft * C.Kgam, in.F_cf_planet);
    Z = floor(pi * (M(2).D_or - sb.planet.Dw) / (sb.planet.Dw * (1 + sb.planet.pitch_gap)));
    Lw = gi.s2.b - sb.planet.L_ends;
    Q = in.stribeck * Fr / Z;
    a = sb.planet.Dw / 2;
    Ro = M(2).D_or / 2;  Ri = Ro - sb.planet.Dw;
    E = Es(206e3, 0.3, 206e3, 0.3);
    for rc = {{'planet bore (outer race)', a * Ro / (Ro - a), 'P53'}, {'planet pin (inner race)', a * Ri / (Ri + a), 'M5N'}}
        [nm, R, kk] = rc{1}{:};
        p0 = sqrt(Q * E / (pi * R * Lw));
        rows(end + 1, :) = {nm, cases(c).name, kk, p0, R, E}; %#ok<AGROW>
    end
    C.Fr(c) = Fr;  C.Qmax(c) = Q;  C.Z = Z;  C.Lw = Lw;
end
p0 = [rows{:, 4}]';  R = [rows{:, 5}]';  E = [rows{:, 6}]';
b = 2 * p0 .* R ./ E;
z = 0.786 * b;
need = in.k_cd * z;
spec = cell2mat(cellfun(@(k) in.cd.(k), rows(:, 3), 'UniformOutput', false));
C.T = table(string(rows(:, 1)), string(rows(:, 2)), string(rows(:, 3)), p0, R, b, z, 0.300 * p0, need, spec, ...
            spec(:, 1) ./ need, 'VariableNames', {'contact', 'case', 'material', 'p0_MPa', 'R_mm', 'b_mm', ...
            'z_tau_mm', 'tau_max_MPa', 'cd_needed_mm', 'cd_spec_mm', 'margin'});
C.iso_max = in.cd_iso(2) * [gi.s1.mn gi.s2.m];      % largest case depth by ISO 6336-5: first stage, planetary
end
