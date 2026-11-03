"""Step 3.12: comparison of the RGB with the CT7-9 and the PT6A-67A gearboxes.

    python comparison/make_comparison.py        (matplotlib; use the anaconda python on Hamit's PC)

Writes comparison/comparison_v1.csv (one row per quantity, Turkish and English, with the source of every
value) and the chart docs/figures/step312/rgb_mass_en.png / _tr.png (RGB mass against propeller torque).

Neither type certificate data sheet gives the gearbox mass, so it is derived from the dry weights of the same
data sheet and the report says so:
  CT7-9B/-9C: dry weight 365.1 kg minus the CT7-2A turboshaft of the same core, 194.6 kg (EASA IM.E.010,
              Issue 10). The 170.5 kg is the propeller gearbox with its accessory pads, the drive shaft to it and
              the front-drive structure: an upper bound of the gearbox itself.
  PT6A-67A:   the PT6A-66 and -67A share the series description (2-stage reduction gearbox, 2-stage power
              turbine); the -67A is 22.7 kg heavier (229.5 against 206.8 kg) for 5,028 against 3,024 N m of
              propeller torque (EASA IM.E.008, Issue 06). If the whole difference is gearbox and gearbox mass
              scales with torque to a power k of 0.75 to 1.0, the -67A gearbox is m = dm r^k / (r^k - 1),
              r = 5,028 / 3,024: 57 to 72 kg.
Our values come from the design records (SYS-06 roll-up, steps 2.7, 3.1 to 3.9). Self-checks: the speed
ratios from the data-sheet speeds, the torque from power and speed against the data-sheet torque.
Source: Phase 3 report, Section 3.12.
"""
import csv
import math
import os

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
FIG = os.path.join(ROOT, 'docs', 'figures', 'step312')

TCDS_CT7 = 'EASA TCDS IM.E.010 Issue 10 (19 Dec 2025)'
TCDS_PT6 = 'EASA TCDS IM.E.008 Issue 06 (18 Feb 2022)'

# --- data-sheet values -------------------------------------------------------------------------------
CT7 = dict(P_mcp=1305.0, P_apr=1394.0, n_prop=1384.0, n_pt=22000.0, speed_ratio=0.06291, dry=365.1,
           dry_core=194.6, L=2438.0, W=660.0, H=737.0, L_core=1194.0)
PT6 = dict(P_to=895.0, n_prop=1700.0, n_pt=29894.0, T_to=5028.0, T_tr=6915.0, dry=229.5, L=1888.5, D=466.1,
           dry_66=206.8, T_66=3024.0, P_66=634.0)
# --- this design (design records) --------------------------------------------------------------------
OURS = dict(P=895.0, n_prop=1700.0, n_pt=22000.0, i=12.932, T=5027.0, m=109.95, m_drive=5.46,
            m_planetary=66.43, m_first=21.77, m_acc=10.09, m_oil=4.70, m_allow=5.46, m_later=1.50,
            losses=12.39, eff=98.71, heat_oil=14.9, tbo=4000, L=798.0, OD=325.0, offset=146.0)
K = (0.75, 1.0)
CORE, TANK = 198.0, 1.6                     # kg: T700-GE-700 dry (Phase 0), RGB oil tank (ICD-34)
HERON = dict(mtow=5670.0, payload=2700.0)   # kg, IAI Heron TP page


def torque(P_kw, n_rpm):
    return P_kw * 1e3 / (n_rpm * 2 * math.pi / 60)


def pt6_rgb(k):
    r = PT6['T_to'] / PT6['T_66']
    dm = PT6['dry'] - PT6['dry_66']
    return dm * r ** k / (r ** k - 1)


def main():
    # self-checks against the data sheets
    i_ct7 = CT7['n_pt'] / CT7['n_prop']
    assert abs(1 / i_ct7 - CT7['speed_ratio']) / CT7['speed_ratio'] < 2e-3, 'CT7-9 speed ratio'
    T_ct7 = torque(CT7['P_mcp'], CT7['n_prop'])
    T_pt6 = torque(PT6['P_to'], PT6['n_prop'])
    assert abs(T_pt6 / PT6['T_to'] - 1) < 1e-3, 'PT6A-67A torque from power and speed'
    T_ours = torque(OURS['P'], OURS['n_prop'])
    assert abs(T_ours / OURS['T'] - 1) < 1e-3, 'our torque'
    assert abs(OURS['m_planetary'] + OURS['m_first'] + OURS['m_acc'] + OURS['m_oil'] + OURS['m_allow']
               + OURS['m_later'] - OURS['m']) < 0.02, 'mass split'
    i_pt6 = PT6['n_pt'] / PT6['n_prop']
    m_ct7 = CT7['dry'] - CT7['dry_core']
    m_pt6 = [pt6_rgb(k) for k in K[::-1]]                     # k 1.0 gives the low end
    m_ct7_scaled = [m_ct7 * (OURS['T'] / T_ct7) ** k for k in K[::-1]]
    m_engine = CORE + OURS['m'] + OURS['m_drive'] + TANK

    def rng(a, fmt='%.0f'):
        return (fmt + '-' + fmt) % (a[0], a[1])

    rows = [
        ('ratio', 'Reduction ratio', 'Redüksiyon oranı', '%.2f (22,000 / 1,700 rpm)' % OURS['i'],
         '%.2f (22,000 / 1,384 rpm)' % i_ct7, '%.2f (29,894 / 1,700 rpm)' % i_pt6,
         'speeds from the data sheets; CT7-9 speed ratio 0.06291 (pad table)'),
        ('power', 'Power, kW (take-off)', 'Güç, kW (kalkış)', '895 (flat-rated)', '1,305 (1,394 APR)', '895',
         'TCDS ratings, sea level'),
        ('torque', 'Propeller torque, N m', 'Pervane torku, N m', '%.0f' % OURS['T'], '%.0f (from power and speed)' % T_ct7,
         '%.0f (data sheet; transient %.0f)' % (PT6['T_to'], PT6['T_tr']), 'CT7-9 torque = 1,305 kW at 1,384 rpm'),
        ('mass', 'Gearbox mass, kg', 'Dişli kutusu kütlesi, kg', '%.2f (SYS-06 roll-up; + %.2f input drive)' % (OURS['m'], OURS['m_drive']),
         '%.1f (derived upper bound)' % m_ct7, '%s (derived estimate)' % rng(m_pt6),
         'not in either data sheet: derived from the dry weights (see the method)'),
        ('power_density', 'Power density, kW/kg', 'Güç yoğunluğu, kW/kg', '%.2f' % (OURS['P'] / OURS['m']),
         '%.2f (MCP), %.2f (APR)' % (CT7['P_mcp'] / m_ct7, CT7['P_apr'] / m_ct7),
         rng([PT6['P_to'] / m_pt6[1], PT6['P_to'] / m_pt6[0]], '%.1f'), 'power over gearbox mass'),
        ('torque_density', 'Torque density, N m/kg', 'Tork yoğunluğu, N m/kg', '%.1f' % (OURS['T'] / OURS['m']),
         '%.1f' % (T_ct7 / m_ct7), rng([PT6['T_to'] / m_pt6[1], PT6['T_to'] / m_pt6[0]]), 'propeller torque over gearbox mass'),
        ('scaled', 'CT7-9 gearbox scaled to our torque, kg', 'Torkumuza ölçeklenmiş CT7-9 dişli kutusu, kg',
         '%.2f' % OURS['m'], rng(m_ct7_scaled), '-', 'm = 170.5 (T / 9,004)^k, k 0.75-1.0'),
        ('layout', 'Layout', 'Düzen', 'offset helical first stage 31/110 (PT axis 146 mm below) + planetary 45/37/119, '
         '4 planets, fixed ring, carrier drives the propeller',
         'front drive, integral propeller gearbox forward of the core; stages not public',
         '2-stage reduction gearbox, coaxial (planetary)', 'TCDS descriptions; our design records'),
        ('accessories', 'Accessories on the gearbox', 'Dişli kutusundaki aksesuarlar',
         'generator, OSG, PCU, oil pumps (10.09 kg of drives)', 'AC generator, hydraulic pump, OSG, PCU',
         'propeller governor and overspeed governor; the generator is on the rear gearbox driven by the gas generator',
         'CT7-9: TCDS pad table; PT6A: TCDS (separate accessory gearbox) and the known PT6 layout; ours: step 2.6'),
        ('size', 'Size, mm', 'Boyut, mm', 'RGB about %.0f long (accessory cover to propeller flange), case flange OD %.0f'
         % (OURS['L'], OURS['OD']), 'engine %.0f x %.0f x %.0f with the gearbox; gearbox and drive about %.0f long (derived)'
         % (CT7['L'], CT7['W'], CT7['H'], CT7['L'] - CT7['L_core']), 'engine %.1f long, %.1f diameter' % (PT6['L'], PT6['D']),
         'TCDS dimensions; CT7-9 gearbox length = 2,438 - 1,194 (CT7-2A)'),
        ('efficiency', 'Efficiency at max. continuous', 'Azami sürekli güçte verim', '%.2f%% (losses %.2f kW)' % (OURS['eff'], OURS['losses']),
         'not published', 'not published', 'our step 2.7 / CDR SYS-05'),
        ('heat', 'Heat into the oil, kW', 'Yağa giden ısı, kW', '%.1f (incl. PT rear sump 1.2)' % OURS['heat_oil'],
         'not published', 'not published', 'our step 2.7'),
        ('oil', 'Oil system', 'Yağ sistemi', 'separate RGB system with emergency mist (LUB-07)', 'self-contained engine system',
         'one engine oil system', 'CT7-9: TCDS description; PT6A: TCDS oil limits for the whole engine; ours: steps 2.7, 3.2'),
        ('tbo', 'TBO, h', 'TBO, sa', '%d (STR-05) with HUMS on condition between' % OURS['tbo'],
         'no fixed TBO (GE, CT7 family)', 'set by P&WC SB14603 (not public); sibling -67R 6,000 h initial',
         'GE CT7 page; TCDS note 5; Basler Turbo'),
        ('engine_mass', 'Engine dry mass, kg', 'Motor kuru kütlesi, kg',
         'about %.0f (T700-class core %.0f + RGB %.2f + input drive %.2f + oil tank %.1f; ICD-34)'
         % (m_engine, CORE, OURS['m'], OURS['m_drive'], TANK), '%.1f' % CT7['dry'], '%.1f' % PT6['dry'],
         'data sheets; core T700-GE-700 437 lb (Phase 0)'),
        ('payload', 'Payload cost on the Heron TP, kg', 'Heron TP\'de faydalı yük bedeli, kg',
         '%.1f more than the PT6A-67A installation: %.1f%% of the 2,700 kg maximum payload, %.1f%% of the 5,670 kg MTOW'
         % (m_engine - PT6['dry'], 100 * (m_engine - PT6['dry']) / HERON['payload'], 100 * (m_engine - PT6['dry']) / HERON['mtow']),
         '-', 'reference (flies on the Heron TP today)', 'IAI Heron TP page; at fixed MTOW the extra mass comes out of payload and fuel'),
    ]
    with open(os.path.join(HERE, 'comparison_v1.csv'), 'w', newline='', encoding='utf-8') as fh:
        w = csv.writer(fh)
        w.writerow(['id', 'quantity_en', 'quantity_tr', 'this_design', 'CT7-9B/C', 'PT6A-67A', 'basis'])
        w.writerows(rows)
    # sources table
    with open(os.path.join(HERE, 'sources_v1.csv'), 'w', newline='', encoding='utf-8') as fh:
        w = csv.writer(fh)
        w.writerow(['id', 'source', 'url', 'used_for'])
        w.writerows([
            ('S1', TCDS_CT7, 'https://www.easa.europa.eu/en/downloads/7783/en',
             'CT7-9 ratings, propeller speed, speed ratio, dry weights (CT7-9B/C, CT7-2A), dimensions, pad list'),
            ('S2', TCDS_PT6, 'https://www.easa.europa.eu/en/downloads/7787/en',
             'PT6A-67A and -66 ratings, torque limits, speeds, dry weights, dimensions, gearbox description, TBO note'),
            ('S3', 'GE Aerospace, CT7 engine page', 'https://www.geaerospace.com/commercial/aircraft-engines/ct7',
             'no time between overhauls (CT7/T700 family)'),
            ('S4', 'Basler Turbo Conversions, power and performance', 'https://www.baslerturbo.com/power-and-performance.html',
             'PT6A-67R TBO 6,000 h initial'),
            ('S5', 'IAI, Heron TP product page', 'https://www.iai.co.il/p/heron-tp',
             'MTOW 5,670 kg, maximum payload 2,700 kg, 1,200 hp PT6 powerplant'),
        ])

    # chart: gearbox mass against propeller torque
    os.makedirs(FIG, exist_ok=True)
    for lang in ('en', 'tr'):
        tr = lang == 'tr'
        fig, ax = plt.subplots(figsize=(8.6, 5.2), dpi=130)
        Ts = [3000 + 70 * j for j in range(101)]
        lo = [m_ct7 * (t / T_ct7) ** 1.0 for t in Ts]
        hi = [m_ct7 * (t / T_ct7) ** 0.75 for t in Ts]
        ax.fill_between(Ts, lo, hi, color='#9db7d5', alpha=0.45, lw=0,
                        label='CT7-9 dişli kutusu torka ölçeklenmiş (k 0,75-1,0)' if tr else 'CT7-9 gearbox scaled with torque (k 0.75-1.0)')
        ax.plot(T_ct7, m_ct7, 's', color='#2f5d8a', ms=9, label='CT7-9B/C (türetilmiş üst sınır)' if tr else 'CT7-9B/C (derived upper bound)')
        mid = sum(m_pt6) / 2
        ax.errorbar(PT6['T_to'] + 60, mid, yerr=[[mid - m_pt6[0]], [m_pt6[1] - mid]], fmt='D', color='#7a7a7a', ms=8,
                    capsize=5, label='PT6A-67A (türetilmiş tahmin)' if tr else 'PT6A-67A (derived estimate)')
        ax.plot(OURS['T'] - 60, OURS['m'], 'o', color='#c0392b', ms=10, label='Bu tasarım, SYS-06' if tr else 'This design, SYS-06')
        ax.plot(OURS['T'] - 60, OURS['m_planetary'], 'o', mfc='white', mec='#c0392b', mew=2, ms=9,
                label='Bu tasarım, yalnız planet modülü' if tr else 'This design, planetary module only')
        ax.plot([OURS['T'] - 60] * 2, [OURS['m_planetary'] + 3.5, OURS['m'] - 3.5], ':', color='#c0392b', lw=1.2)
        ax.text(OURS['T'] + 220, (OURS['m'] + OURS['m_planetary']) / 2,
                'birinci kademe 21,8 + aksesuarlar 10,1\n+ yağ ve sis 4,7 + paylar 7,0 kg' if tr else
                'first stage 21.8 + accessories 10.1\n+ oil and mist 4.7 + allowances 7.0 kg',
                fontsize=8.5, color='#444', va='center')
        ax.set_xlim(3000, 10000)
        ax.set_ylim(0, 200)
        ax.set_xlabel('Pervane torku, N m (kalkış / azami sürekli)' if tr else 'Propeller torque, N m (take-off / max. continuous)')
        ax.set_ylabel('Dişli kutusu kütlesi, kg' if tr else 'Gearbox mass, kg')
        ax.set_title('Bu RGB, torkuna ölçeklenmiş CT7-9 dişli kutusunun üst ucunda' if tr else
                     'This RGB sits at the top of the CT7-9 gearbox scaled to its torque', fontsize=11)
        ax.grid(alpha=0.3)
        ax.legend(fontsize=8.5, loc='upper left')
        fig.tight_layout()
        fig.savefig(os.path.join(FIG, 'rgb_mass_%s.png' % lang))
        plt.close(fig)

    print('CT7-9: i %.3f, torque %.0f N m, gearbox %.1f kg (derived), %.2f kW/kg, %.1f N m/kg'
          % (i_ct7, T_ct7, m_ct7, CT7['P_mcp'] / m_ct7, T_ct7 / m_ct7))
    print('CT7-9 scaled to %.0f N m: %.1f-%.1f kg' % (OURS['T'], *m_ct7_scaled))
    print('PT6A-67A: i %.3f, torque %.0f N m, gearbox %.1f-%.1f kg (derived)' % (i_pt6, T_pt6, *m_pt6))
    print('this design: i %.3f, torque %.0f N m, %.2f kg, %.2f kW/kg, %.1f N m/kg'
          % (OURS['i'], T_ours, OURS['m'], OURS['P'] / OURS['m'], OURS['T'] / OURS['m']))
    print('checks passed: speed ratio, torques, mass split')


if __name__ == '__main__':
    main()
