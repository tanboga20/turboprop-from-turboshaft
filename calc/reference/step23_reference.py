"""Expected values for the step 2.3 MATLAB tests (calc/tests/step23_test_cases.csv).

    python calc/reference/step23_reference.py        (needs numpy and scipy; rotordynamics/.venv has both)

An independent Python implementation of the step 2.3 torsional model. The gear data of the PDR design
(31/110 | 45/37/119, N = 4) are copied from calc/torsion/gear_data.m's output. Test cases:

TC30  Natural frequencies of the elastic modes 1-6 [Hz], PT and propeller free, ring fixed.
TC31  Speed ratios in rigid rotation from gear kinematics alone: gear 2 and sun 1/u1, generator 110/57/u1,
      carrier and propeller 1/i, planets (1/i) (r_c / r_p).
TC32  Sudden stoppage, PT stopping linearly in 0.2 s: peak torque in the propeller shaft [N m], from a
      direct time integration (scipy Radau) of M x'' + C x' + K x = -M r a_PT with the modal damping matrix,
      and the quasi-static torque J_prop w_prop / t_stop.

Source: Phase 2 report, Section 2.3 ("Tests").
"""
import csv
import os

import numpy as np
from scipy.integrate import solve_ivp
from scipy.linalg import eigh

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tests', 'step23_test_cases.csv')

# Gear data (gear_data.m) and inputs (torsion_inputs.m)
g = dict(r1=0.0320935615927, r2=0.113880379845, at1=0.360356324017, b1=0.052, rs=0.045, rp=0.037, rr=0.119,
         rc=0.082, at2=0.349065850399, b2=0.06, N=4, rag=0.0590107422834, Jp=0.00070831266325,
         Jg2=0.0504233489061, Js=0.00265459879111, mpl=1.1167911897, Jpl=0.00121800039126, Jc=0.061,
         Jag=0.000691377667033, i=12.9318996416)
G, CG, ZETA = 79.5e9, 20e9, 0.02
J_PT, J_CPL, J_PROP, J_GEN = 0.084, 0.0006, 15.0, 0.012
SH = dict(stub=(0.050, 0.030, 0.08), float=(0.066, 0.063, 0.55), input=(0.040, 0.024, 0.10),
          mid=(0.045, 0.027, 0.15), prop=(0.120, 0.100, 0.61))
K_DIA = 9.3e5
GEN = dict(b=0.010, nd=0.01048, nL=0.015, bd=0.016, bL=0.065)
N_PT = 22000.0


def kt(d):
    do, di, L = d
    return G * np.pi / 32 * (do**4 - di**4) / L


def ser(*k):
    return 1.0 / sum(1.0 / x for x in k)


def model():
    names = ['PT', 'c1', 'c2', 'pinion', 'gear2', 'ag', 'gen', 'sun', 'carrier'] + \
            ['p%d' % i for i in range(g['N'])] + ['prop']
    ix = {nm: i for i, nm in enumerate(names)}
    n = len(names)
    J = np.zeros(n)
    J[ix['PT']], J[ix['c1']], J[ix['c2']] = J_PT, J_CPL, J_CPL
    J[ix['pinion']], J[ix['gear2']], J[ix['ag']], J[ix['gen']] = g['Jp'], g['Jg2'], g['Jag'], J_GEN
    J[ix['sun']] = g['Js']
    J[ix['carrier']] = g['Jc'] + g['N'] * g['mpl'] * g['rc']**2
    for i in range(g['N']):
        J[ix['p%d' % i]] = g['Jpl']
    J[ix['prop']] = J_PROP
    K = np.zeros((n, n))
    els = {}

    def add(name, k, a):
        nonlocal K
        K += k * np.outer(a, a)
        els[name] = (k, a)

    def shaft(name, i, j, k):
        a = np.zeros(n)
        a[ix[i]], a[ix[j]] = 1.0, -1.0
        add(name, k, a)

    kq = ser(G * np.pi / 32 * GEN['nd']**4 / GEN['nL'], G * np.pi / 32 * GEN['bd']**4 / GEN['bL'])
    shaft('stub', 'PT', 'c1', ser(kt(SH['stub']), K_DIA))
    shaft('float', 'c1', 'c2', kt(SH['float']))
    shaft('input', 'c2', 'pinion', ser(K_DIA, kt(SH['input'])))
    a = np.zeros(n)
    a[ix['pinion']], a[ix['gear2']] = g['r1'] * np.cos(g['at1']), -g['r2'] * np.cos(g['at1'])
    add('mesh1', CG * g['b1'], a)
    a = np.zeros(n)
    a[ix['gear2']], a[ix['ag']] = g['r2'] * np.cos(g['at1']), -g['rag'] * np.cos(g['at1'])
    add('meshg', CG * GEN['b'], a)
    shaft('quill', 'ag', 'gen', kq)
    shaft('mid', 'gear2', 'sun', kt(SH['mid']))
    ca = np.cos(g['at2'])
    for i in range(g['N']):
        a = np.zeros(n)
        a[ix['sun']], a[ix['carrier']], a[ix['p%d' % i]] = ca * g['rs'], -ca * g['rc'], -ca * g['rp']
        add('sp%d' % i, CG * g['b2'], a)
        a = np.zeros(n)
        a[ix['carrier']], a[ix['p%d' % i]] = ca * g['rc'], -ca * g['rp']
        add('pr%d' % i, CG * g['b2'], a)
    shaft('prop', 'carrier', 'prop', kt(SH['prop']))
    return names, ix, np.diag(J), K, els


def main():
    names, ix, M, K, els = model()
    w2 = eigh(K, M, eigvals_only=True)
    f = np.sqrt(np.sort(w2[w2 > 1e-6 * w2.max()])) / (2 * np.pi)
    rows = [('TC30', 'f%d' % (k + 1), f[k], 'Hz') for k in range(6)]
    u1 = 110 / 31
    rows += [('TC31', 'ratio_gear2', 1 / u1, '-'), ('TC31', 'ratio_generator', 110 / 57 / u1, '-'),
             ('TC31', 'ratio_carrier', 1 / g['i'], '-'),
             ('TC31', 'ratio_planet', 1 / g['i'] * g['rc'] / g['rp'], '-')]
    # rigid ratios for the time integration (null space of K)
    w2f, V = eigh(K, M)
    r = V[:, np.argmin(np.abs(w2f))]
    r = r / r[ix['PT']]
    free = [i for i in range(len(names)) if i != ix['PT']]
    Mr, Kr, rr = M[np.ix_(free, free)], K[np.ix_(free, free)], r[free]
    wf2, Phi = eigh(Kr, Mr)
    wf = np.sqrt(wf2)
    # modal damping matrix: C = M Phi diag(2 zeta w) Phi' M (Phi mass-normalised by eigh)
    C = Mr @ Phi @ np.diag(2 * ZETA * wf) @ Phi.T @ Mr
    w0 = N_PT * np.pi / 30
    ts = 0.2
    nf = len(free)
    Minv = np.linalg.inv(Mr)

    def rhs(t, y):
        x, v = y[:nf], y[nf:]
        a_pt = -w0 / ts if t < ts else 0.0
        return np.concatenate([v, Minv @ (-Mr @ rr * a_pt - C @ v - Kr @ x)])

    t_end = ts + 4 / (wf[0] / (2 * np.pi))
    sol = solve_ivp(rhs, (0, t_end), np.zeros(2 * nf), method='Radau', rtol=1e-9, atol=1e-13,
                    dense_output=True, max_step=1e-4)
    tt = np.linspace(0, t_end, 200001)
    X = sol.sol(tt)[:nf]
    xf = np.zeros((len(names), tt.size))
    xf[free] = X
    k_ps, a_ps = els['prop']
    T_ps = k_ps * (a_ps @ xf)
    rows.append(('TC32', 'peak_prop_shaft_0p2s', np.abs(T_ps).max(), 'N m'))
    rows.append(('TC32', 'T_qs_0p2s', J_PROP * w0 / g['i'] / ts, 'N m'))
    with open(OUT, 'w', newline='') as fh:
        wr = csv.writer(fh)
        wr.writerow(['tc', 'quantity', 'expected', 'unit'])
        for tc, q, v, u in rows:
            wr.writerow([tc, q, '%.6g' % v, u])
    for row in rows:
        print('%-5s %-22s %14.6g %s' % row)
    print('Written %s' % os.path.normpath(OUT))


if __name__ == '__main__':
    main()
