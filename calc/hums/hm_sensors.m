function S = hm_sensors(g, mat, Hmax)
%HM_SENSORS  How strongly points on the outside of the case move under the loads of each source.
%   S = hm_sensors(g, mat, Hmax)
%
%   g: the case of hs_inputs (rects, pt_flange, pt_seat_in, pt_seat_out,
%   seat_in, seat_out); mat: E [Pa], nu; Hmax [m].
%
%   The step 2.8 case, fixed on its flange, takes a 1 kN radial load (along
%   y) from each source in turn: the inner propeller bearing seat, the outer
%   propeller bearing seat, and the ring gear seat (the case bore, where the
%   planetary mesh forces enter). For each load the radial displacement of
%   the outer surface along its top line (the load direction, theta = 90
%   deg) is the static transfer compliance from that source to an
%   accelerometer there. It ranks sensor positions: an accelerometer reads
%   a source well where its compliance is high, and the dynamic transfer
%   functions follow from the modal tap test of the first casting (Phase 3).
%
%   Output struct S: z [mm] and r [mm] of the surface points, c [m/N]
%   (rows: inner seat, outer seat, ring seat), src (names).
%   Source: Phase 2 report, Section 2.10 ("Sensor positions").

file = [tempname '.stl'];
stlwrite(hs_revolve(g.rects, 120, 4), file);
m = createpde('structural', 'static-solid');
gm = importGeometry(m, file);
delete(file);
structuralProperties(m, 'YoungsModulus', mat.E, 'PoissonsRatio', mat.nu);
generateMesh(m, 'Hmax', Hmax, 'GeometricOrder', 'quadratic');
structuralBC(m, 'Face', nearestFace(gm, g.pt_flange), 'Constraint', 'fixed');
A = @(w, r) 2 * pi * r * w * 1e-6;                         % m^2
faces = {nearestFace(gm, g.pt_seat_in), nearestFace(gm, g.pt_seat_out), nearestFace(gm, [0 0.1295 0.071])};
areas = [A(g.seat_in(1), g.seat_in(2)), A(g.seat_out(1), g.seat_out(2)), A(118, 129.5)];
X = m.Mesh.Nodes * 1000;
r = hypot(X(1, :), X(2, :));  th = atan2d(X(2, :), X(1, :));  z = X(3, :);
top = abs(th - 90) < 2;
zb = 0:4:446;
pick = zeros(size(zb));
for k = 1:numel(zb)                                        % the outermost node of each 4 mm strip
    in = find(top & abs(z - zb(k)) < 2);
    if isempty(in), continue, end
    [~, j] = max(r(in));
    pick(k) = in(j);
end
keep = pick > 0;
S = struct('z', z(pick(keep)), 'r', r(pick(keep)), 'c', zeros(3, sum(keep)), ...
           'src', {{'inner propeller bearing', 'outer propeller bearing', 'ring gear (planetary meshes)'}});
for q = 1:3
    bl = structuralBoundaryLoad(m, 'Face', faces{q}, 'SurfaceTraction', [0; 1e3 / areas(q); 0]);
    R = solve(m);
    S.c(q, :) = abs(R.Displacement.uy(pick(keep)))' / 1e3;
    delete(bl);
end
end
