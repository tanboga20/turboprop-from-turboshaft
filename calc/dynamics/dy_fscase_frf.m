function Q = dy_fscase_frf(in, st, Ld, band, Hmax)
%DY_FSCASE_FRF  Modes and forced response of the first-stage case in the first-stage 1x mesh band (DYN-04 housing).
%   Q = dy_fscase_frf(in, st, Ld, band, Hmax)
%
%   in = dy_inputs, st = st_inputs (step 3.5: in.fs_step geometry, in.fs
%   seats, A357-T6 in st.al), Ld = the first-stage mesh loads of dy_web (Fb,
%   alpha, tbb, Fs, dZ; rw = working pitch radii of pinion and gear [m]),
%   band = [f1 f2] Hz (1x first-stage band), Hmax [m] (coarse: the case
%   walls get about one quadratic element).
%   The first-stage case on its CATIA geometry hangs on its 30 flange bolt
%   holes (held fixed; mount card A, as step 3.5 'flange'). Modes up to
%   in.fs_fcut x the band top (toolbox Lanczos). Forced response by modal
%   superposition (modal damping, envelope over in.cs.zeta) at in.n_freq
%   points over the band and at every mode inside it. Load: the dynamic
%   mesh force k TE_1 along the line of action (tangential along x,
%   separating along y, axial on the rear four-point seats), split equally
%   between the front and rear bosses (z -23 and -140 mm, over the bearing
%   width L_seat, each bore normalised by its own area 2 pi r_bore L_seat),
%   equal and opposite on the pinion and the intermediate-shaft bores (as
%   st_fscase3d); the moment of the axial force F_a r_w about each shaft as
%   +-F_a r_w / L_b along y on its bosses; the shuttle couples F_t dZ1 and
%   F_r dZ1 as opposite forces on the front and rear bosses, bracketed in
%   phase and in antiphase. Both half-cylinder faces of every bore and of
%   every bolt hole are picked (the faces are split on the seams). Check: a
%   static run with the pinion bosses alone, whose bolt-face reaction is
%   minus the applied force (Q.check). Stress: cycle-maximum von Mises
%   (dy_vm_cycle) away from the bolt holes; Goodman as the planetary case
%   (A357, k_cast, in.cs.k_gc), with the steady bound in.fs_sm.
%   Output Q: n_nodes, f (modes), n_band (modes in the band), f_resp,
%   sig (largest stress over the band, worse bracket and damping) [MPa],
%   f_pk, sig_pk, sf and sf_hot (dy_fscase_sf), check (applied and reaction
%   force [N]).
%   Source: Phase 3 report, Section 3.6 ("First-stage case").

m = createpde('structural', 'modal-solid');
importGeometry(m, st.fs_step);
structuralProperties(m, 'YoungsModulus', st.al.E, 'PoissonsRatio', st.al.nu, 'MassDensity', st.al.rho);
generateMesh(m, 'Hmax', Hmax, 'GeometricOrder', 'quadratic');
g = m.Geometry;  N = m.Mesh.Nodes;  z = N(3, :)';
Q.n_nodes = size(N, 2);
fs = st.fs;  ypt = fs.y_pt;
[f_bolt, f_pin, f_mid] = fs_faces(g, ypt);
structuralBC(m, 'Face', f_bolt, 'Constraint', 'fixed');
Rm = solve(m, 'FrequencyRange', [-1, in.fs_fcut * band(2)] * 2 * pi);
f = Rm.NaturalFrequencies(:)' / (2 * pi);
Q.f = f;  Q.n_band = sum(f >= band(1) & f <= band(2));
away = true(size(z));
for t = (0:29) * 2 * pi / 30
    away = away & ~(hypot(N(1, :)' - 0.145 * cos(t), N(2, :)' - 0.145 * sin(t)) < 0.0025 + 0.006 & z > -0.016);
end
rb = [fs.r_seat, 0.045];                              % m, pinion and gear (intermediate shaft) bores
Fb = Ld.Fb(1);  Ft = Fb * cos(Ld.alpha);  Fr = Fb * sin(Ld.alpha);  Fa = Fb * Ld.tbb;
Lb = 0.117;                                           % m, front to rear boss centres (z -23 and -140 mm)
sg = sign(ypt);                                       % the pinion axis lies at y_pt, the gear axis at y = 0
% one-off check: the pinion bosses alone, static; the bolt-face reaction must be minus the applied force
ms = createpde('structural', 'static-solid');
importGeometry(ms, st.fs_step);
structuralProperties(ms, 'YoungsModulus', st.al.E, 'PoissonsRatio', st.al.nu);
generateMesh(ms, 'Hmax', Hmax, 'GeometricOrder', 'quadratic');
structuralBC(ms, 'Face', f_bolt, 'Constraint', 'fixed');
cx = 0;  cy = 0;
for fp = f_pin, structuralBoundaryLoad(ms, 'Face', fp, 'SurfaceTraction', @(r, s) seat(r, -1)); end
Rs = solve(ms);
% reaction as K u at the fixed nodes (discrete equilibrium; evaluateReaction integrates recovered stresses over
% the small hole faces and reads low on this coarse mesh)
nfix = unique(cell2mat(arrayfun(@(f) findNodes(ms.Mesh, 'region', 'Face', f), f_bolt, 'UniformOutput', false)));
Nn = size(ms.Mesh.Nodes, 2);
Fe_ = assembleFEMatrices(ms, 'none');
r_ = Fe_.K * [Rs.Displacement.ux; Rs.Displacement.uy; Rs.Displacement.uz];
Fr_ = [sum(r_(nfix)); sum(r_(Nn + nfix)); sum(r_(2 * Nn + nfix))];
Q.check = struct('applied', [-Ft; -Fr; Fa], 'reaction', Fr_);
m.AnalysisType = 'frequency-solid';
fq = unique([linspace(band(1), band(2), in.n_freq), f(f >= band(1) & f <= band(2))]);
Q.f_resp = fq;  Q.sig = zeros(size(fq));
for zeta = in.cs.zeta
    structuralDamping(m, 'Zeta', zeta);
    for sgn = [1 -1]
        cx = sgn * Ld.Fs(1) * Ld.dZ(1) / Lb;  cy = sgn * Ld.Fs(2) * Ld.dZ(1) / Lb;   % shuttle couples, front + / rear -
        for fp = f_pin, structuralBoundaryLoad(m, 'Face', fp, 'SurfaceTraction', @(r, s) seat(r, -1)); end
        for fp = f_mid, structuralBoundaryLoad(m, 'Face', fp, 'SurfaceTraction', @(r, s) seat(r, 1)); end
        for k0 = 1:10:numel(fq)
            kk = k0:min(k0 + 9, numel(fq));
            om = 2 * pi * fq(kk);
            if numel(om) == 1, om = om * [1 1.0001]; end
            R = solve(m, om, 'ModalResults', Rm);
            S = evaluateStress(R);
            for j = 1:numel(kk)
                Sr = [real(S.xx(away, j)), real(S.yy(away, j)), real(S.zz(away, j)), real(S.xy(away, j)), real(S.yz(away, j)), real(S.xz(away, j))];
                Si = [imag(S.xx(away, j)), imag(S.yy(away, j)), imag(S.zz(away, j)), imag(S.xy(away, j)), imag(S.yz(away, j)), imag(S.xz(away, j))];
                Q.sig(kk(j)) = max(Q.sig(kk(j)), max(dy_vm_cycle(Sr, Si)) / 1e6);
            end
        end
        fprintf('   first-stage case: zeta %.3g, shuttle %+d done, peak so far %.2f MPa (%s)\n', zeta, sgn, max(Q.sig), ...
                datestr(now, 'HH:MM'));
    end
end
[Q.sig_pk, i] = max(Q.sig);  Q.f_pk = fq(i);
se = in.sigma_e.A357 * in.cs.k_gc;
[Q.sf, Q.sf_hot] = dy_fscase_sf(Q, in, st);           % coded and hot Goodman factors

    function t = seat(region, s)
        % one shaft's bosses (s = -1 pinion, +1 gear): the dynamic mesh force half on each boss over the bearing
        % width, the axial force on the rear seat and its moment F_a r_w / L_b along y, the shuttle couple
        k_ = 1.5 + s / 2;  Ab = 2 * pi * rb(k_) * fs.L_seat;
        front = abs(region.z + 0.023) <= fs.L_seat / 2;  rear = abs(region.z + 0.140) <= fs.L_seat / 2;
        on = front | rear;
        ca = sg * Ld.rw(k_) * Fa / Lb;                % the same sign on both shafts (axial force -s F_a)
        tx = s * (on * Ft / 2 + (front - rear) * cx) / Ab;
        ty = (s * (on * Fr / 2 + (front - rear) * cy) + (front - rear) * ca) / Ab;
        tz = -s * rear * Fa / Ab;
        t = [tx; ty; tz] .* ones(3, numel(region.x));
    end
end

function [f_bolt, f_pin, f_mid] = fs_faces(g, ypt)
% both half-cylinder faces of the 30 bolt holes (tangential offsets on the hole circle, off the radial seams) and of
% the pinion (y_pt, r 42.5 mm) and gear (r 45 mm) bores at the front and rear bosses (off the seams at x = +-r)
t = (0:29) * 2 * pi / 30;  rh = 0.0025;
pb = [0.145 * cos(t) - rh * sin(t), 0.145 * cos(t) + rh * sin(t); 0.145 * sin(t) + rh * cos(t), 0.145 * sin(t) - rh * cos(t)];
f_bolt = unique(arrayfun(@(k) nearestFace(g, [pb(:, k)', -0.005]), 1:size(pb, 2)));
f_pin = unique(arrayfun(@(p) nearestFace(g, p{1}), {[0, ypt + 0.0425, -0.023], [0, ypt - 0.0425, -0.023], ...
                                                   [0, ypt + 0.0425, -0.140], [0, ypt - 0.0425, -0.140]}));
f_mid = unique(arrayfun(@(p) nearestFace(g, p{1}), {[0, 0.045, -0.023], [0, -0.045, -0.023], [0, 0.045, -0.140], [0, -0.045, -0.140]}));
assert(numel(f_bolt) == 60 && numel(f_pin) == 4 && numel(f_mid) == 4, ...
       'fs_faces: %d bolt, %d pinion, %d gear faces (expected 60, 4, 4)', numel(f_bolt), numel(f_pin), numel(f_mid));
end
