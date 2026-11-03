function T = torsion_model(in, g)
%TORSION_MODEL  Torsional model of the drive chain from the power turbine to the propeller.
%   T = torsion_model(in, g)
%
%   Inputs
%     in   torsion_inputs
%     g    gear data of the design (run_step23 builds it with the step 1.3
%          tool): pitch radii r1, r2 (first stage), r_s, r_p, r_r, r_c
%          (planetary, carrier = r_s + r_p), transverse pressure angles
%          alpha_t1, alpha_t2, face widths b1, b2, number of planets N,
%          inertias J_pinion, J_gear2, J_sun, J_planet, J_carrier [kg m^2],
%          planet mass m_planet [kg], accessory gear pitch radius r_ag
%
%   Output struct T
%     M, K       inertia and stiffness matrices, physical rotations; each DOF
%                is positive in its own running direction
%     names      DOF names
%     ratio      speed of each DOF over the PT speed in rigid rotation
%     el         elements: name, kind ('shaft' or 'mesh'), stiffness k
%                [N m/rad or N/m], vector a with deflection = a' q
%                [rad or m] and the lever arm that turns the element force
%                into the torque reported for it: the gear 2 side of the
%                first-stage mesh, the accessory gear, the sun (sun-planet)
%                and the carrier (planet-ring)
%     iPT, iProp, iCarrier   DOF numbers
%
%   Shafts are torsional springs G J / L (in series with the diaphragm packs
%   at the floating shaft ends). Gear meshes are springs along the line of
%   action, k = c_gamma b, with deflection r_b1 theta_1 - r_b2 theta_2 for
%   an external pair. Planetary stage (ring fixed), purely torsional:
%   sun-planet deflection cos(a) (r_s th_s - r_c th_c - r_p th_p), planet-
%   ring deflection cos(a) (r_c th_c - r_p th_p); the carrier carries the
%   planets' mass at r_c (Lin and Parker, J. Vib. Acoust. 121, 1999).
%
%   Source: Phase 2 report, Section 2.3 ("Model"). Tested by test_step23
%   (TC30, TC31).

names = {'PT', 'coupling 1', 'coupling 2', 'pinion', 'gear 2', 'accessory gear', 'generator', ...
         'sun', 'carrier'};
for i = 1:g.N
    names{end + 1} = sprintf('planet %d', i); %#ok<AGROW>
end
names{end + 1} = 'propeller';
n = numel(names);
idx = @(s) find(strcmp(names, s));
J = zeros(n, 1);
J(idx('PT')) = in.J_PT;
J(idx('coupling 1')) = in.J_coupling;
J(idx('coupling 2')) = in.J_coupling;
J(idx('pinion')) = g.J_pinion;
J(idx('gear 2')) = g.J_gear2;
J(idx('accessory gear')) = g.J_ag;
J(idx('generator')) = in.J_gen;
J(idx('sun')) = g.J_sun;
J(idx('carrier')) = g.J_carrier + g.N * g.m_planet * g.r_c^2;
for i = 1:g.N
    J(idx(sprintf('planet %d', i))) = g.J_planet;
end
J(idx('propeller')) = in.J_prop;

kt = @(d) in.G * pi / 32 * (d(1)^4 - d(2)^4) / d(3);      % G J / L of a hollow shaft
series = @(varargin) 1 / sum(1 ./ [varargin{:}]);
q = in.gen;
k_quill = series(in.G * pi / 32 * q.neck_d^4 / q.neck_L, in.G * pi / 32 * q.body_d^4 / q.body_L);

el = struct('name', {}, 'kind', {}, 'k', {}, 'a', {}, 'arm', {});
    function add_shaft(name, i, j, k)
        a = zeros(n, 1);  a(idx(i)) = 1;  a(idx(j)) = -1;
        el(end + 1) = struct('name', name, 'kind', 'shaft', 'k', k, 'a', a, 'arm', 1);
    end
    function add_mesh(name, k, a, arm)
        el(end + 1) = struct('name', name, 'kind', 'mesh', 'k', k, 'a', a, 'arm', arm);
    end
add_shaft('PT stub and coupling 1', 'PT', 'coupling 1', series(kt(in.sh.stub), in.k_diaphragm));
add_shaft('floating shaft', 'coupling 1', 'coupling 2', kt(in.sh.float));
add_shaft('coupling 2 and input shaft', 'coupling 2', 'pinion', series(in.k_diaphragm, kt(in.sh.input)));
a = zeros(n, 1);  a(idx('pinion')) = g.r1 * cos(g.alpha_t1);  a(idx('gear 2')) = -g.r2 * cos(g.alpha_t1);
add_mesh('first-stage mesh', in.c_gamma * g.b1, a, g.r2 * cos(g.alpha_t1));
a = zeros(n, 1);  a(idx('gear 2')) = g.r2 * cos(g.alpha_t1);  a(idx('accessory gear')) = -g.r_ag * cos(g.alpha_t1);
add_mesh('generator mesh', in.c_gamma * in.gen.b, a, g.r_ag * cos(g.alpha_t1));
add_shaft('generator quill', 'accessory gear', 'generator', k_quill);
add_shaft('intermediate shaft', 'gear 2', 'sun', kt(in.sh.mid));
ca = cos(g.alpha_t2);
for i = 1:g.N
    p = idx(sprintf('planet %d', i));
    a = zeros(n, 1);  a(idx('sun')) = ca * g.r_s;  a(idx('carrier')) = -ca * g.r_c;  a(p) = -ca * g.r_p;
    add_mesh(sprintf('sun-planet %d', i), in.c_gamma * g.b2, a, ca * g.r_s);
    a = zeros(n, 1);  a(idx('carrier')) = ca * g.r_c;  a(p) = -ca * g.r_p;
    add_mesh(sprintf('planet-ring %d', i), in.c_gamma * g.b2, a, ca * g.r_c);
end
add_shaft('propeller shaft', 'carrier', 'propeller', kt(in.sh.prop));

K = zeros(n);
for e = el
    K = K + e.k * (e.a * e.a.');
end

% Speed ratios in rigid rotation: the null space of K, scaled to 1 at the PT
[V, D] = eig(K, diag(J));
[~, i0] = min(abs(diag(D)));
r = V(:, i0) / V(idx('PT'), i0);

T = struct('M', diag(J), 'K', K, 'names', {names}, 'ratio', r, 'el', el, ...
           'iPT', idx('PT'), 'iProp', idx('propeller'), 'iCarrier', idx('carrier'));
end
