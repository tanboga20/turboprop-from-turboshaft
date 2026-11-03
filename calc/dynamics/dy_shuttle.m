function D = dy_shuttle(g, n_phase)
%DY_SHUTTLE  Axial shuttle of the contact-line centroid of a helical mesh over one mesh cycle.
%   D = dy_shuttle(g)
%   D = dy_shuttle(g, n_phase)
%
%   g = a gd_meshes geometry (b [mm], beta_b [rad], p_et, g_alpha [mm]).
%   In the plane of action (x along the path of contact, 0 ... g_alpha; z
%   across the face, 0 ... b) the contact lines are the lines x - z tan
%   beta_b = c0 + k p_et. With the load spread evenly along the lines
%   (crowned to a uniform load, TBR), the line load acts at the length-
%   weighted axial centroid z_c(c0), which moves at mesh frequency as the
%   lines run across the face. Output D: z_c over n_phase (default 720)
%   phases of a mesh cycle [mm], the total contact length L [mm] and the
%   amplitudes of the 1st and 2nd mesh harmonics of z_c, dZ = [dZ1 dZ2] [mm].
%   Source: Phase 3 report, Section 3.6 ("Excitation").

if nargin < 2, n_phase = 720; end
t = tan(g.beta_b);
c0 = (0:n_phase - 1) / n_phase * g.p_et;
zc = zeros(size(c0));  L = zc;
for i = 1:n_phase
    k = floor((-g.b * t - c0(i)) / g.p_et):ceil((g.g_alpha - c0(i)) / g.p_et);
    c = c0(i) + k * g.p_et;
    z1 = max(0, -c / t);  z2 = min(g.b, (g.g_alpha - c) / t);
    dz = max(z2 - z1, 0);
    L(i) = sum(dz) / cos(g.beta_b);
    zc(i) = sum(dz .* (z1 + z2) / 2) / sum(dz);
end
Z = fft(zc) / n_phase;
D = struct('c0', c0, 'zc', zc, 'L', L, 'dZ', 2 * abs(Z(2:3)), 'zc_mean', real(Z(1)));
end
