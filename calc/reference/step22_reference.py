"""Expected values for the step 2.2 MATLAB tests (calc/tests/step22_test_cases.csv).

    python calc/reference/step22_reference.py        (needs numpy and scipy; rotordynamics/.venv has both)

An independent Python implementation of the step 2.2 checks. The diaphragm plate problems are solved here
with scipy's boundary value solver on the plate differential equation, not with the closed-form solution
the MATLAB tool uses, so the two agree only if both are right. Test cases (SI units, speeds in rpm):

TC24  Floating shaft 60 x 2 mm, 0.55 m, k_theta 50 N m/rad, M_bend 0.5 N m: shear stresses, twist, fatigue
      and buckling safeties, first bending critical speed (Timoshenko finite elements, end masses and
      springs), and the simply supported closed-form Timoshenko frequency for the same tube.
TC25  Flat diaphragm a 65 mm, b 32.5 mm, t 1.0 mm, 15-5PH: axial and angular stiffness and the stress per
      unit offset and per unit tilt; and the axial compliance with b = 0.001 a against the clamped plate
      with a central load, w = P a^2 / (16 pi D).
TC26  The same diaphragm with the step 2.2 loads: fatigue, static, burst and buckling safeties.
TC27  Torque meter on the TC24 shaft: twist at T_100, resolution, resolution error.
TC28  PT rear bearing: running and limit loads, L10, minimum load.
TC29  Shaft tunnel, 60 mm shaft, 0.55 m, 7.5 g/s, gas 700 degC: air outlet and hottest shaft temperature,
      heat through the insulation, windage power.

Source: Phase 2 report, Section 2.2 ("Tests").
"""
import csv
import os

import numpy as np
from scipy.integrate import solve_bvp, trapezoid
from scipy.linalg import eigh

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tests', 'step22_test_cases.csv')

# Inputs, as in calc/pt_shaft/ptshaft_inputs.m
T100 = 895e3 / (22000 * np.pi / 30)
TMC = 417.33
TLIM = 1.375 * T100
TALT = 0.10
NPT, NOVER, NBRK = 22000.0, 24200.0, 1.30 * 22000
E_S, NU_S, RHO_S, SU_S, SY_S = 205e9, 0.29, 7850.0, 1240e6, 1100e6
KT, KA, KE = 1.6, 0.84, 0.753
M_HALF, K_RAD = 1.2, 5e8
L_MEAS = 0.45
DIA = dict(E=196e9, nu=0.27, rho=7800.0, su=1070e6, sy=1000e6, Se=0.45 * 1070e6 * 0.9 * 0.814)
MIS_TH, MIS_THX, MIS_AX, MIS_AXX = 0.25, 0.5, 0.75e-3, 1.5e-3


def timoshenko(L, do, di, E, nu, rho):
    """Planar Timoshenko element (w1, phi1, w2, phi2): K, M (translational + rotary)."""
    G = E / (2 * (1 + nu))
    A = np.pi / 4 * (do**2 - di**2)
    I = np.pi / 64 * (do**4 - di**4)
    m = di / do
    kap = 6 * (1 + nu) * (1 + m**2)**2 / ((7 + 6 * nu) * (1 + m**2)**2 + (20 + 12 * nu) * m**2)
    ph = 12 * E * I / (kap * G * A * L**2)
    K = E * I / ((1 + ph) * L**3) * np.array([
        [12, 6 * L, -12, 6 * L],
        [6 * L, (4 + ph) * L**2, -6 * L, (2 - ph) * L**2],
        [-12, -6 * L, 12, -6 * L],
        [6 * L, (2 - ph) * L**2, -6 * L, (4 + ph) * L**2]])
    a = [312 + 588 * ph + 280 * ph**2, (44 + 77 * ph + 35 * ph**2) * L, 108 + 252 * ph + 140 * ph**2,
         -(26 + 63 * ph + 35 * ph**2) * L, (8 + 14 * ph + 7 * ph**2) * L**2, -(6 + 14 * ph + 7 * ph**2) * L**2]
    Mt = rho * A * L / (840 * (1 + ph)**2) * np.array([
        [a[0], a[1], a[2], a[3]], [a[1], a[4], -a[3], a[5]], [a[2], -a[3], a[0], -a[1]], [a[3], a[5], -a[1], a[4]]])
    r1, r2, r3 = (3 - 15 * ph) * L, (4 + 5 * ph + 10 * ph**2) * L**2, (-1 - 5 * ph + 5 * ph**2) * L**2
    Mr = rho * I / (30 * (1 + ph)**2 * L) * np.array([
        [36, r1, -36, r1], [r1, r2, -r1, r3], [-36, -r1, 36, -r1], [r1, r3, -r1, r2]])
    return K, Mt + Mr, kap, A, I


def tc24():
    D, t, L, kth, Mb = 0.060, 0.002, 0.55, 50.0, 0.5
    d = D - 2 * t
    r = D / 2
    A = np.pi / 4 * (D**2 - d**2)
    I = np.pi / 64 * (D**4 - d**4)
    J = 2 * I
    G = E_S / (2 * (1 + NU_S))
    rows = [('TC24', 'tau_MC', TMC * r / J, 'Pa'), ('TC24', 'tau_lim', TLIM * r / J, 'Pa'),
            ('TC24', 'twist_100', T100 * L_MEAS / (G * J) * 180 / np.pi, 'deg')]
    rm = (D - t) / 2
    rows.append(('TC24', 'n_buck', 0.78 * E_S * (t / rm)**1.25 / np.sqrt(L / rm) / (TLIM * r / J), '-'))
    dmm = D * 1e3
    kb = 1.24 * dmm**-0.107 if dmm <= 51 else 1.51 * dmm**-0.157
    Se = 0.5 * SU_S * KA * kb * KE
    tm, ta, sa = KT * TMC * r / J, KT * TALT * TMC * r / J, Mb * r / I
    rows.append(('TC24', 'n_f', 1 / (np.sqrt(sa**2 + 3 * ta**2) / Se + np.sqrt(3) * tm / SU_S), '-'))
    ne = 20
    Ke, Me, *_ = timoshenko(L / ne, D, d, E_S, NU_S, RHO_S)
    nd = 2 * (ne + 1)
    K, M = np.zeros((nd, nd)), np.zeros((nd, nd))
    for k in range(ne):
        q = np.arange(2 * k, 2 * k + 4)
        K[np.ix_(q, q)] += Ke
        M[np.ix_(q, q)] += Me
    for q in (0, nd - 2):
        K[q, q] += K_RAD
        M[q, q] += M_HALF
    for q in (1, nd - 1):
        K[q, q] += kth
    w = np.sqrt(np.abs(eigh(K, M, eigvals_only=True)))
    rows.append(('TC24', 'n_cr', w.min() * 30 / np.pi, 'rpm'))
    # simply supported closed-form Timoshenko frequency, same tube
    m = d / D
    kap = 6 * (1 + NU_S) * (1 + m**2)**2 / ((7 + 6 * NU_S) * (1 + m**2)**2 + (20 + 12 * NU_S) * m**2)
    k = np.pi / L
    aa = RHO_S**2 * I / (kap * G)
    bb = -(RHO_S * A + RHO_S * I * k**2 * (1 + E_S / (kap * G)))
    cc = E_S * I * k**4
    w2 = (-bb - np.sqrt(bb**2 - 4 * aa * cc)) / (2 * aa)
    rows.append(('TC24', 'n_ss', np.sqrt(w2) * 30 / np.pi, 'rpm'))
    return rows, J


def plate(a, b, t, E, nu):
    """Clamped-clamped annular plate by solve_bvp: axial compliance, stress per offset, tilt stiffness and
    stress per tilt."""
    D = E * t**3 / (12 * (1 - nu**2))
    r = np.linspace(b, a, 400)
    # Axisymmetric: y = [w, w', w'', w''']; plate equation  (d2/dr2 + 1/r d/dr)^2 w = 0 written as
    # w'''' = -2 w'''/r + w''/r^2 - w'/r^3
    P = 1.0

    def f0(x, y):
        return np.vstack([y[1], y[2], y[3], -2 * y[3] / x + y[2] / x**2 - y[1] / x**3])

    def bc0(ya, yb):
        # at r = b: slope 0, shear: Q = -D (w''' + w''/r - w'/r^2), 2 pi b Q = P (load pushing the hub)
        Qb = -D * (ya[3] + ya[2] / b - ya[1] / b**2)
        return np.array([ya[1], 2 * np.pi * b * Qb - P, yb[0], yb[1]])

    s0 = solve_bvp(f0, bc0, r, np.zeros((4, r.size)), tol=1e-10, max_nodes=200000)
    w_b = s0.sol(b)[0]
    yb, ya = s0.sol(b), s0.sol(a)
    Mr = lambda y, x: -D * (y[2] + nu * y[1] / x)  # noqa: E731
    k_ax = P / abs(w_b)
    s_ax = max(abs(Mr(yb, b)), abs(Mr(ya, a))) * 6 / t**2 / abs(w_b)

    # First harmonic: (d2/dr2 + 1/r d/dr - 1/r^2)^2 W = 0
    # expanded: W'''' + 2 W'''/r - 3 W''/r^2 + 3 W'/r^3 - 3 W/r^4 = 0
    th = 1.0

    def f1(x, y):
        return np.vstack([y[1], y[2], y[3],
                          -2 * y[3] / x + 3 * y[2] / x**2 - 3 * y[1] / x**3 + 3 * y[0] / x**4])

    def bc1(ya, yb):
        return np.array([ya[0] - th * b, ya[1] - th, yb[0], yb[1]])

    guess = np.vstack([th * b * (a - r) / (a - b), -th * b / (a - b) * np.ones_like(r), 0 * r, 0 * r])
    s1 = solve_bvp(f1, bc1, r, guess, tol=1e-10, max_nodes=200000)
    rr = np.linspace(b, a, 20001)
    W, dW, d2W = s1.sol(rr)[0], s1.sol(rr)[1], s1.sol(rr)[2]
    q = dW / rr - W / rr**2
    U = D / 2 * np.pi * trapezoid(((d2W + q)**2 - 2 * (1 - nu) * (d2W * q - q**2)) * rr, rr)
    k_th = 2 * U / th**2
    MrT = -D * (d2W + nu * q)
    s_th = max(abs(MrT[0]), abs(MrT[-1])) * 6 / t**2 / th
    return dict(k_ax=k_ax, s_ax=s_ax, k_th=k_th, s_th=s_th, D=D)


def tc25():
    a, b, t = 0.065, 0.0325, 0.0010
    p = plate(a, b, t, DIA['E'], DIA['nu'])
    rows = [('TC25', 'k_ax', p['k_ax'], 'N/m'), ('TC25', 's_ax', p['s_ax'], 'Pa/m'),
            ('TC25', 'k_th', p['k_th'], 'N m/rad'), ('TC25', 's_th', p['s_th'], 'Pa/rad')]
    D = p['D']
    rows.append(('TC25', 'k_ax_point_load', 16 * np.pi * D / a**2, 'N/m'))
    return rows, p


def tc26(p):
    a, b, t = 0.065, 0.0325, 0.0010
    nu, rho = DIA['nu'], DIA['rho']
    th, thx = np.radians(MIS_TH), np.radians(MIS_THX)
    tq = lambda T: T / (2 * np.pi * b**2 * t)  # noqa: E731
    hoop = lambda n: (3 + nu) / 4 * rho * (n * np.pi / 30)**2 * (a**2 + (1 - nu) / (3 + nu) * b**2)  # noqa: E731
    sr, st = p['s_ax'] * MIS_AX, hoop(NPT)
    sm = np.sqrt(sr**2 + st**2 - sr * st + 3 * tq(TMC)**2)
    sa = np.sqrt((p['s_th'] * th)**2 + 3 * (TALT * tq(TMC))**2)
    n_f = 1 / (sa / DIA['Se'] + sm / DIA['su'])
    sr = p['s_ax'] * MIS_AXX + p['s_th'] * thx
    st = hoop(NOVER)
    n_static = DIA['sy'] / np.sqrt(sr**2 + st**2 - sr * st + 3 * tq(TLIM)**2)
    n_burst = DIA['su'] / hoop(NBRK)
    tau_cr = 8.98 * np.pi**2 * p['D'] / (t * (a - b)**2)
    return [('TC26', 'n_f', n_f, '-'), ('TC26', 'n_static', n_static, '-'),
            ('TC26', 'n_burst', n_burst, '-'), ('TC26', 'n_buck', tau_cr / tq(TLIM), '-'),
            ('TC26', 'F_ax', p['k_ax'] * MIS_AX, 'N'), ('TC26', 'M_mis', p['k_th'] * th, 'N m')]


def tc27(J):
    G = E_S / (2 * (1 + NU_S))
    tw = T100 * L_MEAS / (G * J) * 180 / np.pi
    res = NPT * np.pi / 30 * 20e-9 * 180 / np.pi
    return [('TC27', 'twist_100', tw, 'deg'), ('TC27', 'res', res, 'deg'), ('TC27', 'err_res', res / tw, '-')]


def tc28(F_coupling):
    m = 25 * 0.5
    w = NPT * np.pi / 30
    F1, Fu = m * 9.81, m * 2.5e-3 * w
    P = F1 + Fu + F_coupling
    Plim = 6.0 * F1 + Fu * (NOVER / NPT)**2 + F_coupling
    L10 = (78e3 / P)**(10 / 3) * 1e6 / (60 * NPT)
    dm = (50 + 90) / 2
    Frm = 0.15 * (6 + 4 * NPT / 11000) * (dm / 100)**2 * 1e3
    return [('TC28', 'P', P, 'N'), ('TC28', 'P_lim', Plim, 'N'), ('TC28', 'L10', L10, 'h'),
            ('TC28', 'F_rm', Frm, 'N')]


def tc29():
    D, L, m_air, T_gas = 0.060, 0.55, 0.0075, 700.0
    gap, t_ins, k_ins, h_gas, T_in, N = 0.010, 0.015, 0.06, 115.0, 60.0, 40
    cp, k_air, mu, Pr, R, p0 = 1007.0, 0.029, 2.0e-5, 0.71, 287.0, 101325.0
    rs, ri = D / 2, D / 2 + gap
    ro = ri + t_ins
    w = NPT * np.pi / 30
    dx = L / N
    Rout = 1 / (h_gas * 2 * np.pi * ro) + np.log(ro / ri) / (2 * np.pi * k_ins)
    Ta, Q, Pw, Tsmax = T_in, 0.0, 0.0, -1e9
    for _ in range(N):
        rho = p0 / (R * (Ta + 273.15))
        u = m_air / (rho * np.pi * (ri**2 - rs**2))
        Dh = 2 * gap
        Re = rho * np.hypot(u, w * rs / 2) * Dh / mu
        h = 0.023 * Re**0.8 * Pr**0.4 * k_air / Dh
        Rew = rho * w * rs * gap / mu
        pw = 0.5 * 0.065 * (gap / rs)**0.3 * Rew**-0.2 * np.pi * rho * w**3 * rs**4 * dx
        Tl = (T_gas / Rout + h * 2 * np.pi * ri * Ta) / (1 / Rout + h * 2 * np.pi * ri)
        q = (T_gas - Tl) / Rout * dx
        Tsmax = max(Tsmax, Ta + pw / (h * np.pi * D * dx))
        Ta += (q + pw) / (m_air * cp)
        Q += q
        Pw += pw
    return [('TC29', 'T_air_out', Ta, 'degC'), ('TC29', 'T_shaft_max', Tsmax, 'degC'),
            ('TC29', 'Q_in', Q, 'W'), ('TC29', 'P_wind', Pw, 'W')]


def main():
    r24, J = tc24()
    r25, p = tc25()
    r26 = tc26(p)
    M_mis = p['k_th'] * np.radians(MIS_TH)
    rows = r24 + r25 + r26 + tc27(J) + tc28(M_mis / 0.08) + tc29()
    with open(OUT, 'w', newline='') as fh:
        wr = csv.writer(fh)
        wr.writerow(['tc', 'quantity', 'expected', 'unit'])
        for tc, q, v, u in rows:
            wr.writerow([tc, q, '%.6g' % v, u])
    for r in rows:
        print('%-5s %-16s %14.6g %s' % r)
    print('Written %s' % os.path.normpath(OUT))


if __name__ == '__main__':
    main()
