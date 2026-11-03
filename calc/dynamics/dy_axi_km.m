function [K, M, Sg] = dy_axi_km(A, n, E, nu, rho, sel)
%DY_AXI_KM  Stiffness and mass of an axisymmetric solid for one circumferential harmonic n (semi-analytical FE).
%   [K, M] = dy_axi_km(A, n, E, nu, rho)
%   [K, M, Sg] = dy_axi_km(A, n, E, nu, rho)
%   [K, M, Sg] = dy_axi_km(A, n, E, nu, rho, sel)
%
%   A = dy_axi_mesh output (6-node triangles in (r, z) [m]). The
%   displacement is u_r = U(r, z) cos n theta, u_theta = V(r, z) sin n
%   theta, u_z = W(r, z) cos n theta (the family symmetric about theta = 0);
%   degrees of freedom [U V W] per node. Strains [eps_r eps_theta eps_z
%   gam_rz] go with cos n theta, [gam_rtheta gam_thetaz] with sin n theta:
%     eps_r = U,r   eps_theta = (U + n V) / r   eps_z = W,z   gam_rz = U,z + W,r
%     gam_rtheta = V,r - (V + n U) / r          gam_thetaz = V,z - n W / r
%   The integral over theta gives the factor pi for n >= 1 and 2 pi for
%   n = 0 (V is then the torsion about the axis). E, nu, rho: scalars or one
%   value per element. 7-point Gauss rule on straight-sided triangles.
%   Output: K, M sparse [3 nodes x 3 nodes] such that the virtual work of
%   a load f(r, z) cos n theta is F' dU with F built with the same factor
%   (dy_web); Sg (6 x 3 nodes sparse) gives the nodal stress amplitudes
%   [sig_r sig_theta sig_z tau_rz tau_rtheta tau_thetaz] = Sg U, averaged
%   over the elements that share a node; with sel (logical, one per
%   element) only over the selected elements (zero rows at nodes of no
%   selected element), e.g. the stresses of one material at an interface.
%   Source: Phase 3 report, Section 3.6 ("First-stage gear web").

X = A.X;  T = A.T;  ne = size(T, 2);  nn = size(X, 2);
if nargin < 6 || isempty(sel), sel = true(1, ne); end
c = pi;  if n == 0, c = 2 * pi; end
Dm = @(E_, nu_) blkdiag(E_ * nu_ / ((1 + nu_) * (1 - 2 * nu_)) * ones(3) + E_ / (1 + nu_) * eye(3), E_ / (2 * (1 + nu_)) * eye(3));
a1 = 0.0597158717;  b1 = 0.4701420641;  a2 = 0.7974269853;  b2 = 0.1012865073;
Lg = [1/3 1/3 1/3; a1 b1 b1; b1 a1 b1; b1 b1 a1; a2 b2 b2; b2 a2 b2; b2 b2 a2];
wg = [0.225, 0.1323941527 * [1 1 1], 0.1259391805 * [1 1 1]];
Ln = [1 0 0; 0 1 0; 0 0 1; 0.5 0.5 0; 0 0.5 0.5; 0.5 0 0.5];   % area coordinates of the 6 nodes
I = zeros(324, ne);  J = I;  Kv = I;  Mv = I;
if nargout > 2, Si = zeros(108 * 6, ne);  Sj = Si;  Sv = Si; end
for e = 1:ne
    t = T(:, e);
    r = X(1, t);  z = X(2, t);
    br = [z(2) - z(3), z(3) - z(1), z(1) - z(2)];
    bz = [r(3) - r(2), r(1) - r(3), r(2) - r(1)];
    A2 = r(2) * z(3) - r(3) * z(2) - r(1) * z(3) + r(3) * z(1) + r(1) * z(2) - r(2) * z(1);
    dL = [br; bz] / A2;                                % dL_i / d(r, z), 2 x 3
    D = Dm(E(min(e, numel(E))), nu(min(e, numel(nu))));
    Ke = zeros(18);  Me = zeros(18);
    for g = 1:7
        [N, dN] = shp(Lg(g, :), dL);
        rg = N * r';
        B = bmat(N, dN, rg, n);
        Nm = zeros(3, 18);  Nm(1, 1:3:end) = N;  Nm(2, 2:3:end) = N;  Nm(3, 3:3:end) = N;
        w = c * wg(g) * abs(A2) / 2 * rg;
        Ke = Ke + w * (B' * D * B);
        Me = Me + w * rho(min(e, numel(rho))) * (Nm' * Nm);
    end
    dof = reshape([3 * t' - 2; 3 * t' - 1; 3 * t'], 1, []);
    [jj, ii] = meshgrid(dof, dof);
    I(:, e) = ii(:);  J(:, e) = jj(:);  Kv(:, e) = Ke(:);  Mv(:, e) = Me(:);
    if nargout > 2 && sel(e)
        Se = zeros(36, 18);
        for q = 1:6
            [N, dN] = shp(Ln(q, :), dL);
            Se(6 * q - 5:6 * q, :) = D * bmat(N, dN, r(q), n);
        end
        rows = reshape(repmat(6 * (t' - 1), 6, 1) + (1:6)', [], 1);
        [jj, ii] = meshgrid(dof, rows);
        Si(:, e) = ii(:);  Sj(:, e) = jj(:);  Sv(:, e) = Se(:);
    end
end
K = sparse(I(:), J(:), Kv(:), 3 * nn, 3 * nn);  K = (K + K') / 2;
M = sparse(I(:), J(:), Mv(:), 3 * nn, 3 * nn);  M = (M + M') / 2;
if nargout > 2
    Ts = T(:, sel);  cnt = accumarray(Ts(:), 1, [nn 1]);
    Si = Si(:, sel);  Sj = Sj(:, sel);  Sv = Sv(:, sel);
    Sg = sparse(Si(:), Sj(:), Sv(:), 6 * nn, 3 * nn);
    Sg = spdiags(1 ./ kron(max(cnt, 1), ones(6, 1)), 0, 6 * nn, 6 * nn) * Sg;
end
end

function [N, dN] = shp(L, dL)
% quadratic triangle: N (1 x 6), dN (2 x 6) in (r, z)
N = [L(1) * (2 * L(1) - 1), L(2) * (2 * L(2) - 1), L(3) * (2 * L(3) - 1), 4 * L(1) * L(2), 4 * L(2) * L(3), 4 * L(3) * L(1)];
dNdL = [4 * L(1) - 1, 0, 0, 4 * L(2), 0, 4 * L(3);
        0, 4 * L(2) - 1, 0, 4 * L(1), 4 * L(3), 0;
        0, 0, 4 * L(3) - 1, 0, 4 * L(2), 4 * L(1)];
dN = dL * dNdL;
end

function B = bmat(N, dN, r, n)
B = zeros(6, 18);
iu = 1:3:18;  iv = 2:3:18;  iw = 3:3:18;
B(1, iu) = dN(1, :);
B(2, iu) = N / r;  B(2, iv) = n * N / r;
B(3, iw) = dN(2, :);
B(4, iu) = dN(2, :);  B(4, iw) = dN(1, :);
B(5, iu) = -n * N / r;  B(5, iv) = dN(1, :) - N / r;
B(6, iv) = dN(2, :);  B(6, iw) = -n * N / r;
end
