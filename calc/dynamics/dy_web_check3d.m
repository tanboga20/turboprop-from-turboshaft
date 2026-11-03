function C = dy_web_check3d(in, pw, Fax, n_target, f_cut)
%DY_WEB_CHECK3D  3-D check of the harmonic web model: modal superposition against a direct frequency solve.
%   C = dy_web_check3d(in, pw, Fax, n_target, f_cut)
%
%   The blank of dy_web in 3-D (hs_revolve, quadratic tetrahedra at the
%   coarse in.Hmax_web, held at its bore, as hs_gear_web), the same 10 deg
%   axial patch load Fax on the rim face. At the out-of-plane mode with
%   n_target nodal diameters nearest the top of the modes found below
%   f_cut [Hz], the response is solved twice: by modal superposition over
%   the modes below f_cut (modal damping in.zeta_web) and directly
%   (stiffness-proportional damping, in.zeta_web at the mode).
%   Output C: f (the 3-D mode frequency), n, n_nodes, and for both
%   solutions the largest cycle-maximum von Mises sig0 [MPa] (dy_vm_cycle, as dy_web,
%   outside in.r_corner of the sharp corners), Win = pi Fax mean(-Im u_z)
%   over the patch [J] and the largest axial amplitude uz [um].
%   Source: Phase 3 report, Section 3.6 ("First-stage gear web", check).

p = pw;
sec = [p.r_bore p.r_hub (p.b - p.L_hub) / 2 (p.b + p.L_hub) / 2;
       p.r_hub p.r_rim (p.b - p.t_web) / 2 (p.b + p.t_web) / 2;
       p.r_rim p.r_out 0 p.b];
file = [tempname '.stl'];
stlwrite(hs_revolve(sec, 180, 2), file);
m = createpde('structural', 'modal-solid');
gm = importGeometry(m, file);
delete(file);
structuralProperties(m, 'YoungsModulus', p.E, 'PoissonsRatio', p.nu, 'MassDensity', p.rho);
generateMesh(m, 'Hmax', in.Hmax_web, 'GeometricOrder', 'quadratic');
structuralBC(m, 'Face', nearestFace(gm, [p.r_bore, 0, p.b / 2] / 1000), 'Constraint', 'fixed');
Rm = solve(m, 'FrequencyRange', [-1, f_cut] * 2 * pi);
f = Rm.NaturalFrequencies' / (2 * pi);
X = m.Mesh.Nodes;
r = hypot(X(1, :), X(2, :));  th = atan2(X(2, :), X(1, :));
rm = (p.r_hub + p.r_rim) / 2000;
sel = abs(r - rm) < 0.004 & abs(X(3, :) - p.b / 2000) < p.t_web / 2000 + 1e-6;
nn = 0:20;
Af = [ones(sum(sel), 1), cos(th(sel)' * nn(2:end)), sin(th(sel)' * nn(2:end))];
n = zeros(size(f));  ax = n;
for k = 1:numel(f)
    uz = Rm.ModeShapes.uz(sel, k);
    uu = Rm.ModeShapes.ux(sel, k).^2 + Rm.ModeShapes.uy(sel, k).^2 + uz.^2;
    c = Af \ uz;
    [~, i] = max([abs(c(1)), hypot(c(2:21), c(22:41))']);
    n(k) = nn(i);
    ax(k) = sum(uz.^2) / sum(uu);
end
k = find(n == n_target & ax > 0.5, 1);
C.f = f(k);  C.n = n_target;  C.n_nodes = size(X, 2);  C.n_modes = numel(f);
f_out = nearestFace(gm, [p.r_out, 0, p.b / 2] / 1000);
A_patch = p.r_out / 1000 * deg2rad(10) * p.b / 1000;
m.AnalysisType = 'frequency-solid';
structuralBoundaryLoad(m, 'Face', f_out, 'SurfaceTraction', @(loc, st) patch(loc), 'Vectorized', 'on');
ld = abs(r - p.r_out / 1000) < 1e-6 & abs(th) <= deg2rad(5);
crn = [p.r_hub p.r_hub p.r_rim p.r_rim; [p.b - p.t_web, p.b + p.t_web, p.b - p.t_web, p.b + p.t_web] / 2] / 1000;
far = min(pdist2([r; X(3, :)]', crn'), [], 2) > in.r_corner;
om = 2 * pi * C.f * [1 1.0005];                       % the toolbox needs two frequencies; the first is used
structuralDamping(m, 'Zeta', in.zeta_web);
C.modal = evaluate(solve(m, om, 'ModalResults', Rm));
structuralDamping(m, 'Alpha', 0, 'Beta', 2 * in.zeta_web / om(1));
C.direct = evaluate(solve(m, om));

    function T = patch(loc)
        on = abs(atan2(loc.y, loc.x)) <= deg2rad(5);
        T = [0 * loc.x; 0 * loc.x; Fax / A_patch * on];
    end
    function o = evaluate(R)
        S = evaluateStress(R);
        fn = {'xx', 'yy', 'zz', 'xy', 'yz', 'xz'};
        Sr = zeros(nnz(far), 6);  Si = Sr;
        for q = 1:6, Sr(:, q) = real(S.(fn{q})(far, 1));  Si(:, q) = imag(S.(fn{q})(far, 1)); end
        uz = R.Displacement.uz(:, 1);
        o = struct('sig0', max(dy_vm_cycle(Sr, Si)) / 1e6, 'Win', pi * Fax * mean(-imag(uz(ld))), ...
                   'uz', max(abs(uz)) * 1e6);
    end
end
