"""Step 3.9 representative drawing set: the sheet contents and the drawing checklist.

Writes cad/params/dwg39_<sheet>.txt (read by cad/scripts/drawing39.vbs: the title block, the part or product to
view and the tables, one line of text per row) for the planet P107, the carrier with propeller shaft P103, the
planetary case P101 and the RGB assembly, and manufacturing/drawing_checklist_v1.csv, which traces every value
placed on the four sheets to its source table and row. No value is computed here except the 20 degC catcher-lip
gap of the assembly, taken from the 3.8 axial stack (manufacturing/stack_axial_v1.csv). Source: Phase 3 report,
Section 3.9.
"""
import csv
import os
import textwrap

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
MF = os.path.join(ROOT, 'manufacturing')
W = 92                                        # characters per line in a table column
CHECK = []


def rd(name, folder=MF):
    with open(os.path.join(folder, name), encoding='utf-8', newline='') as f:
        return list(csv.DictReader(f))


def params(name):
    d = {}
    for line in open(os.path.join(ROOT, 'cad', 'params', name + '.txt'), encoding='utf-8'):
        if '=' in line and not line.startswith('#'):
            k, v = line.split('=', 1)
            d[k.strip()] = v.strip()
    return d


class Sheet:
    def __init__(self, key, title, part_no, material, source, scale, paper, rcut=170):
        self.key, self.lines = key, []
        self.head = [('TITLE', title), ('PARTNO', part_no), ('MAT', material), ('SOURCE', source), ('SCALE', scale),
                     ('PAPER', paper), ('RCUT', rcut)]

    def table(self, title):
        self.lines.append(('TABLE', title))

    def row(self, text, value='', src='', srckey=''):
        for i, ln in enumerate(textwrap.wrap(text, W) or ['']):
            self.lines.append(('ROW', ('  ' if i else '') + ln))
        if src:
            CHECK.append((self.key, text[:120], value, src, srckey))

    def write(self):
        p = os.path.join(ROOT, 'cad', 'params', 'dwg39_%s.txt' % self.key)
        with open(p, 'w', encoding='utf-8') as f:
            f.write('# written by cad/scripts/make_dwg39.py, do not edit\n')
            for k, v in self.head + self.lines:
                f.write('%s|%s\n' % (k, v))


def dim(sh, view, x1, y1, x2, y2, dia, what, src, key):
    """A model-driven dimension: two points at model coordinates in the end view (x, y radial) or the section
    (x radial, y = -z from the part origin)."""
    sh.lines.append(('DIM', '%s|%g|%g|%g|%g|%d' % (view, x1, y1, x2, y2, dia)))
    CHECK.append((sh.key, 'dimension: ' + what, '%g' % (((x2 - x1) ** 2 + (y2 - y1) ** 2) ** 0.5), src, key))


def callouts(sh, parts):
    tol = rd('tolerances_v1.csv')
    sh.table('TOLERANCES AND CALLOUTS / TOLERANSLAR (tolerances_v1.csv; GD&T frames as this table, R19)')
    for r in tol:
        if r['part'].strip() in parts:
            sh.row('%s: %s = %s' % (r['feature_en'], r['callout_en'], r['value']), r['value'], 'manufacturing/tolerances_v1.csv',
                   '%s / %s' % (r['part'].strip(), r['feature_en']))


def material(sh, key):
    m = {r['key']: r for r in rd('materials_v1.csv')}[key]
    sh.table('MATERIAL AND PROCESS / MALZEME VE PROSES (materials_v1.csv, %s)' % key)
    for col, lab in (('material', 'Material'), ('specification', 'Specification'), ('condition_en', 'Condition'),
                     ('hardness_case', 'Hardness and case'), ('finish', 'Surface texture'), ('ndt', 'NDT'),
                     ('protection_en', 'Protection')):
        sh.row('%s: %s' % (lab, m[col]), m[col][:60], 'manufacturing/materials_v1.csv', '%s / %s' % (key, col))


def critical(sh, part, basis):
    rows = [r for r in rd('critical_parts_v1.csv', os.path.join(ROOT, 'safety')) if r['part'] == part]
    r = rows[0]
    sh.table('CRITICAL PART / KRITIK PARCA (CS-E 515; safety/critical_parts_v1.csv)')
    sh.row('Mark: CRITICAL PART - CS-E 515 / KRITIK PARCA; serial number on the part; life tracking: %s' % r['life_tracking'],
           'critical', 'safety/critical_parts_v1.csv', '%s / life_tracking' % part)
    life = r['life_limit'].replace('(cited data; A357: validated casting quality)', '(%s)' % basis)
    sh.row('Life limit: %s' % life, life[:40], 'safety/critical_parts_v1.csv', '%s / life_limit' % part)
    sh.row('NDT at manufacture: %s' % r['ndt_manufacture'], 'ndt', 'safety/critical_parts_v1.csv', '%s / ndt_manufacture' % part)
    sh.row('NDT at TBO: %s' % r['ndt_tbo'], 'ndt', 'safety/critical_parts_v1.csv', '%s / ndt_tbo' % part)
    sh.row('D4 governing locations: ' + '; '.join(x['governing_location'] for x in rows), str(len(rows)),
           'safety/critical_parts_v1.csv', '%s / governing_location' % part)


def planet():
    sh = Sheet('planet', 'PLANET GEAR P107 / PLANET DISLISI P107', 'RGB-P107', 'Pyrowear 53 (AMS 6308), carburized',
               'part:planet', 1, 4, 45)
    g = {r['key']: r for r in rd('gear_accuracy_v1.csv')}['planet']
    p = params('planet')
    sh.table('GEAR DATA / DISLI VERILERI (ISO 1328-1:2013; gear_accuracy_v1.csv, cad/params/planet.txt)')
    for lab, val, src, k in (
            ('Number of teeth z', g['z'], 'manufacturing/gear_accuracy_v1.csv', 'planet / z'),
            ('Normal module m_n [mm]', g['m_n'], 'manufacturing/gear_accuracy_v1.csv', 'planet / m_n'),
            ('Helix angle [deg]', g['beta_deg'], 'manufacturing/gear_accuracy_v1.csv', 'planet / beta_deg'),
            ('Pressure angle [deg]', p['alpha_n'], 'cad/params/planet.txt', 'alpha_n'),
            ('Profile shift x', p['x'], 'cad/params/planet.txt', 'x'),
            ('Face width b [mm]', g['b_mm'], 'manufacturing/gear_accuracy_v1.csv', 'planet / b_mm'),
            ('Reference diameter d [mm]', g['d_mm'], 'manufacturing/gear_accuracy_v1.csv', 'planet / d_mm'),
            ('Tip / root diameter [mm]', '%s / %s' % (p['d_tip'], p['d_root']), 'cad/params/planet.txt', 'd_tip, d_root'),
            ('Bore = outer race of the planet bearing [mm]', p['bore'], 'cad/params/planet.txt', 'bore'),
            ('ISO 1328-1 class (profile class)', '%s (%s)' % (g['class'], g['class_profile']), 'manufacturing/gear_accuracy_v1.csv', 'planet / class'),
            ('f_p / F_p [um]', '%s / %s' % (g['f_p_um'], g['F_p_um']), 'manufacturing/gear_accuracy_v1.csv', 'planet / f_p, F_p'),
            ('f_fa / f_Ha / F_a [um]', '%s / %s / %s' % (g['f_fa_um'], g['f_Ha_um'], g['F_a_um']), 'manufacturing/gear_accuracy_v1.csv', 'planet / profile'),
            ('f_fb / f_Hb / F_b [um]', '%s / %s / %s' % (g['f_fb_um'], g['f_Hb_um'], g['F_b_um']), 'manufacturing/gear_accuracy_v1.csv', 'planet / helix'),
            ('Runout F_r [um]', g['F_r_um'], 'manufacturing/gear_accuracy_v1.csv', 'planet / F_r_um'),
            ('Tooth thickness allowance E_sns / E_sni [um]', '%s / %s' % (g['E_sns_um'], g['E_sni_um']), 'manufacturing/gear_accuracy_v1.csv', 'planet / E_sns, E_sni'),
            ('Profile / lead modification tolerance [um]', g['mod_tol_um'], 'manufacturing/gear_accuracy_v1.csv', 'planet / mod_tol_um'),
            ('Flank finish', g['finish'], 'manufacturing/gear_accuracy_v1.csv', 'planet / finish'),
            ('Mating gears', 'sun z45, ring z119', 'cad/scripts/drawing.vbs', 'planet rows (Phase 2)')):
        sh.row('%s: %s' % (lab, val), val, src, k)
    t, bo, b = float(p['d_tip']), float(p['bore']), float(p['b'])
    dim(sh, 'end', -t / 2, 0, t / 2, 0, 1, 'tip diameter', 'cad/params/planet.txt', 'd_tip')
    dim(sh, 'end', 0, -bo / 2, 0, bo / 2, 1, 'bore', 'cad/params/planet.txt', 'bore')
    dim(sh, 'sect', t / 2, 0, t / 2, -b, 0, 'face width', 'cad/params/planet.txt', 'b')
    dim(sh, 'sect', -t / 2, 0, t / 2, 0, 1, 'tip diameter (section)', 'cad/params/planet.txt', 'd_tip')
    dim(sh, 'sect', -bo / 2, -b, bo / 2, -b, 1, 'bore (section)', 'cad/params/planet.txt', 'bore')
    sh.row('Dimensions on the views are the main sizes from the model; all other sizes are in the tables.')
    callouts(sh, ('Planets P107', 'planets P107'))
    material(sh, 'P53')
    sh.table('NOTES / NOTLAR')
    sh.row('1. Case depth zone: teeth (flanks and roots) and the bore (integral outer race of the planet bearing) carburized '
           'as given under Hardness and case; faces and chamfers masked or ground after case hardening.')
    sh.row('2. Surface texture as given under Surface texture; elsewhere Ra 1.6 um. 3. Unless noted ISO 2768-m; '
           'dimensions in mm; drawing per ASME Y14.5-2018 (metric) as the 3.8 basis.')
    sh.write()


def carrier():
    sh = Sheet('carrier', 'PLANET CARRIER WITH PROPELLER SHAFT P103 / TASIYICI VE PERVANE MILI P103', 'RGB-P103',
               'AISI 4340 VAR (AMS 6414); pins P104 M50NiL (AMS 6278)', 'part:carrier', 0.25, 4, 130)
    p = params('carrier')
    sh.table('DESIGN DATA / TASARIM VERILERI (cad/params/carrier.txt)')
    for lab, k in (('Planets', 'n_planets'), ('Planet radius [mm]', 'a'), ('Pin = inner race [mm]', 'd_pin'),
                   ('Pin length [mm]', 'L_pin'), ('Plates: diameter x thickness [mm]', 'plate_d')):
        v = p[k] if k != 'plate_d' else '%s x %s' % (p['plate_d'], p['plate_t'])
        sh.row('%s: %s' % (lab, v), v, 'cad/params/carrier.txt', k)
    sh.row('Datums: A = outer bearing seat, B = inner bearing seat (axis A-B); C = carrier rear face', 'A-B',
           'manufacturing/gdt_v1.csv', 'Carrier with propeller shaft P103 / datums')
    pd, a, dp, ze = float(p['plate_d']), float(p['a']), float(p['d_pin']), float(p['ze'])
    zs = -300                                             # a shaft station, z 300
    dim(sh, 'sect', -pd / 2, -5, pd / 2, -5, 1, 'plate diameter', 'cad/params/carrier.txt', 'plate_d')
    dim(sh, 'end', 0, -a, 0, a, 1, 'pin circle', 'cad/params/carrier.txt', 'a')
    dim(sh, 'sect', -60, zs, 60, zs, 1, 'propeller shaft outside diameter', 'calc/safety/sf_inputs.m', 'P103 120 / 100 mm')
    dim(sh, 'sect', -50, zs - 40, 50, zs - 40, 1, 'propeller shaft bore', 'calc/safety/sf_inputs.m', 'P103 120 / 100 mm')
    dim(sh, 'sect', pd / 2, 0, pd / 2, -ze, 0, 'overall length', 'cad/params/carrier.txt', 'ze')
    dim(sh, 'end', a - dp / 2, 0, a + dp / 2, 0, 1, 'pin diameter', 'cad/params/carrier.txt', 'd_pin')
    sh.row('Dimensions on the views are the main sizes from the model; all other sizes are in the tables.')
    callouts(sh, ('Carrier with propeller shaft P103', 'Carrier P103 / planet pins P104', 'Bearing housing P111 / carrier P103'))
    material(sh, 'S43')
    critical(sh, 'P103', 'cited data for AISI 4340 VAR forgings, AMS 6414')
    sh.table('NOTES / NOTLAR')
    sh.row('1. Planet pins P104 are separate M50NiL parts, pressed in (LN2 shrink) and retained (3.4; materials_v1.csv M5N); '
           'pin bores machined before the pins are fitted.', 'pins', 'manufacturing/materials_v1.csv', 'M5N / condition_en')
    sh.row('2. R5 at the shaft-to-front-plate corner (3.9 brief); polish the radius, no tool marks across it.', 'R5',
           '3.9 brief', 'O2')
    sh.row('3. QJ pull-out shoulder-ring groove: root diameter 118 mm, full radius, 1 mm deep (3.7 D4 location 12, OI-16).',
           '118', 'calc/safety/sf_inputs.m', 'in.dt.groove')
    sh.row('4. Catcher-lip collar P118 shrink fit at z 512-516 on the same setup as the QJ1024 seat (gdt_v1.csv).', 'P118',
           'manufacturing/bom_v1.csv', 'RGB-P118')
    sh.row('5. CAD views from the Phase 2 model; the tables and notes govern where they differ (3.9 CAD update open).')
    sh.write()


def case():
    sh = Sheet('case', 'PLANETARY CASE P101, CAST + MACHINED / PLANET GOVDESI P101', 'RGB-P101',
               'A357.0-T6 premium sand casting (AMS-A-21180), HIP', 'part:case', 0.25, 4)
    sh.table('DESIGN DATA / TASARIM VERILERI')
    sh.row('Attachment flange: OD 325, PCD 308, 30 x M6 12.9 into helical coil inserts in F201, 12 mm flange (3.6 design change)',
           'PCD 308', 'calc/dynamics/dy_inputs.m', 'flange [137.5 162.5 0 12], PCD 308, OD 325')
    sh.row('Mount pads: interface TBD with the airframer, LD-08 (ICD-24; open item OI-14)', 'TBD', 'safety/open_items_37.csv', 'OI-14')
    sh.row('Rear wall: a separate plate clamped in the P101 / F201 joint (open item OI-16; no 3.7 credit depends on an '
           'integral wall)', 'separate', 'safety/open_items_37.csv', 'OI-16')
    sh.row('NJ1024 thermocouple boss: raised 12 mm pad round the hole (3.7 D4 location 11)', '12', 'calc/safety/sf_inputs.m',
           'in.dt.tc_boss.t_pad')
    sh.table('RING GEAR SEAT FIT / HALKA DISLI YUVASI GECMESI (fits_ring_seat_v1.csv)')
    for r in rd('fits_ring_seat_v1.csv'):
        v = '%.0f-%.0f um, p %.2f-%.2f MPa' % (float(r['delta_min_um']), float(r['delta_max_um']), float(r['p_min_MPa']),
                                                float(r['p_max_MPa']))
        sh.row('%s: interference %s' % (r['state_en'], v), v, 'manufacturing/fits_ring_seat_v1.csv', r['state_en'])
    L = 446.0
    dim(sh, 'sect', -129.5, -60, 129.5, -60, 1, 'ring gear seat bore', 'manufacturing/tolerances_v1.csv', 'ring gear seat bore dia 259')
    dim(sh, 'sect', -90, -150, 90, -150, 1, 'inner propeller bearing seat', 'cad/params/case.txt', 'segs r 90, z 133.8-160')
    dim(sh, 'sect', -90, -430, 90, -430, 1, 'outer propeller bearing seat', 'cad/params/case.txt', 'segs r 90, z 412-446')
    dim(sh, 'sect', 140, 0, 140, -L, 0, 'overall length', 'cad/params/case.txt', 'segs z 0-446')
    dim(sh, 'end', -129.5, 0, 129.5, 0, 1, 'ring gear seat bore (end view)', 'manufacturing/tolerances_v1.csv', 'ring gear seat bore dia 259')
    sh.row('Dimensions on the views are the main sizes from the model; all other sizes are in the tables. The flange '
           'is not dimensioned on the views: the CAD still has the Phase 2 flange (PCD 290); the 3.6 flange (PCD 308, '
           'OD 325, R10 outer / R5 inner) is in the design data table (CAD update open, OI-16).')
    callouts(sh, ('Planetary case P101', 'Planetary case P101 / ring gear P102'))
    material(sh, 'A357')
    pr = {r['id']: r for r in rd('processes_v1.csv')}['PR-10']
    critical(sh, 'planetary case', 'cited data; A357: validated casting quality')
    sh.table('NOTES / NOTLAR')
    sh.row('1. HIP of the whole casting, then radiography / CT: ' + list(pr.values())[5], 'PR-10', 'manufacturing/processes_v1.csv',
           'PR-10')
    sh.row('2. Critical zones (R10 flange junction, nose, mount flange and pads): pore limit 0.5 mm; elsewhere 0.8 mm.', '0.5',
           'manufacturing/processes_v1.csv', 'PR-10')
    sh.row('3. Fire: the P101 / F201 joint plane carries the nacelle fire seal (ICD-39); fire-rated secondary seal at the '
           'joint (open item OI-05).', 'ICD-39', 'safety/open_items_37.csv', 'OI-05, OI-07')
    sh.row('4. CAD views from the Phase 2 model; the tables and notes govern where they differ (3.9 CAD update open).')
    sh.write()


def assembly():
    sh = Sheet('assembly', 'RGB ASSEMBLY / RGB MONTAJI', 'RGB-000', 'see parts list / parca listesine bakiniz',
               'product:rgb_assembly', 0.25, 3)
    st = rd('stack_axial_v1.csv')
    hot = min(float(r['lip_gap_min']) for r in st)
    off = float(st[0]['lip_gap_min']) - float(st[0]['lip_margin_min'])        # loaded pull-out offset of the stack
    tol = {r['feature_en']: r for r in rd('tolerances_v1.csv')}['catcher-lip axial gap at 20 degC']
    g_min = float(tol['value'].split('-')[0])                                  # 20 degC minimum of the drawing tolerance
    loss = g_min - hot                                                         # 20 degC minimum to the hottest state
    g20 = 0.6 + loss + off
    lo = round(g20 * 10 + 0.4999) / 10
    sh.table('ASSEMBLY NOTES / MONTAJ NOTLARI')
    sh.row('1. Catcher-lip axial gap at 20 degC: %.2f-%.2f mm (at least 0.6 mm hot, loaded and pulled out: 20 degC minimum '
           '%.3f = 0.6 + hot loss %.3f + loaded pull-out offset %.3f from the 3.8 axial stack; closes OI-18)' % (lo, lo + 0.2, g20,
                                                                                                            loss, off),
           '%.2f-%.2f' % (lo, lo + 0.2), 'manufacturing/stack_axial_v1.csv', 'lip_gap_min, lip_margin_min')
    sh.row('2. NJ1024 end play 0.52 mm by a measured selective spacer P120; coupling pre-stretch 0.75 mm by a measured '
           'shim (ICA-22).', '0.52', 'calc/safety/sf_inputs.m', 'in.ica ICA-22')
    sh.row('3. Case flange S601 30 x M6 12.9: torque and lock per drawing; P101 / F201 joint plane carries the nacelle fire '
           'seal (ICD-39).', 'S601', 'manufacturing/bom_v1.csv', 'RGB-S601')
    sh.row('4. Critical parts (CS-E 515) marked on their drawings: PT output shaft F212, RGB input shaft, P103, P111, '
           'P101, P117, couplings F213 / F214.', '7', 'safety/critical_parts_v1.csv', 'critical = yes')
    sh.table('PARTS LIST / PARCA LISTESI (manufacturing/bom_v1.csv): no. | part | qty | material | kg')
    n = 0
    for r in rd('bom_v1.csv'):
        n += 1
        sh.lines.append(('ROW', '%s | %s | %s | %s | %s' % (r['part_no'], r['part'], r['qty'], r['material'], ('%.3f' % float(r['kg'])) if r['kg'] not in ('', '-') else r['kg'])))
    CHECK.append(('assembly', 'parts list rows', str(n), 'manufacturing/bom_v1.csv', 'all rows'))
    sh.write()
    return lo


def main():
    planet()
    carrier()
    case()
    lo = assembly()
    out = os.path.join(MF, 'drawing_checklist_v1.csv')
    with open(out, 'w', encoding='utf-8', newline='') as f:
        w = csv.writer(f)
        w.writerow(['drawing', 'item', 'value', 'source', 'source_key'])
        w.writerows(CHECK)
        w.writerow(['all', 'SYS-06 change from the drawing set', 'none (no mass change; the drawings carry the 3.7 roll-up)',
                    'requirements/changes_phase3.csv', 'SYS-06'])
    print('%d checklist rows written to %s; lip gap at 20 degC %.2f-%.2f mm' % (len(CHECK) + 1, os.path.normpath(out), lo,
                                                                                lo + 0.2))


if __name__ == '__main__':
    main()
