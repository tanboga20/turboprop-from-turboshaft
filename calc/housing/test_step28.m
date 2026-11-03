% TEST_STEP28  Checks the step 2.8 finite element pipeline against calc/tests/step28_test_cases.csv.
%   Run from the repo root:  addpath('calc/housing');  test_step28
%   The expected values are closed-form results from
%   calc/reference/step28_reference.py; each row carries its own tolerance
%   (the exact volume to 0.1%, beam and ring theory and the stress
%   concentration at a hole to a few percent).

T = readtable('calc/tests/step28_test_cases.csv', 'TextType', 'string');
in = hs_inputs();
res = struct();
tmp = tempname;

% TC52: faceted volume of the housing and its A357 mass, from the PDE mesh of the revolved section
TR = hs_revolve(in.case.rects, in.n_seg, 4);
stlwrite(TR, [tmp '.stl']);
m = createpde('structural', 'static-solid');
importGeometry(m, [tmp '.stl']);
generateMesh(m, 'Hmax', 0.010, 'GeometricOrder', 'linear');
V = volume(m.Mesh);
res.TC52 = struct('volume_cm3', V * 1e6, 'mass_A357_kg', V * in.mat(1).rho);

% TC53: cantilever steel tube 40/30 x 400 mm: first bending mode and tip deflection
gm = multicylinder([0.015 0.020], 0.400, 'Void', [true false]);
mm = createpde('structural', 'modal-solid');
mm.Geometry = gm;
structuralProperties(mm, 'YoungsModulus', 206e9, 'PoissonsRatio', 0.3, 'MassDensity', 7830);
generateMesh(mm, 'Hmax', 0.004, 'GeometricOrder', 'quadratic');
f0 = nearestFace(gm, [0.0175 0 0]);
f1 = nearestFace(gm, [0.0175 0 0.400]);
structuralBC(mm, 'Face', f0, 'Constraint', 'fixed');
R = solve(mm, 'FrequencyRange', [-1 600] * 2 * pi);
res.TC53.f1_Hz = R.NaturalFrequencies(1) / (2 * pi);
ms = createpde('structural', 'static-solid');
ms.Geometry = gm;
structuralProperties(ms, 'YoungsModulus', 206e9, 'PoissonsRatio', 0.3);
generateMesh(ms, 'Hmax', 0.004, 'GeometricOrder', 'quadratic');
structuralBC(ms, 'Face', f0, 'Constraint', 'fixed');
structuralBoundaryLoad(ms, 'Face', f1, 'SurfaceTraction', [1000 / (pi / 4 * (0.04^2 - 0.03^2)); 0; 0]);
Rs = solve(ms);
nodes = findNodes(ms.Mesh, 'region', 'Face', f1);
res.TC53.tip_mm = mean(Rs.Displacement.ux(nodes)) * 1e3;

% TC54: free planet ring, first in-plane bending mode
p = struct('D_or', 53, 'd_root', 69, 'b', 70, 'h_teeth', 2.25, 'E', 206e9, 'nu', 0.3, 'rho', 7830, 'Hmax', 0.004);
Rp = hs_planet3d(p, 'free', 7000);
res.TC54.ring_n2_Hz = Rp.f(1);

% TC55: hole in a tension plate, 3-D, 0.5 mm elements on the hole
B = hs_bench_hole(0.5);
res.TC55.Kt_3d = B.Kt;

% TC56: the same plate in 2-D plane stress, 0.25 mm elements on the hole
m2 = createpde('structural', 'static-planestress');
g2 = decsg([[3 4 0 0.150 0.150 0 0 0 0.050 0.050]', [1 0 0 0.010 0 0 0 0 0 0]'], 'R1-C1', ['R1'; 'C1']');
geometryFromEdges(m2, g2);
structuralProperties(m2, 'YoungsModulus', 206e9, 'PoissonsRatio', 0.3);
eh = nearestEdge(m2.Geometry, [0.00707 0.00707]);
generateMesh(m2, 'Hmax', 0.004, 'Hedge', {eh, 0.00025});
structuralBC(m2, 'Edge', nearestEdge(m2.Geometry, [0 0.03]), 'XDisplacement', 0);
structuralBC(m2, 'Edge', nearestEdge(m2.Geometry, [0.08 0]), 'YDisplacement', 0);
structuralBoundaryLoad(m2, 'Edge', nearestEdge(m2.Geometry, [0.150 0.025]), 'SurfaceTraction', [100e6; 0]);
R2 = solve(m2);
res.TC56.Kt_2d = max(R2.Stress.sxx(findNodes(m2.Mesh, 'region', 'Edge', eh))) / 1e8;

% Compare
nfail = 0;
for i = 1:height(T)
    tc = char(T.tc(i));
    q = char(T.quantity(i));
    v = res.(tc).(q);
    e = T.expected(i);
    ok = abs(v / e - 1) <= T.tol(i);
    verdict = 'PASS';
    if ~ok
        nfail = nfail + 1;
        verdict = 'FAIL';
    end
    fprintf('%-5s %-16s %14.6g %14.6g %8.3f%% (tol %.1f%%)  %s\n', tc, q, v, e, 100 * (v / e - 1), 100 * T.tol(i), verdict);
end
fprintf('%d values, %d failures\n', height(T), nfail);
