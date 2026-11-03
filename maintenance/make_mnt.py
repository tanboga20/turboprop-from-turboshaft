"""Write the maintenance task table of step 3.10 (maintenance/mnt_tasks_v1.csv) and its summary.

    python maintenance/make_mnt.py

mnt_tasks_v1.csv   one row per task step: task, level (line = on the aircraft, shop), step text in English and
                   Turkish, counts of fasteners, connectors and lines, elemental minutes, people, whether the RGB
                   stays installed (MNT-02), the ICA items of safety/ica_items_v1.csv it carries out, requirement.
Times come from a standard-time model (elemental minutes per fastener, connector, line, lift and check, below),
not from a timed trial: they are estimates (TBR) to be confirmed in the maintainability demonstration on the first
engine (3.11). Fastener counts are those of the BOM (manufacturing/bom_v1.csv); the interface counts to the core
and the aircraft (coupling bolts, tunnel flange, mount links, harness) are TBD with the core maker and the airframer.
Prints the totals per task; the RGB removal plus installation is the MNT-01 value.
Source: Phase 3 report, Section 3.10.
"""
import csv
import os

HERE = os.path.dirname(os.path.abspath(__file__))

# elemental minutes: (remove, install); install includes torque, locking and witness marks
EL = {
    'fastener': (0.5, 1.5),       # bolt, nut or stud nut, per piece
    'connector': (1.0, 3.0),      # electrical connector, per piece (install: check pins, lock, safety)
    'line': (5.0, 10.0),          # oil or air line: open, drain, cap / uncap, new seal, torque
}
# fixed elements, minutes
PREP = 30          # access panels, tools, documentation
DRAIN, FILL = 20, 15
RIG, LIFT = 20, 15  # rig a hoist or stand; move a module on it
INSPECT = 15       # independent inspection of a critical joint group (ICA-05, ICA-06)
RUN = 30           # ground run, leak and vibration check

# task, level, step_en, step_tr, (fasteners, connectors, lines), fixed minutes, direction ('rem', 'inst', 'both'),
# people, rgb_installed, ica, requirement
STEPS = [
    # T01: RGB module off the engine and back (propeller already off: ICA-05 is its own task)
    ('T01', 'line', 'Open cowls, drain RGB oil system', 'Kaportaları aç, RGB yağ sistemini boşalt',
     (0, 0, 0), PREP + DRAIN, 'rem', 1, 'yes', '', 'MNT-01'),
    ('T01', 'line', 'Disconnect the RGB harness (chip detectors, ODM, pressure, temperature, filter, switch, mist valve) '
     'and the 3 accelerometer leads (7 connectors, TBD)',
     'RGB kablo demetini (talaş dedektörleri, ODM, basınç, sıcaklık, filtre, anahtar, sis valfi) ve 3 ivmeölçer '
     'kablosunu ayır (7 konektör, TBD)', (0, 7, 0), 0, 'both', 1, 'yes', '', 'MNT-01'),
    ('T01', 'line', 'Disconnect the oil lines (cooler in and out, tank supply, tank vent, PT rear sump scavenge) and the '
     'mist bleed-air line (6 lines)',
     'Yağ hatlarını (soğutucu giriş ve çıkış, tank besleme, tank havalandırma, PT arka karter emiş) ve sis hava hattını '
     'ayır (6 hat)', (0, 0, 6), 0, 'both', 1, 'yes', '', 'MNT-01'),
    ('T01', 'line', 'Fit the core support cradle and rig the RGB hoist (the engine mounts are on the RGB flange, '
     'ICD-24)', 'Çekirdek destek beşiğini tak, RGB vincini bağla (motor bağlantıları RGB flanşında, ICD-24)',
     (0, 0, 0), RIG + 15, 'both', 2, 'yes', '', 'MNT-01'),
    ('T01', 'line', 'Disconnect the input drive at the RGB-end diaphragm coupling (8 bolts, TBR)',
     'Giriş tahrikini RGB tarafı diyafram kaplinden ayır (8 cıvata, TBR)', (8, 0, 0), 0, 'both', 1, 'yes', '',
     'MNT-01'),
    ('T01', 'line', 'Release the aircraft mount links at the RGB flange (3 bolts, TBD airframer) and the RGB to '
     'PT-tunnel flange (12 bolts, TBD core maker)',
     'RGB flanşındaki uçak bağlantı çubuklarını (3 cıvata, TBD) ve RGB-PT tüneli flanşını (12 cıvata, TBD) çöz',
     (15, 0, 0), 0, 'both', 2, 'yes', '', 'MNT-01'),
    ('T01', 'line', 'Draw the RGB forward on the hoist and set it on its stand (about 110 kg)',
     'RGB\'yi vinçle öne çek ve sehpasına koy (yaklaşık 110 kg)', (0, 0, 0), LIFT + 10, 'both', 2, 'yes', '',
     'MNT-01'),
    ('T01', 'line', 'Measure and set the coupling pre-stretch with the selective shim (0.75 mm)',
     'Kaplin ön gerdirmesini seçmeli şimle ölç ve ayarla (0,75 mm)', (0, 0, 0), 30, 'inst', 1, 'yes', 'ICA-22',
     'MNT-01'),
    ('T01', 'line', 'Independent inspection of the coupling, mount and flange joints; fill oil, check level',
     'Kaplin, bağlantı ve flanş birleşimlerinin bağımsız muayenesi; yağ doldur, seviyeyi kontrol et',
     (0, 0, 0), INSPECT * 2 + FILL, 'inst', 2, 'yes', 'ICA-06', 'MNT-01'),
    ('T01', 'line', 'Ground run: leak check, HUMS baseline record, chip detectors clean',
     'Yer çalıştırması: kaçak kontrolü, HUMS temel kaydı, talaş dedektörleri temiz', (0, 0, 0), RUN, 'inst', 2,
     'yes', 'ICA-14', 'MNT-01, CTL-03'),
    # T02: planetary module change (shop, RGB on its stand)
    ('T02', 'shop', 'Remove the propeller bearing housing from the nose (12 x M6) and the nose cover (8 x M5)',
     'Pervane yatak yuvasını burundan (12 x M6) ve burun kapağını (8 x M5) sök', (20, 0, 0), PREP, 'both', 1, 'no',
     'ICA-02, ICA-04', 'MNT-01'),
    ('T02', 'shop', 'Separate the planetary case from the first-stage case at the flange (30 x M6, 6 dowels) and lift '
     'the planetary module off (sun stays on its quill)',
     'Planet gövdesini birinci kademe gövdesinden flanştan ayır (30 x M6, 6 pim) ve planet modülünü kaldır (güneş '
     'milinde kalır)', (30, 0, 0), RIG + LIFT, 'both', 2, 'no', '', 'MNT-01'),
    ('T02', 'shop', 'Withdraw the carrier with the planets from the ring and case (ring retention plate 12 x M6); '
     'inspect planet bearings and the ring',
     'Taşıyıcıyı planetlerle halkadan ve gövdeden çek (halka tutma plakası 12 x M6); planet rulmanlarını ve halkayı '
     'muayene et', (12, 0, 0), LIFT + 45, 'both', 2, 'no', 'ICA-07', 'STR-05'),
    # T03: first-stage and accessory module (shop)
    ('T03', 'shop', 'Remove the accessory cover from the first-stage case (24 x M5) and the pump pack (4 x M6)',
     'Aksesuar kapağını birinci kademe gövdesinden (24 x M5) ve pompa paketini (4 x M6) sök', (28, 0, 0), PREP, 'both',
     1, 'no', '', 'MNT-01'),
    ('T03', 'shop', 'Remove the generator cartridge (8 x M6) and draw out the intermediate and input shafts with their '
     'bearings; inspect gear 2, its damping ring and the shear necks',
     'Jeneratör kartuşunu (8 x M6) sök, ara ve giriş millerini rulmanlarıyla çek; dişli 2\'yi, sönüm halkasını ve kesme '
     'boyunlarını muayene et', (8, 0, 0), LIFT + 60, 'both', 2, 'no', 'ICA-09, ICA-15', 'STR-05'),
    # T04: line tasks with the RGB installed (MNT-02)
    ('T04', 'line', 'Borescope the ring-planet mesh through port BP1 (z 117), turning the propeller by hand to bring each '
     'planet under the port, and the pinion-gear mesh through BP2',
     'BP1 deliğinden (z 117) halka-planet kavramasını, pervaneyi elle çevirip her planeti deliğin altına getirerek, '
     've BP2\'den pinyon-dişli kavramasını boroskopla incele', (2, 0, 0), PREP + 40, 'both', 2, 'yes', 'ICA-04',
     'MNT-02'),
    ('T04', 'line', 'Pull and check the chip detectors (self-closing valves), take the oil sample',
     'Talaş dedektörlerini çıkar ve kontrol et (kendinden kapanan valfler), yağ numunesi al', (0, 2, 0), 20, 'both', 1,
     'yes', 'ICA-14', 'MNT-02'),
    ('T04', 'line', 'Change the filter element, test the bypass valve and the impending-bypass indicator',
     'Filtre elemanını değiştir, baypas valfini ve baypas öncesi göstergesini test et', (0, 1, 0), 30, 'both', 1,
     'yes', 'ICA-13', 'MNT-02'),
    ('T04', 'line', 'Check the oil level, the mist accumulator pre-charge and the low-oil-pressure switch',
     'Yağ seviyesini, sis akümülatörü ön dolumunu ve düşük yağ basıncı anahtarını kontrol et', (0, 1, 0), 30, 'both',
     1, 'yes', 'ICA-17, ICA-19', 'MNT-02, LUB-07'),
    ('T04', 'line', 'Replace an accelerometer or the ODM sensor (2 x M5 each)',
     'Bir ivmeölçeri ya da ODM algılayıcısını değiştir (her biri 2 x M5)', (2, 1, 0), 10, 'both', 1, 'yes', '',
     'MNT-02, CTL-03'),
    ('T04', 'line', 'Replace the generator on its pad (6 stud nuts, 3 connectors), OSG (8) or PCU (10)',
     'Jeneratörü pedinde (6 saplama somunu, 3 konektör), OSG\'yi (8) ya da PCU\'yu (10) değiştir', (6, 3, 0), LIFT + 15,
     'both', 2, 'yes', 'ICA-11', 'MNT-02'),
]

TASKS = {
    'T01': ('RGB module removal and installation on the engine (MNT-01)', 'RGB modülünün motordan sökülüp takılması (MNT-01)'),
    'T02': ('Planetary module change (shop)', 'Planet modülü değişimi (atölye)'),
    'T03': ('First-stage and accessory module (shop)', 'Birinci kademe ve aksesuar modülü (atölye)'),
    'T04': ('Line tasks with the RGB installed (MNT-02)', 'RGB takılıyken hat görevleri (MNT-02)'),
}


def minutes(counts, fixed, direction):
    rem = sum(c * EL[k][0] for c, k in zip(counts, ('fastener', 'connector', 'line')))
    ins = sum(c * EL[k][1] for c, k in zip(counts, ('fastener', 'connector', 'line')))
    if direction == 'rem':
        return rem + fixed, 0.0
    if direction == 'inst':
        return 0.0, ins + fixed
    return rem + fixed, ins + fixed


def main():
    out = os.path.join(HERE, 'mnt_tasks_v1.csv')
    tot = {}
    with open(out, 'w', newline='', encoding='utf-8') as fh:
        w = csv.writer(fh)
        w.writerow(['task', 'task_en', 'task_tr', 'level', 'step', 'step_en', 'step_tr', 'fasteners', 'connectors',
                    'lines', 'remove_min', 'install_min', 'people', 'rgb_installed', 'ica', 'requirement'])
        n = {}
        for s in STEPS:
            task, level, en, tr, counts, fixed, direction, people, inst, ica, req = s
            n[task] = n.get(task, 0) + 1
            r, i = minutes(counts, fixed, direction)
            tot.setdefault(task, [0.0, 0.0, 0])
            tot[task][0] += r
            tot[task][1] += i
            tot[task][2] = max(tot[task][2], people)
            w.writerow([task, TASKS[task][0], TASKS[task][1], level, n[task], en, tr, *counts, '%.1f' % r, '%.1f' % i,
                        people, inst, ica, req])
    print('%s written' % out)
    for task, (r, i, p) in tot.items():
        note = '  (independent tasks, not one sequence)' if task == 'T04' else ''
        print('%s  %-60s remove %5.1f h  install %5.1f h  total %5.1f h  (up to %d people)%s'
              % (task, TASKS[task][0], r / 60, i / 60, (r + i) / 60, p, note))


if __name__ == '__main__':
    main()
