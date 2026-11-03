function s = sb_spline(sp, T, KA, T_lim, d_i, in)
%SB_SPLINE  Tooth shear, flank pressure and root torsion of an involute spline (Dudley form).
%   s = sb_spline(sp, T, KA, T_lim, d_i, in)
%
%   Inputs
%     sp      spline (sb_inputs.spl): module m, teeth z, engaged length L
%             [mm], load distribution factor Km, crowned flag
%     T, KA   torque in continuous running [N m] and application factor
%     T_lim   torque at limit load (LD-08)                              [N m]
%     d_i     bore of the external member                               [mm]
%     in      sb_inputs (shaft material, allowables)
%
%   Output struct s: D (pitch diameter), t (tooth thickness), h (active
%   depth) [mm]; tau (tooth shear at the pitch line), p (mean flank
%   pressure), tau_root (torsion at the root of the external spline),
%   tau_lim, p_lim (at T_lim) [MPa]; safety factors S_fat (0.25 su /
%   tau), S_static (0.577 sy / tau_lim) and the flank pressure ratio
%   p / allowable [-].
%
%   ISO 4156 30 deg flat root: D = m z, t = pi D / (2 z), active depth
%   0.9 m, external root diameter m (z - 1.5). Dudley's spline formulae
%   take only half the teeth as carrying load: tau = 4 T Km KA / (D z L t),
%   p = 2 T Km KA / (D z L h). The flank pressure limits (oil-fed, case
%   hardened, fixed or crowned) are design practice values, TBR until the
%   Phase 3 spline wear tests. Source: Phase 2 report, Section 2.5
%   ("Splines"). Tested by test_step25 (TC43).

D = sp.m * sp.z;
t = pi * D / (2 * sp.z);
h = 0.9 * sp.m;
Dre = sp.m * (sp.z - 1.5);
f_tau = @(TT, K) 4 * TT * 1e3 * sp.Km * K / (D * sp.z * sp.L * t);
f_p = @(TT, K) 2 * TT * 1e3 * sp.Km * K / (D * sp.z * sp.L * h);
tau = f_tau(T, KA);
p = f_p(T, KA);
tau_root = 16 * T * KA * 1e3 * Dre / (pi * (Dre^4 - d_i^4));
tau_lim = f_tau(T_lim, 1);
p_lim = f_p(T_lim, 1);
p_allow = in.spl_pc_lim(1 + sp.crowned);
s = struct('D', D, 't', t, 'h', h, 'Dre', Dre, 'tau', tau, 'p', p, 'tau_root', tau_root, ...
           'tau_lim', tau_lim, 'p_lim', p_lim, 'S_fat', in.spl_tau_fat * in.sh_mat.su / tau, ...
           'S_static', 0.577 * in.sh_mat.sy / tau_lim, 'p_ratio', p / p_allow, 'p_allow', p_allow);
end
