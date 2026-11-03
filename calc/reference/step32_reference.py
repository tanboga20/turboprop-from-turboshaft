"""Expected values for the step 3.2 MATLAB tests (calc/tests/step32_test_cases.csv).

    python calc/reference/step32_reference.py        (needs numpy and scipy; rotordynamics/.venv has both)

An independent Python implementation of the step 3.2 oil network (calc/oil_system). The network description
(galleries, jets, orifices) and the values taken from steps 2.7 and 3.1 (pump delivery, cooler pressure drop,
cruise losses, masses) are read from cad/params/oil_network.txt, written by MATLAB; the physics is re-coded here
from the inputs copied from calc/oil_system/os_inputs.m and calc/lubrication/lb_inputs.m. Each row carries its
own relative tolerance. Test cases:

TC67  Maximum continuous power: manifold and pump outlet pressures, flows (network, regulating valve), every jet
      flow and the lowest jet pressure.
TC68  Ground idle (60% pump speed, 100 degC): manifold pressure, network flow, lowest jet flow ratio.
TC69  Cold start: at -40 degC the relief flow and the filter bypass; the temperature from which every jet has half
      its design flow and the warm-up time to it.
TC70  Pump inlet at 45,000 ft (hot), at -1.27 g and cold at sea level; negative-g endurance.
TC71  Running without oil (LUB-07): reservoir volumes and masses, and the run-dry times of options A, B, C with
      and without the case heat path.
TC72  Emergency air-oil mist (LUB-07 option): time to 230 degC and steady parts temperature at A-05 cruise and at
      75% MCP, without measures and with 10 and 20 SCFM of mist air (lubricated friction), and the system mass for
      6 and 30 min at 0.3 and 1 mL/min per contact.
TC73  Mass of the weighed oil hardware for SYS-06 (jet nozzles, external tubes with fittings, transfer sleeve,
      titanium pitch tube; CATIA volumes from cad/assy/part_volumes.csv) and of the LUB-07 mist system (6 min at
      1 mL/min per contact with a 1.5 volume margin).

Source: Phase 3 report, Section 3.2 ("Tests").
"""
import csv
import math
import os

import numpy as np
from scipy.optimize import brentq

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
OUT = os.path.join(HERE, '..', 'tests', 'step32_test_cases.csv')

# ---------------------------------------------------------------- inputs (os_inputs.m, lb_inputs.m)
NU40, NU100, RHO15, ALPHA, CP = 27.6, 5.1, 1003.5, 7.0e-4, 2000.0
NU_COLD = 11000.0
P_REG, P_RELIEF = 550.0, 1100.0
DPF_CLEAN, DPF_BYPASS, DPC_BYPASS = 35.0, 170.0, 240.0
T_THERMO = 60.0
DP_STRAINER = 8.0
LINES = {'suction': (150, 32, 1), 'pump_filter': (250, 12, 2), 'filter_cooler': (1500, 16, 4),
         'cooler_rgb': (1500, 16, 4)}
K_BEND, CD_INF, L_D = 0.4, 0.70, 2.0
OPS = [('MC', 1.00, 100.0), ('ground idle', 0.60, 100.0), ('cold start', 0.60, -40.0)]
ALT_FT, P_TANK, H_TANK, P_IN_MIN, V_USABLE, G_NEG = 45000, 34.5, 150.0, 35.0, 5.69, -1.27
T_START, T_LIMIT, Q_DRIP, RHO_RES, MARGIN = 110.0, 230.0, (0.02, 0.05, 0.10), 1.4, 2.34
T_DRIP, G_PC, HA, T_AMB = 100.0, 30.0, 40.0, 53.0
M_WARM, C_MET, V_OIL, P_IDLE, Q_OK, M_RGB = 0.3, 0.5, 6.8, 2.5, 0.5, 107.66
T_LUB07 = 1800.0


def params(name):
    d = {}
    with open(os.path.join(ROOT, 'cad', 'params', name + '.txt'), encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                k, v = line.split('=', 1)
                d[k.strip()] = [float(x) for x in v.split()]
    return d


def walther(T, nu_a, Ta, nu_b, Tb):
    W = lambda nu: math.log10(math.log10(nu + 0.7))
    b = (W(nu_a) - W(nu_b)) / (math.log10(Ta + 273.15) - math.log10(Tb + 273.15))
    return 10 ** (10 ** (W(nu_b) + b * (math.log10(T + 273.15) - math.log10(Tb + 273.15)))) - 0.7


def oil(T):
    nu = walther(T, NU40, 40, NU100, 100) if T >= 40 else walther(T, NU_COLD, -40, NU40, 40)
    return nu, RHO15 * (1 - ALPHA * (T - 15))


class Net:
    def __init__(self, p):
        self.p = p
        self.branches = []
        for k in range(1, int(p['n_branch'][0]) + 1):
            Lg, dg, nb, rot, rr, nj = p['branch%d' % k]
            jets = [p['jet%d_%d' % (k, j)] for j in range(1, int(nj) + 1)]
            self.branches.append(dict(L=Lg, d=dg, nb=nb, rot=rot > 0.5, r_rot=rr, jets=jets))


def solve(net, n, T, nu, rho):
    """Manifold-centred solution of one operating point (independent of the MATLAB nesting)."""
    P = net.p
    w = 2 * math.pi * 1700 / 60 * n
    dbr = P['d_branch'][0]

    def pipe(Q, L, d, nb):
        A = math.pi / 4 * (d * 1e-3) ** 2
        v = Q / 6e4 / A
        Re = max(v * d * 1e-3 / (nu * 1e-6), 1e-9)
        if Re < 2300:
            return 64 / Re * L / d * rho * v * v / 2e3
        return (0.316 * Re ** -0.25 * L / d + K_BEND * nb) * rho * v * v / 2e3

    def orifice(Q, d, Qd):
        A = math.pi / 4 * (d * 1e-3) ** 2
        v = Q / 6e4 / A
        Re = max(v * d * 1e-3 / (nu * 1e-6), 1e-9)
        Cd = 1 / (1 / CD_INF + 20 * (1 + 2.25 * L_D) / Re)
        s = 0.0 if math.isinf(Qd) else DP_STRAINER * (Q / Qd) ** 2      # Qd: the strainer's rated flow
        return rho / 2 * (v / Cd) ** 2 / 1e3 + s

    def jet_q(ph, b, jt):
        d, Ld, Qd, r, Qn = jt[:5]
        boost = rho * w * w * ((r * 1e-3) ** 2 - (b['r_rot'] * 1e-3) ** 2) / 2e3 if b['rot'] else 0.0
        pa = ph + boost
        if pa <= 0:
            return 0.0
        return brentq(lambda Q: pipe(Q, Ld, dbr, 1) + orifice(Q, d, Qn) - pa, 0, 1e3, xtol=1e-14, rtol=1e-13)

    def branch(pm, b):
        tot = lambda ph: sum(jet_q(ph, b, jt) for jt in b['jets'])
        A = math.pi / 4 * (b['d'] * 1e-3) ** 2
        Kin = 1.5 if b['rot'] else 0.0
        h = lambda ph: pm - pipe(tot(ph), b['L'], b['d'], b['nb']) - Kin * rho / 2 * (tot(ph) / 6e4 / A) ** 2 / 1e3 - ph
        if h(0) <= 0:
            return 0.0, 0.0
        ph = brentq(h, 0, pm, xtol=1e-12, rtol=1e-13)
        return tot(ph), ph

    def orif_q(p, d):
        return 0.0 if p <= 0 else brentq(lambda Q: orifice(Q, d, math.inf) - p, 0, 1e3, xtol=1e-14, rtol=1e-13)

    def demand(pm):
        return sum(branch(pm, b)[0] for b in net.branches) + orif_q(pm, P['d_pcu'][0]) + orif_q(pm, P['d_leak'][0])

    loop = T >= T_THERMO

    def supply(Q):
        dpf = DPF_CLEAN * (Q / 30) * (nu / 5.1)
        byf = dpf > DPF_BYPASS
        dpf = min(dpf, DPF_BYPASS)
        dp = pipe(Q, *LINES['pump_filter']) + dpf
        if loop:
            dpc = min(P['cool_dp0'][0] * (Q / P['cool_Q0'][0]) * (nu / P['cool_nu0'][0]), DPC_BYPASS)
            dp += pipe(Q, *LINES['filter_cooler']) + dpc + pipe(Q, *LINES['cooler_rgb'])
        return dp, byf

    Qp = P['Qp100'][0] * n
    Dreg = demand(P_REG)
    if Dreg <= Qp:
        pm, qnet = P_REG, Dreg
    else:
        pm = brentq(lambda p: demand(p) - Qp, 1e-6, P_REG, xtol=1e-12)
        qnet = Qp
    dps, byf = supply(Qp)
    pout, qrel = pm + dps, 0.0
    if pout > P_RELIEF:
        pmq = lambda Q: brentq(lambda p: demand(p) - Q, 0, P_REG, xtol=1e-12)
        Qd = brentq(lambda Q: pmq(min(Q, Dreg)) + supply(Q)[0] - P_RELIEF, 1e-6, Qp, xtol=1e-12)
        qrel = Qp - Qd
        if Qd <= Dreg:
            qnet, pm = Qd, pmq(Qd)
        dps, byf = supply(Qd)
        pout = pm + dps
    jets = []
    for b in net.branches:
        qb, ph = branch(pm, b)
        for jt in b['jets']:
            q = jet_q(ph, b, jt)
            boost = rho * w * w * ((jt[3] * 1e-3) ** 2 - (b['r_rot'] * 1e-3) ** 2) / 2e3 if b['rot'] else 0.0
            pj = ph + boost - pipe(q, jt[1], dbr, 1) - DP_STRAINER * (q / jt[4]) ** 2
            jets.append((q, jt[2], pj))
    return dict(pm=pm, pout=pout, Qp=Qp, qnet=qnet, prv=max(Qp - qrel - qnet, 0), qrel=qrel, byf=byf, jets=jets)


def main():
    rows = []
    add = lambda tc, q, v, tol=1e-3: rows.append((tc, q, float(v), tol))
    P = params('oil_network')
    net = Net(P)
    res = {}
    for name, n, T in OPS:
        nu, rho = oil(T)
        res[name] = solve(net, n, T, nu, rho)
    S = res['MC']
    add('TC67', 'p_m', S['pm'])
    add('TC67', 'p_out', S['pout'])
    add('TC67', 'Q_net', S['qnet'])
    add('TC67', 'Q_prv', S['prv'])
    add('TC67', 'p_jet_min', min(j[2] for j in S['jets']))
    for i, j in enumerate(S['jets'], 1):
        add('TC67', 'Q_jet%02d' % i, j[0])
    S = res['ground idle']
    add('TC68', 'p_m', S['pm'])
    add('TC68', 'Q_net', S['qnet'])
    add('TC68', 'ratio_min', min(j[0] / j[1] for j in S['jets']))
    S = res['cold start']
    add('TC69', 'Q_relief', S['qrel'])
    add('TC69', 'bypass_filter', 1.0 if S['byf'] else 0.0, 1e-3)
    Ts = [-40, -30, -20, -10, 0, 10, 20, 30, 40]
    ratio, ppump = [], []
    for T in Ts:
        nu, rho = oil(T)
        s = solve(net, 0.6, T, nu, rho)
        ratio.append(min(j[0] / j[1] for j in s['jets']))
        ppump.append(s['pout'] * s['Qp'] / 60)
    k = next(i for i, r in enumerate(ratio) if r >= Q_OK)
    T_ok = Ts[k - 1] + (Q_OK - ratio[k - 1]) * (Ts[k] - Ts[k - 1]) / (ratio[k] - ratio[k - 1])
    E = (V_OIL * RHO15 / 1000 * CP / 1000 + M_WARM * M_RGB * C_MET) * (T_ok + 40)
    Pw = P_IDLE + np.mean(ppump[:k + 1]) / 1000
    add('TC69', 'T_ok', T_ok, 5e-3)
    add('TC69', 't_ok', E / Pw, 5e-3)
    # TC70
    h = ALT_FT * 0.3048
    p_amb = 22.632 * math.exp(-9.80665 * (h - 11000) / (287.053 * 216.65))
    Qp = P['Qp100'][0]

    def suction(T):
        nu, rho = oil(T)
        Ls, ds, nb = LINES['suction']
        A = math.pi / 4 * (ds * 1e-3) ** 2
        v = Qp / 6e4 / A
        Re = v * ds * 1e-3 / (nu * 1e-6)
        if Re < 2300:
            f, K = 64 / Re, 0.0
        else:
            f, K = 0.316 * Re ** -0.25, K_BEND * nb
        return (f * Ls / ds + K + 1) * rho * v * v / 2e3, rho

    dph, rh = suction(100)
    dpc, rc = suction(-40)
    head = lambda rho, g: rho * 9.80665 * g * H_TANK * 1e-3 / 1e3
    add('TC70', 'p_in', p_amb + P_TANK + head(rh, 1) - dph)
    add('TC70', 'p_in_negg', p_amb + P_TANK + head(rh, G_NEG) - dph)
    add('TC70', 'p_in_cold', 101.325 + head(rc, 1) - dpc)
    add('TC70', 't_negg', V_USABLE / Qp * 60)
    # TC71
    n = 11
    for q in Q_DRIP:
        V = q * n * T_LUB07 / 60
        add('TC71', 'V_%g' % q, V)
        add('TC71', 'mass_%g' % q, V * RHO15 / 1000 + V * RHO_RES)
    V_fit = MARGIN / (RHO15 / 1000 + RHO_RES)
    t_fit = V_fit / (Q_DRIP[0] * n) * 60
    mdot = Q_DRIP[0] * n / 60 * RHO15 / 1000
    Pc, m1, m2 = P['P_cruise'][0], P['m_parts'][0], P['m_case'][0]

    def dry(md, tdrip, G, hA):
        T1 = T2 = T_START
        t = 0
        while T1 < T_LIMIT and t < 7200:
            qd = md * CP / 1000 * max(T1 - T_DRIP, 0) if t < tdrip else 0.0
            q12 = G / 1000 * (T1 - T2)
            q2a = hA / 1000 * (T2 - T_AMB)
            T1 += (Pc - qd - q12) / (m1 * 0.46)
            T2 += (q12 - q2a) / (m2 * 0.90)
            t += 1
        return t

    for lab, md, td in (('A', 0.0, 0.0), ('B', mdot, t_fit), ('C', mdot, T_LUB07)):
        add('TC71', 't_%s_parts' % lab, dry(md, td, 0.0, 0.0), 5e-3)
        add('TC71', 't_%s_case' % lab, dry(md, td, G_PC, HA), 5e-3)

    # TC72: emergency air-oil mist, friction uplift 1
    MIST = dict(T_air=100.0, eff=0.5, m_acc_per_L=1.2, m_acc_min=0.6, m_valve=0.3, m_lines=0.6, m_air=1.0)
    G, hA = G_PC / 1000, HA / 1000
    Gs = 1 / (1 / G + 1 / hA)
    for lab, Pm in (('cruise', P['P_mist'][0]), ('75', P['P_mist'][1])):
        for scfm in (0, 10, 20):
            ca = 1.005 * MIST['eff'] * scfm * 0.000471947 * 1.225
            Tss = (Pm + ca * MIST['T_air'] + Gs * T_AMB) / (ca + Gs)
            T1 = T2 = T_START
            t = 0
            while T1 < T_LIMIT and t < 7200:
                q12 = G * (T1 - T2)
                T1 += (Pm - q12 - ca * (T1 - MIST['T_air'])) / (m1 * 0.46)
                T2 += (q12 - hA * (T2 - T_AMB)) / (m2 * 0.90)
                t += 1
            add('TC72', 't_%s_%d' % (lab, scfm), t, 5e-3)
            add('TC72', 'Tss_%s_%d' % (lab, scfm), Tss)
    for d in (6, 30):
        for qc in (0.3, 1.0):
            V = qc * 1e-3 * 31 * d
            add('TC72', 'mass_%d_%g' % (d, qc), V * RHO15 / 1000 + max(V * MIST['m_acc_per_L'], MIST['m_acc_min'])
                + MIST['m_valve'] + MIST['m_lines'] + MIST['m_air'])

    # TC73: oil hardware and mist system mass
    vols = {}
    with open(os.path.join(ROOT, 'cad', 'assy', 'part_volumes.csv'), encoding='utf-8') as f:
        for row in csv.DictReader(f):
            vols[row['part']] = float(row['volume_mm3'])
    st, tia = 7830e-9, 4430e-9
    jets = 0.0
    L8 = L6 = 0.0
    for b in net.branches:
        for jt in b['jets']:
            if jt[5] > 0.5:
                jets += vols['oil_jet_%03d' % round(jt[0] * 100)] * st
        if b['d'] >= 8:
            L8 += b['L']
        else:
            L6 += b['L']
    A8 = math.pi / 4 * ((8 + 1.8) ** 2 - 64)
    A6 = math.pi / 4 * ((6 + 1.6) ** 2 - 36)
    tubes = (L8 * A8 + L6 * A6) * st * 1.3
    hw = jets + tubes + vols['oil_transfer_sleeve'] * st + vols['oil_pitch_tube'] * tia
    add('TC73', 'jets', jets)
    add('TC73', 'tubes', tubes)
    add('TC73', 'lub_hw', hw)
    V = 1.0e-3 * 31 * 6 * 1.5
    add('TC73', 'V_acc', V)
    add('TC73', 'mist', V * RHO15 / 1000 + max(V * 1.2, 0.6) + 0.3 + 0.6 + 1.0)

    with open(OUT, 'w', newline='') as f:
        wr = csv.writer(f)
        wr.writerow(['tc', 'quantity', 'expected', 'tol'])
        for tc, q, v, tol in rows:
            wr.writerow([tc, q, '%.10g' % v, tol])
    print('%d rows written to %s' % (len(rows), os.path.normpath(OUT)))


if __name__ == '__main__':
    main()
