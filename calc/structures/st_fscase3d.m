function Q = st_fscase3d(in, L, B, gi, Hmax, support)
%ST_FSCASE3D  3-D check of the first-stage case on its CATIA geometry (step 3.5).
%   Q = st_fscase3d(in, L, B, gi)
%   Q = st_fscase3d(in, L, B, gi, Hmax)
%   Q = st_fscase3d(in, L, B, gi, Hmax, 'flange')
%
%   in = st_inputs, L = st_loads, B = st_bolts (flange moment), gi =
%   gd_inputs. Geometry: in.fs_step, the first-stage case with its 30 tapped
%   flange holes ending 2 mm above the pad bottom (at the full 12 mm depth of
%   step 3.1 they break onto the wall edge and the CATIA body is not a
%   closed solid) and, since Hamit's mount card A, the 16 mm rear wall.
%   A357-T6, quadratic tetrahedra.
%   Support 'mount' (the step 3.1 layout): the 12 holes of the engine mount
%   ring (ICD-24 placeholder) held fixed, i.e. the bolts and dowels as
%   rigid (TBR, engine maker); all propeller loads pass through the case.
%   Support 'flange' (the alternative of Section 3.5): the engine and nacelle
%   mounts take the propeller loads at the planetary case flange, so the
%   first-stage case hangs on its 30 flange bolt holes (held fixed) and
%   carries only its gear forces and its own mass at 2.5 g (limit) or 1 g.
%   Loads, both through tractions that are zero outside their area:
%     - from the planetary case on the bolt ring (z = 0, r 129.5..153.5 mm,
%       the contact annulus of the case flange): thrust and the flange
%       moment as linear axial stress, the ring reaction torque as shear
%       (it reaches the first-stage case through the dowels) and the net
%       radial bearing load;
%     - the first-stage gear forces on the pinion bearing bores (PT axis)
%       and the intermediate shaft bores (propeller axis), each split
%       equally between its front and rear bosses (z -23 and -140 mm, over
%       the bearing width, each bore normalised by its own area), equal and
%       opposite: tangential force along x, separating force along y, axial
%       force on the rear (four-point contact) seats, and the moment of the
%       axial force at the pitch point, +-F_a r_w / L_b along y on the
%       bosses of each shaft. Both half-cylinder faces of every bore and
%       bolt hole are picked (the faces are split on the seams).
%   Cases: limit (LD-05 at the flange, LD-01 torque and gear forces x
%   1.375) with the casting factor; fatigue (mean: 1 g, 18 kN thrust, MCT
%   torque and gear forces; amplitude: the 1P moment at the flange),
%   Goodman; first-stage alignment at MCT: the relative displacement of
%   the pinion and gear axes between the front and rear bosses along x (the
%   line of action of the tangential force) over the face width, against
%   the step 2.4 f_ma of the first-stage mesh.
%   Output Q: m [kg], n_nodes, sig_lim, n_y, n_u, fatigue (sa, sm, n_f),
%   slope_um (over the 52 mm face), dcd_um (centre distance change), R_lim.
%   Source: Phase 3 report, Section 3.5 ("First-stage case").

if nargin < 5 || isempty(Hmax), Hmax = in.Hmax; end
if nargin < 6, support = 'mount'; end
g = fegeometry(in.fs_step);
m0 = femodel(AnalysisType='structuralStatic', Geometry=g);
m0.MaterialProperties = materialProperties(YoungsModulus=in.al.E, PoissonsRatio=in.al.nu, MassDensity=in.al.rho);
m0 = generateMesh(m0, Hmax=Hmax, GeometricOrder='quadratic');
msh = m0.Geometry.Mesh;
N = msh.Nodes;  z = N(3, :)';
Q.n_nodes = size(N, 2);
Q.m = volume(msh) * in.al.rho;
fs = in.fs;
ypt = fs.y_pt;
% faces
th = (0:11) * 2 * pi / 12;
f_mount = unique(arrayfun(@(t) nearestFace(g, [fs.r_mount * cos(t) + fs.r_hole * cos(t), ypt + fs.r_mount * sin(t) + fs.r_hole * sin(t), -0.166]), th));
f_top = nearestFace(g, [0.140 0.010 0]);
tb = (0:29) * 2 * pi / 30;  rh = 0.0025;              % bolt holes: both halves, off the radial seams
pb = [0.145 * cos(tb) - rh * sin(tb), 0.145 * cos(tb) + rh * sin(tb); 0.145 * sin(tb) + rh * cos(tb), 0.145 * sin(tb) - rh * cos(tb)];
f_bolt = unique(arrayfun(@(k) nearestFace(g, [pb(:, k)', -0.005]), 1:size(pb, 2)));
f_pin = unique(arrayfun(@(p) nearestFace(g, p{1}), {[0, ypt + 0.0425, -0.023], [0, ypt - 0.0425, -0.023], ...
                                                   [0, ypt + 0.0425, -0.140], [0, ypt - 0.0425, -0.140]}));
f_mid = unique(arrayfun(@(p) nearestFace(g, p{1}), {[0, 0.045, -0.023], [0, -0.045, -0.023], [0, 0.045, -0.140], [0, -0.045, -0.140]}));
assert(numel(f_bolt) == 60 && numel(f_pin) == 4 && numel(f_mid) == 4, 'st_fscase3d: %d bolt, %d pinion, %d gear faces', ...
       numel(f_bolt), numel(f_pin), numel(f_mid));
M1 = gd_meshes(gi);
g1 = M1(1).g;
Ft = 2000 * gi.T_PT / g1.dw1;  Fr = Ft * tan(g1.alpha_wt);  Fa = Ft * tan(g1.beta);
Q.F1 = [Ft Fr Fa];
Atop = pi * (0.1535^2 - 0.1295^2);  Itop = pi / 4 * (0.1535^4 - 0.1295^4);  Jtop = 2 * Itop;
rw = [g1.dw1, g1.dw2] / 2000;                         % m, working pitch radii of pinion and gear
Lb = 0.117;  sg = sign(ypt);                          % boss centres z -23 and -140 mm; pinion axis at y_pt

    function t = top_tr(region, ~, Fax, Mx, T, Fy)
        r = hypot(region.x, region.y);
        on = r > 0.1295 & r < 0.1535;
        sz = Fax / Atop + Mx * region.y / Itop;       % axial, the propeller pulls (+z) and bends about x
        tt = T * r / Jtop;
        t = [on .* (-tt .* region.y ./ r); on .* (tt .* region.x ./ r + Fy / Atop); on .* sz];
    end
    function t = seat_tr(region, ~, Fx, Fy, Fz, rb, ca)
        % uniform traction over the bearing width on the front and rear bosses of a bore (radius rb), half each;
        % the axial force on the rear seat; the couple ca (+ front, - rear) of the axial force moment along y
        Ab = 2 * pi * rb * fs.L_seat;
        front = abs(region.z + 0.023) <= fs.L_seat / 2;  rear = abs(region.z + 0.140) <= fs.L_seat / 2;
        on = front | rear;
        t = [on * Fx / 2 / Ab; (on * Fy / 2 + (front - rear) * ca) / Ab; rear * Fz / Ab];
        t = t .* ones(3, numel(region.x));
    end
    function R = run(Fax, Mx, T, Fy, k, nz)
        mm = m0;
        if strcmp(support, 'mount')
            mm.FaceBC(f_mount) = faceBC(Constraint='fixed');
            mm.FaceLoad(f_top) = faceLoad(SurfaceTraction=@(r, s) top_tr(r, s, Fax, Mx, T, Fy));
        else
            mm.FaceBC(f_bolt) = faceBC(Constraint='fixed');
            if nz ~= 0, mm.CellLoad = cellLoad(Gravity=[0; -9.81 * nz; 0]); end
        end
        % pinion: pushed away from the gear (-y) and along -x; gear (intermediate shaft) the opposite
        % the axial force moment F_a r_w / L_b: the same sign on both shafts (axial force +F_a pinion, -F_a gear)
        for f = f_pin, mm.FaceLoad(f) = faceLoad(SurfaceTraction=@(r, s) seat_tr(r, s, -k * Ft, -k * Fr, k * Fa, fs.r_seat, sg * rw(1) * k * Fa / Lb)); end
        for f = f_mid, mm.FaceLoad(f) = faceLoad(SurfaceTraction=@(r, s) seat_tr(r, s, k * Ft, k * Fr, -k * Fa, 0.045, sg * rw(2) * k * Fa / Lb)); end
        R = solve(mm);
    end

away = true(size(z));
for t = th
    away = away & hypot(N(1, :)' - fs.r_mount * cos(t), N(2, :)' - (ypt + fs.r_mount * sin(t))) > fs.r_hole + 0.006;
end
for t = (0:29) * 2 * pi / 30
    away = away & ~(hypot(N(1, :)' - 0.145 * cos(t), N(2, :)' - 0.145 * sin(t)) < 0.0025 + 0.006 & z > -0.016);
end
% limit
R = run(in.F_ax, B.M_flange, L.T_ring_lim, L.R_in + L.R_out, in.K_over, in.nz);
vm = R.VonMisesStress / 1e6;
Q.sig_lim = max(vm(away));
Q.n_y = in.al.sy / (in.k_cast * Q.sig_lim);
Q.n_u = in.al.su / (1.5 * in.k_cast * Q.sig_lim);
Q.R_lim = R;
% fatigue
W = in.m_prop * in.g;
Rm = run(in.thrust, W * in.bolt.z_prop, L.T_ring_mct, L.W1(1) + L.W1(2), 1, 1);
Ra = run(0, in.M_1P, 0, 0, 0, 0);
sm = Rm.VonMisesStress / 1e6;  sa = Ra.VonMisesStress / 1e6;
nf = 1 ./ (in.k_cast * (sa / in.al.sf + sm / in.al.su));
nf(~away) = Inf;
[Q.fatigue.n_f, i] = min(nf);
Q.fatigue.sa = sa(i);  Q.fatigue.sm = sm(i);
% first-stage alignment at MCT (gear forces only)
Rg = run(0, 0, 0, 0, 1, 0);
ux = Rg.Displacement.ux;  uy = Rg.Displacement.uy;
pick = @(xc, yc, rr, z1, z2) abs(hypot(N(1, :)' - xc, N(2, :)' - yc) - rr) < 1e-3 & z > z1 & z < z2;
pf = pick(0, ypt, fs.r_seat, -0.038, -0.008);  pr = pick(0, ypt, fs.r_seat, -0.164, -0.114);
gf = pick(0, 0, 0.045, -0.038, -0.008);  gr = pick(0, 0, 0.045, -0.164, -0.114);
dfront = mean(ux(pf)) - mean(ux(gf));  drear = mean(ux(pr)) - mean(ux(gr));
span = 0.126;                                        % m, boss centre to boss centre (-23 to -139 mm)
Q.slope_um = abs(dfront - drear) / span * gi.s1.b * 1e3;   % rad x face width [mm] -> um
Q.dcd_um = (mean(uy(gf)) - mean(uy(pf)) + mean(uy(gr)) - mean(uy(pr))) / 2 * 1e6;
Q.f_ma = M1(1).f_ma;
Q.u_max_mm = max(sqrt(R.Displacement.ux.^2 + R.Displacement.uy.^2 + R.Displacement.uz.^2)) * 1e3;
Q.support = support;
end
