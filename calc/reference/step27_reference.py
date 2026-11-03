"""Expected values for the step 2.7 MATLAB tests (calc/tests/step27_test_cases.csv).

    python calc/reference/step27_reference.py        (needs numpy and scipy; rotordynamics/.venv has both)

An independent Python implementation of the step 2.7 lubrication tools. The gear geometry comes from the step 2.4
and 2.6 references in this folder (simulated generating cut), not from the MATLAB code; the loss formulas (step 1.4),
the jet schedule and the cooler model are re-coded here. Inputs are copied from calc/lubrication/lb_inputs.m and the
step 2.4 to 2.6 input files. Test cases:

TC49  Heat balance of the detailed RGB at maximum continuous power with a given pump power: every loss item,
      L_mech (SYS-05), Q_oil (LUB-04), power turbine power.
TC50  Oil flows and jets for a given set of component heats: flow and largest jet of each feed, totals.
TC51  Air-oil cooler: effectiveness, NTU, UA, Manglik-Bergles j and f, core depth, pressure drops, mass, fan power.

Source: Phase 2 report, Section 2.7 ("Tests").
"""
import csv
import os
import sys

import numpy as np
from scipy.optimize import brentq

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import step24_reference as r24  # noqa: E402
import step26_reference as r26  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tests', 'step27_test_cases.csv')

# ---------------------------------------------------------------- inputs (lb_inputs.m and steps 2.4-2.6)
OIL = dict(nu40=27.6, nu100=5.1, rho15=1003.5, alpha_rho=7.0e-4, cp=2000.0)
DT_OIL = 30.0
RA, RA_SF, XL, MU_MIST = 0.3, 0.13, 1.0, 0.023
F0 = dict(roller=3.0, ball=2.0)
F1 = dict(roller=0.0003, ball=0.0005)
Q_REAR, P_REAR = 1204.0, 900.0
DP_JET, CD_JET, D_MIN, D_MAX = 400.0, 0.70, 0.6, 2.0
Q_MIN_BRG, Q_SPLINE, Q_PCU, LEAK, INTO = 0.20, 0.15, 5.0, 0.10, 0.3
COOLER = dict(T_amb=53.0, T_out=100.0, m_air=0.72, p=101.325, k_al=170.0, k_oil=0.135, rho_core=1100.0,
              k_tanks=1.35, t_plate=0.4, dp_ducts=300.0, eta_fan=0.55,
              fa=dict(s=1.6, h=6.35, t=0.10, l=3.2), fo=dict(s=1.0, h=2.0, t=0.10, l=2.0))
T_GEN, T_OSG, T_PCU = 41.8, 1.13, 1.81
PROP = dict(m=76.4, g=9.81, a=250.0, Lp=300.0, M1P=2000.0)
SPAN1 = 102.0
PLANET = dict(Dw=7.5, gap=0.03, L_ends=14.0, rim=4.0)
DPW = dict(inp=65.0, mid=70.0, prop=150.0, acc=(43.5, 25.0, 28.5))
N_PT, P_RATED = 22000.0, 895e3
T_PT = P_RATED / (N_PT * np.pi / 30)


def oil_props(T, oil=OIL):
    T1, T2 = 313.15, 373.15
    Y1, Y2 = np.log10(np.log10(oil['nu40'] + 0.7)), np.log10(np.log10(oil['nu100'] + 0.7))
    B = (Y1 - Y2) / (np.log10(T2) - np.log10(T1))
    A = Y1 + B * np.log10(T1)
    nu = 10 ** (10 ** (A - B * np.log10(T + 273.15))) - 0.7
    rho = oil['rho15'] * (1 - oil['alpha_rho'] * (T - 15))
    return dict(nu=nu, rho=rho, eta=nu * rho / 1000, cp=oil['cp'])


def mesh_loss(g, T1, n1, eta, Ra):
    at, bb = g['at'], g['bb']
    u = g['z2'] / g['z1']
    t1 = np.sqrt((g['da1'] / g['db1']) ** 2 - 1)
    t2 = np.sqrt((g['da2'] / g['db2']) ** 2 - 1)
    e1 = g['z1'] / (2 * np.pi) * (t1 - np.tan(at))
    if g['internal']:
        e2, sgn = g['z2'] / (2 * np.pi) * (np.tan(at) - t2), -1
    else:
        e2, sgn = g['z2'] / (2 * np.pi) * (t2 - np.tan(at)), 1
    HV = np.pi * (u + sgn) / (g['z1'] * u * np.cos(bb)) * (1 - g['ea'] + e1 ** 2 + e2 ** 2)
    Fbt = 2000 * T1 / g['d1'] / np.cos(at)
    vsum = 2 * np.pi * g['d1'] * n1 / 60000 * np.sin(at)
    r1 = g['d1'] / 2 * np.sin(at) / np.cos(bb)
    r2 = g['d2'] / 2 * np.sin(at) / np.cos(bb)
    rred = r1 * r2 / (r2 + sgn * r1)
    mu = 0.048 * ((Fbt / g['b']) / (vsum * rred)) ** 0.2 * eta ** -0.05 * Ra ** 0.25 * XL
    return T1 * n1 * 2 * np.pi / 60 * mu * HV


def brg_loss(dm, n, nu, P1, typ):
    M0 = 1e-7 * F0[typ] * (nu * n) ** (2 / 3) * dm ** 3 if nu * n >= 2000 else 160e-7 * F0[typ] * dm ** 3
    return (M0 + F1[typ] * P1 * dm) / 1000 * n * 2 * np.pi / 60


def windage(d, b, n):
    return 1000 * 2.82e-7 * (1 + 2.3 * b / (d / 2)) * n ** 2.8 * (d / 2000) ** 4.6 * (0.028 * MU_MIST + 0.019) ** 0.2


# ---------------------------------------------------------------- design (gd_meshes, ad_meshes, lb_design)
def design():
    S1, S2 = r24.S1, r24.S2
    s1 = r24.pair(S1['z1'], S1['z2'], S1['mn'], S1['beta'], S1['b'], S1['x1'], S1['x2'], False, r24.A_S1)
    sp = r24.pair(S2['zp'], S2['zs'], S2['m'], 0.0, S2['b'], S2['xp'], S2['xs'], False, r24.A_S2)
    pr = r24.pair(S2['zp'], S2['zr'], S2['m'], 0.0, S2['b'], S2['xp'], S2['xr'], True, r24.A_S2, S2['ha_r'])
    acc = r26.meshes()
    u1 = S1['z2'] / S1['z1']
    ns = N_PT / u1
    nc = ns / (1 + S2['zr'] / S2['zs'])
    ns_rel = ns - nc
    np_rel = ns_rel * S2['zs'] / S2['zp']
    Tp = T_PT * u1 / S2['N'] * S2['zp'] / S2['zs']
    Ft = 2000 * T_PT / s1['dw1']
    Fr, Fa = Ft * np.tan(s1['awt']), Ft * np.tan(s1['beta'])
    R = lambda r: max(np.hypot(Ft / 2, Fr / 2 + Fa * r / SPAN1), np.hypot(Ft / 2, Fr / 2 - Fa * r / SPAN1))
    dw2 = s1['dw1'] * s1['u']
    Dor = sp['root1']['df'] - 2 * PLANET['rim'] * S2['m']
    Dpw = Dor - PLANET['Dw']
    Z = np.floor(np.pi * Dpw / (PLANET['Dw'] * (1 + PLANET['gap'])))
    mass = r24.RHO * np.pi / 4 * (((sp['da1'] + sp['root1']['df']) / 2) ** 2 - Dor ** 2) * S2['b'] \
        + Z * r24.RHO * np.pi / 4 * PLANET['Dw'] ** 2 * (S2['b'] - PLANET['L_ends'])
    Fc = mass * (sp['d1'] + sp['d2']) / 2 / 1000 * (nc * np.pi / 30) ** 2
    return dict(s1=s1, sp=sp, pr=pr, acc=acc, ns=ns, nc=nc, ns_rel=ns_rel, np_rel=np_rel, Tp=Tp, N=S2['N'],
                R_in=R(s1['dw1'] / 2), R_mid=R(dw2 / 2), Fa1=Fa, Dpw=Dpw, Fc=Fc)


def losses(D, f_T, T_in, thrust, P_pumps):
    o = oil_props(T_in + DT_OIL / 2)
    nu, eta = o['nu'], o['eta']
    w = lambda n: n * 2 * np.pi / 60
    L = {}
    P_prop = f_T * P_RATED
    Tp = f_T * D['Tp']
    N = D['N']
    sp = D['sp']
    L['mesh_sp'] = N * mesh_loss(sp, Tp, D['np_rel'], eta, RA_SF)
    L['mesh_pr'] = N * mesh_loss(D['pr'], Tp, D['np_rel'], eta, RA_SF)
    Fg = 2 * 2000 * Tp / sp['dw1']
    L['brg_planet'] = N * brg_loss(D['Dpw'], D['np_rel'], nu, np.hypot(Fg, D['Fc']), 'roller')
    W = PROP['m'] * PROP['g']
    R_out = W * (1 + PROP['a'] / PROP['Lp']) + PROP['M1P'] * 1e3 / PROP['Lp']
    R_inn = W * PROP['a'] / PROP['Lp'] + PROP['M1P'] * 1e3 / PROP['Lp']
    nc = D['nc']
    L['brg_prop'] = brg_loss(DPW['prop'], nc, nu, thrust, 'ball') + brg_loss(DPW['prop'], nc, nu, R_out, 'roller') \
        + brg_loss(DPW['prop'], nc, nu, R_inn, 'roller')
    L['wind_planetary'] = N * windage(sp['d1'], sp['b'], D['np_rel']) + windage(sp['d2'], sp['b'], D['ns_rel']) \
        + windage(sp['d2'] + 2 * sp['d1'], sp['b'] + 30, nc)
    P_sun = P_prop + L['mesh_sp'] + L['mesh_pr'] + L['brg_planet'] + L['brg_prop'] + L['wind_planetary']
    gen, osg, pcu = D['acc']
    n_gen = gen['n1']
    n_osg = n_gen * osg['g']['z1'] / osg['g']['z2']
    n_pcu = D['ns'] * pcu['g']['z1'] / pcu['g']['z2']
    T_osg1 = T_OSG * osg['g']['z1'] / osg['g']['z2']
    P_gen = T_GEN * w(n_gen)
    L['mesh_gen'] = mesh_loss(gen['g'], T_GEN + T_osg1, n_gen, eta, RA_SF)
    L['mesh_osg'] = mesh_loss(osg['g'], T_osg1, n_gen, eta, RA)
    L['mesh_pcu'] = mesh_loss(pcu['g'], T_PCU * pcu['g']['z1'] / pcu['g']['z2'], D['ns'], eta, RA)
    Ft = [2000 * (T_GEN + T_osg1) / gen['g']['d1'], 2000 * T_OSG / osg['g']['d2'], 2000 * T_PCU / pcu['g']['d2']]
    nsh = [n_gen, n_osg, n_pcu]
    L['brg_acc'] = sum(2 * brg_loss(DPW['acc'][k], nsh[k], nu, Ft[k] / 2, 'ball') for k in range(3))
    L['wind_acc'] = windage(gen['g']['d1'], gen['g']['b'], n_gen) + windage(osg['g']['d2'], osg['g']['b'], n_osg) \
        + windage(pcu['g']['d2'], pcu['g']['b'], n_pcu)
    L['pumps'] = P_pumps
    L['pcu_osg'] = T_PCU * w(n_pcu) + T_OSG * w(n_osg)
    P_mid = P_sun + L['mesh_pcu'] + L['pcu_osg'] + P_pumps + P_gen + L['mesh_gen'] + L['mesh_osg'] + L['brg_acc'] \
        + L['wind_acc']
    f = P_mid / w(N_PT) / T_PT
    L['brg_mid'] = 2 * brg_loss(DPW['mid'], D['ns'], nu, D['R_mid'] * f, 'roller') \
        + brg_loss(DPW['mid'], D['ns'], nu, D['Fa1'] * f, 'ball')
    s1 = D['s1']
    L['wind_gear2'] = windage(s1['d2'], s1['b'], D['ns'])
    P_mid += L['brg_mid'] + L['wind_gear2']
    f = P_mid / w(N_PT) / T_PT
    L['mesh_s1'] = mesh_loss(s1, P_mid / w(N_PT), N_PT, eta, RA_SF)
    L['brg_inp'] = 2 * brg_loss(DPW['inp'], N_PT, nu, D['R_in'] * f, 'roller') \
        + brg_loss(DPW['inp'], N_PT, nu, D['Fa1'] * f + 278, 'ball')
    L['wind_pinion'] = windage(s1['d1'], s1['b'], N_PT)
    P_PT = P_mid + L['mesh_s1'] + L['brg_inp'] + L['wind_pinion']
    L['rear_sump'] = Q_REAR
    Q_oil = sum(L.values())
    return L, Q_oil - L['pcu_osg'] - Q_REAR, Q_oil, P_PT


# ---------------------------------------------------------------- jets (lb_flows.m)
def flows(L, N, o):
    v_id = np.sqrt(2 * DP_JET * 1e3 / o['rho'])
    q_jet = lambda d: CD_JET * np.pi / 4 * (d * 1e-3) ** 2 * v_id * 6e4
    d_for = lambda q: np.sqrt(4 * q / 6e4 / (CD_JET * v_id * np.pi)) * 1e3
    Qh = lambda P: P / (o['rho'] * o['cp'] * DT_OIL) * 6e4
    comps = [('first', L['mesh_s1'] + L['wind_pinion'] + L['wind_gear2'], 1, 'mesh'),
             ('planetary', L['mesh_sp'] + L['mesh_pr'] + L['wind_planetary'], N, 'mesh'),
             ('planet_brg', L['brg_planet'], N, 'brg'), ('input_brg', L['brg_inp'], 3, 'brg'),
             ('mid_brg', L['brg_mid'], 3, 'brg'), ('prop_brg', L['brg_prop'], 3, 'brg'),
             ('acc_mesh', L['mesh_gen'] + L['mesh_osg'] + L['mesh_pcu'] + L['wind_acc'], 3, 'mesh1'),
             ('gen_brg', L['brg_acc'], 2, 'brg'), ('splines', 0.0, 2, 'spline'), ('rear', L['rear_sump'], 2, 'brg')]
    out = []
    for nm, P, n, kind in comps:
        if kind == 'mesh':
            need, shares, nj = Qh(P), [INTO / n, (1 - INTO) / n], 2 * n
        elif kind == 'mesh1':
            need, shares, nj = Qh(P), [1 / n], n
        elif kind == 'brg':
            need, shares, nj = max(Qh(P), n * Q_MIN_BRG), [1 / n], n
        else:
            need, shares, nj = n * Q_SPLINE, [1 / n], n
        flow, dmax = 0.0, 0.0
        for s in shares:
            q = need * s
            d = d_for(q)
            m = 1
            if d > D_MAX:
                m = int(np.ceil((d / D_MAX) ** 2))
                d = d_for(q / m)
            d = max(d, D_MIN)
            flow += nj / len(shares) * m * q_jet(d)
            dmax = max(dmax, d)
        out.append((nm, flow, dmax))
    Q_lube = sum(f for _, f, _ in out)
    return out, Q_lube, (Q_lube + Q_PCU) * (1 + LEAK)


# ---------------------------------------------------------------- cooler (lb_cooler.m)
def mb(Re, al, de, ga):
    j = 0.6522 * Re ** -0.5403 * al ** -0.1541 * de ** 0.1499 * ga ** -0.0678 \
        * (1 + 5.269e-5 * Re ** 1.340 * al ** 0.504 * de ** 0.456 * ga ** -1.055) ** 0.1
    f = 9.6243 * Re ** -0.7422 * al ** -0.1856 * de ** 0.3053 * ga ** -0.2659 \
        * (1 + 7.669e-8 * Re ** 4.429 * al ** 0.920 * de ** 3.767 * ga ** 0.236) ** 0.1
    return j, f


def geom(f):
    s, h, t, l = f['s'], f['h'], f['t'], f['l']
    return 4 * s * h * l / (2 * (s * l + h * l + t * h) + t * s) * 1e-3, s / h, t / l, t / s


def surf_eff(h, f, k):
    m = np.sqrt(2 * h / (k * f['t'] * 1e-3))
    lf = f['h'] / 2 * 1e-3
    return 1 - f['h'] / (f['h'] + f['s']) * (1 - np.tanh(m * lf) / (m * lf))


def cooler(Q, m_oil, v_face):
    c = COOLER
    o0 = oil_props(c['T_out'])
    T_in = c['T_out'] + Q / (m_oil * o0['cp'])
    o = oil_props((T_in + c['T_out']) / 2)
    T_in = c['T_out'] + Q / (m_oil * o['cp'])
    cpa = 1007.0
    Ca, Co = c['m_air'] * cpa, m_oil * o['cp']
    T_aout = c['T_amb'] + Q / Ca
    Cmin, Cr = min(Ca, Co), min(Ca, Co) / max(Ca, Co)
    eps = Q / (Cmin * (T_in - c['T_amb']))
    epsf = lambda N: 1 - np.exp(N ** 0.22 / Cr * (np.exp(-Cr * N ** 0.78) - 1))
    NTU = brentq(lambda N: epsf(N) - eps, 1e-3, 50, xtol=1e-14)
    UA = NTU * Cmin
    Ta = (c['T_amb'] + T_aout) / 2 + 273.15
    rho_a = c['p'] * 1e3 / (287.05 * Ta)
    mu_a = 1.716e-5 * (Ta / 273.15) ** 1.5 * (273.15 + 110.4) / (Ta + 110.4)
    Pr_a = mu_a * cpa / (0.0241 * (Ta / 273.15) ** 0.81)
    mu_o = o['nu'] * 1e-6 * o['rho']
    Pr_o = mu_o * o['cp'] / c['k_oil']
    fa, fo = c['fa'], c['fo']
    pitch = fa['h'] + fo['h'] + 2 * c['t_plate']
    A_fr = c['m_air'] / (rho_a * v_face)
    W = np.sqrt(A_fr)
    sig_a = fa['h'] / pitch * fa['s'] / (fa['s'] + fa['t'])
    sig_o = fo['h'] / pitch * fo['s'] / (fo['s'] + fo['t'])
    Dha, ala, dea, gaa = geom(fa)
    Dho, alo, deo, gao = geom(fo)
    Ga = c['m_air'] / (sig_a * A_fr)
    Rea = Ga * Dha / mu_a
    ja, fa_ = mb(Rea, ala, dea, gaa)
    ha = ja * Ga * cpa / Pr_a ** (2 / 3)
    eta_a = surf_eff(ha, fa, c['k_al'])
    ba, bo = 4 * sig_a / Dha, 4 * sig_o / Dho

    def ua(Lc):
        Go = m_oil / (sig_o * W * Lc)
        Reo = Go * Dho / mu_o
        jo, fo_ = mb(Reo, alo, deo, gao)
        ho = jo * Go * o['cp'] / Pr_o ** (2 / 3)
        eto = surf_eff(ho, fo, c['k_al'])
        V = A_fr * Lc
        return 1 / (1 / (eta_a * ha * ba * V) + 1 / (eto * ho * bo * V)), Reo, ho, Go, fo_
    Lc = brentq(lambda x: ua(x)[0] - UA, 1e-3, 2, xtol=1e-14)
    _, Reo, ho, Go, fo_ = ua(Lc)
    dpa = Ga ** 2 / (2 * rho_a) * (4 * fa_ * Lc / Dha + 0.6)
    dpo = Go ** 2 / (2 * o['rho']) * 4 * fo_ * W / Dho
    m_cooler = c['k_tanks'] * c['rho_core'] * A_fr * Lc
    return dict(T_oil_in=T_in, eps=eps, NTU=NTU, UA=UA, Re_a=Rea, j_a=ja, f_a=fa_, h_a=ha, L=Lc * 1e3, Re_o=Reo,
                h_o=ho, dp_air=dpa, dp_oil=dpo, m_cooler=m_cooler,
                P_fan=c['m_air'] * (dpa + c['dp_ducts']) / (rho_a * c['eta_fan']))


# ---------------------------------------------------------------- main
def main():
    rows = []
    add = lambda tc, q, v: rows.append((tc, q, float(v)))
    D = design()
    L, L_mech, Q_oil, P_PT = losses(D, 1.0, 100.0, 18e3, 2392.6)
    for k in ('mesh_s1', 'mesh_sp', 'mesh_pr', 'mesh_gen', 'mesh_osg', 'brg_inp', 'brg_mid', 'brg_prop',
              'brg_planet', 'brg_acc', 'wind_pinion', 'wind_gear2', 'wind_planetary', 'wind_acc', 'pcu_osg'):
        add('TC49', k, L[k])
    add('TC49', 'L_mech', L_mech)
    add('TC49', 'Q_oil', Q_oil)
    add('TC49', 'P_PT', P_PT)
    Lf = dict(mesh_s1=2500.0, wind_pinion=120.0, wind_gear2=500.0, mesh_sp=2300.0, mesh_pr=800.0,
              wind_planetary=50.0, brg_planet=540.0, brg_inp=1900.0, brg_mid=470.0, brg_prop=530.0, mesh_gen=40.0,
              mesh_osg=4.0, mesh_pcu=1.3, wind_acc=120.0, brg_acc=80.0, rear_sump=1204.0)
    comps, Q_lube, Q_need = flows(Lf, 4, oil_props(115.0))
    for nm, fl, d in comps:
        add('TC50', nm + '_flow', fl)
        add('TC50', nm + '_d', d)
    add('TC50', 'Q_lube', Q_lube)
    add('TC50', 'Q_need', Q_need)
    C = cooler(18e3, 0.33, 6.0)
    for k in ('T_oil_in', 'eps', 'NTU', 'UA', 'Re_a', 'j_a', 'f_a', 'h_a', 'L', 'Re_o', 'h_o', 'dp_air', 'dp_oil',
              'm_cooler', 'P_fan'):
        add('TC51', k, C[k])
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
