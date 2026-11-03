function B = hs_bench_hole(h, p)
%HS_BENCH_HOLE  Peak stress at a hole in a tension plate: the local-stress benchmark of the step 2.8 solver.
%   B = hs_bench_hole(h)
%   B = hs_bench_hole(h, p)
%
%   h: target element size on the hole surface [mm]. p (optional): W, d,
%   L, t [mm] (plate width, hole diameter, length, thickness), Hmax [mm]
%   (elsewhere), s0 [MPa] (remote tension).
%
%   One eighth of the plate (x >= 0, y >= 0, 0 <= z <= t/2) with roller
%   symmetry planes through the hole centre and the mid-plane, the same pipeline as
%   the housing (closed STL surface, importGeometry, quadratic tetrahedra,
%   static solve). The largest nodal sxx on the hole surface over the
%   remote stress is the gross stress concentration factor, compared with
%   Heywood's fit to Howland's solution, Ktn = 2 + (1 - d/W)^3 on the net
%   section (3.14 gross at d/W = 0.2).
%
%   Output struct B: h [mm], Kt (FE), n_nodes, fe (mesh and results).
%   Source: Phase 2 report, Section 2.8 ("Verification"). Tested by
%   test_step28 (TC55).

if nargin < 2
    p = struct('W', 100, 'd', 20, 'L', 300, 't', 4, 'Hmax', 4, 's0', 100);
end
a = p.d / 2;  X = p.L / 2;  Y = p.W / 2;  T = p.t / 2;
n_arc = 48;
ph = linspace(pi / 2, 0, n_arc + 1)';
P = [a * cos(ph), a * sin(ph); X 0; X Y; 0 Y];       % hole arc from (0, a) to (a, 0), then the outer edges
P = P([1:n_arc + 1, n_arc + 2:end], :);
if signed_area(P) < 0, P = flipud(P); end               % counter-clockwise in (x, y)
TR = prism(P, T);
file = [tempname '.stl'];
stlwrite(TR, file);
m = createpde('structural', 'static-solid');
importGeometry(m, file);
delete(file);
structuralProperties(m, 'YoungsModulus', 206e9, 'PoissonsRatio', 0.3);
gm = m.Geometry;
f_hole = nearestFace(gm, [a * cos(pi / 4), a * sin(pi / 4), T / 2] / 1000);
generateMesh(m, 'Hmax', p.Hmax / 1000, 'Hface', {f_hole, h / 1000}, 'GeometricOrder', 'quadratic');
% Symmetry planes as rollers: only the normal displacement is held. (The toolbox's 'symmetric'
% constraint gave a wrong stress through the thickness here, about 15 % high at the free surface
% and low at the mid-plane, so it is not used in step 2.8.)
structuralBC(m, 'Face', nearestFace(gm, [0, (a + Y) / 2, T / 2] / 1000), 'XDisplacement', 0);
structuralBC(m, 'Face', nearestFace(gm, [(a + X) / 2, 0, T / 2] / 1000), 'YDisplacement', 0);
structuralBC(m, 'Face', nearestFace(gm, [X / 2, Y / 2, 0] / 1000), 'ZDisplacement', 0);
structuralBoundaryLoad(m, 'Face', nearestFace(gm, [X, Y / 2, T / 2] / 1000), 'SurfaceTraction', [p.s0 * 1e6; 0; 0]);
R = solve(m);
nodes = findNodes(m.Mesh, 'region', 'Face', f_hole);
B = struct('h', h, 'Kt', max(R.Stress.sxx(nodes)) / (p.s0 * 1e6), 'n_nodes', size(m.Mesh.Nodes, 2), ...
           'fe', struct('mesh', m.Mesh, 'R', R));
end

function A = signed_area(P)
A = 0.5 * sum(P(:, 1) .* P([2:end 1], 2) - P([2:end 1], 1) .* P(:, 2));
end

function TR = prism(P, T)
% Closed surface of the counter-clockwise polygon P [mm] extruded from z = 0 to T [mm], in metres
n = size(P, 1);
V = [P, zeros(n, 1); P, T * ones(n, 1)];
dt = delaunayTriangulation(P, [(1:n)', [2:n 1]']);
C = dt.ConnectivityList(isInterior(dt), :);               % counter-clockwise: normal +z
F = [C(:, [1 3 2]); C + n];                               % bottom faces down, top faces up
j = (1:n)';  j2 = [2:n 1]';
F = [F; j, j2, j2 + n; j, j2 + n, j + n];                 % side walls, outward for a counter-clockwise outline
TR = triangulation(F, V / 1000);
end
