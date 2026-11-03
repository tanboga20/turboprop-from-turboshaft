function S = dy_tet10_stress(X, T, E, nu, U)
%DY_TET10_STRESS  Nodal stresses of a quadratic tetrahedron mesh for a displacement field (real or complex).
%   S = dy_tet10_stress(X, T, E, nu, U)
%
%   X (3 x nodes) [m], T (10 x elements, PDE Toolbox order: corners 1-4,
%   then the mid-side nodes, identified here from their positions), E [Pa],
%   nu; U (3 nodes x m), displacements in the toolbox order [ux of all nodes;
%   uy; uz], m load cases. The strain is evaluated at the element nodes
%   (straight-edged elements, constant Jacobian) and the stress averaged
%   over the elements that share a node.
%   Output S: nodes x 6 x m, [sxx syy szz sxy syz sxz] [Pa].
%   Source: Phase 3 report, Section 3.6 ("Planet").

nn = size(X, 2);  ne = size(T, 2);  m = size(U, 2);
% mid-side node of each corner pair, from the first element (checked on all)
pairs = [1 2; 2 3; 1 3; 1 4; 2 4; 3 4];
e1 = T(:, 1);  ms = zeros(1, 6);
for k = 1:6
    pm = (X(:, e1(pairs(k, 1))) + X(:, e1(pairs(k, 2)))) / 2;
    [~, j] = min(vecnorm(X(:, e1(5:10)) - pm));  ms(k) = 4 + j;
end
for k = 1:6
    err = max(vecnorm(X(:, T(ms(k), :)) - (X(:, T(pairs(k, 1), :)) + X(:, T(pairs(k, 2), :))) / 2));
    assert(err < 1e-9, 'dy_tet10_stress: unexpected node order');
end
lam = E * nu / ((1 + nu) * (1 - 2 * nu));  G = E / (2 * (1 + nu));
D = blkdiag([lam + 2 * G, lam, lam; lam, lam + 2 * G, lam; lam, lam, lam + 2 * G], G * eye(3));
% area coordinates of the 10 nodes (corners, then the mid-sides in the order of 'pairs')
Ln = [eye(4); zeros(6, 4)];
for k = 1:6, Ln(4 + k, pairs(k, :)) = 0.5; end
S = zeros(nn, 6, m);  cnt = zeros(nn, 1);
Ux = reshape(U(1:nn, :), nn, 1, m);  Uy = reshape(U(nn + 1:2 * nn, :), nn, 1, m);  Uz = reshape(U(2 * nn + 1:end, :), nn, 1, m);
for e = 1:ne
    t = T(:, e);  tl = [t(1:4); t(ms)];               % local order: corners, then mid-sides of 'pairs'
    P = [ones(1, 4); X(:, t(1:4))];
    dL = P \ [zeros(1, 3); eye(3)];                  % 4 x 3: d L_i / d(x, y, z)
    ux = squeeze(Ux(tl, 1, :));  uy = squeeze(Uy(tl, 1, :));  uz = squeeze(Uz(tl, 1, :));
    if m == 1, ux = ux(:);  uy = uy(:);  uz = uz(:); end
    for q = 1:10
        L = Ln(q, :);
        dN = zeros(10, 3);                           % d N / d(x, y, z)
        for i = 1:4, dN(i, :) = (4 * L(i) - 1) * dL(i, :); end
        for k = 1:6
            a = pairs(k, 1);  b = pairs(k, 2);
            dN(4 + k, :) = 4 * (L(a) * dL(b, :) + L(b) * dL(a, :));
        end
        ex = dN(:, 1)' * ux;  ey = dN(:, 2)' * uy;  ez = dN(:, 3)' * uz;
        gxy = dN(:, 2)' * ux + dN(:, 1)' * uy;
        gyz = dN(:, 3)' * uy + dN(:, 2)' * uz;
        gxz = dN(:, 3)' * ux + dN(:, 1)' * uz;
        sg = D * [ex; ey; ez; gxy; gyz; gxz];         % 6 x m
        S(tl(q), :, :) = S(tl(q), :, :) + reshape(sg, 1, 6, m);
        cnt(tl(q)) = cnt(tl(q)) + 1;
    end
end
S = S ./ cnt;
end
