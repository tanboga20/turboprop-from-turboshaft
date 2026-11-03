function R = hs_planet3d(p, support, f_max)
%HS_PLANET3D  3-D modes of a planet with its rim, on its loaded rollers and its two meshes (DYN-04).
%   R = hs_planet3d(p, support, f_max)
%
%   p: D_or (bore = outer race), d_root, b [mm]; h_teeth (tooth layer as
%   added mass) [mm]; E [Pa], nu, rho [kg/m^3]; Z, Lwe [mm], F [N] (roller
%   set and bearing load, as in sb_planet_rim); k_mesh [N/m], alpha [rad];
%   psi_mesh [rad] (angular width of the mesh patch); Hmax [m].
%   support: 'free', 'rollers' or 'rollers+meshes'. f_max [Hz].
%
%   The planet is a solid annular cylinder (bore to root circle, face width
%   b, quadratic tetrahedra) whose density carries the tooth mass. The
%   loaded rollers are an elastic foundation on the bore over the loaded
%   half (load at psi = 0): the roller radial stiffness of sb_planet_rim
%   (Stribeck loads, Palmgren contact, inner and outer race in series),
%   spread over each roller's share of the bore area. The two meshes are
%   elastic foundations on patches of the root surface at psi = +-90 deg
%   along the line of action. The PDE Toolbox foundation acts on the x, y
%   and z displacement separately, so a radial spring n n' enters by its
%   diagonal (k cos^2 psi, k sin^2 psi): an approximation that leaves out
%   the coupling term.
%
%   Output struct R: f [Hz] (natural frequencies above 10 Hz and below
%   f_max), n_dof, m [kg]; fe (mesh and modal results for the plots).
%   Source: Phase 2 report, Section 2.8 ("Planet modes"). Tested by
%   test_step28 (TC53: the free planet against the thick ring).

model = createpde('structural', 'modal-solid');
gm = multicylinder([p.D_or, p.d_root] / 2000, p.b / 1000, 'Void', [true, false]);
model.Geometry = gm;
h = (p.d_root - p.D_or) / 2;
rho_eq = p.rho * (h + p.h_teeth) / h;
structuralProperties(model, 'YoungsModulus', p.E, 'PoissonsRatio', p.nu, 'MassDensity', rho_eq);
generateMesh(model, 'Hmax', p.Hmax, 'GeometricOrder', 'quadratic');
if ~strcmp(support, 'free')
    f_bore = nearestFace(gm, [p.D_or / 2000, 0, p.b / 2000]);
    Qmax = 4.08 * p.F / p.Z;
    A_roll = pi * p.D_or / p.Z * p.b * 1e-6;                  % m^2 of bore per roller
    kr = @(Q) Q.^0.1 * p.Lwe^0.8 / (0.9 * 3.84e-5) * 1e3 / 2;  % N/m per roller, two contacts in series
    structuralBoundaryLoad(model, 'Face', f_bore, 'TranslationalStiffness', @(loc, st) roll(loc), ...
                           'Vectorized', 'on');
    if strcmp(support, 'rollers+meshes')
        f_out = nearestFace(gm, [p.d_root / 2000, 0, p.b / 2000]);
        A_mesh = p.d_root / 2 * p.psi_mesh * p.b * 1e-6;
        km = p.k_mesh / A_mesh;
        structuralBoundaryLoad(model, 'Face', f_out, 'TranslationalStiffness', @(loc, st) mesh_k(loc), ...
                               'Vectorized', 'on');
    end
end
Rm = solve(model, 'FrequencyRange', [-1, f_max] * 2 * pi);
f = Rm.NaturalFrequencies' / (2 * pi);
R = struct('f', f(f > 10), 'n_dof', 3 * size(model.Mesh.Nodes, 2), ...
           'm', rho_eq * pi / 4 * (p.d_root^2 - p.D_or^2) * p.b * 1e-9, ...
           'fe', struct('mesh', model.Mesh, 'Rm', Rm, 'first', find(f > 10, 1)));

    function K = roll(loc)
        psi = atan2(loc.y, loc.x);
        c = cos(psi);
        Q = Qmax * max(c, 0).^(10/9);
        k = kr(Q) / A_roll .* (c > 0);
        K = [k .* c.^2; k .* sin(psi).^2; zeros(size(psi))];
    end

    function K = mesh_k(loc)
        psi = atan2(loc.y, loc.x);
        on = abs(abs(psi) - pi / 2) <= p.psi_mesh / 2;
        K = [km * cos(p.alpha)^2 * on; km * sin(p.alpha)^2 * on; zeros(size(psi))];
    end
end
