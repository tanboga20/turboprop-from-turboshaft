"""Expected values for the step 3.8 MATLAB tests (calc/tests/step38_test_cases.csv).

    python calc/reference/step38_reference.py        (standard library only)

An independent Python implementation of the closed forms of step 3.8 (calc/tolerances). Inputs are copied from
tl_inputs.m and gd_inputs.m.

Test cases:
TC107 Thermal map: the LD-02 case temperatures (15 min of first-order lag from the MCT state); the cold-start
      transient (explicit first-order lags behind the oil ramp) at a few times, and the largest lead of gear 2 over
      the first-stage case.
TC108 Gear tolerances by the ISO 1328-1:2013 formulae (class 5 values times sqrt(2)^(A - 5), rounded), the runout
      and the tooth thickness limits.
TC109 ISO 286-1 limit deviations from the formulae (tolerance unit, IT multiples, fundamental deviations).
TC110 Stack-ups: first-stage worst-case backlash at 20 degC and its thermal change per state; the ring bore change
      by the seat fit (Lame) and the planetary minimum backlash per state; the catcher-lip margin and the tube
      anchor gap per state; K_gamma with the step 2.4 uniform tolerances against the step 2.4 / 2.5 record.
TC111 Fits (Lame): the ring gear seat interference and hoop stress per state, the part-power Goodman at the
      cruise, the assembly temperature; the liner pressures; the roller-bearing operating clearance (fits, liner
      squeeze from 20 degC, inner-ring warmth); the planet pin press fit.
TC112 Splines: the ISO 4156 class tolerance (T + lambda), the fundamental deviation, the largest clearance at cold
      soak and MCT; the number of callouts in the drawing table.

Source: Phase 3 report, Section 3.8 ("Tests").
"""
import csv
import math
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
OUT = os.path.join(ROOT, 'calc', 'tests', 'step38_test_cases.csv')


def hround(v):
    """Round half away from zero (as MATLAB round)."""
    return math.floor(v + 0.5) if v >= 0 else -math.floor(-v + 0.5)

# ---- tl_inputs: thermal map
PARTS = ['oil_in', 'pinion', 'gear2', 'sun', 'planet', 'ring', 'carrier', 'brg_in', 'brg_out', 'liner', 'case_p',
         'case_f', 'P111', 'tube']
T_IDLE = [60, 65, 65, 66, 66, 62, 63, 66, 63, 62, 50, 50, 48, 60]
T_MCT = [132, 144.9, 144.9, 149.0, 149.0, 135.8, 140, 142, 137, 132, 120, 118, 115, 132]
TAU = {'gear': 60.0, 'brg': 120.0, 'carrier': 300.0, 'liner': 400.0, 'case': 600.0, 'P111': 900.0}
DT_CASE = 12.0
COLD = dict(T0=-40.0, T_ok=10.6, t_ok=9.1 * 60, rate=12.8 / 28.5, T_max=60.0, dT_gear_idle=3.0, t_end=3600)


def tau(p):
    if p in ('pinion', 'gear2', 'sun', 'planet', 'ring'):
        return TAU['gear']
    if p in ('brg_in', 'brg_out'):
        return TAU['brg']
    if p in ('carrier', 'tube'):
        return TAU['carrier']
    if p == 'liner':
        return TAU['liner']
    if p in ('case_p', 'case_f'):
        return TAU['case']
    if p == 'P111':
        return TAU['P111']
    return 1.0


def thermal(add):
    # LD-02 lag of the cases and P111 (15 min from the MCT state towards 149 - 12, P111 a further 5 K below)
    for p in ('case_p', 'case_f', 'P111'):
        tt = 149.0 - DT_CASE - (5.0 if p == 'P111' else 0.0)
        T0 = T_MCT[PARTS.index(p)]
        add('TC107', 'LD02_' + p, tt + (T0 - tt) * math.exp(-900.0 / tau(p)))
    # cold-start transient
    c = COLD
    off_idle = [T_IDLE[j] - T_IDLE[0] for j in range(len(PARTS))]
    for j in range(1, 6):
        off_idle[j] = c['dT_gear_idle']
    off_mct = [T_MCT[j] - T_MCT[0] for j in range(len(PARTS))]
    X = [c['T0']] * len(PARTS)
    out = {}
    best = (-1e9, 0)
    for k in range(1, c['t_end'] + 1):
        t = float(k)
        oil = (c['T0'] + (c['T_ok'] - c['T0']) * t / c['t_ok']) if t <= c['t_ok'] else \
            min(c['T_ok'] + c['rate'] * (t - c['t_ok']), c['T_max'])
        off = off_idle if t <= c['t_ok'] else off_mct
        Xn = [oil]
        for j in range(1, len(PARTS)):
            tgt = max(oil + off[j], c['T0'])
            Xn.append(X[j] + 1.0 / tau(PARTS[j]) * (tgt - X[j]))
        X = Xn
        if k in (300, 600, 900, 1800, 3600):
            out[k] = list(X)
        d = X[PARTS.index('gear2')] - X[PARTS.index('case_f')]
        if d > best[0]:
            best = (d, k)
    for k, X in out.items():
        for p in ('gear2', 'sun', 'carrier', 'case_f', 'case_p'):
            add('TC107', 't%d_%s' % (k, p), X[PARTS.index(p)], 2e-3)
    add('TC107', 'lead_gear2_case_f', best[0], 2e-3)
    add('TC107', 'lead_time', best[1], 0.01)


# ---- gears (gd_tolerances, tl_gears)
GEARS = (('pinion', 31, 2, 15, 52, 4, 4, (-70, 30)), ('gear2', 110, 2, 15, 52, 4, 4, (-90, 40)),
         ('sun', 45, 2, 0, 70, 5, 4, (-40, 25)), ('planet', 37, 2, 0, 70, 5, 4, (-40, 25)),
         ('ring', 119, 2, 0, 70, 5, 5, (60, 40)))


def rnd(v):
    return hround(v * 10) / 10 if v < 10 else float(hround(v))


def tol(d, mn, b, A):
    s = math.sqrt(2) ** (A - 5)
    fp = rnd((0.001 * d + 0.4 * mn + 5) * s)
    Fp = rnd((0.002 * d + 0.55 * math.sqrt(d) + 0.7 * mn + 12) * s)
    ffa = rnd((0.55 * mn + 5) * s)
    fHa = rnd((0.4 * mn + 0.001 * d + 4) * s)
    Fb = rnd(math.hypot((0.07 * math.sqrt(d) + 0.45 * math.sqrt(b) + 4) * s, (0.05 * math.sqrt(d) + 0.35 * math.sqrt(b) + 4) * s))
    return fp, Fp, ffa, fHa, Fb


def gears(add):
    for key, z, mn, beta, b, A, Ap, tt in GEARS:
        d = z * mn / math.cos(math.radians(beta))
        fp, Fp, _, _, Fb = tol(d, mn, b, A)
        _, _, ffa, fHa, _ = tol(d, mn, b, Ap)
        add('TC108', key + '_d', d)
        add('TC108', key + '_f_p', fp, 0)
        add('TC108', key + '_F_p', Fp, 0)
        add('TC108', key + '_f_fa', ffa, 0)
        add('TC108', key + '_f_Ha', fHa, 0)
        add('TC108', key + '_F_b', Fb, 0)
        add('TC108', key + '_F_r', hround(0.9 * Fp), 0)
        add('TC108', key + '_E_sni', tt[0] - tt[1], 0)


# ---- ISO 286 (tl_iso286)
STEPS = [3, 6, 10, 18, 30, 50, 80, 120, 180, 250, 315, 400, 500]
MULT = {5: 7, 6: 10, 7: 16, 8: 25, 9: 40}


def iso286(D, cls):
    k = [i for i in range(len(STEPS) - 1) if STEPS[i] < D <= STEPS[i + 1]][0]
    Dm = math.sqrt(STEPS[k] * STEPS[k + 1])
    i = 0.45 * Dm ** (1 / 3) + 0.001 * Dm
    it = lambda n: MULT[n] * i
    letter = ''.join(ch for ch in cls if not ch.isdigit())
    n = int(''.join(ch for ch in cls if ch.isdigit()))
    IT = hround(it(n))
    L = letter.lower()
    pe = it(7) + 1 + (Dm > 50) + (Dm > 120)
    se = it(8) + 4 if Dm <= 50 else it(7) + 0.4 * Dm
    ei = {'k': 0.6 * Dm ** (1 / 3), 'm': it(7) - it(6), 'n': 5 * Dm ** 0.34, 'p': pe, 'r': math.sqrt(pe * se),
          's': se}.get(L)
    es = {'f': -5.5 * Dm ** 0.41, 'g': -2.5 * Dm ** 0.34, 'h': 0.0}.get(L)
    if letter.islower():
        if L in ('f', 'g', 'h'):
            hi = hround(es)
            return hi - IT, hi
        if L == 'js':
            return -hround(IT / 2), hround(IT / 2)
        lo = hround(ei)
        return lo, lo + IT
    if L in ('f', 'g', 'h'):
        lo = -hround(es)
        return lo, lo + IT
    if L == 'js':
        return -hround(IT / 2), hround(IT / 2)
    if L == 'j':
        hi = hround(0.6 * IT)
        return hi - IT, hi
    hi = hround(-ei + (it(n) - it(n - 1)))
    return hi - IT, hi


ISO_CASES = (('H6', 180), ('J6', 180), ('K6', 85), ('M6', 90), ('H7', 259), ('n6', 120), ('m5', 45), ('k5', 45),
             ('p6', 38), ('s6', 38), ('h6', 259), ('f6', 45), ('js5', 120), ('G6', 180), ('P6', 259), ('r6', 120))


def iso(add):
    for cls, D in ISO_CASES:
        lo, hi = iso286(D, cls)
        add('TC109', '%s_%d_lo' % (cls, D), lo, 0)
        add('TC109', '%s_%d_hi' % (cls, D), hi, 0)


# ---- E3 stack-ups (tl_backlash worst-case values, tl_lame, tl_axial)
CTE = dict(steel=12.3e-6, P53=11.9e-6, A357=21.5e-6, Ti=8.8e-6)
E_ST, NU_ST, E_AL, NU_AL = 205e3, 0.29, 72e3, 0.33
STATES = ['cold soak', 'ground idle', 'cruise 50%', 'MCT, oil 132', 'LD-02, oil 149, 15 min']
T_COLD = [-40.0] * 14
T_CRUISE = [110, 117.7, 117.7, 120.2, 120.2, 112.3, 115, 117, 113, 110, 98, 97, 95, 110]


def state_map():
    ld02 = [149, 163.5, 163.5, 170.0, 170.0, 154.1, 157, 159, 154, 149, None, None, None, 149]
    for p in ('case_p', 'case_f', 'P111'):
        tt = 149.0 - DT_CASE - (5.0 if p == 'P111' else 0.0)
        T0 = T_MCT[PARTS.index(p)]
        ld02[PARTS.index(p)] = tt + (T0 - tt) * math.exp(-900.0 / tau(p))
    rows = [T_COLD, T_IDLE, T_CRUISE, T_MCT, ld02]
    return [dict(zip(PARTS, r)) for r in rows]


def lame(a, b, c, Ei, nui, Eo, nuo, delta):
    flex = b / Eo * ((c * c + b * b) / (c * c - b * b) + nuo) + b / Ei * ((b * b + a * a) / (b * b - a * a) - nui)
    p = max(delta, 0.0) / flex
    return p, -2 * p * b * b * a / (Ei * (b * b - a * a)), p * (c * c + b * b) / (c * c - b * b)


# geometry (gd_meshes): first stage a_w, alpha_wt, beta_b, pitch radii; planetary
A1, AWT1, BB1, AN = 145.9739, 0.36036, 0.24567, math.radians(20.0)
RW1 = (64.187 / 2, 227.761 / 2)
A2, AW2, R_P, R_S, R_R = 82.0, math.radians(20.0), 37.0, 45.0, 119.0
TT = dict(pinion=(-0.070, 0.030), gear2=(-0.090, 0.040), sun=(-0.040, 0.025), planet=(-0.040, 0.025), ring=(0.060, 0.040))
FR = dict(pinion=0.012, gear2=0.014, sun=0.017, planet=0.016, ring=0.020)
FA = 0.010
SEAT = dict(r=129.5, r_in=121.5, t=8.0, d_min=(-0.023 - (-0.230)) / 2)   # bore -262 / -230 um, h5 ring


def stack(add):
    S = state_map()
    kj = 2 * math.sin(AWT1) * math.cos(BB1)
    tp, tg = TT['pinion'], TT['gear2']
    wc_min = -(tp[0] + tg[0]) * math.cos(AN) - kj * (FA + (FR['pinion'] + FR['gear2']) / 2)
    wc_max = -((tp[0] - tp[1]) + (tg[0] - tg[1])) * math.cos(AN) + kj * (FA + (FR['pinion'] + FR['gear2']) / 2)
    add('TC110', 's1_wc_min_20', wc_min)
    add('TC110', 's1_wc_max_20', wc_max)
    for s, T in zip(STATES, S):
        dj = kj * (A1 * CTE['A357'] * (T['case_f'] - 20) - RW1[0] * CTE['P53'] * (T['pinion'] - 20)
                   - RW1[1] * CTE['P53'] * (T['gear2'] - 20))
        tag = s.split(',')[0].replace(' ', '_').replace('%', '')
        add('TC110', 's1_dj_' + tag, dj)
        # planetary: ring bore from the seat fit at the smallest interference, sun-planet and planet-ring minimum
        d_T = SEAT['d_min'] + SEAT['r'] * (CTE['steel'] * (T['ring'] - 20) - CTE['A357'] * (T['case_p'] - 20))
        _, u, hoop = lame(SEAT['r_in'], SEAT['r'], SEAT['r'] + SEAT['t'], E_ST, NU_ST, E_AL, NU_AL, d_T)
        da_sp = A2 * CTE['steel'] * (T['carrier'] - 20) - R_S * CTE['P53'] * (T['sun'] - 20) - R_P * CTE['P53'] * (T['planet'] - 20)
        da_pr = R_R * CTE['steel'] * (T['ring'] - 20) + u - A2 * CTE['steel'] * (T['carrier'] - 20) - R_P * CTE['P53'] * (T['planet'] - 20)
        ts, tpl, tr = TT['sun'], TT['planet'], TT['ring']
        j_sp = -(ts[0] + tpl[0]) * math.cos(AN) + 2 * math.sin(AW2) * (da_sp - (FR['sun'] + FR['planet']) / 2)
        j_pr = (tr[0] - tr[1] - tpl[0]) * math.cos(AN) + 2 * math.sin(AW2) * (da_pr - (FR['planet'] + FR['ring']) / 2)
        if abs(u) > 0:
            add('TC110', 'u_ring_' + tag, u)
        add('TC110', 'j_sp_min_' + tag, j_sp)
        add('TC110', 'j_pr_min_' + tag, j_pr)
        # axial: lip gap minimum margin and tube gap minimum
        lip = 0.80 + CTE['Ti'] * (T['P111'] - 20) * 35 - CTE['steel'] * (T['carrier'] - 20) * 35
        add('TC110', 'lip_margin_' + tag, lip - 0.10 - 0.045)
        stretch = 20e3 * 600 / (E_ST * math.pi / 4 * (120 ** 2 - 100 ** 2))
        tube = 0.50 - (CTE['steel'] * (T['carrier'] - 20) - CTE['Ti'] * (T['tube'] - 20)) * 600 - stretch
        add('TC110', 'tube_gap_' + tag, tube)
    # K_gamma with the step 2.4 uniform tolerances reproduces the step 2.4 / 2.5 record (P99 1.337, P90 1.221)
    add('TC110', 'Kgam_uniform_P99', 1.337, 0.005)
    add('TC110', 'Kgam_uniform_P90', 1.221, 0.005)


# ---- E4 fits (tl_fits)
def p5(d):
    for lim, dev in ((50, 6), (80, 7), (120, 8), (180, 10), (250, 11), (315, 13)):
        if d <= lim:
            return -dev


LINERS = dict(NU1024=(90.0, 3.0, 108.0, 0.3335, 'case_p'), NU2209=(42.5, 2.5, 58.0, 0.0859, 'case_f'),
              NU2210=(45.0, 2.5, 60.0, 0.0930, 'case_f'))
BRG = (('NU1024', 120, 180, 'n6', 0.100), ('NU2209', 45, 85, 'm5', 0.060), ('NU2210', 50, 90, 'm5', 0.060))


def fits(add):
    S = state_map()
    tags = [s.split(',')[0].replace(' ', '_').replace('%', '') for s in STATES]
    # ring gear seat: bore -262 / -230 um, ring h5
    rlo, rhi = iso286(259, 'h5')
    d20 = ((rlo - (-230)) / 2000.0, (rhi - (-262)) / 2000.0)
    add('TC111', 'seat_d20_min', 1000 * d20[0])
    add('TC111', 'seat_d20_max', 1000 * d20[1])
    for tag, T in zip(tags, S):
        dd = 129.5 * (CTE['steel'] * (T['ring'] - 20) - CTE['A357'] * (T['case_p'] - 20))
        p, _, hoop = lame(121.5, 129.5, 137.5, E_ST, NU_ST, E_AL, NU_AL, d20[1] + dd)
        add('TC111', 'seat_dmin_' + tag, 1000 * (d20[0] + dd))
        add('TC111', 'seat_hoopmax_' + tag, hoop)
    # part-power Goodman at the cruise (smallest and largest fit)
    T = S[2]
    dd = 129.5 * (CTE['steel'] * (T['ring'] - 20) - CTE['A357'] * (T['case_p'] - 20))
    for j, tag in ((0, 'min'), (1, 'max')):
        _, _, hoop = lame(121.5, 129.5, 137.5, E_ST, NU_ST, E_AL, NU_AL, d20[j] + dd)
        sm = 0.5 * 9.777 + hoop
        add('TC111', 'goodman_cruise_' + tag, 1 / (1.25 * ((0.5 * (6.025 + 11.85) + 8.4) / 42.0 + sm / 310.0)))
    add('TC111', 'T_assy', 20 + (d20[1] + 0.025) / (CTE['A357'] * 129.5))
    # liners: pressure at cold soak and MCT (smallest interference)
    for name, (ri, t, rb, d0, case) in LINERS.items():
        for tag, T in ((tags[0], S[0]), (tags[3], S[3])):
            d = d0 + (ri + t) * (CTE['steel'] * (T['liner'] - 20) - CTE['A357'] * (T[case] - 20))
            p, _, _ = lame(ri, ri + t, rb, E_ST, NU_ST, E_AL, NU_AL, d)
            add('TC111', 'liner_%s_p_%s' % (name, tag), p)
    # roller bearings: smallest operating clearance at cold soak and MCT
    for name, d, D, shaft, c0 in BRG:
        ri, t, rb, d0, case = LINERS[name]
        slo, shi = iso286(d, shaft)
        i_max = shi - p5(d)
        r_rw = D / 2 - 0.4 * (D - d) / 2
        b = ri + t
        def u(T):
            dl = d0 + b * (CTE['steel'] * (T['liner'] - 20) - CTE['A357'] * (T[case] - 20))
            _, ua, _ = lame(r_rw, b, rb, E_ST, NU_ST, E_AL, NU_AL, dl)
            _, u0, _ = lame(r_rw, b, rb, E_ST, NU_ST, E_AL, NU_AL, d0)
            return ua - u0
        for tag, T in ((tags[0], S[0]), (tags[3], S[3])):
            c = 1000 * c0 - 0.8 * max(i_max, 0) + 2000 * u(T) - CTE['steel'] * (T['brg_in'] - T['brg_out']) * (d + D) / 2 * 1000
            add('TC111', 'clear_%s_%s' % (name, tag), c)
    # planet pin H6 / s6 in the plate
    blo, bhi = iso286(38, 'H6')
    plo, phi = iso286(38, 's6')
    for j, dI in enumerate(((plo - bhi) / 2000.0, (phi - blo) / 2000.0)):
        p, _, hoop = lame(10.0, 19.0, 40.0, E_ST, NU_ST, E_ST, NU_ST, dI)
        add('TC111', 'pin_p_%d' % j, p)
        add('TC111', 'pin_hold_%d' % j, 0.12 * p * math.pi * 38 * 10)


# ---- E5 splines (tl_splines) and the drawing table
SPL = (('fixed', 1.5, 30, 'k', 5, 'gear2', 'gear2'), ('crowned', 1.5, 30, 'f', 5, 'sun', 'gear2'),
       ('coupling', 1.5, 24, 'h', 5, 'pinion', 'pinion'), ('gen', 1.0, 22, 'f', 6, 'gear2', 'gear2'),
       ('osg', 0.8, 14, 'f', 6, 'gear2', 'gear2'))


def splines(add):
    S = state_map()
    for tag, m, z, fit, cls, hub, shaft in SPL:
        D = m * z
        E = math.pi * m / 2
        i1 = 0.45 * D ** (1 / 3) + 0.001 * D
        i2 = 0.45 * E ** (1 / 3) + 0.001 * E
        Tl = {5: 10 * i1 + 40 * i2, 6: 16 * i1 + 64 * i2}[cls]
        es = {'f': iso286(D, 'f6')[1], 'h': 0, 'k': iso286(D, 'k5')[0]}[fit]
        add('TC112', tag + '_T_lambda', Tl)
        if es != 0:
            add('TC112', tag + '_es', es, 0)
        for st, T in (('cold', S[0]), ('MCT', S[3])):
            dc = 1000 * D * CTE['P53'] * ((T[hub] - 20) - (T[shaft] - 20)) * math.tan(math.radians(30))
            add('TC112', '%s_cmax_%s' % (tag, st), 2 * Tl - es + dc)
    add('TC112', 'n_callouts', 72, 0)


def main():
    rows = []
    add = lambda tc, q, v, tol=1e-3: rows.append((tc, q, float(v), tol))
    thermal(add)
    gears(add)
    iso(add)
    stack(add)
    fits(add)
    splines(add)
    with open(OUT, 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(['tc', 'quantity', 'expected', 'tol'])
        for tc, q_, v, tol_ in rows:
            w.writerow([tc, q_, '%.10g' % v, tol_])
    print('%d values written to %s' % (len(rows), os.path.normpath(OUT)))


if __name__ == '__main__':
    main()
