function S = hs_submodel(Rg, sec, corner, opt)
%HS_SUBMODEL  Filleted submodel of one re-entrant corner of the case, driven by the global displacements.
%   S = hs_submodel(Rg, sec, corner, opt)
%
%   Rg: static results of the global case (hs_housing, sharp corners).
%   sec: its section pieces [mm] (hs_poly); corner: [r z] of the
%   re-entrant corner [mm].
%   opt: rf (cast fillet radius) [mm], half (half size of the section
%   window) [mm], th_c (azimuth of the global peak) [rad], n_seg (facets of
%   the global model), n_fac (facets on each side of th_c), n_sub (points
%   per facet), Hmax [mm], h (element sizes on the fillet) [mm], E [Pa], nu,
%   bc (struct array: type 'fixed', 'traction' or 'global', seg [r1 z1 r2
%   z2] [mm] of the outline edge, t [3x1] traction [Pa]; 'global' faces
%   take the global displacements like the cut faces).
%
%   The section is clipped to the window around the corner, every
%   re-entrant corner in it gets the fillet (hs_section), and the piece is
%   revolved over the sector on the global facets (hs_sector). The faces cut
%   out of the case (the window cuts and the two sector caps) take the
%   global displacements, interpolated (nearest global node where a point
%   falls just outside the global mesh); faces of the global boundary
%   conditions keep them. The submodel is solved once per fillet element
%   size h: the largest nodal von Mises stress on the fillet away from the
%   caps is its peak stress, which converges as h falls, unlike the
%   sharp-corner value of the global mesh.
%
%   Output struct S: h [mm], sig [MPa] (peak on the fillet per h), sig_win
%   [MPa] (largest anywhere away from the cut faces), n_nodes, at [r z th]
%   (where the finest peak is) [mm mm rad], rf, win; fe (finest mesh and
%   results for the plots).
%   Source: Phase 2 report, Section 2.8 ("Verification").

tol = 0.05;
win = [corner(1) + [-1 1] * opt.half, corner(2) + [-1 1] * opt.half] + 0.37;   % off the section edges
[P, cut, C] = hs_section(sec, opt.rf, win, 2);
ic = find(all(abs(C(:, 1:2) - corner) < 1e-6, 2), 1);
if isempty(ic), error('hs_submodel:corner', 'no re-entrant corner at (%g, %g)', corner); end
cf = C(ic, 3:4);  R = C(ic, 5);                          % fillet centre and radius
a1 = atan2(C(ic, 7) - cf(2), C(ic, 6) - cf(1));          % the arc runs from a1 by da
da = angle(exp(1i * (atan2(C(ic, 9) - cf(2), C(ic, 8) - cf(1)) - a1)));
dth = 2 * pi / opt.n_seg;
kc = round(opt.th_c / dth);
th0 = kc * dth;
th = th0 + (-opt.n_fac:opt.n_fac) * dth;
file = [tempname '.stl'];
stlwrite(hs_sector(P, th, opt.n_sub), file);
m = createpde('structural', 'static-solid');
gm = importGeometry(m, file);
delete(file);
structuralProperties(m, 'YoungsModulus', opt.E, 'PoissonsRatio', opt.nu);

% Faces: classify each by the section coordinates of its nodes on a first coarse mesh
generateMesh(m, 'Hmax', opt.Hmax / 1000, 'GeometricOrder', 'linear');
np = size(P, 1);
segs = [P, P([2:np 1], :)];
csegs = segs(cut, :);
f_bound = [];  f_fil = [];  f_bc = cell(1, numel(opt.bc));
for f = 1:gm.NumFaces
    [rr, zz, tr] = secxy(m.Mesh.Nodes(:, findNodes(m.Mesh, 'region', 'Face', f)));
    if all(abs(tr - th(1) + th0) < 1e-6) || all(abs(tr - th(end) + th0) < 1e-6) || ...
       (~isempty(csegs) && all(dseg(rr, zz, csegs) < tol))
        f_bound(end + 1) = f; %#ok<AGROW>
        continue
    end
    for k = 1:numel(opt.bc)
        if all(dseg(rr, zz, opt.bc(k).seg) < tol)
            if strcmp(opt.bc(k).type, 'global')
                f_bound(end + 1) = f; %#ok<AGROW>
            else
                f_bc{k}(end + 1) = f;
            end
        end
    end
    if sum(onarc(rr, zz)) >= 3                            % the fillet (alone or merged with its neighbours)
        f_fil(end + 1) = f; %#ok<AGROW>
    end
end
if isempty(f_fil), error('hs_submodel:fillet', 'no fillet face found at (%g, %g)', corner); end
structuralBC(m, 'Face', f_bound, 'Displacement', @(loc, ~) gdisp(loc));
for k = 1:numel(opt.bc)
    if isempty(f_bc{k}), continue, end
    if strcmp(opt.bc(k).type, 'fixed')
        structuralBC(m, 'Face', f_bc{k}, 'Constraint', 'fixed');
    else
        structuralBoundaryLoad(m, 'Face', f_bc{k}, 'SurfaceTraction', opt.bc(k).t);
    end
end

S = struct('h', opt.h, 'sig', zeros(size(opt.h)), 'sig_win', zeros(size(opt.h)), 'n_nodes', zeros(size(opt.h)), ...
           'at', [], 'rf', R, 'win', win, 'corner', corner, 'fe', []);
for q = 1:numel(opt.h)
    generateMesh(m, 'Hmax', opt.Hmax / 1000, 'Hface', {f_fil, opt.h(q) / 1000}, 'GeometricOrder', 'quadratic');
    Rs = solve(m);
    [rr, zz, tr] = secxy(m.Mesh.Nodes);
    vm = Rs.VonMisesStress' / 1e6;
    away = abs(tr) <= (opt.n_fac - 2) * dth;              % two facets clear of the caps
    on_f = away & onarc(rr, zz);
    clear_cut = away;
    for j = 1:size(csegs, 1)
        clear_cut = clear_cut & dseg(rr, zz, csegs(j, :)) > 6;
    end
    [S.sig(q), i] = max(vm .* on_f);
    S.sig_win(q) = max(vm(clear_cut));
    S.n_nodes(q) = size(m.Mesh.Nodes, 2);
    S.at = [rr(i), zz(i), tr(i) + th0];
end
S.fe = struct('mesh', m.Mesh, 'R', Rs);

    function U = gdisp(loc)
        x = loc.x(:);  y = loc.y(:);  z = loc.z(:);
        u = interpolateDisplacement(Rg, x, y, z);
        U = [u.ux(:)'; u.uy(:)'; u.uz(:)'];
        bad = any(isnan(U), 1);
        if any(bad)
            id = findNodes(Rg.Mesh, 'nearest', [x(bad), y(bad), z(bad)]');
            U(:, bad) = [Rg.Displacement.ux(id)'; Rg.Displacement.uy(id)'; Rg.Displacement.uz(id)'];
        end
    end

    function in = onarc(rr, zz)
        % points on the fillet arc, between its tangent points
        s = angle(exp(1i * (atan2(zz - cf(2), rr - cf(1)) - a1))) / da;
        in = abs(hypot(rr - cf(1), zz - cf(2)) - R) < tol & s >= -0.02 & s <= 1.02;
    end

    function [rr, zz, tr] = secxy(X)
        % section coordinates [mm] of points on the chord-faceted sector, angle from th0
        t = atan2(X(2, :), X(1, :)) - th0;
        tr = angle(exp(1i * t));
        k = min(max(floor((tr + opt.n_fac * dth) / dth), 0), 2 * opt.n_fac - 1);
        tm = th0 + (k - opt.n_fac + 0.5) * dth;
        rr = (X(1, :) .* cos(tm) + X(2, :) .* sin(tm)) / cos(dth / 2) * 1000;
        zz = X(3, :) * 1000;
    end
end

function d = dseg(r, z, s)
% distance of points (r, z) to the nearest of the segments s = [r1 z1 r2 z2] (rows)
d = inf(size(r));
for j = 1:size(s, 1)
    a = s(j, 1:2);  b = s(j, 3:4);  ab = b - a;
    t = min(max(((r - a(1)) * ab(1) + (z - a(2)) * ab(2)) / max(ab * ab', eps), 0), 1);
    d = min(d, hypot(r - a(1) - t * ab(1), z - a(2) - t * ab(2)));
end
end
