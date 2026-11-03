"""Write requirements version 4 and the final compliance matrix (end of Phase 3).

    python requirements/make_v4.py        (then: python requirements/check_requirements.py)

Version 4 is version 3 with the requirement changes that Phase 3 (steps 3.1 to 3.12) decided or found, as
logged in changes_phase3.csv. Only rows that change a requirement itself (its text, type or status, or a new
requirement) are folded in here, with their text in Turkish and English; the log rows that record a
compliance result, a derived design value or a design change stay in the log and reach compliance_final.csv
as evidence. compliance_final.csv gives, for every v4 requirement, the verdict and evidence after Phase 3
(from verification_v1.csv of step 3.11) and how it is closed: shown (by analysis, inspection or design),
test (a planned test or demonstration of test_plan_v1.csv) or ICD (an interface value in icd_v1.csv; open
until the partner gives it). The script also repairs two rows of changes_phase3.csv whose decision field had
an unquoted comma. Source: Phase 3 report, "Requirements v4".
"""
import csv
from pathlib import Path

HERE = Path(__file__).parent

# ------------------------------------------------------------------ changes to v3 requirements
# id -> {column: new value}; only the columns that change. src_* is appended to the source columns.
CHANGES = {
    "SYS-06": {
        "status": "TBR",
        "text_tr": "RGB'nin kuru kütlesi (pervane mili ve aksesuar tahrikleri dahil, aksesuarlar hariç) 110 kg'ı geçmemeli (TBR).",
        "text_en": "RGB dry mass, including the propeller shaft and accessory drives but not the accessories, shall not exceed 110 kg (TBR).",
        "src_tr": "Faz 3 adım 3.1 (Hamit'in kararı)",
        "src_en": "Phase 3 step 3.1 (Hamit's decision)",
    },
    "LUB-01": {
        "text_tr": "Sistem yalnız MIL-PRF-23699 (Tip II) yağla çalışmalı; soğuk üslerde yer ön ısıtması kullanılır (A-08).",
        "text_en": "The system shall run on MIL-PRF-23699 (Type II) oil only; cold bases use ground preheat (A-08).",
        "src_tr": "Faz 3 adım 3.3 (Hamit'in kararı)",
        "src_en": "Phase 3 step 3.3 (Hamit's decision)",
    },
    "LUB-02": {
        "text_tr": "RGB, yağ giriş sıcaklığı sürekli 132 °C'ye ve 15 dakikaya kadar 149 °C'ye çıkarken çalışabilmeli ve MIL-PRF-23699 (Tip II) yağla −40 °C'de soğuk çalıştırma yapılabilmeli.",
        "text_en": "The RGB shall run with oil inlet temperature up to 132 °C continuous and 149 °C for up to 15 min, and allow cold starts at −40 °C with MIL-PRF-23699 (Type II) oil.",
        "src_tr": "Faz 3 adım 3.3 (Hamit'in kararı)",
        "src_en": "Phase 3 step 3.3 (Hamit's decision)",
    },
    "LUB-06": {
        "text_tr": "RGB'nin yağ tankında en az %10 genleşme hacmi, havalandırma ve miktar göstergesi olmalı; kullanılabilir yağ en uzun görev (30 saat) artı yedek için yetmeli. Tüyleme yedeği gerekmez: pervane karşı ağırlıklarla tüyler (PIF-03).",
        "text_en": "The RGB oil tank shall have at least 10% expansion space, venting and a quantity indicator; usable oil shall last the longest mission (30 h) plus reserve. No feathering reserve is needed: the propeller feathers on counterweights (PIF-03).",
        "src_tr": "Faz 3 adım 3.7",
        "src_en": "Phase 3 step 3.7",
    },
    "LUB-07": {
        "type": "shall",
        "text_tr": "RGB, yağ basıncının tamamen kaybından sonra acil hava-yağ sisi sistemiyle azami sürekli gücün %75'inde en az 6 dakika çalışmalı; düşük yağ basıncı anahtarı sis valfini açmalı ve FADEC'e %75 güç sınırı göndermeli.",
        "text_en": "The RGB shall run for at least 6 min at 75% of maximum continuous power after a total loss of oil pressure, using an emergency air-oil mist system; a low-oil-pressure switch opens the mist valve and sends a 75% power limit to the FADEC.",
        "src_tr": "Faz 3 adım 3.2 (Hamit'in kararı)",
        "src_en": "Phase 3 step 3.2 (Hamit's decision)",
    },
    "DYN-04": {
        "text_tr": "Dişli kavrama frekansları ve harmonikleri, çalışma aralığında dişli gövdelerinin ve jantlarının doğal frekanslarından en az %10 ayrık olmalı; bunun sağlanamadığı bir dişli gövdesi, DYN-03 payını belirleyen ve sönümleyicinin kaydığı mod aileleri için (en kötü durumda genlik oranı s ≤ 0,6) testle gösterilmiş bir sönümle (sönüm halkası) donatılmalı; diğer aileler, sabit ve devir başına bir gerilmelerle DYN-03 Goodman katsayısına göre kabul edilir. Kavrama bantlarında modları sık olan RGB gövde panellerinde ise kavrama uyarısına zorlanmış titreşim cevabı, titreşim gerilmelerini DYN-03 sınırının altında tutmalı.",
        "text_en": "Gear mesh frequencies and their harmonics shall be at least 10% away from the natural frequencies of gear webs and rims across the operating range; a gear web where this cannot be met shall have damping shown by test (a damping ring) for the mode families that set its DYN-03 margin and in which the damper slips (amplitude ratio s ≤ 0.6 on the worst bracket); the other families are accepted on the DYN-03 Goodman factor with the steady and once-per-revolution stresses. For RGB housing panels, whose shell modes are dense in the mesh bands, the forced response to the mesh excitation shall keep vibratory stresses below the DYN-03 limit.",
        "src_tr": "Faz 3 adım 3.6",
        "src_en": "Phase 3 step 3.6",
    },
    "SAF-03": {
        "text_tr": "Güç zincirindeki hiçbir mil ya da dişli arızası tehlikeli bir güç türbini aşırı hızına yol açmamalı. Yöntem (PDR'de seçildi): iki bağımsız hız sinyalini (CTL-02) karşılaştırarak kopmayı en geç 20 ms'de algılayan ve yakıt kesme valfini algılamadan sonra en geç 25 ms'de kapatan bir koruma. Güç türbini rotoru, ortaya çıkan tepe hızın 1,05 katında gösterilmeli (τ ≤ 0,1 s ile yaklaşık %130; SAF-06). Koruma, çekirdek güç türbini rotorundan iki bağımsız koruma Np sinyalini ve iki Nr algılayıcısını 2'den 1 kesme mantığıyla kullanmalı ve her çalıştırmada bir bütün olarak kontrol edilmeli; her koruma elemanının ortalama kullanılamazlığı en çok 1,3e-3, yanlış kesme oranı saatte 1e-6'nın altında olmalı (TBR).",
        "text_en": "No shaft or gear failure in the drive chain shall cause a hazardous power turbine overspeed. Means (chosen at the PDR): protection that compares the two independent speed signals (CTL-02), detects a break within 20 ms and closes the fuel shutoff valve within 25 ms of detection. The power turbine rotor shall be shown at 1.05 times the resulting peak speed (about 130% with τ ≤ 0.1 s; SAF-06). The protection shall use two independent protection Np signals from the core power turbine rotor and the two Nr pickups with 1-out-of-2 trip logic and be checked as a whole at each start; each protection element shall have a mean unavailability of at most 1.3e-3 and the spurious trip rate shall stay below 1e-6 per hour (TBR).",
        "src_tr": "Faz 3 adım 3.7",
        "src_en": "Phase 3 step 3.7",
    },
    "PIF-01": {
        "text_tr": "Pervane flanşı müşterinin pervanesine (PT6A-67A sınıfı flanş) uymalı; flanş ölçüleri TBD. Pervane göbeği tutma tüpü P114'ün bağlantısını almalı ve hatve borusunu içinden geçirmeli (pervane üreticisiyle TBD).",
        "text_en": "The propeller flange shall fit the customer's propeller (PT6A-67A class flange); flange dimensions TBD. The propeller hub shall take the anchor of the retention tube P114 and pass the pitch tube through it (TBD with the propeller maker).",
        "src_tr": "Faz 3 adım 3.7",
        "src_en": "Phase 3 step 3.7",
    },
    "PIF-05": {
        "status": "TBR",
        "verification": "A;T",
        "text_tr": "Aşırı sürükleme ya da aşırı hıza karşı pervane koruması (14 CFR 35.15(g)(1)) PCU regülatörüne bağlı olmamalı ve dört katmanı olmalı: PCU'dan bağımsız, test solenoidli bir aşırı hız regülatörü; tek bir arızanın kaldıramayacağı bir uçuş içi düşük hatve durdurucusu; PCU üzerindeki tüyleme solenoidiyle, her çalıştırmada test edilen bir FADEC tüyleme komutu; karşı ağırlıkla tüyleme. Kredilenen her katman pervane üreticisine bir kullanılamazlık bütçesi olarak verilir; her kesim kümesi saatte 1e-8'i geçmemeli (TBR). Aşırı hız regülatörünün ayarı SYS-04'ün %110 sınırının altında kalmalı.",
        "text_en": "The propeller protection against excessive drag or overspeed (14 CFR 35.15(g)(1)) shall not depend on the PCU governor and shall have four layers: an overspeed governor independent of the PCU, with a test solenoid; an in-flight low-pitch stop that no single failure can remove; a FADEC feather command through a feather solenoid on the PCU, tested at each start; and counterweight feathering. Each credited layer is given to the propeller maker as an unavailability budget; each cut set shall not exceed 1e-8 per hour (TBR). The overspeed governor setting shall stay below the 110% limit of SYS-04.",
        "src_tr": "Faz 3 adım 3.7",
        "src_en": "Phase 3 step 3.7",
    },
    "MNT-01": {
        "status": "TBR",
        "text_tr": "RGB, çekirdeğe dokunmadan sökülüp takılabilen ayrı bir modül olmalı; söküm ve takma iki teknisyenle en çok 8 saat sürmeli, pervane sökümü hariç (TBR).",
        "text_en": "The RGB shall be a separate module that can be removed and installed without disturbing the core, in at most 8 h by two technicians, propeller removal not included (TBR).",
        "src_tr": "Faz 3 adım 3.10",
        "src_en": "Phase 3 step 3.10",
    },
}

# ------------------------------------------------------------------ new requirements (inserted after the row named)
NEW = [
    ("SYS-10", {
        "id": "SYS-11", "group": "SYS", "type": "shall",
        "title_tr": "Giriş tahriki kütlesi", "title_en": "Input drive mass",
        "text_tr": "Giriş tahriki (güç türbini çıkış mili, iki kaplini ve mil tüneli) 6 kg'ı geçmemeli (TBR); SYS-06'nın yanında ayrı bir kütle kalemidir ve RGB ile giriş tahrikinin toplamı her zaman raporlanır.",
        "text_en": "The input drive (power turbine output shaft, its two couplings and the shaft tunnel) shall not exceed 6 kg (TBR); it is a mass line of its own beside SYS-06, and the total of RGB and input drive is always reported.",
        "source_tr": "A-09; SYS-06; SYS-10; Faz 3 adım 3.3 (Hamit'in kararı)",
        "source_en": "A-09; SYS-06; SYS-10; Phase 3 step 3.3 (Hamit's decision)",
        "source_type": "cus;asm",
        "rationale_tr": "Kurulum C, güç türbini çıkış milini ve tünelini kapsamımıza alıyor; bunları SYS-06'nın dışında ama ayrı bir sınırla tutmak ikisini de görünür kılıyor (3.3'te 5,46 kg).",
        "rationale_en": "Installation C puts the power turbine output shaft and its tunnel in our scope; keeping them outside SYS-06 but under a limit of their own keeps both visible (5.46 kg in step 3.3).",
        "verification": "A;I", "verification_phase": "P3", "allocation": "shf;hsg", "status": "TBR",
    }),
    ("STR-10", {
        "id": "STR-11", "group": "STR", "type": "shall",
        "title_tr": "Yüklü iletim hatası", "title_en": "Loaded transmission error",
        "text_tr": "Güneş-planet ve planet-halka kavramalarının yüklü iletim hatasının ikinci kavrama harmoniği azami sürekli torkta 0,15 µm'yi geçmemeli (TBR).",
        "text_en": "The second mesh harmonic of the loaded transmission error of the sun-planet and planet-ring meshes at maximum continuous torque shall not exceed 0.15 µm (TBR).",
        "source_tr": "STR-01; DYN-04; Faz 3 adım 3.6",
        "source_en": "STR-01; DYN-04; Phase 3 step 3.6",
        "source_type": "asm",
        "rationale_tr": "3.6, planet ve gövde cevabının ve dinamik diş katsayısının bu harmoniğe bağlı olduğunu gösterdi; 0,15 µm diş dibi güvenliğini 1,55'in üstünde tutuyor. Profil düzeltmesinin yüklü temas analizi ve yüklü iletim hatası testiyle gösterilecek.",
        "rationale_en": "Step 3.6 showed that the planet and case responses and the dynamic tooth factor depend on this harmonic; 0.15 µm keeps the tooth root safety above 1.55. To be shown by a loaded tooth contact analysis of the profile modification and by the loaded transmission error test.",
        "verification": "A;T", "verification_phase": "P3", "allocation": "ger", "status": "TBR",
    }),
    ("CTL-03", {
        "id": "CTL-04", "group": "CTL", "type": "shall",
        "title_tr": "İtki tabanı ve topal mod", "title_en": "Thrust floor and limp mode",
        "text_tr": "Uçuşta FADEC pervane itkisini en az 1,5 kN pozitif tutmalı (TBR); uçuşta negatif itki, beta ya da rüzgârla dönme olmamalı. NJ1024 ya da P116 termokupl uyarısında FADEC yer istasyonuna bildirmeli ve dönüş ve motorlu iniş için itkiyi, tabanı koruyarak 3,0 kN ile sınırlamalı.",
        "text_en": "In flight the FADEC shall hold a positive propeller thrust of at least 1.5 kN (TBR), with no negative thrust, beta or windmilling in flight. On an NJ1024 or P116 thermocouple alert the FADEC shall report to the ground station and cap the thrust at 3.0 kN while keeping the floor, for a return and a powered landing.",
        "source_tr": "SAF-01; Faz 3 adım 3.7",
        "source_en": "SAF-01; Phase 3 step 3.7",
        "source_type": "crt;asm",
        "rationale_tr": "Yedek eksenel yol (NJ1024 kenarı, P116 yakalama dudağı) yalnız pervane çekerken kredi alıyor; itki tabanı onu hizmette yüksüz tutuyor, topal mod da bir QJ1024 arızasından sonra NJ1024'ün değeri içinde tutuyor (3.7).",
        "rationale_en": "The standby axial path (NJ1024 rib, P116 catcher lip) is credited only while the propeller pulls; the thrust floor keeps it unloaded in service and the limp mode keeps it within the NJ1024 rating after a QJ1024 failure (step 3.7).",
        "verification": "A;T", "verification_phase": "P3", "allocation": "sen;pif", "status": "TBR",
    }),
]

# ------------------------------------------------------------------ changes to needs and assumptions
CHANGES_NA = {
    "A-08": {
        "text_tr": "Yağ yalnız MIL-PRF-23699 (Tip II); soğuk üslerde yer ön ısıtması kullanılır.",
        "text_en": "Oil is MIL-PRF-23699 (Type II) only; cold bases use ground preheat.",
        "source_tr": "CT7-9 TCDS; Faz 3 adım 3.3 (Hamit'in kararı)",
        "source_en": "CT7-9 TCDS; Phase 3 step 3.3 (Hamit's decision)",
    },
}

# ------------------------------------------------------------------ evidence of requirements whose text changed in v4
# id -> (verdict, evidence_tr, evidence_en); the others keep the step 3.11 verdict and evidence
EVIDENCE = {
    "LUB-01": ("met",
               "Yalnız MIL-PRF-23699 (3.3'te Hamit'in kararı); bütün hesaplar bu yağla, yağ sınıfı kontrolü calc/interfaces/oil_grade_check.csv dosyasında.",
               "MIL-PRF-23699 only (Hamit's decision in 3.3); every rating uses it, and the oil grade check is in calc/interfaces/oil_grade_check.csv."),
    "LUB-02": ("partial",
               "Dişliler ve yataklar 132 °C yağ girişinde hesaplandı, soğutucu yağı 100 °C'de tutuyor (2.7). −40 °C ilk çalışmada memeler yaklaşık 9 dakikada besleniyor, kalkış gücü yaklaşık 11 °C yağ istiyor (3.2, ICD-31). 15 dakika 149 °C ve soğuk çalıştırma testte (ET-03, ET-08).",
               "Gears and bearings are rated at 132 °C oil inlet and the cooler holds 100 °C (2.7). In a −40 °C start the jets are fed after about 9 min and take-off power needs about 11 °C oil (3.2, ICD-31). 149 °C for 15 min and the cold start are tested (ET-03, ET-08)."),
    "LUB-06": ("met",
               "6,8 L tank (2.7): kullanılabilir yağ ve %10 genleşme hacmi; karşı ağırlıkla tüylemeyle tüyleme yedeği artık gerekmiyor (3.7), yedeksiz tank boyutu gözden geçirmesi 3.9 listesinde.",
               "6.8 L tank (2.7): usable oil and 10% expansion space; with counterweight feathering the feathering reserve is no longer needed (3.7), and a tank-size review without it is on the 3.9 list."),
    "PIF-01": ("tbd",
               "Flanş ölçüleri ve tutma tüpü P114'ün göbekteki bağlantısı pervane üreticisinden gelecek (ICD-14); CATIA modelinde yer tutucu flanş var.",
               "The flange dimensions and the hub anchor of the retention tube P114 come from the propeller maker (ICD-14); the CATIA model has a placeholder flange."),
    "PIF-05": ("partial",
               "3.7'de dört koruma katmanı ve kullanılamazlık bütçeleriyle yeniden yazıldı: bütün tehlikeli etkiler saatte 2,9e-8, sınır 1e-7 (3.7). Aşırı hız regülatörü ayarı ve katman bütçeleri pervane üreticisine gidiyor (ICD-13).",
               "Rewritten in 3.7 as four protection layers with unavailability budgets: all hazardous effects 2.9e-8 per hour against 1e-7 (3.7). The overspeed governor setting and the layer budgets go to the propeller maker (ICD-13)."),
    "DYN-04": ("partial",
               "Planet modları tam yay tensörleriyle 3.309 / 4.008 / 6.658 / 7.370 Hz (3.6, 2.8'i düzeltiyor); bantlardan ayrım sağlanmıyor, kabul dinamik diş kuvvetine dayanıyor (S_F en az 1,55, STR-11 ile). Birinci kademe dişli gövdesi: kayan aileler için 8 x 4 mm sönüm halkası, diğerleri DYN-03 Goodman katsayısıyla. Gövde panelleri DYN-03 içinde (3.6). Sönümlenme testi RT-04'te.",
               "Planet modes with exact spring tensors 3,309 / 4,008 / 6,658 / 7,370 Hz (3.6, corrects 2.8); separation is not met in the bands and acceptance rests on the dynamic tooth force (S_F at least 1.55 with STR-11). First-stage gear web: an 8 x 4 mm damping ring for the slipping families, the others on the DYN-03 Goodman factor. Housing panels within DYN-03 (3.6). Ring-down test in RT-04."),
}

CLOSURE = {"shown": ("shown by analysis, inspection or design", "analiz, inceleme ya da tasarımla gösterildi"),
           "test": ("test or demonstration planned", "test ya da gösterim planlı"),
           "ICD": ("interface value in the ICD", "ICD'de arayüz değeri"),
           "open": ("open", "açık")}


def read(name):
    with open(HERE / name, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def write(name, fields, rows):
    with open(HERE / name, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)


def repair_log():
    """Quote the decision field of the two LUB-07 rows that an unquoted comma split into two columns."""
    path = HERE / "changes_phase3.csv"
    with open(path, encoding="utf-8", newline="") as f:
        rows = list(csv.reader(f))
    fixed = 0
    for r in rows[1:]:
        if len(r) == 10:
            r[6:8] = [r[6] + "," + r[7]]
            fixed += 1
    if fixed:
        with open(path, "w", encoding="utf-8", newline="") as f:
            csv.writer(f).writerows(rows)
    return fixed


def main():
    fixed = repair_log()
    v3 = read("requirements_v3.csv")
    fields = [c if c != "v3_change" else "v4_change" for c in v3[0].keys()]
    out = []
    for r in v3:
        row = {k if k != "v3_change" else "v4_change": v for k, v in r.items()}
        row["v4_change"] = ""
        ch = CHANGES.get(r["id"])
        if ch:
            for k, v in ch.items():
                if k == "src_tr":
                    row["source_tr"] = r["source_tr"] + "; " + v
                elif k == "src_en":
                    row["source_en"] = r["source_en"] + "; " + v
                else:
                    row[k] = v
            row["v4_change"] = "changed"
        out.append(row)
        for after, new in NEW:
            if after == r["id"]:
                nrow = dict.fromkeys(fields, "")
                nrow.update(new)
                nrow["v4_change"] = "new"
                out.append(nrow)
    write("requirements_v4.csv", fields, out)

    na = read("needs_assumptions_v3.csv")
    nfields = [c if c != "v3_change" else "v4_change" for c in na[0].keys()]
    nout = []
    for r in na:
        row = {k if k != "v3_change" else "v4_change": v for k, v in r.items()}
        row["v4_change"] = ""
        if r["id"] in CHANGES_NA:
            row.update(CHANGES_NA[r["id"]])
            row["v4_change"] = "changed"
        nout.append(row)
    write("needs_assumptions_v4.csv", nfields, nout)

    # final compliance: verdict and evidence from step 3.11, closure from the methods, tests and the ICD
    ver = {r["id"]: r for r in read("verification_v1.csv")}
    icd = {}
    for r in read("icd_v1.csv"):
        for q in r["requirement"].replace(",", ";").split(";"):
            q = q.strip()
            if q and q != "-":
                icd.setdefault(q, []).append(r["id"])
    comp = []
    for r in out:
        v = dict(ver[r["id"]])
        if r["id"] in EVIDENCE:
            v["status_after_phase3"], v["evidence_tr"], v["evidence_en"] = EVIDENCE[r["id"]]
        methods = r["verification"].split(";")
        close = []
        if v["status_after_phase3"] == "met" and not ({"T", "D"} & set(methods)):
            close.append("shown")
        if v["planned_tests"]:
            close.append("test")
        if r["id"] in icd and v["status_after_phase3"] != "met":
            close.append("ICD")
        if not close:
            close.append("open")
        comp.append({"id": r["id"], "verdict": v["status_after_phase3"],
                     "evidence_tr": v["evidence_tr"], "evidence_en": v["evidence_en"],
                     "closure": ";".join(close),
                     "closure_en": "; ".join(CLOSURE[c][0] for c in close),
                     "closure_tr": "; ".join(CLOSURE[c][1] for c in close),
                     "planned_tests": v["planned_tests"], "icd_items": ";".join(icd.get(r["id"], [])),
                     "status_v4": r["status"]})
    write("compliance_final.csv", list(comp[0].keys()), comp)

    n_ch = sum(r["v4_change"] == "changed" for r in out)
    n_new = sum(r["v4_change"] == "new" for r in out)
    verdicts, closes = {}, {}
    for c in comp:
        verdicts[c["verdict"]] = verdicts.get(c["verdict"], 0) + 1
        for k in c["closure"].split(";"):
            closes[k] = closes.get(k, 0) + 1
    print(f"requirements_v4.csv: {len(out)} requirements ({n_ch} changed, {n_new} new); "
          f"needs_assumptions_v4.csv: {sum(r['v4_change'] == 'changed' for r in nout)} changed")
    print(f"compliance_final.csv: verdicts {verdicts}; closure {closes}")
    if fixed:
        print(f"changes_phase3.csv: {fixed} rows repaired")


if __name__ == "__main__":
    main()
