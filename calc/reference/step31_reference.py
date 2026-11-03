"""Expected values for the step 3.1 MATLAB tests (calc/tests/step31_test_cases.csv).

    python calc/reference/step31_reference.py        (needs numpy and scipy; rotordynamics/.venv has both)

An independent Python implementation of the step 3.1 checks (calc/assembly). Inputs are copied from
calc/assembly/as_inputs.m; gear sizes and centre distances are read from cad/params (gear2, pinion, gen_gear,
osg, pcu, layout: the Phase 2 gear designs), the CATIA volumes from cad/assy/part_volumes.csv and the
instance list from cad/params/assembly.txt. Each row carries its own relative tolerance. Test cases:

TC60  Convex hull of circles: area and perimeter of a two-circle hull and of the first-stage case and
      accessory cover outlines at the chosen angles (dense polygon hull, scipy).
TC61  Axial stations of the first-stage module (front and rear bearing centres, gear centre, engine-side
      face, four-point contact bearings, nuts, accessory cover and meshes).
TC62  Packaging margins at the chosen accessory angles (as_angles result, read from the instance positions in
      cad/params/assembly.txt): distances between gear tips, units, cover and keep-outs (exact point-to-hull
      distances), and the A357 mass proxy of the case and the cover.
TC63  Gear phases of the new meshes: generator gear on the first-stage gear (helical, matched in the
      generator gear plane), OSG pair, PCU pair.
TC64  Carrier plate: the plane-stress benchmark (exact annulus in torsion), the scallop area (circle
      lens) and the mass removed from both plates, the propeller torque at MCT.
TC65  CAD check: volumes of the revolved parts without teeth or holes (Pappus on the exported profile)
      and of the accessory cover (prismatic, from the hull areas) against the CATIA volumes.
TC66  Mass roll-up against SYS-06: module masses, modelled mass, allowances, total and margins (against the
      v3 limit of 100 kg and against 110 kg TBR, Hamit's decision in step 3.1); the input drive of SYS-11 (PT
      output shaft 1.31 kg, couplings 2 x 1.2 kg, tunnel shells and 0.3 kg of end rings) against 6 kg (TBR)
      and the RGB + input drive total.

Source: Phase 3 report, Section 3.1 ("Tests").
"""
import csv
import math
import os

import numpy as np
from scipy.spatial import ConvexHull

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
OUT = os.path.join(HERE, '..', 'tests', 'step31_test_cases.csv')

# ---------------------------------------------------------------- inputs (as_inputs.m)
SPAN, WALL_F, WALL, GAP_GEAR, BOSS, GAP_AX = 102.0, 12.0, 6.0, 8.0, 9.0, 1.5   # WALL: side walls (package A)
WALL_END = 8.0
BRG = {'NU2209': (45, 85, 23), 'QJ209': (45, 85, 19), 'NU2210': (50, 90, 23), 'QJ210': (50, 90, 20),
       'NU1024': (120, 180, 28), 'QJ1024': (120, 180, 28), '6305': (25, 62, 17), '6202': (15, 35, 11),
       '6203': (17, 40, 12)}
NUT = {'KM9': (45, 65, 10), 'KM10': (50, 70, 11), 'KM24': (120, 155, 20)}
FILL_BRG, FILL_SEAL = 0.72, 0.5
UNIT = {'generator': (200, 300), 'OSG': (90, 120), 'PCU': (120, 150)}
PUMP_D, PUMP_L, PUMP_M = 84.0, 40.0, 2.2
R_KER, L_FREE, R_EXH, GAP_PACK = 70.0, 330.0, 250.0, 5.0
RHO = {'steel': 7830.0, 'A357': 2680.0, 'Ti': 4430.0}
R_FLANGE = 153.5
CARR = dict(n_sc=8, r_sc=122.0, R_sc=22.0, rho=7830.0, E=205e3, nu=0.29)
PLATE_T, PLATE_R, BORE_R, PIN_A, PIN_R = 10.0, 112.0, 50.0, 82.0, 19.0     # plates 10 mm (Hamit's mass card B)
ALLOW_SHARE, ALLOW = 0.05, (1.5, 0.8, 0.9)
FASTENERS, EXTRA = 1.958092, (1.281249, 0.088555, 0.435680)   # mass card B (step 3.5): bottom-up fasteners, extras
# gear data (gd_inputs / ad_inputs): first stage 31/110 mn 2 beta 15, planetary 45/37/119 m 2
Z1, Z2, MN, BETA = 31, 110, 2.0, 15.0
ZS, ZR = 45, 119
T_PT = 895e3 / (22000 * math.pi / 30)


def params(name):
    d = {}
    with open(os.path.join(ROOT, 'cad', 'params', name + '.txt'), encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                k, v = line.split('=', 1)
                d[k.strip()] = v.strip()
    return d


def num(d, k):
    return float(d[k])


# ---------------------------------------------------------------- geometry helpers
def hull_area_perim(circles, n=20000):
    t = np.linspace(0, 2 * np.pi, n, endpoint=False)
    pts = np.vstack([np.c_[x + r * np.cos(t), y + r * np.sin(t)] for x, y, r in circles])
    h = ConvexHull(pts)
    return h.volume, h.area                        # 2-D: volume = area, area = perimeter


def dist_point_hull2(p, c1, c2):
    """Exact distance from a point outside to the convex hull of two circles (x, y, r)."""
    p = np.asarray(p, float)
    cands = [np.linalg.norm(p - c1[:2]) - c1[2], np.linalg.norm(p - c2[:2]) - c2[2]]
    d = np.asarray(c2[:2]) - np.asarray(c1[:2])
    L = np.linalg.norm(d)
    u = d / L
    c = (c1[2] - c2[2]) / L
    for sgn in (1, -1):
        ur = sgn * np.array([u[1], -u[0]])
        nrm = c * u + math.sqrt(1 - c * c) * ur
        a = np.asarray(c1[:2]) + c1[2] * nrm
        b = np.asarray(c2[:2]) + c2[2] * nrm
        s = np.dot(p - a, b - a) / np.dot(b - a, b - a)
        if 0 <= s <= 1:
            cands.append(np.dot(p - a, nrm))
    return min(cands) if min(cands[:2]) > 0 else min(cands[:2])


def tip(z, m, x, beta=0.0):
    return (m / math.cos(math.radians(beta)) * z + 2 * m * (1 + x)) / 2


def phase(zt, deg):
    p = 360.0 / zt
    return deg - p * math.floor(deg / p)


def mesh_rot(rA, phi, zA, zB):
    d = rA - (phi - 90)
    return phase(zB, (phi + 180 - 90 - 180 / zB) - d * zA / zB)


def pappus(rz):
    r, z = rz[0::2], rz[1::2]
    n = len(r)
    A = M = 0.0
    for i in range(n):
        j = (i + 1) % n
        cr = z[i] * r[j] - z[j] * r[i]
        A += cr
        M += (r[i] + r[j]) * cr
    return abs(math.pi * M / 3)


def main():
    rows = []
    add = lambda tc, q, v, tol=1e-3: rows.append((tc, q, float(v), tol))
    g2, pin, gen, osg, pcu, lay = (params(n) for n in ('gear2', 'pinion', 'gen_gear', 'osg', 'pcu', 'layout'))
    a_s1, a_gen, a_osg, a_pcu = num(lay, 'a_s1'), num(gen, 'a_w'), num(osg, 'a_w'), num(pcu, 'a_w')
    r_g2, r_pin = num(g2, 'd_tip') / 2, num(pin, 'd_tip') / 2
    r_gen = tip(57, MN, 0.0, BETA)
    r_osgp, r_osg = tip(21, 2.0, 0.1), tip(30, 2.0, -0.1)
    r_pcu = tip(73, 1.5, -0.4)
    # outline radii
    R_fs = {'prop': r_g2 + GAP_GEAR, 'pt': 85 / 2 + BOSS, 'gen': r_gen + GAP_GEAR, 'osg': r_osg + GAP_GEAR}
    R_cov = {'prop': PUMP_D / 2 + GAP_GEAR, 'pcu': r_pcu + GAP_GEAR}

    # TC60
    A, P = hull_area_perim([(0, 0, 10), (30, 0, 5)])
    add('TC60', 'two_area', A)
    add('TC60', 'two_perim', P)
    ap = params('assembly')
    pos = {}
    for k in range(1, int(ap['n']) + 1):
        f = ap['i%d' % k].split()
        pos.setdefault(f[0], (float(f[3]), float(f[4])))
    ang = lambda v: math.degrees(math.atan2(v[1], v[0])) % 360
    tg = round(ang(pos['gen_gear']))
    to = round(ang(np.subtract(pos['osg_gear'], pos['gen_gear'])))
    tp = round(ang(pos['pcu_gear']))
    add('TC62', 'theta_g', tg)
    PT = np.array([0.0, -a_s1])
    Gp = a_gen * np.array([math.cos(math.radians(tg)), math.sin(math.radians(tg))])
    Op = Gp + a_osg * np.array([math.cos(math.radians(to)), math.sin(math.radians(to))])
    Pp = a_pcu * np.array([math.cos(math.radians(tp)), math.sin(math.radians(tp))])
    fs_out = [(0, 0, R_fs['prop'] + WALL), (*PT, R_fs['pt'] + WALL), (*Gp, R_fs['gen'] + WALL), (*Op, R_fs['osg'] + WALL)]
    cov_out = [(0, 0, R_cov['prop'] + WALL), (*Pp, R_cov['pcu'] + WALL)]
    cov_cav = [(0, 0, R_cov['prop']), (*Pp, R_cov['pcu'])]
    Af, Pf = hull_area_perim(fs_out)
    Ac, Pc = hull_area_perim(cov_out)
    Acc, _ = hull_area_perim(cov_cav)
    add('TC60', 'fs_area', Af)
    add('TC60', 'fs_perim', Pf)
    add('TC60', 'cov_area', Ac)
    add('TC60', 'cov_perim', Pc)

    # TC61
    zwf = -WALL_F
    zbf = zwf - GAP_AX - 23 / 2
    zc = zbf - SPAN / 2
    zbr = zc - SPAN / 2
    qj_mid0 = zbr - 23 / 2 - 20
    qj_pt0 = zbr - 23 / 2 - 19
    nut_mid0 = qj_mid0 - 11
    nut_pt0 = qj_pt0 - 10
    zwr = min(qj_mid0, qj_pt0) - GAP_AX
    zrear = zwr - WALL_F
    zcov0 = zrear - 76
    zpcu = zrear - 14 - 10
    zgen = zc - 16 / 2
    zosg = (zbf - 23 / 2 - GAP_AX) - 12 - 6
    for k, v in (('z_bf', zbf), ('z_c', zc), ('z_br', zbr), ('z_qj_mid', qj_mid0), ('z_nut_pt', nut_pt0),
                 ('z_wr', zwr), ('z_rear', zrear), ('z_cov', zcov0), ('z_pcu', zpcu), ('z_gen', zgen),
                 ('z_osg', zosg)):
        add('TC61', k, v)

    # TC62
    dPT = np.linalg.norm(Gp - PT)
    rg, ro, rp = UNIT['generator'][0] / 2, UNIT['OSG'][0] / 2, UNIT['PCU'][0] / 2
    m = {}
    m['gen_tip_pin'] = dPT - (r_gen + r_pin + GAP_GEAR)
    m['gen_unit_tunnel'] = dPT - (rg + R_KER + GAP_PACK)
    m['osg_unit_flange'] = np.linalg.norm(Op) - (R_FLANGE + ro + GAP_PACK)
    m['osg_tip_gear2'] = np.linalg.norm(Op) - (r_osg + r_g2 + GAP_GEAR)
    c1 = np.array(cov_out[0], float)
    c2 = np.array(cov_out[1], float)
    m['gen_unit_cover'] = dist_point_hull2(Gp, c1, c2) - (rg + GAP_PACK)
    m['gen_unit_pcu_unit'] = np.linalg.norm(Gp - Pp) - (rg + rp + GAP_PACK)
    m['pcu_unit_tunnel'] = np.linalg.norm(Pp - PT) - (rp + R_KER + GAP_PACK)
    m['cover_tunnel'] = dist_point_hull2(PT, c1, c2) - (R_KER + GAP_PACK)
    for k, v in m.items():
        add('TC62', k, v, 2e-3 if abs(v) > 5 else 2e-2)
    Lfs, Lcov = -zrear, 76.0
    add('TC62', 'm_fs_proxy', RHO['A357'] * 1e-9 * (WALL * Pf * Lfs + 2 * WALL_END * Af))
    add('TC62', 'm_cov_proxy', RHO['A357'] * 1e-9 * (WALL * Pc * Lcov + 2 * WALL_END * Ac))

    # TC63
    k2 = math.tan(math.radians(BETA)) / (MN / math.cos(math.radians(BETA)) * Z2 / 2) * 180 / math.pi
    kg = math.tan(math.radians(BETA)) / (MN / math.cos(math.radians(BETA)) * 57 / 2) * 180 / math.pi
    zg2 = zc - 52 / 2
    A_eff = -(zgen - zg2 + 2) * k2
    rot_gen = mesh_rot(A_eff, tg, Z2, 57) - 2 * kg
    add('TC63', 'rot_gen', rot_gen)
    add('TC63', 'rot_osg', mesh_rot(rot_gen, to, 21, 30))
    add('TC63', 'rot_pcu', mesh_rot(0.0, tp, 20, 73))
    add('TC63', 'rot_pinion', mesh_rot(0.0, 270.0, Z2, Z1))

    # TC64
    G = CARR['E'] / (2 * (1 + CARR['nu']))
    T = 1e6
    r = 0.999 * PLATE_R
    add('TC64', 'bench_u_mm', T * r / (4 * math.pi * G * PLATE_T) * (1 / BORE_R ** 2 - 1 / r ** 2), 5e-3)
    R, rs, d = PLATE_R, CARR['R_sc'], CARR['r_sc']
    a1 = math.acos((d * d + R * R - rs * rs) / (2 * d * R))
    a2 = math.acos((d * d + rs * rs - R * R) / (2 * d * rs))
    lens = R * R * a1 + rs * rs * a2 - 0.5 * math.sqrt((-d + rs + R) * (d + rs - R) * (d - rs + R) * (d + rs + R))
    add('TC64', 'A_scallop', CARR['n_sc'] * lens)
    add('TC64', 'm_saved', 2 * CARR['n_sc'] * lens * PLATE_T * CARR['rho'] * 1e-9)
    add('TC64', 'T_MCT', T_PT * Z2 / Z1 * (1 + ZR / ZS))

    # TC65 (CAD volumes against the exported profiles)
    rev = params('revolved')
    vols = {}
    with open(os.path.join(ROOT, 'cad', 'assy', 'part_volumes.csv'), encoding='utf-8') as f:
        for row in csv.DictReader(f):
            vols[row['part']] = float(row['volume_mm3'])
    for name in rev['names'].split():
        if name + '.teeth' in rev or name + '.holes' in rev:
            continue
        rz = [float(x) for x in rev[name + '.rz'].split()]
        add('TC65', 'V_' + name, pappus(rz))
    add('TC65', 'V_acc_cover', Ac * 76 - Acc * 64 - math.pi * 20 ** 2 * 12)

    # TC66 (mass roll-up from the CATIA volumes)
    steel = {'planet', 'sun', 'ring', 'carrier', 'gear2', 'pinion', 'gen_gear', 'planet_rollers'}
    alu = {'case', 'fs_case', 'acc_cover'}
    tot = {'planetary': 0.0, 'first_stage': 0.0, 'accessories': 0.0}
    for k in range(1, int(ap['n']) + 1):
        part, module = ap['i%d' % k].split()[:2]
        if module == 'equipment':
            continue
        if part == 'pump_pack':
            kg_ = PUMP_M
        elif part in steel:
            kg_ = vols[part] * RHO['steel'] * 1e-9
        elif part in alu:
            kg_ = vols[part] * RHO['A357'] * 1e-9
        elif part.startswith('brg_'):
            kg_ = vols[part] * RHO['steel'] * FILL_BRG * 1e-9
        elif part.startswith('seal_'):
            kg_ = vols[part] * RHO['steel'] * FILL_SEAL * 1e-9
        elif part in ('ret_tube', 'qj_housing'):
            kg_ = vols[part] * RHO['Ti'] * 1e-9
        elif part == 'gen_cartridge':
            kg_ = vols[part] * RHO['A357'] * 1e-9
        else:
            kg_ = vols[part] * RHO['steel'] * 1e-9
        tot[module] += kg_
    modelled = sum(tot.values())
    am = list(ALLOW)
    on = os.path.join(ROOT, 'cad', 'params', 'oil_network.txt')
    if os.path.exists(on):                             # step 3.2 lines: weighed oil hardware and LUB-07 mist system
        pn = params('oil_network')
        modelled += float(pn['m_lub_hw']) + float(pn['m_mist'])
        am[0] = 0.0                                    # replaces the oil jets, tubes and manifolds allowance
    allow = FASTENERS + sum(am) + sum(EXTRA)          # package B basis; before it: ALLOW_SHARE * modelled + sum(am)
    for k, v in tot.items():
        add('TC66', 'm_' + k, v)
    add('TC66', 'modelled', modelled)
    add('TC66', 'allowances', allow)
    add('TC66', 'total', modelled + allow)
    add('TC66', 'margin', 100 - modelled - allow)          # against requirements v3
    add('TC66', 'margin_110', 110 - modelled - allow)      # against 110 kg TBR (Hamit's decision)
    # input drive (SYS-11): liner r 43-43.5 Inconel 625, blanket 15 mm at 128 kg/m3, CRES skin 0.3 mm, L 550 mm
    sh = lambda r, th, rho: math.pi * ((r + th) ** 2 - r ** 2) * 550 * rho * 1e-9
    tunnel = sh(43, 0.5, 8440) + sh(43.5, 15, 128) + sh(58.5, 0.3, 7920) + 0.3
    drive = 1.31 + 2.4 + tunnel
    add('TC66', 'tunnel', tunnel)
    add('TC66', 'drive', drive)
    add('TC66', 'margin_drive', 6 - drive)
    add('TC66', 'total_with_drive', modelled + allow + drive)

    with open(OUT, 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(['tc', 'quantity', 'expected', 'tol'])
        for tc, q, v, tol in rows:
            w.writerow([tc, q, '%.10g' % v, tol])
    print('%d rows written to %s' % (len(rows), os.path.normpath(OUT)))


if __name__ == '__main__':
    main()
