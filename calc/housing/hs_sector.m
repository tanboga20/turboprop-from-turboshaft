function TR = hs_sector(P, th, n_sub)
%HS_SECTOR  Closed surface of a section outline revolved over a sector, on the facets of the global case.
%   TR = hs_sector(P, th, n_sub)
%
%   P: outline [mm], clockwise in (r, z) (hs_section); th: increasing facet
%   angles of the global model, from the first to the last [rad] (for the
%   case, multiples of 2 pi / n_seg); n_sub: points per facet. Between two
%   facet angles the surface runs on the chord, as the global faceted
%   surface does, so that the submodel and the global model share their
%   surfaces. The sector is closed by plane caps at th(1) and th(end).
%   Output TR: triangulation in metres with outward normals.
%   Source: Phase 2 report, Section 2.8 ("Verification"). Used by
%   hs_submodel.

np = size(P, 1);
% angular stations: facet ends and chord points, as [facet start angle, facet end angle, t]
S = zeros(0, 3);
for k = 1:numel(th) - 1
    t = (0:n_sub - 1)' / n_sub;
    S = [S; repmat(th(k:k + 1), n_sub, 1), t]; %#ok<AGROW>
end
S = [S; th(end - 1:end), 1];
ns = size(S, 1);
V = zeros(np * ns, 3);
for i = 1:ns
    ea = [cos(S(i, 1)), sin(S(i, 1))];  eb = [cos(S(i, 2)), sin(S(i, 2))];
    e = (1 - S(i, 3)) * ea + S(i, 3) * eb;                % on the chord, not the circle
    V((i - 1) * np + (1:np), :) = [P(:, 1) * e(1), P(:, 1) * e(2), P(:, 2)];
end
F = zeros(2 * np * (ns - 1), 3);
c = 0;
for i = 1:ns - 1
    for j = 1:np
        j2 = mod(j, np) + 1;
        a = (i - 1) * np + j;  b = (i - 1) * np + j2;  cc = i * np + j2;  d = i * np + j;
        F(c + 1, :) = [a b cc];
        F(c + 2, :) = [a cc d];
        c = c + 2;
    end
end
dt = delaunayTriangulation(P, [(1:np)', [2:np 1]']);
T = dt.ConnectivityList(isInterior(dt), :);              % counter-clockwise in (r, z): normal -theta
F = [F; T; T(:, [1 3 2]) + (ns - 1) * np];                % first cap faces -theta, last cap +theta
TR = triangulation(F, V / 1000);
end
