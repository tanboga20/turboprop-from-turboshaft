"""Expected values for the step 3.4 MATLAB tests (calc/tests/step34_test_cases.csv).

    python calc/reference/step34_reference.py        (standard library only)

An independent Python implementation of the closed forms of step 3.4 (calc/manufacturing). Inputs are copied
from mf_inputs.m, sb_inputs.m and gd_inputs.m, from the step 2.4 rating (contact stresses sigma_H, the K_gamma P99
1.33709 of the Monte Carlo load sharing and the film thickness at the pitch point, which rerun the tested tools
of step 2.4) and from the step 3.2 roll-up (step32.mat). Test cases:

TC80  Case depth at LD-02: Hertz half width b = 2 p0 R / E*, depth of the largest shear stress 0.786 b, case depth
      needed 2 x that depth and the margin of the specified minimum, for the flanks (relative radius of the
      sun-planet and planet-ring meshes from the gear geometry, of the helical first stage copied) and for the
      planet bearing raceways (most loaded roller 4.08 Fr / Z, line contact over 56 mm).
TC81  Fasteners: bottom-up mass of the 12 joints (A286, shank plus head, washer, nut and insert volumes as
      multiples of d^3), with the 1.5 contingency, and the step 3.1 allowance (5% of 104.18 kg) minus it.
TC82  Steel seat liners: mass added over the A357 they replace, and the change of the NU1024 liner fit at -40
      and 132 degC.
TC83  Flank finish: film ratio at Ra 0.10 um on both flanks from the step 2.4 film, and the Ra for lambda = 1.
TC84  Bill of materials: the roll-up and the bottom-up estimate (fastener allowance replaced, liners added).

Source: Phase 3 report, Section 3.4 ("Tests").
"""
import csv
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tests', 'step34_test_cases.csv')

E = 206e3
NU = 0.3
ESTAR = 1 / (2 * (1 - NU ** 2) / E)
K_CD = 2.0
CD_MIN = {'P53': 0.5, 'N13': 0.5, 'M5N': 1.0}


def hertz(p0, R):
    b = 2 * p0 * R / ESTAR
    z = 0.786 * b
    return b, z, K_CD * z


def main():
    rows = []
    add = lambda tc, q, v, tol=1e-3: rows.append((tc, q, float(v), tol))

    # TC80: flanks at LD-02 (sigma_H of the step 2.4 rating at 137.5% torque, K_A 1)
    a20 = math.radians(20)
    r_p, r_s, r_r = 37 * math.sin(a20), 45 * math.sin(a20), 119 * math.sin(a20)    # module 2, x = 0: pitch = working
    R_sp = r_p * r_s / (r_p + r_s)
    R_pr = r_p * r_r / (r_r - r_p)
    R_fs = 9.101717908                                     # helical first stage (normal section), copied
    flanks = [('pinion', 1033.814652, R_fs, 'P53'), ('planet_sun', 1202.027099, R_sp, 'P53'),
              ('sun', 1188.728986, R_sp, 'P53'), ('planet_ring', 834.7094204, R_pr, 'P53'),
              ('ring', 786.1693468, R_pr, 'N13')]
    for name, p0, R, m in flanks:
        b, z, need = hertz(p0, R)
        add('TC80', 'b_' + name, b)
        add('TC80', 'need_' + name, need)
        add('TC80', 'margin_' + name, CD_MIN[m] / need)
    # planet bearing raceways at LD-02: Fr of the two mesh forces and the centrifugal force (copied), 18 rollers
    Fr = 28414.7349569303
    Dw, D_or, Lw = 7.5, 53.0, 70 - 14
    Z = math.floor(math.pi * (D_or - Dw) / (Dw * 1.03))
    Q = 4.08 * Fr / Z
    a = Dw / 2
    Ro = D_or / 2
    Ri = Ro - Dw
    for name, R, m in (('bore', a * Ro / (Ro - a), 'P53'), ('pin', a * Ri / (Ri + a), 'M5N')):
        p0 = math.sqrt(Q * ESTAR / (math.pi * R * Lw))
        b, z, need = hertz(p0, R)
        add('TC80', 'p0_' + name, p0)
        add('TC80', 'need_' + name, need)
        add('TC80', 'margin_' + name, CD_MIN[m] / need)
    add('TC80', 'Z', Z)

    # TC81: fasteners [n, d, L, washers, nuts, inserts]
    J = [(30, 6, 26, 1, 0, 1), (24, 5, 20, 1, 0, 1), (12, 8, 30, 1, 0, 1), (12, 6, 20, 1, 0, 1), (12, 6, 18, 0, 0, 1),
         (8, 6, 20, 1, 0, 1), (6, 8, 35, 1, 1, 1), (8, 6, 25, 1, 1, 1), (10, 6, 25, 1, 1, 1), (4, 6, 25, 1, 0, 1),
         (24, 5, 16, 1, 0, 1), (20, 5, 14, 0, 0, 1)]
    tot = 0.0
    for n, d, L, w, nut, ins in J:
        V = math.pi / 4 * d ** 2 * L + (1.0 + 0.35 * w + 0.9 * nut + 0.15 * ins) * d ** 3
        tot += n * V * 7940e-9
    add('TC81', 'sum', tot)
    add('TC81', 'with_k', 1.5 * tot)
    allowance = 0.05 * 102.9820508                   # 5% of the modelled mass, for comparison (step 3.2 roll-up)
    add('TC81', 'diff', allowance - 1.5 * tot)

    # TC82: liners [n, D, B, t]; steel 7830 over A357 2680, CTE 21.5e-6 and 12.3e-6
    L = [(2, 180, 28, 3.0), (2, 85, 23, 2.5), (2, 90, 23, 2.5), (1, 85, 19, 2.5), (1, 90, 20, 2.5), (2, 62, 17, 2.0),
         (1, 35, 11, 2.0), (2, 40, 12, 2.0)]
    kg = 0.0
    for n, D, B, t in L:
        V = math.pi / 4 * ((D + 2 * t) ** 2 - D ** 2) * (B + 4)
        kg += n * V * (7830 - 2680) * 1e-9
    add('TC82', 'kg', kg)
    n, D, B, t = L[0]
    add('TC82', 'kg_NU1024', n * math.pi / 4 * ((D + 2 * t) ** 2 - D ** 2) * (B + 4) * (7830 - 2680) * 1e-9)
    for T in (-40, 132):
        add('TC82', 'dfit_NU1024_%d' % T, (21.5e-6 - 12.3e-6) * (D + 2 * t) * (T - 20))

    # TC83: film at the pitch point (h_C of step 2.4, MIL-PRF-23699), roughness of step 2.4: Ra = Rz / 6
    sig_ext = math.sqrt(2) * 0.8 / 6
    sig_ring = math.sqrt((0.8 / 6) ** 2 + (1.0 / 6) ** 2)
    for name, h, sig in (('sun_planet_100', 0.09982486321, sig_ext), ('sun_planet_132', 0.06653584811, sig_ext),
                         ('planet_ring_100', 0.1814137366, sig_ring), ('first_stage_100', 0.2897783091, sig_ext)):
        add('TC83', 'lambda24_' + name, h / sig)
        add('TC83', 'lambda_Ra01_' + name, h / (math.sqrt(2) * 0.10))
    add('TC83', 'Ra_lambda1_sun_planet_100', 0.09982486321 / math.sqrt(2))

    # TC84: BOM roll-up (step 3.2) and bottom-up estimate
    total, bolts = 108.4456268, 1.958092             # roll-up with the mass card B basis (bottom-up fasteners, extras)
    add('TC84', 'rollup', total)
    add('TC84', 'bottom_up', total)                   # the roll-up already has the bottom-up basis (mass card B)

    with open(OUT, 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(['tc', 'quantity', 'expected', 'tol'])
        for tc, q, v, tol in rows:
            w.writerow([tc, q, '%.10g' % v, tol])
    print('%d rows written to %s' % (len(rows), os.path.normpath(OUT)))


if __name__ == '__main__':
    main()
