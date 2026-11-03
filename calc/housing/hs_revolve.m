function [TR, P] = hs_revolve(sec, n_seg, d_max)
%HS_REVOLVE  Closed triangulated surface of an axisymmetric part from the pieces of its (r, z) section.
%   [TR, P] = hs_revolve(sec, n_seg, d_max)
%
%   sec: the pieces of the half section [mm], rectangles [r1 r2 z1 z2] and
%   polygons (hs_poly), united into one region that must not touch the
%   axis. The outline is cut into edges of at most d_max [mm] and revolved
%   about z in n_seg steps. Output TR: triangulation in metres (outward
%   normals), ready for stlwrite and importGeometry; P the outline [mm],
%   clockwise in (r, z).
%   Source: Phase 2 report, Section 2.8 ("Models"). Tested by test_step28
%   (TC52: enclosed volume against Pappus).

ps = hs_poly(sec);
if ps.NumRegions ~= 1 || ps.NumHoles ~= 0
    error('hs_revolve:section', 'the section must be one region without holes');
end
[x, y] = boundary(ps);
P0 = [x(1:end-1), y(1:end-1)];
if 0.5 * sum(P0(:, 1) .* P0([2:end 1], 2) - P0([2:end 1], 1) .* P0(:, 2)) > 0
    P0 = flipud(P0);                                    % clockwise in (r, z): outward normals below
end
P = [];
for j = 1:size(P0, 1)
    p1 = P0(j, :);
    p2 = P0(mod(j, size(P0, 1)) + 1, :);
    m = max(1, ceil(norm(p2 - p1) / d_max));
    P = [P; p1 + (0:m - 1)' / m * (p2 - p1)]; %#ok<AGROW>
end
np = size(P, 1);
th = 2 * pi * (0:n_seg - 1)' / n_seg;
V = zeros(np * n_seg, 3);
for i = 1:n_seg
    V((i - 1) * np + (1:np), :) = [P(:, 1) * cos(th(i)), P(:, 1) * sin(th(i)), P(:, 2)];
end
F = zeros(2 * np * n_seg, 3);
c = 0;
for i = 1:n_seg
    i2 = mod(i, n_seg) + 1;
    for j = 1:np
        j2 = mod(j, np) + 1;
        a = (i - 1) * np + j;  b = (i - 1) * np + j2;  cc = (i2 - 1) * np + j2;  d = (i2 - 1) * np + j;
        F(c + 1, :) = [a b cc];
        F(c + 2, :) = [a cc d];
        c = c + 2;
    end
end
TR = triangulation(F, V / 1000);
end
