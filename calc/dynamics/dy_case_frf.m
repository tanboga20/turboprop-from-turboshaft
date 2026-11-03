function C = dy_case_frf(in, hc, mat, P, alpha, bands, z_ring)
%DY_CASE_FRF  Forced response of the planetary case to the planets, coupled through the ring (DYN-03, DYN-04 housing).
%   C = dy_case_frf(in, hc, mat, P, alpha, bands, z_ring)
%
%   in = dy_inputs (in.cs: case model, brackets and Goodman inputs; in.cs.W1
%   and in.cs.thrust, the step 3.5 operating loads at MCT); hc =
%   hs_inputs().case (the axisymmetric case section of step 2.8); mat = the
%   case material (A357-T6); P = dy_planet_frf output (modal model of the
%   planet mesh forces); alpha [rad], the working pressure angle; bands =
%   3 x 2 [Hz], the 1x, 2x and 3x planetary mesh bands; z_ring, the ring
%   gear teeth.
%   Case model: one circumferential harmonic at a time (dy_axi_km, section
%   mesh in.cs.h_axi), modes of n = 0 ... in.cs.n_count up to in.cs.f_cut x
%   the 3x band top, modal superposition with the static residual. Each
%   planet loads the ring seat along the line of action (outward radial
%   sin(alpha), tangential -cos(alpha): the carrier turns +theta, planet k
%   leads with the phase below under e^(i w t), the ring pushes the planet
%   +theta and the planet the ring -theta) on a patch (in.cs.dpsi on the
%   seat for the mass layer; two ring pitches on the ring bore for rim and
%   slide, whose rim spreads the load itself) at its
%   azimuth k pi / 2, with the mesh phase 2 pi h z_ring k / 4: 1x loads
%   n = 1, 3, 5, ..., 2x n = 2, 6, ...; the cos n theta part goes in the
%   family u_r ~ cos n theta, the sin n theta part in the family turned by
%   pi / (2 n).
%   Coupling by receptance: H(f) is the displacement of the ring patch of
%   planet 0 along the line of action for a unit force on all four planets
%   with the phase pattern of h. With D = a_pr / TE and B = b_pr / TE, the
%   ring-mesh forces of the planet on a rigid ring from the ring and sun
%   load cases (dy_planet_forces), the coupled ring-mesh force is
%   F = (D TE_r + B TE_s) / (1 + D H), enveloped over the sun-ring phase:
%   (|D| TE_r + |B| TE_s) / |1 + D H|. The coupled sun-mesh force is
%   As TE_s e^(i phi) + Bsr (TE_r - H F), maximised over phi; both give
%   K_v,FE coupled. The frequency grid is refined around the coupled peaks
%   (local maxima of |H| F on a dense grid). The blocked-ring force (H = 0)
%   is kept as a sensitivity line (rim bracket, flange fixed).
%   Ring seat brackets: 'slide', the ring gear seated in contact and free to
%   slip (rim mesh with the ring nodes split from the case nodes on the
%   seat, u tied for n >= 1, u v w tied for n = 0: torque through the
%   anti-rotation feature, axial retention; static fields only, the mesh
%   response from 'rim' of the same support and damping), the DYN-03
%   basis; 'rim', a bonded steel rim (r in.cs.r_root_ring to r_seat, teeth
%   as mass) loaded on its tooth circle, the lower bound; 'mass', a mass
%   layer on the seat (a ring without bending stiffness), the extreme upper
%   bound. Each with the flange face fixed or on the step 3.5 joint springs
%   (in.cs.k_joint) and damping in.cs.zeta (two values).
%   Stress: von Mises at the boundary nodes and the case side of the seat,
%   from A357 elements only, on the shell (z > 20 mm) and at the flange
%   junction (2 < z <= 20 mm); cycle maximum of the mesh response
%   (dy_vm_cycle). Static fields at MCT on the same section and bracket:
%   steady, the n = 0 part of the four planet loads (uniform radial load,
%   ring torque), the 18 kN thrust (n = 0) and the 1 g reactions (n = 1);
%   planet pass, the n = 4, 8, ... parts (radial in the cos family,
%   tangential in the turned family), which rotate with the carrier and
%   pass each node at 4 f_c: alternating, half the longest chord over one
%   pass period (dy_pass_amp). Quasi-static check: lowest mode of each
%   n = 4k against 3 n f_c (C.qs). The ring seat has no interference fit.
%   Goodman node by node: 1 / (k_cast ((sa_mesh + sa_pass + sa_1P) / se +
%   sm / su)), se the sand-cast endurance x in.cs.k_gc; the bonded seat
%   corners of 'rim' apart (C.var.corner); at the re-entrant corners of the
%   section the larger of the raw value and in.cs.Kt_corner x the largest
%   value at in.r_corner to 2 in.r_corner (C.var.reentrant); the step 3.5
%   bound in.cs.sm in place of the steady stress as a sensitivity line.
%   Output C: var (one entry per bracket: per band f, sig, sig_flange,
%   F_ring, sf, sf_flange, Kv_sp, Kv_pr, n_modes; sig_steady, sig_pass and
%   its (r, z), corner, reentrant), band(h) (sig_pk and its bracket over
%   'rim', sig_mass, sf_base (slide, fixed, first zeta), sf_worst (slide),
%   sf_rim, sf_mass, sf_flange (slide), sf_bound, sig_blocked (rim, fixed),
%   Kv_sp, Kv_pr, F_coupled, F_blocked, n_modes, sig_steady, sig_pass),
%   brackets (summary table), qs, f_modes, modes, mass, f_bare (bare case,
%   n = 0-4).
%   Source: Phase 3 report, Section 3.6 ("Case").

cs = in.cs;
% benchmark: the bare case of step 2.8 (no ring gear, flange fixed), lowest modes of n = 0 ... 4
A0 = dy_axi_mesh(hc.rects, cs.h_axi);
fx0 = abs(A0.X(2, :)) < 1e-9;  n0 = size(A0.X, 2);
fb = [];
for n = 0:4
    [K, M] = dy_axi_km(A0, n, mat.E, mat.nu, mat.rho);
    fr0 = setdiff(1:3 * n0, [3 * find(fx0) - 2, 3 * find(fx0) - 1, 3 * find(fx0)]);
    w2 = eigs(K(fr0, fr0), M(fr0, fr0), 4, 'smallestabs');
    fb = [fb; sqrt(abs(w2)) / (2 * pi)]; %#ok<AGROW>
end
C.f_bare = sort(fb);
V = struct('label', {}, 'ring', {}, 'sup', {}, 'zeta', {}, 'h', {}, 'sa_full', {}, 'sig_steady', {}, 'sig_pass', {}, ...
           'pass_rz', {}, 'sig_pass_bound', {}, 'corner', {}, 'reentrant', {}, 'fillet', {});
% the case section: the step 2.8 rectangles with the 3.6 flange (in.cs.flange) and the modelled fillets
% (in.cs.fillets [r z R side], arcs as polygons of 16 segments, which the mesh follows)
secC = hc.rects;
if isfield(cs, 'flange'), secC{2} = cs.flange; end
if isfield(cs, 'fillets')
    for k = 1:size(cs.fillets, 1)
        fr = cs.fillets(k, :);  s_ = fr(4);  Rf = fr(3);  c_ = [fr(1) + s_ * Rf, fr(2) + Rf];
        t_ = linspace(3 * pi / 2, pi + (s_ < 0) * pi, 17)';  % from the face z = z_c round to the face r = r_c
        secC{end + 1} = [fr(1:2); c_ + Rf * [cos(t_), sin(t_)]]; %#ok<AGROW>
    end
end
RC = reentrant(secC);                                  % re-entrant corners left sharp [mm]
psk = (0:3) * pi / 2;
th = linspace(0, 2 * pi, 121);  th = th(1:end - 1);
ipass = 1:numel(th) / 4;                               % one planet-pass period of the n = 4k field
sa_ = sin(alpha);  ca_ = -cos(alpha);                 % seat load direction of a planet: (+sin, -cos) alpha
se = in.sigma_e.A357 * cs.k_gc;  su = mat.su;
gmn = @(sa, sp, sm) 1 ./ (in.k_cast * ((sa + sp + cs.sa_1P) / se + sm / su));
f_c = bands(1, 2) / z_ring;                            % carrier speed at the top of the speed range [Hz]
rs = cs.r_seat / 1000;  zs = cs.z_seat / 1000;
QS = [];  Arim = [];  tie_res = 0;
po = isfield(cs, 'pass_only') && cs.pass_only;        % check mode: static fields of rim and slide only
rlist = {'mass', 'rim', 'slide'};  if po, rlist = {'rim', 'slide'}; end
for ring = rlist
    for sup = {'fixed', 'springs'}
        sec = secC;
        if ~strcmp(ring{1}, 'mass'), sec{end + 1} = [cs.r_root_ring, cs.r_seat, cs.z_seat]; end %#ok<AGROW>
        if strcmp(ring{1}, 'slide')
            A = Arim;                                  % the rim mesh, split at the seat below
        else
            A = dy_axi_mesh(sec, cs.h_axi);
            if strcmp(ring{1}, 'rim'), Arim = A; end
        end
        nn0 = size(A.X, 2);  T = A.T;
        rc = (A.X(1, T(1, :)) + A.X(1, T(2, :)) + A.X(1, T(3, :))) / 3;  zc = (A.X(2, T(1, :)) + A.X(2, T(2, :)) + A.X(2, T(3, :))) / 3;
        inr = rc < rs - 1e-9 & zc > zs(1) & zc < zs(2);
        pairs = zeros(0, 2);
        if strcmp(ring{1}, 'slide'), [A, pairs] = split_seat(A, inr, rs, zs); end
        X = A.X;  nn = size(X, 2);  r = X(1, :);  z = X(2, :);  T = A.T;
        E = mat.E * ones(1, size(T, 2));  nu = mat.nu * ones(size(E));  rho = mat.rho * ones(size(E));
        E(inr) = cs.E_ring;  nu(inr) = 0.3;  rho(inr) = cs.rho_ring * cs.f_teeth;
        alu = ~inr;                                    % A357 elements: stresses from these only
        rl = cs.r_seat;  if ~strcmp(ring{1}, 'mass'), rl = cs.r_root_ring; end
        % load patch: on the seat (mass layer) in.cs.dpsi, which stands for the spreading through the ring rim; on the
        % ring bore (rim, slide) the tooth-contact arc, two ring pitches, since the modelled rim spreads it itself
        dps = deg2rad(cs.dpsi);  if ~strcmp(ring{1}, 'mass'), dps = 2 * 2 * pi / z_ring; end
        fs = edge_int(A, rl / 1000, zs);               % load circle
        fsw = fs / sum(fs);
        fseat = edge_int(A, rs, zs);                   % seat (mass layer)
        ffl = edge_int_z(A, 0, [hc.rects{3}(1), secC{2}(2)] / 1000);    % flange face z = 0
        rsb = hc.seat_in(2) / 1000;                                      % propeller bearing seats
        zi = hc.pt_seat_in(3) + [-1 1] * hc.seat_in(1) / 2000;  zo = hc.pt_seat_out(3) + [-1 1] * hc.seat_out(1) / 2000;
        fsi = edge_int(A, rsb, zi);  fso = edge_int(A, rsb, zo);
        Ap = dps * sum(fs);                            % patch area from the integrated load circle
        mlay = 0;  if any(fseat), mlay = cs.m_ring / (2 * pi * sum(fseat)); end   % kg/m^2
        iu = 1:3:3 * nn;  iv = 2:3:3 * nn;  iw = 3:3:3 * nn;
        fixed = abs(z) < 1e-9 & strcmp(sup{1}, 'fixed');
        % check nodes: the boundary and the case side of the ring seat, on A357 elements only; the two seat
        % corners (r_seat, z_seat) apart
        Ta = T(:, alu);  onalu = accumarray(Ta(:), 1, [nn 1]) > 0;
        ifc = find(abs(r - rs) < 1e-9 & z >= zs(1) - 1e-9 & z <= zs(2) + 1e-9);  ifc = ifc(ifc <= nn0);
        bnd = unique([A.E(:); ifc(:)]);  bnd = bnd(onalu(bnd));  nb = numel(bnd);
        cor = abs(r(bnd) - rs) < 1e-9 & (abs(z(bnd) - zs(1)) < 1e-9 | abs(z(bnd) - zs(2)) < 1e-9);
        exc = cor & strcmp(ring{1}, 'rim');            % bonded: bimaterial corners, singular
        shell = z(bnd) > 0.020 & ~exc;  fl = z(bnd) > 0.002 & z(bnd) <= 0.020 & ~exc;
        % re-entrant corners of the case section (singular): the raw value is kept, and in.cs.Kt_corner x the
        % largest value at in.r_corner to 2 in.r_corner from the corner (the cast fillet), the larger in the decision
        dc = hypot(1000 * r(bnd)' - RC(:, 1)', 1000 * z(bnd)' - RC(:, 2)') / 1000;   % nodes x corners [m]
        ann = dc >= in.r_corner & dc <= 2 * in.r_corner;
        [~, i0c] = min(dc, [], 1);
        srow = reshape(6 * (bnd(:)' - 1) + (1:6)', [], 1);
        dyn = ~strcmp(ring{1}, 'slide') && ~po;        % slide: static fields only (n = 0, 1 g, planet pass)
        nlist = 0:cs.n_count;  if ~dyn, nlist = unique([0, 1, 4:4:cs.n_count]); end
        H = struct('n', {}, 'S', {}, 'free', {}, 'phi', {}, 'w', {}, 'gr', {}, 'gt', {}, 'Rr', {}, 'Rt', {}, ...
                   'pU', {}, 'pV', {}, 'rU', {}, 'rV', {}, 'snc', {}, 'U0', {});
        rows = [];
        for n = nlist
            [K, M, Sg] = dy_axi_km(A, n, E, nu, rho, alu);
            c = pi + pi * (n == 0);
            if strcmp(ring{1}, 'mass')
                for d = {iu, iv, iw}, M = M + sparse(d{1}, d{1}, c * mlay * fseat, 3 * nn, 3 * nn); end
            end
            if strcmp(sup{1}, 'springs')
                for d = {iu, iv, iw}, K = K + sparse(d{1}, d{1}, c * cs.k_joint * ffl, 3 * nn, 3 * nn); end
            end
            % unit patch loads (radial on U, tangential on V) per newton of planet force, with the series factor
            cn = dps / (2 * pi);  wt = 2 * pi;
            if n > 0, cn = 2 / (n * pi) * sin(n * dps / 2);  wt = pi; end
            Br = zeros(3 * nn, 1);  Bt = Br;  Br(iu) = cn * wt * fs / Ap;  Bt(iv) = cn * wt * fs / Ap;
            % operating loads at MCT: thrust on the outer seat (n = 0), the 1 g reactions on both seats (n = 1)
            Fx = zeros(3 * nn, 1);
            if n == 0, Fx(iw) = cs.thrust * fso / (rsb * diff(zo)); end
            if n == 1, Fx(iu) = cs.W1(1) * fsi / (rsb * diff(zi)) + cs.W1(2) * fso / (rsb * diff(zo)); end
            fxd = [iu(fixed), iv(fixed), iw(fixed)];
            if ~dyn
                % ring and case nodes of a pair share u (contact, free to slip) for n >= 1, and u, v, w for n = 0
                % (torque through the anti-rotation feature, axial retention): master-slave by merging the dofs
                dm = 1:3 * nn;
                for d = 1:(1 + 2 * (n == 0))
                    dm(3 * pairs(:, 2) - 3 + d) = 3 * pairs(:, 1) - 3 + d;
                end
                [kc, ~, col] = unique(dm);
                Pt = sparse(1:3 * nn, col, 1, 3 * nn, numel(kc));
                fr = setdiff(1:numel(kc), col(fxd));
                Pf = Pt(:, fr);
                U0 = Pf * ((Pf' * K * Pf) \ (Pf' * [Br, Bt, Fx]));
                tie_res = max(tie_res, max(abs(U0(3 * pairs(:, 1) - 2, :) - U0(3 * pairs(:, 2) - 2, :)), [], 'all') / ...
                                       max(abs(U0), [], 'all'));      % u equal at the pairs (relative)
                H(end + 1) = struct('n', n, 'S', Sg(srow, :), 'free', [], 'phi', [], 'w', [], 'gr', [], 'gt', [], ...
                                    'Rr', [], 'Rt', [], 'pU', [], 'pV', [], 'rU', [], 'rV', [], 'snc', [], 'U0', U0); %#ok<AGROW>
                continue
            end
            free = setdiff(1:3 * nn, fxd);
            Kf = K(free, free);  Mf = M(free, free);
            nm = 20;
            while true
                [Vm, L2] = eigs(Kf, Mf, nm, 'smallestabs');
                [w2, o] = sort(real(diag(L2)));  Vm = Vm(:, o);
                if sqrt(max(w2(end), 0)) / (2 * pi) > cs.f_cut * max(bands(:)) || nm >= 160, break; end
                nm = nm + 20;
            end
            keep = sqrt(max(w2, 0)) / (2 * pi) <= cs.f_cut * max(bands(:));
            Vm = Vm(:, keep);  w = sqrt(max(w2(keep), 1));
            Vm = Vm ./ sqrt(sum(Vm .* (Mf * Vm), 1));
            R0 = Kf \ [Br(free), Bt(free), Fx(free)];
            gr = Vm' * Br(free);  gt = Vm' * Bt(free);
            % patch displacement along the line of action: weights over the patch, averaged over its width
            oU = zeros(3 * nn, 1);  oV = oU;  oU(iu) = fsw;  oV(iv) = fsw;  oU = oU(free);  oV = oV(free);
            Rr = R0(:, 1) - Vm * (gr ./ w.^2);  Rt = R0(:, 2) - Vm * (gt ./ w.^2);
            snc = 1;  if n > 0, snc = sin(n * dps / 2) / (n * dps / 2); end
            U0 = zeros(3 * nn, 3);  U0(free, :) = R0;
            H(end + 1) = struct('n', n, 'S', Sg(srow, :), 'free', free, 'phi', Vm, 'w', w, 'gr', gr, 'gt', gt, ...
                                'Rr', Rr, 'Rt', Rt, 'pU', oU' * Vm, 'pV', oV' * Vm, 'rU', [oU' * Rr, oU' * Rt], ...
                                'rV', [oV' * Rr, oV' * Rt], 'snc', snc, 'U0', U0); %#ok<AGROW>
            rows = [rows; w / (2 * pi), n + 0 * w]; %#ok<AGROW>
            if n >= 4 && mod(n, 4) == 0                % quasi-static planet pass: lowest mode against 3 x n f_c
                f1 = Inf;  if ~isempty(w), f1 = w(1) / (2 * pi); end   % none below the cut: above it
                QS = [QS; find(strcmp(ring{1}, {'mass', 'rim'})), find(strcmp(sup{1}, {'fixed', 'springs'})), ...
                      n, f1, 3 * n * f_c]; %#ok<AGROW>
            end
        end
        % static fields at MCT (same section, same bracket). Steady at a case node: the n = 0 part of the four
        % planet loads (uniform radial load, ring torque), the thrust (n = 0) and the 1 g (n = 1). The n = 4, 8, ...
        % parts rotate with the carrier and pass each node at 4 f_c: alternating (planet pass)
        Fst = P.Ft / cos(alpha);                           % static planet-ring force along the line of action
        ss = zeros(numel(th), nb, 6);  sp = ss;
        for j = 1:numel(H)
            n = H(j).n;  U = H(j).U0;
            if n == 0
                ss = addfield(ss, reshape(H(j).S * (4 * Fst * (sa_ * U(:, 1) + ca_ * U(:, 2))), 6, nb), 0, 'cos');
            elseif mod(n, 4) == 0
                sp = addfield(sp, reshape(H(j).S * (4 * Fst * sa_ * U(:, 1)), 6, nb), n, 'cos');
                sp = addfield(sp, reshape(H(j).S * (-4 * Fst * ca_ * U(:, 2)), 6, nb), n, 'turned');  % tangential: turned family
            end
            if any(U(:, 3))
                ss = addfield(ss, reshape(H(j).S * U(:, 3), 6, nb), n, 'cos');
            end
        end
        sm_node = max(dy_vm_cycle(ss, 0 * ss), [], 1)' / 1e6;   % largest steady over the circle at each node
        [sp_node, sp_bound] = dy_pass_amp(sp(ipass, :, :));
        sp_node = sp_node / 1e6;  sp_bound = sp_bound / 1e6;
        sh = find(shell | fl);  [spm, ip] = max(sp_node(sh));
        % nodes on the modelled fillet arcs (in.cs.fillets), for the stresses there
        nfil = 0;  if isfield(cs, 'fillets'), nfil = size(cs.fillets, 1); end
        onf = cell(1, nfil);  fpm = NaN(nfil, 2);
        for k = 1:nfil
            fr = cs.fillets(k, :);  cfx = (fr(1) + fr(4) * fr(3)) / 1000;  cfz = (fr(2) + fr(3)) / 1000;
            onf{k} = find(abs(hypot(r(bnd) - cfx, z(bnd) - cfz) - fr(3) / 1000) < 2e-4 & ...
                          abs(r(bnd) - fr(1) / 1000) <= fr(3) / 1000 + 1e-9 & z(bnd) <= cfz + 1e-9);
            fpm(k, :) = [max(sp_node(onf{k})), max(sm_node(onf{k}))];
        end
        for zeta = cs.zeta
            lab = sprintf('ring %s, flange %s, zeta %.3g', ring{1}, sup{1}, zeta);
            v = struct('label', lab, 'ring', ring{1}, 'sup', sup{1}, 'zeta', zeta, 'h', [], 'sa_full', {cell(1, 3)}, ...
                       'sig_steady', max(sm_node(shell)), 'sig_pass', spm, 'pass_rz', 1000 * [r(bnd(sh(ip))), z(bnd(sh(ip)))], ...
                       'sig_pass_bound', max(sp_bound(shell | fl)), 'corner', [], 'reentrant', [], ...
                       'fillet', [fpm, NaN(nfil, 1)]);   % per fillet: pass, mean, mesh [MPa]
            if po
                V(end + 1) = v; %#ok<AGROW>
                continue
            end
            if ~dyn
                % dynamic part from the rim bracket of the same support and damping (same case node ids)
                jr = find(strcmp({V.ring}, 'rim') & strcmp({V.sup}, sup{1}) & [V.zeta] == zeta, 1);
                hh = V(jr).h;  sac = zeros(nb, 1);
                for h = 1:3
                    sa_node = V(jr).sa_full{h}(bnd);
                    assert(all(isfinite(sa_node)), 'dy_case_frf: slide node without a rim stress');
                    [hh(h).sf, hh(h).sf_flange, hh(h).sf_parts] = gmin(sa_node, sp_node, sm_node);  hh(h).sig_blocked = NaN;
                    sac = max(sac, sa_node);
                end
                v.h = hh;
            else
                hh = [];  sac = zeros(nb, 1);
                for h = 1:3
                    TE = in.TE_planet(h) * 1e-6;
                    ph = 2 * pi * h * z_ring * (0:3) / 4;
                    inb = rows(:, 1) >= bands(h, 1) & rows(:, 1) <= bands(h, 2);
                    % dense grid: receptance, coupled ring force, refinement around the coupled peaks
                    fd = unique([linspace(bands(h, 1), bands(h, 2), 300), rows(inb, 1)', ...
                                 P.f_all(P.f_all >= bands(h, 1) & P.f_all <= bands(h, 2))]);
                    [Fc, Hd] = coupled(fd, ph, zeta, TE);
                    qd = abs(Hd) .* Fc;
                    lm = find([false, qd(2:end - 1) > qd(1:end - 2) & qd(2:end - 1) >= qd(3:end), false]);
                    [~, o] = sort(qd(lm), 'descend');  lm = lm(o(1:min(10, numel(o))));
                    fref = reshape(fd(lm)' * (1 + (-3:3) * 0.002), 1, []);
                    fq = unique([linspace(bands(h, 1), bands(h, 2), in.n_freq), rows(inb, 1)', fd(lm), fref]);
                    fq = fq(fq >= bands(h, 1) & fq <= bands(h, 2));
                    [Fq, ~, Fpq] = coupled(fq, ph, zeta, TE);
                    % coupled planet forces and K_v,FE (dense grid and the refined points)
                    [Fs_max, Fr_max] = planet_forces([fd, fq], ph, zeta, TE);
                    % stress over fq with the coupled force; node-by-node Goodman
                    sig = zeros(size(fq));  sfl = sig;  sa_node = zeros(nb, 1);
                    for k = 1:numel(fq)
                        vmc = stress(fq(k), Fq(k), ph, zeta);
                        sig(k) = max(vmc(:, shell), [], 'all');  sfl(k) = max(vmc(:, fl), [], 'all');
                        sa_node = max(sa_node, max(vmc, [], 1)');
                    end
                    [sfs_, sff_, sfp_] = gmin(sa_node, sp_node, sm_node);
                    sf_ = nan(nn, 1);  sf_(bnd) = sa_node;  v.sa_full{h} = sf_;
                    sac = max(sac, sa_node);
                    e_ = struct('f', fq, 'sig', sig, 'sig_flange', sfl, 'F_ring', Fq, 'F_blocked', TE * (abs(Fpq.D) + abs(Fpq.B)), ...
                                'sf', sfs_, 'sf_flange', sff_, 'Kv_sp', 1 + Fs_max / (P.KA * P.Ft), ...
                                'Kv_pr', 1 + Fr_max / (P.KA * P.Ft), 'n_modes', sum(1 + (rows(inb, 2) > 0)), 'sig_blocked', NaN, ...
                                'sf_parts', sfp_);
                    if strcmp(ring{1}, 'rim') && strcmp(sup{1}, 'fixed') && zeta == cs.zeta(1)
                        % sensitivity: the blocked-ring planet force (no coupling), rim bracket, flange fixed
                        sb_ = zeros(size(fq));
                        for k = 1:numel(fq)
                            vmc = stress(fq(k), e_.F_blocked(k), ph, zeta);
                            sb_(k) = max(vmc(:, shell), [], 'all');
                        end
                        e_.sig_blocked = max(sb_);
                    end
                    hh = [hh, e_]; %#ok<AGROW>
                end
                v.h = hh;
            end
            % the two bonded seat corners, apart from the A357 minimum (3.9 edge relief, 3.11 gauge position)
            ic = find(cor);
            if isempty(ic)
                v.corner = struct('rz', NaN(1, 2), 'sm', NaN, 'sa_pass', NaN, 'sa_mesh', NaN, 'sf', NaN);
            else
                v.corner = struct('rz', 1000 * [r(bnd(ic))', z(bnd(ic))'], 'sm', sm_node(ic), 'sa_pass', sp_node(ic), ...
                                  'sa_mesh', sac(ic), 'sf', gmn(sac(ic), sp_node(ic), sm_node(ic)));
            end
            for k = 1:nfil, v.fillet(k, 3) = max(sac(onf{k})); end
            v.reentrant = struct('rz', {}, 'raw', {}, 'fillet', {});
            for kc_ = 1:size(RC, 1)
                ia_ = ann(:, kc_);  i0_ = i0c(kc_);
                v.reentrant(kc_) = struct('rz', RC(kc_, :), 'raw', [sac(i0_), sp_node(i0_), sm_node(i0_)], ...
                                          'fillet', cs.Kt_corner * [max(sac(ia_)), max(sp_node(ia_)), max(sm_node(ia_))]);
            end
            V(end + 1) = v; %#ok<AGROW>
            fprintf('   case bracket %s done: Goodman shell %.2f, flange %.2f; pass %.1f MPa at r %.1f z %.1f mm; steady %.1f MPa (%s)\n', ...
                    lab, min([v.h.sf]), min([v.h.sf_flange]), spm, v.pass_rz, v.sig_steady, datestr(now, 'HH:MM'));
        end
        if strcmp(ring{1}, 'mass') && strcmp(sup{1}, 'fixed')
            C.f_modes = rows(:, 1);  C.modes = array2table(rows, 'VariableNames', {'f', 'n'});
            C.mass = axi_mass(A, rho);  C.n_dof = 3 * nn;
        end
    end
end
C.var = V;
C.tie_res = tie_res;
if po                                                  % check mode: the planet-pass amplitudes only
    C.pass = table({V.label}', [V.sig_pass]', reshape([V.pass_rz], 2, [])', [V.sig_pass_bound]', [V.sig_steady]', ...
                   cell2mat(arrayfun(@(v) reshape(v.fillet(:, 1:2)', 1, []), V, 'UniformOutput', false)'), ...
                   'VariableNames', {'bracket', 'sig_pass', 'pass_rz_mm', 'sig_pass_bound', 'sig_steady', 'fillet_pass_mean'});
    return
end
C.qs = array2table(QS, 'VariableNames', {'ring', 'sup', 'n', 'f_lowest', 'f_3pass'});
% envelope. Interface brackets: slide (ring seated in contact, free to slip) is the DYN-03 basis, the bonded rim
% the lower bound, the mass layer the extreme upper bound (a ring without bending stiffness); slide takes its
% mesh response from the rim bracket of the same support and damping
isl = strcmp({V.ring}, 'slide');  irm = strcmp({V.ring}, 'rim');  ims = strcmp({V.ring}, 'mass');
j0 = find(isl & strcmp({V.sup}, 'fixed') & [V.zeta] == cs.zeta(1), 1);
jr0 = find(irm & strcmp({V.sup}, 'fixed') & [V.zeta] == cs.zeta(1), 1);
sp_slide = max([V(isl).sig_pass]);
for h = 1:3
    pk = arrayfun(@(j) max(V(j).h(h).sig), 1:numel(V));
    pkf = arrayfun(@(j) max(V(j).h(h).sig_flange), 1:numel(V));
    sfa = arrayfun(@(j) V(j).h(h).sf, 1:numel(V));
    sff = arrayfun(@(j) V(j).h(h).sf_flange, 1:numel(V));
    pk(isl) = 0;                                       % slide repeats the rim response
    [sig_pk, jw] = max(pk .* irm);
    [~, i] = max(V(jw).h(h).sig);
    nm = arrayfun(@(j) V(j).h(h).n_modes, find(~isl));
    sfs = sfa;  sfs(~isl) = Inf;  [sf_worst, jws] = min(sfs);
    sfq = sff;  sfq(~isl) = Inf;  [~, jf] = min(sfq);
    C.band(h) = struct('f', V(jr0).h(h).f, 'sig', V(jr0).h(h).sig, 'f_pk', V(jw).h(h).f(i), 'sig_pk', sig_pk, ...
                       'worst', V(jw).label, 'sig_base', pk(jr0), 'sig_mass', max(pk(ims)), 'sig_all', pk, ...
                       'sf_base', sfa(j0), 'sf_worst', sf_worst, 'worst_sf', V(jws).label, ...
                       'sf_rim', min(sfa(irm)), 'sf_mass', min(sfa(ims)), 'sf_all', sfa, ...
                       'sig_flange', max(pkf(irm)), 'sf_flange', min(sff(isl)), ...
                       'sf_bound', 1 / (in.k_cast * ((sig_pk + sp_slide + cs.sa_1P) / se + cs.sm / su)), ...
                       'sig_blocked', V(jr0).h(h).sig_blocked, 'Kv_sp', max(arrayfun(@(j) V(j).h(h).Kv_sp, find(~isl))), ...
                       'Kv_pr', max(arrayfun(@(j) V(j).h(h).Kv_pr, find(~isl))), ...
                       'F_coupled', max(arrayfun(@(j) max(V(j).h(h).F_ring), find(~isl))), ...
                       'F_blocked', max(V(jr0).h(h).F_blocked), 'n_modes', [min(nm) max(nm)], ...
                       'sig_steady', V(j0).sig_steady, 'sig_pass', sp_slide, ...
                       'sf_worst_parts', V(jws).h(h).sf_parts(1, :), ...   % [sa_mesh sa_pass sm] where sf_worst is set
                       'sf_flange_parts', V(jf).h(h).sf_parts(2, :));
end
C.labels = {V.label};
cr = arrayfun(@(v) min(v.corner.sf), V);
C.brackets = table({V.label}', arrayfun(@(v) min([v.h.sf]), V)', arrayfun(@(v) min([v.h.sf_flange]), V)', ...
                   [V.sig_steady]', [V.sig_pass]', reshape([V.pass_rz], 2, [])', [V.sig_pass_bound]', ...
                   arrayfun(@(v) max(v.corner.sa_pass), V)', arrayfun(@(v) max(v.corner.sa_mesh), V)', cr', ...
                   'VariableNames', {'bracket', 'sf_shell', 'sf_flange', 'sig_steady', 'sig_pass', 'pass_rz_mm', ...
                                     'sig_pass_bound', 'corner_pass', 'corner_mesh', 'corner_sf'});

    function [sfs, sff, parts] = gmin(sa, sp_, sm)
        % lowest Goodman factor on the shell and at the flange junction (A357 nodes), with the cast-fillet value
        % at each re-entrant corner; parts = [sa_mesh sa_pass sm] where the shell and the flange minima are set
        g_ = gmn(sa, sp_, sm);
        is_ = find(shell);  [sfs, i1] = min(g_(is_));  ps = [sa(is_(i1)), sp_(is_(i1)), sm(is_(i1))];
        if_ = find(fl);  [sff, i2] = min(g_(if_));  pf = [sa(if_(i2)), sp_(if_(i2)), sm(if_(i2))];
        for k_ = 1:size(RC, 1)
            a_ = ann(:, k_);
            if ~any(a_), continue, end
            pk_ = cs.Kt_corner * [max(sa(a_)), max(sp_(a_)), max(sm(a_))];
            gk = gmn(pk_(1), pk_(2), pk_(3));
            if RC(k_, 2) > 20 && gk < sfs, sfs = gk;  ps = pk_; end
            if RC(k_, 2) > 2 && RC(k_, 2) <= 20 && gk < sff, sff = gk;  pf = pk_; end
        end
        parts = [ps; pf];                              % rows: the shell (sf) and the flange junction (sf_flange)
    end
    function u = msolve(h_, a, b, om, zeta)
        % response to a x (unit radial patch load) + b x (unit tangential), modal with the static residual
        g_ = a * h_.gr + b * h_.gt;
        u = zeros(3 * nn, 1);
        u(h_.free) = h_.phi * (g_ ./ (h_.w.^2 - om^2 + 2i * zeta * h_.w * om)) + a * h_.Rr + b * h_.Rt;
    end
    function q = proj(h_, a, b, om, zeta, fam)
        % patch displacement along the line of action (averaged over the patch) for loads a, b of family fam
        g_ = a * h_.gr + b * h_.gt;
        m_ = g_ ./ (h_.w.^2 - om^2 + 2i * zeta * h_.w * om);
        uU = h_.pU * m_ + h_.rU * [a; b];  uV = h_.pV * m_ + h_.rV * [a; b];
        switch fam
            case 0, q = sa_ * uU + ca_ * uV;
            case 1, q = h_.snc * sa_ * uU;               % u_r ~ cos n theta, u_theta ~ sin (odd: no mean)
            case 2, q = -h_.snc * ca_ * uV;              % turned family: u_theta = -V cos n theta
        end
    end
    function Hq = recept(f_, ph_, zeta)
        % ring-seat receptance at planet 0 along the line of action, unit force on all planets with the phases
        Hq = zeros(size(f_));
        for k_ = 1:numel(f_)
            om = 2 * pi * f_(k_);
            for j_ = 1:numel(H)
                n_ = H(j_).n;
                Cn = sum(exp(1i * ph_) .* cos(n_ * psk));  Sn = sum(exp(1i * ph_) .* sin(n_ * psk));
                if n_ == 0
                    Hq(k_) = Hq(k_) + proj(H(j_), sa_ * Cn, ca_ * Cn, om, zeta, 0);
                else
                    Hq(k_) = Hq(k_) + proj(H(j_), sa_ * Cn, ca_ * Sn, om, zeta, 1) + proj(H(j_), sa_ * Sn, -ca_ * Cn, om, zeta, 2);
                end
            end
        end
    end
    function [Fc, Hq, Fp] = coupled(f_, ph_, zeta, TE)
        Hq = recept(f_, ph_, zeta);
        Fp = dy_planet_forces(P, f_);
        Rc = dy_ring_couple(Fp, Hq, TE);  Fc = Rc.Fc;
    end
    function [Fs_max, Fr_max] = planet_forces(f_, ph_, zeta, TE)
        Rc = dy_ring_couple(dy_planet_forces(P, f_), recept(f_, ph_, zeta), TE);
        Fs_max = Rc.Fs_max;  Fr_max = Rc.Fr_max;
    end
    function vmc = stress(f_, Fpl, ph_, zeta)
        % cycle-maximum von Mises over the circle at the boundary nodes [MPa], planet force amplitude Fpl
        om = 2 * pi * f_;
        qr = Fpl * sa_;  qt = Fpl * ca_;
        sr = zeros(numel(th), nb, 6);
        for j_ = 1:numel(H)
            n_ = H(j_).n;
            Cn = sum(exp(1i * ph_) .* cos(n_ * psk));  Sn = sum(exp(1i * ph_) .* sin(n_ * psk));
            if n_ == 0
                sr = addfield(sr, reshape(H(j_).S * msolve(H(j_), qr * Cn, qt * Cn, om, zeta), 6, nb), 0, 'cos');
                continue
            end
            sr = addfield(sr, reshape(H(j_).S * msolve(H(j_), qr * Cn, qt * Sn, om, zeta), 6, nb), n_, 'cos');
            sr = addfield(sr, reshape(H(j_).S * msolve(H(j_), qr * Sn, -qt * Cn, om, zeta), 6, nb), n_, 'turned');
        end
        vmc = dy_vm_cycle(real(sr), imag(sr)) / 1e6;
    end
    function sr = addfield(sr, s1, n_, fam)
        % add the stress amplitudes s1 (6 x nodes) of harmonic n_ over the circle
        if n_ == 0
            for cc = 1:6, sr(:, :, cc) = sr(:, :, cc) + ones(numel(th), 1) * s1(cc, :); end
            return
        end
        c_ = cos(n_ * th)';  s_ = sin(n_ * th)';
        if strcmp(fam, 'cos')
            for cc = 1:4, sr(:, :, cc) = sr(:, :, cc) + c_ * s1(cc, :); end
            for cc = 5:6, sr(:, :, cc) = sr(:, :, cc) + s_ * s1(cc, :); end
        else
            for cc = 1:4, sr(:, :, cc) = sr(:, :, cc) + s_ * s1(cc, :); end
            for cc = 5:6, sr(:, :, cc) = sr(:, :, cc) - c_ * s1(cc, :); end
        end
    end
end

function f = edge_int(A, R, zr)
% nodal integrals of N r dz along the boundary r = R between z = zr(1) and zr(2)
X = A.X;  nn = size(X, 2);  f = zeros(nn, 1);
E = A.E(:, all(abs(reshape(X(1, A.E), size(A.E)) - R) < 1e-9, 1) & ...
           all(reshape(X(2, A.E), size(A.E)) >= zr(1) - 1e-9 & reshape(X(2, A.E), size(A.E)) <= zr(2) + 1e-9, 1));
for e = 1:size(E, 2)
    L = abs(X(2, E(2, e)) - X(2, E(1, e)));
    f(E(:, e)) = f(E(:, e)) + R * L / 6 * [1; 1; 4];
end
end

function f = edge_int_z(A, Z, rr)
% nodal integrals of N r dr along the boundary z = Z between r = rr(1) and rr(2) (Simpson, exact here)
X = A.X;  nn = size(X, 2);  f = zeros(nn, 1);
E = A.E(:, all(abs(reshape(X(2, A.E), size(A.E)) - Z) < 1e-9, 1) & ...
           all(reshape(X(1, A.E), size(A.E)) >= rr(1) - 1e-9 & reshape(X(1, A.E), size(A.E)) <= rr(2) + 1e-9, 1));
for e = 1:size(E, 2)
    ra = X(1, E(1, e));  rb = X(1, E(2, e));  L = abs(rb - ra);
    f(E(:, e)) = f(E(:, e)) + L / 6 * [ra; rb; 2 * (ra + rb)];
end
end

function m = axi_mass(A, rho)
X = A.X;  T = A.T;
v = @(a) X(:, T(a, :));
d1 = v(2) - v(1);  d2 = v(3) - v(1);
ar = abs(d1(1, :) .* d2(2, :) - d1(2, :) .* d2(1, :)) / 2;
rc = (X(1, T(1, :)) + X(1, T(2, :)) + X(1, T(3, :))) / 3;
m = 2 * pi * sum(rho .* ar .* rc);
end

function [A, pairs] = split_seat(A, inr, rs, zs)
% give the ring elements their own copies of the nodes they share with the case on r = rs, zs(1) <= z <= zs(2);
% pairs = [case node, ring node]; boundary edges recomputed
X = A.X;  nn = size(X, 2);  T = A.T;
on = find(abs(X(1, :) - rs) < 1e-9 & X(2, :) >= zs(1) - 1e-9 & X(2, :) <= zs(2) + 1e-9);
Tr = T(:, inr);  Tc = T(:, ~inr);
on = on(ismember(on, Tr(:)) & ismember(on, Tc(:)));
nw = nn + (1:numel(on));
map = 1:nn;  map(on) = nw;
T(:, inr) = map(T(:, inr));
A.X = [X, X(:, on)];  A.T = T;
ed = [T([1 2 4], :), T([2 3 5], :), T([3 1 6], :)];
[~, ia, ic] = unique(sort(ed(1:2, :), 1)', 'rows');
A.E = ed(:, ia(accumarray(ic, 1) == 1));
pairs = [on(:), nw(:)];
end

function RC = reentrant(sec)
% re-entrant corners (interior angle above 200 deg) of the section, a union of rectangles [r1 r2 z1 z2] and polygons
% [r z] [mm]: the vertices of the union with more than 200 / 360 of a small circle inside
ps = polyshape();
for k = 1:numel(sec)
    s_ = sec{k};
    if numel(s_) == 4, s_ = [s_(1) s_(3); s_(2) s_(3); s_(2) s_(4); s_(1) s_(4)]; end
    ps = union(ps, polyshape(s_(:, 1), s_(:, 2)));
end
Vx = ps.Vertices;  Vx = unique(Vx(all(isfinite(Vx), 2), :), 'rows');
a = (0:35)' * 2 * pi / 36;  d = 0.05;
RC = zeros(0, 2);
for k = 1:size(Vx, 1)
    q = Vx(k, :) + d * [cos(a), sin(a)];
    if mean(isinterior(ps, q(:, 1), q(:, 2))) > 200 / 360, RC(end + 1, :) = Vx(k, :); end %#ok<AGROW>
end
end
