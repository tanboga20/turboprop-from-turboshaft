function H = as_hull(C)
%AS_HULL  Convex hull of circles as a closed outline of tangent lines and arcs.
%   H = as_hull(C)
%
%   C: rows [x y r], one circle each. The outline runs counter-clockwise
%   (seen from +Z): arcs of the hull circles joined by their outer common
%   tangents. H.segs rows [type x1 y1 x2 y2 cx cy]: type 0 a line, type 2 a
%   counter-clockwise arc about (cx, cy) (the format the CATIA scripts
%   draw, cad/scripts/catlib.vbs DrawSegs). H.area and H.perim are exact;
%   H.on lists the circles on the hull in order. A circle inside the hull
%   of the others drops out; a single circle gives one full arc (type 3:
%   [3 x y r 0 0 0]).
%   Source: Phase 3 report, Section 3.1 ("First-stage case").

n = size(C, 1);
if n == 1
    H = struct('segs', [3 C(1, :) 0 0 0], 'area', pi * C(1, 3)^2, 'perim', 2 * pi * C(1, 3), 'on', 1);
    return
end
% hull circles and their order: sample each circle finely, take the convex hull of the samples, and
% read the circle sequence off the hull vertices (the exact tangents follow from the sequence)
m = 1440;
t = (0:m - 1)' / m * 2 * pi;
P = zeros(n * m, 2);
id = zeros(n * m, 1);
for i = 1:n
    P((i - 1) * m + (1:m), :) = C(i, 1:2) + C(i, 3) * [cos(t) sin(t)];
    id((i - 1) * m + (1:m)) = i;
end
k = convhull(P(:, 1), P(:, 2));             % counter-clockwise, first point repeated
s = id(k(1:end - 1));
on = s([true; diff(s) ~= 0]);
if numel(on) > 1 && on(1) == on(end), on(end) = []; end
nh = numel(on);
if nh == 1
    H = struct('segs', [3 C(on, :) 0 0 0], 'area', pi * C(on, 3)^2, 'perim', 2 * pi * C(on, 3), 'on', on);
    return
end
% outer tangent from circle a to circle b (hull to the left of the travel direction)
T1 = zeros(nh, 2);  T2 = zeros(nh, 2);
for j = 1:nh
    a = C(on(j), :);  b = C(on(mod(j, nh) + 1), :);
    d = b(1:2) - a(1:2);  L = norm(d);  u = d / L;
    ur = [u(2), -u(1)];                     % right of the travel direction = outward
    c = (a(3) - b(3)) / L;
    nrm = c * u + sqrt(1 - c^2) * ur;
    T1(j, :) = a(1:2) + a(3) * nrm;
    T2(j, :) = b(1:2) + b(3) * nrm;
end
segs = zeros(2 * nh, 7);
area = 0;  perim = 0;
for j = 1:nh
    segs(2 * j - 1, :) = [0 T1(j, :) T2(j, :) 0 0];
    jn = mod(j, nh) + 1;                    % arc on the next circle, from the incoming to the outgoing tangent
    c = C(on(jn), :);
    segs(2 * j, :) = [2 T2(j, :) T1(jn, :) c(1:2)];
    a1 = atan2(T2(j, 2) - c(2), T2(j, 1) - c(1));
    a2 = atan2(T1(jn, 2) - c(2), T1(jn, 1) - c(1));
    da = mod(a2 - a1, 2 * pi);
    perim = perim + norm(T2(j, :) - T1(j, :)) + c(3) * da;
    % area by Green's theorem: line pieces and arc pieces of x dy - y dx
    area = area + 0.5 * (T1(j, 1) * T2(j, 2) - T1(j, 2) * T2(j, 1));
    area = area + 0.5 * (c(3)^2 * da + c(3) * c(1) * (sin(a1 + da) - sin(a1)) + c(3) * c(2) * (cos(a1) - cos(a1 + da)));
end
H = struct('segs', segs, 'area', area, 'perim', perim, 'on', on(:)');
end
