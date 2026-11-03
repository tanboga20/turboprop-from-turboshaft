function ps = hs_poly(sec)
%HS_POLY  Region of an axisymmetric section from its pieces.
%   ps = hs_poly(sec)
%
%   sec: matrix of rectangles, one row [r1 r2 z1 z2] each, or a cell array
%   whose cells are rectangles (1 x 4) or polygons (K x 2 vertices [r z]),
%   all in mm. The pieces are united; they may overlap. Output ps:
%   polyshape in (r, z) [mm].
%   Source: Phase 2 report, Section 2.8 ("Models"). Used by hs_revolve and
%   hs_section.

if isnumeric(sec)
    sec = num2cell(sec, 2);
end
ps = polyshape();
for k = 1:numel(sec)
    p = sec{k};
    if isequal(size(p), [1 4])
        p = [p(1) p(3); p(2) p(3); p(2) p(4); p(1) p(4)];
    end
    ps = union(ps, polyshape(p(:, 1), p(:, 2)));
end
end
