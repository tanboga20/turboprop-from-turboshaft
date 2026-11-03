function p = annular_plate(a, b, t, E, nu)
%ANNULAR_PLATE  Flat annular diaphragm clamped at both edges: axial and tilt stiffness and stresses.
%   p = annular_plate(a, b, t, E, nu)
%
%   Inputs
%     a, b    outer (rim) and inner (hub) radius                        [m]
%     t       thickness                                                 [m]
%     E, nu   Young's modulus and Poisson's ratio                       [Pa, -]
%
%   Output struct p
%     k_ax      axial stiffness: hub pushed axially, both edges kept
%               perpendicular to the axis                                [N/m]
%     s_ax      largest radial bending stress per metre of axial offset  [Pa/m]
%     k_th      angular stiffness: hub tilted as a rigid body            [N m/rad]
%     s_th      largest radial bending stress per radian of tilt         [Pa/rad]
%
%   Kirchhoff plate theory, D = E t^3 / (12 (1 - nu^2)).
%   Axial offset (axisymmetric): w = A1 + A2 r^2 + A3 ln r + A4 r^2 ln r with
%   w = w' = 0 at r = a, w' = 0 at r = b and the hub load P giving
%   A4 = -P / (8 pi D); k_ax = P / w(b).
%   Tilt (first harmonic): w = W(r) cos(phi), W = B1 r + B2 r^3 + B3 / r +
%   B4 r ln r with W = W' = 0 at r = a and W = theta b, W' = theta at r = b;
%   k_th = 2 U / theta^2 from the bending energy U, integrated numerically.
%   Stresses: sigma_r = 6 M_r / t^2 with M_r = -D (w'' + nu w' / r) for the
%   axial case and -D (W'' + nu (W' / r - W / r^2)) for the tilt case, the
%   largest value at either edge.
%
%   Source: Phase 2 report, Section 2.2 ("Diaphragm couplings"); Timoshenko
%   and Woinowsky-Krieger, Theory of Plates and Shells (1959), Sections 17
%   and 31. Tested by test_step22 (TC25).

D = E * t^3 / (12 * (1 - nu^2));

% Axial offset: unit hub load P = 1 N
P = 1;
A4 = -P / (8 * pi * D);
% unknowns A1, A2, A3: w(a) = 0, w'(a) = 0, w'(b) = 0
wf  = @(r) [1, r^2, log(r)];                 % coefficients of A1..A3 in w
dwf = @(r) [0, 2 * r, 1 / r];                % in w'
w4  = @(r) r^2 * log(r);
dw4 = @(r) 2 * r * log(r) + r;
Mx = [wf(a); dwf(a); dwf(b)];
rhs = -A4 * [w4(a); dw4(a); dw4(b)];
c = Mx \ rhs;
w = @(r) wf(r) * c + A4 * w4(r);
d2w = @(r) 2 * c(2) - c(3) / r^2 + A4 * (2 * log(r) + 3);
dw = @(r) dwf(r) * c + A4 * dw4(r);
delta = abs(w(b) - w(a));
p.k_ax = P / delta;
Mr = @(r) -D * (d2w(r) + nu * dw(r) / r);
p.s_ax = max(abs([Mr(a), Mr(b)])) * 6 / t^2 / delta;

% Tilt: unit tilt theta = 1 rad
th = 1;
Wf   = @(r) [r, r^3, 1 / r, r * log(r)];
dWf  = @(r) [1, 3 * r^2, -1 / r^2, log(r) + 1];
d2Wf = @(r) [0, 6 * r, 2 / r^3, 1 / r];
B = [Wf(a); dWf(a); Wf(b); dWf(b)] \ [0; 0; th * b; th];
W = @(r) Wf(r) * B;
dW = @(r) dWf(r) * B;
d2W = @(r) d2Wf(r) * B;
MrT = @(r) -D * (d2W(r) + nu * (dW(r) / r - W(r) / r^2));
p.s_th = max(abs([MrT(a), MrT(b)])) * 6 / t^2 / th;
rr = linspace(b, a, 2001);
f = zeros(size(rr));
for k = 1:numel(rr)
    r = rr(k);
    q = dW(r) / r - W(r) / r^2;
    lap = d2W(r) + q;                         % Laplacian amplitude of the first harmonic
    f(k) = (lap^2 - 2 * (1 - nu) * (d2W(r) * q - q^2)) * r;
end
U = D / 2 * pi * trapz(rr, f);
p.k_th = 2 * U / th^2;
end
