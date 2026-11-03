function C = as_carrier(in, gi, scallops)
%AS_CARRIER  Windup and stress of the carrier front plate, plain or lightened (plane stress).
%   C = as_carrier(in, gi, scallops)
%
%   in = as_inputs, gi = gd_inputs; scallops true cuts the rim scallops of
%   in.carr (n_sc circles of radius R_sc centred at r_sc, midway between
%   pins and posts). The front plate carries the whole propeller torque into
%   the propeller shaft: half of each planet force reaches it through the
%   pin (straddle mounted pins) and the other half through the posts from
%   the rear plate. Model: PDE Toolbox plane stress, the plate disc of
%   step 2.9 (diameter plate_d, thickness plate_t) with its bore, the four
%   pin holes and the four post footprints cut out; the plate is fixed at
%   the bore (the propeller shaft taken as rigid); the pin and post loads
%   act as uniform tangential tractions on the edges of their holes (the
%   pins and posts as stiff inserts; local peaks at these edges are not
%   resolved, that is step 3.5).
%   Output C: mesh, the windup (rotation of the pin centre circle) and the
%   tangential deflection at the pin radius per unit torque, at maximum
%   continuous torque (MCT) and the peak von Mises stresses at LD-01 limit
%   and at the LD-08 stop torque with their safety factors on yield; the
%   mass of one plate and of the scallops removed from both plates.
%   C = as_carrier(in, gi, 'bench') runs the benchmark instead: an annulus
%   fixed at the bore with a uniform shear traction at the rim, against
%   the exact solution u_theta(b) = T b / (4 pi G t) (1/a^2 - 1/b^2).
%   Source: Phase 3 report, Section 3.1 ("Carrier plate lightening").

c = in.carr;
car = gi.carrier;
t = c.plate_t;  rp = 112;  ra = 50;                    % plate thickness (in.carr), rim and bore radii (step 2.9)
a = 82;  rpin = 19;  N = gi.s2.N;                      % pin circle, pin hole, planets
pt = car.post_t;  pw = car.post_w;
G = c.E / (2 * (1 + c.nu));
if ischar(scallops) && strcmp(scallops, 'bench')
    T = 1e6;                                           % N mm
    g = decsg([1 0 0 rp; 1 0 0 ra]', 'P-B', char('P', 'B')');
    model = createpde('structural', 'static-planestress');
    geometryFromEdges(model, g);
    structuralProperties(model, 'YoungsModulus', c.E, 'PoissonsRatio', c.nu);
    [ein, eout] = rim_edges(g, ra, rp);
    structuralBC(model, 'Edge', ein, 'Constraint', 'fixed');
    tau = T / (2 * pi * rp^2 * t);                     % rim shear stress
    for e = eout
        structuralBoundaryLoad(model, 'Edge', e, 'SurfaceTraction', @(loc, st) tang(loc, tau));
    end
    generateMesh(model, 'Hmax', c.Hmax, 'GeometricOrder', 'quadratic');
    R = solve(model);
    th = linspace(0, 2 * pi, 73);  th(end) = [];
    u = interpolateDisplacement(R, 0.999 * rp * cos(th), 0.999 * rp * sin(th));
    ut = -u.ux(:)' .* sin(th) + u.uy(:)' .* cos(th);
    C.u_fe = mean(ut);
    C.u_exact = T * 0.999 * rp / (4 * pi * G * t) * (1 / ra^2 - 1 / (0.999 * rp)^2);
    C.err = C.u_fe / C.u_exact - 1;
    C.nodes = size(R.Mesh.Nodes, 2);
    return
end

% geometry: plate - bore - pin holes - scallops; posts as inner faces (radially r_in .. rp - 4)
gd = [1 0 0 rp; 1 0 0 ra];
ns = {'P', 'B'};
f = 'P-B';
for i = 1:N
    th = 360 * (i - 1) / N;
    gd(end + 1, :) = [1 a * cosd(th) a * sind(th) rpin]; %#ok<AGROW>
    ns{end + 1} = sprintf('H%d', i); %#ok<AGROW>
    f = [f '-' ns{end}]; %#ok<AGROW>
end
if scallops
    for i = 1:c.n_sc
        th = 360 / c.n_sc * (i - 0.5);
        gd(end + 1, :) = [1 c.r_sc * cosd(th) c.r_sc * sind(th) c.R_sc]; %#ok<AGROW>
        ns{end + 1} = sprintf('S%d', i); %#ok<AGROW>
        f = [f '-' ns{end}]; %#ok<AGROW>
    end
end
gd = [gd zeros(size(gd, 1), 6)]';                      % circles padded to the rectangle column length
r1 = a - pt / 2;  r2 = min(a + pt / 2, rp - 4);
for i = 1:N
    th = 360 * (i - 0.5) / N;                          % posts between the planets (45 deg)
    u = [cosd(th) sind(th)];  v = [-sind(th) cosd(th)];
    q = [r1 * u - pw / 2 * v; r2 * u - pw / 2 * v; r2 * u + pw / 2 * v; r1 * u + pw / 2 * v];
    gd(:, end + 1) = [3 4 q(:, 1)' q(:, 2)']'; %#ok<AGROW>
    ns{end + 1} = sprintf('R%d', i); %#ok<AGROW>
    f = [f '-' ns{end}]; %#ok<AGROW>
end
g = decsg(gd, f, char(ns)');
model = createpde('structural', 'static-planestress');
geometryFromEdges(model, g);
structuralProperties(model, 'YoungsModulus', c.E, 'PoissonsRatio', c.nu);
ein = rim_edges(g, ra, rp);
structuralBC(model, 'Edge', ein, 'Constraint', 'fixed');
% unit torque 1 N m = 1000 N mm; loads per unit model thickness (divide by t)
T1 = 1000;
Fp = T1 / (N * a);                                     % tangential force per planet at the pin circle
for i = 1:N
    th = 360 * (i - 1) / N;
    e = circle_edges(g, a * [cosd(th) sind(th)], rpin);
    tr = Fp / 2 / (2 * pi * rpin) / t;
    d = [-sind(th) cosd(th)];
    structuralBoundaryLoad(model, 'Edge', e, 'SurfaceTraction', tr * d');
end
for i = 1:N
    th = 360 * (i - 0.5) / N;
    u = [cosd(th) sind(th)];  v = [-sind(th) cosd(th)];
    es = [];
    for e = 1:size(g, 2)
        p = mid_edge(g, e);
        if g(1, e) == 2 && abs(p * u' - (r1 + r2) / 2) <= (r2 - r1) / 2 + 1e-6 && abs(p * v') <= pw / 2 + 1e-6
            es(end + 1) = e; %#ok<AGROW>
        end
    end
    tr = T1 / 2 / N / ((r1 + r2) / 2) / (2 * (pw + r2 - r1)) / t;   % post force over its perimeter
    structuralBoundaryLoad(model, 'Edge', es, 'SurfaceTraction', tr * v');
end
generateMesh(model, 'Hmax', c.Hmax, 'GeometricOrder', 'quadratic');
R = solve(model);
% windup: mean tangential displacement on the pin hole edges over the pin radius
phi = [];  ut = [];
for i = 1:N
    th0 = 360 * (i - 1) / N;
    s = linspace(0, 360, 37);  s(end) = [];
    px = a * cosd(th0) + 1.001 * rpin * cosd(s);  py = a * sind(th0) + 1.001 * rpin * sind(s);
    u = interpolateDisplacement(R, px, py);
    ok = ~isnan(u.ux);
    ang = atan2(py, px);
    w = -u.ux(:)' .* sin(ang) + u.uy(:)' .* cos(ang);
    ut(end + 1) = mean(w(ok)); %#ok<AGROW>
end
C.u_pin_per_Nm = mean(ut);                             % mm per N m at the pin radius
C.windup_per_Nm = C.u_pin_per_Nm / a;                  % rad per N m
vm = R.VonMisesStress;
C.vm_per_Nm = max(vm);                                 % MPa per N m (peak, mesh nodes)
i_tot = gi.s1.z2 / gi.s1.z1 * (1 + gi.s2.zr / gi.s2.zs);
C.T_MCT = gi.T_PT * i_tot;                             % N m at the propeller
C.T_lim = gi.K_over * C.T_MCT;
C.T_LD08 = gi.T_stop_prop * 0.2 / 0.22;
C.u_pin_MCT = C.u_pin_per_Nm * C.T_MCT * 1e3;          % um
C.windup_MCT = C.windup_per_Nm * C.T_MCT * 1e6;        % urad
C.vm_lim = C.vm_per_Nm * C.T_lim;
C.vm_LD08 = C.vm_per_Nm * C.T_LD08;
C.SF_lim = c.sy / C.vm_lim;
C.SF_LD08 = c.sy / C.vm_LD08;
C.nodes = size(R.Mesh.Nodes, 2);
% masses
A_plate = pi * (rp^2 - ra^2) - N * pi * rpin^2;
C.A_scallop = c.n_sc * lens(rp, c.R_sc, c.r_sc);
C.m_saved = 2 * C.A_scallop * t * c.rho * 1e-9;        % both plates
C.m_plate = (A_plate - scallops * C.A_scallop) * t * c.rho * 1e-9;
C.model = model;  C.R = R;
end

function v = tang(loc, tau)
r = sqrt(loc.x.^2 + loc.y.^2);
v = [-tau * loc.y ./ r; tau * loc.x ./ r];
end

function [ein, eout] = rim_edges(g, ra, rp)
% edges (columns of the decomposed geometry) on the bore circle and on the rim circle
ein = [];  eout = [];
for e = 1:size(g, 2)
    r = norm(mid_edge(g, e));
    if abs(r - ra) < 1e-3 * ra, ein(end + 1) = e; end %#ok<AGROW>
    if abs(r - rp) < 1e-3 * rp, eout(end + 1) = e; end %#ok<AGROW>
end
end

function es = circle_edges(g, c, r)
es = [];
for e = 1:size(g, 2)
    if abs(norm(mid_edge(g, e) - c) - r) < 1e-3 * r, es(end + 1) = e; end %#ok<AGROW>
end
end

function p = mid_edge(g, e)
% middle point of edge e of a decsg geometry: lines [2 x1 x2 y1 y2 ...], arcs [1 x1 x2 y1 y2 l r cx cy R]
col = g(:, e);
if col(1) == 2
    p = [(col(2) + col(3)) / 2, (col(4) + col(5)) / 2];
else
    a1 = atan2(col(4) - col(9), col(2) - col(8));
    a2 = atan2(col(5) - col(9), col(3) - col(8));
    da = mod(a2 - a1, 2 * pi);                         % decsg arcs run counter-clockwise
    p = [col(8) + col(10) * cos(a1 + da / 2), col(9) + col(10) * sin(a1 + da / 2)];
end
end

function A = lens(R, r, d)
% area of the intersection of a circle of radius R at the origin and one of radius r at distance d
a1 = acos((d^2 + R^2 - r^2) / (2 * d * R));
a2 = acos((d^2 + r^2 - R^2) / (2 * d * r));
A = R^2 * a1 + r^2 * a2 - 0.5 * sqrt((-d + r + R) * (d + r - R) * (d - r + R) * (d + r + R));
end
