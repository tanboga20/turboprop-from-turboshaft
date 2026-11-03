function Lc = sf_locations(in, over)
%SF_LOCATIONS  Governing locations of the critical parts with their stress cycles (D4).
%   Lc = sf_locations(in)         in = sf_inputs
%   Lc = sf_locations(in, over)   over: overrides for the design studies (fields M_1P, thread (Kf, di), ndt_thread,
%                                 carrier_b, carrier_hoop)
%
%   Each location gives the outer-fibre stress components [sigma_x sigma_h tau] (axial, hoop, shear; MPa) of
%   the states the crack sees: the ground-air-ground cycle (lcf_max at the LD-01 torque and the limit thrust
%   with the 1P peak, a bound taken every flight; lcf_min on the ground), the HCF cycle at MCT (hmax, hmin:
%   rotating bending at 1x with the torque ripple) and the limit load (lim, one row per load case: LD-05 with
%   LD-01 and LD-08), with the notch factors of step 2.5. sf_dt finds the crack plane: the normal stress on a
%   plane at theta to the shaft axis is sigma_x cos^2 + sigma_h sin^2 + tau sin(2 theta), and the plane with the
%   smallest HCF threshold size governs; the LCF cycle and the limit load are taken on that plane. The wall
%   stress ratio g splits the normal stress into membrane and bending parts. Closed-form shaft sections; the
%   carrier, P111 and case values come from steps 3.5 / 3.6 / 3.8 or are estimates (TBR). NDT at TBO
%   (design decisions, delegated by Hamit): eddy current at the P103 seat, thread root and carrier pin bores and
%   at the PT shaft, MPI at the input shaft, FPI at P111 and the case.
%   Source: Phase 3 report, Section 3.7 (D4).

if nargin < 2, over = struct(); end
d = in.dt;
if isfield(over, 'M_1P'), d.M_1P = over.M_1P; end
th = d.thread;
if isfield(over, 'thread'), th.Kf = over.thread.Kf;  th.di = over.thread.di; end
if ~isfield(over, 'ndt_thread'), over.ndt_thread = 'ET'; end
ca = d.carrier;
if isfield(over, 'carrier_b'), ca.b = over.carrier_b; end
if isfield(over, 'carrier_hoop'), ca.hoop = over.carrier_hoop; end
cp = d.cpl;
if isfield(over, 'cpl'), cp = over.cpl; end
st = @(lmax, lmin, hmax, hmin, lim) struct('lcf_max', lmax, 'lcf_min', lmin, 'hmax', hmax, 'hmin', hmin, 'lim', lim);
z3 = [0 0 0];
k = 0;
% 1. Propeller shaft P103 (4340), 120 / 100 mm at the outer bearing seat
D = 120;  di = 100;
Z = pi / 32 * (D^4 - di^4) / D;  A = pi / 4 * (D^2 - di^2);
tauf = @(T) T * 1e3 / (2 * Z) * d.Kfs;  sb = @(M) M * 1e3 / Z * d.Kf;  sa = @(F) F / A * d.Kf;
Wa = d.W_prop * d.overhang;
sxa = sb(d.M_1P + Wa);
tm = tauf(d.T_prop);
S = st([sa(d.thrust_lim) + sxa, 0, tauf(d.T_prop01)], z3, [sa(d.thrust_to) + sxa, 0, tm * (1 + d.ripple)], ...
       [sa(d.thrust_to) - sxa, 0, tm * (1 - d.ripple)], ...
       [sa(d.thrust_lim) + sb(d.nz * Wa + d.M_gyro), 0, tauf(d.T_prop01); sa(d.thrust_lim) + sxa, 0, tauf(d.T_prop08)]);
k = k + 1;  Lc(k) = loc('P103', 'Propeller shaft P103 at the outer bearing seat', 'Pervane mili P103, dış yatak yuvası', ...
    'S4340', 'surface', (D - di) / 2, pi * D / 2, di / D, S, 'ET', in);
% 2. P103 at the root of the KM24 nut thread (z 474-494): minor diameter d3, bore di (local bore option), rolled
% thread notch factor; bending from the 1P moment and the propeller weight at the thread, full torque with the
% ripple; the thrust compression is ignored
D = th.d3;  di = th.di;
Z = pi / 32 * (D^4 - di^4) / D;
tauf = @(T) T * 1e3 / (2 * Z) * d.Kfs;  sb = @(M) M * 1e3 / Z * th.Kf;
Wa = d.W_prop * th.arm;
sxa = sb(d.M_1P + Wa);
tm = tauf(d.T_prop);
S = st([sxa, 0, tauf(d.T_prop01)], z3, [sxa, 0, tm * (1 + d.ripple)], [-sxa, 0, tm * (1 - d.ripple)], ...
       [sb(d.nz * Wa + d.M_gyro), 0, tauf(d.T_prop01); sxa, 0, tauf(d.T_prop08)]);
k = k + 1;  Lc(k) = loc('P103', 'Propeller shaft P103 at the KM24 nut thread root', 'Pervane mili P103, KM24 somun dişi dibi', ...
    'S4340', 'surface', (D - di) / 2, pi * D / 2, di / D, S, over.ndt_thread, in);
% 3. Carrier part of P103 at a pin bore edge (corner crack in the rim ligament b): the steady press-fit hoop of the
% planet pin plus the 3.5 load stress scaled with the torque and the load-sharing factor
sl = @(T, Kg) ca.s08 * T / d.T_prop08 * Kg / ca.K08;
s_mct = sl(d.T_prop, ca.K_mct);
S = st([ca.hoop + sl(d.T_prop01, ca.K_01), 0, 0], [ca.hoop, 0, 0], [ca.hoop + s_mct * (1 + d.ripple), 0, 0], ...
       [ca.hoop + s_mct * (1 - d.ripple), 0, 0], [ca.hoop + ca.s08, 0, 0]);
k = k + 1;  Lc(k) = loc('P103', 'Carrier of P103 at a pin bore edge', 'P103 taşıyıcısı, pim deliği kenarı', ...
    'S4340', 'corner', ca.t, ca.b, 1, S, 'ET', in);
% 4. Bearing housing P111 (Ti-6Al-4V): flange plate bending under the thrust (estimate, 3-D FE in 3.9)
p = d.p111;  s20 = p.s_nom20 * p.Kt;  sh = s20 * d.thrust_to / 20e3;
S = st([s20, 0, 0], z3, [sh * (1 + d.ripple), 0, 0], [sh * (1 - d.ripple), 0, 0], [s20 * d.thrust_lim / 20e3, 0, 0]);
k = k + 1;  Lc(k) = loc('P111', 'Bearing housing P111 at the flange fillet', 'Yatak gövdesi P111, flanş köşe yuvarlatması', ...
    'Ti64', 'surface', 8, 300, p.g, S, 'FPI', in);
% 5. Planetary case R10 flange junction (A357): initial flaw the largest allowed pore (surface, a = c = d / 2); the
% 1P part of the amplitude scales with M_1P; the stresses carry the casting factor k_cast (as in 3.6)
cf = d.case_fl;  kc = d.k_cast;
s_a = cf.s_a + cf.s_a1P * d.M_1P / cf.M_1P_ref;
S = st(kc * [cf.s_m + s_a, 0, 0], z3, kc * [cf.s_m + s_a, 0, 0], kc * [cf.s_m - s_a, 0, 0], kc * [cf.s_lim, 0, 0]);
k = k + 1;  Lc(k) = loc('planetary case', 'Planetary case at the R10 flange junction', 'Planet gövdesi, R10 flanş birleşimi', ...
    'A357', 'surface', 8, 500, 1, S, 'FPI', in);
Lc(k).a0 = cf.d_pore / 2;  Lc(k).c0 = cf.d_pore / 2;
% 6. RGB input shaft (Pyrowear 53 pinion shaft) at the bearing seat shoulder, 45 / 24 mm; gear forces at the MC
% torque, bending arm to the gear-face shoulder
g1 = d.gear1;
f = d.T_pt_mc * 1e3 / g1.r / g1.Ft;                       % scale of the step 2.5 gear forces to the MC torque
Rb = f * (hypot(g1.Ft, g1.Fr) / 2 + g1.Fa * g1.r / g1.span);   % bearing reaction [N]
D = 45;  di = 24;
Z = pi / 32 * (D^4 - di^4) / D;
tauf = @(T) T * 1e3 / (2 * Z) * d.Kfs;
sxa = Rb * g1.arm / Z * d.Kf;                             % rotating bending at 1x from the gear forces
tm = tauf(d.T_pt_mc);
S = st([sxa * d.T_pt01 / d.T_pt_mc, 0, tauf(d.T_pt01)], z3, [sxa, 0, tm * (1 + d.ripple)], [-sxa, 0, tm * (1 - d.ripple)], ...
       [sxa * d.T_in08 / d.T_pt_mc, 0, tauf(d.T_in08)]);
k = k + 1;  Lc(k) = loc('RGB input shaft', 'RGB input shaft at the bearing seat shoulder', 'RGB giriş mili, yatak yuvası omzu', ...
    'P53', 'surface', (D - di) / 2, pi * D / 2, di / D, S, 'MPI', in);
% 7. RGB input shaft at the coupling end, 40 / 24 mm: torsion with the ripple (the diaphragm coupling carries no
% bending of note)
c = d.input_cpl;
J = pi / 32 * (c.D^4 - c.di^4);
tauf = @(T) T * 1e3 * (c.D / 2) / J * d.Kfs;
tm = tauf(d.T_pt_mc);
S = st([0, 0, tauf(d.T_pt01)], z3, [0, 0, tm * (1 + d.ripple)], [0, 0, tm * (1 - d.ripple)], [0, 0, tauf(d.T_in08)]);
k = k + 1;  Lc(k) = loc('RGB input shaft', 'RGB input shaft at the coupling end', 'RGB giriş mili, kavrama ucu', ...
    'P53', 'surface', (c.D - c.di) / 2, pi * c.D / 2, c.di / c.D, S, 'MPI', in);
% 8. PT output shaft (4340 tube 66 x 1.5) at the tube-to-flange transition: torsion with the steady centrifugal
% hoop stress of the tube at its outer surface (rotating disc, plane stress)
D = 66;  di = 63;
J = pi / 32 * (D^4 - di^4);
tauf = @(T) T * 1e3 * (D / 2) / J * d.Kfs;
sh = pt_hoop(d.pt, D / 2, di / 2);
tm = tauf(d.T_pt_mc);
S = st([0, sh, tauf(d.T_pt01)], z3, [0, sh, tm * (1 + d.ripple)], [0, sh, tm * (1 - d.ripple)], [0, sh, tauf(d.T_in08)]);
k = k + 1;  Lc(k) = loc('PT output shaft', 'PT output shaft at the tube-to-flange transition', 'PT çıkış mili, borudan flanşa geçiş', ...
    'S4340', 'surface', (D - di) / 2, pi * D / 2, di / D, S, 'ET', in);
Lc(k).R_shell = (D + di) / 4;
% 9. Diaphragm coupling (15-5PH) at the thinnest section, the hub radius of the diaphragm (step 2.2 stresses of the
% adopted option, sf_coupling): radial bending from the axial offset at the continuous position (steady), at the
% transient position (s_tr) and at the cold position (s_cold, the worst face), the tilt (1 x per revolution, s_th, and
% s_thx at the transient tilt), the centrifugal hoop, the torque shear with the ripple; the CM-PIFS-007 anomaly is
% deeper than 0.8 t, so a through crack from the start. Ground-air-ground: from the cold position to the transient
tq = @(T) cp.tau_mc * T / d.T_pt_mc;
S = st([cp.s_tr + cp.s_th, cp.s_cf, tq(d.T_pt01)], [cp.s_cold, 0, 0], [cp.s_ax + cp.s_th, cp.s_cf, cp.tau_mc * (1 + d.ripple)], ...
       [cp.s_ax - cp.s_th, cp.s_cf, cp.tau_mc * (1 - d.ripple)], ...
       [cp.s_tr + cp.s_thx, cp.s_cf, tq(d.T_pt01); cp.s_tr + cp.s_th, cp.s_cf, tq(d.T_in08)]);
k = k + 1;  Lc(k) = loc('diaphragm couplings', 'Diaphragm coupling at the thinnest section (hub radius)', ...
    'Diyafram kavrama, en ince kesit (göbek yarıçapı)', 'C155', 'surface', cp.t, pi * cp.r_hub, 1, S, 'ET', in);
% 10. Diaphragm coupling at the hub transition: a 55 / 49 mm tube (TBR) in torsion with the ripple
J = pi / 32 * (cp.D_hub^4 - cp.di_hub^4);
tauf = @(T) T * 1e3 * (cp.D_hub / 2) / J * d.Kfs;
tm = tauf(d.T_pt_mc);
S = st([0, 0, tauf(d.T_pt01)], z3, [0, 0, tm * (1 + d.ripple)], [0, 0, tm * (1 - d.ripple)], [0, 0, tauf(d.T_in08)]);
k = k + 1;  Lc(k) = loc('diaphragm couplings', 'Diaphragm coupling at the hub transition', 'Diyafram kavrama, göbek geçişi', ...
    'C155', 'surface', (cp.D_hub - cp.di_hub) / 2, pi * cp.D_hub / 2, cp.di_hub / cp.D_hub, S, 'ET', in);
Lc(k).R_shell = (cp.D_hub + cp.di_hub) / 4;
% 11. Planetary case nose at the thermocouple boss of the NJ1024 outer ring (G1b): the nose stresses of 3.6 (steady
% mount stress, planet-pass amplitude) with the hole factor Kt_hole and the casting factor; the 0.5 mm pore of the
% critical zone as the initial flaw; the raised pad round the hole carries the wall stresses at t / t_pad
tb = d.tc_boss;  kc = d.k_cast * tb.t / tb.t_pad;
S = st(kc * tb.Kt * [tb.s_m + tb.s_a, 0, 0], z3, kc * tb.Kt * [tb.s_m + tb.s_a, 0, 0], kc * tb.Kt * [tb.s_m - tb.s_a, 0, 0], ...
       kc * tb.Kt * [tb.s_lim, 0, 0]);
k = k + 1;  Lc(k) = loc('planetary case', 'Planetary case nose at the NJ1024 thermocouple boss', ...
    'Planet gövdesi burnu, NJ1024 termokupl göbeği', 'A357', 'surface', tb.t_pad, 300, 1, S, 'FPI', in);
Lc(k).a0 = d.case_fl.d_pore / 2;  Lc(k).c0 = d.case_fl.d_pore / 2;
% 12. P103 at the groove of the QJ pull-out shoulder ring (G1b, z 441-446): the bearing seat loads at the groove root
% diameter with the groove notch factor; the pull-out thrust as tension
gr = d.groove;
D = gr.d_root;  di = 100;
Z = pi / 32 * (D^4 - di^4) / D;  A = pi / 4 * (D^2 - di^2);
tauf = @(T) T * 1e3 / (2 * Z) * d.Kfs;  sb = @(M) M * 1e3 / Z * gr.Kf;  sa = @(F) F / A * gr.Kf;
Wa = d.W_prop * d.overhang;
sxa = sb(d.M_1P + Wa);
tm = tauf(d.T_prop);
S = st([sa(d.thrust_lim) + sxa, 0, tauf(d.T_prop01)], z3, [sxa, 0, tm * (1 + d.ripple)], [-sxa, 0, tm * (1 - d.ripple)], ...
       [sa(d.thrust_lim) + sb(d.nz * Wa + d.M_gyro), 0, tauf(d.T_prop01); sa(d.thrust_lim) + sxa, 0, tauf(d.T_prop08)]);
k = k + 1;  Lc(k) = loc('P103', 'Propeller shaft P103 at the shoulder-ring groove', 'Pervane mili P103, omuz halkası kanalı', ...
    'S4340', 'surface', (D - di) / 2, pi * D / 2, di / D, S, 'ET', in);
% temperature and environment of each location (room-temperature constants used: see in.dt.env_note)
env = in.dt.env;
for j = 1:numel(Lc), Lc(j).env_en = env{j, 1};  Lc(j).env_tr = env{j, 2}; end
end

function s = pt_hoop(pt, ro, ri)
% hoop stress at the outer radius of a rotating hollow disc (plane stress) [MPa]; radii in mm
w = pt.rpm * pi / 30;
s = (3 + pt.nu) / 8 * pt.rho * w^2 * (ri^2 + ro^2 + ri^2 - (1 + 3 * pt.nu) / (3 + pt.nu) * ro^2) * 1e-6 * 1e-6;
end

function L = loc(part, en, tr, mat, kind, t, b, g, S, ndt, in)
a0 = in.dt.a0_surf;  if strcmp(kind, 'corner'), a0 = in.dt.a0_corner; end
nd = in.dt.ndt.(ndt);
if strcmp(kind, 'corner'), sz = nd.corner; else, sz = nd.surf; end
L = struct('part', part, 'en', en, 'tr', tr, 'mat', mat, 'kind', kind, 't', t, 'b', b, 'g', g, 'a0', a0(1), ...
           'c0', a0(2), 'S', S, 'ndt_method', ndt, 'ndt', sz, 'thin', nd.thin(t), 'R_shell', 0, 'env_en', '', 'env_tr', '');
end
