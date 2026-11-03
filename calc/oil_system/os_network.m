function N = os_network(in, L, F, li, oil)
%OS_NETWORK  The RGB oil network: manifold, external tubes, drillings, jets, carrier transfer, PCU, PT rear sump.
%   N = os_network(in, L, F, li, oil)
%
%   in = os_inputs, L = as_layout (step 3.1 geometry), F = lb_flows at
%   maximum continuous power and li = lb_inputs (step 2.7 jets), oil =
%   oil_props at the design temperature.
%   Routing (checked against the rotating parts with the CATIA clash
%   analysis): the manifold (inlet boss with the regulating and thermostatic
%   valves and the filter) sits outside the first-stage case wall on the
%   left; every branch is an external tube from the manifold, first along
%   the case at the manifold angle to the height of its entry, then round
%   the case 14 mm outside its wall (12 mm outside the planetary case),
%   then into an entry boss; from the boss, drillings in the walls and
%   bosses lead to the jets:
%     bearing jets feed the outer ring radially through the bearing boss
%       (tip at the seat bore, drilling straight out to the wall);
%     mesh jets sit beside the pitch point in the mid-plane of the mesh,
%       their drilling runs straight out to the wall on the jet's line;
%     planet bearings: through the case rear wall, the transfer sleeve, a
%       drilling in the carrier rear plate and the hollow pin; sun-planet
%       meshes: two jets on the side faces of each carrier post, fed along
%       the post;
%     quill splines: a drilling in the generator cartridge flange, and one in
%       the accessory cover to the pump pack;
%     PT rear sump: the tube along the tunnel (in.line.rear_sump; not in CATIA).
%   Jet diameters follow step 2.7: each jet carries its share of its
%   component's flow at li.dp_jet (meshes: li.into_mesh into mesh, the rest
%   out of mesh), never below li.d_jet_min.
%   Output N: manifold M; branch(k): name, rotating, r_rot [mm], route
%   (external tube points from the manifold to the entry boss), L_gal,
%   d_gal, n_bend, jet(j): name, pos, aim, target, nozzle (false: an
%   orifice drilled in a pin or flange, no nozzle part), feed (points from
%   the entry to the jet base), L_drill, d, Q_design (its thermal need), Q_nom
%   (what its bore passes at li.dp_jet, the strainer's rated flow); the PCU and leak
%   orifices; positions of the chip detectors, sampling valve, oil debris
%   monitor and tank.
%   Source: Phase 3 report, Section 3.2 ("Network").

z = L.z;  a = L.ang;
PT = a.PT;  Gp = a.Gp;  Op = a.Op;  Pp = a.Pp;
rho = oil.rho;
v_id = sqrt(2 * li.dp_jet * 1e3 / rho);
d_for = @(q) max(sqrt(4 * q / 6e4 / (li.Cd_jet * v_id * pi)) * 1e3, li.d_jet_min);
cmap = containers.Map({F.comp.name}, num2cell(1:numel(F.comp)));
need = @(nm) F.comp(cmap(nm)).need;
% outlines: first-stage case and cover (outer wall), and 14 mm outside them for the tubes
Pfs = poly(L.fs.out.segs);  Pcv = poly(L.cov.out.segs);
r_fs = @(th) rayr(Pfs, th);  r_cv = @(th) rayr(Pcv, th);
off = 14;
r_pc = @(zz) interp1([0 12 12.01 140 412 446 520], [153.5 153.5 137.5 137.5 108 108 110], zz);   % planetary case
thM = 198;
M = [(r_fs(thM) + off) * [cosd(thM) sind(thM)], z.c - 14];
N.M = M;
B = struct('name', {}, 'rotating', {}, 'r_rot', {}, 'route', {}, 'jet', {}, 'catia', {});

% ---------------------------------------------------------------- first stage (first-stage case)
q = need('first-stage mesh');
rw2 = norm(PT) * 110 / (110 + 31);
P1 = [0, -rw2, z.c];
for s = [-1 1]
    nm = 'first-stage mesh, into mesh';  qq = q * li.into_mesh;
    if s > 0, nm = 'first-stage mesh, out of mesh';  qq = q * (1 - li.into_mesh); end
    tip = P1 + [38 * s 0 0];                           % 1.7 mm clear of both tips with the 6 mm nozzle
    J = meshjet(nm, tip, P1, qq, Pfs);
    B(end + 1) = fsbranch(nm, J); %#ok<AGROW>
end
q = need('input shaft bearings') / 3;
phi = 225;
J = [brgjet('input front roller', PT, 85, z.bf, phi, q, Pfs), brgjet('input rear roller', PT, 85, z.br, phi, q, Pfs), ...
     brgjet('input four-point', PT, 85, mean(z.qj_pt), phi, q, Pfs)];
B(end + 1) = fsbranch('input shaft bearings', J);
q = need('intermediate shaft bearings') / 3;
J = [brgjet('intermediate front roller', [0 0], 90, z.bf, thM, q, Pfs), ...
     brgjet('intermediate rear roller', [0 0], 90, z.br, thM, q, Pfs), ...
     brgjet('intermediate four-point', [0 0], 90, mean(z.qj_mid), thM, q, Pfs)];
B(end + 1) = fsbranch('intermediate shaft bearings', J);
% ---------------------------------------------------------------- accessories
q = need('accessory meshes') / 3;
tg = [-sind(a.theta_g) cosd(a.theta_g)];
Pg = Gp * 110 / (110 + 57);
B(end + 1) = fsbranch('generator mesh', meshjet('generator mesh', [Pg + 40 * tg, z.c], [Pg z.c], q, Pfs));
u = (Op - Gp) / norm(Op - Gp);  v = [-u(2) u(1)];
if dot(v, Gp) < 0, v = -v; end
Po = Gp + 21 * u;
B(end + 1) = fsbranch('OSG mesh', meshjet('OSG mesh', [Po + 25 * v, z.osg + 3], [Po z.osg + 3], q, Pfs));
Pc = Pp * 20 / 93;
w = [-Pp(2) Pp(1)] / norm(Pp);
if w(1) > 0, w = -w; end                               % towards the manifold side
B(end + 1) = cvbranch('PCU mesh', meshjet('PCU mesh', [Pc + 25 * w, z.pcu + 5], [Pc z.pcu + 5], q, Pcv));
q = need('generator shaft bearings') / 2;
phg = a.theta_g + 17;                                  % away from the OSG shaft
J = [brgjet('generator front bearing', Gp, 62, z.bf, phg, q, Pfs), brgjet('generator rear bearing', Gp, 62, z.br, phg, q, Pfs)];
B(end + 1) = fsbranch('generator shaft bearings', J);
q = need('quill splines') / 2;
thq = a.theta_g + 90;
Eq = [80 * [cosd(thq) sind(thq)] + Gp, z.rear - 4];
tipq = [14 * [cosd(thq) sind(thq)] + Gp, z.rear - 4];
J = jetrec('generator quill spline', tipq, [Gp z.rear - 4], q, false, [Eq; tipq]);
B(end + 1) = fsbranch('generator quill spline', J);
thp = 215;
Ep = [r_cv(thp) * [cosd(thp) sind(thp)], z.pump(1) + 16];
rpump = L.rev(strcmp({L.rev.name}, 'pump_pack')).rz(3);   % pump pack radius (step 3.1)
tipp = [rpump * [cosd(thp) sind(thp)], z.pump(1) + 16];
J = jetrec('pump quill spline', tipp, [0 0 z.pump(1) + 16], q, false, [Ep; tipp]);
B(end + 1) = cvbranch('pump quill spline', J);
% ---------------------------------------------------------------- planetary case: propeller bearings and carrier
q = need('propeller shaft bearings') / 3;
zz = [148, z.prop_out + 15, z.nose + 14];
nmz = {'propeller inner roller', 'propeller outer roller', 'propeller four-point'};
J = jetrec('', [0 0 0], [0 0 1], 1, true, [0 0 0]);  J(1) = [];
for k = 1:3
    rs = 90;  ro = r_pc(zz(k));
    if k == 3, ro = 98; end                            % titanium housing on the nose
    tip = [rs * [cosd(thM) sind(thM)], zz(k)];
    base = [(rs + 10) * [cosd(thM) sind(thM)], zz(k)];
    E = [ro * [cosd(thM) sind(thM)], zz(k)];
    J(end + 1) = jetrec(nmz{k}, tip, [(rs - 15) * [cosd(thM) sind(thM)], zz(k)], q, true, [E; base]); %#ok<AGROW>
end
B(end + 1) = pcbranch('propeller shaft bearings', J, r_pc);
qb = need('planet bearings') / 4;
qm = need('planetary meshes') / 8;
zr = 22;  zm = 71;                                     % carrier rear plate drilling and mesh mid-plane
E = [153.5 * [cosd(thM) sind(thM)], 7];
J = jetrec('', [0 0 0], [0 0 1], 1, true, [0 0 0]);  J(1) = [];
for i = 0:3
    th = 90 * i;  e = [cosd(th) sind(th)];
    tip = [(82 - 19) * e, zm];
    feed = [E; 50 * [cosd(thM) sind(thM)] 7; groove(thM, th); 50 * e zr; 82 * e zr; 82 * e zm; tip];
    J(end + 1) = jetrec(sprintf('planet bearing %d (pin)', i + 1), tip, [(82 - 26.5) * e, zm], qb, false, feed); %#ok<AGROW>
    for s = [-1 1]
        tp = th + 45 * s;                              % post between this planet and the next
        ep = [cosd(tp) sind(tp)];  et = s * [sind(tp) -cosd(tp)];   % towards planet i
        tipm = [55 * ep + 16 * et, zm];
        targ = [45 * e, zm];
        aim = (targ - tipm) / norm(targ - tipm);
        base = tipm - 10 * aim;
        feedm = [E; 50 * [cosd(thM) sind(thM)] 7; groove(thM, tp); 50 * ep zr; 62 * ep zr; 62 * ep zm; base];
        J(end + 1) = jetrec(sprintf('sun-planet %d from post %+d', i + 1, s), tipm, targ, qm, true, feedm); %#ok<AGROW>
    end
end
Bc = pcbranch('carrier (planet bearings and planetary meshes)', J, r_pc);
Bc.rotating = true;  Bc.r_rot = in.transfer.r_feed;
B(end + 1) = Bc;
% ---------------------------------------------------------------- PT rear sump (tube along the tunnel; not in CATIA)
q = need('PT rear sump') / 2;
zs = z.rear - in.line.rear_sump(1);
J = [jetrec('PT rear bearing 1', [PT 0] + [0 40 zs], [PT 0] + [0 25 zs - 10], q, true, [[PT 0] + [-80 0 zs]; [PT 0] + [0 50 zs]]), ...
     jetrec('PT rear bearing 2', [PT 0] + [0 -40 zs], [PT 0] + [0 -25 zs - 10], q, true, [[PT 0] + [-80 0 zs]; [PT 0] + [0 -50 zs]])];
Bs = struct('name', 'PT rear sump', 'rotating', false, 'r_rot', 0, ...
            'route', [M; M(1:2) z.rear; PT + [-80 0] z.rear; PT + [-80 0] zs], 'jet', J, 'catia', false);
B(end + 1) = Bs;

% lengths, bores, bends; jet sizes
for k = 1:numel(B)
    rt = B(k).route;
    rt = rt([true; vecnorm(diff(rt), 2, 2) > 1e-6], :);
    B(k).route = rt;
    B(k).L_gal = sum(vecnorm(diff(rt), 2, 2));
    if strcmp(B(k).name, 'PT rear sump')
        B(k).d_gal = in.line.rear_sump(2);  B(k).n_bend = in.line.rear_sump(3);
    else
        B(k).d_gal = in.d_gallery;  B(k).n_bend = size(rt, 1) - 1;
    end
    E0 = arrayfun(@(jj) jj.feed(1, :), B(k).jet, 'UniformOutput', false);   % each jet's own entry
    for j = 1:numel(B(k).jet)
        if j > 1 && norm(E0{j} - E0{j - 1}) > 1e-6
            B(k).jet(j).feed = [E0{j - 1}; B(k).jet(j).feed];   % along the wall from the previous jet's entry
        end
        fd = B(k).jet(j).feed;
        B(k).jet(j).L_drill = sum(vecnorm(diff(fd), 2, 2)) + 10 * B(k).jet(j).nozzle;
        B(k).jet(j).d = d_for(B(k).jet(j).Q_design);
        B(k).jet(j).Q_nom = li.Cd_jet * pi / 4 * (B(k).jet(j).d * 1e-3)^2 * v_id * 6e4;   % flow at li.dp_jet
    end
end
N.branch = B;
N.Q_pcu = li.Q_pcu;
N.Q_leak = li.leak * (F.Q_lube + li.Q_pcu);
v_reg = sqrt(2 * in.p_reg * 1e3 / rho);
N.d_pcu = sqrt(4 * N.Q_pcu / 6e4 / (li.Cd_jet * v_reg * pi)) * 1e3;    % equivalent orifices at p_reg
N.d_leak = sqrt(4 * N.Q_leak / 6e4 / (li.Cd_jet * v_reg * pi)) * 1e3;
N.rho = rho;
N.v_id = v_id;
% hardware positions (chip detectors at the sump bottoms, sampling valve, oil debris monitor, tank)
N.chip = {[0 -r_fs(270) - 10 -45], [0 -147.5 120]};
N.sample = [30 -r_fs(270) - 8 -45];
N.odm = [30 -20 z.cov(1) - 110];
N.tank = [190 -90 z.rear - 228];

    function b = fsbranch(name, J)
        % tube from the manifold down the case at the manifold angle, round the first-stage case 14 mm
        % outside the wall, into the entry boss of the first jet
        E = J(1).feed(1, :);
        thE = atan2d(E(2), E(1));
        rt = [M; [M(1:2) E(3)]; arcpts(thM, thE, E(3), @(t) r_fs(t) + off); E];
        b = struct('name', name, 'rotating', false, 'r_rot', 0, 'route', rt, 'jet', J, 'catia', true);
    end
    function b = cvbranch(name, J)
        % as fsbranch, round the accessory cover below the first-stage case
        E = J(1).feed(1, :);
        thE = atan2d(E(2), E(1));
        rt = [M; [M(1:2) E(3)]; arcpts(thM, thE, E(3), @(t) max(r_cv(t) + off, r_fs(thM) + off)); E];
        b = struct('name', name, 'rotating', false, 'r_rot', 0, 'route', rt, 'jet', J, 'catia', true);
    end
    function b = pcbranch(name, J, r_pc)
        % from the manifold forward past the flange (12 mm outside it), then along the planetary case 12 mm
        % outside its wall at the manifold angle, into the entry boss
        E = J(1).feed(1, :);
        e = [cosd(thM) sind(thM)];
        rt = [M; [M(1:2) -20]; [(153.5 + 12) * e -20]; [(153.5 + 12) * e 12]];
        zs = unique([12 140 E(3)]);
        for zz = zs(zs > 12 & zs <= E(3))
            rt(end + 1, :) = [(r_pc(zz) + 12) * e zz]; %#ok<AGROW>
        end
        rt = [rt; [(r_pc(E(3)) + 12) * e E(3)]; E];
        b = struct('name', name, 'rotating', false, 'r_rot', 0, 'route', rt, 'jet', J, 'catia', true);
    end
end

function pts = groove(th1, th2)
% the annular groove of the transfer sleeve flange (r 50, z 13): oil reaches every carrier drilling round it
d = mod(th2 - th1 + 180, 360) - 180;
t = th1 + linspace(0, d, max(2, ceil(abs(d) / 15) + 1));
pts = [50 * [cosd(t') sind(t')], 13 * ones(numel(t), 1)];
end

function J = brgjet(name, c, D, zb, phi, q, P)
% bearing jet: tip at the seat bore radius D/2 (feeds the outer ring groove), nozzle radially in the boss,
% drilling straight out to the case wall along phi
e = [cosd(phi) sind(phi)];
tip = [c + D / 2 * e, zb];
base = [c + (D / 2 + 10) * e, zb];
E = [rayhit(P, c, e), zb];
J = jetrec(name, tip, [c + (D / 2 - 15) * e, zb], q, true, [E; base]);
end

function J = meshjet(name, tip, target, q, P)
% mesh jet beside the pitch point, aimed at it; nozzle and drilling on the same line, out to the wall
aim = (target - tip) / norm(target - tip);
base = tip - 10 * aim;
E = [rayhit(P, base(1:2), -aim(1:2) / norm(aim(1:2))), base(3)];
J = jetrec(name, tip, target, q, true, [E; base]);
end

function j = jetrec(name, pos, target, Q, nozzle, feed)
j = struct('name', name, 'pos', pos, 'aim', (target - pos) / max(norm(target - pos), eps), 'target', target, ...
           'nozzle', nozzle, 'feed', feed, 'd', NaN, 'Q_design', Q, 'Q_nom', NaN, 'L_drill', NaN);
end

function P = poly(sg)
% dense polygon of an as_hull outline
P = zeros(0, 2);
for k = 1:size(sg, 1)
    s = sg(k, :);
    if s(1) == 0
        P = [P; s(2:3)]; %#ok<AGROW>
    else
        a1 = atan2(s(3) - s(7), s(2) - s(6));  a2 = atan2(s(5) - s(7), s(4) - s(6));
        a2 = a1 + mod(a2 - a1, 2 * pi);
        r = norm(s(2:3) - s(6:7));
        t = linspace(a1, a2, max(3, ceil((a2 - a1) / 0.02)))';
        P = [P; s(6:7) + r * [cos(t) sin(t)]]; %#ok<AGROW>
    end
end
end

function r = rayr(P, th)
% distance from the origin to the outline along the ray at th degrees (the outline is convex)
r = norm(rayhit(P, [0 0], [cosd(th) sind(th)]));
end

function h = rayhit(P, p, d)
% first crossing of the ray p + s d (s > 0) with the closed polygon P
best = inf;
n = size(P, 1);
for k = 1:n
    a = P(k, :);  b = P(mod(k, n) + 1, :);
    M = [d(:) (a - b)'];
    if abs(det(M)) < 1e-12, continue, end
    x = M \ (a - p)';
    if x(1) > 1e-9 && x(2) >= 0 && x(2) <= 1 && x(1) < best, best = x(1); end
end
h = p + best * d;
end

function pts = arcpts(th1, th2, zz, R)
% points round the case at height zz from th1 to th2 (the shorter way), radius R(theta)
d = mod(th2 - th1 + 180, 360) - 180;
t = th1 + linspace(0, d, max(2, ceil(abs(d) / 10) + 1));
pts = zeros(numel(t), 3);
for k = 1:numel(t)
    pts(k, :) = [R(t(k)) * [cosd(t(k)) sind(t(k))], zz];
end
end
