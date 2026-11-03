function A = dy_axi_mesh(sec, h)
%DY_AXI_MESH  Quadratic triangle mesh of the (r, z) half section of an axisymmetric part, for dy_axi_km.
%   A = dy_axi_mesh(sec, h)
%
%   sec: rectangles [r1 r2 z1 z2] [mm] (rows of a matrix or cells) and
%   polygons [r z] (cells), united into one region (as hs_revolve); h [mm],
%   the largest element size. The PDE Toolbox meshes
%   the 2-D region with 6-node triangles (corners 1-3, mid-side nodes 4 on
%   1-2, 5 on 2-3, 6 on 3-1; checked here).
%   Output A: X (2 x nodes, r and z [m]), T (6 x elements), the boundary
%   edges E (3 x edges: corner, corner, mid-side node) and the section
%   area [m^2].
%   Source: Phase 3 report, Section 3.6 ("First-stage gear web").

if ~iscell(sec), sec = num2cell(sec, 2); end
ns = numel(sec);
nv = max(cellfun(@(s) max(4, size(s, 1)), sec));
gd = zeros(2 + 2 * nv, ns);
names = cell(1, ns);
for k = 1:ns
    s = sec{k} / 1000;
    if numel(s) == 4                                   % rectangle [r1 r2 z1 z2]
        gd(1:10, k) = [3; 4; s(1); s(2); s(2); s(1); s(3); s(3); s(4); s(4)];
    else                                               % polygon [r z]
        m = size(s, 1);
        gd(1:2 + 2 * m, k) = [2; m; s(:, 1); s(:, 2)];
    end
    names{k} = sprintf('R%d', k);
end
g = decsg(gd, strjoin(names, '+'), char(names)');
pm = createpde();
geometryFromEdges(pm, g);
generateMesh(pm, 'Hmax', h / 1000, 'GeometricOrder', 'quadratic');
X = pm.Mesh.Nodes;
T = double(pm.Mesh.Elements);
mid = @(a, b) 0.5 * (X(:, T(a, :)) + X(:, T(b, :)));
err = max([vecnorm(X(:, T(4, :)) - mid(1, 2)), vecnorm(X(:, T(5, :)) - mid(2, 3)), vecnorm(X(:, T(6, :)) - mid(3, 1))]);
assert(err < 1e-9, 'dy_axi_mesh: unexpected node order of the quadratic triangles');
% boundary edges: element edges that belong to one element only
ed = [T([1 2 4], :), T([2 3 5], :), T([3 1 6], :)];
key = sort(ed(1:2, :), 1);
[~, ia, ic] = unique(key', 'rows');
cnt = accumarray(ic, 1);
A.E = ed(:, ia(cnt == 1));
A.X = X;
A.T = T;
v = @(a) X(:, T(a, :));
d1 = v(2) - v(1);  d2 = v(3) - v(1);
A.area = sum(abs(d1(1, :) .* d2(2, :) - d1(2, :) .* d2(1, :))) / 2;
end
