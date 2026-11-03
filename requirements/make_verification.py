"""Step 3.11: verification matrix and test plan (Phase 3).

Writes requirements/test_plan_v1.csv, requirements/verification_v1.csv and
requirements/test_cell_v1.csv from requirements_v3.csv, the CDR compliance evidence,
the Phase 3 change log and the lists below, then checks that every requirement verified
by test (T) has at least one planned test, that every test traces to existing
requirements and that every engine test has measuring points in the test cell.
Run: python requirements/make_verification.py
Nothing here is manufactured or tested; all tests are planned only. Text in Turkish and
English; the evidence column is the CDR evidence unless a Phase 3 step changed it.
"""
import csv
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

# id, seq, level, name_en, name_tr, rule, article, measure, pass_en, reqs
TESTS = [
    ("CT-01", 1, "coupon", "A357-T6 coupons: hot yield and fatigue", "A357-T6 numuneleri: sıcak akma ve yorulma",
     "CS-E 70; CS-E 515", "test bars cut from the first P101 / F201 castings",
     "yield at 20-350 degC (1/2 h), S-N at R = -1 and 0.1", "casting factor 1.25 and the 3.7 hot yield shown", "STR-10;SAF-05"),
    ("CT-02", 1, "coupon", "Damping ring friction coupon", "Sönüm halkası sürtünme numunesi",
     "-", "ring segment on an A357 groove coupon, oil-wetted", "friction coefficient, wear", "mu >= 0.15 (3.6 basis)", "DYN-03"),
    ("IN-01", 2, "inspection", "First article inspection", "İlk parça muayenesi",
     "CS-E 515; AS9102", "first P101, F201, P103, gears", "CMM to the 3.8 callouts, CT / RT of castings, case depth coupons, Ra",
     "all callouts of tolerances_v1.csv met; pores <= 0.5 mm in critical zones", "STR-06;STR-09;STR-10;SAF-02"),
    ("RT-01", 3, "rig", "Back-to-back gear rig (stage 1 + planetary)", "Sırt sırta dişli test düzeneği (1. kademe + planet)",
     "AGMA 925 / ISO 6336 practice", "one RGB gear set in a back-to-back rig, MIL-PRF-23699", "strain gauges at the ring roots (load sharing), loaded TE, micropitting and scuffing inspection, losses",
     "K_gamma <= 1.35; TE2 <= 0.15 um; no scuffing at 110% torque; losses <= SYS-05", "STR-06;STR-07;STR-11;SYS-05"),
    ("RT-02", 3, "rig", "Planet bearing speed and load rig", "Planet rulmanı hız ve yük düzeneği",
     "-", "planet with its integral outer race on the M50NiL pin", "outer race temperature, cage slip, vibration",
     "no skidding damage; temperature within the 2.5 limit", "STR-02"),
    ("RT-03", 3, "rig", "Static test of the cases (limit and ultimate)", "Gövdelerin statik testi (sınır ve nihai)",
     "STANAG 4671 USAR.305, USAR.307", "first P101 + F201 with the mounts", "strain gauges at the 3.5 / 3.6 hot spots, deflection at the ring seat",
     "no yield at limit (LD-03 to LD-05, LD-08), no failure at 1.5 x limit; stiffness within 10% of the FE", "STR-04;STR-10;LD-03;LD-04;LD-05;LD-08"),
    ("RT-04", 3, "rig", "Modal tap test and damping-ring ring-down", "Modal vurma testi ve sönüm halkası sönümlenme testi",
     "-", "P101 with the ring gear, gear 2 web with and without the ring", "accelerometers, impact hammer",
     "case and web modes within 5% of 3.6; damping with the ring at or above the 3.6 value", "DYN-03;DYN-04"),
    ("RT-05", 3, "rig", "Accessory pad and shear-neck test", "Aksesuar yuvası ve kesme boynu testi",
     "CS-E 80 (equipment)", "generator pad with its quill", "pad torque to the shear neck, overhung moment",
     "shear neck fails within its band; pad holds 1.5 x limit", "ACC-01;ACC-03"),
    ("RT-06", 3, "rig", "Fire test of F201 and the P101 / F201 joint", "F201 ve P101 / F201 birleşiminin yangın testi",
     "ISO 2685; AC 20-135 / AS6826; CS-E 130", "F201 with the joint and seals, oil flowing at the lowest flow", "flame calibration, wall and seal temperatures, leakage",
     "fire resistant 5 min with no leak that feeds the fire (SAF-05)", "SAF-05"),
    ("RT-07", 3, "rig", "NJ1024 standby rib test", "NJ1024 yedek kenar testi",
     "-", "NJ1024 in the nose housing, push-in load", "outer ring thermocouples, rib wear",
     "carries the limp thrust (3.0 kN) to landing; thermocouple alert works", "SAF-01;CTL-04"),
    ("RT-08", 3, "rig", "Catcher-lip rub test (Ti on 4340)", "Yakalama dudağı sürtünme testi (4340 üzerinde Ti)",
     "-", "P116 lip segment against a 4340 collar", "temperature, wear depth", "lip holds the run-down and feathered drag (3.7 basis)", "SAF-01"),
    ("RT-09", 3, "rig", "Torque meter calibration and HUMS baseline", "Tork ölçer kalibrasyonu ve HUMS temel çizgisi",
     "-", "torque meter on a calibrated rig; HUMS on the first engine", "torque signal against a reference, vibration baselines",
     "torque error within the CTL-01 limit; HUMS baselines recorded", "CTL-01;CTL-03"),
    ("RT-10", 3, "rig", "Sand, dust and salt fog", "Kum, toz ve tuz sisi",
     "MIL-STD-810H 509, 510", "seals, breather and the nose air gap", "ingress, corrosion, seal leakage", "no ingress past the seals; no corrosion beyond the limits", "ENV-03"),
    ("RT-11", 3, "rig", "Spline wear: crowned sun spline and accessory quills", "Kama aşınması: bombeli güneş kaması ve aksesuar milleri",
     "-", "sun quill P106 in the intermediate shaft with the 3.8 misalignment; generator quill", "wear depth and pattern, oil flow at the spline",
     "wear after the TBO equivalent within the 3.8 spline fit allowance; lubricated contact pattern", "STR-05;ACC-03"),
    ("ET-01", 4, "engine", "Vibration survey", "Titreşim taraması",
     "CS-E 650; 14 CFR 33.83", "engine on a water-brake dynamometer (no propeller), then with the propeller", "strain gauges on the case and the gear 2 web, accelerometers, speed sweep",
     "all stresses within the endurance limits with margin (DYN-01 to DYN-05)", "DYN-01;DYN-02;DYN-03;DYN-04;DYN-05;ENV-04"),
    ("ET-02", 4, "engine", "Over-torque and transient torque", "Aşırı tork ve geçici tork",
     "CS-E 820; 14 CFR 33.84", "engine on the dynamometer", "torque, speed, case strain",
     "LD-01 transient and LD-02 over-torque run without damage; teardown clean", "LD-01;LD-02;SYS-08"),
    ("ET-03", 5, "engine", "Endurance test and teardown", "Dayanıklılık testi ve söküm",
     "CS-E 740; 14 CFR 33.87, 33.93", "engine on the dynamometer, 150 h schedule", "power, losses, oil temperatures and pressures, chips, HUMS",
     "rated power held; oil limits met; no distress at teardown", "SYS-01;SYS-03;SYS-05;LUB-02;LUB-03;LUB-05;LUB-09;LUB-10;STR-06;CTL-03"),
    ("ET-04", 4, "engine", "Overspeed and 110% transient speed", "Aşırı hız ve %110 geçici hız",
     "CS-E 830", "engine on the dynamometer", "speeds, vibration", "110% transient run without damage", "SYS-04"),
    ("ET-05", 4, "engine", "Oil system: attitude and negative g", "Yağ sistemi: duruş açısı ve negatif g",
     "CS-E 570; 14 CFR 33.71 (lubrication system)", "RGB oil system on a tilt rig, then the engine", "pressures at the jets, scavenge, pitch oil pressure",
     "jet pressure held at the attitudes and for the negative-g time", "LUB-03;LUB-08;PIF-02"),
    ("ET-06", 5, "engine", "Loss-of-oil run with the emergency mist", "Acil sisle yağsız çalışma",
     "LUB-07 (Hamit's decision)", "engine on the dynamometer at 75% MCP", "bearing and gear temperatures, mist flow",
     ">= 6 min at 75% MCP after total oil-pressure loss", "LUB-07"),
    ("ET-07", 5, "engine", "Windmilling", "Rüzgârla dönme",
     "CS-E 525", "engine with propeller, motored by the propeller", "oil pressure, temperatures", "lubrication held while windmilling (intact drive chain)", "SAF-04"),
    ("ET-08", 5, "engine", "Cold start and altitude", "Soğuk kalkış ve irtifa",
     "test cell (cold soak, altitude)", "engine cold-soaked to -40 degC; altitude cell", "oil temperature rise, jet pressure, pump inlet pressure",
     "start and power within the 3.2 limits; no pump cavitation at altitude", "ENV-01;ENV-02;LUB-02"),
    ("ET-09", 4, "engine", "Shaft-break protection (FADEC hardware-in-the-loop + engine trip)", "Mil kopması koruması (FADEC donanım döngüsü + motor kesme)",
     "CS-E 510; AMC E 510", "FADEC on a hardware-in-the-loop bench, then engine trips", "detection time, valve closure time, peak PT speed",
     "detection and closure within SAF-03; peak PT speed below the burst margin", "SAF-03;SAF-06;CTL-02;CTL-04"),
    ("ET-10", 5, "engine", "Feathering and propeller overspeed governor", "Tüyleme ve pervane aşırı devir regülatörü",
     "CS-P (propeller) with the propeller maker", "engine with propeller", "pitch oil pressure, propeller speed, feather time",
     "feathers on loss of pitch oil; overspeed governor holds the limit", "PIF-02;PIF-03;PIF-05"),
    ("MD-01", 6, "demonstration", "Maintenance demonstration", "Bakım gösterimi",
     "-", "RGB modules (3.10)", "removal and installation times", "MNT-01 and MNT-02 met", "MNT-01;MNT-02"),
]

PASS_TR = {
    "CT-01": "1,25 döküm katsayısı ve 3.7 sıcak akma değerleri gösterildi",
    "CT-02": "mu >= 0,15 (3.6 esası)",
    "IN-01": "tolerances_v1.csv'deki bütün işaretler sağlandı; kritik bölgelerde gözenek <= 0,5 mm",
    "RT-01": "K_gamma <= 1,35; TE2 <= 0,15 um; %110 torkta tutukluk yok; kayıplar <= SYS-05",
    "RT-02": "kayma hasarı yok; sıcaklık 2.5 sınırı içinde",
    "RT-03": "sınır yükte akma yok (LD-03 - LD-05, LD-08), 1,5 x sınırda kırılma yok; direngenlik sonlu elemanın %10'u içinde",
    "RT-04": "gövde ve gövde-dişli modları 3.6'nın %5'i içinde; halkayla sönüm 3.6 değerinde ya da üstünde",
    "RT-05": "kesme boynu kendi bandında kırılır; yuva 1,5 x sınırı taşır",
    "RT-06": "5 dk yangına dayanıklı, yangını besleyen sızıntı yok (SAF-05)",
    "RT-07": "topal itkiyi (3,0 kN) inişe kadar taşır; termokupl uyarısı çalışır",
    "RT-08": "dudak, dönüp durmayı ve tüylenmiş sürüklemeyi taşır (3.7 esası)",
    "RT-09": "tork hatası CTL-01 sınırı içinde; HUMS temel kayıtları alındı",
    "RT-10": "keçeleri geçen giriş yok; sınırların ötesinde korozyon yok",
    "RT-11": "TBO eşdeğerinden sonra aşınma 3.8 kama geçmesi payı içinde; yağlanmış temas izi",
    "ET-01": "bütün gerilmeler yorulma sınırlarının altında, payla (DYN-01 - DYN-05)",
    "ET-02": "LD-01 geçici ve LD-02 aşırı tork hasarsız; sökümde temiz",
    "ET-03": "anma gücü tutuldu; yağ sınırları sağlandı; sökümde hasar yok",
    "ET-04": "%110 geçici hız hasarsız",
    "ET-05": "duruş açılarında ve negatif g süresince meme basıncı tutuldu",
    "ET-06": "toplam yağ basıncı kaybından sonra %75 MCP'de >= 6 dk",
    "ET-07": "rüzgârla dönerken yağlama sürdü (sağlam tahrik zinciri)",
    "ET-08": "kalkış ve güç 3.2 sınırları içinde; irtifada pompa kavitasyonu yok",
    "ET-09": "algılama ve kapanma SAF-03 içinde; en yüksek PT hızı patlama payının altında",
    "ET-10": "pervane yağı kaybında tüyler; aşırı devir regülatörü sınırı tutar",
    "MD-01": "MNT-01 ve MNT-02 sağlandı",
}

# Test cell (water-brake dynamometer in place of the propeller): measuring points
# id, location_en, location_tr, quantity, sensor, rate, tests
CELL = [
    ("MP-01", "PT shaft torque meter (phase shift) and dynamometer load cell", "PT mili tork ölçer (faz kayması) ve dinamometre yük hücresi",
     "torque", "engine torque meter + dyno load cell (reference)", "1 kHz", "ET-02;ET-03;ET-04;RT-09"),
    ("MP-02", "Np (two protection probes) and Nr (two pickups), once-per-rev tachometers on the intermediate shaft and the carrier",
     "Np (iki koruma algılayıcısı) ve Nr (iki algılayıcı), ara mil ve taşıyıcıda tur başına bir darbeli takometreler",
     "speed, phase", "magnetic pickups", "100 kHz (pulse timing)", "ET-01;ET-03;ET-04;ET-09"),
    ("MP-03", "Accelerometers: case wall over the ring gear (z 96), outer propeller bearing boss (z 442), first-stage case at the input bearings",
     "İvmeölçerler: halka dişli üstü gövde duvarı (z 96), dış pervane yatağı göbeği (z 442), giriş yatakları yanında birinci kademe gövdesi",
     "acceleration", "triaxial ICP accelerometers, 0-25 kHz", "51.2 kHz", "ET-01;ET-03;RT-09"),
    ("MP-04", "Strain gauges: gear 2 web (telemetry), ring gear roots, P101 R10 flange junction and the 3.5 / 3.6 hot spots",
     "Gerinim ölçerler: dişli 2 gövdesi (telemetri), halka dişli dip noktaları, P101 R10 flanş birleşimi ve 3.5 / 3.6 sıcak noktaları",
     "strain", "foil gauges; slip ring or telemetry on rotating parts", "20 kHz", "ET-01;ET-02"),
    ("MP-05", "Oil: pressure at the manifold and two jets, pump inlet, scavenge; temperature in and out of the RGB and of the cooler; flow",
     "Yağ: manifold ve iki memede basınç, pompa girişi, emiş; RGB ve soğutucu giriş-çıkış sıcaklığı; debi",
     "pressure, temperature, flow", "transducers, RTDs, turbine flow meter", "10 Hz", "ET-03;ET-05;ET-06;ET-08"),
    ("MP-06", "Bearing outer rings: NJ1024, QJ1024, planet pins (telemetry), input QJ; P116 skirt",
     "Rulman dış bilezikleri: NJ1024, QJ1024, planet pimleri (telemetri), giriş QJ; P116 eteği",
     "temperature", "thermocouples type K", "10 Hz", "ET-03;ET-06;RT-07"),
    ("MP-07", "Chip detectors, oil debris monitor, filter delta-p, oil samples every 10 h",
     "Talaş dedektörleri, yağ kalıntısı izleyicisi, filtre basınç farkı, her 10 saatte yağ numunesi",
     "debris", "engine sensors + spectrometric oil analysis", "event / 1 Hz", "ET-03;ET-06"),
    ("MP-08", "Pitch oil pressure at the transfer sleeve, feather solenoid, mist valve and accumulator pressure",
     "Transfer manşonunda hatve yağı basıncı, tüyleme solenoidi, sis valfi ve akümülatör basıncı",
     "pressure, discrete", "transducers, FADEC data bus", "100 Hz", "ET-05;ET-06;ET-07;ET-09;ET-10"),
    ("MP-09", "Cell: inlet air temperature and pressure, cold-soak chamber, altitude cell pressure",
     "Hücre: giriş havası sıcaklığı ve basıncı, soğuk bekletme odası, irtifa hücresi basıncı",
     "ambient", "cell instrumentation", "1 Hz", "ET-03;ET-08"),
]

LEVEL_TR = {"coupon": "numune", "inspection": "muayene", "rig": "düzenek", "engine": "motor", "demonstration": "gösterim"}

# Status after Phase 3 where a Phase 3 step changed it (else the CDR verdict): status, note_en, note_tr.
P3 = {
    "SYS-06": ("met", "109.95 kg against 110 kg TBR (3.7, with the 3.9 P115 hub scallops)",
               "110 kg TBR sınırına karşı 109,95 kg (3.7, 3.9'daki P115 göbek oyuklarıyla)"),
    "SYS-11": ("met", "5.46 kg against 6 kg TBR (3.3)", "6 kg TBR sınırına karşı 5,46 kg (3.3)"),
    "SAF-01": ("met", "fault tree: largest cut set 2.1e-9 /h, sum 3.3e-9 /h (3.7)",
               "hata ağacı: en büyük kesim kümesi 2,1e-9 /sa, toplam 3,3e-9 /sa (3.7)"),
    "SAF-02": ("partial", "7 critical parts with plans; lives TBR (3.7)", "planlarıyla 7 kritik parça; ömürler TBR (3.7)"),
    "SAF-03": ("partial", "all break locations detected; peak speed TBR (3.7)",
               "bütün kopma yerleri algılanıyor; en yüksek hız TBR (3.7)"),
    "SAF-04": ("partial", "met for an intact drive chain only (3.7)", "yalnız sağlam tahrik zinciri için sağlanıyor (3.7)"),
    "SAF-05": ("open", "oil-wetted walls pass; dry walls, seals, zero flow open (3.7)",
               "yağla ıslanan duvarlar geçiyor; kuru duvarlar, keçeler, sıfır debi açık (3.7)"),
    "DYN-03": ("met", "planetary case Goodman 1.19 at the R10 flange junction (3.6)",
               "planet gövdesi R10 flanş birleşiminde Goodman 1,19 (3.6)"),
    "STR-07": ("met", "K_gamma P99 1.257 with the drawing tolerances (3.8)", "resim toleranslarıyla K_gamma P99 1,257 (3.8)"),
    "STR-11": ("open", "TE2 <= 0.15 um set as the design value (3.6); LTCA and loaded TE test open",
               "TE2 <= 0,15 um tasarım değeri olarak kondu (3.6); LTCA ve yüklü TE testi açık"),
    "LUB-07": ("met", "6.3-6.6 min at 75% MCP with the emergency mist, by analysis (3.2)",
               "acil sisle %75 MCP'de 6,3-6,6 dk, analizle (3.2)"),
    "PIF-03": ("met", "counterweight feathering, by design (3.7)", "karşı ağırlıkla tüyleme, tasarımla (3.7)"),
    "CTL-04": ("open", "new in 3.7: thrust floor 1.5 kN and limp mode 3.0 kN, FADEC owner",
               "3.7'de yeni: itki tabanı 1,5 kN ve topal mod 3,0 kN, sahibi FADEC"),
    "CTL-03": ("partial", "indicators FM4, NA4, ENV and log-normal thresholds set on a synthetic signal (3.10); baselines in RT-09 / ET-03",
               "FM4, NA4, ENV göstergeleri ve log-normal eşikler sentetik sinyalde kuruldu (3.10); temel kayıtlar RT-09 / ET-03'te"),
    "MNT-01": ("partial", "target 8 h TBR set; standard-time estimate 7.3 h (3.10); timed in MD-01",
               "8 sa TBR hedefi kondu; standart zaman tahmini 7,3 sa (3.10); MD-01'de ölçülecek"),
    "MNT-02": ("met", "borescope line of sight to both meshes and line access to the service points shown (3.10); confirmed in MD-01",
               "iki kavramaya boroskop görüş hattı ve servis noktalarına hat erişimi gösterildi (3.10); MD-01'de doğrulanacak"),
}
NEW = {  # Phase 3 requirements not in v3
    "SYS-11": ("SYS", "Input drive mass", "Giriş tahriki kütlesi", "A;I"),
    "STR-11": ("STR", "Loaded transmission error", "Yüklü iletim hatası", "A;T"),
    "CTL-04": ("CTL", "Thrust floor and limp mode", "İtki tabanı ve topal mod", "A;T"),
}


def main():
    req = list(csv.DictReader(open(os.path.join(HERE, "requirements_v3.csv"), encoding="utf-8")))
    cdr = {r["id"]: r for r in csv.DictReader(open(os.path.join(HERE, "compliance_cdr.csv"), encoding="utf-8"))}
    steps = {}
    for c in csv.DictReader(open(os.path.join(HERE, "changes_phase3.csv"), encoding="utf-8")):
        steps.setdefault(c["id"], [])
        if c["step"] not in steps[c["id"]]:
            steps[c["id"]].append(c["step"])
    rows = [(r["id"], r["group"], r["title_en"], r["title_tr"], r["verification"]) for r in req]
    rows += [(k, v[0], v[1], v[2], v[3]) for k, v in NEW.items()]
    ids = {r[0] for r in rows}

    by_req = {}
    for t in TESTS:
        for q in t[9].split(";"):
            if q not in ids:
                sys.exit(f"{t[0]} traces to unknown requirement {q}")
            by_req.setdefault(q, []).append(t[0])

    with open(os.path.join(HERE, "test_plan_v1.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["id", "sequence", "level_en", "level_tr", "name_en", "name_tr", "rule", "article", "measured",
                    "pass_criterion_en", "pass_criterion_tr", "requirements", "measuring_points"])
        for t in sorted(TESTS, key=lambda t: (t[1], t[0])):
            mps = ";".join(c[0] for c in CELL if t[0] in c[6].split(";"))
            w.writerow([t[0], t[1], t[2], LEVEL_TR[t[2]], t[3], t[4], t[5], t[6], t[7], t[8], PASS_TR[t[0]], t[9], mps])

    with open(os.path.join(HERE, "test_cell_v1.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["id", "location_en", "location_tr", "quantity", "sensor", "rate", "tests"])
        w.writerows(CELL)
    tids = {t[0] for t in TESTS}
    for c in CELL:
        for q in c[6].split(";"):
            if q not in tids:
                sys.exit(f"{c[0]} names unknown test {q}")
    for t in TESTS:
        if t[2] == "engine" and not any(t[0] in c[6].split(";") for c in CELL):
            sys.exit(f"engine test {t[0]} has no measuring point")

    missing, out = [], []
    for rid, grp, ten, ttr, ver in rows:
        methods = ver.split(";")
        tests = by_req.get(rid, [])
        if "T" in methods and not tests:
            missing.append(rid)
        c = cdr.get(rid, {})
        status, note_en, note_tr = P3.get(rid, (c.get("verdict", "new"), "", ""))
        ev_en = note_en or c.get("evidence_en", "")
        ev_tr = note_tr or c.get("evidence_tr", "")
        out.append([rid, grp, ten, ttr, ver, ";".join(tests), status, ev_en, ev_tr,
                    ";".join(steps.get(rid, [])) or "-"])
    with open(os.path.join(HERE, "verification_v1.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["id", "group", "title_en", "title_tr", "methods", "planned_tests", "status_after_phase3",
                    "evidence_en", "evidence_tr", "phase3_steps"])
        w.writerows(out)

    n_t = sum("T" in r[4].split(";") for r in rows)
    counts = {}
    for r in out:
        counts[r[6]] = counts.get(r[6], 0) + 1
    print(f"{len(rows)} requirements, {n_t} with T, {len(TESTS)} planned tests; status {counts}")
    if missing:
        sys.exit(f"requirements with T but no planned test: {missing}")
    print(f"{len(CELL)} test cell measuring points")
    print("check passed: every T requirement has a planned test; every test traces to a requirement; "
          "every engine test has measuring points")


if __name__ == "__main__":
    main()
