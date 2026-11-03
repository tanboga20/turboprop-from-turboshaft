function ub = rotor_unbalance(R, rpm, node, U)
%ROTOR_UNBALANCE  Steady unbalance response of the rotor over speed.
%   ub = rotor_unbalance(R, rpm, node, U)
%
%   Inputs
%     R      rotor_model output
%     rpm    shaft speeds                                              [rpm]
%     node   shaft node that carries the unbalance                     [-]
%     U      unbalance, mass x eccentricity                            [kg m]
%
%   Output struct ub
%     rpm        the speeds                                            [rpm]
%     a          major semi-axis of the orbit at every shaft node,
%                numel(rpm) x number of nodes                          [m]
%     a_node     major semi-axis at the unbalance node                 [m]
%     a_jour     major semi-axis of the damper journal relative to the
%                housing at each chain support (orbit inside the film) [m]
%     sigma_alt  largest alternating bending stress in the shaft       [Pa]
%     sigma_ss   largest steady bending stress (forward whirl part)    [Pa]
%     F_brg      largest force through each support's rolling bearing  [N]
%     Q          complex DOF amplitudes, ndof x numel(rpm)             [m, rad]
%
%   The unbalance force U Omega^2 (cos Omega t, sin Omega t) turns with the
%   shaft. With x = Re(X e^(i Omega t)) and y = Re(Y e^(i Omega t)) the
%   orbit splits into a forward circle of radius |X + iY| / 2 and a backward
%   one of radius |X - iY| / 2; the major semi-axis is their sum. In the
%   shaft, which turns with the forward circle, the forward part of the
%   bending moment is steady and the backward part alternates at
%   2 Omega; sigma = M (d_o / 2) / I.
%
%   Source: Phase 2 report, Section 2.1 ("Model"). Tested by test_step21
%   (TC21).

n = R.ndof;
nn = numel(R.z);
Q = zeros(n, numel(rpm));
a = zeros(numel(rpm), nn);
nb = numel(R.sup);
a_jour = nan(numel(rpm), nb);
F_brg = zeros(numel(rpm), nb);
sigma_alt = zeros(numel(rpm), 1);
sigma_ss = zeros(numel(rpm), 1);
bn = R.bn;
for s = 1:numel(rpm)
    W = rpm(s) * pi / 30;
    F = zeros(n, 1);
    F(R.ix(node)) = U * W^2;
    F(R.iy(node)) = -1i * U * W^2;
    q = (R.K - W^2 * R.M + 1i * W * (R.C + W * R.G)) \ F;
    Q(:, s) = q;
    X = q(R.ix);  Y = q(R.iy);
    a(s, :) = (abs(X + 1i * Y) + abs(X - 1i * Y)).' / 2;
    for b = 1:nb
        if strcmp(R.sup(b).type, 'chain')
            dx = q(R.jx(b)) - q(R.hx(b));
            dy = q(R.jy(b)) - q(R.hy(b));
            a_jour(s, b) = (abs(dx + 1i * dy) + abs(dx - 1i * dy)) / 2;
            fx = R.sup(b).k_b * (q(R.ix(bn(b))) - q(R.jx(b)));
            fy = R.sup(b).k_b * (q(R.iy(bn(b))) - q(R.jy(b)));
        else
            fx = (R.sup(b).kxx + 1i * W * R.sup(b).cxx) * q(R.ix(bn(b)));
            fy = (R.sup(b).kyy + 1i * W * R.sup(b).cyy) * q(R.iy(bn(b)));
        end
        F_brg(s, b) = (abs(fx + 1i * fy) + abs(fx - 1i * fy)) / 2;
    end
    % Bending moments at both ends of every element, in both planes
    for k = 1:numel(R.el)
        el = R.el(k);
        px = [R.ix(el.n(1)), R.ipx(el.n(1)), R.ix(el.n(2)), R.ipx(el.n(2))];
        py = [R.iy(el.n(1)), R.ipy(el.n(1)), R.iy(el.n(2)), R.ipy(el.n(2))];
        fxz = el.e.K * q(px);
        fyz = el.e.K * q(py);
        c = el.e.d_o / 2 / el.e.I;           % outer fibre: sigma = M c
        for e = [2 4]
            Mx = fxz(e);  My = fyz(e);
            sigma_ss(s) = max(sigma_ss(s), abs(Mx + 1i * My) / 2 * c);
            sigma_alt(s) = max(sigma_alt(s), abs(Mx - 1i * My) / 2 * c);
        end
    end
end
ub = struct('rpm', rpm(:), 'a', a, 'a_node', a(:, node), 'a_jour', a_jour, ...
            'sigma_alt', sigma_alt, 'sigma_ss', sigma_ss, 'F_brg', F_brg, 'Q', Q);
end
