function B = st_bolts(in, L)
%ST_BOLTS  VDI 2230 Part 1 check of the case attachment flange: 30 x M6 12.9 on PCD 290 (step 3.5).
%   B = st_bolts(in, L)
%
%   in = st_inputs; L: T_ring_lim, T_ring_mct [N m] (torque the flange
%   carries at LD-01/02 and at MCT), R_in, R_out [N] (LD-05 seat reactions).
%   Steps of VDI 2230 Part 1 (2015), short form, tapped-thread joint (the
%   bolts go into helical coil inserts in the A357 first-stage case; the
%   clamped part is the 12 mm A357 flange of the planetary case):
%     R7  assembly preload F_Mzul at 90% of the yield in the thread
%         (combined tension and thread torsion), tightening torque M_A,
%         minimum preload F_Mmin = F_Mzul / alpha_A;
%     R3  resiliences: bolt (head, threaded length in the grip, engaged
%         thread, nut-side thread in the tapped hole) and clamped part
%         (deformation cone, tan phi of the tapped joint, w = 2), load
%         factor Phi_n = n Phi_K;
%     R4  embedding F_Z = f_Z / (delta_S + delta_P), and the thermal change
%         of preload of the steel bolt in aluminium from 20 degC to -40 and
%         149 degC, dF_th = (cte_A357 - cte_bolt) dT l_K / (delta_S + delta_P);
%     R8  working stress: F_Smax = F_Mzul + Phi_n F_A + max(dF_th, 0),
%         reduced stress with 50% of the thread torque, safety on yield;
%     R9  fatigue: the rotating 1P moment as the alternating axial load,
%         sigma_a = Phi_n F_Aa / A_S against sigma_ASV = 0.85 (150 / d + 45);
%     R10 surface pressure of the hardened washer on the A357 flange;
%     R5/R12 residual clamp load after embedding and cooling (opening), and
%         slip: the transverse force of the torque and the radial load against
%         friction, S_G = F_KRmin q_F mu_T / F_Q;
%     thread stripping in the A357 around the inserts.
%   Bolt loads at the flange from the LD-05 limit moment (propeller at 2.5 g
%   and the gyroscopic moment) and the 20 kN thrust; F_A of the most
%   loaded bolt = 4 M / (n PCD) + F_ax / n. Torque by friction is checked;
%   since it fails, the shear path is the dowel pins of in.dowel (shear
%   and bearing on the A357).
%   Output B: struct of every intermediate value and the safety factors.
%   Source: Phase 3 report, Section 3.5 ("Flange bolts"); VDI 2230 Part 1.

b = in.bolt;  Es = in.st.E / 1e6;  Ep = in.al.E / 1e6;
d0 = (b.d2 + b.d3) / 2;  A0 = b.As;  Ad3 = pi / 4 * b.d3^2;  AN = pi / 4 * b.d^2;
% R7 assembly preload and torque
B.F_Mzul = A0 * b.nu_util * b.Rp02 / sqrt(1 + 3 * (3 / 2 * b.d2 / d0 * (b.P / (pi * b.d2) + 1.155 * b.muG))^2);
B.F_Mmin = B.F_Mzul / b.alphaA;
DKm = (b.dw + b.dh) / 2;
B.M_A = B.F_Mzul * (0.16 * b.P + 0.58 * b.d2 * b.muG + DKm / 2 * b.muK) / 1e3;   % N m
% R3 resiliences [mm/N]
dS = 0.4 * b.d / (Es * AN) + b.L_k / (Es * Ad3) + 0.5 * b.d / (Es * Ad3) + 0.33 * b.d / (Es * AN);
bL = b.L_k / b.dw;  y = b.DA / b.dw;
tphi = 0.348 + 0.013 * log(bL) + 0.193 * log(y);
w = 2;
DAGr = b.dw + w * b.L_k * tphi;
if b.DA >= DAGr
    dP = 2 * log((b.dw + b.dh) * (b.dw + w * b.L_k * tphi - b.dh) / ((b.dw - b.dh) * (b.dw + w * b.L_k * tphi + b.dh))) ...
         / (w * Ep * pi * b.dh * tphi);
else                                                 % cone and sleeve
    dP = (2 / (w * b.dh * tphi) * log((b.dw + b.dh) * (b.DA - b.dh) / ((b.dw - b.dh) * (b.DA + b.dh))) ...
          + 4 / (b.DA^2 - b.dh^2) * (b.L_k - (b.DA - b.dw) / (w * tphi))) / (Ep * pi);
end
B.delta_S = dS;  B.delta_P = dP;  B.tan_phi = tphi;  B.DA_Gr = DAGr;
B.Phi_K = dP / (dS + dP);
B.Phi_n = b.n_load * B.Phi_K;
% R4 embedding and temperature
B.F_Z = b.fZ / (dS + dP);
dF = @(T) (in.al.cte - in.st.cte) * (T - 20) * b.L_k / (dS + dP);   % change of preload, positive = rises
B.dF_cold = dF(-40);  B.dF_hot = dF(149);           % -40: the aluminium shrinks more, preload falls; 149: rises
% loads at the flange
M = in.nz * in.m_prop * in.g * b.z_prop + in.M_gyro;           % N m
B.M_flange = M;
B.F_A = 4 * M / (b.n * b.pcd * 1e-3) + in.F_ax / b.n;
B.F_Aa = 4 * in.M_1P / (b.n * b.pcd * 1e-3);                 % amplitude of the rotating 1P moment
B.F_Q = 2 * L.T_ring_lim / (b.n * b.pcd * 1e-3) + abs(L.R_in + L.R_out) / b.n;
% R8 working stress (largest preload: thermal rise counted)
B.F_Smax = B.F_Mzul + B.Phi_n * B.F_A + max([B.dF_cold, B.dF_hot, 0]);
MG = B.F_Mzul * (0.16 * b.P + 0.58 * b.d2 * b.muG);          % thread torque [N mm]
sz = B.F_Smax / A0;  tau = MG / (pi / 16 * d0^3);
B.sig_red = sqrt(sz^2 + 3 * (0.5 * tau)^2);
B.S_F = b.Rp02 / B.sig_red;
% R9 fatigue
B.sig_a = B.Phi_n * B.F_Aa / A0;
B.sig_ASV = 0.85 * (150 / b.d + 45);
B.S_D = B.sig_ASV / B.sig_a;
% R10 surface pressure (hardened washer on the A357)
Ap = pi / 4 * (b.d_washer^2 - b.dh^2);
B.p_max = (B.F_Mzul / 0.9 * 1.0 + B.Phi_n * B.F_A) / Ap;      % F_Mzul at 100% yield utilisation, conservative
B.S_p = b.pG / B.p_max;
% R5/R12 residual clamp load (lowest preload: embedding and the -40 degC loss)
B.F_KRmin = B.F_Mmin - B.F_Z - max(-min([B.dF_cold, B.dF_hot]), 0) - (1 - B.Phi_n) * B.F_A;
B.opening = B.F_KRmin <= 0;
B.S_G = max(B.F_KRmin, 0) * b.qF * b.muT / B.F_Q;
% thread stripping of the A357 around the insert (shear at the insert OD)
B.tau_strip = B.F_Smax / (pi * b.D_ins * b.L_ins * 0.75);
B.S_strip = b.tauB_al / B.tau_strip;
% dowel pins for the torque
dw = in.dowel;
B.F_dowel = L.T_ring_lim / (dw.n * b.pcd / 2 * 1e-3);
B.tau_dowel = B.F_dowel / (pi / 4 * dw.d^2);
B.S_dowel = 0.6 * dw.su / B.tau_dowel;
B.p_dowel = B.F_dowel / (dw.d * dw.t);
B.S_dowel_bearing = dw.p_allow / B.p_dowel;
end
