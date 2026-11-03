"""Overview figures (docs/figures/overview/*_en.png and *_tr.png).

    C:\\Users\\Hamit\\anaconda3\\python.exe report/make_figs.py

1. process: the four phases with their reviews and the decisions taken at each
2. drivechain: power path from the power turbine to the propeller with the shaft speeds and torques
3. reqstatus: requirement count and status per version (v1 SRR, v2 PDR, v3 CDR, v4 end of Phase 3)
4. compliance: final compliance verdicts per requirement group (requirements/compliance_final.csv)
Values are those of the project records named in each function.
"""
import csv
import os

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
OUT = HERE
os.makedirs(OUT, exist_ok=True)
plt.rcParams.update({'font.family': 'Times New Roman', 'font.size': 10})
BLUE, GREY, RED, GREEN, AMBER = '#2f5d8a', '#7a7a7a', '#c0392b', '#3a8a4a', '#d98c1f'

T = {
    'en': dict(
        phases=[('Phase 0', 'Literature and\nrequirements', 'SRR', '53 requirements v1\n8 SRR decisions'),
                ('Phase 1', 'Concept and\ntrade studies', 'PDR', 'Installation C, layout O\n4 planets, own oil system'),
                ('Phase 2', 'Detail design\nand analysis', 'CDR', '66 requirements v3\nDecisions 1-7'),
                ('Phase 3', 'Manufacturing docs,\nverification', 'Final', '69 requirements v4\n25 planned tests')],
        chain=[('Power turbine', '22,000 rpm\n388 N m'), ('Floating shaft\n66 x 1.5 mm', 'two diaphragm\ncouplings'),
               ('Input pinion\nz 31', 'helical, 146 mm\noffset'), ('First-stage gear\nz 110', '6,200 rpm\naccessory drives'),
               ('Sun z 45, 4 planets\nz 37, ring z 119', 'fixed ring'), ('Carrier =\npropeller shaft', '1,700 rpm\n5,027 N m')],
        chain_title='Power path: i = 110/31 x (1 + 119/45) = 12.93',
        ver=['v1 (SRR)', 'v2 (PDR)', 'v3 (CDR)', 'v4 (final)'], st=['Agreed', 'TBR', 'TBD'], ylab='Requirements',
        comp_title='Final compliance by requirement group', verdicts=['met', 'partial', 'open', 'tbd'],
        vlab=['met', 'partly met', 'open', 'waiting for partner value']),
    'tr': dict(
        phases=[('Faz 0', 'Literatür ve\ngereksinimler', 'SRR', '53 gereksinim v1\n8 SRR kararı'),
                ('Faz 1', 'Konsept ve\nkarşılaştırmalar', 'PDR', 'Kurulum C, düzen O\n4 planet, ayrı yağ sistemi'),
                ('Faz 2', 'Detay tasarım\nve analiz', 'CDR', '66 gereksinim v3\nKararlar 1-7'),
                ('Faz 3', 'Üretim dokümanları,\ndoğrulama', 'Final', '69 gereksinim v4\n25 planlı test')],
        chain=[('Güç türbini', '22.000 dev/dk\n388 N m'), ('Yüzer mil\n66 x 1,5 mm', 'iki diyafram\nkaplin'),
               ('Giriş pinyonu\nz 31', 'helisel, 146 mm\nkaçık eksen'), ('Birinci kademe\ndişlisi z 110', '6.200 dev/dk\naksesuar tahrikleri'),
               ('Güneş z 45, 4 planet\nz 37, halka z 119', 'sabit halka'), ('Taşıyıcı =\npervane mili', '1.700 dev/dk\n5.027 N m')],
        chain_title='Güç yolu: i = 110/31 x (1 + 119/45) = 12,93',
        ver=['v1 (SRR)', 'v2 (PDR)', 'v3 (CDR)', 'v4 (final)'], st=['Agreed', 'TBR', 'TBD'], ylab='Gereksinim sayısı',
        comp_title='Gereksinim grubuna göre final uyum', verdicts=['met', 'partial', 'open', 'tbd'],
        vlab=['karşılandı', 'kısmen', 'açık', 'ortak değeri bekliyor']),
}


def box(ax, x, y, w, h, text, fc='white', ec=BLUE, fs=9, bold=False):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle='round,pad=0.02,rounding_size=0.06', fc=fc, ec=ec, lw=1.2))
    ax.text(x + w / 2, y + h / 2, text, ha='center', va='center', fontsize=fs, fontweight='bold' if bold else 'normal')


def process(L, lang):
    fig, ax = plt.subplots(figsize=(8.6, 3.0), dpi=200)
    ax.set_xlim(0, 10); ax.set_ylim(0, 3.2); ax.axis('off')
    for k, (ph, what, gate, out) in enumerate(L['phases']):
        x = 0.2 + 2.45 * k
        box(ax, x, 1.75, 2.0, 1.1, f'{ph}\n{what}', fc='#e8eef5', bold=False)
        if k < 3:
            ax.plot([x + 2.0, x + 2.45], [2.3, 2.3], color=GREY, lw=1.2)
        ax.add_patch(plt.Polygon([[x + 1.0, 1.55], [x + 1.15, 1.35], [x + 1.0, 1.15], [x + 0.85, 1.35]], color=AMBER))
        ax.text(x + 1.0, 0.98, gate, ha='center', va='top', fontsize=9, fontweight='bold')
        ax.text(x + 1.0, 0.62, out, ha='center', va='top', fontsize=8.5, color='#333333')
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, f'process_{lang}.png'))
    plt.close(fig)


def drivechain(L, lang):
    fig, ax = plt.subplots(figsize=(7.2, 2.5), dpi=220)
    ax.set_xlim(0, 12); ax.set_ylim(0, 2.6); ax.axis('off')
    for k, (name, note) in enumerate(L['chain']):
        x = 0.1 + 2.0 * k
        box(ax, x, 1.2, 1.75, 0.95, name, fc='#e8eef5' if k not in (0, 5) else '#f3e6d6', fs=9)
        ax.text(x + 0.875, 1.05, note, ha='center', va='top', fontsize=9, color='#222222')
        if k < 5:
            ax.annotate('', xy=(x + 2.0, 1.67), xytext=(x + 1.75, 1.67), arrowprops=dict(arrowstyle='->', color=GREY, lw=1.3))
    ax.text(6, 2.45, L['chain_title'], ha='center', fontsize=10, fontweight='bold')
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, f'drivechain_{lang}.png'))
    plt.close(fig)


def reqstatus(L, lang):
    data = {'Agreed': [24, 27, 29, 28], 'TBR': [19, 25, 28, 34], 'TBD': [10, 13, 9, 7]}   # v1, v2, v3, v4 records
    fig, ax = plt.subplots(figsize=(6.0, 3.0), dpi=200)
    bottom = [0] * 4
    for s, c in zip(L['st'], [GREEN, AMBER, GREY]):
        ax.bar(L['ver'], data[s], bottom=bottom, color=c, label=s, width=0.6)
        for i, v in enumerate(data[s]):
            ax.text(i, bottom[i] + v / 2, str(v), ha='center', va='center', color='white', fontsize=9, fontweight='bold')
        bottom = [b + v for b, v in zip(bottom, data[s])]
    for i, b in enumerate(bottom):
        ax.text(i, b + 1, str(b), ha='center', fontsize=9)
    ax.set_ylabel(L['ylab']); ax.set_ylim(0, 80); ax.legend(loc='upper left', fontsize=8.5, ncol=3, frameon=False)
    ax.spines[['top', 'right']].set_visible(False)
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, f'reqstatus_{lang}.png'))
    plt.close(fig)


def compliance(L, lang):
    rows = list(csv.DictReader(open(os.path.join(ROOT, 'requirements', 'compliance_final.csv'), encoding='utf-8')))
    groups = []
    for r in rows:
        g = r['id'].split('-')[0]
        if g not in groups:
            groups.append(g)
    cnt = {g: {v: 0 for v in L['verdicts']} for g in groups}
    for r in rows:
        cnt[r['id'].split('-')[0]][r['verdict']] += 1
    fig, ax = plt.subplots(figsize=(7.2, 3.2), dpi=200)
    left = [0] * len(groups)
    for v, lab, c in zip(L['verdicts'], L['vlab'], [GREEN, AMBER, RED, GREY]):
        vals = [cnt[g][v] for g in groups]
        ax.barh(groups, vals, left=left, color=c, label=lab, height=0.6)
        left = [a + b for a, b in zip(left, vals)]
    ax.invert_yaxis(); ax.set_title(L['comp_title'], fontsize=10)
    ax.legend(fontsize=8, ncol=4, loc='lower center', bbox_to_anchor=(0.5, -0.3), frameon=False)
    ax.spines[['top', 'right']].set_visible(False)
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, f'compliance_{lang}.png'))
    plt.close(fig)


SEQ = {
    'en': [('1  Coupons', 'CT-01 A357-T6 hot yield and fatigue  ·  CT-02 damping-ring friction'),
           ('2  First-article inspection', 'IN-01 CMM to the drawing callouts, CT/RT of castings, case depth, surface finish'),
           ('3  Rig and component tests', 'RT-01 back-to-back gears · RT-02 planet bearing speed · RT-03 static case\nRT-04 tap test, ring-down · RT-05 pads · RT-06 fire · RT-07 NJ1024 rib · RT-08 catcher lip\nRT-09 torque meter, HUMS · RT-10 sand, salt · RT-11 splines'),
           ('4  Engine on the water brake', 'ET-01 vibration survey · ET-02 over-torque · ET-04 110% overspeed\nET-05 oil attitude, negative g · ET-09 shaft-break trip'),
           ('5  Endurance and special runs', 'ET-03 150 h endurance and teardown  ·  ET-06 loss of oil with mist  ·  ET-08 cold start, altitude\nwith the propeller: ET-07 windmilling  ·  ET-10 feathering, overspeed governor'),
           ('6  Maintenance demonstration', 'MD-01 module removal and installation against MNT-01 (8 h), access per MNT-02')],
    'tr': [('1  Numuneler', 'CT-01 A357-T6 sıcak akma ve yorulma  ·  CT-02 sönüm halkası sürtünmesi'),
           ('2  İlk parça muayenesi', 'IN-01 resim işaretlerine CMM, dökümlerin CT/RT muayenesi,\nsementasyon derinliği, yüzey kalitesi'),
           ('3  Düzenek ve parça testleri', 'RT-01 sırt sırta dişliler · RT-02 planet rulmanı hızı · RT-03 statik gövde\nRT-04 vurma, sönümlenme · RT-05 pedler · RT-06 yangın · RT-07 NJ1024 kenarı · RT-08 yakalama dudağı\nRT-09 tork ölçer, HUMS · RT-10 kum, tuz · RT-11 kamalar'),
           ('4  Su frenli dinamometrede motor', 'ET-01 titreşim taraması · ET-02 aşırı tork · ET-04 %110 aşırı hız\nET-05 yağ duruş açısı, negatif g · ET-09 mil kopması kesmesi'),
           ('5  Dayanıklılık ve özel çalışmalar', 'ET-03 150 saat dayanıklılık ve söküm  ·  ET-06 sisle yağsız çalışma  ·  ET-08 soğuk kalkış, irtifa\npervaneyle: ET-07 rüzgârla dönme  ·  ET-10 tüyleme, aşırı devir regülatörü'),
           ('6  Bakım gösterimi', 'MD-01 modül söküm ve takma, MNT-01 (8 sa) ve MNT-02 erişimine göre')],
}


def testseq(lang):
    fig, ax = plt.subplots(figsize=(6.6, 6.2), dpi=220)
    ax.set_xlim(0, 10); ax.set_ylim(0, 6.3); ax.axis('off')
    for k, (name, body) in enumerate(SEQ[lang]):
        y = 5.4 - 1.0 * k
        main = k == 4
        box(ax, 0.1, y - 0.36, 9.8, 0.78, '', fc='#e8eef5' if main else 'white', ec=BLUE)
        ax.text(0.3, y + 0.22, name, fontsize=10, fontweight='bold', va='center')
        ax.text(0.3, y - 0.1, body.replace('  ·  ', ' · '), fontsize=7.6, va='center', color='#222222', linespacing=1.25)
        if k < 5:
            ax.annotate('', xy=(5.0, y - 0.62), xytext=(5.0, y - 0.38), arrowprops=dict(arrowstyle='->', color=GREY))
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, f'testseq_{lang}.png'))
    plt.close(fig)


CUT = {
    'en': dict(flight='flight direction', core='given core (T700 class)', scope='designed in this work', cust='customer',
               parts=['1 inlet', '2 compressor (5 axial + 1 centrifugal)', '3 combustor', '4 gas-generator turbine',
                      '5 free power turbine, 22,000 rpm', '6 split exhaust', '7 PT output shaft in a tunnel',
                      '8 reduction gearbox (RGB)', '9 accessory pads', '10 propeller shaft, 1,700 rpm', '11 pusher propeller'],
               note='Schematic, not to scale; the propeller axis is 146 mm above the engine axis in the real layout.'),
    'tr': dict(flight='uçuş yönü', core='hazır çekirdek (T700 sınıfı)', scope='bu çalışmada tasarlanan', cust='müşterinin',
               parts=['1 hava girişi', '2 kompresör (5 eksenel + 1 santrifüj)', '3 yanma odası', '4 gaz üreteci türbini',
                      '5 serbest güç türbini, 22.000 dev/dk', '6 çatallı egzoz', '7 tünelde güç türbini çıkış mili',
                      '8 redüksiyon dişli kutusu (RGB)', '9 aksesuar pedleri', '10 pervane mili, 1.700 dev/dk', '11 itici pervane'],
               note='Şematik, ölçeksiz; gerçek yerleşimde pervane ekseni motor ekseninin 146 mm üstündedir.'),
}


def cutaway(lang):
    L = CUT[lang]
    fig, ax = plt.subplots(figsize=(8.6, 4.8), dpi=220)
    ax.set_xlim(0, 20); ax.set_ylim(-6.6, 4.3); ax.axis('off'); ax.set_aspect('equal')
    core_c, scope_c, prop_c, hot = '#c9ccd1', '#3b6fb6', '#3a8a5a', '#e9a37a'
    # casing outline (upper and lower, symmetric)
    for s in (1, -1):
        ax.fill([0.3, 2.0, 5.2, 6.0, 8.6, 10.6, 11.2, 11.2, 10.6, 8.6, 6.0, 5.2, 2.0, 0.3],
                [s * 2.6, s * 2.6, s * 1.5, s * 2.3, s * 2.3, s * 1.9, s * 1.9, s * 0.9, s * 0.9, s * 0.9, s * 0.9, s * 0.6, s * 0.6, s * 1.6],
                color='#eef0f3', ec='#9aa0a8', lw=0.8)
    # compressor blades
    for k, x in enumerate([2.3, 2.9, 3.5, 4.1, 4.7]):
        h = 2.3 - 0.18 * k
        ax.plot([x, x], [0.7, h], color='#7d838c', lw=3)
        ax.plot([x, x], [-0.7, -h], color='#7d838c', lw=3)
    ax.fill([5.2, 6.0, 6.0, 5.2], [0.6, 0.9, 2.2, 1.5], color='#9aa0a8')
    ax.fill([5.2, 6.0, 6.0, 5.2], [-0.6, -0.9, -2.2, -1.5], color='#9aa0a8')
    # combustor
    for s in (1, -1):
        ax.add_patch(FancyBboxPatch((6.3, s * 1.3 - 0.35), 1.7, 0.7, boxstyle='round,pad=0.02,rounding_size=0.3', fc=hot, ec='#c0603a'))
    # turbines (GG 2 stages, PT 2 stages)
    for x, c in [(8.4, '#8d6e63'), (8.8, '#8d6e63'), (9.6, scope_c), (10.0, scope_c)]:
        ax.plot([x, x], [0.9, 2.0], color=c, lw=4)
        ax.plot([x, x], [-0.9, -2.0], color=c, lw=4)
    # central shafts
    ax.fill([0.8, 9.0, 9.0, 0.8], [0.35, 0.35, -0.35, -0.35], color=core_c, ec='#9aa0a8', lw=0.6)
    ax.fill([9.4, 14.6, 14.6, 9.4], [0.18, 0.18, -0.18, -0.18], color=scope_c)
    # split exhaust ducts
    for s in (1, -1):
        ax.fill([11.2, 13.4, 14.0, 12.0, 11.2], [s * 1.9, s * 3.2, s * 2.5, s * 0.9, s * 0.9], color='#f6d4c0', ec='#c0603a', lw=0.8)
    # tunnel
    ax.fill([11.2, 14.6, 14.6, 11.2], [0.45, 0.45, -0.45, -0.45], color='none', ec=scope_c, lw=1, ls='--')
    # RGB box and pads
    ax.add_patch(FancyBboxPatch((14.6, -1.6), 2.1, 3.0, boxstyle='round,pad=0.02,rounding_size=0.15', fc='#dbe6f4', ec=scope_c, lw=1.4))
    ax.add_patch(plt.Rectangle((14.9, -1.3), 0.5, 2.6, color='#7fa3d6'))
    ax.add_patch(plt.Rectangle((15.6, -0.9), 0.8, 1.8, color='#e39b5b'))
    for y in (1.45, -1.75):
        ax.add_patch(plt.Rectangle((15.1, y), 0.5, 0.3, color=scope_c))
    # propeller shaft and propeller
    ax.fill([16.7, 18.3, 18.3, 16.7], [0.32, 0.32, -0.32, -0.32], color=prop_c)
    ax.fill([18.3, 18.9, 18.3], [0.9, 0.0, -0.9], color='#2e6e48')
    ax.fill([18.45, 18.75, 18.85, 18.55], [0.3, 0.3, 3.4, 3.4], color='#6b6f75')
    ax.fill([18.45, 18.75, 18.85, 18.55], [-0.3, -0.3, -3.4, -3.4], color='#6b6f75')
    # labels
    pos = [(0.6, 3.0), (3.3, 3.0), (7.1, 2.1), (8.5, 2.6), (9.8, 2.6), (13.2, 3.5), (12.9, 0.7), (15.6, 1.9), (15.3, -2.3), (17.4, 0.7), (18.7, 3.75)]
    for (x, y), lab in zip(pos, L['parts']):
        ax.text(x, y, lab.split(' ')[0], ha='center', va='center', fontsize=8, color='white', fontweight='bold',
                bbox=dict(boxstyle='circle,pad=0.25', fc=scope_c if int(lab.split(' ')[0]) in (5, 7, 8, 9, 10) else ('#3a8a5a' if lab.startswith('11') else '#5b6068'), ec='none'))
    ax.annotate('', xy=(0.3, 3.9), xytext=(2.6, 3.9), arrowprops=dict(arrowstyle='->', color='#333333'))
    ax.text(2.8, 3.9, L['flight'], va='center', fontsize=8.5)
    # legend columns
    y0 = -4.0
    ax.text(0.3, y0, L['core'], fontsize=9, fontweight='bold', color='#5b6068')
    ax.text(9.0, y0, L['scope'], fontsize=9, fontweight='bold', color=scope_c)
    ax.text(15.9, y0, L['cust'], fontsize=9, fontweight='bold', color=prop_c)
    for i, lab in enumerate(L['parts'][:6]):
        ax.text(0.3 + (i // 3) * 4.4, y0 - 0.6 - (i % 3) * 0.55, lab, fontsize=8)
    for i, lab in enumerate(L['parts'][6:10]):
        ax.text(9.0 + (i // 2) * 3.75, y0 - 0.6 - (i % 2) * 0.55, lab, fontsize=7.6)
    ax.text(15.9, y0 - 0.6, L['parts'][10], fontsize=8)
    ax.text(0.3, -6.45, L['note'], fontsize=7.5, color='#555555', style='italic')
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, f'cutaway_{lang}.png'))
    plt.close(fig)


def tipspeed(lang):
    import numpy as np
    tr = lang == 'tr'
    n = np.linspace(0, 6000, 200)
    v = np.pi * 2.67 * n / 60
    fig, ax = plt.subplots(figsize=(6.4, 3.2), dpi=220)
    ax.plot(n, v, color=BLUE, lw=2)
    ax.axhline(340, color=RED, ls='--', lw=1.2)
    ax.text(150, 352, 'ses hızı, deniz seviyesi (340 m/s)' if tr else 'speed of sound at sea level (340 m/s)', color=RED, fontsize=8.5)
    ax.plot(1700, np.pi * 2.67 * 1700 / 60, 'o', color=AMBER, ms=8)
    ax.annotate('1.700 dev/dk: uç hızı 238 m/s (Mach 0,7)' if tr else '1,700 rpm: tip speed 238 m/s (Mach 0.7)', xy=(1700, 238), xytext=(2300, 140),
                fontsize=8.5, arrowprops=dict(arrowstyle='-', color=GREY))
    ax.text(3600, 560, 'güç türbini devrinde (22.000 dev/dk)\nuç 3.076 m/s giderdi: imkânsız' if tr else 'at power-turbine speed (22,000 rpm)\nthe tip would move at 3,076 m/s: impossible',
            fontsize=8.5, color='#333333')
    ax.set_xlabel('Pervane devri, dev/dk (2,67 m çap)' if tr else 'Propeller speed, rpm (2.67 m diameter)')
    ax.set_ylabel('Pal ucu hızı, m/s' if tr else 'Blade tip speed, m/s')
    ax.set_xlim(0, 6000); ax.set_ylim(0, 860); ax.grid(alpha=0.3); ax.spines[['top', 'right']].set_visible(False)
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, f'tipspeed_{lang}.png'))
    plt.close(fig)


def torquechain(lang):
    tr = lang == 'tr'
    names = ['Güç türbini\nmili', 'Ara mil\n(güneş)', 'Taşıyıcı =\npervane mili'] if tr else ['Power-turbine\nshaft', 'Intermediate\nshaft (sun)', 'Carrier =\npropeller shaft']
    rpm = [22000, 6200, 1700]
    tq = [388.5, 1378, 5027]
    fig, ax1 = plt.subplots(figsize=(6.4, 3.2), dpi=220)
    x = range(3)
    ax1.bar([i - 0.18 for i in x], rpm, width=0.36, color=BLUE, label='devir, dev/dk' if tr else 'speed, rpm')
    ax2 = ax1.twinx()
    ax2.bar([i + 0.18 for i in x], tq, width=0.36, color=AMBER, label='tork, N m' if tr else 'torque, N m')
    for i in x:
        ax1.text(i - 0.18, rpm[i] + 400, f'{rpm[i]:,}'.replace(',', '.' if tr else ','), ha='center', fontsize=8.5, color=BLUE)
        ax2.text(i + 0.18, tq[i] + 90, f'{tq[i]:,.0f}'.replace(',', '.' if tr else ','), ha='center', fontsize=8.5, color='#9a5b12')
    ax1.set_xticks(list(x)); ax1.set_xticklabels(names, fontsize=9)
    ax1.set_ylabel('Devir, dev/dk' if tr else 'Speed, rpm', color=BLUE); ax2.set_ylabel('Tork, N m' if tr else 'Torque, N m', color='#9a5b12')
    ax1.set_ylim(0, 25000); ax2.set_ylim(0, 5800)
    ax1.set_title('Aynı güç (895 kW): devir düşerken tork büyür, T = P / ω' if tr else 'Same power (895 kW): torque rises as speed falls, T = P / ω', fontsize=10)
    ax1.spines[['top']].set_visible(False); ax2.spines[['top']].set_visible(False)
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, f'torquechain_{lang}.png'))
    plt.close(fig)


def masshist(lang):
    """RGB dry mass through the project: PDR and CDR estimates, then the CATIA roll-ups of Phase 3
    (Phase 1 report section 5, Phase 2 report CDR table, Phase 3 report steps 3.1-3.9)."""
    tr = lang == 'tr'
    steps = (['PDR\ntahmini', 'CDR\ntahmini', '3.1 ilk\nCAD tartımı', '3.1\nA paketi', '3.2 yağ\ndonanımı, sis', '3.5 ikinci\npaket', '3.6 halka,\nflanş', '3.7 burun\nparçaları', '3.9\nson']
             if tr else ['PDR\nestimate', 'CDR\nestimate', '3.1 first\nCAD weighing', '3.1\npackage A', '3.2 oil\nhardware, mist', '3.5 second\npackage', '3.6 ring,\nflange', '3.7 nose\nparts', '3.9\nfinal'])
    m = [77.6, 90.3, 114.6, 107.7, 111.09, 108.45, 109.24, 110.10, 109.95]
    lab = ['77.6', '90.3', '114.6', '107.7', '111.09', '108.45', '109.24', '110.10', '109.95']
    fig, ax = plt.subplots(figsize=(6.6, 3.4), dpi=220)
    x = list(range(len(m)))
    ax.plot(x[:3], m[:3], ls='--', color=GREY, lw=1.2)
    ax.plot(x[2:], m[2:], color=BLUE, lw=2)
    ax.plot(x[:2], m[:2], 'o', mfc='white', mec=GREY, mew=1.6, ms=8, label='tahmin' if tr else 'estimate')
    ax.plot(x[2:], m[2:], 'o', color=BLUE, ms=8, label='CATIA tartımı' if tr else 'CATIA weighing')
    for i, v in enumerate(m):
        below = i in (3, 5, 8)
        dx, ha = (-0.15, 'right') if i in (0, 1) else (0, 'center')
        ax.text(i + dx, v + (-3.8 if below else 1.6) - (1.5 if i in (0, 1) else 0), lab[i].replace('.', ',') if tr else lab[i],
                ha=ha, fontsize=8.5)
    ax.plot([-0.4, 2.5], [100, 100], color=RED, ls=':', lw=1.4)
    ax.plot([2.5, 8.4], [110, 110], color=RED, lw=1.4)
    ax.text(-0.3, 101.2, 'sınır 100 kg (v1-v3)' if tr else 'limit 100 kg (v1-v3)', color=RED, fontsize=8.5)
    ax.text(5.45, 104.6, 'sınır 110 kg (TBR, v4)' if tr else 'limit 110 kg (TBR, v4)', color=RED, fontsize=8.5)
    ax.annotate('ilk tam CAD toplamı: tahminin\nkaçırdığı parçalar ortaya çıktı' if tr else 'first full CAD roll-up: parts\nthe estimate had missed appear',
                xy=(2, 114.6), xytext=(2.6, 86), fontsize=8.5, arrowprops=dict(arrowstyle='->', color=GREY))
    ax.set_xticks(x); ax.set_xticklabels(steps, fontsize=8)
    ax.set_ylabel('RGB kuru kütlesi, kg' if tr else 'RGB dry mass, kg')
    ax.set_xlim(-0.5, 8.5); ax.set_ylim(70, 120); ax.grid(axis='y', alpha=0.3)
    ax.spines[['top', 'right']].set_visible(False)
    ax.legend(loc='lower right', fontsize=8.5, frameon=False)
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, f'masshist_{lang}.png'))
    plt.close(fig)


if __name__ == '__main__':
    for lang, L in T.items():
        process(L, lang); drivechain(L, lang); reqstatus(L, lang); compliance(L, lang); testseq(lang)
        cutaway(lang); tipspeed(lang); torquechain(lang); masshist(lang)
    print('figures in', OUT)
