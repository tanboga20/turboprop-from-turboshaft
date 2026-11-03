function L = sb_life(b, r, t, Fr, Fa, n, nu, e_C)
%SB_LIFE  Modified rating life L10m of one bearing over the mission (ISO 281 form).
%   L = sb_life(b, r, t, Fr, Fa, n, nu, e_C)
%
%   Inputs
%     b, r     bearing (sb_inputs) and its ratings (sb_rating)
%     t        time shares of the mission steps                     [-]
%     Fr, Fa   radial and axial load in each step                    [N]
%     n        speed of the rotating ring relative to the other one  [rpm]
%     nu       oil viscosity at the bearing temperature              [mm^2/s]
%     e_C      contamination factor                                  [-]
%
%   Output struct L: P [N] and a_ISO of each step, kappa, nu1 [mm^2/s],
%   L10 and L10m of each step and over the mission [h].
%
%   Equivalent load: roller P = Fr; four-point contact ball bearing
%   (alpha 35 deg) P = Fr + 0.66 Fa when Fa/Fr <= 0.95, else 0.6 Fr +
%   1.07 Fa: the double-row factors (ISO/TR 1281-1 Table 10, X2 = 1.625
%   X1, Y2 = 1.625 Y1), which go with its rating as a double-row bearing
%   (i = 2 in sb_rating). Deep groove ball bearing ('DGBB', normal
%   clearance): P = Fr when Fa/Fr <= e, else 0.56 Fr + Y Fa, with e and Y
%   interpolated in f0 Fa/C0 from the classic ISO 281 table (TBR). Rated viscosity nu1 = 45000 n^-0.83 d_m^-0.5 below
%   1000 rpm, else 4500 n^-0.5 d_m^-0.5. Life modification factor
%   a_ISO = 0.1 [1 - (A - B / kappa^k) (e_C C_u / P)^w]^(-c/e), capped at
%   50, with roller A 1.5859, w 0.4, c/e 9.185 and ball A 2.5671, w 0.83,
%   c/e 9.3 (B and k by the kappa range); ISO 281:2007 is not in the
%   project library, so the coefficients are TBR. The mission life is the
%   Palmgren-Miner sum over the steps at constant speed.
%   Source: Phase 2 report, Sections 2.5 ("Bearings") and 2.6. Tested by
%   test_step25 (TC41) and test_step26 (TC47, deep groove).

t = t(:);  Fr = Fr(:);  Fa = Fa(:);
if strcmp(b.type, 'CRB')
    p = 10/3;
    P = Fr;
elseif strcmp(b.type, 'DGBB')
    p = 3;
    P = dgbb_load(Fr, Fa, r.f_0 / r.C0);
else
    p = 3;
    P = Fr + 0.66 * Fa;
    hi = Fa > 0.95 * Fr;
    P(hi) = 0.6 * Fr(hi) + 1.07 * Fa(hi);
end
if n < 1000
    nu1 = 45000 * n^-0.83 * r.d_m^-0.5;
else
    nu1 = 4500 * n^-0.5 * r.d_m^-0.5;
end
kappa = min(max(nu / nu1, 0.1), 4);
a = arrayfun(@(PP) a_iso(b.type, kappa, e_C * r.Cu / PP), P);
L10 = (r.C ./ P).^p * 1e6 / (60 * n);
L10m = a .* L10;
L = struct('P', P, 'a_ISO', a, 'kappa', kappa, 'nu1', nu1, 'L10', L10, 'L10m', L10m, ...
           'L10_mission', 1 / sum(t ./ L10), 'L10m_mission', 1 / sum(t ./ L10m), 'p', p);
end

function P = dgbb_load(Fr, Fa, f0_C0)
% Equivalent load of a deep groove ball bearing; columns f0 Fa/C0, e, Y
tab = [0.172 0.19 2.30; 0.345 0.22 1.99; 0.689 0.26 1.71; 1.03 0.28 1.55; 1.38 0.30 1.45; ...
       2.07 0.34 1.31; 3.45 0.38 1.15; 5.17 0.42 1.04; 6.89 0.44 1.00];
q = min(max(f0_C0 * Fa, tab(1, 1)), tab(end, 1));
e = interp1(tab(:, 1), tab(:, 2), q);
Y = interp1(tab(:, 1), tab(:, 3), q);
P = Fr;
hi = Fa > e .* Fr;
P(hi) = 0.56 * Fr(hi) + Y(hi) .* Fa(hi);
end

function a = a_iso(type, kappa, x)
if strcmp(type, 'CRB')
    A = 1.5859;  w = 0.4;  ce = 9.185;
    if kappa < 0.4
        B = 1.3993;  k = 0.054381;
    elseif kappa < 1
        B = 1.2348;  k = 0.19087;
    else
        B = 1.2348;  k = 0.071739;
    end
else
    A = 2.5671;  w = 0.83;  ce = 9.3;
    if kappa < 0.4
        B = 2.2649;  k = 0.054381;
    elseif kappa < 1
        B = 1.9987;  k = 0.19087;
    else
        B = 1.9987;  k = 0.071739;
    end
end
br = 1 - (A - B / kappa^k) * x^w;
if br <= 0
    a = 50;
else
    a = min(0.1 * br^(-ce), 50);
end
end
