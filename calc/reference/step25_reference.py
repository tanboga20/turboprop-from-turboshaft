"""Expected values for the step 2.5 MATLAB tests (calc/tests/step25_test_cases.csv).

    python calc/reference/step25_reference.py        (needs numpy and scipy; rotordynamics/.venv has both)

An independent Python implementation of the step 2.5 bearing, shaft and spline formulas and of the planet rim
model. Every test case gives the functions fixed inputs, so the cases do not depend on the gear model. Test cases:

TC40  Bearing ratings in the ISO 281 forms derived in ISO/TR 1281-1:2021: C, C0 and C_u of cylindrical roller
      bearings (below and above d_m = 100 mm, and the planet bearing) and of four-point contact ball bearings
      rated as double-row angular contact bearings; the ball C0 from the Hertz contact at 4,200 MPa.
TC41  Modified rating life: P, kappa, a_ISO and L10m over the three mission steps for roller and ball bearings,
      with both branches of the ball X and Y factors, both forms of nu1 and two kappa ranges of a_ISO.
TC42  Shaft sections: Goodman with the Marin factors, yield at limit load and rupture at ultimate load.
TC43  Involute splines (Dudley): tooth shear, flank pressure, root torsion and the safety factors.
TC44  Planet rim modes: a ring of frame elements as a free ring, on the loaded rollers (Stribeck load
      distribution, Palmgren contact stiffness) and with the two mesh springs. The free ring is also compared
      with the Hoppe closed form and the ball C0 with exact elliptic integrals (printed, not test values).

Source: Phase 2 report, Section 2.5 ("Tests").
"""
import csv
import os

import numpy as np
from scipy.linalg import eigh
from scipy.optimize import brentq
from scipy.special import ellipe, ellipk

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tests', 'step25_test_cases.csv')

# ---------------------------------------------------------------- inputs (sb_inputs.m)
SU, SY = 1240.0, 1100.0                      # AISI 4340 shafts
KF, KFS, KA_EXP, KE = 2.0, 1.6, (1.38, -0.067), 0.753
SPL_TAU_FAT, SPL_PC = 0.25, (100.0, 60.0)    # share of su; flank pressure limits fixed / crowned
ULT = 1.5
B_M = dict(CRB=1.1, QJ=1.3)
MISSION_T = np.array([1 / 30, 28 / 30, 1 / 30])


# ---------------------------------------------------------------- bearings
def hertz_q(Dw, g, fr, sigma):
    """Ball load giving the contact stress sigma at the inner raceway (Hamrock-Brewe approximations)."""
    Ep = 206e3 / (1 - 0.3 ** 2)
    rx = 2 / Dw + 2 * g / (Dw * (1 - g))
    ry = 2 / Dw - 1 / (fr * Dw)
    Rx, Ry = 1 / rx, 1 / ry
    k = 1.0339 * (Ry / Rx) ** 0.636
    Ek = 1.0003 + 0.5968 * Rx / Ry
    R = Rx * Ry / (Rx + Ry)
    # p_max = 3 Q / (2 pi a b) with a = (6 k^2 E Q R / (pi E'))^(1/3), b = (6 E Q R / (pi k E'))^(1/3)
    ab1 = (6 * k ** 2 * Ek * R / (np.pi * Ep)) ** (1 / 3) * (6 * Ek * R / (np.pi * k * Ep)) ** (1 / 3)
    p1 = 3 / (2 * np.pi * ab1)              # stress at Q = 1 N times Q^(1/3)
    return (sigma / p1) ** 3


def hertz_q_exact(Dw, g, fr, sigma):
    """The same with the exact elliptic integrals (for the printed check only)."""
    Ep = 206e3 / (1 - 0.3 ** 2)
    rx = 2 / Dw + 2 * g / (Dw * (1 - g))
    ry = 2 / Dw - 1 / (fr * Dw)
    sum_rho = rx + ry
    F = (rx - ry) / sum_rho

    def ecc(e2):                             # F(rho) as a function of e^2 = 1 - (b/a)^2
        K, E = ellipk(e2), ellipe(e2)
        return ((2 - e2) * E - 2 * (1 - e2) * K) / (e2 * E) - F

    e2 = brentq(ecc, 1e-9, 1 - 1e-12)
    K, E = ellipk(e2), ellipe(e2)
    kap = 1 / np.sqrt(1 - e2)
    a_star = (2 * kap ** 2 * E / np.pi) ** (1 / 3)
    b_star = (2 * E / (np.pi * kap)) ** (1 / 3)

    def pmax(Q):
        a = a_star * (3 * Q / (2 * sum_rho) * 2 / Ep) ** (1 / 3)
        b = b_star * (3 * Q / (2 * sum_rho) * 2 / Ep) ** (1 / 3)
        return 3 * Q / (2 * np.pi * a * b)
    return (sigma / pmax(1.0)) ** 3


def rating(b):
    a = np.radians(b['alpha'])
    g = b['Dw'] * np.cos(a) / b['Dpw']
    q = (1 - g) / (1 + g)
    dm = b['Dpw']
    out = dict(gamma=g)
    if b['type'] == 'CRB':
        fc = 551.13373 * 0.377 * 0.83 * g ** (2 / 9) * (1 - g) ** (29 / 27) / (1 + g) ** 0.25 \
            * (1 + (1.04 * q ** (143 / 108)) ** 4.5) ** (-2 / 9)
        C = B_M['CRB'] * fc * (b['i'] * b['Lwe'] * np.cos(a)) ** (7 / 9) * b['Z'] ** 0.75 * b['Dw'] ** (29 / 27)
        C0 = 44 * (1 - g) * b['i'] * b['Z'] * b['Lwe'] * b['Dw'] * np.cos(a)
        Cu = C0 / 8.2 * ((100 / dm) ** 0.3 if dm > 100 else 1.0)
    else:
        fr = 0.52
        fc = 98.0665 * 0.41 * 0.95 * (2 * fr / (2 * fr - 1)) ** 0.41 * g ** 0.3 * (1 - g) ** 1.39 \
            / (1 + g) ** (1 / 3) * (1 + (1.04 * q ** 1.72) ** (10 / 3)) ** (-0.3)
        C = B_M['QJ'] * fc * (b['i'] * np.cos(a)) ** 0.7 * b['Z'] ** (2 / 3) * b['Dw'] ** 1.8
        Q = hertz_q(b['Dw'], g, fr, 4200.0)
        C0 = b['i'] * b['Z'] * np.cos(a) * Q / 5
        Cu = C0 / 22 * ((100 / dm) ** 0.5 if dm > 100 else 1.0)
        out['f0'] = C0 / (b['i'] * b['Z'] * b['Dw'] ** 2 * np.cos(a))
        out['C0_exact'] = b['i'] * b['Z'] * np.cos(a) * hertz_q_exact(b['Dw'], g, fr, 4200.0) / 5
    out.update(fc=fc, C=C, C0=C0, Cu=Cu, dm=dm)
    return out


def a_iso(kind, kappa, x):
    if kind == 'CRB':
        A, w, ce = 1.5859, 0.4, 9.185
        Bs = (1.3993, 1.2348, 1.2348)
    else:
        A, w, ce = 2.5671, 0.83, 9.3
        Bs = (2.2649, 1.9987, 1.9987)
    ks = (0.054381, 0.19087, 0.071739)
    j = 0 if kappa < 0.4 else (1 if kappa < 1 else 2)
    br = 1 - (A - Bs[j] / kappa ** ks[j]) * x ** w
    return 50.0 if br <= 0 else min(0.1 * br ** (-ce), 50.0)


def life(b, r, Fr, Fa, n, nu, eC=0.6, t=MISSION_T):
    Fr, Fa = np.asarray(Fr, float), np.asarray(Fa, float)
    if b['type'] == 'CRB':
        p, P = 10 / 3, Fr.copy()
    else:
        p = 3.0
        P = np.where(Fa > 0.95 * Fr, 0.6 * Fr + 1.07 * Fa, Fr + 0.66 * Fa)
    nu1 = 45000 * n ** -0.83 * r['dm'] ** -0.5 if n < 1000 else 4500 * n ** -0.5 * r['dm'] ** -0.5
    kappa = min(max(nu / nu1, 0.1), 4.0)
    a = np.array([a_iso(b['type'], kappa, eC * r['Cu'] / PP) for PP in P])
    L10 = (r['C'] / P) ** p * 1e6 / (60 * n)
    L10m = a * L10
    return dict(P=P, kappa=kappa, a=a, L10=1 / np.sum(t / L10), L10m=1 / np.sum(t / L10m))


# ---------------------------------------------------------------- shafts and splines
def shaft(do, di, T, Malt, Fa, Tl, Ml, Fl):
    A = np.pi / 4 * (do ** 2 - di ** 2)
    Wb = np.pi / 32 * (do ** 4 - di ** 4) / do
    Wt = 2 * Wb
    sa = KF * Malt * 1e3 / Wb
    sm = np.hypot(Fa / A, np.sqrt(3) * KFS * T * 1e3 / Wt)
    kb = 1.24 * do ** -0.107 if do <= 51 else 1.51 * do ** -0.157
    ka = KA_EXP[0] * SU ** KA_EXP[1]
    Se = min(0.5 * SU, 700) * ka * kb * KE
    nf = 1 / (sa / Se + sm / SU)
    tl = Tl * 1e3 / Wt
    sl = np.sqrt((Ml * 1e3 / Wb + Fl / A) ** 2 + 3 * tl ** 2)
    return dict(S_e=Se, n_f=nf, n_y=SY / sl, n_u=SU / (ULT * sl))


def spline(m, z, L, Km, crowned, T, KA, Tl, di):
    D = m * z
    t = np.pi * D / (2 * z)
    h = 0.9 * m
    Dre = m * (z - 1.5)
    tau = 4 * T * 1e3 * Km * KA / (D * z * L * t)
    p = 2 * T * 1e3 * Km * KA / (D * z * L * h)
    tau_root = 16 * T * KA * 1e3 * Dre / (np.pi * (Dre ** 4 - di ** 4))
    tau_l = 4 * Tl * 1e3 * Km / (D * z * L * t)
    return dict(tau=tau, p=p, tau_root=tau_root, S_fat=SPL_TAU_FAT * SU / tau, S_static=0.577 * SY / tau_l,
                p_ratio=p / SPL_PC[1 if crowned else 0])


# ---------------------------------------------------------------- planet rim
def rim_modes(p, nmodes=3):
    N = p['nel']
    R = p['R'] / 1000
    phi = 2 * np.pi * np.arange(N) / N
    xy = R * np.column_stack([np.cos(phi), np.sin(phi)])
    E = p['E'] * 1e6
    A = p['b'] * p['h'] * 1e-6
    I = p['b'] * p['h'] ** 3 / 12 * 1e-12
    mA = p['rho'] * 1e9 * p['b'] * (p['h'] + p['h_teeth']) * 1e-6
    K = np.zeros((3 * N, 3 * N))
    M = np.zeros((3 * N, 3 * N))
    for e in range(N):
        i1, i2 = e, (e + 1) % N
        d = xy[i2] - xy[i1]
        L = np.hypot(*d)
        c, s = d / L
        ea, ei = E * A / L, E * I
        k = np.array([[ea, 0, 0, -ea, 0, 0],
                      [0, 12 * ei / L ** 3, 6 * ei / L ** 2, 0, -12 * ei / L ** 3, 6 * ei / L ** 2],
                      [0, 6 * ei / L ** 2, 4 * ei / L, 0, -6 * ei / L ** 2, 2 * ei / L],
                      [-ea, 0, 0, ea, 0, 0],
                      [0, -12 * ei / L ** 3, -6 * ei / L ** 2, 0, 12 * ei / L ** 3, -6 * ei / L ** 2],
                      [0, 6 * ei / L ** 2, 2 * ei / L, 0, -6 * ei / L ** 2, 4 * ei / L]])
        m = mA * L / 420 * np.array([[140, 0, 0, 70, 0, 0],
                                     [0, 156, 22 * L, 0, 54, -13 * L],
                                     [0, 22 * L, 4 * L ** 2, 0, 13 * L, -3 * L ** 2],
                                     [70, 0, 0, 140, 0, 0],
                                     [0, 54, 13 * L, 0, 156, -22 * L],
                                     [0, -13 * L, -3 * L ** 2, 0, -22 * L, 4 * L ** 2]])
        r3 = np.array([[c, s, 0], [-s, c, 0], [0, 0, 1]])
        Tr = np.block([[r3, np.zeros((3, 3))], [np.zeros((3, 3)), r3]])
        idx = np.r_[3 * i1:3 * i1 + 3, 3 * i2:3 * i2 + 3]
        K[np.ix_(idx, idx)] += Tr.T @ k @ Tr
        M[np.ix_(idx, idx)] += Tr.T @ m @ Tr

    def spring(angle, kk, u=None):
        j = int(np.argmin(np.abs(np.angle(np.exp(1j * (phi - angle))))))
        if u is None:
            u = np.array([np.cos(phi[j]), np.sin(phi[j])])
        idx = np.r_[3 * j:3 * j + 2]
        K[np.ix_(idx, idx)] += kk * np.outer(u, u)

    if p['Z'] > 0:
        qmax = 4.08 * p['F'] / p['Z']
        for kk in range(p['Z']):
            psi = 2 * np.pi * kk / p['Z']
            if np.cos(psi) <= 0:
                continue
            Q = qmax * np.cos(psi) ** (10 / 9)
            kc = Q ** 0.1 * p['Lwe'] ** 0.8 / (0.9 * 3.84e-5) * 1e3     # N/m, one line contact
            spring(psi, kc / 2)
    if p.get('k_mesh', 0) > 0:
        for sg in (1, -1):
            spring(sg * np.pi / 2, p['k_mesh'], np.array([np.cos(p['alpha']), -sg * np.sin(p['alpha'])]))
    lam = eigh(K, M, eigvals_only=True)
    lam = np.sort(lam[lam > (2 * np.pi * 10) ** 2])
    return np.sqrt(lam[:nmodes]) / (2 * np.pi)


def hoppe(p, n):
    I = p['b'] * p['h'] ** 3 / 12
    m = p['rho'] * p['b'] * (p['h'] + p['h_teeth'])
    c = np.sqrt(p['E'] * 1e6 * I * 1e-12 / (m * 1e3 * (p['R'] / 1000) ** 4))
    return n * (n ** 2 - 1) / np.sqrt(n ** 2 + 1) * c / (2 * np.pi)


# ---------------------------------------------------------------- main
def main():
    rows = []
    add = lambda tc, q, v: rows.append((tc, q, float(v)))
    brg = dict(crb1=dict(type='CRB', Z=14, Dw=11.0, Lwe=16.0, Dpw=65.0, alpha=0.0, i=1),
               crb2=dict(type='CRB', Z=26, Dw=15.0, Lwe=16.0, Dpw=150.0, alpha=0.0, i=1),
               planet=dict(type='CRB', Z=18, Dw=7.5, Lwe=56.0, Dpw=45.5, alpha=0.0, i=1),
               qj1=dict(type='QJ', Z=13, Dw=12.7, Lwe=0.0, Dpw=65.0, alpha=35.0, i=2),
               qj2=dict(type='QJ', Z=21, Dw=19.05, Lwe=0.0, Dpw=150.0, alpha=35.0, i=2))
    R = {k: rating(b) for k, b in brg.items()}
    # TC40
    for k in brg:
        for q in ('C', 'C0', 'Cu'):
            add('TC40', '%s_%s' % (k, q), R[k][q])
    add('TC40', 'qj1_f0', R['qj1']['f0'])
    # TC41
    L = life(brg['planet'], R['planet'], [19000, 10000, 7000], [0, 0, 0], 5471, 4.23)
    add('TC41', 'planet_kappa', L['kappa'])
    for j in range(3):
        add('TC41', 'planet_a%d' % (j + 1), L['a'][j])
    add('TC41', 'planet_L10', L['L10'])
    add('TC41', 'planet_L10m', L['L10m'])
    L = life(brg['qj1'], R['qj1'], [0, 0, 0], [3500, 1800, 1100], 22000, 4.23)
    add('TC41', 'qj1ax_P1', L['P'][0])
    add('TC41', 'qj1ax_a1', L['a'][0])
    add('TC41', 'qj1ax_L10m', L['L10m'])
    L = life(brg['qj1'], R['qj1'], [2000, 2000, 2000], [1000, 3000, 500], 22000, 4.23)
    for j in range(3):
        add('TC41', 'qj1mix_P%d' % (j + 1), L['P'][j])
    add('TC41', 'qj1mix_L10m', L['L10m'])
    L = life(brg['qj2'], R['qj2'], [0, 0, 0], [18000, 3000, 2000], 1701, 2.0)
    add('TC41', 'qj2_kappa', L['kappa'])
    add('TC41', 'qj2_a1', L['a'][0])
    add('TC41', 'qj2_a2', L['a'][1])
    add('TC41', 'qj2_L10m', L['L10m'])
    L = life(brg['crb2'], R['crb2'], [20000, 20000, 20000], [0, 0, 0], 800, 4.23)
    add('TC41', 'crb2slow_kappa', L['kappa'])
    add('TC41', 'crb2slow_a1', L['a'][0])
    add('TC41', 'crb2slow_L10m', L['L10m'])
    # TC42
    for name, args in (('s50', (50, 30, 2000, 0, 3243, 6891, 0, 4600)),
                       ('s120', (120, 100, 30600, 2470, 18000, 23754, 8360, 20000))):
        s = shaft(*args)
        for q in ('S_e', 'n_f', 'n_y', 'n_u'):
            add('TC42', '%s_%s' % (name, q), s[q])
    # TC43
    for name, sp in (('fixed', (1.5, 30, 40, 1.3, False)), ('crowned', (1.5, 30, 56, 1.5, True))):
        s = spline(*sp, 1378.6, 1.25, 6891, 30)
        for q in ('tau', 'p', 'tau_root', 'S_fat', 'S_static', 'p_ratio'):
            add('TC43', '%s_%s' % (name, q), s[q])
    # TC44
    p = dict(R=30.5, h=8.0, b=70.0, h_teeth=2.25, E=206e3, rho=7.83e-6, Z=0, Dw=7.5, Lwe=56.0, F=19091.0,
             nel=144, k_mesh=0.0, alpha=np.radians(20.0))
    f = rim_modes(p)
    add('TC44', 'free_f1', f[0])
    add('TC44', 'free_f3', f[2])
    fh = hoppe(p, 2)
    p['Z'] = 18
    f = rim_modes(p)
    for j in range(3):
        add('TC44', 'rollers_f%d' % (j + 1), f[j])
    p['k_mesh'] = 1.41e9
    f = rim_modes(p)
    for j in range(3):
        add('TC44', 'mesh_f%d' % (j + 1), f[j])

    with open(OUT, 'w', newline='') as fh_:
        w = csv.writer(fh_)
        w.writerow(['tc', 'quantity', 'expected'])
        for tc, q, v in rows:
            w.writerow([tc, q, '%.10g' % v])
    for tc, q, v in rows:
        print('%-5s %-20s %.6g' % (tc, q, v))
    print('%d values written to %s' % (len(rows), os.path.normpath(OUT)))
    print('checks: free ring n = 2 Hoppe %.1f Hz against the frame elements %.1f Hz; ball C0 with exact elliptic '
          'integrals %.0f / %.0f N against Hamrock-Brewe %.0f / %.0f N'
          % (fh, [r for r in rows if r[1] == 'free_f1'][0][2], R['qj1']['C0_exact'], R['qj2']['C0_exact'],
             R['qj1']['C0'], R['qj2']['C0']))


if __name__ == '__main__':
    main()
