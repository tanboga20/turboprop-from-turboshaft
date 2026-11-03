function P = dy_planet_frf(in, pp, bands)
%DY_PLANET_FRF  Forced response of the planet on its rollers and meshes to the transmission error (DYN-03, DYN-04).
%   P = dy_planet_frf(in, pp, bands)
%
%   in = dy_inputs; pp = planet data: D_or, d_root, b, h_teeth [mm], E, nu,
%   rho, Z (rollers), Lwe [mm], F [N] (radial roller load), k_sp, k_pr
%   [N/m] (sun-planet and planet-ring mesh stiffness), c_sp, c_pr (load
%   asymmetry over the face, K_Hbeta - 1, step 2.4), alpha [rad] (working
%   pressure angle), psi_mesh [rad] (mesh patch), Ft [N] (static tangential
%   tooth force per mesh), Kv24 = [sun-planet planet-ring] and SF24 (planet-
%   side tooth-root safety factors of step 2.4); bands = 3 x 2 [Hz], the
%   1x, 2x and 3x planetary mesh bands with the speed range.
%   The planet annulus (teeth as mass, quadratic tetrahedra) is assembled
%   with assembleFEMatrices; the face loads use consistent nodal weights
%   (dy_face_weights), since that assembly leaves out surface tractions. The rollers and the two meshes are springs
%   added as full tensors k n n' along their own directions: radial
%   springs over the loaded half of the bore, opposite the net mesh force
%   (roller stiffness at the roller load, ISO/TR 1281-1 line contact), and mesh springs along the
%   line of action on a root patch at -90 deg (sun) and +90 deg (ring),
%   both pushing towards the planet centre. A soft axial spring (1e6 N/m)
%   holds the axial rigid motion. Step 2.8 put the springs on the global
%   axes, diag(k cos^2, k sin^2, 0), which drops the coupling k cos sin
%   and adds a spin stiffness the rollers do not have.
%   Excitation of harmonic h: the transmission error TE_h (in.TE_planet) at each mesh, a
%   load k TE_h on its patch along its line of action, spread over the face
%   as 1 + c (2 z / b - 1). The sun and ring meshes are separate load cases,
%   combined with their relative phase phi swept over 0 ... 2 pi
%   (envelope). Response by modal superposition (modes up to in.f_cut_planet
%   x the 3x band top, modal damping in.zeta) plus the static residual.
%   Outputs per harmonic h (P.h(h)), over the band (in.n_freq points and the
%   modes inside it):
%   - Fd_sp, Fd_pr: dynamic tooth force at each mesh, the patch resultant
%     of k (TE - delta), envelope over phi [N];
%   - Kv_sp, Kv_pr = 1 + max Fd / (K_A F_t) (in.KA), against the step 2.4
%     K_v; SF_sp, SF_pr, the tooth-root safety factors rescaled by K_v;
%   - Fr_sun, Fr_ring: the complex ring-mesh force for the sun and the ring
%     load cases (input of dy_case_frf);
%   - u_max [um]; sig_rim [MPa], the cycle-maximum von Mises of the annulus
%     (rim check), with sf_rim, its Goodman factor with the steady stress
%     of the static mesh forces (Pyrowear 53 core).
%   P.f_all, P.kind: the modes and their dominant rigid-body motion; P.mod,
%   the modal model of the mesh forces for dy_planet_forces (coupling to
%   the ring and case in dy_case_frf).
%   Source: Phase 3 report, Section 3.6 ("Planet").

p = pp;
model = createpde('structural', 'modal-solid');
gm = multicylinder([p.D_or, p.d_root] / 2000, p.b / 1000, 'Void', [true, false]);
model.Geometry = gm;
hgt = (p.d_root - p.D_or) / 2;
rho_eq = p.rho * (hgt + p.h_teeth) / hgt;
structuralProperties(model, 'YoungsModulus', p.E, 'PoissonsRatio', p.nu, 'MassDensity', rho_eq);
generateMesh(model, 'Hmax', in.Hmax_planet, 'GeometricOrder', 'quadratic');
FE = assembleFEMatrices(model);
K = FE.K;  M = FE.M;
X = model.Mesh.Nodes;  N = size(X, 2);
f_bore = nearestFace(gm, [p.D_or / 2000, 0, p.b / 2000]);
f_out = nearestFace(gm, [p.d_root / 2000, 0, p.b / 2000]);
% nodal area weights of the two faces (consistent load of a uniform traction)
Tm = model.Mesh.Elements;
wb = dy_face_weights(X, Tm, findNodes(model.Mesh, 'region', 'Face', f_bore));
wo = dy_face_weights(X, Tm, findNodes(model.Mesh, 'region', 'Face', f_out));
psi = atan2(X(2, :), X(1, :))';  zz = X(3, :)';
dofs = @(i) [i, N + i, 2 * N + i];
% springs as tensors k n n'
Qmax = 4.08 * p.F / p.Z;
A_roll = pi * p.D_or / p.Z * p.b * 1e-6;
kr = @(Q) Q.^0.1 * p.Lwe^0.8 / (0.9 * 3.84e-5) * 1e3 / 2;
I = [];  J = [];  V = [];
    function add(i, kk, nv)
        Kn = kk * (nv(:) * nv(:)');
        [jj, ii] = meshgrid(dofs(i), dofs(i));
        I = [I; ii(:)];  J = [J; jj(:)];  V = [V; Kn(:)];
    end
nb = find(wb > 0);
for i = nb'                                          % loaded zone opposite the net mesh force (+x): cos psi < 0
    c = -cos(psi(i));
    if c > 0, add(i, kr(Qmax * c^(10/9)) / A_roll * wb(i), [cos(psi(i)), sin(psi(i)), 0]); end
    add(i, 1e6 * wb(i) / sum(wb), [0 0 1]);           % soft axial support
end
ds = [cos(p.alpha), sin(p.alpha), 0];                 % sun patch at -90 deg: tangential +x, towards the centre +y
dr = [cos(p.alpha), -sin(p.alpha), 0];                % ring patch at +90 deg: tangential +x, towards the centre -y
ps = find(wo > 0 & abs(angle(exp(1i * (psi + pi / 2)))) <= p.psi_mesh / 2);
pr = find(wo > 0 & abs(angle(exp(1i * (psi - pi / 2)))) <= p.psi_mesh / 2);
ws = zeros(size(wo));  ws(ps) = wo(ps) / sum(wo(ps));   % patch shares: the springs and loads sum exactly to k and F
wr = zeros(size(wo));  wr(pr) = wo(pr) / sum(wo(pr));
for i = ps', add(i, p.k_sp * ws(i), ds); end
for i = pr', add(i, p.k_pr * wr(i), dr); end
Kt = K + sparse(I, J, V, 3 * N, 3 * N);
% patch operators: delta = sum k w (d . u) and the TE loads (unit TE) with the face asymmetry
As = sparse(1, 3 * N);  Ar = As;  fs = zeros(3 * N, 1);  fr = fs;  fst = fs;
for i = ps'
    kk = p.k_sp * ws(i);  wz = 1 + p.c_sp * (2 * zz(i) / (p.b / 1000) - 1);
    As(dofs(i)) = kk * ds;  fs(dofs(i)) = kk * wz * ds;
    fst(dofs(i)) = fst(dofs(i)) + p.Ft / cos(p.alpha) * ws(i) * wz * ds';
end
for i = pr'
    kk = p.k_pr * wr(i);  wz = 1 + p.c_pr * (2 * zz(i) / (p.b / 1000) - 1);
    Ar(dofs(i)) = kk * dr;  fr(dofs(i)) = kk * wz * dr;
    fst(dofs(i)) = fst(dofs(i)) + p.Ft / cos(p.alpha) * wr(i) * wz * dr';
end
% modes
f_cut = in.f_cut_planet * max(bands(:));
nm = 30;
while true
    [Vm, L2] = eigs(Kt, M, nm, 'smallestabs');
    [w2, o] = sort(real(diag(L2)));  Vm = Vm(:, o);
    if sqrt(max(w2(end), 0)) / (2 * pi) > f_cut || nm >= 150, break; end
    nm = nm + 30;
end
keep = sqrt(max(w2, 0)) / (2 * pi) <= f_cut;
Vm = Vm(:, keep);  w = sqrt(max(w2(keep), 1));
Vm = Vm ./ sqrt(sum(Vm .* (M * Vm), 1));
P.f_all = w' / (2 * pi);
% dominant rigid-body motion of each mode
xc = mean(X, 2);
rb = zeros(3 * N, 6);
rb(1:N, 1) = 1;  rb(N + 1:2 * N, 2) = 1;  rb(2 * N + 1:end, 3) = 1;
dx = X(1, :)' - xc(1);  dy = X(2, :)' - xc(2);  dz = X(3, :)' - xc(3);
rb(:, 4) = [zeros(N, 1); -dz; dy];                   % rotation about x
rb(:, 5) = [dz; zeros(N, 1); -dx];                   % about y
rb(:, 6) = [-dy; dx; zeros(N, 1)];                   % about z (spin)
pt = (Vm' * M * rb).^2 ./ sum(rb .* (M * rb), 1);
names = {'x', 'y', 'z', 'rx', 'ry', 'spin'};
[pmax, kmax] = max(pt, [], 2);
P.kind = names(kmax);  P.kind(pmax < 0.3) = {'elastic'};
% static: residuals of the unit TE loads, and the steady stress of the static mesh forces
Us = Kt \ [fs, fr, fst];
Sall = dy_tet10_stress(X, Tm, p.E, p.nu, [Vm, Us]);
Sm = Sall(:, :, 1:end - 3);  Sres = Sall(:, :, end - 2:end - 1);  Sst = Sall(:, :, end);
vm_st = dy_vm_cycle(Sst, 0 * Sst) / 1e6;
gs = Vm' * fs;  gr = Vm' * fr;
% modal model of the mesh forces per unit TE (dy_planet_forces: any frequency, no interpolation)
P.mod = struct('w', w, 'gs', gs, 'gr', gr, 'AsV', full(As * Vm), 'ArV', full(Ar * Vm), 'AsU', full(As * Us(:, 1:2)), ...
               'ArU', full(Ar * Us(:, 1:2)), 'k_sp', p.k_sp, 'k_pr', p.k_pr, 'zeta', in.zeta);
P.Ft = p.Ft;  P.KA = in.KA;  P.Kv24 = p.Kv24;  P.SF24 = p.SF24;
phi = linspace(0, 2 * pi, 25);  phi = phi(1:end - 1);
for h = 1:3
    TE = in.TE_planet(h) * 1e-6;
    fm_ = P.f_all(P.f_all >= bands(h, 1) & P.f_all <= bands(h, 2));
    fq = unique([linspace(bands(h, 1), bands(h, 2), in.n_freq), fm_, fm_ * 0.995, fm_ * 1.005]);
    fq = fq(fq >= bands(h, 1) & fq <= bands(h, 2));
    nq = numel(fq);
    R = struct('f', fq, 'Fd_sp', zeros(1, nq), 'Fd_pr', zeros(1, nq), 'Fr_sun', zeros(1, nq), 'Fr_ring', zeros(1, nq), ...
               'u_max', zeros(1, nq), 'sig_rim', zeros(1, nq));
    sf_rim = Inf;
    for k = 1:nq
        om = 2 * pi * fq(k);
        H = 1 ./ (w.^2 - om^2 + 2i * in.zeta * w * om);
        qs = TE * (H .* gs - gs ./ w.^2);  qr = TE * (H .* gr - gr ./ w.^2);   % modal parts, residual added below
        us = Vm * qs + TE * Us(:, 1);  ur = Vm * qr + TE * Us(:, 2);
        a_sp = p.k_sp * TE - As * us;  b_sp = -As * ur;           % sun mesh: own TE, the ring case moves the patch
        a_pr = p.k_pr * TE - Ar * ur;  b_pr = -Ar * us;
        R.Fd_sp(k) = abs(a_sp) + abs(b_sp);  R.Fd_pr(k) = abs(a_pr) + abs(b_pr);
        R.Fr_sun(k) = b_pr;  R.Fr_ring(k) = a_pr;
        Ss = tensorprod(Sm, qs, 3, 1) + TE * Sres(:, :, 1);
        Sr = tensorprod(Sm, qr, 3, 1) + TE * Sres(:, :, 2);
        um = 0;  sv = zeros(N, 1);
        for ph = phi
            u = us + exp(1i * ph) * ur;
            um = max(um, max(sqrt(abs(u(1:N)).^2 + abs(u(N + 1:2 * N)).^2 + abs(u(2 * N + 1:end)).^2)));
            S = Ss + exp(1i * ph) * Sr;
            sv = max(sv, dy_vm_cycle(real(S), -imag(S)) / 1e6);
        end
        R.u_max(k) = um * 1e6;  R.sig_rim(k) = max(sv);
        sf_rim = min(sf_rim, min(1 ./ (sv / in.sigma_e.P53 + vm_st / in.su.P53)));
    end
    F0 = in.KA * p.Ft;
    R.Kv_sp = 1 + max(R.Fd_sp) / F0;  R.Kv_pr = 1 + max(R.Fd_pr) / F0;
    R.SF_sp = p.SF24(1) * p.Kv24(1) / R.Kv_sp;  R.SF_pr = p.SF24(2) * p.Kv24(2) / R.Kv_pr;
    [R.u_pk, i] = max(R.u_max);  R.f_pk = fq(i);
    R.sig_pk = max(R.sig_rim);  R.sf_rim = sf_rim;
    R.f_modes = fm_;  R.F_te = [p.k_sp, p.k_pr] * TE;
    P.h(h) = R;
end
P.sig_steady = max(vm_st);
P.m = rho_eq * pi / 4 * (p.d_root^2 - p.D_or^2) * p.b * 1e-9;
P.n_dof = 3 * N;
end
