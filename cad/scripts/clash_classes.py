"""Classify every conflict of the CATIA clash analysis (cad/assy/clash_report.csv) and write
cad/assy/clash_classes.csv with its class and reason.

    python cad/scripts/clash_classes.py

Classes: "contact" (touching surfaces: fits, seats, meshes, bolted faces, ports), "intended overlap" (an overlap
that is part of the design: oil passages drawn as oil volumes inside casting metal, tubes meeting at the manifold
block, jets set into their bosses, line ends inside their valve or port), "interference" (anything else: a real
clash to be fixed). The rules use the part names of the instances (i<k>_<part>). Prints the count per class and
lists every interference. Source: Phase 3 report, Sections 3.1 and 3.2 ("Clash check").
"""
import csv
import os
import re
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
ASSY = os.path.join(HERE, '..', 'assy')

CASTINGS = {'case', 'fs_case', 'acc_cover', 'qj_housing', 'gen_cartridge', 'osg_adapter', 'pcu_adapter'}
MANIFOLD = {'oil_prv', 'oil_filter', 'oil_thermostat'}
MESHES = {('gear2', 'pinion'), ('gear2', 'gen_gear'), ('planet', 'ring'), ('planet', 'sun'), ('mid_shaft', 'pcu_gear'),
          ('gen_shaft', 'osg_gear')}


def part(name):
    return re.sub(r'^i\d+_', '', name)


def kind(p):
    if p.startswith('oil_route') or p == 'lub07_lines':
        return 'route'
    if p.startswith('oil_jet'):
        return 'jet'
    if p.startswith('brg_'):
        return 'bearing'
    return p


def classify(a, b, typ):
    pa, pb = sorted([part(a), part(b)])
    ka, kb = kind(pa), kind(pb)
    if typ == 'contact':
        if (pa, pb) in MESHES:
            return 'contact', 'gear mesh (line contact, no backlash modelled)'
        if 'bearing' in (ka, kb):
            return 'contact', 'bearing seat, journal or neighbour'
        if 'route' in (ka, kb) or 'jet' in (ka, kb) or pa.startswith(('oil_', 'lub07')) or pb.startswith(('oil_', 'lub07')):
            return 'contact', 'oil hardware port or mounting face'
        return 'contact', 'fit, spline, quill or bolted/mounting face'
    # clash type: decide whether it is intended
    if ka == 'route' and kb == 'route':
        return 'intended overlap', 'oil routes meeting at the manifold block or sharing a tube run'
    if {ka, kb} & {'route'} and ({pa, pb} & MANIFOLD or {pa, pb} & {'lub07_valve', 'lub07_accumulator'}):
        return 'intended overlap', 'line end inside its valve or manifold port'
    if 'route' in (ka, kb) and ({pa, pb} & CASTINGS or {pa, pb} & {'carrier', 'oil_transfer_sleeve'}):
        return 'intended overlap', 'oil passage drawn as oil volume inside casting, carrier or sleeve metal'
    if 'jet' in (ka, kb) and ({pa, pb} & CASTINGS or 'carrier' in (pa, pb)):
        return 'intended overlap', 'jet nozzle set into its boss, housing or carrier post'
    if 'jet' in (ka, kb) and 'route' in (ka, kb):
        return 'intended overlap', 'jet nozzle on the end of its drilling'
    if ka == 'jet' and kb == 'jet':
        return 'intended overlap', 'two jets sharing one carrier post boss'
    if {pa, pb} & {'oil_chip_detector', 'oil_sample_valve'} and {pa, pb} & CASTINGS:
        return 'intended overlap', 'plug screwed through the case wall'
    if {pa, pb} & MANIFOLD and len({pa, pb} & MANIFOLD) == 2:
        return 'intended overlap', 'parts of the manifold block'
    return 'interference', 'unintended overlap: to be fixed'


def main():
    rows = list(csv.DictReader(open(os.path.join(ASSY, 'clash_report.csv'), encoding='utf-8')))
    out = []
    for r in rows:
        c, why = classify(r['first'], r['second'], r['type'])
        out.append(dict(first=r['first'], second=r['second'], type=r['type'], value_mm=r['value_mm'], cls=c, reason=why))
    with open(os.path.join(ASSY, 'clash_classes.csv'), 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=['first', 'second', 'type', 'value_mm', 'cls', 'reason'])
        w.writeheader()
        w.writerows(out)
    n = Counter(o['cls'] for o in out)
    m = Counter((o['cls'], o['reason']) for o in out)
    print('%d conflicts: %s' % (len(out), ', '.join('%s %d' % kv for kv in sorted(n.items()))))
    for (c, why), k in sorted(m.items()):
        print('  %-17s %3d  %s' % (c, k, why))
    for o in out:
        if o['cls'] == 'interference':
            print('INTERFERENCE', o['first'], o['second'], o['value_mm'])


if __name__ == '__main__':
    main()
