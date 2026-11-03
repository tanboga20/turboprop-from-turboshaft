"""Expected values for the step 3.6 MATLAB tests (calc/tests/step36_test_cases.csv).

    python calc/reference/step36_reference.py        (standard library only)

An independent Python implementation of the closed forms of step 3.6 (calc/dynamics). Inputs are copied from
gd_inputs.m, hs_inputs.m and dy_inputs.m. Where a closed form takes a finite element result as its input, that
result is copied from the run, in the block between the "copied" markers:
- the mesh stiffnesses (ISO 6336-1 c_gamma_alpha b, from the step 2.4 gear design);
- the in-band families of the web with their input energies and groove slips for both shuttle brackets;
- the chosen ring;
- the stresses.

Test cases:
TC93  Mesh frequencies and bands (planetary TE: TE2 0.15 um design value); static mesh force from the torque (F_t, F_r = F_t tan alpha_wt, F_a = F_t tan beta);
      dynamic forces k TE_h along the transverse line of action. The shuttle of the contact-line centroid is counted
      strip by strip across the face (number of contact lines crossing each strip), not by line segments as in
      dy_shuttle. Planet and ring dynamic mesh forces.
TC94  Gear blank: mass by Pappus (bare and teeth-as-mass models have the same mass); the out-of-plane 1x families
      of the harmonic model against the step 2.8 3-D model (teeth as mass, 4 mm tetrahedra, 2% tolerance).
TC95  Check of the harmonic element: bending modes of a slender free steel ring (R 100 mm, 4 x 4 mm) against the
      thin-ring closed forms, in-plane n^2 (n^2 - 1)^2 / (n^2 + 1) and out-of-plane n^2 (n^2 - 1)^2 / (n^2 + EI/GJ).
TC96  Modal superposition plus the static residual against the direct solve, in the harmonic model and in the 3-D
      toolbox model (Hmax 8 mm); the 3-D model against the harmonic one (axial TE load on the bare blank).
TC97  Ring, from the copied families:
      - resonance speeds x = f / (h f_mesh +- n f_rot) inside the band;
      - the macroslip limit mu rho (x Omega)^2 R^3 / (E n^2) at the highest crossing;
      - the families that slip, standing (mean slip) and in rotation (mean slip x pi / 4);
      - E_f / W_in = 4 mu q I / W_in at the lowest crossing (the worse bracket);
      - the travelling-wave amplitude ratio: energy balance with W_in / 2 and a uniform slip, a quadratic, the
        larger of both brackets and both crossings;
      - the ring mass and preload, the rim ratio under the groove and the full rim beyond it.
TC98  Planetary case: mass against the CATIA volume, the lowest modes of the bare case against step 2.8. Goodman
      factors (casting factor, gigacycle knock-down, steady bound and 1P amplitude) of the planetary case per band and
      of the first-stage case, from their copied peak stresses; the Goodman factor at the web roots, bare and with the
      ring.
TC99  Planet: the modes (rx, y, ry, spin) against an independent exact-tensor model (3%); the tooth-root
      safety factors rescaled with K_v,FE (S_F,2.4 K_v,2.4 / K_v,FE); K_v at the TE2 sensitivity value; the cycle
      maximum of von Mises against a sweep of the cycle; the coupling of the planet to the ring and case by receptance
      against a direct solve of a two-DOF planet-mesh-case system.

Source: Phase 3 report, Section 3.6 ("Tests").
"""
import csv
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tests', 'step36_test_cases.csv')

# gd_inputs, hs_inputs, dy_inputs
P_SHP, N_PT, SR = 1200.0, 22000.0, (0.90, 1.01)
Z1, Z2, MN, BETA, ALPHA_N, B1 = 31, 110, 2.0, 15.0, 20.0, 52.0
G_ALPHA = 9.5213                                       # mm, length of the path of contact (gd_meshes, step 2.4)
F_BANDS_P = ((2733.0, 3749.0), (5466.0, 7497.0))
TE = (0.5, 0.2, 0.1)                                   # um, first stage
TE_P, TE2_SENS = (0.5, 0.15, 0.1), 0.2                 # um, planetary meshes (TE2 <= 0.15 um derived requirement)
KV24, SF24, KA = (1.154396783, 1.161456625), (1.875906272, 1.807289837), 1.25   # step 2.4 (TC35, TC36), STR-01
K_GC, SM_CASE, SA_1P, SU_A357, SM_FS = 0.7, 35.4, 8.4, 310.0, 28.7   # case Goodman inputs (dy_inputs)
# hot, cycle-consistent check: 12 % endurance loss at 150 degC; a factor 0.9 per decade beyond 1e8 cycles (0.70 at
# 2.4e11, the k_gc of the coded check) at 8.2e9 (planet pass), 7.3e11 (mesh only) and 8.2e11 (first-stage mesh)
# cycles; hot ultimate 310 x 200 / 240 MPa
K_T, SU_HOT = 0.88, 310.0 * 200 / 240
K_PASS, K_MESH, K_FS = [0.9 ** math.log10(n / 1e8) for n in (8.2e9, 7.3e11, 8.2e11)]
F_PLANET_EXACT = {'rx': 3297.0, 'y': 3986.0, 'ry': 6527.0, 'spin': 7195.0}   # independent exact-tensor model
VM_SAMPLE = ((10, -4, 2, 3, -1, 0.5), (-3, 6, 1, -2, 2, 1))
RHO, NU = 7830.0, 0.3
SIG_E = {'P53': 550.0, 'A357': 60.0}
SU_P53, KT, K_CAST = 1220.0, 1.4, 1.25
U_PRE = 0.1e-6                              # m, ring pre-sliding displacement at mu 0.15 (TBR)
RING = dict(rho=7830.0, E=205e9, mu=0.15, w=4.0, d_groove=1.0, c_ax=0.05)
R_BORE, R_HUB, T_WEB, L_HUB = 25.0, 35.0, 8.0, 40.0
R_ROOT = 221.9608 / 2                                  # mm, first-stage gear root circle
R_RIM, R_OUT = R_ROOT - 3.5 * MN, R_ROOT + 0.25 * 4.5
RIM, H_T = 3.5 * MN, 4.5
F28 = {0: 9923.0, 4: 10100.0, 1: 10106.0, 6: 10321.0, 2: 10864.0, 3: 12459.0, 7: 12628.0, 5: 13069.0}
F28_CASE = (915.0, 977.0, 1684.0, 1726.0)              # lowest case modes (pairs counted once), step 2.8
N28_CASE_1X = 9
V_CASE_CATIA = 4096549.8e-9                            # m^3, cad/assy/part_volumes.csv

# --- copied from the run (dump36) ---
K1 = 884125907                       # N/m, first stage
K_SP = 1413885677                     # N/m, sun-planet
K_RP = 1623053542                     # N/m, planet-ring
BARE_OOP_1X = (0, 1, 2, 3, 4, 5, 6, 7)
RING_H, RING_E = 8, 20             # mm, chosen ring thickness and groove offset
N_RULE = 4                                  # families the s <= 0.6 rule was applied to
FAMS = [                                    # in-band families: n, mesh harmonic, plane, f, W_in and I (both brackets)
    dict(n=0, h=1, oop=True, f=9302.739603, Win=(0.009340683739, 0.00533196488), I=(5.489555501e-07, 4.606575194e-07)),
    dict(n=0, h=1, oop=False, f=10921.49085, Win=(6.982644282e-05, 0.004323542953), I=(1.665295803e-07, 1.904116133e-07)),
    dict(n=1, h=1, oop=True, f=9563.663422, Win=(0.01580111729, 0.01365465776), I=(7.322076733e-06, 6.893991787e-06)),
    dict(n=1, h=1, oop=False, f=12408.09979, Win=(0.006855428269, 0.009851850047), I=(4.657441723e-06, 5.58247752e-06)),
    dict(n=2, h=1, oop=True, f=10370.89613, Win=(0.009402270231, 0.01561518783), I=(2.069515916e-06, 2.481611394e-06)),
    dict(n=3, h=1, oop=True, f=9128.546471, Win=(0.002811400301, 0.006183193363), I=(3.326991568e-07, 2.587661975e-07)),
    dict(n=3, h=1, oop=True, f=11960.00331, Win=(0.005953712228, 0.01060756477), I=(9.79380655e-07, 1.312948966e-06)),
    dict(n=4, h=1, oop=True, f=9867.530917, Win=(0.004981621917, 0.004891931473), I=(7.420632799e-07, 7.340795759e-07)),
    dict(n=4, h=1, oop=True, f=10349.20976, Win=(0.005336645832, 0.01212086725), I=(1.462975979e-06, 1.752467697e-06)),
    dict(n=5, h=1, oop=False, f=11370.67453, Win=(0.0008477965452, 0.003778614577), I=(2.552096968e-07, 3.551561219e-07)),
    dict(n=5, h=1, oop=True, f=12935.36497, Win=(0.002242441385, 0.003440014221), I=(4.163031532e-07, 5.005713731e-07)),
    dict(n=6, h=1, oop=True, f=9667.879363, Win=(0.03204453271, 0.01315437059), I=(3.5034467e-06, 2.479334544e-06)),
    dict(n=6, h=1, oop=False, f=12652.25883, Win=(0.000342292778, 0.004278057986), I=(4.835522714e-07, 7.102709329e-07)),
    dict(n=7, h=1, oop=True, f=11733.79636, Win=(0.02121370321, 0.008175789459), I=(2.516241136e-06, 1.582816137e-06)),
    dict(n=0, h=2, oop=False, f=18992.19302, Win=(2.922490723e-06, 6.883632232e-06), I=(3.456979006e-08, 3.600106593e-08)),
    dict(n=0, h=2, oop=False, f=23267.17088, Win=(9.592996932e-05, 0.0001027370608), I=(3.648513834e-08, 2.839764346e-08)),
    dict(n=1, h=2, oop=True, f=19220.24706, Win=(3.555138938e-06, 1.261590987e-05), I=(3.110384274e-08, 4.070571333e-08)),
    dict(n=2, h=2, oop=True, f=20084.58296, Win=(2.808639304e-06, 1.372112657e-05), I=(2.069048038e-08, 2.513461652e-08)),
    dict(n=3, h=2, oop=False, f=18373.75872, Win=(6.156465745e-05, 2.206269106e-05), I=(1.370120665e-07, 8.64180181e-08)),
    dict(n=3, h=2, oop=True, f=21643.47545, Win=(5.792839104e-06, 1.118057221e-05), I=(2.036009622e-08, 2.095864191e-08)),
    dict(n=3, h=2, oop=False, f=24341.85762, Win=(0.0007692786587, 0.0007606105736), I=(5.717543464e-07, 5.684668759e-07)),
    dict(n=4, h=2, oop=False, f=21486.97022, Win=(1.307634455e-05, 1.48013975e-05), I=(2.35556328e-08, 2.373554668e-08)),
    dict(n=4, h=2, oop=True, f=23950.59483, Win=(1.683308329e-05, 2.013277328e-05), I=(7.3301156e-08, 7.159477362e-08)),
    dict(n=5, h=2, oop=False, f=24817.64459, Win=(1.915538591e-05, 1.564836674e-05), I=(5.804317689e-08, 5.821205655e-08)),
    dict(n=6, h=2, oop=True, f=21368.97238, Win=(3.925304293e-05, 8.362119888e-05), I=(4.455098693e-08, 5.733740615e-08)),
    dict(n=7, h=2, oop=True, f=19884.50205, Win=(1.785454059e-05, 1.939670514e-05), I=(2.731852833e-08, 2.903991979e-08)),
    dict(n=7, h=2, oop=True, f=25393.81116, Win=(3.227529601e-05, 6.028108804e-05), I=(4.026653866e-08, 4.861703884e-08)),
    dict(n=8, h=2, oop=True, f=23659.80943, Win=(3.58246379e-05, 2.133401169e-05), I=(7.597913139e-08, 4.662868294e-08)),
    dict(n=9, h=2, oop=True, f=18227.08218, Win=(5.734906573e-05, 0.000194697104), I=(1.252815837e-07, 1.285853585e-07)),
    dict(n=10, h=2, oop=True, f=18440.56185, Win=(0.000220973381, 2.560315263e-05), I=(2.526649453e-07, 9.842948996e-08)),
    dict(n=10, h=2, oop=True, f=20693.97238, Win=(2.419803067e-05, 0.0001431784862), I=(3.997334605e-08, 2.979185713e-08)),
    dict(n=11, h=2, oop=True, f=20921.73312, Win=(0.0001701568497, 2.086732169e-05), I=(2.022834188e-07, 6.378021375e-08)),
    dict(n=11, h=2, oop=True, f=23409.44409, Win=(3.581865931e-05, 0.000126386063), I=(6.099898066e-08, 3.605515071e-08)),
    dict(n=12, h=2, oop=True, f=23546.71382, Win=(0.0001410160197, 3.278783193e-05), I=(1.759915766e-07, 6.905291007e-08)),
    dict(n=12, h=2, oop=True, f=26337.36967, Win=(9.03795213e-05, 0.0001018412488), I=(1.274262952e-07, 4.625809112e-08)),
    dict(n=13, h=2, oop=True, f=26310.45325, Win=(0.0001107046379, 8.544609009e-05), I=(1.431557806e-07, 5.175361216e-08)),
]
CHECK = {'sig0_direct_2d': 41.82254481, 'Win_direct_2d': 0.00777926977, 'I_direct_2d': 4.255143366e-06,
         'sig0_direct_3d': 12.47805222, 'Win_direct_3d': 0.000598102932,
         'f_2d': 10258.8051, 'sig0_2d': 14.06069843, 'Win_2d': 0.0006420231273}
KV = ((1.022578975, 1.022417865), (1.371823146, 1.358212212), (1.115600846, 1.137924176))   # K_v,FE sun-planet / planet-ring, 1x 2x 3x
SIG_CASE = (7.53250471, 5.183000205, 2.08625235)            # MPa, case peak over the brackets, 1x 2x 3x
SIG_PASS = 12.21783804                             # MPa, largest planet-pass amplitude, slide bracket
SF_WORST_PARTS = ((6.024680405, 11.84869511, 9.777260262), (3.21946939, 11.84869511, 9.777260262), (0.9513656239, 11.84869511, 9.777260262))   # MPa, slide shell minimum: mesh, pass, mean
SF_FLANGE_PARTS = ((6.30202602, 12.21783804, 9.412262583), (3.504515051, 12.21493298, 9.156902282), (1.041000231, 12.21783804, 9.412262583))  # MPa, slide flange minimum
FS_SIG = 9.346711008                               # MPa, first-stage case peak
ROOT = (42.41562421, 106.6512476)                      # MPa, web roots nominal mean and once-per-rev alternating
SIG_VIB = (105.7015141, 56.58044409)                   # MPa, largest vibratory stress, bare and with the ring
# --- end copied ---


def shuttle(n_phase=720, n_strip=4000):
    # contact lines x - z tan(beta_b) = c0 + k p_et in the plane of action; count the lines crossing each axial strip
    at = math.atan(math.tan(math.radians(ALPHA_N)) / math.cos(math.radians(BETA)))
    tbb = math.tan(math.atan(math.tan(math.radians(BETA)) * math.cos(at)))
    p_et = math.pi * MN / math.cos(math.radians(BETA)) * math.cos(at)
    zs = [(i + 0.5) / n_strip * B1 for i in range(n_strip)]
    zc = []
    for j in range(n_phase):
        c0 = j / n_phase * p_et
        num = den = 0.0
        for z in zs:
            lo = math.ceil((0 - z * tbb - c0) / p_et)
            hi = math.floor((G_ALPHA - z * tbb - c0) / p_et)
            cnt = max(hi - lo + 1, 0)
            num += cnt * z
            den += cnt
        zc.append(num / den)
    def harm(k):
        re = sum(v * math.cos(2 * math.pi * k * j / n_phase) for j, v in enumerate(zc)) / n_phase
        im = sum(v * math.sin(2 * math.pi * k * j / n_phase) for j, v in enumerate(zc)) / n_phase
        return 2 * math.hypot(re, im)
    return harm(1), harm(2)


def keys(fams):
    # n<n>_<o|i><h>, 'b' for a second family alike (as test_step36)
    out = []
    for fm in fams:
        k = 'n%d_%s%d' % (fm['n'], 'o' if fm['oop'] else 'i', fm['h'])
        out.append(k + 'b' if k in out else k)
    return out


def main():
    rows = []
    add = lambda tc, q, v, tol=1e-3: rows.append((tc, q, float(v), tol))
    fm1 = N_PT * Z1 / 60
    frot2 = fm1 / Z2
    at = math.atan(math.tan(math.radians(ALPHA_N)) / math.cos(math.radians(BETA)))
    T1 = P_SHP * 745.7 / (N_PT * math.pi / 30)
    dw1 = Z1 * MN / math.cos(math.radians(BETA))
    Ft = 2000 * T1 / dw1
    add('TC93', 'fm1', fm1)
    add('TC93', 'frot2', frot2)
    add('TC93', 'band1_lo', 0.9 * SR[0] * fm1)
    add('TC93', 'band1_hi', 1.1 * SR[1] * fm1)
    fmP = F_BANDS_P[0][0] / (0.9 * SR[0]) / 2 + F_BANDS_P[0][1] / (1.1 * SR[1]) / 2
    add('TC93', 'fmP', fmP)
    add('TC93', 'bandP3_lo', 3 * fmP * 0.9 * SR[0])      # the 3x planetary band
    add('TC93', 'bandP3_hi', 3 * fmP * 1.1 * SR[1])
    add('TC93', 'Fb1', K1 * TE[0] * 1e-6)
    add('TC93', 'Fb2', K1 * TE[1] * 1e-6)
    add('TC93', 'F_t', Ft, 2e-3)
    add('TC93', 'F_r', Ft * math.tan(at), 2e-3)
    add('TC93', 'F_a', Ft * math.tan(math.radians(BETA)), 2e-3)
    dz1, dz2 = shuttle()
    add('TC93', 'dZ1', dz1, 0.01)
    add('TC93', 'dZ2', dz2, 0.05)
    for h, lab in enumerate(('1x', '2x', '3x')):
        add('TC93', 'F_dyn_' + lab, K_SP * TE_P[h] * 1e-6)
        add('TC93', 'Fp_' + lab, K_RP * TE_P[h] * 1e-6)

    # TC94 blank mass by Pappus (three annuli); bare out-of-plane 1x families against step 2.8
    ann = lambda r1, r2, L: math.pi * (r2 ** 2 - r1 ** 2) * L * 1e-9
    m = RHO * (ann(R_BORE, R_HUB, L_HUB) + ann(R_HUB, R_RIM, T_WEB) + ann(R_RIM, R_OUT, B1))
    add('TC94', 'm_blank', m)
    add('TC94', 'm_teeth', m)
    for n in sorted(BARE_OOP_1X):
        add('TC94', 'f_n%d' % n, F28[n], 0.02)

    # TC95 thin free ring, square 4 x 4 mm, R 100 mm
    R, t = 0.100, 0.004
    A, I = t * t, t ** 4 / 12
    J = 0.1406 * t ** 4                                # square section torsion constant
    G = 205e9 / (2 * (1 + NU))
    for n in (2, 3, 4):
        base = 205e9 * I / (RHO * A * R ** 4) * n ** 2 * (n ** 2 - 1) ** 2
        add('TC95', 'f_in_n%d' % n, math.sqrt(base / (n ** 2 + 1)) / (2 * math.pi), 0.02)
        add('TC95', 'f_out_n%d' % n, math.sqrt(base / (n ** 2 + 205e9 * I / (G * J))) / (2 * math.pi), 0.02)

    # TC96 modal against direct, 3-D against 2-D
    add('TC96', 'sig0_modal_2d', CHECK['sig0_direct_2d'], 0.005)
    add('TC96', 'Win_modal_2d', CHECK['Win_direct_2d'], 0.005)
    add('TC96', 'I_modal_2d', CHECK['I_direct_2d'], 0.005)
    add('TC96', 'sig0_modal_3d', CHECK['sig0_direct_3d'], 0.005)
    add('TC96', 'Win_modal_3d', CHECK['Win_direct_3d'], 0.005)
    add('TC96', 'f_3d', CHECK['f_2d'], 0.05)
    add('TC96', 'sig0_3d', CHECK['sig0_2d'], 0.15)
    add('TC96', 'Win_3d', CHECK['Win_2d'], 0.10)

    # TC97 ring
    Om = 2 * math.pi * frot2
    Rg = R_RIM / 1000
    x_band = (0.9 * SR[0], 1.1 * SR[1])
    u_st = lambda x, n: RING['mu'] * RING['rho'] * (x * Om) ** 2 * Rg ** 3 / (RING['E'] * max(n, 1) ** 2) + U_PRE * RING['mu'] / 0.15
    Ar = RING_H * RING['w'] * 1e-6
    q = lambda x: RING['rho'] * Ar * (x * Om) ** 2 * Rg
    add('TC97', 'ring_mass', RING['rho'] * Ar * 2 * math.pi * Rg)
    add('TC97', 'q100', q(1.0))
    add('TC97', 'sR_ht', (RIM - RING['d_groove']) / H_T)
    add('TC97', 'rim_beyond', B1 / 2 - RING_E - (RING['w'] + 2 * RING['c_ax']) / 2)
    n_slip = n_trav = 0
    for k, fm in zip(keys(FAMS), FAMS):
        n, h, f = fm['n'], fm['h'], fm['f']
        xs = [f / (h * fm1 + n * frot2)] + ([f / (h * fm1 - n * frot2)] if n > 0 else [])
        xs = [x for x in xs if x_band[0] <= x <= x_band[1]] or [1.0]
        x_lo, x_hi = min(xs), max(xs)
        u_slip = max(fm['I']) / (2 * math.pi * Rg)
        slips = n > 0 and u_slip > u_st(x_hi, n)
        n_trav += n > 0 and u_slip * math.pi / 4 > u_st(x_hi, n)
        if not slips:
            continue
        n_slip += 1
        add('TC97', 'x_lo_' + k, x_lo)
        add('TC97', 'x_hi_' + k, x_hi)
        add('TC97', 'u_stick_hi_' + k, u_st(x_hi, n) * 1e6)
        add('TC97', 'Ef_Win_' + k, min(4 * RING['mu'] * q(x_lo) * Ii / Wi for Wi, Ii in zip(fm['Win'], fm['I'])))
        s_t = 0.0
        for Wi, Ii in zip(fm['Win'], fm['I']):
            # travelling wave: s W_t (1 - s) = 4 mu q R 2 pi (s u_t - u_stick), W_t = W_in / 2, u_t = mean slip x pi / 4
            Wt, ut = Wi / 2, Ii / (2 * math.pi * Rg) * math.pi / 4
            for x in {x_lo, x_hi}:
                a = 4 * RING['mu'] * q(x) * Rg * 2 * math.pi * ut
                b = 4 * RING['mu'] * q(x) * Rg * 2 * math.pi * u_st(x, n)
                sx = 1.0 if a <= b else min(1.0, ((Wt - a) + math.sqrt((Wt - a) ** 2 + 4 * Wt * b)) / (2 * Wt))
                s_t = max(s_t, sx)
        add('TC97', 's_trav_' + k, s_t, 2e-3)
    add('TC97', 'n_slip', n_slip, 0)
    add('TC97', 'n_slip_trav', n_trav, 0)
    add('TC97', 'n_rule', N_RULE, 0)

    # TC98 case and margins
    # the 3.6 design change on the CATIA case: flange OD 307 -> 325 mm (ring r 153.5-162.5, z 0-12) and the R10 outer /
    # R5 inner fillets at z 12 (spandrel area R^2 (1 - pi / 4), centroid 0.2234 R from each face; Pappus)
    v_fl = math.pi * (162.5 ** 2 - 153.5 ** 2) * 12e-9
    spandrel = lambda Rf, rc, s: Rf ** 2 * (1 - math.pi / 4) * 1e-6 * 2 * math.pi * (rc + s * (10 - 3 * math.pi) / (3 * (4 - math.pi)) * Rf) * 1e-3
    add('TC98', 'm_case', 2680 * (V_CASE_CATIA + v_fl + spandrel(10, 137.5, 1) + spandrel(5, 129.5, -1)), 0.01)
    for k, f in enumerate(F28_CASE):
        add('TC98', 'f_case_%d' % (k + 1), f, 0.02)
    se = SIG_E['A357'] * K_GC
    for h, lab in enumerate(('1x', '2x', '3x')):
        # the steady bound in place of the steady stress; the planet-pass amplitude (slide) and the 1P on the alternating
        add('TC98', 'sf_bound_' + lab, 1 / (K_CAST * ((SIG_CASE[h] + SIG_PASS + SA_1P) / se + SM_CASE / SU_A357)))
        # slide bracket, node by node: Goodman recomputed from the stresses where the shell and flange minima are set
        # (mesh, planet pass, mean [MPa]); 0.1% (the parts are printed to 10 digits)
        for q, parts in (('sf_worst_', SF_WORST_PARTS[h]), ('sf_flange_', SF_FLANGE_PARTS[h])):
            sa, sp, sm = parts
            add('TC98', q + lab, 1 / (K_CAST * ((sa + sp + SA_1P) / se + sm / SU_A357)))
            # hot: the full amplitude at the planet-pass cycles, the mesh amplitude alone at the mesh cycles
            se0 = SIG_E['A357']
            hot = min(1 / (K_CAST * ((sa + sp + SA_1P) / (K_T * K_PASS * se0) + sm / SU_HOT)),
                      1 / (K_CAST * (sa / (K_T * K_MESH * se0) + sm / SU_HOT)))
            add('TC98', 'hot_' + q + lab, hot, 2e-3)
        sa, sp, sm = SF_FLANGE_PARTS[h]
        add('TC98', 'kT_star_' + lab, (sa + sp + SA_1P) / (K_PASS * SIG_E['A357'] * (1 / K_CAST - sm / SU_HOT)), 2e-3)
    add('TC98', 'sf_fscase', 1 / (K_CAST * (FS_SIG / se + SM_FS / SU_A357)))
    add('TC98', 'hot_sf_fscase', 1 / (K_CAST * (FS_SIG / (K_T * K_FS * SIG_E['A357']) + SM_FS / SU_HOT)), 2e-3)
    # two-DOF coupling benchmark: the coupled mesh force solved directly (independent of the receptance formula)
    m1, k1, km, m2, k2, zt = 1.2, 4e8, 1.5e9, 3.0, 2e9, 0.02
    c1, c2 = 2 * zt * math.sqrt(k1 * m1), 2 * zt * math.sqrt(k2 * m2)
    for f in (3000, 5000, 6500, 7500, 9000, 12000):
        w = 2 * math.pi * f
        za, zb = complex(k1 - m1 * w * w, w * c1), complex(k2 - m2 * w * w, w * c2)
        a11, a12, a22 = za + km, km, zb + km
        det = a11 * a22 - a12 * a12
        x1 = (km * a22 - a12 * km) / det
        x2 = (a11 * km - a12 * km) / det
        F = abs(km * (1 - x1 - x2))
        add('TC99', 'couple_formula_%d' % f, F, 1e-6)
        add('TC99', 'couple_direct_%d' % f, F, 1e-6)
    gm = lambda v: 1 / ((KT * ROOT[1] + v) / SIG_E['P53'] + KT * ROOT[0] / SU_P53)
    add('TC98', 'sf_root_bare', gm(SIG_VIB[0]))
    add('TC98', 'sf_root_ring', gm(SIG_VIB[1]))

    # TC99 planet: modes against the independent exact-tensor model; S_F rescaled with K_v; TE2 sensitivity;
    # the cycle maximum of von Mises by sweeping the cycle
    for k, f in F_PLANET_EXACT.items():
        add('TC99', 'f_' + k, f, 0.03)
    for h, lab in enumerate(('1x', '2x', '3x')):
        add('TC99', 'SF_sp_' + lab, SF24[0] * KV24[0] / KV[h][0])
        add('TC99', 'SF_pr_' + lab, SF24[1] * KV24[1] / KV[h][1])
    add('TC99', 'Kv2_sens_sp', 1 + (KV[1][0] - 1) * TE2_SENS / TE_P[1])
    add('TC99', 'Kv2_sens_pr', 1 + (KV[1][1] - 1) * TE2_SENS / TE_P[1])
    sr, si = VM_SAMPLE
    vm = lambda c: math.sqrt(0.5 * ((c[0] - c[1]) ** 2 + (c[1] - c[2]) ** 2 + (c[2] - c[0]) ** 2) + 3 * (c[3] ** 2 + c[4] ** 2 + c[5] ** 2))
    vmax = max(vm([a * math.cos(t) - b * math.sin(t) for a, b in zip(sr, si)])
               for t in (2 * math.pi * j / 200000 for j in range(200000)))
    add('TC99', 'vm_cycle', vmax, 1e-6)
    # planet-pass amplitude, half the longest chord, by brute force over the point pairs of one period
    tp = [j * (math.pi / 2) / 30 for j in range(30)]
    pts = [[10 * math.cos(4 * t) + 3 * math.cos(8 * t), 0, 0, 4 * math.sin(4 * t), 0, 0] for t in tp]
    add('TC99', 'pass_amp', max(vm([(a - b) / 2 for a, b in zip(p1, p2)]) for p1 in pts for p2 in pts), 1e-9)
    # self-checks of the MATLAB models (expected 0): u equal at the slide ties (relative), first-stage case reaction
    add('TC98', 'tie_slide', 0, 1e-9)
    # (the bolt-face reaction, K u at the fixed nodes, against the nominal pinion force: the bearing-width load bands
    # cut the coarse 12 mm elements, so the applied total is within a few percent of nominal; gravity checks to 0.1%)
    add('TC98', 'fs_reaction', 0, 0.04)

    with open(OUT, 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(['tc', 'quantity', 'expected', 'tol'])
        for tc, q_, v, tol in rows:
            w.writerow([tc, q_, '%.10g' % v, tol])
    print('%d test values written to %s' % (len(rows), os.path.normpath(OUT)))


if __name__ == '__main__':
    main()
