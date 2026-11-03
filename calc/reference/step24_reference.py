"""Expected values for the step 2.4 MATLAB tests (calc/tests/step24_test_cases.csv).

    python calc/reference/step24_reference.py        (needs numpy and scipy; rotordynamics/.venv has both)

An independent Python implementation of the step 2.4 gear rating. Inputs are copied from
calc/gear_detail/gd_inputs.m. Test cases:

TC33  ISO 6336-3 Method B tooth root values (s_Fn, rho_F, h_Fe, Y_F, Y_S) of the pinion, gear 2, sun, planet
      and ring. s_Fn, rho_F and the height of the critical section come from a numerical simulation of the
      generating cut (the hob rack rolling on the virtual spur gear; the shaper cutter meshing inside the ring),
      with the 30 deg (external) or 60 deg (internal) tangent found on the simulated fillet.
TC34  Geometry and contact factors: centre distance, contact ratios, Z_H, Z_eps, Z_B, Z_D.
TC35  Tooth stiffness, K_v (Method B, planetary per 6.5.8.4), K_Hbeta and K_Fbeta (Method C) at MCT, with
      K_gamma 1.30 on the planetary meshes.
TC36  Pitting and root safety factors at MCT (1e10 cycles) and in the static case (137.5% torque, K_A 1).
TC37  Planet load sharing for given path errors: a full static model with the sun (x, y, rotation) and each
      planet (x, y, rotation) on a pin spring, mesh springs along the lines of action, carrier and ring fixed.
      MATLAB reduces each planet to a series load path; this model does not.
TC38  Flash temperature, bulk temperature, scuffing safety and film thickness ratio (MIL-PRF-23699, 132 C).
TC39  Modes: free thin ring (Hoppe); first-stage gear web with rim by a Rayleigh-Ritz model; the bare web by
      the exact Bessel-function solution of the clamped-free annular plate.

Source: Phase 2 report, Section 2.4 ("Tests").
"""
import csv
import os

import numpy as np
from scipy.linalg import eigh
from scipy.optimize import brentq
from scipy.special import iv, ivp, jv, jvp, kv, kvp, yv, yvp

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tests', 'step24_test_cases.csv')

# ---------------------------------------------------------------- inputs (gd_inputs.m)
P, N_PT = 895e3, 22000.0
T_PT = P / (N_PT * np.pi / 30)
S1 = dict(z1=31, z2=110, mn=2.0, beta=15.0, b=52.0, x1=0.20, x2=-0.20)
S2 = dict(zs=45, zp=37, zr=119, m=2.0, b=70.0, N=4, xs=0.0, xp=0.0, xr=0.0, ha_r=0.9)
AN = np.radians(20.0)
HOB = dict(hfP=1.25, rhofP=0.38)
SHAPER = dict(z0=38, x0=0.0, haP0=1.25, rhoa0=0.25)
CHAMFER = 0.10
A_S1, A_S2 = 4, 5
EH = dict(type='Eh', sHlim=1650.0, sFlim=525.0, E=206e3, nu=0.3)
NT = dict(type='NT', sHlim=1450.0, sFlim=468.0, E=206e3, nu=0.3)
RHO = 7.83e-6
RZ_FLANK, RZ_RING, RZ_ROOT = 0.8, 1.0, 10.0
K_OVER = 1.375
GEAR2_RIM, GEAR2_WEB = 3.5, 8.0
D_BORE_PINION, SUN_BORE, PLANET_RIM, RING_RIM = 24.0, 48.0, 4.0, 4.0
CARRIER = dict(L_pin=82.0, post_w=32.0, post_t=60.0, L_post=82.0, E=206e3, f_pin_par=5.0)
K_BRG, K_PIN = 2.5e9, 6.0e9
OIL = dict(nu40=27.6, nu100=5.1, rho15=1003.5, a100=1.00e-8, a150=0.85e-8, S_FZG=8, XL=1.0)
XS, XW, LAM_STEEL, C_STEEL = 1.2, 1.0, 40.0, 470.0

inv = lambda a: np.tan(a) - a


def rot(p, a):
    c, s = np.cos(a), np.sin(a)
    return np.array([c * p[0] - s * p[1], s * p[0] + c * p[1]])


# ---------------------------------------------------------------- tolerances (ISO 1328-1:2013 formulae)
def tol(d, mn, b, A):
    s = np.sqrt(2) ** (A - 5)
    r = lambda v: round(v * 10) / 10 if v < 10 else float(round(v))
    fHb = (0.05 * np.sqrt(d) + 0.35 * np.sqrt(b) + 4) * s
    return dict(f_p=r((0.001 * d + 0.4 * mn + 5) * s), F_p=r((0.002 * d + 0.55 * np.sqrt(d) + 0.7 * mn + 12) * s),
                f_fa=r((0.55 * mn + 5) * s), f_Hb=r(fHb))


# ---------------------------------------------------------------- generating-cut simulation (TC33)
def fillet_point(C, rho, ps, tangent, bottom):
    def dC(p, h=1e-7):
        return (C(p + h) - C(p - h)) / (2 * h)

    def F(p):
        c, d = C(p), dC(p)
        n = np.array([d[1], -d[0]]) / np.hypot(*d)
        if n[0] * c[0] > 0:
            n = -n
        return c + rho * n

    ang = lambda p: np.degrees(np.arctan2(abs(dC(p)[0]), abs(dC(p)[1])))
    rr = np.array([np.hypot(*C(p)) for p in ps])
    ib = int(np.argmin(rr) if bottom == 'min' else np.argmax(rr))
    cands = []
    for idx in (range(ib, len(ps)), range(ib, -1, -1)):
        prev = None
        for i in idx:
            if prev is not None and (ang(ps[prev]) - tangent) * (ang(ps[i]) - tangent) <= 0:
                cands.append(brentq(lambda p: ang(p) - tangent, min(ps[prev], ps[i]), max(ps[prev], ps[i]),
                                    xtol=1e-15))
                break
            prev = i
    pts = [F(p) for p in cands]
    k = int(np.argmin([abs(q[0]) for q in pts]))
    p0, Pt = cands[k], pts[k]
    h = 2e-5
    d1 = (F(p0 + h) - F(p0 - h)) / (2 * h)
    d2 = (F(p0 + h) - 2 * Pt + F(p0 - h)) / h ** 2
    rhoF = np.hypot(*d1) ** 3 / abs(d1[0] * d2[1] - d1[1] * d2[0])
    return 2 * abs(Pt[0]), rhoF, abs(Pt[1])


def root_values(z, mn, beta_deg, x, dNa, eps_a, eps_b, internal):
    beta = np.radians(beta_deg)
    bb = np.arcsin(np.sin(beta) * np.cos(AN))
    zn = z / (np.cos(bb) ** 2 * np.cos(beta))
    ean = eps_a / np.cos(bb) ** 2
    if not internal:
        rfP, hfP = HOB['rhofP'] * mn, HOB['hfP'] * mn
        r = zn * mn / 2
        E = np.pi / 4 * mn - hfP * np.tan(AN) - rfP * (1 - np.sin(AN)) / np.cos(AN)
        X0, Y0 = np.pi * mn / 2 - E, r + x * mn - (hfP - rfP)
        C = lambda p: rot(np.array([X0 - r * p, Y0]), -p)
        sFn, rhoF, yc = fillet_point(C, rfP, np.linspace(-0.4, 0.4, 8001), 30.0, 'min')
    else:
        z0 = SHAPER['z0']
        rho = SHAPER['rhoa0'] * mn
        Z = zn
        xi = inv(AN) + 2 * np.tan(AN) * (SHAPER['x0'] + x) / (z0 - Z)
        aw = brentq(lambda a: inv(a) - xi, 1e-3, 1.4)
        a0 = mn * (Z - z0) / 2 * np.cos(AN) / np.cos(aw)
        rw, rw0 = a0 * Z / (Z - z0), a0 * z0 / (Z - z0)
        rb0 = mn * z0 / 2 * np.cos(AN)
        rM = mn * (z0 / 2 + SHAPER['haP0'] + SHAPER['x0']) - rho
        dal = (np.pi / 2 + 2 * SHAPER['x0'] * np.tan(AN)) / z0 + inv(AN) - inv(np.arccos(rb0 / rM)) - rho / rb0
        Mc = np.array([rM * np.sin(dal), rM * np.cos(dal)])
        tooth = -np.pi / Z
        C = lambda pg: rot(rot(np.array([0.0, a0]) + rot(Mc, pg * rw / rw0), -pg), -tooth)
        sFn, rhoF, yc = fillet_point(C, rho, np.linspace(-0.3, 0.3, 12001), 60.0, 'max')
    # load at the outer point of single pair contact of the virtual gear (signed for the internal gear)
    sg = -1 if internal else 1
    zs = sg * z
    d = zs * mn / np.cos(beta)
    dn = d / np.cos(bb) ** 2
    dbn = dn * np.cos(AN)
    dan = dn + sg * dNa - d
    den = 2 * sg * np.sqrt((np.sqrt((dan / 2) ** 2 - (dbn / 2) ** 2)
                            - np.pi * d * np.cos(beta) * np.cos(AN) / abs(zs) * (ean - 1)) ** 2 + (dbn / 2) ** 2)
    aen = np.arccos(dbn / den)
    ge = (0.5 * np.pi + 2 * x * np.tan(AN)) / (sg * zn) + inv(AN) - inv(aen)
    aFen = aen - ge
    yL = abs((np.cos(ge) - np.sin(ge) * np.tan(aFen)) * den / 2)
    hFe = abs(yL - yc)
    if eps_b <= 0:
        fe = 1.0 if ean < 2 else 0.7
    elif eps_b < 1:
        fe = np.sqrt(1 - eps_b + eps_b / ean) if ean < 2 else np.sqrt((1 - eps_b) / 2 + eps_b / ean)
    else:
        fe = ean ** -0.5
    YF = 6 * (hFe / mn) * np.cos(aFen) / ((sFn / mn) ** 2 * np.cos(AN)) * fe
    qs, L = sFn / (2 * rhoF), sFn / hFe
    YS = (1.2 + 0.13 * L) * qs ** (1 / (1.21 + 2.3 / L))
    df = (abs(d) - 2 * (HOB['hfP'] * mn - x * mn)) if not internal else 2 * (abs(a0) + rM + rho)
    return dict(sFn=sFn, rhoF=rhoF, hFe=hFe, YF=YF, YS=YS, qs=qs, df=df, ean=ean)


# ---------------------------------------------------------------- pair geometry (TC34)
def pair(z1, z2, mn, beta_deg, b, x1, x2, internal, A, ha2=1.0):
    beta = np.radians(beta_deg)
    at = np.arctan(np.tan(AN) / np.cos(beta))
    mt = mn / np.cos(beta)
    bb = np.arctan(np.tan(beta) * np.cos(at))
    d1, d2 = z1 * mt, z2 * mt
    db1, db2 = d1 * np.cos(at), d2 * np.cos(at)
    if internal:
        awt = brentq(lambda a: inv(a) - inv(at) - 2 * np.tan(AN) * (x1 + x2) / (z1 - z2), 0.2, 0.6)
        aw = (d2 - d1) / 2 * np.cos(at) / np.cos(awt)
        da2 = d2 - 2 * mn * (ha2 + x2)
        dNa2 = da2 + 2 * CHAMFER
    else:
        awt = brentq(lambda a: inv(a) - inv(at) - 2 * np.tan(AN) * (x1 + x2) / (z1 + z2), 0.2, 0.6)
        aw = (d1 + d2) / 2 * np.cos(at) / np.cos(awt)
        da2 = d2 + 2 * mn * (ha2 + x2)
        dNa2 = da2 - 2 * CHAMFER
    da1 = d1 + 2 * mn * (1 + x1)
    dNa1 = da1 - 2 * CHAMFER
    T12 = aw * np.sin(awt)
    r1E = np.sqrt((dNa1 / 2) ** 2 - (db1 / 2) ** 2)
    r2t = np.sqrt((dNa2 / 2) ** 2 - (db2 / 2) ** 2)
    r1A = r2t - T12 if internal else T12 - r2t
    rho2 = (lambda r: r + T12) if internal else (lambda r: T12 - r)
    ga = r1E - r1A
    pet = np.pi * mt * np.cos(at)
    ea, eb = ga / pet, b * np.sin(beta) / (np.pi * mn)
    r1C = db1 / 2 * np.tan(awt)
    r1B, r1D = r1E - pet, r1A + pet
    ZH = np.sqrt(2 * np.cos(bb) * np.cos(awt) / (np.cos(at) ** 2 * np.sin(awt)))
    Zeps = np.sqrt((4 - ea) / 3 * (1 - eb) + eb / ea) if eb < 1 else np.sqrt(1 / ea)
    M1 = np.sqrt(r1C * rho2(r1C) / (r1B * rho2(r1B)))
    M2 = np.sqrt(r1C * rho2(r1C) / (r1D * rho2(r1D)))
    e1 = min(eb, 1.0)
    ZB = max(M1, 1) - e1 * (max(M1, 1) - 1)
    ZD = 1.0 if internal else max(M2, 1) - e1 * (max(M2, 1) - 1)
    g = dict(z1=z1, z2=z2, u=z2 / z1, mn=mn, b=b, beta=beta, bb=bb, at=at, awt=awt, aw=aw, d1=d1, d2=d2,
             db1=db1, db2=db2, da1=da1, da2=da2, dNa1=dNa1, dNa2=dNa2, internal=internal, x1=x1, x2=x2,
             ea=ea, eb=eb, eg=ea + eb, pet=pet, ga=ga, T12=T12, r1A=r1A, r1E=r1E, r1C=r1C, rho2=rho2,
             ZH=ZH, Zeps=Zeps, ZB=ZB, ZD=ZD, tol1=tol(d1, mn, b, A), tol2=tol(d2, mn, b, A), A=A,
             dw1=2 * aw / (z2 / z1 + (-1 if internal else 1)))
    g['root1'] = root_values(z1, mn, beta_deg, x1, dNa1, ea, eb, False)
    g['root2'] = root_values(z2, mn, beta_deg, x2, dNa2, ea, eb, internal)
    g['h1'] = (da1 - g['root1']['df']) / 2
    g['h2'] = abs(g['root2']['df'] - da2) / 2
    return g


# ---------------------------------------------------------------- meshes (gd_meshes.m)
def mstar(dm, q, db):
    return np.pi / 8 * RHO * dm ** 4 * (1 - q ** 4) / db ** 2


def build():
    s = S1
    g1 = pair(s['z1'], s['z2'], s['mn'], s['beta'], s['b'], s['x1'], s['x2'], False, A_S1)
    dm1 = (g1['da1'] + g1['root1']['df']) / 2
    dm2 = (g1['da2'] + g1['root2']['df']) / 2
    di2 = g1['root2']['df'] - 2 * GEAR2_RIM * s['mn']
    CR = 1 + np.log(min(max(GEAR2_WEB / s['b'], 0.2), 1.2)) / (5 * np.exp(GEAR2_RIM / 5))
    m1 = dict(name='s1', g=g1, mat1=EH, mat2=EH, T1=T_PT, n1=N_PT, Kgam=1.0, rev1=False, rev2=False,
              kv=('pair', mstar(dm1, D_BORE_PINION / dm1, g1['db1']), mstar(dm2, di2 / dm2, g1['db2'])),
              ksh=0.023 * (s['b'] / g1['d1']) ** 2,
              fma=np.hypot(g1['tol1']['f_Hb'], g1['tol2']['f_Hb']), CR=CR, Rz=(RZ_FLANK, RZ_FLANK),
              sR=(np.inf, GEAR2_RIM * s['mn']))
    p = S2
    u1 = S1['z2'] / S1['z1']
    Ts, ns = T_PT * u1, N_PT / u1
    nc = ns / (1 + p['zr'] / p['zs'])
    np_rel = (ns - nc) * p['zs'] / p['zp']
    Tp = Ts / p['N'] * p['zp'] / p['zs']
    gsp = pair(p['zp'], p['zs'], p['m'], 0.0, p['b'], p['xp'], p['xs'], False, A_S2)
    gpr = pair(p['zp'], p['zr'], p['m'], 0.0, p['b'], p['xp'], p['xr'], True, A_S2, p['ha_r'])
    dms = (gsp['da2'] + gsp['root2']['df']) / 2
    dmp = (gsp['da1'] + gsp['root1']['df']) / 2
    Dor = gsp['root1']['df'] - 2 * PLANET_RIM * p['m']
    kvp_ = ('planetary', mstar(dms, SUN_BORE / dms, gsp['db2']), mstar(dmp, Dor / dmp, gsp['db1']), p['N'],
            p['zs'], p['zp'] / p['zs'])
    G = EH['E'] / (2 * (1 + EH['nu']))
    Js = np.pi / 32 * (gsp['root2']['df'] ** 4 - SUN_BORE ** 4)
    k_twist = gsp['db2'] / 2 * p['N'] * gsp['d2'] / 2 * p['b'] * p['b'] / (2 * G * Js) * 1000
    c = CARRIER
    I = c['post_t'] * c['post_w'] ** 3 / 12
    kpost = 1 / (c['L_post'] ** 3 / (12 * c['E'] * I) + c['L_post'] / (5 / 6 * G * c['post_w'] * c['post_t']))
    k_car = p['b'] / kpost * (p['b'] / c['L_pin']) * np.cos(gsp['awt']) * 1000
    fpin = c['f_pin_par'] * p['b'] / c['L_pin']
    m2 = dict(name='sp', g=gsp, mat1=EH, mat2=EH, T1=Tp, n1=np_rel, Kgam=1.0, rev1=True, rev2=False, kv=kvp_,
              ksh=abs(k_twist - k_car),
              fma=np.sqrt(gsp['tol1']['f_Hb'] ** 2 + gsp['tol2']['f_Hb'] ** 2 + fpin ** 2), CR=1.0,
              Rz=(RZ_FLANK, RZ_FLANK), sR=(PLANET_RIM * p['m'], (gsp['root2']['df'] - SUN_BORE) / 2))
    m3 = dict(name='pr', g=gpr, mat1=EH, mat2=NT, T1=Tp, n1=np_rel, Kgam=1.0, rev1=True, rev2=False, kv=kvp_,
              ksh=k_car, fma=np.sqrt(gpr['tol1']['f_Hb'] ** 2 + gpr['tol2']['f_Hb'] ** 2 + fpin ** 2), CR=1.0,
              Rz=(RZ_FLANK, RZ_RING), sR=(PLANET_RIM * p['m'], RING_RIM * p['m']))
    return [m1, m2, m3], Ts


# ---------------------------------------------------------------- rating (TC35, TC36)
def stiffness(g, CR, w):
    C = [0.04723, 0.15551, 0.25791, -0.00635, -0.11654, -0.00193, -0.24188, 0.00529, 0.00182]
    zn1 = g['z1'] / np.cos(g['beta']) ** 3
    x1 = g['x1']
    i2, x2 = (0.0, 0.0) if g['internal'] else (np.cos(g['beta']) ** 3 / g['z2'], g['x2'])
    q = (C[0] + C[1] / zn1 + C[2] * i2 + C[3] * x1 + C[4] * x1 / zn1 + C[5] * x2 + C[6] * x2 * i2
         + C[7] * x1 ** 2 + C[8] * x2 ** 2)
    c0 = 1 / q * 0.8 * CR * (1 + 0.5 * (1.2 - 1.25)) * np.cos(g['beta'])
    c = c0 * (w / 100) ** 0.25 if w < 100 else c0
    cga = c * (0.75 * g['ea'] + 0.25)
    return c0, c, cga, 0.85 * cga


def kv_factor(m, g, c, cga, Ft, n1, KA, Kg, Ca):
    eg = g['eg']
    if eg <= 2:
        Cv = [0.32, 0.34, 0.23, 0.90, 0.47, 0.47]
    else:
        Cv = [0.32, 0.57 / (eg - 0.3), 0.096 / (eg - 1.56), (0.57 - 0.05 * eg) / (eg - 1.44), 0.47,
              0.12 / (eg - 1.74)]
    Cv7 = 0.75 if eg <= 1.5 else (0.125 * np.sin(np.pi * (eg - 2)) + 0.875 if eg <= 2.5 else 1.0)
    w = KA * Kg * Ft / g['b']
    fpb = max(g['tol1']['f_p'], g['tol2']['f_p'])
    ffa = max(g['tol1']['f_fa'], g['tol2']['f_fa'])
    Bp = c * (fpb - min(0.075 * fpb, 3)) / w
    Bf = c * (ffa - min(0.075 * ffa, 3)) / w
    Bk = abs(1 - c * Ca / w)
    NS = 0.5 + 0.35 * np.sqrt(w / 100) if w < 100 else 0.85
    if m['kv'][0] == 'pair':
        m1_, m2_ = m['kv'][1], m['kv'][2]
        Ns = [n1 / (30000 / (np.pi * g['z1']) * np.sqrt(cga / (m1_ * m2_ / (m1_ + m2_))))]
    else:
        _, msun, mpla, N, zsun, sp = m['kv']
        Ns = [n1 * sp / (30000 / (np.pi * zsun) * np.sqrt(cga / mr))
              for mr in (mpla * msun / (N * mpla + msun), mpla)]
    out = []
    for N in Ns:
        sub = N * (Cv[0] * Bp + Cv[1] * Bf + Cv[2] * Bk) + 1
        res = Cv[0] * Bp + Cv[1] * Bf + Cv[3] * Bk + 1
        sup = Cv[4] * Bp + Cv[5] * Bf + Cv7
        if N <= NS:
            out.append(sub)
        elif N <= 1.15:
            out.append(res)
        elif N < 1.5:
            out.append(sup + (res - sup) * (1.5 - N) / 0.35)
        else:
            out.append(sup)
    return max(out)


def sn(kind, typ, Gs, Gr, N):
    Ns = 1e5 if kind == 'H' else 1e3
    Nr = (5e7 if typ == 'Eh' else 2e6) if kind == 'H' else 3e6
    if N <= Ns:
        return Gs
    if N <= Nr:
        return Gr * (Nr / N) ** (np.log(Gs / Gr) / np.log(Nr / Ns))
    return Gr * (Nr / N) ** (-np.log(0.85) / np.log(1e10 / Nr))


def rate(m, T1, n1, KA, Kg, mode):
    g = m['g']
    b = g['b']
    Ft = 2000 * T1 / g['d1']
    v = np.pi * g['d1'] * n1 / 60000
    c0, c, cga, cgb = stiffness(g, m['CR'], Ft * KA * Kg / b)
    Ca = KA * m['Kgam'] * (2000 * m['T1'] / g['d1']) / b / c0
    Kv = kv_factor(m, g, c, cga, Ft, n1, KA, Kg, Ca)
    Fm = Ft * KA * Kg * Kv
    Fmc = 2000 * m['T1'] / g['d1'] * KA * m['Kgam'] * Kv
    fsh, fshc = m['ksh'] * Fm / b, m['ksh'] * Fmc / b
    fHb = max(g['tol1']['f_Hb'], g['tol2']['f_Hb'])
    Fbx = max(1.33 * abs(fsh - 0.9 * fshc) + 0.5 * m['fma'], 0.005 * Fm / b, 0.5 * fHb)
    Fby = Fbx - min(0.15 * Fbx, 6)
    q = Fby * cgb / (2 * Fm / b)
    KHb = 1 + q if q < 1 else np.sqrt(2 * Fby * cgb / (Fm / b))
    bh = max(min(b / g['h1'], b / g['h2']), 3)
    KFb = KHb ** (bh ** 2 / (1 + bh + bh ** 2))
    fpb = 0.5 * max(g['tol1']['f_p'], g['tol2']['f_p'])
    ya = min(0.075 * fpb, 3)
    FtH = Fm * KHb
    eg = g['eg']
    if eg <= 2:
        KHa = eg / 2 * (0.9 + 0.4 * cga * (fpb - ya) / (FtH / b))
    else:
        KHa = 0.9 + 0.4 * np.sqrt(2 * (eg - 1) / eg) * cga * (fpb - ya) / (FtH / b)
    KFa = min(max(KHa, 1), eg / (0.25 * g['ea'] + 0.75))
    KHa = min(max(KHa, 1), eg / (g['ea'] * g['Zeps'] ** 2))
    # pitting
    us = (g['u'] - 1) / g['u'] if g['internal'] else (g['u'] + 1) / g['u']
    ZE = np.sqrt(1 / (np.pi * 2 * (1 - 0.09) / 206e3))
    sH0 = g['ZH'] * ZE * g['Zeps'] / np.sqrt(np.cos(g['beta'])) * np.sqrt(Ft / (g['d1'] * b) * us)
    K = KA * Kg * Kv * KHb * KHa
    sH = [g['ZB'] * sH0 * np.sqrt(K), g['ZD'] * sH0 * np.sqrt(K)]
    sl = min(m['mat1']['sHlim'], m['mat2']['sHlim'])
    CZL = 0.91 if sl > 1200 else (sl / 4375 + 0.6357 if sl >= 850 else 0.83)
    ZL = CZL + 4 * (1 - CZL) / (1.2 + 134 / OIL['nu40']) ** 2
    Zv = CZL + 0.02 + 2 * (1 - CZL - 0.02) / np.sqrt(0.8 + 32 / v)
    r1 = g['db1'] / 2 * np.tan(g['awt'])
    r2 = g['db2'] / 2 * np.tan(g['awt']) * (-1 if g['internal'] else 1)
    rred = r1 * r2 / (r1 + r2)
    Rz10 = sum(m['Rz']) / 2 * (10 / rred) ** (1 / 3)
    ZR = (3 / Rz10) ** 0.08
    mats = (m['mat1'], m['mat2'])
    out = {}
    for i in range(2):
        mt = mats[i]
        zst = 1.6 if mt['type'] == 'Eh' else 1.3
        Gs, Gr = mt['sHlim'] * zst, mt['sHlim'] * ZL * Zv * ZR
        G = Gs if mode == 'static' else sn('H', mt['type'], Gs, Gr, 1e10)
        out['S_H%d' % (i + 1)] = G / sH[i]
    # root
    bd = min(np.degrees(g['beta']), 30)
    Yb = (1 - min(g['eb'], 1) * bd / 120) / np.cos(np.radians(bd)) ** 3
    for i in range(2):
        rt = g['root%d' % (i + 1)]
        mt = mats[i]
        sR = m['sR'][i]
        h = g['h%d' % (i + 1)]
        internal = g['internal'] and i == 1
        if internal:
            YB = 1.0 if sR / g['mn'] >= 3.5 else 1.15 * np.log(8.324 / (sR / g['mn']))
        else:
            YB = 1.0 if sR / h >= 1.2 else 1.6 * np.log(2.242 / (sR / h))
        sF = Ft / (b * g['mn']) * rt['YF'] * rt['YS'] * Yb * YB * KA * Kg * Kv * KFb * KFa
        eh = mt['type'] == 'Eh'
        Yds = 0.44 * rt['YS'] + 0.12 if eh else 0.20 * rt['YS'] + 0.60
        rp = 0.0030 if eh else 0.1005
        Ydr = (1 + np.sqrt(rp * 0.2 * (1 + 2 * rt['qs']))) / (1 + np.sqrt(rp * 1.2))
        YR = 1.674 - 0.529 * (RZ_ROOT + 1) ** 0.1 if eh else 4.299 - 3.259 * (RZ_ROOT + 1) ** 0.005
        rev = m['rev%d' % (i + 1)]
        YMf = lambda M_: 1 / (1 + 1.2 * (1 - M_) / (1 + M_))
        YMs = YMf(0.7 if eh else 0.3) if rev else 1.0
        YMr = YMf(0.8 - 0.15 * rt['YS'] if eh else 0.3) if rev else 1.0
        Gs = mt['sFlim'] * 2 * (2.5 if eh else 1.6) * Yds * YMs
        Gr = mt['sFlim'] * 2 * Ydr * YR * YMr
        G = Gs if mode == 'static' else sn('F', mt['type'], Gs, Gr, 1e10)
        out['S_F%d' % (i + 1)] = G / sF
    out.update(dict(Ft=Ft, c=c, cga=cga, Kv=Kv, KHb=KHb, KFb=KFb, KHa=KHa, K=K, v=v))
    return out


# ---------------------------------------------------------------- scuffing and film (TC38)
def oil_at(T):
    A = np.log10(np.log10(OIL['nu40'] + 0.7) / np.log10(OIL['nu100'] + 0.7)) / np.log10(313 / 373)
    B = np.log10(np.log10(OIL['nu40'] + 0.7)) - A * np.log10(313)
    nu = 10 ** (10 ** (A * np.log10(T + 273) + B)) - 0.7
    return nu, OIL['rho15'] * (1 - 7.0e-4 * (T - 15))


def scuffing(m, r, n1, Toil, Xmp):
    g = m['g']
    x = np.linspace(0, g['ga'], 81)
    r1 = g['r1A'] + x
    r2 = g['rho2'](r1)
    w1 = n1 * np.pi / 30
    v1, v2 = w1 * r1 / 1000, w1 / g['u'] * r2 / 1000
    rt = r1 * r2 / (r2 - r1) if g['internal'] else r1 * r2 / (r1 + r2)
    rn = rt / np.cos(g['bb'])
    if g['eb'] >= 1.2:
        ea = g['ea']
        Xm = 1 / ea + (ea - 1) / (ea * (ea + 1))
        gAB = (g['ga'] - g['pet']) / 2
        X = Xm * np.minimum(np.minimum(x / gAB, 1), (g['ga'] - x) / (g['ga'] - gAB - g['pet']))
    else:
        X = np.minimum(np.minimum(x / (g['ga'] - g['pet']), 1), (g['ga'] - x) / (g['ga'] - g['pet']))
    X = np.maximum(X, 0)
    Er = 206e3 / (1 - 0.09)
    w = r['Ft'] * r['K'] * X / (g['b'] * np.cos(g['at']))
    p = np.sqrt(Er * w / (2 * np.pi * rn))
    bH = 4 * rn * p / Er
    nu, dens = oil_at(Toil)
    vS = 2 * w1 * g['dw1'] / 2 / 1000 * np.sin(g['awt'])
    rC = g['r1C']
    rnC = rC * g['rho2'](rC) / ((g['rho2'](rC) - rC) if g['internal'] else (rC + g['rho2'](rC))) / np.cos(g['bb'])
    eg = g['eg']
    KBg = 1.0 if eg <= 2 else (1 + 0.2 * np.sqrt((eg - 2) * (5 - eg)) if eg < 3.5 else 1.3)
    Ra = sum(m['Rz']) / 2 / 6
    mu = 0.045 * (r['Ft'] * r['K'] / g['b'] * KBg / (vS * rnC)) ** 0.2 * (nu * dens / 1000) ** -0.05 \
        * 2.2 * (Ra / rnC) ** 0.25 * OIL['XL']
    BM = np.sqrt(LAM_STEEL * RHO * 1e9 * C_STEEL)
    with np.errstate(invalid="ignore", divide="ignore"):
        fl = 0.785 * mu * w * 1000 * np.abs(np.sqrt(v1) - np.sqrt(v2)) / (BM * np.sqrt(bH / 1000))
    fl[X <= 0] = 0
    flm = np.trapezoid(fl, x) / g['ga']
    thM = Toil + 0.47 * XS * Xmp * flm
    thS = 80 + (0.85 + 1.4 * XW) * OIL['XL'] * OIL['S_FZG'] ** 2
    SS = (thS - Toil) / (np.max(thM + fl) - Toil)
    nuM, dM = oil_at(thM)
    alpha = OIL['a100'] + (OIL['a150'] - OIL['a100']) * (thM - 100) / 50
    iC = int(np.argmin(np.abs(r1 - rC)))
    h = 2.65 * (nuM * 1e-6 * dM * (v1[iC] + v2[iC]) / 2) ** 0.7 * alpha ** 0.54 * (rn[iC] / 1000) ** 0.43 \
        * (Er * 1e6) ** -0.03 * (w[iC] * 1000) ** -0.13 * 1e6
    lamC = h / np.hypot(m['Rz'][0] / 6, m['Rz'][1] / 6)
    return dict(flmax=np.max(fl), thM=thM, SS=SS, lamC=lamC)


# ---------------------------------------------------------------- load sharing, full model (TC37)
def load_share(m2, Ts, ksp, kpr, E, scale=1.0):
    """Sun (x, y, theta) and planets (x, y, theta) on pin springs; ring and carrier fixed."""
    g = m2['g']
    N = S2['N']
    al = g['awt']
    rs, rp = g['d2'] / 2, g['d1'] / 2          # pitch radii of sun and planet
    rc = rs + rp
    ksp, kpr = ksp * 1000, kpr * 1000           # N/mm
    ks = 1 / (1 / (K_BRG / 1000) + 1 / (K_PIN / 1000))
    nd = 3 + 3 * N
    K = np.zeros((nd, nd))
    Fv = np.zeros(nd)
    z = np.array([0, 0, 1.0])

    def point_row(dofs, centre, P, n):
        # row giving (displacement of the body point at P) . n for body DOFs (dx, dy, theta)
        row = np.zeros(nd)
        row[dofs[0]] = n[0]
        row[dofs[1]] = n[1]
        rr = np.append(P - centre, 0)
        row[dofs[2]] = np.dot(np.cross(z, rr)[:2], n)
        return row

    sun = [0, 1, 2]
    rows = []
    for i in range(N):
        psi = 2 * np.pi * i / N
        t = np.array([-np.sin(psi), np.cos(psi)])
        rv = np.array([np.cos(psi), np.sin(psi)])
        cp = rc * rv
        pl = [3 + 3 * i, 4 + 3 * i, 5 + 3 * i]
        # sun-planet mesh: pitch point between the centres, force on the planet along n
        Psp = rs * rv
        n = np.cos(al) * t + np.sin(al) * rv
        row_sp = point_row(sun, np.zeros(2), Psp, n) - point_row(pl, cp, Psp, n)
        # planet-ring mesh: pitch point outside the planet, force on the planet along mr (ring fixed)
        Ppr = (rc + rp) * rv
        mr = np.cos(al) * t - np.sin(al) * rv
        row_pr = -point_row(pl, cp, Ppr, mr)
        K += ksp * np.outer(row_sp, row_sp) + kpr * np.outer(row_pr, row_pr)
        # pin spring to the pin position shifted tangentially by e_i = E_i / (2 cos alpha)
        e = E[i] / (2 * np.cos(al))
        for j, d in enumerate(pl[:2]):
            K[d, d] += ks
            Fv[d] += ks * e * t[j]
        rows.append(row_sp)
    Fv[2] += scale * Ts * 1000                   # sun torque [N mm]
    q = np.linalg.lstsq(K, Fv, rcond=None)[0]
    F = np.array([ksp * r_.dot(q) for r_ in rows])
    return F.max() / F.mean(), np.hypot(q[0], q[1])


# ---------------------------------------------------------------- modes (TC39)
def ring_modes(R, h, b, ht, ns):
    I = b * h ** 3 / 12
    m = RHO * b * (h + ht)
    c = np.sqrt(206e3 * 1e6 * I * 1e-12 / (m * 1e3 * (R / 1000) ** 4))
    return [n * (n ** 2 - 1) / np.sqrt(n ** 2 + 1) * c / (2 * np.pi) for n in ns]


def web_ritz(p, n, rim=True, nb=12):
    a, b = p['r_in'] / 1000, p['r_out'] / 1000
    t = p['t'] / 1000
    E, nu, rho = 206e9, 0.3, RHO * 1e9
    D = E * t ** 3 / (12 * (1 - nu ** 2))
    xg, wg = np.polynomial.legendre.leggauss(80)
    r = a + (b - a) * (xg + 1) / 2
    wr = wg * (b - a) / 2
    L = b - a

    def basis(rr):
        xi = (rr - a) / L
        s = 2 * xi - 1
        P = [np.polynomial.legendre.Legendre.basis(k) for k in range(nb)]
        phi = np.array([xi ** 2 * Pk(s) for Pk in P])
        d1 = np.array([(2 * xi * Pk(s) + xi ** 2 * 2 * Pk.deriv()(s)) / L for Pk in P])
        d2 = np.array([(2 * Pk(s) + 8 * xi * Pk.deriv()(s) + 4 * xi ** 2 * Pk.deriv(2)(s)) / L ** 2 for Pk in P])
        return phi, d1, d2

    W, W1, W2 = basis(r)
    A = W2 + W1 / r - n ** 2 * W / r ** 2
    B1 = W1 / r - n ** 2 * W / r ** 2
    C = W1 / r - W / r ** 2
    Kmat = D * ((A * wr * r) @ A.T - (1 - nu) * ((W2 * wr * r) @ B1.T + (B1 * wr * r) @ W2.T)
                + 2 * (1 - nu) * n ** 2 * (C * wr * r) @ C.T)
    Mmat = rho * t * (W * wr * r) @ W.T
    if rim:
        Rc = b + p['s_rim'] / 2000
        br, sr, sm = p['b_rim'] / 1000, p['s_rim'] / 1000, p['s_mass'] / 1000
        Ib = sr * br ** 3 / 12
        J = br * sr ** 3 * (1 / 3 - 0.21 * (sr / br) * (1 - (sr / br) ** 4 / 12))
        Gm = E / (2 * (1 + nu))
        we, w1e, _ = basis(np.array([b]))
        e = Rc - b
        Wc = we[:, 0] + e * w1e[:, 0]                 # rim centroid displacement per coefficient
        Ph = w1e[:, 0]
        kap = n ** 2 * Wc / Rc ** 2 - Ph / Rc
        tw = n / Rc * (Ph - Wc / Rc)
        Kmat += (E * Ib * np.outer(kap, kap) + Gm * J * np.outer(tw, tw)) * Rc
        Mmat += (rho * br * sm * np.outer(Wc, Wc) + rho * (sm * br ** 3 + br * sm ** 3) / 12 * np.outer(Ph, Ph)) * Rc
    lam = eigh(Kmat, Mmat, eigvals_only=True)
    return np.sqrt(lam[0]) / (2 * np.pi)


def web_bessel(p, n):
    a, b = p['r_in'] / 1000, p['r_out'] / 1000
    t = p['t'] / 1000
    E, nu, rho = 206e9, 0.3, RHO * 1e9
    D = E * t ** 3 / (12 * (1 - nu ** 2))

    def det(lam):
        def cols(r):
            x = lam * r
            f = [jv(n, x), yv(n, x), iv(n, x), kv(n, x)]
            f1 = [lam * jvp(n, x), lam * yvp(n, x), lam * ivp(n, x), lam * kvp(n, x)]
            f2 = [lam ** 2 * jvp(n, x, 2), lam ** 2 * yvp(n, x, 2), lam ** 2 * ivp(n, x, 2), lam ** 2 * kvp(n, x, 2)]
            sg = [-1, -1, 1, 1]                      # Laplacian of J, Y is -lam^2 f; of I, K is +lam^2 f
            lap1 = [sg[k] * lam ** 2 * f1[k] for k in range(4)]
            return f, f1, f2, lap1
        fa, f1a, _, _ = cols(a)
        fb, f1b, f2b, lap1b = cols(b)
        Mb = [f2b[k] + nu * (f1b[k] / b - n ** 2 * fb[k] / b ** 2) for k in range(4)]
        Vb = [lap1b[k] - (1 - nu) * n ** 2 * (f1b[k] / b - fb[k] / b ** 2) / b for k in range(4)]
        return np.linalg.det(np.array([fa, f1a, Mb, Vb]))

    lams = np.linspace(0.5, 200, 20000)
    vals = [det(l_) for l_ in lams]
    for i in range(len(lams) - 1):
        if np.sign(vals[i]) != np.sign(vals[i + 1]):
            lam = brentq(det, lams[i], lams[i + 1], xtol=1e-14)
            return lam ** 2 * np.sqrt(D / (rho * t)) / (2 * np.pi)
    return np.nan


# ---------------------------------------------------------------- main
def main():
    M, Ts = build()
    rows = []
    add = lambda tc, q, v: rows.append((tc, q, float(v)))
    # TC33
    rt = [('pinion', M[0]['g']['root1']), ('gear2', M[0]['g']['root2']), ('sun', M[1]['g']['root2']),
          ('planet', M[1]['g']['root1']), ('ring', M[2]['g']['root2'])]
    for nm, r in rt:
        for q, k in (('sFn', 'sFn'), ('rhoF', 'rhoF'), ('hFe', 'hFe'), ('YF', 'YF'), ('YS', 'YS')):
            add('TC33', '%s_%s' % (nm, q), r[k])
    # TC34
    g1, gsp, gpr = M[0]['g'], M[1]['g'], M[2]['g']
    for q, v in (('s1_a_w', g1['aw']), ('s1_eps_alpha', g1['ea']), ('s1_eps_beta', g1['eb']),
                 ('sp_eps_alpha', gsp['ea']), ('pr_eps_alpha', gpr['ea']), ('s1_Z_H', g1['ZH']),
                 ('s1_Z_eps', g1['Zeps']), ('sp_Z_eps', gsp['Zeps']), ('sp_Z_B', gsp['ZB']),
                 ('sp_Z_D', gsp['ZD']), ('pr_Z_B', gpr['ZB'])):
        add('TC34', q, v)
    # TC35, TC36, TC38
    for k, m in enumerate(M):
        mk = m['name']
        if k > 0:
            m['Kgam'] = 1.30
        r = rate(m, m['T1'], m['n1'], 1.25, m['Kgam'], 'ref')
        for q, v in (('c_prime', r['c']), ('c_ga', r['cga']), ('Kv', r['Kv']), ('KHb', r['KHb']), ('KFb', r['KFb'])):
            add('TC35', '%s_%s' % (mk, q), v)
        for q in ('S_H1', 'S_H2', 'S_F1', 'S_F2'):
            add('TC36', '%s_%s' % (mk, q), r[q])
        rs = rate(m, K_OVER * m['T1'], m['n1'], 1.0, m['Kgam'], 'static')
        for q in ('S_H1', 'S_F1', 'S_F2'):
            add('TC36', '%s_static_%s' % (mk, q), rs[q])
        if k <= 1:
            s = scuffing(m, r, m['n1'], 132.0, [1, 2][k])
            add('TC38', mk + '_theta_fl_max', s['flmax'])
            add('TC38', mk + '_theta_M', s['thM'])
            add('TC38', mk + '_S_S', s['SS'])
            add('TC38', mk + '_lambda_C', s['lamC'])
    # TC37
    k1, f1 = load_share(M[1], Ts, 1200, 1400, [0.010, -0.005, 0.003, -0.008])
    k2, _ = load_share(M[1], Ts, 1200, 1400, 0.012 * np.array([1, -1, 1, -1]))
    k3, _ = load_share(M[1], Ts, 1200, 1400, 0.004 * np.array([1, -1, 1, -1]), scale=0.3)
    add('TC37', 'Kgam_E1', k1)
    add('TC37', 'Kgam_alt12', k2)
    add('TC37', 'Kgam_alt4_30pct', k3)
    add('TC37', 'float_E1_um', 1000 * f1)
    # TC39
    for n, f in zip((3, 5, 6), ring_modes(125.5, 8.0, 70.0, 2.25, (3, 5, 6))):
        add('TC39', 'ring_n%d' % n, f)
    pw = dict(r_in=35.0, r_out=104.0, t=8.0, b_rim=52.0, s_rim=7.0, s_mass=9.25)
    for n in range(5):
        add('TC39', 'web_n%d' % n, web_ritz(pw, n))
    for n in range(4):
        add('TC39', 'bare_n%d' % n, web_bessel(pw, n))
    with open(OUT, 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['tc', 'quantity', 'expected'])
        for tc, q, v in rows:
            w.writerow([tc, q, '%.10g' % v])
    for tc, q, v in rows:
        print('%-5s %-24s %.6g' % (tc, q, v))
    print('%d values written to %s' % (len(rows), os.path.normpath(OUT)))


if __name__ == '__main__':
    main()
