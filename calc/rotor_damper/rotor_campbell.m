function cb = rotor_campbell(R, rpm, nmodes)
%ROTOR_CAMPBELL  Damped natural frequencies and whirl directions over speed.
%   cb = rotor_campbell(R, rpm, nmodes)
%
%   Inputs
%     R        rotor_model output
%     rpm      shaft speeds                                            [rpm]
%     nmodes   number of modes kept at each speed, lowest first        [-]
%
%   Output struct cb
%     rpm      the speeds                                              [rpm]
%     f        damped natural frequencies, numel(rpm) x nmodes          [cpm]
%     zeta     damping ratios                                          [-]
%     whirl    1 forward, -1 backward, 0 mixed (the shaft nodes do not
%              all whirl the same way)                                  [-]
%     cross    rows [mode, speed, whirl] where a mode crosses 1 x running
%              speed, by linear interpolation                          [-, rpm, -]
%
%   State space x = [q; q'], A = [0 I; -M\K -M\(C + Omega G)]; the modes
%   are the eigenvalues with a positive imaginary part (underdamped).
%   Whirl: at a shaft node with complex amplitudes X, Y of x and y, the
%   orbit is forward (with the spin, +x to +y) when imag(conj(X) Y) < 0.
%   The mode's whirl value is -2 sum(imag(conj(X) Y)) / sum(|X|^2 + |Y|^2)
%   over the shaft nodes: +1 for a circular forward orbit everywhere, -1
%   for a backward one, 0 for straight-line orbits. Values within +-0.05
%   of zero count as mixed; anisotropic supports make the orbits elliptic,
%   so the value drops below 1 without changing sign.
%
%   Source: Phase 2 report, Section 2.1 ("Model"). Tested by test_step21
%   (TC19, TC20).

n = R.ndof;
Minv = R.M \ eye(n);
f = nan(numel(rpm), nmodes);
zeta = f;
whirl = zeros(numel(rpm), nmodes);
for s = 1:numel(rpm)
    W = rpm(s) * pi / 30;
    A = [zeros(n), eye(n); -Minv * R.K, -Minv * (R.C + W * R.G)];
    [V, D] = eig(A);
    lam = diag(D);
    keep = find(imag(lam) > 1e-6 * max(1, abs(lam)));
    [~, o] = sort(imag(lam(keep)));
    keep = keep(o);
    for j = 1:min(nmodes, numel(keep))
        l = lam(keep(j));
        f(s, j) = imag(l) * 30 / pi;
        zeta(s, j) = -real(l) / abs(l);
        whirl(s, j) = whirl_dir(V(1:n, keep(j)), R);
    end
end

% 1 x crossings
cross = zeros(0, 3);
for j = 1:nmodes
    d = f(:, j) - rpm(:);
    for s = 1:numel(rpm) - 1
        if ~isnan(d(s)) && ~isnan(d(s + 1)) && (d(s) == 0 || d(s) * d(s + 1) < 0)
            x = rpm(s) + (rpm(s + 1) - rpm(s)) * d(s) / (d(s) - d(s + 1));
            cross(end + 1, :) = [j, x, whirl(s, j)]; %#ok<AGROW>
        end
    end
end
cb = struct('rpm', rpm(:), 'f', f, 'zeta', zeta, 'whirl', whirl, 'cross', cross);
end

function w = whirl_dir(v, R)
% +1 forward, -1 backward, 0 mixed, from the shaft node orbits of mode shape v
X = v(R.ix);
Y = v(R.iy);
val = -2 * sum(imag(conj(X) .* Y)) / sum(abs(X).^2 + abs(Y).^2);
w = sign(val) * (abs(val) > 0.05);
end
