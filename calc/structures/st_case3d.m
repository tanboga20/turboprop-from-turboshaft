function K = st_case3d(in, L, Hmax, limit_only)
%ST_CASE3D  3-D finite element checks of the planetary case on its CATIA geometry (step 3.5).
%   K = st_case3d(in, L)
%   K = st_case3d(in, L, Hmax)
%   K = st_case3d(in, L, Hmax, true)    limit load only (the mesh convergence check)
%
%   in = st_inputs; L = loads: R_in, R_out [N] (LD-05 limit radial reactions
%   of the inner and outer propeller bearings, opposite in sign), T_ring_lim,
%   T_ring_mct [N m] (ring reaction torque at LD-01/02 and at maximum
%   continuous torque), W1 [N] (radial reactions of the 1 g propeller weight
%   at the two seats, [in out]), P1 [N] (radial reactions of the 1P moment).
%   The case is cad/step/case.stp (step 3.1: conical nose, R5 cast fillets,
%   30 flange holes), quadratic tetrahedra, A357-T6. The attachment flange
%   face is held either fixed or on springs (the bolted joint opened, step
%   2.8 bound). Seat and ring loads are uniform tractions on their faces.
%   Cases:
%     seat stiffness: 10 kN radial on each seat (fixed and springs);
%     limit (LD-05 + LD-01 ring torque + 20 kN thrust): von Mises away from
%       the flange face (z > 20 mm), margins with the casting factor 1.25:
%       yield sy / (1.25 sig), ultimate su / (1.25 x 1.5 sig);
%     fatigue: mean = 1 g weight + 18 kN thrust + MCT ring torque; amplitude
%       = the 1P moment (rotating, so its von Mises stress is the amplitude);
%       Goodman with the sand-cast fatigue strength and the casting factor;
%     ring seat twist at MCT: tangential displacement over the ring face
%       width, i.e. the helix slope error the case adds to the planet-ring
%       mesh [um over the face width], for the K_Hbeta back-check.
%   Output K: k_in, k_out [N/m] (fixed, springs), sig_lim [MPa] (fixed,
%   springs), n_y, n_u, fatigue (sa, sm, n_f at the worst node), twist_um,
%   n_nodes, m [kg], and the result objects for the plots.
%   Source: Phase 3 report, Section 3.5 ("Case").

if nargin < 3 || isempty(Hmax), Hmax = in.Hmax; end
if nargin < 4, limit_only = false; end
g = fegeometry(in.case_step);
m0 = femodel(AnalysisType='structuralStatic', Geometry=g);
m0.MaterialProperties = materialProperties(YoungsModulus=in.al.E, PoissonsRatio=in.al.nu);
m0 = generateMesh(m0, Hmax=Hmax, GeometricOrder='quadratic');
msh = m0.Geometry.Mesh;
K.n_nodes = size(msh.Nodes, 2);
K.m = volume(msh) * in.al.rho;
f = structfun(@(p) nearestFace(g, p), in.pt, 'UniformOutput', false);
f_ring = unique([f.ring1 f.ring2]);
A = @(s) 2 * pi * s(2) * s(1);                         % seat area [m^2]
N = msh.Nodes;
z = N(3, :)';
tang = @(region, state, tau) [-tau * region.y ./ hypot(region.x, region.y); tau * region.x ./ hypot(region.x, region.y); 0 * region.x];
tauR = @(T) T / (2 * pi * 0.1295^2 * (in.ring_z(2) - in.ring_z(1)));    % ring seat shear stress [Pa]

    function R = run(support, loads)
        mm = m0;
        if strcmp(support, 'fixed')
            mm.FaceBC(f.flange) = faceBC(Constraint='fixed');
        else
            mm.FaceLoad(f.flange) = faceLoad(TranslationalStiffness=in.k_joint * [1; 1; 1]);
            % rigid-body rotation about z is free on springs only through shear: the springs act in all three directions
        end
        for q = 1:size(loads, 1)
            mm.FaceLoad(loads{q, 1}) = faceLoad(SurfaceTraction=loads{q, 2});
        end
        R = solve(mm);
    end

% seat stiffness, both supports
sup = {'fixed', 'springs'};
for s = 1:2 * ~limit_only
    for j = 1:2
        fs = [f.seat_in f.seat_out];  sg = {in.seat_in, in.seat_out};
        R = run(sup{s}, {fs(j), [0; -1e4 / A(sg{j}); 0]});
        n = findNodes(msh, 'region', 'Face', fs(j));
        kk(s, j) = 1e4 / abs(mean(R.Displacement.uy(n))); %#ok<AGROW>
    end
end
if ~limit_only, K.k_in = kk(:, 1)';  K.k_out = kk(:, 2)'; end

% limit load
lim = {f.seat_in, [0; L.R_in / A(in.seat_in); 0]; ...
       f.seat_out, [0; L.R_out / A(in.seat_out); in.F_ax / A(in.seat_out)]};
for s = 1:2
    ld = lim;
    for fr = f_ring, ld(end + 1, :) = {fr, @(r, st) tang(r, st, tauR(L.T_ring_lim))}; end %#ok<AGROW>
    R = run(sup{s}, ld);
    vm = R.VonMisesStress / 1e6;
    K.sig_lim(s) = max(vm(z > 0.020));
    if s == 1, K.R_lim = R; end
end
K.allow = min(in.al.sy / in.k_cast, in.al.su / (1.5 * in.k_cast));
K.n_y = in.al.sy ./ (in.k_cast * K.sig_lim);
K.n_u = in.al.su ./ (1.5 * in.k_cast * K.sig_lim);
if limit_only, return, end

% steel seat liners shrunk into the propeller bearing bores: the cold (-40 degC) contact pressure of
% st_liners on both seats, alone and with the limit load (fixed flange)
if isfield(L, 'p_liner')
    pl = {f.seat_in, L.p_liner(1); f.seat_out, L.p_liner(2)};
    rr = hypot(N(1, :), N(2, :))';
    near = rr < 0.115 & ((z > 0.118 & z < 0.175) | (z > 0.398));   % bosses of the two seats
    mm = m0;  mm.FaceBC(f.flange) = faceBC(Constraint='fixed');
    for q = 1:2, mm.FaceLoad(pl{q, 1}) = faceLoad(Pressure=pl{q, 2} * 1e6); end
    Rp = solve(mm);
    K.sig_liner = max(Rp.VonMisesStress(near') / 1e6);
    ld = lim;
    for fr = f_ring, ld(end + 1, :) = {fr, @(r, st) tang(r, st, tauR(L.T_ring_lim))}; end %#ok<AGROW>
    mm = m0;  mm.FaceBC(f.flange) = faceBC(Constraint='fixed');
    for q = 1:size(ld, 1), mm.FaceLoad(ld{q, 1}) = faceLoad(SurfaceTraction=ld{q, 2}); end
    for q = 1:2, mm.FaceLoad(pl{q, 1}) = faceLoad(SurfaceTraction=@(r, st) liner_tr(r, pl{q, 2} * 1e6, ld{q, 2})); end
    Rpl = solve(mm);
    K.sig_liner_lim = max(Rpl.VonMisesStress(near') / 1e6);
    K.n_liner = in.al.sy ./ (in.k_cast * [K.sig_liner K.sig_liner_lim]);
end

% fatigue: mean and 1P amplitude (fixed flange)
mean_ld = {f.seat_in, [0; L.W1(1) / A(in.seat_in); 0]; f.seat_out, [0; L.W1(2) / A(in.seat_out); in.thrust / A(in.seat_out)]};
for fr = f_ring, mean_ld(end + 1, :) = {fr, @(r, st) tang(r, st, tauR(L.T_ring_mct))}; end %#ok<AGROW>
Rm = run('fixed', mean_ld);
Ra = run('fixed', {f.seat_in, [0; L.P1(1) / A(in.seat_in); 0]; f.seat_out, [0; L.P1(2) / A(in.seat_out); 0]});
sm = Rm.VonMisesStress / 1e6;  sa = Ra.VonMisesStress / 1e6;
ok = z > 0.020;
nf = 1 ./ (in.k_cast * (sa / in.al.sf + sm / in.al.su));
nf(~ok) = Inf;
[K.fatigue.n_f, i] = min(nf);
K.fatigue.sa = sa(i);  K.fatigue.sm = sm(i);  K.fatigue.node_z = z(i) * 1e3;
K.fatigue.sa_max = max(sa(ok));

% ring seat twist at MCT torque (fixed flange): tangential displacement at the two ends of the ring face
Rt = run('fixed', {f_ring(1), @(r, st) tang(r, st, tauR(L.T_ring_mct)); f_ring(end), @(r, st) tang(r, st, tauR(L.T_ring_mct))});
nr = findNodes(msh, 'region', 'Face', f_ring);
P = N(:, nr);  th = atan2(P(2, :), P(1, :));
ut = -Rt.Displacement.ux(nr)' .* sin(th) + Rt.Displacement.uy(nr)' .* cos(th);
zr = P(3, :);
z_mid = mean(in.ring_z);  bw = 0.070;                 % ring face width 70 mm centred on the seat
e1 = abs(zr - (z_mid - bw / 2)) < 0.004;  e2 = abs(zr - (z_mid + bw / 2)) < 0.004;
K.twist_um = abs(mean(ut(e2)) - mean(ut(e1))) * 1e6;
K.ut_mean_um = mean(ut) * 1e6;
end

function t = liner_tr(region, p, tr0)
% outward radial pressure p on a bore face plus the uniform traction tr0 of the bearing load
r = hypot(region.x, region.y);
t = [p * region.x ./ r + tr0(1); p * region.y ./ r + tr0(2); 0 * region.x + tr0(3)];
end
