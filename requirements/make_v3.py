"""Write requirements version 3 and the compliance matrix at the critical design review (CDR).

    python requirements/make_v3.py        (then: python requirements/check_requirements.py)

Version 3 is version 2 with the changes that Phase 2 (detail design, steps 2.1 to 2.11) decided or found;
each change is listed here with its new text in Turkish and English, and compliance_cdr.csv gives the
Phase 2 status of every v3 requirement with its evidence. The files are generated from this script so
that the changes stay reviewable in one place. Source: Phase 2 report, Section 2.11.
"""
import csv
from pathlib import Path

HERE = Path(__file__).parent

# ------------------------------------------------------------------ changes to v2 requirements
# id -> {column: new value}; only the columns that change
CHANGES = {
    "SYS-10": {
        "status": "TBR",
        "text_tr": "Kurulum C'de güç türbini çıkış mili egzoz kanalının içinden RGB'ye geçer; mil tüneli, soğutması ve egzoz kanalına bağlantısı bizim kapsamımızdadır. Yüzer mil diyaframdan diyaframa en fazla 0,60 m olmalı (adım 2.2); egzoz kanalının ölçüleri ve gaz sıcaklıkları çekirdek üreticisiyle belirlenir (TBR).",
        "text_en": "In installation C the power turbine output shaft passes through the exhaust duct to the RGB; the shaft tunnel, its cooling and the attachment to the exhaust duct are in our scope. The floating shaft shall be at most 0.60 m from diaphragm to diaphragm (step 2.2); the exhaust duct dimensions and gas temperatures are agreed with the core maker (TBR).",
        "source_tr": "A-02; A-09; Faz 1 adım 1.1; Faz 2 adım 2.2",
        "source_en": "A-02; A-09; Phase 1 step 1.1; Phase 2 step 2.2",
    },
    "LD-08": {
        "status": "TBR",
        "text_tr": "RGB, çekirdek ya da güç türbini sıkışarak aniden durduğunda pervane ataletinin doğurduğu tork darbesine dayanmalı. Faz 2 tasarımında dişliler pervanede 24.386 N·m taşıyabildiği için güç türbininin durma süresi en az 0,22 s olmalı; bu, çekirdek üreticisine bir arayüz koşuludur. 0,76 s ve üstünde tork LD-01 içinde kalır.",
        "text_en": "The RGB shall withstand the torque spike from the propeller inertia when the core or power turbine seizes suddenly. In the Phase 2 design the gears can take 24,386 N·m at the propeller, so the power turbine shall take at least 0.22 s to stop; this is an interface condition on the core maker. At 0.76 s or more the torque stays within LD-01.",
        "source_tr": "STANAG 4671 USAR.361(b)(1); A-04; Faz 2 adım 2.3, 2.4, 2.5",
        "source_en": "STANAG 4671 USAR.361(b)(1); A-04; Phase 2 steps 2.3, 2.4, 2.5",
    },
    "DYN-04": {
        "text_tr": "Dişli kavrama frekansları ve harmonikleri, çalışma aralığında dişli gövdelerinin ve jantlarının doğal frekanslarından en az %10 ayrık olmalı; bunun sağlanamadığı bir dişli gövdesi, testle gösterilmiş bir sönümle (sönüm halkası) donatılmalı. Kavrama bantlarında modları sık olan RGB gövde panellerinde ise kavrama uyarısına zorlanmış titreşim cevabı, titreşim gerilmelerini DYN-03 sınırının altında tutmalı.",
        "text_en": "Gear mesh frequencies and their harmonics shall be at least 10% away from the natural frequencies of gear webs and rims across the operating range; a gear web where this cannot be met shall have damping shown by test (a damping ring). For RGB housing panels, whose shell modes are dense in the mesh bands, the forced response to the mesh excitation shall keep vibratory stresses below the DYN-03 limit.",
        "source_tr": "CS-E 650; tasarım pratiği; Faz 2 adım 2.4, 2.8",
        "source_en": "CS-E 650; design practice; Phase 2 steps 2.4, 2.8",
        "rationale_tr": "2.8'in sonlu eleman modeli, döküm gövdenin kabuk modlarının kavrama bantlarında çok sık olduğunu ve birinci kademe dişlisinin gövdesinde bant içi modlardan kaçınılamadığını gösterdi; %10 ayrım dişli jant ve gövdelerinde hedef olarak kalıyor, sağlanamadığı yerde ölçüt sönüm ve cevap.",
        "rationale_en": "The step 2.8 finite element model showed that the shell modes of a cast case are dense in the mesh bands and that in-band modes of the first-stage gear web cannot be avoided; the 10% separation stays the target for gear rims and webs, and where it cannot be met the criterion is damping and response.",
        "verification": "A;T",
        "verification_phase": "P2;P3",
    },
    "STR-02": {
        "text_tr": "Ana yatakların ve planet yataklarının ISO 281 değiştirilmiş anma ömrü (L10m, a_ISO ile, yağ temizliği dahil) görev yük spektrumunda (A-05) en az 3 × TBO = 12.000 saat olmalı; planet yatağının yükü planetin merkezkaç kuvvetini de içermeli ve yük paylaşım katsayısının P90 değeriyle (K_γ), yatakta 110 °C yağla hesaplanmalı. Sınır yüklerde statik güvenlik s0 ≥ 2. Tam dolu makaralı planet yatağının hız sınırı yatak üreticisiyle doğrulanmalı.",
        "text_en": "Main bearings and planet bearings shall have an ISO 281 modified rating life (L10m with a_ISO, including oil cleanliness) of at least 3 × TBO = 12,000 h over the mission load spectrum (A-05); the planet bearing load shall include the planet's centrifugal force and be computed with the P90 value of the load sharing factor (K_γ) and 110 °C oil at the bearing. Static safety s0 ≥ 2 at limit loads. The speed limit of the full-complement planet bearing shall be confirmed with the bearing maker.",
        "source_tr": "A-05; A-06; STR-05; Faz 1 adım 1.2 ve 1.3; Faz 2 adım 2.5",
        "source_en": "A-05; A-06; STR-05; Phase 1 steps 1.2 and 1.3; Phase 2 step 2.5",
    },
    "STR-04": {
        "status": "TBR",
        "text_tr": "RGB gövdesi tüm pervane yüklerini motor bağlantılarına iletmeli. Her pervane yatağı yuvasının radyal direngenliği, cıvatalı bağlantı dahil, her yönde en az 5×10⁷ N/m olmalı (DYN-05; tasarım hedefi 2×10⁸ N/m); azami sürekli yükte gövdenin şekil değiştirmesi dişli eksen kaçıklığını dişli hesaplarının K_Hβ kabulü içinde tutmalı.",
        "text_en": "The RGB housing shall carry all propeller loads to the engine mounts. The radial stiffness of each propeller bearing seat, bolted attachment included, shall be at least 5×10⁷ N/m in every direction (DYN-05; design target 2×10⁸ N/m); at maximum continuous load the housing deflection shall keep gear misalignment within the K_Hβ assumption of the gear ratings.",
        "source_tr": "LD grubu; STR-01; DYN-05; Faz 2 adım 2.1, 2.8",
        "source_en": "LD group; STR-01; DYN-05; Phase 2 steps 2.1, 2.8",
    },
    "STR-07": {
        "text_tr": "Planet kademesinin güneşi yüzer, halkası esnek olmalı ve halka jantı en az 3,5 × modül kalınlığında olmalı; taşıyıcı pim konumu 0,010 mm, planetler eşleştirilmiş takım (diş kalınlığı ±3 µm) olmalı. 2.4'ün Monte Carlo modelinden çıkan yük paylaşım katsayısı K_γ (P99) 1,35'i aşmamalı ve dişli hesapları bu değeri kullanmalı.",
        "text_en": "The planetary stage shall have a floating sun and a flexible ring with a rim at least 3.5 × module thick; the carrier pin position tolerance shall be 0.010 mm and the planets a matched set (tooth thickness ±3 µm). The load sharing factor K_γ (P99) from the Monte Carlo model of step 2.4 shall not exceed 1.35, and the gear ratings shall use it.",
        "source_tr": "STR-01; Faz 1 adım 1.3; AGMA 6123; Faz 2 adım 2.4, 2.5",
        "source_en": "STR-01; Phase 1 step 1.3; AGMA 6123; Phase 2 steps 2.4, 2.5",
        "rationale_tr": "Faz 1'in 1,15 kabulü, toleransları içeren Monte Carlo modelinde 1,32–1,34 çıktı; dişliler ve yataklar bu değerle hesaplandı ve gereksinimleri sağlıyor, bu yüzden sınır 1,35'e çekildi ve toleranslar gereksinime yazıldı.",
        "rationale_en": "The 1.15 assumed in Phase 1 came out at 1.32–1.34 in the Monte Carlo model with the tolerances; the gears and bearings were rated with that value and meet their requirements, so the limit moves to 1.35 and the tolerances are written into the requirement.",
    },
    "STR-09": {
        "status": "Agreed",
        "title_tr": "Diş yüzeyi pürüzlülüğü (süper bitirme)",
        "title_en": "Flank roughness (superfinishing)",
        "text_tr": "Bütün dişlilerin diş yüzeyleri süper bitirmeyle Ra ≤ 0,15 µm (Rz ≤ 0,8 µm) olmalı.",
        "text_en": "All gear flanks shall be superfinished to Ra ≤ 0.15 µm (Rz ≤ 0.8 µm).",
        "source_tr": "SYS-05; STR-01; Faz 1 adım 1.4; Faz 2 adım 2.4 (Karar 1)",
        "source_en": "SYS-05; STR-01; Phase 1 step 1.4; Phase 2 step 2.4 (Decision 1)",
        "rationale_tr": "Taşlanmış yüzeyle planet kademesinin pitting güvenliği 1,19'da kalıyordu (STR-01: 1,2); süper bitirme bunu ve kavrama kayıplarını (SYS-05) iyileştiriyor. Hamit'in 1. kararı.",
        "rationale_en": "With ground flanks the pitting safety of the planetary stage stayed at 1.19 (STR-01: 1.2); superfinishing improves it and the mesh losses (SYS-05). Hamit's Decision 1.",
    },
    "LUB-02": {
        "text_tr": "RGB, yağ giriş sıcaklığı sürekli 132 °C'ye ve 15 dakikaya kadar 149 °C'ye çıkarken çalışabilmeli; −40 °C'de (Tip II yağ) ve −54 °C'de (Tip I yağ) soğuk çalıştırma yapılabilmeli. MIL-PRF-7808 (Tip I) yağla yağ giriş sıcaklığı 105 °C'yi geçmemeli (dişli sıvanma payı, Karar 2).",
        "text_en": "The RGB shall run with oil inlet temperature up to 132 °C continuous and 149 °C for up to 15 min, and allow cold starts at −40 °C (Type II oil) and −54 °C (Type I oil). With MIL-PRF-7808 (Type I) oil the oil inlet temperature shall not exceed 105 °C (gear scuffing margin, Decision 2).",
        "source_tr": "CT7-9 TCDS; LUB-01; Faz 2 adım 2.4 (Karar 2)",
        "source_en": "CT7-9 TCDS; LUB-01; Phase 2 step 2.4 (Decision 2)",
    },
    "LUB-09": {
        "status": "Agreed",
        "text_tr": "Hava-yağ soğutucusunun soğutma havası (53 °C'lik günde yaklaşık 0,72 kg/s) yerde ve düşük hızda elektrikli bir fandan, uçuşta dinamik hava basıncından (ram) sağlanmalı (Karar 5).",
        "text_en": "The cooling air of the air–oil cooler (about 0.72 kg/s on a 53 °C day) shall come from an electric fan on the ground and at low speed and from ram air in flight (Decision 5).",
        "source_tr": "LUB-04; ENV-01; Faz 1 adım 1.4; Faz 2 adım 2.7 (Karar 5)",
        "source_en": "LUB-04; ENV-01; Phase 1 step 1.4; Phase 2 step 2.7 (Decision 5)",
    },
    "CTL-03": {
        "status": "TBR",
        "text_tr": "Talaş dedektörü, yağ kalıntısı izleyicisi, yağ basıncı, yağ sıcaklığı ve filtre tıkanma uyarısı sinyalleri motor ve uçak izleme sistemine verilmeli. Durum izleme için RGB'de üç ivmeölçer olmalı: halka dişlinin üzerindeki gövde duvarında, dış pervane yatağı göbeğinde (yerleri adım 2.10'dan) ve birinci kademe gövdesinde giriş pinyonu yataklarının yanında; ana emme hattında bir yağ kalıntısı izleyicisi olmalı. CTL-02'nin hız sinyalleriyle her milin zaman eşzamanlı ortalaması alınmalı; durum göstergeleri ve uyarı eşikleri adım 2.10'un arıza frekansları tablosundan belirlenmeli (TBR).",
        "text_en": "Chip detector, oil debris monitor, oil pressure, oil temperature and filter impending-bypass signals shall go to the engine and aircraft monitoring system. For condition monitoring the RGB shall carry three accelerometers: on the case wall over the ring gear, on the outer propeller bearing boss (positions from step 2.10) and on the first-stage case next to the input pinion bearings; and an inline oil debris monitor in the main scavenge line. With the CTL-02 speed signals each shaft shall be time-synchronously averaged; condition indicators and alert thresholds shall come from the step 2.10 fault frequency table (TBR).",
        "source_tr": "CS-E 570; N-07; LUB-05; Faz 2 adım 2.10 (Karar 7)",
        "source_en": "CS-E 570; N-07; LUB-05; Phase 2 step 2.10 (Decision 7)",
        "verification": "A;I;T",
        "verification_phase": "P2;P3",
    },
    "MNT-02": {
        "text_tr": "Talaş dedektörleri, yağ kalıntısı izleyicisi, filtre, yağ doldurma ve seviye kontrolü, yağ analizi numune noktası ve sensörler RGB sökülmeden erişilebilir olmalı. Planet kademesinde halka-planet kavramasını ve birinci kademede pinyon-dişli kavramasını gösteren birer boroskop deliği olmalı.",
        "text_en": "Chip detectors, the oil debris monitor, filter, oil filling and level check, the oil sampling point and the sensors shall be reachable without removing the RGB. Borescope ports shall give a view of the ring-planet meshes of the planetary stage and of the pinion-gear mesh of the first stage.",
        "source_tr": "N-07; yol haritası (bakım odaklı tasarım); Faz 2 adım 2.10 (Karar 7)",
        "source_en": "N-07; roadmap (maintenance-focused design); Phase 2 step 2.10 (Decision 7)",
        "rationale_tr": "Karar 7 (bakım odaklı tasarım) boroskop erişimini ve yağ numunesini hedeften zorunluluğa çevirdi: durum izleme bir uyarı verdiğinde dişliler RGB sökülmeden görülebilmeli.",
        "rationale_en": "Decision 7 (maintenance-driven design) turned borescope access and oil sampling from goals into requirements: when condition monitoring raises an alert, the gears must be inspectable without removing the RGB.",
    },
    "ACC-01": {
        "text_tr": "Marş-jeneratör pedi çekirdek tedarikçisinin gaz üreteci tahrikli AGB'sinde kalır; bu bir arayüz gereksinimidir: ped hızı Ng'nin 0,2663 katı (CT7-9'daki gibi), marş torku gaz üretecini (≈0,060 kg·m²) TBD saniyede kendini sürdürme hızına çıkarmalı. T700'ün diğer AGB pedleri olduğu gibi kalıyor.",
        "text_en": "The starter-generator pad stays on the core supplier's gas-generator-driven AGB; this is an interface requirement: pad speed 0.2663 × Ng (as on the CT7-9), and the starting torque shall bring the gas generator (≈0.060 kg·m²) to self-sustaining speed within TBD s. The other T700 AGB pads stay as they are.",
        "source_tr": "N-06; CT7-9 TCDS; NASA TM-100991; A-02; Faz 2 adım 2.6",
        "source_en": "N-06; CT7-9 TCDS; NASA TM-100991; A-02; Phase 2 step 2.6",
    },
}

# ------------------------------------------------------------------ new requirements
NEW = [
    {
        "id": "STR-10", "group": "STR", "type": "shall",
        "title_tr": "Gövde dökümü", "title_en": "Housing casting",
        "text_tr": "RGB planet gövdesi A357-T6 alüminyum kum dökümü olmalı (Karar 6). Döküm gövdelerde sınır ve nihai yük gerilmeleri 1,25 döküm katsayısıyla değerlendirilmeli: sınır yükte gerilme × 1,25 ≤ akma, nihai yükte (1,5 × sınır) gerilme × 1,25 ≤ çekme dayanımı. Kritik bölgelerin radyografik muayene sınıfı TBR.",
        "text_en": "The RGB planetary case shall be an A357-T6 aluminium sand casting (Decision 6). Stresses in cast housings shall be assessed with a casting factor of 1.25: limit-load stress × 1.25 ≤ yield, ultimate-load (1.5 × limit) stress × 1.25 ≤ tensile strength. The radiographic inspection class of the critical areas is TBR.",
        "source_tr": "STR-04; LD-05; Faz 2 adım 2.8 (Karar 6)",
        "source_en": "STR-04; LD-05; Phase 2 step 2.8 (Decision 6)",
        "source_type": "asm",
        "rationale_tr": "Magnezyum (WE43-T6) gövde 3,4 kg daha hafifti ama cıvatalı bağlantı açıldığında yuva direngenliği alt sınırın altına düşüyor ve döküm katsayısıyla gerilme sınırını aşıyordu.",
        "rationale_en": "A magnesium (WE43-T6) case was 3.4 kg lighter, but with an opened bolted joint its seat stiffness fell below the floor and its stress exceeded the limit with the casting factor.",
        "verification": "A;I", "verification_phase": "P2;P3", "allocation": "hsg", "status": "Agreed",
    },
]

# ------------------------------------------------------------------ compliance at the CDR: id -> (verdict, tr, en)
CDR = {
    "SYS-01": ("met", "RGB'nin dişlileri, milleri ve yatakları (2.4–2.6) ve güç türbini çıkış mili ile diyafram kaplinleri (2.2) 895 kW için gösterildi. Güç ve verim testi Faz 3'te.",
               "The RGB gears, shafts and bearings (2.4–2.6) and the power turbine output shaft with its diaphragm couplings (2.2) are shown at 895 kW. Power and efficiency test in Phase 3."),
    "SYS-02": ("met", "i = 12,932: hata −%0,07 (sınır ±%0,5); Faz 2'de diş sayıları değişmedi.",
               "i = 12.932: error −0.07% (limit ±0.5%); the tooth numbers did not change in Phase 2."),
    "SYS-03": ("partial", "Bütün dinamik kontroller (DYN-01, DYN-02, DYN-04, DYN-05) %90–101 aralığında yapıldı; aralıkta çalışma Faz 3 testinde gösterilecek.",
               "All dynamic checks (DYN-01, DYN-02, DYN-04, DYN-05) used the 90–101% range; running over it is shown in the Phase 3 test."),
    "SYS-04": ("partial", "%110'da birinci kademe çevre hızı 81 m/s (STR-08), güç türbini milinin mil kopmasındaki tepe hızda çevresel gerilmesi 152,6 MPa. Tam dolu makaralı planet yatağı %110'da benzer katalog yatağının hız sınırında (6.000 rpm): yatak üreticisiyle doğrulanacak.",
               "At 110% the first-stage pitch-line velocity is 81 m/s (STR-08) and the hoop stress of the power turbine shaft at the post-break peak speed 152.6 MPa. The full-complement planet bearing runs at the speed limit of a similar catalogue bearing (6,000 rpm) at 110%: to be confirmed with the bearing maker."),
    "SYS-05": ("met", "Azami sürekli güçte kayıplar 12,39 kW (sınır 13,6 kW, verim %98,71); süper bitirme koşuluyla (STR-09). Verim testi Faz 3'te.",
               "Losses at maximum continuous power 12.39 kW (limit 13.6 kW, efficiency 98.71%), with superfinishing (STR-09). Efficiency test in Phase 3."),
    "SYS-06": ("met", "PDR kütlesi 77,6 kg; Faz 2 değişiklikleri: pervane mili 120/100 mm +3,0 kg, planet kademesi +3,5 kg, titanyum tutma borusu +3,6 kg, aksesuar tahrikleri +1,5 kg, konik burunlu gövde +1,1 kg; tahmin yaklaşık 90 kg (sınır 100 kg). CATIA kütle toplaması Faz 3'te.",
               "PDR mass 77.6 kg; Phase 2 changes: propeller shaft 120/100 mm +3.0 kg, planetary stage +3.5 kg, titanium retention tube +3.6 kg, accessory drives +1.5 kg, conical-nose case +1.1 kg; estimate about 90 kg (limit 100 kg). CATIA mass roll-up in Phase 3."),
    "SYS-07": ("tbd", "Temel tasarımda pervane güç türbininin tersine dönüyor; diğer yön iki avara dişliyle (eksen kaçıklığı en az 153 mm). Yön uçak üreticisinden gelecek.",
               "In the base design the propeller turns opposite to the power turbine; the other hand needs two idlers (offset at least 153 mm). The direction comes from the aircraft maker."),
    "SYS-08": ("open", "Tanım PDR'de kondu; tork sınırlaması CTL-01 tork ölçeriyle yapılıyor. Kontrol mantığı ve test Faz 3'te.",
               "The definition was set at the PDR; torque limiting uses the CTL-01 torque meter. Control logic and test in Phase 3."),
    "SYS-09": ("tbd", "Kaçıklık yaklaşık 146 mm; yönü ve kabulü uçak üreticisinden gelecek.",
               "Offset about 146 mm; its direction and agreement come from the aircraft maker."),
    "SYS-10": ("partial", "Mil tüneli tasarlandı (2.2): 15 mm yalıtım ve 7,5 g/s tampon havayla mil en fazla 124,5 °C. Arayüz koşulu: diyaframdan diyaframa en fazla 0,60 m. Egzoz kanalı ölçüleri ve sıcaklıkları çekirdek üreticisinden.",
               "The shaft tunnel is designed (2.2): with 15 mm of insulation and 7.5 g/s of buffer air the shaft stays at or below 124.5 °C. Interface condition: at most 0.60 m from diaphragm to diaphragm. Exhaust duct dimensions and temperatures come from the core maker."),
    "LD-01": ("met", "Dişlilerin statik kontrolü, millerin akma kontrolü ve güç türbini mili ile kaplinler (LD-01'de kayma gerilmesi 124,9 MPa, statik güvenlik 1,17) geçiyor.",
              "The static check of the gears, the yield check of the shafts and the power turbine shaft with its couplings (shear stress 124.9 MPa at LD-01, static safety 1.17) pass."),
    "LD-02": ("open", "Tasarım LD-01 torkunu kullanıyor; aşırı tork testi Faz 3'te.",
              "The design uses the LD-01 torque; the overtorque test is in Phase 3."),
    "LD-03": ("met", "20 kN itkiyle pervane milinin dört noktalı bilyalı yatağı 35.000 saat (STR-02) ve gövde sınır yükte en fazla 81 MPa (2.8).",
              "With 20 kN of thrust the four-point contact bearing of the propeller shaft reaches 35,000 h (STR-02) and the case stays at or below 81 MPa at limit load (2.8)."),
    "LD-04": ("met", "Dört noktalı bilyalı yatak iki yönde de yük taşıyor; ikinci yük yolu olarak pervane milinin içinde titanyum tutma borusu ve burun kapağında yakalama dudağı var (Karar 4, SAF-01).",
              "The four-point contact bearing carries load in both directions; as a second load path there is a titanium retention tube inside the propeller shaft and a catcher lip in the nose cover (Decision 4, SAF-01)."),
    "LD-05": ("met", "Pervane mili (PDR), yataklar (2.5, statik güvenlik ve ömür) ve gövde (2.8: en yüklü yuvarlatma 81 MPa, izin verilen 165 MPa) jiroskopik sınır yükü taşıyor.",
              "The propeller shaft (PDR), the bearings (2.5, static safety and life) and the case (2.8: most loaded fillet 81 MPa, 165 MPa allowed) carry the gyroscopic limit load."),
    "LD-06": ("tbd", "Düşey yük katsayıları kullanıldı (jeneratör pedi 3,17 g'de); yanal ve ileri-geri katsayılar uçak üreticisinden gelecek.",
              "The vertical load factors are used (generator pad at 3.17 g); the lateral and fore-aft factors come from the aircraft maker."),
    "LD-07": ("tbd", "Değerler pervane üreticisinden gelecek; gövde yorulması bu değerlerle Faz 3'te hesaplanacak.",
              "The values come from the propeller maker; the housing fatigue check uses them in Phase 3."),
    "LD-08": ("partial", "Dişliler pervanede 24.386 N·m taşıyor; koşul, güç türbininin en az 0,22 s'de durması (çekirdek üreticisine arayüz koşulu).",
              "The gears take 24,386 N·m at the propeller; condition: the power turbine takes at least 0.22 s to stop (interface condition on the core maker)."),
    "SAF-01": ("partial", "İkinci yük yolu tasarlandı: titanyum tutma borusu ve yakalama dudağı (Karar 4). Olasılık hedefinin hata ağacı analizi Faz 3'te.",
               "The second load path is designed: titanium retention tube and catcher lip (Decision 4). The fault tree analysis of the probability target is in Phase 3."),
    "SAF-02": ("partial", "Kritik parçalar belirlendi; yorulma güvenlikleri: güç türbini mili 7,32, pervane mili ve RGB milleri STR-03'te. Hasar toleransı ve yönetim planları Faz 3'te.",
               "The critical parts are identified; fatigue safeties: power turbine shaft 7.32, the propeller shaft and RGB shafts under STR-03. Damage tolerance and management plans in Phase 3."),
    "SAF-03": ("partial", "Kopma 14,5 ms'de algılanıyor (sınır 20 ms), vana 25 ms sonra kapanıyor; tepe hız %123,3. Koşul: SAF-06 (τ ≤ 0,1 s) ve J ≥ 0,084 kg·m².",
               "The break is detected at 14.5 ms (limit 20 ms) and the valve closes 25 ms later; peak speed 123.3%. Condition: SAF-06 (τ ≤ 0.1 s) and J ≥ 0.084 kg·m²."),
    "SAF-04": ("met", "Yağ pompaları ara milden döndüğü için rüzgârla dönmede de çalışıyor; pompa debisi ısı için fazlasıyla yeterli (2.7). Test Faz 3'te.",
               "The oil pumps turn with the intermediate shaft, so they keep running while windmilling; the pump flow is ample for the heat (2.7). Test in Phase 3."),
    "SAF-05": ("open", "Gövde A357-T6 alüminyum döküm (STR-10); yangın direnci, tank ve hatların korunması Faz 3'te gösterilecek.",
               "The case is an A357-T6 aluminium casting (STR-10); fire resistance and the protection of the tank and lines are shown in Phase 3."),
    "SAF-06": ("tbd", "Çekirdek üreticisine aktarıldı.", "Passed to the core maker."),
    "DYN-01": ("met", "Güç türbini mili 34.443 rpm (sınır 26.640 rpm); RGB milleri PDR'deki gibi; 120/100 mm pervane milinin ileri yönlü kritik hızları %110'un üstünde (2.1).",
               "Power turbine shaft 34,443 rpm (limit 26,640 rpm); RGB shafts as at the PDR; the forward-whirl criticals of the 120/100 mm propeller shaft lie above 110% (2.1)."),
    "DYN-02": ("met", "Burulma modları uyarı mertebelerinden en az %11,7 ayrık (2.3); pervane kanadının esnekliği gelince güncellenecek.",
               "The torsional modes stay at least 11.7% away from every excitation order (2.3); updated when the propeller blade flexibility is known."),
    "DYN-03": ("open", "Titreşim taraması Faz 3'te; ivmeölçer yerleri ve arıza frekansları tablosu 2.10'da hazır.", "The vibration survey is in Phase 3; the accelerometer positions and the fault frequency table are ready in 2.10."),
    "DYN-04": ("partial", "Halka ve planet jantları ile aksesuar dişlileri açık (en az %63). Planet: 1× bandı %27 açık, 3. mod 2× bandın kıyısında (açık). Birinci kademe dişlisinin gövdesi bantta: sönüm halkası, test Faz 3'te. Gövde panelleri: zorlanmış titreşim cevabı Faz 3'te (v3 metni).",
               "Ring and planet rims and the accessory gears are clear (at least 63%). Planet: 1× band clear by 27%, its third mode at the edge of the 2× band (open). First-stage gear web in the band: damping ring, test in Phase 3. Housing panels: forced response in Phase 3 (v3 text)."),
    "DYN-05": ("met", "Sönümleyicisiz pervane milinde oran en kötü durumda 1,67 (sınır 2,5), koşulu yuvalarda her yönde en az 5×10⁷ N/m (2.1). Gövde iç yuvada 5,04×10⁸, dış yuvada 9,47×10⁷ N/m veriyor; cıvatalı bağlantı açılsa bile 6,56×10⁷ N/m (2.8). PDR'deki risk kalktı.",
               "Without a damper the ratio is 1.67 in the worst case (limit 2.5), on condition of at least 5×10⁷ N/m in every direction at the seats (2.1). The case gives 5.04×10⁸ N/m at the inner seat and 9.47×10⁷ N/m at the outer seat, still 6.56×10⁷ N/m with an opened bolted joint (2.8). The PDR risk is removed."),
    "STR-01": ("met", "ISO 6336 Yöntem B ve C ile en düşük S_H 1,34, S_F 1,77 (2.5'ten sonra); aşırı torkta statik kontrol geçiyor. Sıvanma, ISO/TS 6336-20'nin yayımlanmış yöntemiyle MIL-PRF-23699'da S_S ≥ 1,61 (TBR).",
               "By ISO 6336 Methods B and C the lowest S_H is 1.34 and the lowest S_F 1.77 (after 2.5); the static check at overtorque passes. Scuffing by the published form of the ISO/TS 6336-20 method gives S_S ≥ 1.61 with MIL-PRF-23699 (TBR)."),
    "STR-02": ("met", "Bütün yataklar 110 °C'de 12.000 saatin üstünde: en düşüğü planet yatağı 14.500 saat, ana yataklarda pervane milinin dört noktalı yatağı 35.000 saat, aksesuar yatakları da üstünde. b_m, e_C ve a_ISO katsayıları ISO 281 gelene kadar TBR.",
               "Every bearing is above 12,000 h at 110 °C: the lowest is the planet bearing at 14,500 h, among the main bearings the four-point contact bearing of the propeller shaft at 35,000 h, and the accessory bearings are above too. b_m, e_C and the a_ISO coefficients are TBR until ISO 281 is available."),
    "STR-03": ("met", "Miller ve kamalı bağlantılar sağlıyor (2.5); güç türbini mili yorulma güvenliği 7,32 (2.2). Kamalı bağlantı basınç sınırları Faz 3 aşınma testlerine kadar TBR.",
               "The shafts and splines meet it (2.5); power turbine shaft fatigue safety 7.32 (2.2). The spline pressure limits are TBR until the Phase 3 wear tests."),
    "STR-04": ("partial", "Yuva direngenliği sağlanıyor: iç yuva 5,04×10⁸, dış yuva 9,47×10⁷ N/m, cıvatalı bağlantı açıldığında 6,56×10⁷ N/m (2.8). Halka dişlinin yük altındaki eksen kaçıklığı ve motor tarafının esnekliği Faz 3'te.",
               "The seat stiffness is met: inner seat 5.04×10⁸, outer seat 9.47×10⁷ N/m, 6.56×10⁷ N/m with an opened bolted joint (2.8). The misalignment of the ring gear under load and the engine-side flexibility follow in Phase 3."),
    "STR-05": ("met", "Hesaplar bu esasa göre: dişliler 10¹⁰ çevrim, miller sonsuz ömür, yataklar 3 × TBO.",
               "The calculations use this basis: gears for 10¹⁰ cycles, shafts for infinite life, bearings for 3 × TBO."),
    "STR-06": ("partial", "Dişliler Pyrowear 53 (AMS 6308) sementasyon, halka 32CrMoV13 nitrürleme (2.4); malzeme şartnameleri ve sertlik kontrolleri teknik resimlerle Faz 3'te.",
               "Gears in carburized Pyrowear 53 (AMS 6308), the ring in nitrided 32CrMoV13 (2.4); material specifications and hardness checks with the drawings in Phase 3."),
    "STR-07": ("met", "Yüzer güneş, 8 mm (4 modül) halka jantı; Monte Carlo modelinde K_γ (P99) 1,337 (sınır 1,35); toleranslar teknik resimlere yazılıyor.",
               "Floating sun, 8 mm (4 module) ring rim; K_γ (P99) 1.337 from the Monte Carlo model (limit 1.35); the tolerances go on the drawings."),
    "STR-08": ("met", "Birinci kademenin helis düzeltmeleri ve uç kırmaları 3B yük dağılımıyla belirlendi (2.4); %110'da çevre hızı 81 m/s (sınır 100 m/s).",
               "The helix corrections and tip reliefs of the first stage were set by 3D load distribution (2.4); pitch-line velocity at 110% 81 m/s (limit 100 m/s)."),
    "STR-09": ("met", "Bütün dişliler süper bitirme (Karar 1); teknik resimlere yazıldı, muayene Faz 3'te.",
               "All gears are superfinished (Decision 1); written on the drawings, inspection in Phase 3."),
    "STR-10": ("met", "A357-T6 gövde 1,25 döküm katsayısıyla: en yüklü yuvarlatma sınır yükte 81 MPa (izin 165 MPa), yaylı flanşta 128 MPa (2.8). Radyografik muayene sınıfı TBR.",
               "A357-T6 case with the 1.25 casting factor: most loaded fillet 81 MPa at limit load (165 MPa allowed), 128 MPa with a spring-supported flange (2.8). Radiographic inspection class TBR."),
    "LUB-01": ("met", "Hesaplar MIL-PRF-23699 yağıyla; MIL-PRF-7808 için sıcaklık sınırı LUB-02'de.",
               "The calculations use MIL-PRF-23699 oil; the temperature limit for MIL-PRF-7808 is in LUB-02."),
    "LUB-02": ("partial", "132 °C yağ girişinde dişliler ve yataklar hesaplandı; normal çalışmada soğutucu yağı 100 °C'de tutuyor (2.7). 15 dakika 149 °C ve soğuk çalıştırma Faz 3'te.",
               "The gears and bearings are rated at 132 °C oil inlet; in normal operation the cooler holds the oil at 100 °C (2.7). 15 minutes at 149 °C and cold starts in Phase 3."),
    "LUB-03": ("partial", "Memeler 400 kPa, besleme 550 kPa: ikisi de 172–965 kPa içinde. Rölantide basınç Faz 3'te.",
               "Jets at 400 kPa, supply at 550 kPa, both inside 172–965 kPa. Pressure at ground idle in Phase 3."),
    "LUB-04": ("met", "Yağa giren ısı 14,9 kW (PT arka yatak bölmesi dahil); soğutucu 53 °C'lik günde 18 kW için boyutlandı (2.7).",
               "Heat into the oil 14.9 kW (PT rear sump included); the cooler is sized for 18 kW on a 53 °C day (2.7)."),
    "LUB-05": ("partial", "3 µm filtre ve iki talaş dedektörü devrede; 0,6 mm memeler için son çare süzgeçleri TBR. Parça seçimi Faz 3'te.",
               "3 µm filter and two chip detectors in the circuit; last-chance strainers for the 0.6 mm jets TBR. Part selection in Phase 3."),
    "LUB-06": ("met", "6,8 L tank (2.7): kullanılabilir yağ, %10 genleşme payı ve tüy açma rezervi dahil.",
               "6.8 L tank (2.7): usable oil, 10% expansion space and the feathering reserve included."),
    "LUB-07": ("open", "Hedef; yağsız çalışma Faz 3'te.", "A goal; running without oil in Phase 3."),
    "LUB-08": ("tbd", "Negatif g süresi uçak üreticisinden gelecek; Faz 3'te.", "The negative-g duration comes from the aircraft maker; Phase 3."),
    "LUB-09": ("met", "Karar 5 ile kapandı: yerde elektrikli fan (yaklaşık 0,5 kW), uçuşta dinamik hava.",
               "Closed by Decision 5: an electric fan on the ground (about 0.5 kW), ram air in flight."),
    "LUB-10": ("met", "PT arka yatak bölmesi iki memeyle besleniyor, kendi emme elemanıyla boşaltılıyor; 1,27 L/dk (2.2, 2.7).",
               "The PT rear sump is fed by two jets and scavenged by its own element; 1.27 L/min (2.2, 2.7)."),
    "ACC-01": ("tbd", "Çekirdek tedarikçisine arayüz gereksinimi; marş süresi TBD.", "Interface requirement on the core supplier; starting time TBD."),
    "ACC-02": ("met", "Dört ped (jeneratör, OSG, PCU, yağ pompası) torkları ve hızlarıyla tasarlandı (2.6).",
               "The four pads (generator, OSG, PCU, oil pump) are designed with their torques and speeds (2.6)."),
    "ACC-03": ("met", "1,5 kat torkta yorulma, kesme boyunları ve boyunların dişlilerden önce koptuğu gösterildi (2.6). Jeneratörün kısa devre torku seçimden sonra kesme bandının altıyla (169 N·m) karşılaştırılacak (TBR).",
               "Fatigue at 1.5 times the torque, the shear necks and necks that break before the gears are shown (2.6). The generator's short-circuit torque is compared with the bottom of the shear band (169 N·m) once the generator is chosen (TBR)."),
    "PIF-01": ("tbd", "Flanş ölçüleri pervane üreticisinden gelecek; CATIA modelinde yer tutucu flanş var.",
               "The flange dimensions come from the propeller maker; the CATIA model has a placeholder flange."),
    "PIF-02": ("tbd", "Yol, 100 mm delikli pervane milinin içinden (2.1); debi ve basınç pervane üreticisinden gelecek.",
               "The route is through the 100 mm bore of the propeller shaft (2.1); flow and pressure come from the propeller maker."),
    "PIF-03": ("open", "Tankta tüy açma rezervi var (LUB-06); test Faz 3'te.", "The tank holds a feathering reserve (LUB-06); the test is in Phase 3."),
    "PIF-04": ("met", "Tasarımda beta modu yok; dişliler ve yataklar ters itki çevrimi için hesaplanmadı (inceleme).",
               "The design has no beta mode; the gears and bearings are not rated for reversing cycles (inspection)."),
    "PIF-05": ("tbd", "Regülatör pedi var (ACC-02); ayar pervane üreticisinden gelecek.", "The governor pad is there (ACC-02); the setting comes from the propeller maker."),
    "CTL-01": ("met", "Faz kaydırmalı tork ölçer 20 ns zaman çözünürlüğü ve sıcaklık düzeltmesiyle ±%2'yi sağlıyor (2.2); doğruluk testi Faz 3'te.",
               "The phase-shift torque meter meets ±2% with a 20 ns timing resolution and temperature correction (2.2); accuracy test in Phase 3."),
    "CTL-02": ("partial", "Np × 2 ve Nr × 2 sensörlerinin yerleri belli (adım 1.4); parça seçimi ve test Faz 3'te.",
               "The places of the Np × 2 and Nr × 2 sensors are set (step 1.4); part selection and test in Phase 3."),
    "CTL-03": ("partial", "Durum izleme kavramı tasarlandı (2.10, Karar 7): bütün millerin, kavramaların, yerel dişli hatalarının ve 11 yatağın arıza frekansları; sonlu eleman aktarımına göre iki ivmeölçer yeri (z 96 mm gövde duvarı, z 442 mm dış yatak göbeği); yağ kalıntısı izleyicisi. Durum göstergeleri, eşikler ve test Faz 3'te.",
               "The condition monitoring concept is designed (2.10, Decision 7): fault frequencies of every shaft, mesh, local gear fault and the 11 bearings; two accelerometer positions from the finite element transfer (case wall at z 96 mm, outer bearing boss at z 442 mm); an oil debris monitor. Condition indicators, thresholds and test in Phase 3."),
    "MNT-01": ("tbd", "RGB ayrı bir modül olarak modellendi (CATIA montajı); 2.10'da planet modülü, birinci kademe modülü ve tek tek değiştirilebilen aksesuarlar tanımlandı. Hedef sökme-takma süresi müşteriden gelecek.",
               "The RGB is modelled as a separate module (CATIA assembly); 2.10 defines the planetary module, the first-stage module and individually replaceable accessories. The target removal and installation time comes from the customer."),
    "MNT-02": ("partial", "Boroskop delikleri (planet kademesinde halka-planet kavrama düzlemi, birinci kademede pinyon-dişli kavraması), yağ numune noktası ve yağ kalıntısı izleyicisinin yeri 2.10'da belirlendi; erişim, birinci kademe ve aksesuar gövdeleriyle Faz 3'te gösterilecek.",
               "The borescope ports (ring-planet mesh plane of the planetary stage, pinion-gear mesh of the first stage), the oil sampling point and the place of the oil debris monitor are set in 2.10; access is shown with the first-stage and accessory cases in Phase 3."),
    "ENV-01": ("partial", "Soğutucu 53 °C'lik günde boyutlandı; −40 °C soğuk çalıştırma Faz 3'te.",
               "The cooler is sized on a 53 °C day; cold starts at −40 °C in Phase 3."),
    "ENV-02": ("open", "Yükseklikte pompa girişi, havalandırma ve hava ayırma Faz 3'te.", "Pump inlet, venting and de-aeration at altitude in Phase 3."),
    "ENV-03": ("open", "Gövde A357-T6 (STR-10); kaplama ve test yöntemleri Faz 3'te.", "The case is A357-T6 (STR-10); coatings and test methods in Phase 3."),
    "ENV-04": ("partial", "Tünel sıcaklıkları 700 °C gazla hesaplandı (2.2); gerçek gaz sıcaklıkları çekirdek üreticisinden gelince güncellenecek.",
               "The tunnel temperatures are computed with 700 °C gas (2.2); updated with the real gas temperatures from the core maker."),
}


def main():
    with open(HERE / "requirements_v2.csv", encoding="utf-8", newline="") as f:
        v2 = list(csv.DictReader(f))
    columns = [c for c in v2[0].keys() if c != "v2_change"] + ["v3_change"]
    rows = []
    for r in v2:
        row = {c: r[c] for c in columns if c != "v3_change"}
        change = CHANGES.get(r["id"])
        if change:
            unknown = set(change) - set(columns)
            assert not unknown, (r["id"], unknown)
            row.update(change)
        row["v3_change"] = "changed" if change else ""
        rows.append(row)
    for n in NEW:
        row = {c: n.get(c, "") for c in columns}
        row["v3_change"] = "new"
        after = max(i for i, r in enumerate(rows) if r["group"] == n["group"])
        rows.insert(after + 1, row)
    with open(HERE / "requirements_v3.csv", "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=columns)
        w.writeheader()
        w.writerows(rows)

    with open(HERE / "needs_assumptions_v2.csv", encoding="utf-8", newline="") as f:
        na = list(csv.DictReader(f))
    na_cols = [c for c in na[0].keys() if c != "v2_change"] + ["v3_change"]
    with open(HERE / "needs_assumptions_v3.csv", "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=na_cols)
        w.writeheader()
        for r in na:
            w.writerow({**{c: r[c] for c in na_cols if c != "v3_change"}, "v3_change": ""})

    ids = [r["id"] for r in rows]
    missing = [i for i in ids if i not in CDR]
    extra = [i for i in CDR if i not in ids]
    assert not missing and not extra, (missing, extra)
    with open(HERE / "compliance_cdr.csv", "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["id", "verdict", "evidence_tr", "evidence_en"])
        for i in ids:
            v, tr, en = CDR[i]
            w.writerow([i, v, tr, en])
    print(f"requirements_v3.csv: {len(rows)} rows ({len(CHANGES)} changed, {len(NEW)} new); compliance_cdr.csv written")


if __name__ == "__main__":
    main()
