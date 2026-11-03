function [sa, smax] = dy_pass_amp(Sp)
%DY_PASS_AMP  Alternating von Mises amplitude of a stress state that sweeps a closed path (the planets passing a case node).
%   [sa, smax] = dy_pass_amp(Sp)
%
%   Sp: stress states along the path, points x nodes x 6 [xx yy zz xy yz xz]
%   (e.g. one planet-pass period of the n = 4, 8, ... field over the circle,
%   which a rotating load pattern carries past a fixed node). The amplitude
%   is half the longest chord: sa = max over points i, j of vm((S_i - S_j) / 2),
%   one per node. smax = max over the points of vm(S_i), a bound (sa <= smax).
%   Source: Phase 3 report, Section 3.6 ("Planetary case").

np = size(Sp, 1);  nb = size(Sp, 2);
sa = zeros(nb, 1);
for i = 1:np - 1
    D = (Sp(i, :, :) - Sp(i + 1:end, :, :)) / 2;
    sa = max(sa, max(vm(D), [], 1)');
end
smax = max(vm(Sp), [], 1)';
end

function v = vm(S)
s = @(k) S(:, :, k);
v = sqrt(max(0.5 * ((s(1) - s(2)).^2 + (s(2) - s(3)).^2 + (s(3) - s(1)).^2) + 3 * (s(4).^2 + s(5).^2 + s(6).^2), 0));
end
