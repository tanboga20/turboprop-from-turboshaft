"""Expected values for the step 2.10 MATLAB tests (calc/tests/step210_test_cases.csv).

    python calc/reference/step210_reference.py        (standard library only)

Re-codes the characteristic frequencies of the RGB at 100% speed from the design data of steps 2.4 to 2.6
(tooth numbers, speeds, bearing geometry, copied below), independently of calc/hums/hm_frequencies.m.
Test cases, all to 0.1%:

TC57  Shaft speeds (7) and mesh frequencies (4): kinematics of the offset first stage, the planetary
      stage with the ring fixed and the accessory gear trains.
TC58  Local gear fault frequencies (4): sun tooth, planet tooth, ring tooth, planet pass.
TC59  Bearing frequencies (11 bearings x cage, inner race, outer race, rolling element spin): the
      classical kinematic formulas, with the races swapped for the planet bearing (stationary pin).

Source: Phase 2 report, Section 2.10 ("Tests").
"""
import csv
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tests', 'step210_test_cases.csv')

N_PT = 22000.0                                  # rpm (SYS-02)
Z1, Z2 = 31, 110                                # first stage (step 2.4)
ZS, ZP, ZR, N = 45, 37, 119, 4                  # planetary stage
Z_GEN = 57                                      # generator gear on the first-stage gear (step 2.6)
Z_OSG = (21, 30)                                # pinion on the generator shaft / OSG gear
Z_PCU = (20, 73)                                # pinion on the intermediate shaft / PCU gear
D_OR = 53.0                                     # planet bore = outer race (step 2.5)
PLANET = dict(Dw=7.5, gap=0.03)

# (name, shaft index, Z, Dw, Dpw, alpha deg); shaft index into the speed list below
BEARINGS = [('input roller', 0, 14, 11.0, 65.0, 0.0), ('input QJ', 0, 13, 12.7, 65.0, 35.0),
            ('intermediate roller', 1, 15, 11.0, 70.0, 0.0), ('intermediate QJ', 1, 14, 12.7, 70.0, 35.0),
            ('propeller inner roller', 2, 26, 15.0, 150.0, 0.0), ('propeller outer roller', 2, 26, 15.0, 150.0, 0.0),
            ('propeller QJ', 2, 21, 19.05, 150.0, 35.0)]
ACC_BEARINGS = [('generator shaft bearing', 4, 8, 11.0, 43.5), ('OSG shaft bearing', 5, 8, 5.953, 25.0),
                ('PCU shaft bearing', 6, 8, 6.747, 28.5)]


def speeds():
    n_in = N_PT
    n_mid = n_in * Z1 / Z2
    n_c = n_mid * ZS / (ZS + ZR)               # ring fixed: n_c / n_sun = zs / (zs + zr)
    n_p = (n_mid - n_c) * ZS / ZP
    n_gen = n_mid * Z2 / Z_GEN
    n_osg = n_gen * Z_OSG[0] / Z_OSG[1]
    n_pcu = n_mid * Z_PCU[0] / Z_PCU[1]
    return [n_in, n_mid, n_c, n_p, n_gen, n_osg, n_pcu]


def bearing(fr, Z, Dw, Dpw, alpha, stationary_inner=False):
    g = Dw / Dpw * math.cos(math.radians(alpha))
    spin = Dpw / (2 * Dw) * fr * (1 - g * g)
    inner = Z * fr / 2 * (1 + g)
    outer = Z * fr / 2 * (1 - g)
    cage = fr / 2 * (1 + g) if stationary_inner else fr / 2 * (1 - g)
    return cage, inner, outer, spin


def main():
    rows = []
    add = lambda tc, q, v: rows.append((tc, q, float(v), 0.001))
    f = [n / 60 for n in speeds()]
    for i, v in enumerate(f, 1):
        add('TC57', 'shaft%d_Hz' % i, v)
    meshes = [Z1 * f[0], ZR * f[2], Z_OSG[0] * f[4], Z_PCU[0] * f[1]]
    for i, v in enumerate(meshes, 1):
        add('TC57', 'mesh%d_Hz' % i, v)
    for i, v in enumerate([N * (f[1] - f[2]), 2 * f[3], N * f[2], N * f[2]], 1):
        add('TC58', 'gearfault%d_Hz' % i, v)
    table = [bearing(f[k], Z, Dw, Dpw, a) for _, k, Z, Dw, Dpw, a in BEARINGS]
    Dpw_p = D_OR - PLANET['Dw']
    Z_p = math.floor(math.pi * Dpw_p / (PLANET['Dw'] * (1 + PLANET['gap'])))
    table.append(bearing(f[3], Z_p, PLANET['Dw'], Dpw_p, 0.0, stationary_inner=True))
    table += [bearing(f[k], Z, Dw, Dpw, 0.0) for _, k, Z, Dw, Dpw in ACC_BEARINGS]
    for j, vals in enumerate(table, 1):
        for name, v in zip(('cage', 'inner', 'outer', 'spin'), vals):
            add('TC59', 'brg%d_%s_Hz' % (j, name), v)
    with open(OUT, 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['tc', 'quantity', 'expected', 'tol'])
        for tc, q, v, tol in rows:
            w.writerow([tc, q, '%.10g' % v, tol])
    print('%d values written to %s (planet bearing Z %d)' % (len(rows), os.path.normpath(OUT), Z_p))


if __name__ == '__main__':
    main()
