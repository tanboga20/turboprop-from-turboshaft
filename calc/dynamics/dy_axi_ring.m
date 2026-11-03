function R = dy_axi_ring(Rm, t, h, n, E, nu, rho)
%DY_AXI_RING  Check of the harmonic element (dy_axi_km): bending modes of a slender free ring of square section.
%   R = dy_axi_ring(Rm, t, h, n, E, nu, rho)
%
%   Ring of mean radius Rm and square section t x t [mm], meshed at h [mm],
%   free; harmonics n (>= 2). For each n the lowest mode with mostly
%   radial motion (in-plane bending) and the lowest with mostly axial
%   motion (out-of-plane bending with torsion). Compared in test_step36
%   with the thin-ring closed forms (step36_reference.py):
%     in-plane      w^2 = E I / (rho A Rm^4) n^2 (n^2 - 1)^2 / (n^2 + 1)
%     out-of-plane  w^2 = E I / (rho A Rm^4) n^2 (n^2 - 1)^2 / (n^2 + E I / (G J))
%   Output R: n, f_in, f_out [Hz].
%   Source: Phase 3 report, Section 3.6 ("Model checks").

A = dy_axi_mesh([Rm - t / 2, Rm + t / 2, 0, t], h);
nn = size(A.X, 2);
R.n = n;  R.f_in = zeros(size(n));  R.f_out = R.f_in;
for k = 1:numel(n)
    [K, M] = dy_axi_km(A, n(k), E, nu, rho);
    [V, L2] = eigs(K, M, 6, 'smallestabs');
    [w2, o] = sort(real(diag(L2)));  V = V(:, o);
    ur = sum(V(1:3:3 * nn, :).^2, 1);  uz = sum(V(3:3:3 * nn, :).^2, 1);
    f = sqrt(max(w2, 0)) / (2 * pi);
    R.f_in(k) = f(find(ur > uz, 1));
    R.f_out(k) = f(find(uz > ur, 1));
end
end
