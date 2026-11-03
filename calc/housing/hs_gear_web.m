function W = hs_gear_web(p, f_max, Hmax)
%HS_GEAR_WEB  3-D modes of the first-stage gear blank (rim, web, hub) for the DYN-04 web check of step 2.4.
%   W = hs_gear_web(p, f_max, Hmax)
%
%   p: r_bore, r_hub, r_rim (inside radius of the rim), r_out (outside
%   radius of the solid rim) [mm], t_web, b (rim width), L_hub [mm], E [Pa],
%   nu, rho [kg/m^3]. f_max [Hz], Hmax [m].
%
%   The blank is revolved from its three pieces (hs_revolve), meshed with
%   quadratic tetrahedra and held on its bore (the intermediate shaft). The
%   teeth are left out; r_out at the root circle leaves out their mass,
%   r_out at mid-tooth height counts it but stiffens the rim, so the two
%   bracket the plate model of step 2.4 (gd_modes 'web'). Each mode gets its
%   number of nodal diameters from the axial displacement around the web
%   at mid-radius (largest Fourier term, n = 0 ... 20), and its share of
%   axial motion there.
%
%   Output struct W: f [Hz], n (nodal diameters), ax (axial share of the
%   web motion at mid-radius, 0 to 1), m [kg], n_dof.
%   Source: Phase 2 report, Section 2.8 ("First-stage gear web").

sec = [p.r_bore p.r_hub (p.b - p.L_hub) / 2 (p.b + p.L_hub) / 2;
       p.r_hub p.r_rim (p.b - p.t_web) / 2 (p.b + p.t_web) / 2;
       p.r_rim p.r_out 0 p.b];
file = [tempname '.stl'];
stlwrite(hs_revolve(sec, 180, 2), file);
m = createpde('structural', 'modal-solid');
gm = importGeometry(m, file);
delete(file);
structuralProperties(m, 'YoungsModulus', p.E, 'PoissonsRatio', p.nu, 'MassDensity', p.rho);
generateMesh(m, 'Hmax', Hmax, 'GeometricOrder', 'quadratic');
structuralBC(m, 'Face', nearestFace(gm, [p.r_bore, 0, p.b / 2] / 1000), 'Constraint', 'fixed');
R = solve(m, 'FrequencyRange', [-1, f_max] * 2 * pi);
f = R.NaturalFrequencies' / (2 * pi);
X = m.Mesh.Nodes * 1000;
r = hypot(X(1, :), X(2, :));
rm = (p.r_hub + p.r_rim) / 2;
sel = abs(r - rm) < 4 & abs(X(3, :) - p.b / 2) < p.t_web / 2 + 1e-6;
th = atan2(X(2, sel), X(1, sel))';
nn = 0:20;
A = [ones(numel(th), 1), cos(th * nn(2:end)), sin(th * nn(2:end))];
W = struct('f', f, 'n', zeros(size(f)), 'ax', zeros(size(f)), 'm', volume(m.Mesh) * p.rho, ...
           'n_dof', 3 * size(m.Mesh.Nodes, 2));
for k = 1:numel(f)
    uz = R.ModeShapes.uz(sel, k);
    ur = R.ModeShapes.ux(sel, k) .* cos(th) + R.ModeShapes.uy(sel, k) .* sin(th);
    ut = -R.ModeShapes.ux(sel, k) .* sin(th) + R.ModeShapes.uy(sel, k) .* cos(th);
    c = A \ uz;
    amp = [abs(c(1)), hypot(c(2:21), c(22:41))'];
    [~, i] = max(amp);
    W.n(k) = nn(i);
    W.ax(k) = sum(uz.^2) / sum(uz.^2 + ur.^2 + ut.^2);
end
end
