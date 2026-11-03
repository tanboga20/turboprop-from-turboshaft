"""Expected values for the step 3.3 MATLAB tests (calc/tests/step33_test_cases.csv).

    python calc/reference/step33_reference.py        (standard library only)

An independent Python implementation of the closed-form sensitivities of step 3.3 (calc/interfaces/if_sens). The
other rows of the sensitivity table rerun the tested tools of steps 2.2, 2.5 and 3.2 with changed inputs and are
not repeated here. Inputs are copied from gd_inputs.m, ad_inputs.m, lb_inputs.m, os_inputs.m and the step 2.5 and
2.8 results named below. Test cases:

TC74  LD-08: propeller torque peak 26,129 x 0.2 / t and the margin of the ring gear capacity (24,386 N m) for
      stopping times 0.15 to 0.5 s.
TC75  LUB-08: usable oil needed for 5 to 30 s of negative g at the full supply pump flow (5.8 cm3/rev, 6,200 rpm,
      volumetric efficiency 0.85) against 5.69 L.
TC76  STR-02: planet speed at 110% (5,471.5 rpm at 100%, step 2.5) against supplier limits 5,500 to 7,000 rpm.
TC77  DYN-05: propeller bearing seat stiffness of the bolted flange (6.56e7 N/m, step 2.8) in series with the engine
      mount, against the 5e7 N/m floor; and LD-06: the generator pad moment (16 kg, CG 140 mm) at 2.5 to 5 g.
TC79  Oil decision (Type II only): RGB oil inlet at maximum continuous power with the step 2.7 cooler core (UA
      419.025 W/K, oil 730.898 W/K, air 725.04 W/K, cross-flow both unmixed eps = 1 - exp(NTU^0.22/Cr (exp(-Cr
      NTU^0.78) - 1))) for 14.9 and 18 kW on 53, -20 and -40 degC days, and the ambient for a 73 degC inlet.
TC78  ICD-34: installed dry engine mass, T700-GE-700 core 437 lb + RGB 108.4456268 kg (step 3.2 roll-up, mass card B and mount card A) + SYS-11 input drive
      5.460681 kg (PT output shaft, couplings, tunnel; step 3.1 TC66) + oil tank 1.6 kg, and its excess over the
      229.5 kg of the PT6A-67A.

Source: Phase 3 report, Section 3.3 ("Tests").
"""
import csv
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tests', 'step33_test_cases.csv')


def main():
    rows = []
    add = lambda tc, q, v, tol=1e-3: rows.append((tc, q, float(v), tol))
    cap = 24386.0
    for t in (0.15, 0.20, 0.22, 0.30, 0.50):
        T = 26129.0 * 0.2 / t
        add('TC74', 'T_%g' % t, T)
        add('TC74', 'margin_%g' % t, cap / T)
    Qp = 5.8 * 6200 * 0.85 / 1000
    for t in (5, 10, 20, 30):
        V = Qp * t / 60
        add('TC75', 'V_%g' % t, V)
        add('TC75', 'margin_%g' % t, 5.69 / V)
    n110 = 5471.5 * 1.10
    for nl in (5500, 6000, 6500, 7000):
        add('TC76', 'margin_%g' % nl, nl / n110)
    for km in (1e8, 2e8, 5e8, 1e9):
        k = 1 / (1 / 6.56e7 + 1 / km)
        add('TC77', 'k_%g' % km, k)
        add('TC77', 'margin_k_%g' % km, k / 5e7)
    for nz in (2.5, 3.17, 4.0, 5.0):
        add('TC77', 'M_pad_%g' % nz, 16 * 9.81 * nz * 140 / 1000)
    m = 437 * 0.45359237 + 108.4456268 + 5.460681 + 1.6
    add('TC78', 'm_installed', m)
    add('TC78', 'over_PT6A67A', m - 229.5)
    UA, Co, Ca = 419.025, 730.898, 725.04
    Cmin, Cr = min(Co, Ca), min(Co, Ca) / max(Co, Ca)
    N = UA / Cmin
    eps = 1 - math.exp(N ** 0.22 / Cr * (math.exp(-Cr * N ** 0.78) - 1))
    for q in (14.9, 18):
        rise = q * 1e3 / (eps * Cmin) - q * 1e3 / Co
        for ta in (53, -20, -40):
            add('TC79', 'Tin_%g_%g' % (q, ta), ta + rise, 2e-3)
        add('TC79', 'Tamb73_%g' % q, 73 - rise, 2e-3)
    with open(OUT, 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(['tc', 'quantity', 'expected', 'tol'])
        for tc, q, v, tol in rows:
            w.writerow([tc, q, '%.10g' % v, tol])
    print('%d rows written to %s' % (len(rows), os.path.normpath(OUT)))


if __name__ == '__main__':
    main()
