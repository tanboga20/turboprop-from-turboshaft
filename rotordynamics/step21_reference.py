"""Expected values for the step 2.1 MATLAB tests (calc/tests/step21_test_cases.csv), from ROSS and closed forms.

    python step21_reference.py              writes ../calc/tests/step21_test_cases.csv

The MATLAB rotor model of step 2.1 (calc/rotor_damper) is checked against an independent implementation:
ROSS for everything with a rotor, closed-form solutions for the rest. Test cases (SI units, speeds in rpm):

TC18  Simply supported uniform Timoshenko beam, 75/45 mm AISI 4340, 1.0 m: first two natural frequencies
      [Hz] from the frequency equation (rho^2 I / (kappa G)) w^4 - (rho A + rho I k^2 (1 + E / (kappa G))) w^2
      + E I k^4 = 0, k = n pi / L, lower root; Cowper's shear coefficient for a hollow circle.
TC19  The Phase 1 propeller shaft model (prop_shaft_campbell.build) with bearings of 1e8 N/m and 1e3 N s/m:
      damped natural frequencies of modes 1-4 [cpm] at 0 and 1,700 rpm, and the 1 x crossing [rpm] for
      bearings of 5e7, 1e8 and 1e9 N/m on a 50 rpm grid.
TC20  The same model under the G6.3 propeller unbalance: major semi-axis of the propeller orbit [um] at
      1,700 rpm (isotropic bearings), at 1,462 and 1,700 rpm (kyy = kxx / 2) and at 1,462 rpm
      (kyy = kxx / 2, 3e4 N s/m).
TC21  Shaft A (120/100 mm) with a 4 kg propeller flange, each bearing in series with a housing: shaft -
      bearing 1e9 N/m - journal 1.5 kg - 1e11 N/m (no damper) - housing 3 kg - ground 2e8 / 1e8 N/m with
      2% damping. Modes 1-4 at 1,700 rpm [cpm], orbit at 1,700 rpm [um], largest orbit from 100 to 1,870 rpm
      on a 2 rpm grid [um] and the DYN-05 ratio.
TC22  Squeeze-film damping of a short land, pi eta R L^3 / c^3 x seal factor [N s/m].
TC23  Squirrel-cage stiffness n / 2 (E w t^3 + E t w^3) / l^3 [N/m] and bar stress per metre 3 E max(w, t) / l^2.

Source: Phase 2 report, Section 2.1 ("Tests").
"""
import csv
import os
import warnings

import numpy as np

warnings.filterwarnings('ignore')
import ross as rs  # noqa: E402

from prop_shaft_campbell import STEEL, build, campbell, crossings, unbalance  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'calc', 'tests', 'step21_test_cases.csv')
E, NU, RHO = 205e9, 0.29, 7850.0


def tc18():
    do, di, L = 0.075, 0.045, 1.0
    A = np.pi / 4 * (do**2 - di**2)
    I = np.pi / 64 * (do**4 - di**4)
    G = E / (2 * (1 + NU))
    m = di / do
    kappa = 6 * (1 + NU) * (1 + m**2)**2 / ((7 + 6 * NU) * (1 + m**2)**2 + (20 + 12 * NU) * m**2)
    rows = []
    for n in (1, 2):
        k = n * np.pi / L
        a = RHO**2 * I / (kappa * G)
        b = -(RHO * A + RHO * I * k**2 * (1 + E / (kappa * G)))
        c = E * I * k**4
        w2 = (-b - np.sqrt(b**2 - 4 * a * c)) / (2 * a)
        rows.append(('TC18', 'f%d' % n, np.sqrt(w2) / (2 * np.pi), 'Hz'))
    return rows


def tc19():
    rows = []
    rpm, f, whirl = campbell(build(k_brg=1e8), rpm_max=3000.0, npts=61)
    for j in range(4):
        rows.append(('TC19', 'f0_mode%d' % (j + 1), f[0, j], 'cpm'))
    i = int(np.argmin(abs(rpm - 1700)))
    for j in range(4):
        rows.append(('TC19', 'f1700_mode%d' % (j + 1), f[i, j], 'cpm'))
    for k, name in ((5e7, '5e7'), (1e8, '1e8'), (1e9, '1e9')):
        rpm, f, whirl = campbell(build(k_brg=k), rpm_max=3000.0, npts=61)
        rows.append(('TC19', 'cross_k' + name, min(s for _, s, _ in crossings(rpm, f, whirl)), 'rpm'))
    return rows


def tc20():
    rows = []
    sp = np.array([1462.0, 1700.0])
    a, _ = unbalance(build(aniso=1.0), sp)
    rows.append(('TC20', 'iso_1700', a[1] * 1e6, 'um'))
    a, _ = unbalance(build(aniso=0.5), sp)
    rows.append(('TC20', 'aniso_1462', a[0] * 1e6, 'um'))
    rows.append(('TC20', 'aniso_1700', a[1] * 1e6, 'um'))
    a, _ = unbalance(build(aniso=0.5, c_brg=3e4), sp)
    rows.append(('TC20', 'aniso_c3e4_1462', a[0] * 1e6, 'um'))
    return rows


def shaft_a_rotor(kh=2e8, aniso=0.5):
    """Shaft A on chain supports, the MATLAB model of run_step21 section 5 (nominal housing, kyy = kxx / 2)."""
    ns, no = 6, 5
    lengths = [0.06] + [0.05] * ns + [0.05] * no
    shaft = [rs.ShaftElement(L=l, idl=0.100, odl=0.120, material=STEEL, n=i) for i, l in enumerate(lengths)]
    nn = len(lengths)
    disks = [rs.DiskElement(n=0, m=8.6, Id=0.035, Ip=0.061, tag='carrier'),
             rs.DiskElement(n=nn, m=76.4 + 4.0, Id=7.5 + 0.011, Ip=15.0 + 0.022, tag='propeller')]
    m_h = 3.0
    ch = lambda k: 2 * 0.02 * np.sqrt(k * m_h)  # noqa: E731
    bearings, masses = [], []
    for b, node in enumerate((1, 1 + ns)):
        j, h = nn + 1 + 2 * b, nn + 2 + 2 * b    # extra nodes follow the shaft nodes 0..nn
        bearings.append(rs.BearingElement(n=node, n_link=j, kxx=1e9, kyy=1e9, cxx=0.0, cyy=0.0,
                                          tag='brg%d' % b))
        bearings.append(rs.BearingElement(n=j, n_link=h, kxx=1e11, kyy=1e11, cxx=0.0, cyy=0.0,
                                          tag='cage%d' % b))
        bearings.append(rs.BearingElement(n=h, kxx=kh, kyy=aniso * kh, cxx=ch(kh), cyy=ch(aniso * kh),
                                          tag='housing%d' % b))
        masses += [rs.PointMass(n=j, m=1.5, tag='journal%d' % b), rs.PointMass(n=h, m=m_h, tag='seat%d' % b)]
    return rs.Rotor(shaft, disks, bearings, point_mass_elements=masses)


def tc21():
    rows = []
    rotor = shaft_a_rotor()
    modal = rotor.run_modal(1700 * np.pi / 30, num_modes=24)
    wd = np.sort(np.asarray(modal.wd)[np.asarray(modal.wd) > 1.0])[:4] * 30 / np.pi
    for j in range(4):
        rows.append(('TC21', 'f1700_mode%d' % (j + 1), wd[j], 'cpm'))
    prop = [d for d in rotor.disk_elements if d.tag == 'propeller'][0]
    U = 76.4 * 6.3e-3 / (1700 * np.pi / 30)
    rpm = np.arange(100.0, 1870.1, 2.0)
    resp = np.asarray(rotor.run_unbalance_response(prop.n, U, 0.0, rpm * np.pi / 30).forced_resp)
    x, y = resp[rotor.number_dof * prop.n], resp[rotor.number_dof * prop.n + 1]
    a = (abs(x + 1j * y) + abs(x - 1j * y)) / 2
    i17 = int(np.argmin(abs(rpm - 1700)))
    rows.append(('TC21', 'a1700', a[i17] * 1e6, 'um'))
    rows.append(('TC21', 'a_max', a.max() * 1e6, 'um'))
    rows.append(('TC21', 'ratio', a.max() / a[i17], '-'))
    return rows


def tc22():
    R, L, c, eta, seal = 0.068, 0.040, 0.10e-3, 2.5e-3, 2.0
    return [('TC22', 'C', seal * np.pi * eta * R * L**3 / c**3, 'N s/m')]


def tc23():
    n, l, w, t = 24, 0.080, 0.006, 0.005
    k = n / 2 * (E * w * t**3 + E * t * w**3) / l**3
    return [('TC23', 'k', k, 'N/m'), ('TC23', 's_per_m', 3 * E * max(w, t) / l**2, 'Pa/m')]


def main():
    rows = tc18() + tc19() + tc20() + tc21() + tc22() + tc23()
    with open(OUT, 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['tc', 'quantity', 'expected', 'unit'])
        for tc, q, v, u in rows:
            w.writerow([tc, q, '%.6g' % v, u])
    for r in rows:
        print('%-5s %-18s %14.6g %s' % r)
    print('Written %s' % os.path.normpath(OUT))


if __name__ == '__main__':
    main()
