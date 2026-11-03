function R = rotor_model(in, sup)
%ROTOR_MODEL  Finite element model of the propeller shaft with its carrier, propeller and supports.
%   R = rotor_model(in, sup)
%
%   Inputs
%     in    damper_inputs: shaft, stub, span, overhang, el, carrier, prop;
%           optional shaft_over (d_o, d_i of the overhang if it differs
%           from the span) and flange (m, Id, Ip added to the propeller)
%     sup   struct array, one element per support: inner bearing, outer
%           bearing, then any extra support. Field n (optional) is the
%           shaft node; without it the first two sit at the inner and outer
%           bearing. Field type:
%           'direct'  bearing straight to ground (the Phase 1 model):
%                     kxx, kyy [N/m], cxx, cyy [N s/m]
%           'chain'   shaft - rolling bearing k_b - damper journal (mass m_j) -
%                     centring spring k_sc in parallel with the squeeze film
%                     c_sfd - housing (mass m_h) - ground through khx, khy
%                     with dampers chx, chy. Units N/m, N s/m, kg.
%
%   Output struct R
%     M, C, G, K   global matrices of M q'' + (C + Omega G) q' + K q = F;
%                  C holds the support damping, G the gyroscopic terms
%     z            axial position of the shaft nodes, inner bearing at 0 [m]
%     n_car, n_in, n_out, n_prop   node numbers of carrier, bearings, propeller
%     bn           shaft node of each support
%     ix, iy, ipx, ipy   DOF numbers of x, y, dx/dz, dy/dz at each shaft node
%     jx, jy, hx, hy     DOF numbers of the journal and housing nodes of each
%                  chain support (empty for direct supports)
%     el           element list: node numbers and beam_timoshenko matrices
%
%   Each shaft node has four DOFs (x, dx/dz, y, dy/dz); bending in the xz
%   and yz planes uses the planar element of beam_timoshenko. The spin
%   Omega is about +z, from +x to +y, and its kinetic energy
%   Ip Omega theta_x' theta_y with theta_y = dx/dz and theta_x = -dy/dz
%   gives the gyroscopic coupling G(phi_x, phi_y) = +MJ, G(phi_y, phi_x) = -MJ.
%   Discs are lumped at nodes: mass m, diametral inertia Id, polar Ip.
%
%   Source: Phase 2 report, Section 2.1 ("Model"). Tested by test_step21
%   (TC18-TC21).

% Shaft nodes: carrier stub, span and overhang split into elements of about in.el
ns = max(1, round(in.span / in.el));
no = max(1, round(in.overhang / in.el));
L = [in.stub, repmat(in.span / ns, 1, ns), repmat(in.overhang / no, 1, no)];
z = [0, cumsum(L)] - in.stub;
nn = numel(z);
R.z = z;
R.n_car = 1;
R.n_in = 2;
R.n_out = 2 + ns;
R.n_prop = nn;

% DOF numbering: shaft nodes first, then two DOFs per extra support node
R.ix = 4 * (1:nn) - 3;
R.ipx = 4 * (1:nn) - 2;
R.iy = 4 * (1:nn) - 1;
R.ipy = 4 * (1:nn);
nd = 4 * nn;
for b = 1:numel(sup)
    if strcmp(sup(b).type, 'chain')
        R.jx(b) = nd + 1;  R.jy(b) = nd + 2;  R.hx(b) = nd + 3;  R.hy(b) = nd + 4;
        nd = nd + 4;
    else
        R.jx(b) = 0;  R.jy(b) = 0;  R.hx(b) = 0;  R.hy(b) = 0;
    end
end
M = zeros(nd);  K = zeros(nd);  C = zeros(nd);  G = zeros(nd);

% Shaft elements. The stub and span use in.shaft, the overhang in.shaft_over if it is given.
mat = struct('E', in.shaft.E, 'nu', in.shaft.nu, 'rho', in.shaft.rho);
d_o = repmat(in.shaft.d_o, 1, numel(L));
d_i = repmat(in.shaft.d_i, 1, numel(L));
if isfield(in, 'shaft_over') && ~isempty(in.shaft_over)
    d_o(end - no + 1:end) = in.shaft_over.d_o;
    d_i(end - no + 1:end) = in.shaft_over.d_i;
end
for k = 1:numel(L)
    e = beam_timoshenko(L(k), d_o(k), d_i(k), mat);
    px = [R.ix(k), R.ipx(k), R.ix(k + 1), R.ipx(k + 1)];   % xz plane: x, dx/dz
    py = [R.iy(k), R.ipy(k), R.iy(k + 1), R.ipy(k + 1)];   % yz plane: y, dy/dz
    K(px, px) = K(px, px) + e.K;
    K(py, py) = K(py, py) + e.K;
    M(px, px) = M(px, px) + e.Mt + e.Mr;
    M(py, py) = M(py, py) + e.Mt + e.Mr;
    G(px, py) = G(px, py) + e.MJ;
    G(py, px) = G(py, px) - e.MJ;
    R.el(k) = struct('n', [k, k + 1], 'L', L(k), 'e', e);
end

% Discs: carrier at the stub end, propeller (with the shaft flange, if given) at the shaft end
m_fl = 0;  Id_fl = 0;  Ip_fl = 0;
if isfield(in, 'flange') && ~isempty(in.flange)
    m_fl = in.flange.m;  Id_fl = in.flange.Id;  Ip_fl = in.flange.Ip;
end
discs = [struct('n', R.n_car, 'm', in.carrier.m, 'Id', in.carrier.Id, 'Ip', in.carrier.Ip), ...
         struct('n', R.n_prop, 'm', in.prop.m + m_fl, 'Id', in.prop.Id + Id_fl, 'Ip', in.prop.Ip + Ip_fl)];
for d = discs
    M(R.ix(d.n), R.ix(d.n)) = M(R.ix(d.n), R.ix(d.n)) + d.m;
    M(R.iy(d.n), R.iy(d.n)) = M(R.iy(d.n), R.iy(d.n)) + d.m;
    M(R.ipx(d.n), R.ipx(d.n)) = M(R.ipx(d.n), R.ipx(d.n)) + d.Id;
    M(R.ipy(d.n), R.ipy(d.n)) = M(R.ipy(d.n), R.ipy(d.n)) + d.Id;
    G(R.ipx(d.n), R.ipy(d.n)) = G(R.ipx(d.n), R.ipy(d.n)) + d.Ip;
    G(R.ipy(d.n), R.ipx(d.n)) = G(R.ipy(d.n), R.ipx(d.n)) - d.Ip;
end

% Supports
bn = zeros(1, numel(sup));
for b = 1:numel(sup)
    if isfield(sup, 'n') && ~isempty(sup(b).n)
        bn(b) = sup(b).n;
    elseif b <= 2
        bn(b) = R.n_in * (b == 1) + R.n_out * (b == 2);
    else
        error('rotor_model: support %d needs a node number n', b);
    end
end
R.bn = bn;
for b = 1:numel(sup)
    s = sup(b);
    sx = R.ix(bn(b));
    sy = R.iy(bn(b));
    if strcmp(s.type, 'direct')
        K(sx, sx) = K(sx, sx) + s.kxx;  K(sy, sy) = K(sy, sy) + s.kyy;
        C(sx, sx) = C(sx, sx) + s.cxx;  C(sy, sy) = C(sy, sy) + s.cyy;
    else
        jx = R.jx(b);  jy = R.jy(b);  hx = R.hx(b);  hy = R.hy(b);
        [K, C] = link(K, C, sx, jx, s.k_b, 0);         % rolling bearing
        [K, C] = link(K, C, sy, jy, s.k_b, 0);
        [K, C] = link(K, C, jx, hx, s.k_sc, s.c_sfd);  % centring spring and squeeze film
        [K, C] = link(K, C, jy, hy, s.k_sc, s.c_sfd);
        K(hx, hx) = K(hx, hx) + s.khx;  C(hx, hx) = C(hx, hx) + s.chx;   % housing to ground
        K(hy, hy) = K(hy, hy) + s.khy;  C(hy, hy) = C(hy, hy) + s.chy;
        M(jx, jx) = M(jx, jx) + s.m_j;  M(jy, jy) = M(jy, jy) + s.m_j;
        M(hx, hx) = M(hx, hx) + s.m_h;  M(hy, hy) = M(hy, hy) + s.m_h;
    end
end
R.M = M;  R.K = K;  R.C = C;  R.G = G;
R.ndof = nd;
R.sup = sup;
end

function [K, C] = link(K, C, a, b, k, c)
% Spring k and damper c between DOFs a and b
K([a b], [a b]) = K([a b], [a b]) + k * [1 -1; -1 1];
C([a b], [a b]) = C([a b], [a b]) + c * [1 -1; -1 1];
end
