"""Expected values for the step 3.7 MATLAB tests (calc/tests/step37_test_cases.csv).

    python calc/reference/step37_reference.py        (standard library only)

An independent Python implementation of the closed forms of step 3.7 (calc/safety). Inputs are copied from
sf_inputs.m.

Test cases:
TC100 Fault tree of propeller release: the QJ1024 failure probability within one TBO (Weibull, slope 3/2, through
      the step 2.5 L10m; the ISO 281 reliability factor form), its mean hazard H(T) / T, and the dual-path cut sets
      (QJ wear-out, oil-loss dependent QJ failure, shaft, flange) with the standby failed with lambda t + q_d,
      averaged over the interval by a midpoint sum weighted by the hazard shape of the per-hour event; the largest
      and the sum; the same cut sets never inspected over 20,000 h; the sensitivity (each assumption x10, E4 at
      1e-6 per hour): the largest cut set and, where it exceeds 1e-8, the inspection interval that restores it;
      the retention tube stresses of the post-failure phase.
TC101 FMEA (safety/fmea_v1.csv) recounted: failure modes by CS-E 510 class with and without the design features; the
      number of failed consistency checks, expected 0 (fixed, not computed: unknown class, unknown group, duplicate
      IDs, hazardous modes without a critical part, modes hazardous before mitigation with neither a critical part
      nor a design feature, modes without a detection means or a 3.10 / 3.11 item, critical parts named by no mode;
      the script stops if its own recount fails any); the modes found by oil quantity, by HUMS and with no means
      in service (latent only).
TC102 Newman-Raju equations against the published finite-element values: NASA TP-1578 Table I (surface crack,
      tension and bending, c/b = 0.2) and NASA TM-85793 Table 2 (corner crack, bending); expected the FE value,
      tolerance 9% (the equations claim about 5% of the case maximum; the corner rows at a/c = 2, 17-43% off, lie
      outside the range used and are not tested); NASA TM-89070 Table 1 (corner crack, tension, c/b = 0.04),
      tolerance 15% (the equations lie up to 13% above it, on the safe side).
TC103 Damage tolerance re-coded: the Newman-Raju factors at a few points; the stress components of the eight
      locations (closed-form shaft sections, notch factors, the centrifugal hoop of the PT shaft, the press-fit
      hoop of the carrier) and the crack plane (normal stress on a fixed plane, 1 deg steps, the largest effective
      HCF range over its threshold), the stresses on it; K at the initial flaw; the HCF threshold size and the
      critical size (bisection along the initial shape); the anomaly life and the growth life from the detectable
      sizes (no threshold) by a fine explicit (Euler) integration, tolerance 2%, the inspection interval and the
      NDT margin.
      G6: ten locations (the two coupling locations added), through cracks with the shell bulging factor where the
      anomaly or a detectable pair is deeper than 0.8 t or by the NASA-STD-5009C thickness limits, the embedded flaw of
      CS-E 515(a) (penny crack of the UT acceptance radius: HCF margin, threshold radius), the A357 case at the
      casting factor with the 0.4 mm pore radius, the Ti-6Al-4V threshold of Forth and the A357 constants of McDowell.
TC104 Critical parts: the LCF life of the ground-air-ground cycle (max principal stress) on the minimum S-N curve
      (Basquin, Morrow).
TC105 Dual-failure trees (D1b): (a) PT overspeed (drive-chain breaks of the G2 coverage table x a protection element:
      pickups, valve, logic, each lambda T / 2 + q_d at the start check) and the allowance of each element; (b) the
      hazardous propeller effect (PCU fail-to-fine, downstream breaks, cross-leak, blockage, common cause) with the
      layers at their allowances, each from its own cut set; the sums against 1e-7; the lowest OSG and low-pitch-stop
      intervals over the x10 cases.
TC113 D4 design studies: the P103 thread options (drawing M120, MJ thread, local 95 mm bore, both) with the rule
      a_HCF >= 1.25 x the deepest MPI pair, the option adopted (c) and the intervals with the eddy current sizes, the carrier pin bore at rim ligaments 11 and
      20 mm, the 3.5 press-fit hoop check, the PT shaft hoop stress, the 1P sweep (a_HCF) and the largest M_1P that
      keeps the base-case conclusions (bisection, 2%); a_HCF with the steel threshold 2.0 at every R (reported).
TC115 Shaft-break protection: the step 1.4 run-up re-coded (RK4) for the PT alone and for the PT side up to the
      carrier, with the 3% mismatch and the 106% absolute trips: detection time (1%) and peak speed.
TC106 Fire: the A357 wall in the standard flame re-solved by explicit finite volumes (pdepe in MATLAB): the highest
      flame-side and mean temperatures with oil flow (1%) and the time to the solidus without flow (2%).

Source: Phase 3 report, Section 3.7 ("Tests").
"""
import csv
import math
import os
import re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
OUT = os.path.join(ROOT, 'calc', 'tests', 'step37_test_cases.csv')
CRITICAL = ('PT output shaft', 'RGB input shaft', 'P103', 'P111', 'planetary case', 'diaphragm couplings', 'P117')
ICA = tuple('ICA-%02d' % k for k in range(1, 24))

# sf_inputs
TBO, TARGET, LIFE = 4000.0, 1e-8, 20000.0
RATE = {'E1': 1e-7, 'E6': 1e-6, 'E2': 1e-6, 'E5': 1e-6, 'E8': 1e-7}
QD = {'E1': 0.0, 'E6': 0.0, 'E2': 1e-4, 'E5': 1e-3, 'E4': 0.0, 'E7': 0.0, 'E8': 0.0, 'CC1': 1e-4}
KIND = {'E1': 'a', 'E6': 'a', 'E4': 'a', 'E7': 'a', 'E8': 'a', 'E2': 'l', 'E5': 'l', 'CC1': 'd', 'R4': 'd', 'R7': 'd'}
L10M, SLOPE, F_AXIAL = 3.50e4, 1.5, 0.01
LAM_OIL, P_QJ = 1e-5, 0.01
CUTS = (('E1', 'E2'), ('E6', 'E2'), ('E6', 'CC1'), ('E4', 'E5'), ('E4', 'R4'), ('E7', 'E5'), ('E7', 'R7'), ('E8', 'E5'),
        ('E8', 'R4'))
SENS = (('E1', 'rate', 10), ('E6', 'rate', 10), ('E2', 'rate', 10), ('E7', 'rate', 10), ('E5', 'rate', 10),
        ('E2', 'qd', 10), ('E5', 'qd', 10), ('CC1', 'qd', 10), ('R4', 'qd', 10), ('E4', 'set', 1e-6), ('f_neg', 'qj', 10),
        ('p_tc', 'qj', 10), ('p_limp', 'qj', 10), ('f_axial', 'qj', 10))
# G1b (sf_qj): transient share, NJ1024 branch probabilities, feather failure q_cw of D1b, the Ti-6Al-4V hot yield
QJ = dict(f_neg=1e-3, p_tc=1 / 30, p_limp=0.05, q_trans=1e-3, q_wear=1e-3, p_mist=0.01, f_axial=F_AXIAL)
Q_CW = 1e-6 * 30 / 2 + 1e-4
SY_T = ((20, 827), (200, 690), (300, 620), (400, 560), (500, 500), (600, 400), (700, 250), (800, 120), (900, 50))


D1_SUM = [0.0]


def plate_moment(a, b, nu):
    """Annular plate clamped at r = a, free at r = b, unit line load at the bore: the larger of M_r(a) and M_t(b) per
    unit length (axisymmetric plate theory, the two constants by Cramer's rule)."""
    K = 1 / (2 * math.pi)
    # theta(a) = 0: A a / 2 + B / a = -K (a ln a / 2 - a / 4)
    # M_r(b) = 0:   A (1 + nu) / 2 + B (nu - 1) / b^2 = -K (ln b / 2 + 1 / 4) - nu K (ln b / 2 - 1 / 4)
    a11, a12, r1 = a / 2, 1 / a, -K * (a * math.log(a) / 2 - a / 4)
    a21, a22 = (1 + nu) / 2, (nu - 1) / b ** 2
    r2 = -K * (math.log(b) / 2 + 0.25) - nu * K * (math.log(b) / 2 - 0.25)
    det = a11 * a22 - a12 * a21
    A, B = (r1 * a22 - a12 * r2) / det, (a11 * r2 - a21 * r1) / det
    th = lambda r: K * (r * math.log(r) / 2 - r / 4) + A * r / 2 + B / r
    dth = lambda r: K * (math.log(r) / 2 + 0.25) + A / 2 - B / r ** 2
    return max(abs(dth(a)), abs(nu * dth(b) + th(b) / b))


def rub(t, onesided):
    """Run-down rub, transient 2-D r-z (explicit finite volumes, axisymmetric): the lip disc r 66-84 mm over t and the
    collar r 60-72 mm over 4 mm, 4 layers each, 0.5 mm rings, 1 ms steps over 6 s; contact r 66-72 mm; the lip outer
    edge and the collar bore held at 142 degC. Returns the hottest temperature, the energy and the lip share."""
    dr, nz, T0, dt = 0.5e-3, 4, 142.0, 1e-3
    kt, rt, ct = 6.7, 4430.0, 526.0
    ks, rs, cs = 42.0, 7850.0, 475.0
    rl = [0.066 + dr * (k + 0.5) for k in range(36)]
    rc = [0.060 + dr * (k + 0.5) for k in range(24)]
    dzl, dzc = t * 1e-3 / nz, 4e-3 / nz
    band = list(range(12))                          # lip nodes 0-11 and collar nodes 12-23 sit at r 66.25-71.75 mm
    Tl = [[T0] * 36 for _ in range(nz)]
    Tc = [[T0] * 24 for _ in range(nz)]
    al, ac = kt / (rt * ct), ks / (rs * cs)
    A_band = math.pi * (0.072 ** 2 - 0.066 ** 2)
    w0, n = 1700 * math.pi / 30, 6000
    E = Eti = 0.0
    Tmax = T0

    def step(T, r, dz, a, outer):
        nr_ = len(r)
        out = []
        for i in range(nz):
            row = T[i]
            up = T[i - 1] if i > 0 else row
            dn = T[i + 1] if i < nz - 1 else row
            new = []
            for j in range(nr_):
                tm = row[j - 1] if j > 0 else row[j]
                tp = row[j + 1] if j < nr_ - 1 else row[j]
                rp, rm = r[j] + dr / 2, r[j] - dr / 2
                lap = (rp * (tp - row[j]) - rm * (row[j] - tm)) / (r[j] * dr * dr) + (up[j] - 2 * row[j] + dn[j]) / dz ** 2
                new.append(row[j] + a * dt * lap)
            if outer:
                new[-1] = T0
            else:
                new[0] = T0
            out.append(new)
        return out
    Cl, Cc = rt * ct * dzl, rs * cs * dzc
    for i in range(n):
        x = (i + 0.5) / n
        w = w0 * (1 - 0.95 * x)
        F = 5e3 * (1 - 0.9 * x)
        q = [0.4 * F / A_band * w * rl[j] for j in band]
        Tl = step(Tl, rl, dzl, al, True)
        Tc = step(Tc, rc, dzc, ac, False)
        for k, j in enumerate(band):
            area = 2 * math.pi * rl[j] * dr
            if onesided:
                Tl[-1][j] += q[k] * dt / (rt * ct * dzl)
            else:
                Tm = (Cl * Tl[-1][j] + Cc * Tc[0][12 + k] + q[k] * dt) / (Cl + Cc)
                Eti += (Tm - Tl[-1][j]) * Cl * area
                Tl[-1][j] = Tm
                Tc[0][12 + k] = Tm
            E += q[k] * area * dt
        Tmax = max(Tmax, max(max(r_) for r_ in Tl), max(max(r_) for r_ in Tc))
    return Tmax, E, (Eti / E if not onesided else 1.0)


def interp(tab, x):
    for (x0, y0), (x1, y1) in zip(tab, tab[1:]):
        if x0 <= x <= x1:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    return tab[-1][1] if x > tab[-1][0] else tab[0][1]


LIP_CACHE = {}


def lip():
    """P116 lip (sf_lip re-coded): the clamped annular plate sized at LD-04 (yield at limit, RF 1.15 on F_tu at
    ultimate, 0.1 mm steps), mass, bolts, the 2-D run-down rub, the hot yield against the drag stress."""
    if LIP_CACHE:
        return LIP_CACHE
    Fl, Fu, rho = 20e3, 30e3, 4.43e-6
    M1 = plate_moment(0.084, 0.066, 0.34)
    sig = lambda F, t: 6 * F * M1 / (t * 1e-3) ** 2 / 1e6
    t = 2.0
    while sig(Fl, t) > 827 or sig(Fu, t) * 1.15 > 896:
        t += 0.1
    t = round(t * 10) / 10
    m_disc = math.pi * (84 ** 2 - 66 ** 2) * t * rho
    m_cover = m_disc + (math.pi * (94 ** 2 - 84 ** 2) - 8 * math.pi / 4 * 5.5 ** 2) * 7 * rho
    out = dict(t=t, s_lim=sig(Fl, t), s_ult=sig(Fu, t), m_cover=m_cover, m_total=m_cover + 0.16 + 0.04,
               bolt_lim=Fl * 1.3 / 8 / 14.2, s_drag=sig(5e3, t))
    out['rf_ult'] = 896 / out['s_ult']
    out['T_max'], out['E'], out['share'] = rub(t, False)
    out['T_onesided'] = rub(t, True)[0]
    out['sy_hot'] = interp(SY_T, min(out['T_max'], 900))
    out['q_r7'] = 1e-3 if out['sy_hot'] >= out['s_drag'] else 1.0
    LIP_CACHE.update(out)
    return out


def qj(Lp, par=QJ):
    """G1b (sf_qj re-coded): thrust floor, NJ1024 axial ratings (SKF F_ap = k1 C0 1e4 / (n (d + D)) - k2 Fr, x 0.85),
    limp thrust, end play, the R4 branches given a QJ1024 axial loss, the E7 p, the SYS-06 roll-up."""
    cap = lambda k1: (k1 * 166e3 * 1e4 / (1700 * (120 + 180)) - 0.15 * 8.6e3) * 0.85
    o = dict(floor=600 + 500 + 400, nj_cont=min(cap(1.5), 0.5 * 8.6e3), nj_brief=min(cap(3.0), 8.6e3), end_play=0.42 + 0.1)
    o['limp'] = math.floor(o['nj_cont'] / 100) * 100
    p_nj = par['p_tc'] + (1 - par['p_tc']) * par['p_limp']
    o['p_nj'] = p_nj
    o['branch'] = ((1 - p_nj) * par['q_trans'] * par['f_neg'] / 1e-3, p_nj * (Lp['q_r7'] + par['q_wear']), p_nj * Q_CW)
    o['R4'] = min(1.0, sum(o['branch']))
    o['p_qj'] = par['p_mist'] + 0.01 * min(1.0, 6 / 60) + 1e-3
    changes = 0.25 + 0.05 - 0.20 + 0.05 + 0.05 + 0.02 + 0.08 - 0.10
    o['rollup'] = 109.24 + 0.18 + Lp['m_total'] + changes
    o['rollup_net'] = o['rollup'] + (-0.15 - 0.10) * (o['rollup'] > 110)
    return o


def mean_rate(ev, T, uniform):
    """One cut set: the per-hour event times the mean, over the interval, of the latent unavailabilities
    lambda t + q_d (weighted by the hazard shape of a Weibull per-hour event renewed at T), times the demand
    probabilities; a midpoint sum over 20000 steps (independent of the closed-form moments in sf_cutset)."""
    act = [e for e in ev if e[0] == 'a']
    assert len(act) == 1
    _, ra, b = act[0]
    b = 1.0 if uniform else b
    lat = [e for e in ev if e[0] == 'l']
    dem = [e for e in ev if e[0] == 'd']
    n, acc = 20000, 0.0
    for k in range(n):
        t = (k + 0.5) / n * T
        w = b * (t / T) ** (b - 1) / n
        prod = 1.0
        for _, rl, ql in lat:
            prod *= rl * t + ql
        acc += w * prod
    for _, q in dem:
        acc *= q
    return ra * acc


def cut_sets(rate, qd, beta, T=TBO, uniform=False):
    out = []
    for c in CUTS:
        ev = []
        for e in c:
            k = KIND[e]
            if k == 'a':
                ev.append(('a', rate[e], beta.get(e, 1.0)))
            elif k == 'l':
                ev.append(('l', rate[e], qd[e]))
            else:
                ev.append(('d', qd[e]))
        out.append(mean_rate(ev, T, uniform))
    return out


def events(par=QJ):
    """Rates, demand probabilities and Weibull slopes of the D1 events for one set of the G1b inputs."""
    H = math.log(1 / 0.9) * (TBO / L10M) ** SLOPE
    Lp = lip()
    Q = qj(Lp, par)
    rate = dict(RATE, E4=H / TBO * par['f_axial'], E7=LAM_OIL * Q['p_qj'])
    qd = dict(QD, R4=Q['R4'], R7=Lp['q_r7'])
    return rate, qd, {'E4': SLOPE}, Lp, Q


def fta(add):
    # reliability R(t) = 0.9 ** ((t / L10) ** slope): the survival of the Weibull life through L10; H = -ln R
    H = math.log(1 / 0.9) * (TBO / L10M) ** SLOPE
    f_tbo = 1.0 - math.exp(-H)
    lam_qj = H / TBO
    rate, qd, beta, Lp, Q = events()
    p = cut_sets(rate, qd, beta)
    add('TC100', 'F_tbo_qj', f_tbo)
    add('TC100', 'lam_qj', lam_qj)
    for c, pk in zip(CUTS, p):
        add('TC100', 'P_%s_%s' % c, pk)
    add('TC100', 'P_max', max(p))
    add('TC100', 'P_total', sum(p))
    D1_SUM[0] = sum(p)
    for c, pk in zip(CUTS, cut_sets(rate, qd, beta, LIFE, True)):
        add('TC100', 'P0_%s_%s' % c, pk)
    ie = CUTS.index(('E4', 'R4'))
    pe4 = []
    for e, what, f in SENS:
        if what == 'qj':
            par = dict(QJ)
            par[e] *= f
            r, d, bt = events(par)[:3]
        else:
            r, d, bt = dict(rate), dict(qd), dict(beta)
            if what == 'rate':
                r[e] *= f
            elif what == 'qd':
                d[e] *= f
            else:                                   # all causes: the bearing rate times f_axial (once)
                r[e] = f * F_AXIAL
                bt.pop(e, None)
        ps = cut_sets(r, d, bt)
        pe4.append(ps[ie])
        j = max(range(len(ps)), key=lambda i: ps[i])
        tag = 'sens_%s_%s' % (e, what)
        add('TC100', tag + '_P_max', ps[j])
        a, l = CUTS[j]
        if ps[j] > TARGET and KIND[l] == 'l':           # interval of the latent path that restores the target
            b = bt.get(a, 1.0)
            tb = (TARGET / r[a] - d[l]) / (r[l] * b / (b + 1))
            if tb > 0:
                add('TC100', tag + '_T_back', tb)
    # retention tube, post-failure phase
    A = math.pi / 4 * (90 ** 2 - 80 ** 2)
    Z = math.pi / 32 * (90 ** 4 - 80 ** 4) / 90
    s_ax = 1.5 * 20e3 / A
    s_b = 1.5 * (20e3 / A + (2.5 * 76.4 * 9.81 * 0.25 + 7190) * 1e3 / Z)
    add('TC100', 'tube_s_axial', s_ax)
    add('TC100', 'tube_s_bound', s_b)
    add('TC100', 'tube_RF_ult_bound', 896 / s_b)
    # P116 lip and E7 phases
    add('TC100', 'lip_t', Lp['t'], 1e-6)
    add('TC100', 'lip_m_cover', Lp['m_cover'])
    add('TC100', 'lip_s_ult', Lp['s_ult'])
    add('TC100', 'lip_bolt_lim', Lp['bolt_lim'])
    add('TC100', 'mass_rollup', Q['rollup'])
    add('TC100', 'lip_E_rundown', Lp['E'])
    add('TC100', 'lip_T_rundown', Lp['T_max'], 0.01)
    add('TC100', 'q_R4', Q['R4'])
    add('TC100', 'E7_p', Q['p_qj'])
    # TC118: G1b (the clamped plate, the 2-D rub, the thrust floor, the NJ1024 standby, the R4 branches, the mass)
    add('TC118', 'lip_s_lim', Lp['s_lim'])
    add('TC118', 'lip_rf_ult', Lp['rf_ult'])
    add('TC118', 'lip_share_ti', Lp['share'], 0.01)
    add('TC118', 'lip_T_onesided', Lp['T_onesided'], 0.01)
    add('TC118', 'lip_s_drag', Lp['s_drag'])
    add('TC118', 'lip_sy_hot', Lp['sy_hot'], 0.02)
    add('TC118', 'q_R7', Lp['q_r7'])
    for k in ('floor', 'nj_cont', 'nj_brief', 'limp', 'end_play', 'p_nj', 'rollup_net'):
        add('TC118', k, Q[k])
    for k, v in enumerate(Q['branch'], 1):
        add('TC118', 'R4_branch%d' % k, v)
    add('TC118', 'P_E4_R4_max_sens', max(pe4))
    # TC114: the cut-set function on synthetic cut sets (one constant per-hour event with two latent events sharing
    # one inspection: T^2/3; a Weibull per-hour event with one latent and one demand event)
    T = 4000.0
    add('TC114', 'two_latent', mean_rate([('a', 1e-6, 1.0), ('l', 2e-6, 1e-4), ('l', 3e-6, 2e-3)], T, False))
    add('TC114', 'two_latent_closed', 1e-6 * (2e-6 * 3e-6 * T * T / 3 + (2e-6 * 2e-3 + 3e-6 * 1e-4) * T / 2 + 1e-4 * 2e-3))
    add('TC114', 'weibull_demand', mean_rate([('a', 5e-7, 1.5), ('l', 1e-6, 1e-3), ('d', 0.02)], T, False))
    add('TC114', 'weibull_demand_uniform', mean_rate([('a', 5e-7, 1.5), ('l', 1e-6, 1e-3), ('d', 0.02)], T, True))


def shaft_break(J, Q0, n0, delay, tau, trip, k=2.0, drag=0.02, t_end=8.0, dt=1e-4):
    """PT run-up after the load is lost (step 1.4 shaft_break, re-coded): torque line Q0 (k - (k - 1) w / w0),
    drag Q0 (w / w0)^2, the fuel valve closed delay after the speed passes trip x w0, then the torque decays with tau;
    RK4. Returns the detection time [s] and the peak / w0."""
    w0 = n0 * math.pi / 30
    t, w, wmax, t_det, t_cut = 0.0, w0, w0, None, float('inf')

    def f(t, w):
        g = 1.0 if t < t_cut else math.exp(-(t - t_cut) / tau)
        return Q0 * (g * (k - (k - 1) * w / w0) - drag * (w / w0) ** 2) / J
    for _ in range(int(round(t_end / dt))):
        k1 = f(t, w)
        k2 = f(t + dt / 2, w + dt / 2 * k1)
        k3 = f(t + dt / 2, w + dt / 2 * k2)
        k4 = f(t + dt, w + dt * k3)
        w += dt / 6 * (k1 + 2 * k2 + 2 * k3 + k4)
        t += dt
        if t_det is None and w >= w0 * trip:
            t_det, t_cut = t, t + delay
        wmax = max(wmax, w)
    return t_det, wmax / w0


def protect(add):
    """TC115: the run-up for the PT alone (0.084 kg m2) and for the PT side up to the carrier (0.094565 kg m2, the
    step 2.3 inertias in rigid rotation, copied), 3% mismatch and 106% absolute trips, MCT torque 417.3 N m."""
    for tag, J, trip in (('pt_only', 0.084, 1.03), ('mismatch_max', 0.094565, 1.03), ('absolute', 0.094565, 1.06)):
        td, pk = shaft_break(J, 417.3, 22000.0, 0.025, 0.10, trip)
        add('TC115', tag + '_t_det', 1e3 * td, 0.01)
        add('TC115', tag + '_peak', 100 * pk, 2e-4)


def fmea(add):
    with open(os.path.join(ROOT, 'safety', 'fmea_v1.csv'), encoding='utf-8', newline='') as f:
        rows = list(csv.DictReader(f))
    for c in ('hazardous', 'major', 'minor'):
        add('TC101', 'n_' + c, sum(r['class'] == c for r in rows), 0)
        add('TC101', 'n_unmit_' + c, sum(r['class_unmitigated'] == c for r in rows), 0)
    named = lambda r: any(p in r['critical_part'] for p in CRITICAL)
    classes = ('hazardous', 'major', 'minor')
    groups = ('gears', 'ring_damping', 'planetary', 'shafts_retention', 'cases_joints', 'oil', 'mist', 'sensors',
              'accessory', 'maintenance')
    bad = sum(r['class'] not in classes or r['class_unmitigated'] not in classes for r in rows)
    bad += sum(r['group'] not in groups for r in rows)
    bad += len(rows) - len(set(r['id'] for r in rows))
    bad += sum(r['class'] == 'hazardous' and not named(r) for r in rows)
    bad += sum(r['class_unmitigated'] == 'hazardous' and not named(r) and r['design_feature'] in ('', '-') for r in rows)
    bad += sum(r['detection'] == '' or r['verification'] in ('', '-') for r in rows)
    bad += sum(not any(p in r['critical_part'] for r in rows) for p in CRITICAL)
    latent = lambda r: re.search('latent|none in service', r['failure_mode'] + ' ' + r['detection'], re.I) is not None
    bad += sum(latent(r) and not any(c in r['verification'] for c in ICA) for r in rows)
    add('TC101', 'n_latent', sum(latent(r) for r in rows), 0)
    if bad:
        raise SystemExit('the FMEA fails %d consistency checks: fix safety/fmea_v1.csv' % bad)
    add('TC101', 'n_fails', 0, 0)                     # expected: a consistent table (fixed, not computed)
    # detection means counted as in sf_fmea (a mode with no means in service counts as latent only)
    pats = ('chip detector', 'oil debris monitor|ODM', 'HUMS', 'oil pressure|low oil pressure', 'oil temperature',
            'Np/Nr|Np against Nr|absolute Np', 'borescope', 'BIT', 'quantity', 'latent|none in service')
    cnt = [0] * len(pats)
    for r in rows:
        hit = [re.search(p_, r['detection'], re.I) is not None for p_ in pats]
        if hit[-1]:
            hit = [False] * (len(pats) - 1) + [True]
        cnt = [c + h for c, h in zip(cnt, hit)]
    add('TC101', 'n_det_quantity', cnt[8], 0)
    add('TC101', 'n_det_latent', cnt[9], 0)
    add('TC101', 'n_det_HUMS', cnt[2], 0)


# ---- D4 (sf_nr, sf_locations, sf_dt)
def nr(kind, a, c, t, b, phi):
    """Newman-Raju factors (NASA TM-85793): tension F and bending H F, and Q."""
    r, at = a / c, a / t
    sn, cs = math.sin(phi), math.cos(phi)
    if r <= 1:
        Q = 1 + 1.464 * r ** 1.65
        fphi = (r * r * cs * cs + sn * sn) ** 0.25
    else:
        Q = 1 + 1.464 * (c / a) ** 1.65
        fphi = ((c / a) ** 2 * sn * sn + cs * cs) ** 0.25
    if kind == 'surface':
        fw = (1.0 / math.cos(math.pi * c / (2 * b) * math.sqrt(at))) ** 0.5
        if r <= 1:
            m = (1.13 - 0.09 * r, -0.54 + 0.89 / (0.2 + r), 0.5 - 1 / (0.65 + r) + 14 * (1 - r) ** 24)
            g = 1 + (0.1 + 0.35 * at * at) * (1 - sn) ** 2
            p = 0.2 + r + 0.6 * at
            h1 = 1 - 0.34 * at - 0.11 * r * at
            g21, g22 = -1.22 - 0.12 * r, 0.55 - 1.05 * r ** 0.75 + 0.47 * r ** 1.5
        else:
            q = c / a
            m = (math.sqrt(q) * (1 + 0.04 * q), 0.2 * q ** 4, -0.11 * q ** 4)
            g = 1 + (0.1 + 0.35 * q * at * at) * (1 - sn) ** 2
            p = 0.2 + q + 0.6 * at
            h1 = 1 + (-0.04 - 0.41 * q) * at + (0.55 - 1.93 * q ** 0.75 + 1.38 * q ** 1.5) * at * at
            g21, g22 = -2.11 + 0.77 * q, 0.55 - 0.72 * q ** 0.75 + 0.14 * q ** 1.5
        F = (m[0] + m[1] * at ** 2 + m[2] * at ** 4) * g * fphi * fw
    else:
        lam = c / b * math.sqrt(at)
        fw = 1 - 0.2 * lam + 9.4 * lam ** 2 - 19.4 * lam ** 3 + 27.1 * lam ** 4
        if r <= 1:
            m = (1.08 - 0.03 * r, -0.44 + 1.06 / (0.3 + r), -0.5 + 0.25 * r + 14.8 * (1 - r) ** 15)
            g = (1 + (0.08 + 0.4 * at * at) * (1 - sn) ** 3) * (1 + (0.08 + 0.15 * at * at) * (1 - cs) ** 3)
            p = 0.2 + r + 0.6 * at
            h1 = 1 - 0.34 * at - 0.11 * r * at
            g21, g22 = -1.22 - 0.12 * r, 0.64 - 1.05 * r ** 0.75 + 0.47 * r ** 1.5
        else:
            q, ct = c / a, c / t
            m = (math.sqrt(q) * (1.08 - 0.03 * q), 0.375 * q * q, -0.25 * q * q)
            g = (1 + (0.08 + 0.4 * ct * ct) * (1 - sn) ** 3) * (1 + (0.08 + 0.15 * ct * ct) * (1 - cs) ** 3)
            p = 0.2 + q + 0.6 * at
            h1 = 1 + (-0.04 - 0.41 * q) * at + (0.55 - 1.93 * q ** 0.75 + 1.38 * q ** 1.5) * at * at
            g21, g22 = -2.11 + 0.77 * q, 0.64 - 0.72 * q ** 0.75 + 0.14 * q ** 1.5
        F = (m[0] + m[1] * at ** 2 + m[2] * at ** 4) * g * fphi * fw
    h2 = 1 + g21 * at + g22 * at * at
    H = h1 + (h2 - h1) * sn ** p
    return F, H * F, Q


# FE values: kind, load, a/c, a/t, 2 phi / pi, value (TP-1578 Table I, c/b 0.2; TM-85793 Table 2; TM-89070 Table 1,
# corner tension at c/b 0.04); the corner rows at a/c = 2 (outside the range used) are not tested
FE = ((1, 1, 0.2, 0.2, 0, 0.617), (1, 1, 0.2, 0.2, 1, 1.173), (1, 1, 0.2, 0.8, 0, 1.190), (1, 1, 0.2, 0.8, 1, 1.851),
      (1, 1, 0.4, 0.4, 0, 0.896), (1, 1, 0.4, 0.4, 1, 1.225), (1, 1, 1.0, 0.2, 0, 1.174), (1, 1, 1.0, 0.2, 1, 1.049),
      (1, 1, 1.0, 0.8, 0, 1.464), (1, 1, 1.0, 0.8, 1, 1.112), (1, 1, 2.0, 0.4, 0, 0.848), (1, 1, 2.0, 0.4, 1, 0.501),
      (1, 2, 0.2, 0.2, 0, 0.572), (1, 2, 0.2, 0.2, 1, 0.862), (1, 2, 1.0, 0.2, 0, 1.076), (1, 2, 1.0, 0.2, 1, 0.742),
      (1, 2, 1.0, 0.6, 0, 1.003), (1, 2, 1.0, 0.6, 1, 0.207),
      (2, 2, 0.2, 0.2, 0, 0.522), (2, 2, 0.2, 0.2, 1, 0.876), (2, 2, 1.0, 0.2, 0, 1.084), (2, 2, 1.0, 0.2, 1, 0.839),
      (2, 2, 1.0, 0.5, 0, 1.046), (2, 2, 1.0, 0.5, 1, 0.407))
FE_T = ((2, 1, 1.0, 0.2, 0, 1.1480), (2, 1, 1.0, 0.2, 1, 1.1653), (2, 1, 1.0, 0.5, 0, 1.2421), (2, 1, 1.0, 0.5, 1, 1.2041),
        (2, 1, 1.0, 0.8, 0, 1.4313), (2, 1, 1.0, 0.8, 1, 1.3720), (2, 1, 0.4, 0.2, 0, 0.7851), (2, 1, 0.4, 0.2, 1, 1.1316),
        (2, 1, 0.4, 0.5, 0, 0.9498), (2, 1, 0.4, 0.5, 1, 1.3250), (2, 1, 0.4, 0.8, 0, 1.2761), (2, 1, 0.4, 0.8, 1, 1.6630),
        (2, 1, 0.2, 0.5, 0, 0.7905), (2, 1, 0.2, 0.5, 1, 1.5232))

# sf_inputs: loads, notch factors, materials, NDT sizes
KF, KFS, RIP = 2.0, 1.6, 0.10
T_PROP = 895e3 / (1700 * math.pi / 30)
T_PT_MC, T_PT01, T_IN08 = 417.3, 534.2, 2158 * 0.2 / 0.22
T_PROP01, T_PROP08 = 6915.0, 26129 * 0.2 / 0.22
THR_TO, THR_LIM, M1P, WPROP, OVH, MGYRO, NZ = 18e3, 20e3, 2000.0, 76.4 * 9.81, 0.25, 7190.0, 2.5
FT, FR, FA, RP, SPAN, ARM = 12105.0, 4561.0, 3243.0, 32.09, 102.0, 25.0
D3, ARM_TH, L_BORE, RHO = 120 - 1.226869 * 2, 0.192, 30.0, 7.83e-6
THREAD_OPT = (('M', 3.0, 100.0), ('a', 2.5, 100.0), ('b', 3.0, 95.0), ('c', 2.5, 95.0))
CARRIER = dict(s08=1100 / 2.41, K08=1.071, K_mct=1.32, K_01=1.245, hoop=150.0, hoop_35=76.0, t=10.0, b=11.0)
M1P_SENS = (2000.0, 3000.0, 4000.0, 4900.0)
RULE, TARGET_CYC = 1.25, 3000.0


def dk_steel(R):
    return 6.04 if R < 0.1 else 7.03 * (1 - 0.85 * R)


MAT = {'S4340': (1.35e-10, 2.25, dk_steel, 80.0), 'P53': (1.35e-10, 2.25, dk_steel, 100.0),
       'Ti64': (5e-11, 3.5, lambda R: max(2.2, 3.4 - 2.0 * max(R - 0.1, 0)), 55.0),
       'A357': (1.5e-11, 4.2, lambda R: 1.3, 18.0), 'C155': (1.35e-10, 2.25, dk_steel, 90.0)}
THIN = {'MPI': lambda t: 3.18 if t <= 1.91 else 0.0, 'FPI': lambda t: 3.81 - t if 1.27 < t <= 1.91 else 0.0,
        'ET': lambda t: 1.27 if t <= 1.27 else 0.0}
K_CAST, A_EMB = 1.25, 0.4
NDT = {'MPI': {'surface': ((0.97, 4.78), (1.91, 3.18)), 'corner': ((1.91, 6.35),)},
       'FPI': {'surface': ((0.64, 3.18), (1.91, 1.91)), 'corner': ((2.54, 3.81),)},
       'ET': {'surface': ((0.51, 2.54), (1.27, 1.27)), 'corner': ((1.91, 1.91),)}}
CYC_TBO = 4000.0


def pt_hoop(ro, ri, rpm=22000.0, rho=7850.0, nu=0.3):
    w = rpm * math.pi / 30
    return (3 + nu) / 8 * rho * w * w * (2 * ri * ri + ro * ro - (1 + 3 * nu) / (3 + nu) * ro * ro) * 1e-12


def locations(M=M1P, thread=(3.0, 100.0), carrier_b=None, hoop=None, ndt_thread='ET'):
    """Stress components (sigma_x, sigma_h, tau) of each state: lmax, lmin, hmax, hmin, lim (list)."""
    L = []
    z = (0.0, 0.0, 0.0)
    # 1 propeller shaft seat 120 / 100
    D, d = 120.0, 100.0
    Z, A = math.pi / 32 * (D ** 4 - d ** 4) / D, math.pi / 4 * (D * D - d * d)
    tau = lambda T: T * 1e3 / (2 * Z) * KFS
    sb = lambda Mb: Mb * 1e3 / Z * KF
    sa = lambda F: F / A * KF
    sxa = sb(M + WPROP * OVH)
    tm = tau(T_PROP)
    L.append(dict(name='P103 seat', mat='S4340', kind='surface', t=10.0, b=math.pi * D / 2, g=d / D, a0=0.381, c0=0.381,
                  lmax=(sa(THR_LIM) + sxa, 0, tau(T_PROP01)), lmin=z, hmax=(sa(THR_TO) + sxa, 0, tm * (1 + RIP)),
                  hmin=(sa(THR_TO) - sxa, 0, tm * (1 - RIP)),
                  lim=[(sa(THR_LIM) + sb(NZ * WPROP * OVH + MGYRO), 0, tau(T_PROP01)), (sa(THR_LIM) + sxa, 0, tau(T_PROP08))],
                  ndt='ET'))
    # 2 thread root
    kf, di = thread
    D, d = D3, di
    Z = math.pi / 32 * (D ** 4 - d ** 4) / D
    tau = lambda T: T * 1e3 / (2 * Z) * KFS
    sb = lambda Mb: Mb * 1e3 / Z * kf
    sxa = sb(M + WPROP * ARM_TH)
    tm = tau(T_PROP)
    L.append(dict(name='P103 thread', mat='S4340', kind='surface', t=(D - d) / 2, b=math.pi * D / 2, g=d / D, a0=0.381,
                  c0=0.381, lmax=(sxa, 0, tau(T_PROP01)), lmin=z, hmax=(sxa, 0, tm * (1 + RIP)), hmin=(-sxa, 0, tm * (1 - RIP)),
                  lim=[(sb(NZ * WPROP * ARM_TH + MGYRO), 0, tau(T_PROP01)), (sxa, 0, tau(T_PROP08))], ndt=ndt_thread))
    # 3 carrier pin bore (corner): press-fit hoop + load stress scaled with torque and K_gamma
    C = CARRIER
    h = C['hoop'] if hoop is None else hoop
    sl = lambda T, K: C['s08'] * T / T_PROP08 * K / C['K08']
    sm = sl(T_PROP, C['K_mct'])
    L.append(dict(name='P103 carrier', mat='S4340', kind='corner', t=C['t'], b=C['b'] if carrier_b is None else carrier_b,
                  g=1.0, a0=0.381, c0=0.381, lmax=(h + sl(T_PROP01, C['K_01']), 0, 0), lmin=(h, 0, 0),
                  hmax=(h + sm * (1 + RIP), 0, 0), hmin=(h + sm * (1 - RIP), 0, 0), lim=[(h + C['s08'], 0, 0)], ndt='ET'))
    # 4 P111 flange fillet, plate bending, back face -0.5
    s20 = 60.0 * 2.0
    st = s20 * THR_TO / 20e3
    L.append(dict(name='P111', mat='Ti64', kind='surface', t=8.0, b=300.0, g=-0.5, a0=0.381, c0=0.381, lmax=(s20, 0, 0),
                  lmin=z, hmax=(st * (1 + RIP), 0, 0), hmin=(st * (1 - RIP), 0, 0), lim=[(s20 * THR_LIM / 20e3, 0, 0)],
                  ndt='FPI'))
    # 5 case flange junction, critical-zone pore 0.5 mm; the 1P amplitude scales with M; casting factor 1.25 on the stresses
    smn, sal, kc = 9.41, 6.30 + 12.22 + 8.4 * M / 2000, K_CAST
    L.append(dict(name='case', mat='A357', kind='surface', t=8.0, b=500.0, g=1.0, a0=0.25, c0=0.25,
                  lmax=(kc * (smn + sal), 0, 0), lmin=z, hmax=(kc * (smn + sal), 0, 0), hmin=(kc * (smn - sal), 0, 0),
                  lim=[(kc * 60.0, 0, 0)], ndt='FPI'))
    # 6 input shaft seat 45 / 24, gear forces at the MC torque, arm 25 mm
    f = T_PT_MC * 1e3 / RP / FT
    Rb = f * (math.hypot(FT, FR) / 2 + FA * RP / SPAN)
    D, d = 45.0, 24.0
    Z = math.pi / 32 * (D ** 4 - d ** 4) / D
    tau = lambda T: T * 1e3 / (2 * Z) * KFS
    sxa = Rb * ARM / Z * KF
    tm = tau(T_PT_MC)
    L.append(dict(name='input seat', mat='P53', kind='surface', t=(D - d) / 2, b=math.pi * D / 2, g=d / D, a0=0.381,
                  c0=0.381, lmax=(sxa * T_PT01 / T_PT_MC, 0, tau(T_PT01)), lmin=z, hmax=(sxa, 0, tm * (1 + RIP)),
                  hmin=(-sxa, 0, tm * (1 - RIP)), lim=[(sxa * T_IN08 / T_PT_MC, 0, tau(T_IN08))], ndt='MPI'))
    # 7 input shaft coupling end 40 / 24, torsion
    D, d = 40.0, 24.0
    J = math.pi / 32 * (D ** 4 - d ** 4)
    tau = lambda T: T * 1e3 * (D / 2) / J * KFS
    tm = tau(T_PT_MC)
    L.append(dict(name='input coupling', mat='P53', kind='surface', t=(D - d) / 2, b=math.pi * D / 2, g=d / D, a0=0.381,
                  c0=0.381, lmax=(0, 0, tau(T_PT01)), lmin=z, hmax=(0, 0, tm * (1 + RIP)), hmin=(0, 0, tm * (1 - RIP)),
                  lim=[(0, 0, tau(T_IN08))], ndt='MPI'))
    # 8 PT output shaft 66 x 1.5, torsion and the centrifugal hoop
    D, d = 66.0, 63.0
    J = math.pi / 32 * (D ** 4 - d ** 4)
    tau = lambda T: T * 1e3 * (D / 2) / J * KFS
    sh = pt_hoop(D / 2, d / 2)
    tm = tau(T_PT_MC)
    L.append(dict(name='PT shaft', mat='S4340', kind='surface', t=1.5, b=math.pi * D / 2, g=d / D, a0=0.381, c0=0.381,
                  lmax=(0, sh, tau(T_PT01)), lmin=z, hmax=(0, sh, tm * (1 + RIP)), hmin=(0, sh, tm * (1 - RIP)),
                  lim=[(0, sh, tau(T_IN08))], ndt='ET', R=(D + d) / 4))
    # 9 diaphragm coupling at the hub radius, the adopted H4 option 2 (3 x 0.3 mm, axial pre-stretch 0.75 mm, 0.1 deg):
    # step 2.2 model stresses copied from sf_coupling; through crack from the start
    s_ax, s_th, s_cf, t_mc, s_tr, s_thx, s_cold = 0.0, 34.5841, 90.3244, 97.5870, 350.7984, 69.1682, -350.7984
    tq = lambda T: t_mc * T / T_PT_MC
    L.append(dict(name='diaphragm', mat='C155', kind='surface', t=0.3, b=math.pi * 27.5, g=1.0, a0=0.381, c0=0.381,
                  lmax=(s_tr + s_th, s_cf, tq(T_PT01)), lmin=(s_cold, 0, 0), hmax=(s_ax + s_th, s_cf, t_mc * (1 + RIP)),
                  hmin=(s_ax - s_th, s_cf, t_mc * (1 - RIP)),
                  lim=[(s_tr + s_thx, s_cf, tq(T_PT01)), (s_tr + s_th, s_cf, tq(T_IN08))], ndt='ET', R=0.0))
    # 10 coupling hub transition, 55 / 49 tube in torsion
    D, d = 55.0, 49.0
    J = math.pi / 32 * (D ** 4 - d ** 4)
    tau = lambda T: T * 1e3 * (D / 2) / J * KFS
    tm = tau(T_PT_MC)
    L.append(dict(name='coupling hub', mat='C155', kind='surface', t=(D - d) / 2, b=math.pi * D / 2, g=d / D, a0=0.381,
                  c0=0.381, lmax=(0, 0, tau(T_PT01)), lmin=z, hmax=(0, 0, tm * (1 + RIP)), hmin=(0, 0, tm * (1 - RIP)),
                  lim=[(0, 0, tau(T_IN08))], ndt='ET', R=(D + d) / 4))
    # 11 case nose at the NJ1024 thermocouple boss (G1b): 3.6 nose stresses x hole factor 2.5 x casting factor, carried
    # by a raised 12 mm pad round the hole (wall 8 mm: x 8 / 12); critical-zone pore 0.5 mm
    kc = K_CAST * 2.5 * 8.0 / 12.0
    L.append(dict(name='TC boss', mat='A357', kind='surface', t=12.0, b=300.0, g=1.0, a0=0.25, c0=0.25,
                  lmax=(kc * (16.7 + 12.2), 0, 0), lmin=z, hmax=(kc * (16.7 + 12.2), 0, 0), hmin=(kc * (16.7 - 12.2), 0, 0),
                  lim=[(kc * 30.0, 0, 0)], ndt='FPI'))
    # 12 P103 at the shoulder-ring groove (G1b): root 118 / 100, notch factor 2.0 on bending and thrust; no thrust in HCF
    D, d, kg = 118.0, 100.0, 2.0
    Z, A = math.pi / 32 * (D ** 4 - d ** 4) / D, math.pi / 4 * (D * D - d * d)
    tau = lambda T: T * 1e3 / (2 * Z) * KFS
    sb = lambda Mb: Mb * 1e3 / Z * kg
    sa = lambda F: F / A * kg
    sxa = sb(M + WPROP * OVH)
    tm = tau(T_PROP)
    L.append(dict(name='P103 groove', mat='S4340', kind='surface', t=(D - d) / 2, b=math.pi * D / 2, g=d / D, a0=0.381,
                  c0=0.381, lmax=(sa(THR_LIM) + sxa, 0, tau(T_PROP01)), lmin=z, hmax=(sxa, 0, tm * (1 + RIP)),
                  hmin=(-sxa, 0, tm * (1 - RIP)),
                  lim=[(sa(THR_LIM) + sb(NZ * WPROP * OVH + MGYRO), 0, tau(T_PROP01)), (sa(THR_LIM) + sxa, 0, tau(T_PROP08))],
                  ndt='ET'))
    return L


def sn(X, th):
    return X[0] * math.cos(th) ** 2 + X[1] * math.sin(th) ** 2 + X[2] * math.sin(2 * th)


def plane(L, mat):
    """The plane (1 deg steps) with the largest effective HCF range over its threshold; stresses on it."""
    dkth = mat[2]
    best, bi = None, None
    for deg in range(-89, 91):
        th = deg * math.pi / 180
        h1, h2 = sn(L['hmax'], th), sn(L['hmin'], th)
        hi, lo = max(h1, h2), min(h1, h2)
        e = max(hi - max(lo, 0.0), 0.0)
        R = lo / hi if hi > 0 else 0.0
        l1, l2 = sn(L['lmax'], th), sn(L['lmin'], th)
        lr = max(max(l1, l2) - max(min(l1, l2), 0.0), 0.0)
        score = round(e / dkth(max(R, 0.0)), 9) + 1e-12 * lr
        if best is None or score > best:
            best, bi = score, (deg, hi, lo, max(l1, l2), min(l1, l2), max(sn(x, th) for x in L['lim']))
    P = dict(L)
    P['theta'], P['hmax_s'], P['hmin_s'], P['lcf'], P['lcf_min'], P['lim_s'] = bi
    return P


def K2(L, a, c, s):
    out = []
    for ph in (math.pi / 2, 0.0):
        Ft, Fb, Q = nr(L['kind'], a, c, L['t'], L['b'], ph)
        out.append(s * ((1 + L['g']) / 2 * Ft + (1 - L['g']) / 2 * Fb) * math.sqrt(math.pi * a * 1e-3 / Q))
    return out


def dK_hcf(L, a, c):
    kx, kn = K2(L, a, c, L['hmax_s']), K2(L, a, c, L['hmin_s'])
    return max(x - max(n, 0.0) for x, n in zip(kx, kn))


def dK_lcf(L, a, c):
    kx, kn = K2(L, a, c, L['lcf']), K2(L, a, c, L['lcf_min'])
    return [x - max(n, 0.0) for x, n in zip(kx, kn)]


def th_hcf(L, mat):
    R = L['hmin_s'] / L['hmax_s']
    return mat[2](max(R, 0.0))


def size_where(L, test, r=None):
    r = L['a0'] / L['c0'] if r is None else r
    n = 4000
    prev = None
    amax = 0.8 * L['t'] if L['kind'] != 'corner' else min(0.8 * L['t'], 0.4999 * L['b'] * r)
    for i in range(n + 1):
        a = 0.02 * L['t'] + (amax - 0.02 * L['t']) * i / n
        if test(a, a / r):
            if prev is None:
                return a
            lo, hi = prev, a
            for _ in range(60):
                mid = (lo + hi) / 2
                if test(mid, mid / r):
                    hi = mid
                else:
                    lo = mid
            return hi
        prev = a
    return float('inf')


def life(L, a, c, mat):
    """LCF cycles from (a, c) to the first failure condition, no threshold: explicit Euler, small relative steps."""
    C, m, dkth, KIC = mat
    th_h = th_hcf(L, mat)
    N = 0.0
    while True:
        if dK_hcf(L, a, c) >= th_h or max(K2(L, a, c, L['lim_s'])) >= KIC or a >= 0.8 * L['t']:
            return N
        dk = dK_lcf(L, a, c)
        ra = C * dk[0] ** m * 1e3 if dk[0] > 0 else 0.0
        rc = C * dk[1] ** m * 1e3 if dk[1] > 0 else 0.0
        if ra == 0 and rc == 0:
            return float('inf')
        dN = 2.5e-4 * min(a / ra if ra > 0 else float('inf'), c / rc if rc > 0 else float('inf'))
        a, c, N = a + ra * dN, c + rc * dN, N + dN


def Kth(L, c, s):
    """Through crack of half-length c [mm] with the shell bulging factor (flat when R = 0)."""
    R = L.get('R', 0.0)
    M = math.sqrt(1 + 1.61 * c * c / (R * L['t'])) if R > 0 else 1.0
    return s * math.sqrt(math.pi * c * 1e-3) * M


def life_through(L, c, mat):
    C, m, dkth, KIC = mat
    th_h = th_hcf(L, mat)
    N = 0.0
    while True:
        if Kth(L, c, L['hmax_s']) - max(Kth(L, c, L['hmin_s']), 0.0) >= th_h or Kth(L, c, L['lim_s']) >= KIC or c >= L['b']:
            return N
        dk = Kth(L, c, L['lcf']) - max(Kth(L, c, L['lcf_min']), 0.0)
        if dk <= 0:
            return float('inf')
        r = C * dk ** m * 1e3
        dN = 2.5e-4 * c / r
        c, N = c + r * dN, N + dN


def c_where(L, test):
    n = 20000
    prev = None
    for i in range(n + 1):
        c = 0.005 + (L['b'] - 0.005) * i / n
        if test(c):
            if prev is None:
                return c
            lo, hi = prev, c
            for _ in range(60):
                mid = (lo + hi) / 2
                if test(mid):
                    hi = mid
                else:
                    lo = mid
            return hi
        prev = c
    return float('inf')


def embedded(L, mat, a=A_EMB):
    """Penny crack of radius a [mm]: HCF margin, threshold radius, LCF cycles to it (closed form)."""
    C, m, dkth, KIC = mat
    th = th_hcf(L, mat)
    de = L['hmax_s'] - max(L['hmin_s'], 0.0)
    dl = L['lcf'] - max(L['lcf_min'], 0.0)
    Y = 2 / math.pi * math.sqrt(math.pi * 1e-3)
    a_h = math.pi * th * th / (4 * de * de) * 1e3
    if a_h <= a:
        N = 0.0
    else:
        k, e = C * (Y * dl) ** m, 1 - m / 2
        N = (a_h ** e - a ** e) / (e * k * 1e3)
    return dict(margin=th / (Y * de * math.sqrt(a)), a_hcf=a_h, N=N)


def assess(L0, mat=None, lives=True):
    """Plane, a_HCF, a_c, anomaly life, interval, NDT margin and embedded flaw of one location; through cracks where
    the anomaly or a detectable pair is deeper than 0.8 t, or by the thickness limit of the method."""
    mat = MAT[L0['mat']] if mat is None else mat
    L = plane(L0, mat)
    th_h = th_hcf(L, mat)
    through0 = L['a0'] >= 0.8 * L['t']
    if through0:
        out = dict(L=L, a_hcf=c_where(L, lambda c: Kth(L, c, L['hmax_s']) - max(Kth(L, c, L['hmin_s']), 0.0) >= th_h),
                   a_c=c_where(L, lambda c: Kth(L, c, L['lim_s']) >= mat[3]))
    else:
        out = dict(L=L, a_hcf=size_where(L, lambda a, c: dK_hcf(L, a, c) >= th_h),
                   a_c=size_where(L, lambda a, c: max(K2(L, a, c, L['lim_s'])) >= mat[3]))
    pairs = [p for p in NDT[L['ndt']][L['kind']] if p[0] < L['t']]
    thin = THIN[L['ndt']](L['t'])
    allp = pairs + ([(L['t'], thin)] if thin > 0 else [])
    if through0:
        out['ratio'] = 0.0
    else:
        out['ratio'] = min(out['a_hcf'], 0.8 * L['t']) / max(p[0] for p in allp) if allp else 0.0
    out['emb'] = embedded(L, mat)
    if lives:
        out['N'] = life_through(L, L['c0'], mat) if through0 else life(L, L['a0'], L['c0'], mat)
        Ns = [life_through(L, cd, mat) if ad >= 0.8 * L['t'] else life(L, ad, cd, mat) for ad, cd in allp]
        out['N_det'] = min(Ns) if Ns else 0.0
        out['interval'] = math.floor(0.5 * out['N_det'] / CYC_TBO)
    return out


def tol_interval(N, n):
    """Tolerance of an interval n = floor(0.5 N / CYC_TBO): exact, unless N lies within the 2% life tolerance of
    a TBO boundary, where one TBO either way is allowed (relative to n)."""
    x = 0.5 * N / CYC_TBO
    if n >= 1 and math.isfinite(x) and (x * 1.02 >= n + 1 or x * 0.98 < n):
        return 1.0 / n
    return 0


def scaled(mat, f):
    C, m, dkth, KIC = mat
    return (C, m, lambda R: f * dkth(R), KIC)


def dt(add):
    for i, row in enumerate(FE + FE_T, 1):
        add('TC102', 'nr%02d' % i, row[5], 0.09 if i <= len(FE) else 0.15)
    # the factors themselves at a few points (re-coded exactly)
    pts = (('surface', 0.381, 0.381, 10.0, 188.5, math.pi / 2), ('surface', 0.381, 0.381, 10.0, 188.5, 0.0),
           ('surface', 2.0, 5.0, 8.0, 300.0, math.pi / 2), ('corner', 0.381, 0.381, 10.0, 40.0, math.pi / 2),
           ('corner', 2.0, 3.0, 10.0, 40.0, 0.0), ('surface', 3.0, 2.0, 10.0, 200.0, 0.3))
    for k, pt in enumerate(pts, 1):
        Ft, Fb, Q = nr(*pt)
        add('TC103', 'nr_Ft_%d' % k, Ft, 1e-4)
        add('TC103', 'nr_Fb_%d' % k, Fb, 1e-4)
    for k, L0 in enumerate(locations(thread=(2.5, 95.0)), 1):    # thread option (c) adopted (TC113)
        R = assess(L0)
        L = R['L']
        add('TC103', 'loc%d_plane' % k, L['theta'] if L['theta'] != 0 else 0.0, 1e-6)
        add('TC103', 'loc%d_s_lcf' % k, L['lcf'])
        if L['lcf_min'] != 0:
            add('TC103', 'loc%d_s_lcf_min' % k, L['lcf_min'])
        add('TC103', 'loc%d_s_hmax' % k, L['hmax_s'])
        add('TC103', 'loc%d_s_hmin' % k, L['hmin_s'])
        add('TC103', 'loc%d_s_lim' % k, L['lim_s'])
        add('TC103', 'loc%d_dK_lcf0' % k, dK_lcf(L, L['a0'], L['c0'])[0])
        add('TC103', 'loc%d_dK_hcf0' % k, dK_hcf(L, L['a0'], L['c0']))
        if math.isfinite(R['a_hcf']):
            add('TC103', 'loc%d_a_hcf' % k, R['a_hcf'])
        if math.isfinite(R['a_c']):
            add('TC103', 'loc%d_a_c' % k, R['a_c'])
        add('TC103', 'loc%d_N' % k, R['N'], 0.02)
        add('TC103', 'loc%d_ndt_ratio' % k, R['ratio'])
        if R['N_det'] > 0:
            add('TC103', 'loc%d_N_det' % k, R['N_det'], 0.02)
        add('TC103', 'loc%d_interval_tbo' % k, R['interval'], tol_interval(R['N_det'], R['interval']))
        add('TC103', 'loc%d_emb_margin' % k, R['emb']['margin'])
        add('TC103', 'loc%d_emb_a_hcf' % k, R['emb']['a_hcf'])
    # sensitivity: steel threshold 2.0 at every R (reported)
    for k in (1, 6):
        L0 = locations(thread=(2.5, 95.0))[k - 1]
        C, m, _, KIC = MAT[L0['mat']]
        R = assess(L0, (C, m, lambda R: 2.0, KIC), lives=False)
        add('TC113', 'steel2_loc%d_a_hcf' % k, R['a_hcf'])


SN = {'S4340': (1655.0, -0.076), 'P53': (1655.0, -0.076), 'Ti64': (1540.0, -0.104), 'A357': (430.0, -0.10),
      'C155': (1550.0, -0.08)}


def s1(X):
    return (X[0] + X[1]) / 2 + math.sqrt(((X[0] - X[1]) / 2) ** 2 + X[2] ** 2)


def parts(add):
    for k, L in enumerate(locations(thread=(2.5, 95.0)), 1):
        sf, b = SN[L['mat']]
        smax, smin = s1(L['lmax']), s1(L['lmin'])
        sa, sm = (smax - smin) / 2, (smax + smin) / 2
        sar = sa / (1 - sm / sf)
        add('TC104', 'loc%d_N_lcf_min' % k, 0.5 * (sar / (0.7 * sf)) ** (1 / b), 0.005)


def design(add):
    """TC113: the thread options, the carrier ligament, the 3.5 hoop check, the 1P sweep and its limit."""
    S4 = MAT['S4340']
    S4w = scaled(S4, 0.8)
    adopted = 0
    for i, (key, kf, di) in enumerate(THREAD_OPT, 1):
        L0 = locations(thread=(kf, di), ndt_thread='MPI')[1]
        R = assess(L0)
        Rw = assess(L0, S4w)
        Re = assess(locations(thread=(kf, di))[1])
        add('TC113', 'thr_%s_interval_ET' % key, Re['interval'], tol_interval(Re['N_det'], Re['interval']))
        add('TC113', 'thr_%s_a_hcf' % key, R['a_hcf'])
        add('TC113', 'thr_%s_ratio' % key, R['ratio'])
        add('TC113', 'thr_%s_interval' % key, R['interval'], tol_interval(R['N_det'], R['interval']))
        add('TC113', 'thr_%s_N' % key, R['N'], 0.02)
        add('TC113', 'thr_%s_N_w' % key, Rw['N'], 0.02)
        if key == 'c' and R['ratio'] >= RULE and Rw['N'] >= TARGET_CYC:    # decision
            adopted = i
    add('TC113', 'thr_adopted', adopted, 0)
    add('TC113', 'thr_mass', RHO * math.pi / 4 * (100 ** 2 - 95 ** 2) * L_BORE)
    for b in (11.0, 20.0):
        R = assess(locations(thread=(2.5, 95.0), carrier_b=b)[2])
        add('TC113', 'carrier_b%d_a_hcf' % b, R['a_hcf'])
        add('TC113', 'carrier_b%d_interval' % b, R['interval'], tol_interval(R['N_det'], R['interval']))
    R = assess(locations(thread=(2.5, 95.0), hoop=CARRIER['hoop_35'])[2], lives=False)
    add('TC113', 'carrier_hoop35_a_hcf', R['a_hcf'])
    add('TC113', 'pt_hoop', pt_hoop(33.0, 31.5))
    # TC117: the coupling alignment stack of the adopted H4 option (linear sum, deg)
    at = lambda x: math.degrees(math.atan(x))
    add('TC117', 'stack_sum', at(0.04 / 550) + at(0.02 / 140) + at(0.02 / 102) + 0.02 + at(0.1 / 550) + at(0.1 / 550) + 0.01)
    add('TC117', 'adopted', 3, 0)                     # option 2 of the list 0-3 (sf_coupling, base and dKth x0.8 pass)
    base = {k: assess(locations(thread=(2.5, 95.0))[k]) for k in (0, 1, 4, 11)}

    def holds(R, R0, k):
        return (R['N'] >= TARGET_CYC and R['interval'] >= min(1, R0['interval']) and R['a_hcf'] > R['L']['a0']
                and (k != 1 or R0['ratio'] < RULE or R['ratio'] >= RULE))
    for M in M1P_SENS:
        Ls = locations(M=M, thread=(2.5, 95.0))
        for k, tag in ((0, 'seat'), (1, 'thread'), (4, 'case'), (11, 'groove')):
            R = assess(Ls[k], lives=False)
            add('TC113', 'm1p%d_%s_a_hcf' % (M, tag), R['a_hcf'])
    for k, tag in ((0, 'seat'), (1, 'thread'), (4, 'case'), (11, 'groove')):
        f = lambda M: holds(assess(locations(M=M, thread=(2.5, 95.0))[k]), base[k], k)
        lo, hi = M1P, 20000.0
        if f(hi):
            lo = hi
        else:
            while hi - lo > 10:
                mid = (lo + hi) / 2
                if f(mid):
                    lo = mid
                else:
                    hi = mid
        add('TC113', 'm1p_max_%s' % tag, lo, 0.02)


def fta2(add):
    """TC105: the D1b trees re-coded (closed forms): (a) PT overspeed, (b) the hazardous propeller effect; sums,
    allowances from each cut set, the lowest OSG and low-pitch-stop intervals over the x10 cases."""
    def ev(rows_a=None, ch=1e-5, valve=(2e-6, 5e-5), logic=(1e-6, 1e-6), fine=1e-5, cross=1e-6, osg=(5e-6, 1e-6, 1e-4),
           cc=2e-6, down=4.2e-6, lps=(1e-6, 1e-4), ff=(1e-5, 1e-4), cw=(1e-6, 1e-4)):
        T, TBO_ = 30.0, 4000.0
        lb = 7e-6 + 7e-7 if rows_a is None else rows_a
        lt, beta = ch * T, 0.05
        qa = [2 * (((1 - beta) * lt) ** 2 / 3 + beta * lt / 2), valve[0] * T / 2 + valve[1], logic[0] * T / 2 + logic[1]]
        q_osg = (osg[0] + osg[1]) * TBO_ / 2 + osg[2]
        q_ff = ff[0] * T / 2 + ff[1]
        q_lps = lps[0] * TBO_ / 2 + lps[1]
        q_cw = cw[0] * T / 2 + cw[1]
        A_lps = TARGET / max(fine, cross)
        A_cw, A_cc = TARGET / down, TARGET / cc
        A_osg = TARGET / (fine * q_ff)
        A_osg0 = TARGET / fine
        T_lps = max(0.0, 2 * (A_lps - lps[1]) / lps[0])
        T_osg = max(0.0, 2 * (A_osg - osg[2]) / (osg[0] + osg[1]))
        T_osg0 = max(0.0, 2 * (A_osg0 - osg[2]) / (osg[0] + osg[1]))
        ql, qc = min(A_lps, q_lps), min(A_cw, A_cc, q_cw)
        Pb = [fine * q_osg * q_ff, fine * ql, down * qc, cross * q_ff, cross * ql, 1e-6 * 1e-5 * T / 2, cc * A_cc]
        return dict(lb=lb, Pa=[lb * x for x in qa], Pb=Pb, q_osg=q_osg, q_ff=q_ff, A_p=TARGET / lb, A_lps=A_lps,
                    T_lps=T_lps, A_cw=A_cw, T_osg=T_osg, T_osg0=T_osg0)
    b = ev()
    add('TC105', 'lam_break', b['lb'])
    add('TC105', 'sum_a', sum(b['Pa']))
    add('TC105', 'sum_b', sum(b['Pb']))
    for k, v in enumerate(b['Pa'], 1):
        add('TC105', 'Pa%d' % k, v)
    for k, v in enumerate(b['Pb'], 1):
        add('TC105', 'Pb%d' % k, v)
    add('TC105', 'spurious', 4 * 1e-5 * 0.01)
    add('TC105', 'q_p_allow', b['A_p'])
    add('TC105', 'q_lps_allow', b['A_lps'])
    add('TC105', 'T_lps', b['T_lps'])
    add('TC105', 'q_cw_allow', b['A_cw'])
    add('TC105', 'T_osg_noFF', b['T_osg0'])
    add('TC105', 'q_osg', b['q_osg'])
    add('TC105', 'q_ff', b['q_ff'])
    # the D1 sum is taken from fta(); here the D1b part of the overall sum
    add('TC105', 'sum_all', D1_SUM[0] + sum(b['Pa']) + sum(b['Pb']))
    cases = [dict(fine=1e-4), dict(cross=1e-5), dict(osg=(5e-5, 1e-6, 1e-4)), dict(osg=(5e-6, 1e-5, 1e-4)),
             dict(osg=(5e-6, 1e-6, 1e-3)), dict(ff=(1e-4, 1e-4)), dict(lps=(1e-5, 1e-4))]
    add('TC105', 'T_osg_range_lo', min([ev(**c)['T_osg'] for c in cases] + [b['T_osg']]), 2e-3)
    add('TC105', 'T_lps_range_lo', min([ev(**c)['T_lps'] for c in cases] + [b['T_lps']]), 0, )

FIRE = dict(T_f=1180.0, q0=126e3, T_sink=170.0, k=152.0, rho=2680.0, sol=555.0)
SY_FIRE = ((20, 240), (100, 230), (150, 215), (200, 185), (250, 140), (300, 80), (350, 45), (400, 30), (450, 20), (500, 12),
           (555, 0))
# walls: name tag, t [mm], flow share (None: fixed h), fixed h, operating stress [MPa]
WALLS = (('w1', 6.0, 0.5, None, 28.7 + 9.35), ('w2', 6.0, 0.0, 20.0, 28.7 + 9.35), ('w3', 8.0, 0.5, None, 16.7 + 12.2),
         ('w4', 8.0, 0.0, 75.0, 16.7 + 12.2))


def film_h(share, ri=129.5e-3, Q=20.1 * 0.6 / 6e4, rho=880.0, nu=2.2e-6, k=0.13):
    """Laminar drain film round the bore: Nusselt thickness, h = 1.88 k / delta."""
    G = rho * Q * share / (2 * math.pi * ri)
    return 1.88 * k / (3 * nu * G / (rho * 9.81)) ** (1 / 3)


def fire_cyl(t_mm, h, t_end, T_init=None, ri=129.5e-3, n=10):
    """Cylindrical A357 wall, explicit finite volumes (independent of pdepe): oil at ri with h to the sink, the flame
    at the upper tolerance round the outside (radiation-scaled flux). Returns the profile at the end (or at the
    solidus), the highest area-mean temperature and the time the flame side reaches the solidus."""
    F = FIRE
    K = lambda T: T + 273.15
    qf = lambda T: F['q0'] * (K(F['T_f']) ** 4 - K(T) ** 4) / (K(F['T_f']) ** 4 - K(20.0) ** 4)
    cp = lambda T: 920.0 + 0.45 * T
    dr = t_mm * 1e-3 / n
    rf = [ri + i * dr for i in range(n + 1)]
    vol = [(rf[i + 1] ** 2 - rf[i] ** 2) / 2 for i in range(n)]          # per radian and metre
    T = list(T_init) if T_init else [F['T_sink']] * n
    dt = 0.2 * F['rho'] * 900.0 * dr * dr / F['k']
    t, mean_max, t_sol = 0.0, 0.0, float('inf')
    while t < t_end - 1e-12:
        st = min(dt, t_end - t)
        Ts0 = (T[0] + h * dr / (2 * F['k']) * F['T_sink']) / (1 + h * dr / (2 * F['k']))
        Tsn = T[-1] + qf(T[-1]) * dr / (2 * F['k'])
        flux = [-h * (Ts0 - F['T_sink']) * rf[0]] + [F['k'] * (T[i - 1] - T[i]) / dr * rf[i] for i in range(1, n)] + \
               [-qf(Tsn) * rf[n]]
        T = [T[i] + st * (flux[i] - flux[i + 1]) / (F['rho'] * cp(T[i]) * vol[i]) for i in range(n)]
        t += st
        mean_max = max(mean_max, sum(Ti * v for Ti, v in zip(T, vol)) / sum(vol))
        if T[-1] + qf(T[-1]) * dr / (2 * F['k']) >= F['sol']:
            t_sol = t
            break
    return T, mean_max, t_sol


def fire_joint(partition, h=560.0, dt=0.01, t_end=300.0):
    """P101 / F201 joint, 2-D r-z explicit finite volumes on a 2 mm grid (re-coded from the description in
    sf_fire_joint): F201 flange r 129-163, z -12..0; P101 flange and shell r 129-163, z 0..12; rear wall r 45-129,
    z 0..10; flame on the F201 outside diameter and fire-side face (r > 137), and without the partition on the P101
    ring; oil on the F201 bore, the P101 shell bore and the rear-wall inner face. Highest temperatures over 5 min."""
    F = FIRE
    d = 2e-3
    rc = [(46 + 2 * i) * 1e-3 for i in range(59)]
    zc = [(-11 + 2 * j) * 1e-3 for j in range(12)]
    sol = lambda i, j: 0 <= i < 59 and 0 <= j < 12 and (rc[i] > 0.129 or (zc[j] > 0 and zc[j] < 0.010))
    Kk = lambda T: T + 273.15
    qf = lambda T: F['q0'] * (Kk(F['T_f']) ** 4 - Kk(T) ** 4) / (Kk(F['T_f']) ** 4 - Kk(20.0) ** 4)
    heff = 1 / (1 / h + d / 2 / F['k'])
    cells = [(i, j) for i in range(59) for j in range(12) if sol(i, j)]
    terms = []
    for i, j in cells:
        r, z = rc[i], zc[j]
        Ae, Aw, Az, V = (r + d / 2) * d, (r - d / 2) * d, r * d, r * d * d
        nb = []
        for di, dj, A in ((1, 0, Ae), (-1, 0, Aw), (0, 1, Az), (0, -1, Az)):
            if sol(i + di, j + dj):
                nb.append((i + di, j + dj, F['k'] / d * A))
        oil = 0.0
        if not sol(i - 1, j) and abs(r - 0.130) < 1e-9:
            oil += heff * Aw
        if not sol(i, j + 1) and r < 0.129 and abs(z - 0.009) < 1e-9:
            oil += heff * Az
        fl = 0.0
        if not sol(i + 1, j) and (z < 0 or not partition):
            fl += Ae
        if not sol(i, j - 1) and z < 0 and r > 0.137:
            fl += Az
        if not partition and not sol(i, j + 1) and z > 0 and r > 0.137:
            fl += Az
        terms.append((i, j, nb, oil, fl, V))
    T = {c: F['T_sink'] for c in cells}
    Tmax = dict(T)
    for _ in range(round(t_end / dt)):
        new = {}
        for i, j, nb, oil, fl, V in terms:
            Tc = T[(i, j)]
            q = sum(g * (T[(a, b)] - Tc) for a, b, g in nb) + oil * (F['T_sink'] - Tc) + fl * qf(Tc)
            new[(i, j)] = Tc + dt * q / (F['rho'] * (920.0 + 0.45 * Tc) * V)
        T = new
        for c in cells:
            if T[c] > Tmax[c]:
                Tmax[c] = T[c]
    at = lambda r, z: Tmax[(round((r - 46) / 2), round((z + 11) / 2))]
    return dict(seat=at(154, 11), insert=(at(154, -7) + at(154, -5)) / 2, oring_f=at(140, -1), oring_p=at(140, 1),
                p101_max=max(v for (i, j), v in Tmax.items() if zc[j] > 0))


def fire(add):
    add('TC106', 't_zero', 10 + 2 + 6 + 30, 0)
    sy = lambda T: interp(SY_FIRE, min(T, 555.0))
    hmin = {}
    for tag, t_mm, share, hf, sreq in WALLS:
        h = film_h(share) if hf is None else hf
        add('TC106', tag + '_h_basis', h)
        T, mm, ts = fire_cyl(t_mm, h, 300.0)
        if ts < float('inf'):
            add('TC106', tag + '_t_solidus_with_flow', ts, 0.03)
        else:
            _, _, ts2 = fire_cyl(t_mm, 10.0, 600.0, T)
            add('TC106', tag + '_t_solidus_after_flow', ts2, 0.05)
        key = (t_mm, sreq)
        if key not in hmin:
            ok = lambda hh: (lambda r: r[2] == float('inf') and sy(r[1]) >= sreq)(fire_cyl(t_mm, hh, 300.0))
            lo, hi = 1.0, 20000.0
            while hi - lo > 2.0:
                mid = (lo + hi) / 2
                if ok(mid):
                    hi = mid
                else:
                    lo = mid
            hmin[key] = hi
        add('TC106', tag + '_h_min', hmin[key], 0.03)
    J = fire_joint(True)
    for k in ('seat', 'insert', 'oring_f', 'oring_p', 'p101_max'):
        add('TC106', 'joint_' + k, J[k], 0.01)
    add('TC106', 'joint_nopart_p101_max', fire_joint(False)['p101_max'], 0.01)
    # residual clamp per bolt at the partition case: the seat and the insert relax to the hot yield
    F_M = 230 * math.pi / 4 * (10 ** 2 - 6.6 ** 2)
    F_res = min(F_M, sy(J['seat']) * math.pi / 4 * (10 ** 2 - 6.6 ** 2), F_M * sy(J['insert']) / 101)
    add('TC106', 'joint_residual_clamp', F_res - 0.9 * 700, 0.03)


def main():
    rows = []
    add = lambda tc, q, v, tol=1e-3: rows.append((tc, q, float(v), tol))
    fta(add)
    protect(add)
    fmea(add)
    dt(add)
    parts(add)
    design(add)
    fta2(add)
    fire(add)
    with open(OUT, 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(['tc', 'quantity', 'expected', 'tol'])
        for tc, q_, v, tol in rows:
            w.writerow([tc, q_, '%.10g' % v, tol])
    print('%d values written to %s' % (len(rows), os.path.normpath(OUT)))


if __name__ == '__main__':
    main()
