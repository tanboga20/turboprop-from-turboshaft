function V = sf_nr_check()
%SF_NR_CHECK  sf_nr against the finite-element values published with the Newman-Raju equations.
%   V = sf_nr_check()   table of equation, FE value and difference per point
%   Surface crack: NASA TP-1578 (1979) Table I, c/b = 0.2, nu = 0.3 (tension F, bending H F). Corner crack in
%   bending: NASA TM-85793 (1984) Table 2 (H_c F_c). Corner crack in tension: NASA TM-89070 (Raju and Newman,
%   1987) Table 1, c/b = 0.04 (the D4 corner crack sits at small c/b). The equations claim about 5% of the case
%   maximum for a/t <= 0.8. The corner rows at a/c = 2 lie outside the range used in D4 (cracks start at a/c = 1,
%   sf_dt stops a corner crack beyond a/c = 1.2 and sf_nr beyond c/b = 0.5): against TM-89070 Table 1 (c/b 0.04) the
%   tension rows at a/c = 2 agree within 5% and the bending rows within 9%, except the deepest point at a/t = 0.8,
%   where the bending correction H of the a/c > 1 branch goes negative (-0.13 against 0.81). The TM-85793 Table 2
%   bending rows at a/c = 2 used before (17-43% off) are replaced by the TM-89070 rows. Against TM-89070 tension the
%   corner equations lie above the FE (conservative) by up to 13% at a/t = 0.8.
%   Source: Phase 3 report, Section 3.7 (D4, verification).

% kind (1 surface, 2 corner), load (1 tension, 2 bending), a/c, a/t, 2 phi / pi, FE value
P = [1 1 0.2 0.2 0 0.617; 1 1 0.2 0.2 1 1.173; 1 1 0.2 0.8 0 1.190; 1 1 0.2 0.8 1 1.851;
     1 1 0.4 0.4 0 0.896; 1 1 0.4 0.4 1 1.225; 1 1 1.0 0.2 0 1.174; 1 1 1.0 0.2 1 1.049;
     1 1 1.0 0.8 0 1.464; 1 1 1.0 0.8 1 1.112; 1 1 2.0 0.4 0 0.848; 1 1 2.0 0.4 1 0.501;
     1 2 0.2 0.2 0 0.572; 1 2 0.2 0.2 1 0.862; 1 2 1.0 0.2 0 1.076; 1 2 1.0 0.2 1 0.742;
     1 2 1.0 0.6 0 1.003; 1 2 1.0 0.6 1 0.207;
     2 2 0.2 0.2 0 0.522; 2 2 0.2 0.2 1 0.876; 2 2 1.0 0.2 0 1.084; 2 2 1.0 0.2 1 0.839;
     2 2 1.0 0.5 0 1.046; 2 2 1.0 0.5 1 0.407;
     2 1 1.0 0.2 0 1.1480; 2 1 1.0 0.2 1 1.1653; 2 1 1.0 0.5 0 1.2421; 2 1 1.0 0.5 1 1.2041;
     2 1 1.0 0.8 0 1.4313; 2 1 1.0 0.8 1 1.3720; 2 1 0.4 0.2 0 0.7851; 2 1 0.4 0.2 1 1.1316;
     2 1 0.4 0.5 0 0.9498; 2 1 0.4 0.5 1 1.3250; 2 1 0.4 0.8 0 1.2761; 2 1 0.4 0.8 1 1.6630;
     2 1 0.2 0.5 0 0.7905; 2 1 0.2 0.5 1 1.5232;
     2 1 2.0 0.2 0 0.8006; 2 1 2.0 0.2 1 0.5860; 2 1 2.0 0.8 0 0.8636; 2 1 2.0 0.8 1 0.6460;
     3 2 2.0 0.2 0 0.7361; 3 2 2.0 0.2 1 0.3975; 3 2 2.0 0.8 0 0.6118; 3 2 2.0 0.8 1 0.8142];
% kind 3: corner crack in bending (about x) of TM-89070 Table 1 at c/b 0.04, which replaces the a/c = 2 bending rows
% of TM-85793 Table 2 (those were 17-43% off; that table is for another width ratio)
src = repmat("TP-1578 Table I", size(P, 1), 1);  src(P(:, 1) == 2) = "TM-85793 Table 2";
src(P(:, 1) == 2 & P(:, 2) == 1 | P(:, 1) == 3) = "TM-89070 Table 1 (c/b 0.04)";
P(P(:, 1) == 3, 1) = 2;
kinds = {'surface', 'corner'};  loads = {'tension', 'bending'};
n = size(P, 1);
eq = zeros(n, 1);
t = 10;
for i = 1:n
    a = P(i, 4) * t;  c = a / P(i, 3);
    if P(i, 1) == 1, b = c / 0.2; elseif src(i) == "TM-89070 Table 1 (c/b 0.04)", b = c / 0.04; else, b = 1e6 * t; end
    [Ft, Fb] = sf_nr(kinds{P(i, 1)}, a, c, t, b, P(i, 5) * pi / 2);
    if P(i, 2) == 1, eq(i) = Ft; else, eq(i) = Fb; end
end
in_use = ~(P(:, 1) == 2 & P(:, 3) > 1.2);
V = table(string(kinds(P(:, 1))'), string(loads(P(:, 2))'), P(:, 3), P(:, 4), P(:, 5), P(:, 6), eq, ...
          100 * (eq ./ P(:, 6) - 1), in_use, src, 'VariableNames', {'crack', 'load', 'a_c', 'a_t', 'phi_2_pi', ...
          'FE', 'equation', 'diff_pct', 'in_D4_range', 'source'});
end
