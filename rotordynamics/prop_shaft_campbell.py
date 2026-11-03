"""Campbell diagram of the propeller shaft with ROSS (step 1.4, check of the step 1.3 critical speed).

    python prop_shaft_campbell.py              writes results/ next to this file

Model (SI units). Propeller shaft of the selected RGB (31/110 | 45/37/119, N = 4), from the step 1.3
tool (calc/rgb_sizing): hollow AISI 4340 shaft, 75 mm outer and 45 mm inner diameter, Timoshenko beam
elements of 50 mm (60 mm for the carrier stub).
    x = -0.06 m  planet carrier, 8.6 kg (rgb_mass), Id 0.035, Ip 0.061 kg m^2 (disc of the carrier's
                 outer diameter, an assumption)
    x =  0       inner roller bearing
    x =  0.30 m  outer roller bearing (span: rgb_inputs prop_span); the thrust ball bearing next to it
                 carries no radial load
    x =  0.55 m  propeller (overhang: rgb_inputs prop_overhang), 76.4 kg, Ip 15 kg m^2 (A-04);
                 Id = Ip / 2, the value of a thin planar rotor
Bearings are springs, k from 5e7 to 1e9 N/m with 1e8 as the nominal value, c 1e3 N s/m. They are
isotropic (kyy = kxx) except in the anisotropic unbalance case, where kyy = kxx / 2, as a housing
that is stiffer in one direction would give.
The propeller runs at 1,700 rpm. The steady speed range is 1,534-1,715 rpm (SYS-03); DYN-01 keeps
critical speeds 20% away from it, below 1,227 or above 2,058 rpm. The 1.1 x transient speed is
1,870 rpm (SYS-04).

Outputs in results/:
    campbell.csv    damped natural frequencies [cpm] and whirl direction of the first six modes over
                    0-3,000 rpm, nominal bearing stiffness
    crossings.csv   speeds where a mode crosses 1 x running speed, for every bearing stiffness
    unbalance.csv   major semi-axis of the propeller orbit [um] under a G6.3 unbalance at the
                    propeller (ISO 21940-11 grade, an assumption): isotropic bearings, anisotropic
                    bearings, and anisotropic bearings with 3e4 N s/m of damping (a squeeze-film damper)
    campbell.png, unbalance.png   plots of the two (if matplotlib is installed)
The printout also gives the point-mass check: Id = Ip = 0 on very stiff bearings, the model of the
step 1.3 overhung-shaft formula (5,373 rpm).

Source: Phase 1 report, Section 4 ("Propeller shaft rotordynamics (ROSS)"). ROSS: Timbo et al.,
ROSS - Rotordynamic Open Source Software, Journal of Open Source Software 5(48), 2120 (2020).
"""
import csv
import os
import warnings

import numpy as np

warnings.filterwarnings('ignore')
import ross as rs  # noqa: E402

STEEL = rs.Material(name='AISI_4340', rho=7850, E=205e9, Poisson=0.29)
N_PROP = 1700.0
N_LO, N_HI = 1534.0, 1715.0      # steady speed range (SYS-03)
N_OVER = 1.1 * N_PROP            # transient speed (SYS-04)
MARGIN = 0.2                     # DYN-01: critical speeds at least 20% away from the steady range
K_LIST = (5e7, 1e8, 2e8, 5e8, 1e9)
K_NOM = 1e8
G_BAL = 6.3e-3                   # m/s, balance grade of the propeller (G6.3), an assumption


def build(k_brg=K_NOM, c_brg=1e3, Id_prop=7.5, Ip_prop=15.0, span=0.30, overhang=0.25, aniso=1.0):
    """ROSS rotor of the propeller shaft. Lengths in m, stiffness in N/m, inertias in kg m^2.
    aniso is the bearing stiffness ratio kyy / kxx."""
    ns, no = int(round(span / 0.05)), int(round(overhang / 0.05))
    lengths = [0.06] + [span / ns] * ns + [overhang / no] * no
    shaft = [rs.ShaftElement(L=l, idl=0.045, odl=0.075, material=STEEL, n=i)
             for i, l in enumerate(lengths)]
    disks = [rs.DiskElement(n=0, m=8.6, Id=0.035, Ip=0.061, tag='carrier'),
             rs.DiskElement(n=len(lengths), m=76.4, Id=Id_prop, Ip=Ip_prop, tag='propeller')]
    bearings = [rs.BearingElement(n=1, kxx=k_brg, kyy=aniso * k_brg, cxx=c_brg, tag='inner_roller'),
                rs.BearingElement(n=1 + ns, kxx=k_brg, kyy=aniso * k_brg, cxx=c_brg,
                                  tag='outer_roller')]
    return rs.Rotor(shaft, disks, bearings)


def campbell(rotor, rpm_max=3000.0, npts=61, modes=6):
    """Damped natural frequencies [cpm] and whirl values (0 forward, 1 backward) over speed [rpm]."""
    speeds = np.linspace(0, rpm_max * np.pi / 30, npts)
    camp = rotor.run_campbell(speeds, frequencies=modes, frequency_type='wd')
    return speeds * 30 / np.pi, np.asarray(camp.wd) * 30 / np.pi, np.asarray(camp.whirl_values)


def whirl_name(w):
    if np.isnan(w):
        return 'mixed'
    return 'forward' if w < 0.25 else ('backward' if w > 0.75 else 'mixed')


def crossings(rpm, f, whirl, order=1.0):
    """Speeds where a mode crosses order x running speed, by linear interpolation."""
    out = []
    for j in range(f.shape[1]):
        d = f[:, j] - order * rpm
        for i in range(len(d) - 1):
            if d[i] == 0 or d[i] * d[i + 1] < 0:
                s = rpm[i] + (rpm[i + 1] - rpm[i]) * d[i] / (d[i] - d[i + 1])
                out.append((j + 1, s, whirl_name(whirl[i, j])))
    return out


def unbalance(rotor, rpm):
    """Major semi-axis of the propeller orbit [m] over speed [rpm] under a G_BAL unbalance at the
    propeller, and the unbalance [kg m]."""
    prop = [d for d in rotor.disk_elements if d.tag == 'propeller'][0]
    U = prop.m * G_BAL / (N_PROP * np.pi / 30)
    resp = np.asarray(rotor.run_unbalance_response(prop.n, U, 0.0, rpm * np.pi / 30).forced_resp)
    x, y = resp[rotor.number_dof * prop.n], resp[rotor.number_dof * prop.n + 1]
    ph = np.exp(1j * np.linspace(0, 2 * np.pi, 181))
    return np.array([np.hypot((xi * ph).real, (yi * ph).real).max() for xi, yi in zip(x, y)]), U


def peaks(rpm, a):
    """Speeds and values of the local maxima of a response curve."""
    return [(rpm[i], a[i]) for i in range(1, len(a) - 1) if a[i - 1] < a[i] >= a[i + 1]]


def plot(rpm, f, whirl, file):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(7, 4.5))
    for j in range(f.shape[1]):
        fw = whirl[:, j] < 0.25
        ax.plot(rpm, f[:, j], color='#555555', lw=0.8)
        ax.plot(rpm[fw], f[fw, j], 'o', ms=3, color='#1f6fb2', label='forward' if j == 1 else None)
        ax.plot(rpm[~fw], f[~fw, j], 's', ms=3, color='#c0392b', label='backward' if j == 0 else None)
    ax.plot(rpm, rpm, 'k--', lw=1, label='1 x running speed')
    ax.axvspan((1 - MARGIN) * N_LO, (1 + MARGIN) * N_HI, color='#f5d76e', alpha=0.15,
               label='DYN-01 margin (20%)')
    ax.axvspan(N_LO, N_HI, color='#f5d76e', alpha=0.5, label='steady range (SYS-03)')
    ax.axvline(N_OVER, color='k', lw=0.8, ls=':')
    ax.text(N_OVER + 30, 11400, '1.1 x overspeed', fontsize=8)
    ax.set_xlim(0, rpm[-1])
    ax.set_ylim(0, 12000)
    ax.set_xlabel('Propeller speed (rpm)')
    ax.set_ylabel('Natural frequency (cpm)')
    ax.set_title('Propeller shaft Campbell diagram, bearings %.0e N/m' % K_NOM)
    ax.grid(alpha=0.3)
    ax.legend(loc='upper left', fontsize=8)
    fig.tight_layout()
    fig.savefig(file, dpi=150)
    plt.close(fig)


def plot_unbalance(rpm, amps, file):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(7, 4.5))
    for (name, a), c in zip(amps, ('#1f6fb2', '#c0392b', '#27ae60')):
        ax.semilogy(rpm, a * 1e6, color=c, lw=1.2, label=name)
    ax.axvspan((1 - MARGIN) * N_LO, (1 + MARGIN) * N_HI, color='#f5d76e', alpha=0.15,
               label='DYN-01 margin (20%)')
    ax.axvspan(N_LO, N_HI, color='#f5d76e', alpha=0.5, label='steady range (SYS-03)')
    ax.set_xlim(rpm[0], rpm[-1])
    ax.set_xlabel('Propeller speed (rpm)')
    ax.set_ylabel('Propeller orbit, major semi-axis (um)')
    ax.set_title('Unbalance response at the propeller, G6.3, bearings %.0e N/m' % K_NOM)
    ax.grid(alpha=0.3, which='both')
    ax.legend(loc='upper left', fontsize=8)
    fig.tight_layout()
    fig.savefig(file, dpi=150)
    plt.close(fig)


def main():
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'results')
    os.makedirs(out, exist_ok=True)

    print('Propeller shaft, 75/45 mm, span 0.30 m, overhang 0.25 m')
    rows = []
    for k in K_LIST:
        rpm, f, whirl = campbell(build(k_brg=k))
        i_op = int(np.argmin(abs(rpm - N_PROP)))
        print('k %.0e N/m: modes at 0 rpm %s cpm; at %.0f rpm %s cpm (%s)' % (
            k, np.round(f[0, :4]).astype(int), rpm[i_op], np.round(f[i_op, :4]).astype(int),
            ', '.join(whirl_name(w) for w in whirl[i_op, :4])))
        for mode, s, w in crossings(rpm, f, whirl):
            print('   mode %d crosses 1 x at %.0f rpm, %s whirl' % (mode, s, w))
            rows.append((k, mode, round(s, 1), w))
        if k == K_NOM:
            nominal = (rpm, f, whirl)

    rpm, f, whirl = nominal
    with open(os.path.join(out, 'campbell.csv'), 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['rpm'] + ['mode%d_cpm' % (j + 1) for j in range(f.shape[1])]
                   + ['mode%d_whirl' % (j + 1) for j in range(f.shape[1])])
        for i in range(len(rpm)):
            w.writerow(['%.1f' % rpm[i]] + ['%.1f' % v for v in f[i]]
                       + [whirl_name(v) for v in whirl[i]])
    with open(os.path.join(out, 'crossings.csv'), 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['k_N_per_m', 'mode', 'rpm', 'whirl'])
        w.writerows(rows)

    rpm_u = np.unique(np.r_[np.arange(200.0, 2601.0, 10.0), np.arange(1300.0, 1801.0, 1.0)])
    amps = []
    for name, aniso, c in (('isotropic', 1.0, 1e3), ('anisotropic, kyy = kxx / 2', 0.5, 1e3),
                           ('anisotropic, damping 3e4 N s/m', 0.5, 3e4)):
        a, U = unbalance(build(c_brg=c, aniso=aniso), rpm_u)
        amps.append((name, a))
    print('Unbalance response, %.0f g mm at the propeller (G6.3), bearings %.0e N/m:' % (U * 1e6, K_NOM))
    for name, a in amps:
        pk = ', '.join('%.0f rpm (%.0f um)' % (s, v * 1e6) for s, v in peaks(rpm_u, a)) or 'none'
        print('   %s: %.1f um at %.0f rpm; peaks: %s' % (name, np.interp(N_PROP, rpm_u, a) * 1e6,
                                                       N_PROP, pk))
    print('Damping needed, anisotropic bearings (peak, and peak / orbit at %.0f rpm):' % N_PROP)
    for aniso in (0.5, 0.8):
        for c in (1e3, 1e4, 3e4, 1e5):
            a, _ = unbalance(build(c_brg=c, aniso=aniso), rpm_u)
            s, v = max(peaks(rpm_u, a), key=lambda p: p[1])
            print('   kyy/kxx %.1f, c %.0e N s/m: %.1f um at %.0f rpm, %.1f x' % (
                aniso, c, v * 1e6, s, v / np.interp(N_PROP, rpm_u, a)))
    with open(os.path.join(out, 'unbalance.csv'), 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['rpm', 'isotropic_um', 'anisotropic_um', 'anisotropic_damped_um'])
        for i in range(len(rpm_u)):
            w.writerow(['%.0f' % rpm_u[i]] + ['%.2f' % (a[i] * 1e6) for _, a in amps])
    try:
        plot(rpm, f, whirl, os.path.join(out, 'campbell.png'))
        plot_unbalance(rpm_u, amps, os.path.join(out, 'unbalance.png'))
    except ImportError:
        print('matplotlib not installed: campbell.png and unbalance.png not written')

    print('Point-mass check (Id = Ip = 0, no gyroscopic terms), step 1.3 formula 5,373 rpm:')
    for k in (1e9, 1e10, 1e11):
        modal = build(k_brg=k, Id_prop=1e-6, Ip_prop=0.0).run_modal(0)
        print('   k %.0e N/m: first bending mode %.0f cpm' % (k, np.asarray(modal.wn)[0] * 30 / np.pi))

    print('Geometry variants, k %.0e N/m:' % K_NOM)
    for span, overhang in ((0.30, 0.25), (0.40, 0.25), (0.30, 0.20), (0.40, 0.20), (0.50, 0.15)):
        rpm, f, whirl = campbell(build(span=span, overhang=overhang), modes=4)
        cr = ', '.join('%.0f rpm (%s)' % (s, w) for _, s, w in crossings(rpm, f, whirl))
        print('   span %.2f m, overhang %.2f m: first mode %.0f cpm at 0 rpm; 1 x crossings: %s' % (
            span, overhang, f[0, 0], cr or 'none'))
    print('Files written to %s' % out)


if __name__ == '__main__':
    main()
