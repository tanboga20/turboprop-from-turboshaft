function T = dy_case_fillets(C, in)
%DY_CASE_FILLETS  Stresses and Goodman factor on the modelled fillet arcs of the planetary case, per bracket.
%   T = dy_case_fillets(C, in)
%
%   C = dy_case_frf output (C.var(j).fillet = per fillet the largest
%   planet-pass amplitude, mean and mesh stress on the arc [MPa]), in =
%   dy_inputs (in.cs.fillets [r z R side], Goodman inputs). The Goodman
%   factor combines the three maxima of each arc (conservative where they
%   sit at different nodes of the arc).
%   Output T: one row per bracket and fillet: bracket, r_mm, z_mm, R_mm,
%   pass, mean, mesh, sf.
%   Source: Phase 3 report, Section 3.6 ("Planetary case").

cs = in.cs;  se = in.sigma_e.A357 * cs.k_gc;  su = in.su_A357;
rows = {};
for j = 1:numel(C.var)
    v = C.var(j);
    for k = 1:size(v.fillet, 1)
        p = v.fillet(k, :);  fr = cs.fillets(k, :);
        sf = 1 / (in.k_cast * ((p(3) + p(1) + cs.sa_1P) / se + p(2) / su));
        rows(end + 1, :) = {v.label, fr(1), fr(2), fr(3), p(1), p(2), p(3), sf}; %#ok<AGROW>
    end
end
T = cell2table(rows, 'VariableNames', {'bracket', 'r_mm', 'z_mm', 'R_mm', 'pass', 'mean', 'mesh', 'sf'});
end
