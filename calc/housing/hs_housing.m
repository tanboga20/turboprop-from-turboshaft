function H = hs_housing(g, mat, L, opt)
%HS_HOUSING  Mass, bearing seat stiffness, modes and limit-load stress of the axisymmetric RGB case.
%   H = hs_housing(g, mat, L, opt)
%
%   g: rects (the half section for hs_revolve, mm), pt_flange, pt_seat_in,
%   pt_seat_out (points on the attachment flange face and on the two
%   propeller bearing seats [m]), seat_in, seat_out ([width radius] of the
%   seats [mm]). mat: E [Pa], nu, rho [kg/m^3], sy, su [MPa]. L: R_in,
%   R_out [N] (radial reactions of the inner and outer propeller bearings at
%   limit load, opposite in sign), F_ax [N] (axial load on the outer seat).
%   opt: Hmax [m], f_max [Hz], n_seg, stl (file for the surface); optional
%   modal (false: static cases only), support ('fixed', default, or
%   'elastic') and k_sup ([kx ky kz] [N/m^3], the elastic flange support).
%
%   The case is revolved from its section (hs_revolve), meshed with
%   quadratic tetrahedra and held on its attachment flange face: fixed
%   (rigid joint and engine) or on an elastic foundation (the bolted joint
%   as springs, the bracketing case of the verification). Seat stiffness: a
%   10 kN radial load spread as a uniform traction on one seat, over the
%   mean radial displacement of that seat. Modes: without the rotor (local
%   shell and panel modes for DYN-04). Stress: both seat reactions and the
%   axial load at limit, von Mises; the largest nodal value away from the
%   flange (z > 20 mm) is a sharp-corner value of this mesh (the section
%   has no fillets), for the margins see hs_submodel.
%
%   Output struct H: m [kg], k_in, k_out [N/m], f [Hz], sig [MPa], n_y,
%   n_u [-], n_nodes; fe (meshes and solver results for the plots and the
%   submodels: Rm modes, Rseat the outer seat under 10 kN, Rlim the limit
%   load).
%   Source: Phase 2 report, Section 2.8 ("Housing"). Tested by
%   test_step28 (TC52, TC54).

if ~isfield(opt, 'modal'), opt.modal = true; end
if ~isfield(opt, 'support'), opt.support = 'fixed'; end
TR = hs_revolve(g.rects, opt.n_seg, 4);
stlwrite(TR, opt.stl);

% Modes
H.f = [];  Rm = [];
mm = createpde('structural', 'modal-solid');
importGeometry(mm, opt.stl);
structuralProperties(mm, 'YoungsModulus', mat.E, 'PoissonsRatio', mat.nu, 'MassDensity', mat.rho);
generateMesh(mm, 'Hmax', opt.Hmax, 'GeometricOrder', 'quadratic');
H.m = volume(mm.Mesh) * mat.rho;
H.n_nodes = size(mm.Mesh.Nodes, 2);
if opt.modal
    hold_flange(mm);
    Rm = solve(mm, 'FrequencyRange', [-1, opt.f_max] * 2 * pi);
    H.f = Rm.NaturalFrequencies' / (2 * pi);
end

% Seat stiffness and limit-load stress
ms = createpde('structural', 'static-solid');
importGeometry(ms, opt.stl);
structuralProperties(ms, 'YoungsModulus', mat.E, 'PoissonsRatio', mat.nu);
generateMesh(ms, 'Hmax', opt.Hmax, 'GeometricOrder', 'quadratic');
hold_flange(ms);
fin = nearestFace(ms.Geometry, g.pt_seat_in);
fout = nearestFace(ms.Geometry, g.pt_seat_out);
A = @(s) 2 * pi * s(2) * s(1) * 1e-6;                 % seat area [m^2]
k = zeros(1, 2);
seats = {fin, g.seat_in; fout, g.seat_out};
for j = 1:2
    bl = structuralBoundaryLoad(ms, 'Face', seats{j, 1}, 'SurfaceTraction', [0; -1e4 / A(seats{j, 2}); 0]);
    Rs = solve(ms);
    nodes = findNodes(ms.Mesh, 'region', 'Face', seats{j, 1});
    k(j) = 1e4 / abs(mean(Rs.Displacement.uy(nodes)));
    delete(bl);
    Rseat = Rs;
end
H.k_in = k(1);  H.k_out = k(2);
structuralBoundaryLoad(ms, 'Face', fin, 'SurfaceTraction', [0; L.R_in / A(g.seat_in); 0]);
structuralBoundaryLoad(ms, 'Face', fout, 'SurfaceTraction', [0; L.R_out / A(g.seat_out); L.F_ax / A(g.seat_out)]);
Rs = solve(ms);
vm = Rs.VonMisesStress / 1e6;
z = ms.Mesh.Nodes(3, :)';
H.sig = max(vm(z > 0.020));
H.n_y = mat.sy / H.sig;
H.n_u = mat.su / (1.5 * H.sig);
H.fe = struct('mesh_m', mm.Mesh, 'Rm', Rm, 'mesh_s', ms.Mesh, 'Rseat', Rseat, 'Rlim', Rs);

    function hold_flange(model)
        f_fl = nearestFace(model.Geometry, g.pt_flange);
        if strcmp(opt.support, 'fixed')
            structuralBC(model, 'Face', f_fl, 'Constraint', 'fixed');
        else
            structuralBoundaryLoad(model, 'Face', f_fl, 'TranslationalStiffness', opt.k_sup(:));
        end
    end
end
