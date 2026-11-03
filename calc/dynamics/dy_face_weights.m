function w = dy_face_weights(X, T, fn)
%DY_FACE_WEIGHTS  Consistent nodal weights of a uniform traction on a face of a quadratic tetrahedron mesh.
%   w = dy_face_weights(X, T, fn)
%
%   X (3 x nodes) [m], T (10 x elements, PDE Toolbox order), fn = the nodes
%   of the face (findNodes). The boundary triangles whose six nodes all lie
%   on the face carry the load; on a straight-sided 6-node triangle a
%   uniform traction gives nothing at the corners and a third of the area
%   at each mid-side node. Output w (nodes x 1) [m^2]: sum(w) is the face
%   area (to the faceting of the mesh).
%   Source: Phase 3 report, Section 3.6 ("Planet").

nn = size(X, 2);
pairs = [1 2; 2 3; 1 3; 1 4; 2 4; 3 4];
e1 = T(:, 1);  ms = zeros(1, 6);
for k = 1:6
    pm = (X(:, e1(pairs(k, 1))) + X(:, e1(pairs(k, 2)))) / 2;
    [~, j] = min(vecnorm(X(:, e1(5:10)) - pm));  ms(k) = 4 + j;
end
tri = [1 2 3; 1 2 4; 1 3 4; 2 3 4];
mid = @(a, b) ms(all(sort(pairs, 2) == sort([a b]), 2));
F = [];
for t = 1:4
    c = tri(t, :);
    F = [F, [T(c, :); T(mid(c(1), c(2)), :); T(mid(c(2), c(3)), :); T(mid(c(1), c(3)), :)]]; %#ok<AGROW>
end
key = sort(F(1:3, :), 1)';
[~, ia, ic] = unique(key, 'rows');
cnt = accumarray(ic, 1);
F = F(:, ia(cnt == 1));                              % boundary triangles
on = false(nn, 1);  on(fn) = true;
F = F(:, all(on(F), 1));
a = X(:, F(2, :)) - X(:, F(1, :));  b = X(:, F(3, :)) - X(:, F(1, :));
A = vecnorm(cross(a, b)) / 2;
w = accumarray(reshape(F(4:6, :), [], 1), repelem(A / 3, 3)', [nn 1]);
end
