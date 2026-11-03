function H = st_khb(gi, twist_um, k)
%ST_KHB  Back-check of K_Hbeta of the planet-ring mesh with the case twist of the 3-D model (step 3.5).
%   H = st_khb(gi, twist_um)
%   H = st_khb(gi, twist_um, k)      mesh k of gd_meshes (default 3, planet-ring; 1 = first stage)
%
%   gi = gd_inputs; twist_um = tangential displacement difference of the
%   ring seat over the 70 mm face width at maximum continuous torque
%   (st_case3d). The step 2.4 rating took the ring as rigid in the case; the
%   twist is added in full to the manufacturing misalignment f_ma of the
%   planet-ring mesh (conservative: the helix correction of step 2.4 is
%   not re-optimised) and the mesh is rated again at maximum continuous
%   torque with K_gamma P99 (gd_rate, the tested step 2.4 tool).
%   Output H: f_ma [um] before and after, K_Hbeta, sigma_H [MPa] and S_H
%   (planet and ring) before and after.
%   Source: Phase 3 report, Section 3.5 ("K_Hbeta back-check").

if nargin < 3, k = 3; end
M = gd_meshes(gi);
ref = struct('KA', gi.KA, 'mode', 'ref', 'oil', gi.oil(1), 'ZNT10', gi.ZNT_ref, 'fpb_share', gi.fpb_share);
r0 = arrayfun(@(k) gd_rate(setfield(M(k), 'Kgam', 1), M(k).T1, M(k).n1, ref), 2:3);
ls = gd_loadshare(M(2), M(3), M(2).Ts, r0(1).c_ga * M(2).g.b, r0(2).c_ga * M(3).g.b, gi);
m3 = M(k);
if k > 1, m3.Kgam = ls.Kgam_p99; end
a = gd_rate(m3, m3.T1, m3.n1, ref);
m3b = m3;  m3b.f_ma = m3.f_ma + twist_um;
b = gd_rate(m3b, m3b.T1, m3b.n1, ref);
H = struct('f_ma', [m3.f_ma m3b.f_ma], 'KHb', [a.KHb b.KHb], 'sigma_H', [a.sigma_H1 b.sigma_H1], ...
           'S_H1', [a.S_H1 b.S_H1], 'S_H2', [a.S_H2 b.S_H2]);
end
