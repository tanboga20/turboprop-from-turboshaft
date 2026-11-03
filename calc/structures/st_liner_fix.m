function X = st_liner_fix(in, k3)
%ST_LINER_FIX  Two fixes for the NU1024 seat liner whose A357 boss is at a yield safety of about 1.07 at -40 degC.
%   X = st_liner_fix(in, k3)
%
%   in = st_inputs; k3 = ratio of the 3-D von Mises stress at the boss to the
%   Lame value (st_case3d K.sig_liner over st_liners sig_vm_cold), which
%   carries the 3-D shape of the bosses into the ring formulas. Target: the
%   A357 at a yield safety of at least in.n_liner_min with the casting
%   factor at -40 degC, i.e. a Lame stress of sy / (1.25 n k3).
%   Fix 1, thicker boss: the boss outer radius that meets the target with
%   the fit still sized to hold at 149 degC (the interference follows the
%   boss), and the added A357 mass of both propeller bearing bosses over
%   their lengths in.boss_L.
%   Fix 2, lower hold temperature: the highest temperature to which the fit
%   can hold (contact pressure p_req) with the present boss; above it the
%   outer ring is held by an anti-rotation pin and the axial clamp alone.
%   Output X: target_lame [MPa], r_boss [mm], dm_kg, n_3d (at r_boss),
%   T_hold [degC], n_3d_hold, d20_um for both fixes.
%   Source: Phase 3 report, Section 3.5 ("Seat liners").

al = in.al;  st = in.st;  l = in.liner(1);
ri = l.r_i;  rm = ri + l.t;  rb0 = l.r_boss;
X.target_lame = al.sy / (in.k_cast * in.n_liner_min * k3);
p_req = max(in.p_min, l.F_r / (in.mu_fit * 2 * pi * rm * l.B));
C = @(rb) rm / (al.E / 1e6) * ((rb^2 + rm^2) / (rb^2 - rm^2) + al.nu) + rm / (st.E / 1e6) * ((rm^2 + ri^2) / (rm^2 - ri^2) - st.nu);
dth = @(T) (al.cte - st.cte) * (T - 20) * rm;
vm = @(p, rb) p * sqrt(((rb^2 + rm^2) / (rb^2 - rm^2))^2 + 1 + (rb^2 + rm^2) / (rb^2 - rm^2));
pcold = @(rb, Th) (p_req * C(rb) + dth(Th) - dth(-40)) / C(rb);
% fix 1: boss radius
f1 = @(rb) vm(pcold(rb, 149), rb) - X.target_lame;
X.r_boss = fzero(f1, [rb0 + 0.1, 3 * rb0]);
X.dm_kg = pi * (X.r_boss^2 - rb0^2) * sum(in.boss_L) * al.rho * 1e-9;
X.n_3d = al.sy / (in.k_cast * k3 * vm(pcold(X.r_boss, 149), X.r_boss));
X.d20_um_1 = 2 * (p_req * C(X.r_boss) + dth(149)) * 1e3;
% fix 2: hold temperature with the present boss
f2 = @(Th) vm(pcold(rb0, Th), rb0) - X.target_lame;
X.T_hold = fzero(f2, [-30, 149]);
X.n_3d_hold = al.sy / (in.k_cast * k3 * vm(pcold(rb0, X.T_hold), rb0));
X.d20_um_2 = 2 * (p_req * C(rb0) + dth(X.T_hold)) * 1e3;
X.n_now = al.sy / (in.k_cast * k3 * vm(pcold(rb0, 149), rb0));
end
