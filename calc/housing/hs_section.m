function [P, cut, C, Q0] = hs_section(sec, rf, win, d_max)
%HS_SECTION  Outline of an axisymmetric section with cast fillets, optionally clipped to a window.
%   [P, cut, C, Q0] = hs_section(sec, rf, win, d_max)
%
%   sec: the pieces of the section [mm] (rectangles and polygons, hs_poly).
%   rf: fillet radius [mm] at every re-entrant corner (0: sharp); a fillet
%   takes at most 45 % of either edge at its corner. win: [r1 r2 z1 z2]
%   [mm] window the section is clipped to ([] = whole section). d_max: the
%   longest outline edge [mm].
%
%   Output P: outline, clockwise in (r, z) like hs_revolve [mm]; cut: true
%   for each edge P(i) -> P(i+1) that the window cut through material (the
%   cut faces of a submodel); C: re-entrant corners of the unclipped
%   section, rows [r z cr cz R t1r t1z t2r t2z] (corner, fillet centre,
%   fillet radius, its two tangent points: t1 on the edge before the corner
%   and t2 on the edge after it, going counter-clockwise); Q0: the sharp
%   outline of the unclipped section, counter-clockwise, one row per corner
%   (for the CAD profile, calc/cad_export).
%   Source: Phase 2 report, Section 2.8 ("Verification"). Used by
%   hs_submodel.

ps = hs_poly(sec);
[x, y] = boundary(ps);
Q = drop_collinear([x(1:end - 1), y(1:end - 1)]);
if area2(Q) < 0, Q = flipud(Q); end                        % counter-clockwise: material on the left
Q0 = Q;
n = size(Q, 1);
C = zeros(0, 9);
for i = 1:n
    v = Q(i, :);  a = Q(mod(i - 2, n) + 1, :);  b = Q(mod(i, n) + 1, :);
    d1 = (v - a) / norm(v - a);  d2 = (b - v) / norm(b - v);
    if d1(1) * d2(2) - d1(2) * d2(1) >= 0, continue, end  % left turn: not re-entrant
    e1 = -d1;  e2 = d2;                                    % the two edges, the open wedge between them
    al = acos(max(-1, min(1, e1 * e2')));
    R = min(rf, 0.45 * min(norm(v - a), norm(b - v)) * tan(al / 2));
    bis = (e1 + e2) / norm(e1 + e2);
    C(end + 1, :) = [v, v + R / sin(al / 2) * bis, R, v + R / tan(al / 2) * e1, v + R / tan(al / 2) * e2]; %#ok<AGROW>
end
for i = 1:size(C, 1)
    R = C(i, 5);
    if R <= 0, continue, end
    c = C(i, 3:4);  t1 = C(i, 6:7);  t2 = C(i, 8:9);
    a1 = atan2(t1(2) - c(2), t1(1) - c(1));
    da = angle(exp(1i * (atan2(t2(2) - c(2), t2(1) - c(1)) - a1)));
    ph = a1 + da * linspace(0, 1, max(4, ceil(abs(da) / (pi / 24))) + 1)';
    ps = union(ps, polyshape([C(i, 1:2); c + R * [cos(ph), sin(ph)]]));
end
full = ps;
if ~isempty(win)
    ps = intersect(ps, polyshape(win([1 2 2 1]), win([3 3 4 4])));
end
if ps.NumRegions ~= 1 || ps.NumHoles ~= 0
    error('hs_section:region', 'the section must be one region without holes');
end
[x, y] = boundary(ps);
Q = drop_collinear([x(1:end - 1), y(1:end - 1)]);
if area2(Q) > 0, Q = flipud(Q); end                        % clockwise, as hs_revolve
P = [];  cut = false(0, 1);
nrm = [-1 0; 1 0; 0 -1; 0 1];
for j = 1:size(Q, 1)
    p1 = Q(j, :);  p2 = Q(mod(j, size(Q, 1)) + 1, :);
    m = max(1, ceil(norm(p2 - p1) / d_max));
    P = [P; p1 + (0:m - 1)' / m * (p2 - p1)]; %#ok<AGROW>
    iscut = false;
    if ~isempty(win)
        mid = (p1 + p2) / 2;
        on = [abs(mid(1) - win(1:2)), abs(mid(2) - win(3:4))] < 1e-6;
        if any(on) && (p1(1) == p2(1) || p1(2) == p2(2))
            q = mid + 0.05 * nrm(find(on, 1), :);         % just outside the window
            iscut = isinterior(full, q(1), q(2));
        end
    end
    cut = [cut; repmat(iscut, m, 1)]; %#ok<AGROW>
end
end

function A = area2(Q)
A = 0.5 * sum(Q(:, 1) .* Q([2:end 1], 2) - Q([2:end 1], 1) .* Q(:, 2));
end

function Q = drop_collinear(Q)
k = true(size(Q, 1), 1);
for i = 1:size(Q, 1)
    a = Q(mod(i - 2, size(Q, 1)) + 1, :);  b = Q(i, :);  c = Q(mod(i, size(Q, 1)) + 1, :);
    u = b - a;  w = c - b;
    if abs(u(1) * w(2) - u(2) * w(1)) < 1e-9 * norm(u) * norm(w)
        k(i) = false;
    end
end
Q = Q(k, :);
end
