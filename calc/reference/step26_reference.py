"""Expected values for the step 2.6 MATLAB tests (calc/tests/step26_test_cases.csv).

    python calc/reference/step26_reference.py        (needs numpy and scipy; rotordynamics/.venv has both)

An independent Python implementation of the step 2.6 accessory drive checks. It builds on the step 2.4 and 2.5
references in this folder (their pair geometry from the simulated generating cut, ISO 6336 rating, bearing ratings
and a_ISO), not on the MATLAB code. Inputs are copied from calc/accessory/ad_inputs.m. Test cases:

TC45  The three accessory gear pairs (generator on the first-stage gear, OSG, PCU) at the STR-01 load: K_v, K_Hbeta,
      S_H and S_F of both gears.
TC46  Shear necks of the generator and OSG pads: diameter, shear torque band, fatigue at 1.5 x the rated torque.
TC47  Deep groove ball bearing life: X and Y from the ISO 281 table in f0 Fa/C0, a_ISO, L10m (generator shaft
      bearing and two load cases on the same bearing).
TC48  Web modes of the PCU gear blank (Rayleigh-Ritz model of step 2.4) for n = 0 to 3.

Source: Phase 2 report, Section 2.6 ("Tests").
"""
import csv
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import step24_reference as r24  # noqa: E402
import step25_reference as r25  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tests', 'step26_test_cases.csv')

# ---------------------------------------------------------------- inputs (ad_inputs.m)
T_GEN_MAX, T_OSG, T_PCU = 46.89, 1.13, 1.81
GEN = dict(z=57, x=0.0, b=16.0, A=5, Rz=0.8, hub_d=80.0, bore=16.0)
OSG = dict(z=(21, 30), m=2.0, x=(0.1, -0.1), b=6.0, A=5, Rz=2.0, hub_d=20.0, bore=(16.0, 10.0))
PCU = dict(z=(20, 73), m=1.5, x=(0.4, -0.4), b=10.0, A=5, Rz=2.0, hub_d=40.0, bore=(14.0, 12.0))
KA = 1.25
NECK = dict(k_shear=4.0, d_min=5.0, su=1240.0, tau_ratio=0.67, scatter=0.10, tol=0.02, Kfs=1.3, ripple=0.10,
            k_fat=1.5, ka=(1.38, -0.067), ke=0.753)
S1 = r24.S1
N_MID = r24.N_PT * S1['z1'] / S1['z2']


# ---------------------------------------------------------------- meshes
def meshes():
    g = r24.pair(GEN['z'], S1['z2'], S1['mn'], S1['beta'], GEN['b'], GEN['x'], S1['x2'], False, GEN['A'])
    dm1 = (g['da1'] + g['root1']['df']) / 2
    dm2 = (g['da2'] + g['root2']['df']) / 2
    di2 = g['root2']['df'] - 2 * r24.GEAR2_RIM * S1['mn']
    CR = 1 + np.log(min(max(r24.GEAR2_WEB / GEN['b'], 0.2), 1.2)) / (5 * np.exp(r24.GEAR2_RIM / 5))
    n_gen = N_MID * S1['z2'] / GEN['z']
    out = [dict(name='gen', g=g, mat1=r24.EH, mat2=r24.EH, T1=T_GEN_MAX, n1=n_gen, Kgam=1.0, rev1=False, rev2=True,
                kv=('pair', r24.mstar(dm1, GEN['bore'] / dm1, g['db1']), r24.mstar(dm2, di2 / dm2, g['db2'])),
                ksh=0.023 * (GEN['b'] / g['d1']) ** 2, fma=np.hypot(g['tol1']['f_Hb'], g['tol2']['f_Hb']), CR=CR,
                Rz=(GEN['Rz'], r24.RZ_FLANK), sR=((g['root1']['df'] - GEN['hub_d']) / 2, r24.GEAR2_RIM * S1['mn']))]
    for p, T, n1, nm in ((OSG, T_OSG, n_gen, 'osg'), (PCU, T_PCU, N_MID, 'pcu')):
        g = r24.pair(p['z'][0], p['z'][1], p['m'], 0.0, p['b'], p['x'][0], p['x'][1], False, p['A'])
        dm1 = (g['da1'] + g['root1']['df']) / 2
        dm2 = (g['da2'] + g['root2']['df']) / 2
        out.append(dict(name=nm, g=g, mat1=r24.EH, mat2=r24.EH, T1=T * p['z'][0] / p['z'][1], n1=n1, Kgam=1.0,
                        rev1=False, rev2=False,
                        kv=('pair', r24.mstar(dm1, p['bore'][0] / dm1, g['db1']),
                            r24.mstar(dm2, p['bore'][1] / dm2, g['db2'])),
                        ksh=0.023 * (p['b'] / g['d1']) ** 2, fma=np.hypot(g['tol1']['f_Hb'], g['tol2']['f_Hb']),
                        CR=1.0, Rz=(p['Rz'], p['Rz']),
                        sR=((g['root1']['df'] - p['bore'][0]) / 2, (g['root2']['df'] - p['bore'][1]) / 2)))
    return out


# ---------------------------------------------------------------- shear neck
def neck(Tmax):
    tau_u = NECK['tau_ratio'] * NECK['su']
    d = (16 * NECK['k_shear'] * Tmax * 1e3 / (np.pi * tau_u)) ** (1 / 3)
    d = max(np.ceil(10 * d - 1e-9) / 10, NECK['d_min'])
    T = lambda dd, tu: np.pi * dd ** 3 * tu / 16 / 1e3
    tau_m = 16 * NECK['k_fat'] * Tmax * 1e3 / (np.pi * d ** 3)
    tau_a = NECK['ripple'] * tau_m
    kb = 1.24 * d ** -0.107 if d <= 51 else 1.51 * d ** -0.157
    Se = min(0.5 * NECK['su'], 700) * NECK['ka'][0] * NECK['su'] ** NECK['ka'][1] * kb * NECK['ke']
    nf = 1 / (np.sqrt(3) * NECK['Kfs'] * tau_a / Se + np.sqrt(3) * NECK['Kfs'] * tau_m / NECK['su'])
    return dict(d=d, T_nom=T(d, tau_u), T_lo=T(d - NECK['tol'], tau_u * (1 - NECK['scatter'])),
                T_hi=T(d + NECK['tol'], tau_u * (1 + NECK['scatter'])), n_f=nf)


# ---------------------------------------------------------------- deep groove ball bearing
XY = np.array([[0.172, 0.19, 2.30], [0.345, 0.22, 1.99], [0.689, 0.26, 1.71], [1.03, 0.28, 1.55],
               [1.38, 0.30, 1.45], [2.07, 0.34, 1.31], [3.45, 0.38, 1.15], [5.17, 0.42, 1.04], [6.89, 0.44, 1.00]])


def dgbb_life(b, r, Fr, Fa, n, nu, eC=0.6):
    q = np.clip(r['f0'] * Fa / r['C0'], XY[0, 0], XY[-1, 0])
    e = np.interp(q, XY[:, 0], XY[:, 1])
    Y = np.interp(q, XY[:, 0], XY[:, 2])
    P = 0.56 * Fr + Y * Fa if Fa > e * Fr else Fr
    nu1 = 45000 * n ** -0.83 * r['dm'] ** -0.5 if n < 1000 else 4500 * n ** -0.5 * r['dm'] ** -0.5
    kappa = min(max(nu / nu1, 0.1), 4.0)
    a = r25.a_iso('DGBB', kappa, eC * r['Cu'] / P)
    L10 = (r['C'] / P) ** 3 * 1e6 / (60 * n)
    return dict(P=P, kappa=kappa, a=a, L10m=a * L10)


# ---------------------------------------------------------------- main
def main():
    rows = []
    add = lambda tc, q, v: rows.append((tc, q, float(v)))
    # TC45
    for m in meshes():
        r = r24.rate(m, m['T1'], m['n1'], KA, 1.0, 'ref')
        for q, k in (('Kv', 'Kv'), ('KHb', 'KHb'), ('S_H1', 'S_H1'), ('S_H2', 'S_H2'), ('S_F1', 'S_F1'),
                     ('S_F2', 'S_F2')):
            add('TC45', '%s_%s' % (m['name'], q), r[k])
    # TC46
    for nm, T in (('gen', T_GEN_MAX), ('osg', T_OSG)):
        s = neck(T)
        for q in ('d', 'T_nom', 'T_lo', 'T_hi', 'n_f'):
            add('TC46', '%s_%s' % (nm, q), s[q])
    # TC47
    b = dict(type='DGBB', Z=8, Dw=11.0, Lwe=0.0, Dpw=43.5, alpha=0.0, i=1)
    r = r25.rating(b)
    add('TC47', 'C', r['C'])
    add('TC47', 'C0', r['C0'])
    n_gen = N_MID * S1['z2'] / GEN['z']
    for nm, Fr, Fa in (('gen', 477.3, 190.0), ('radial', 2000.0, 100.0), ('axial', 0.0, 1500.0)):
        L = dgbb_life(b, r, Fr, Fa, n_gen, 4.23)
        add('TC47', nm + '_P', L['P'])
        add('TC47', nm + '_a', L['a'])
        add('TC47', nm + '_L10m', L['L10m'])
    # TC48
    g = r24.pair(PCU['z'][0], PCU['z'][1], PCU['m'], 0.0, PCU['b'], PCU['x'][0], PCU['x'][1], False, PCU['A'])
    pw = dict(r_in=PCU['hub_d'] / 2, r_out=g['root2']['df'] / 2 - 3.5 * PCU['m'], t=PCU['b'], b_rim=PCU['b'],
              s_rim=3.5 * PCU['m'], s_mass=3.5 * PCU['m'] + 0.5 * g['h2'])
    for n in range(4):
        add('TC48', 'pcu_web_n%d' % n, r24.web_ritz(pw, n))

    with open(OUT, 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['tc', 'quantity', 'expected'])
        for tc, q, v in rows:
            w.writerow([tc, q, '%.10g' % v])
    for tc, q, v in rows:
        print('%-5s %-20s %.6g' % (tc, q, v))
    print('%d values written to %s' % (len(rows), os.path.normpath(OUT)))


if __name__ == '__main__':
    main()
