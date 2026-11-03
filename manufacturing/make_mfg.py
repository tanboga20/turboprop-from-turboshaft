"""Write the material, process, route and component tables of step 3.4 (manufacturing/*.csv).

    python manufacturing/make_mfg.py

materials_v1.csv   one row per material key of the BOM (manufacturing/bom_v1.csv, written by
                   calc/manufacturing/run_step34.m): specification, condition and heat treatment, hardness and case,
                   surface finish, non-destructive inspection, protection, the parts and the requirements.
processes_v1.csv   the process specifications the drawings of step 3.9 will call up, with the key values.
routes_v1.csv      manufacturing routes of the three critical parts: planet gear, carrier with the propeller shaft,
                   planetary case.
components_v1.csv  bought and standard parts: what each must do, its key values and its status.
Values are TBR unless marked set; specification numbers are to be checked against the current issue when the
drawings are released. Oil: MIL-PRF-23699 only (Hamit's decision). Text in Turkish and English.
Source: Phase 3 report, Section 3.4.
"""
import csv
import os

HERE = os.path.dirname(os.path.abspath(__file__))

# key, parts (BOM numbers), material, specification, condition_en, condition_tr, hardness_case, finish, ndt,
# protection_en, protection_tr, requirements, status
MATERIALS = [
    ('P53', 'P105 sun, P107 planets, F202 gear 2, F203 pinion, F204 intermediate shaft, A302/A303 generator gear-shaft, '
            'A308 OSG gear, A312 PCU gear',
     'Pyrowear 53, VIM-VAR', 'AMS 6308',
     'Carburized, hardened, sub-zero treated, double tempered at about 200-230 degC (above the 145-171 degC bulk '
     'temperatures of step 2.4)',
     'Sementasyon, sertleştirme, sıfır altı işlem, yaklaşık 200-230 °C\'de çift menevişleme (2.4\'teki 145-171 °C '
     'gövde sıcaklıklarının üstünde)',
     'Surface 58-63 HRC; effective case depth to 550 HV after grinding 0.5-0.7 mm on the main gears (0.4-0.6 mm on '
     'the m 1.5 accessory gears; at most 0.4 m_n); core at least 30 HRC (STR-06); retained austenite at most 15% (TBR)',
     'Flanks ground, then superfinished to Ra <= 0.15 um, Rz <= 0.8 um (STR-09); planet bore (outer race) ground and '
     'superfinished, Ra <= 0.1 um (TBR); roots protuberance-hobbed, not ground',
     'Temper etch after grinding (ISO 14104 / AMS 2649), magnetic particle (ASTM E1444), case depth and core '
     'hardness on a test coupon of each heat-treat lot',
     'Oil-wetted, no coating; preservation oil for storage', 'Yağla ıslanıyor, kaplama yok; depolamada koruma yağı',
     'STR-01, STR-06, STR-09, LUB-07', 'set (material, Decision 1 and step 2.4); TBR (values)'),
    ('N13', 'P102 ring gear', '32CrMoV13 (EN 1.8523), aerospace grade 32CDV13', 'EN 1.8523; aerospace specification TBR',
     'Quenched and tempered, stress relieved, gear shaped, gas nitrided (AMS 2759/6)',
     'Su verilip menevişlenmiş, gerilim giderilmiş, dişleri planyalanmış, gaz nitrürlenmiş (AMS 2759/6)',
     'Surface at least 650 HV (STR-06), aluminium-free steel; nitriding depth (core + 50 HV) 0.5-0.7 mm (the planet-ring '
     'contact needs 0.40 mm at LD-02); compound (white) layer removed or at most 10 um (TBR)',
     'Flanks honed, then superfinished to Ra <= 0.15 um, Rz <= 0.8 um (STR-09; the step 2.4 rating used Rz 1.0, '
     'so it is conservative)',
     'Magnetic particle (ASTM E1444); nitride depth and hardness on a coupon nitrided with the part',
     'Oil-wetted; the outer seat in the case: no coating', 'Yağla ıslanıyor; gövdedeki dış yuva: kaplama yok',
     'STR-01, STR-06, STR-09', 'set (material, step 2.4); TBR (values)'),
    ('S43', 'P103 carrier with propeller shaft, F212 PT output shaft (forged hollow, integral flanges), P106 sun quill, P112/F209/F210 nuts, A307/A311/A315/A317 quills, '
            'A309/A313 pad adapters, L403 transfer sleeve, S621-S628 seat liners',
     'AISI 4340, vacuum arc remelted', 'AMS 6414',
     'Quenched and tempered to 1240 MPa tensile (AMS 2759/1); splines of the sun quill and the transfer sleeve bore '
     'gas nitrided (AMS 2759/6, TBR)',
     'Su verilip 1240 MPa çekme dayanımına menevişlenmiş (AMS 2759/1); güneş mili kamaları ve transfer manşonu deliği '
     'gaz nitrürlenmiş (AMS 2759/6, TBR)',
     '38-42 HRC core; nitrided splines at least 600 HV (TBR)',
     'Bearing journals ground Ra <= 0.4 um; fillets polished; carrier pin bores line-bored to the 0.010 mm true '
     'position of step 2.4',
     'Ultrasonic of the forging (AMS 2630), magnetic particle (ASTM E1444) after final machining',
     'Oil-wetted surfaces bare; the propeller shaft outside the nose and the flange: zinc-nickel (AMS 2417) with '
     'hydrogen embrittlement bake, epoxy primer and topcoat (ENV-03)',
     'Yağla ıslanan yüzeyler çıplak; burun dışındaki pervane mili ve flanş: çinko-nikel (AMS 2417), hidrojen '
     'gevrekliği fırınlaması, epoksi astar ve son kat (ENV-03)',
     'STR-03, SAF-01, ENV-03', 'set (steel propeller shaft 120/100, step 2.1); TBR (AISI 4340 grade, step 2.5)'),
    ('M5N', 'P104 planet pins (inner race of the planet bearing)', 'M50NiL, VIM-VAR', 'AMS 6278',
     'Carburized, hardened, tempered; pressed into the carrier (LN2 shrink) and retained',
     'Sementasyon, sertleştirme, menevişleme; taşıyıcıya presle (sıvı azotla daraltarak) takılıp sabitleniyor',
     'Surface 60-64 HRC, case 1.0-1.5 mm (raceway needs 0.10 mm at LD-02), core 40-48 HRC (TBR)',
     'Raceway ground and superfinished Ra <= 0.1 um, roller crown matched (bearing supplier)',
     'Temper etch, magnetic particle; bearing supplier\'s raceway inspection', 'Oil-wetted, no coating',
     'Yağla ıslanıyor, kaplama yok', 'STR-02, STR-06',
     'proposed: a separate pin keeps the 4340 carrier of step 2.5 (the CATIA carrier has the pins in one body)'),
    ('A357', 'P101 planetary case, F201 first-stage case, A301 accessory cover, A304 generator cartridge',
     'A357.0-T6 aluminium, premium-quality sand casting', 'AMS-A-21180 (class giving at least 310 MPa tensile and 240 MPa '
     'yield in the designated areas, the step 2.8 allowables; class number TBR)',
     'Sand cast (bonded sand cores for the oil passages, chills at the bearing bosses), solution treated, quenched, '
     'artificially aged (T6, AMS 2771); optional hot isostatic pressing (TBR)',
     'Kum döküm (yağ kanalları için bağlı kum maçaları, rulman göbeklerinde soğutucular), çözeltiye alma, su verme, '
     'yapay yaşlandırma (T6, AMS 2771); isteğe bağlı sıcak izostatik presleme (TBR)',
     'Not applicable (about 85-95 HB); steel seat liners in the bearing bores',
     'Machined faces Ra 1.6 um; bearing liner bores Ra 0.8 um; flange face flatness 0.03 mm (TBR)',
     'Radiography 100% (ASTM E1742, grading to ASTM E155 reference radiographs): AMS 2175 grade B in the critical zones '
     '(flange root, conical nose, bearing bosses, ring seat), grade C elsewhere (TBR, STR-10); fluorescent penetrant '
     '(ASTM E1417); separately cast test bars from each melt and coupons cut from a casting per lot; oil passages '
     'pressure tested at 1650 kPa (1.5 x the 1100 kPa relief, TBR)',
     'Outside: chromate-free conversion coating (MIL-DTL-5541 Type II) + epoxy primer (MIL-PRF-23377, non-chromate) + '
     'topcoat (MIL-PRF-85285); oil-wetted inside: conversion coating only; faying surfaces with steel and titanium '
     'parts installed wet with a corrosion-inhibiting sealant (ENV-03)',
     'Dış: kromatsız dönüşüm kaplaması (MIL-DTL-5541 Tip II) + epoksi astar (MIL-PRF-23377, kromatsız) + son kat '
     '(MIL-PRF-85285); yağla ıslanan iç: yalnız dönüşüm kaplaması; çelik ve titanyum parçalarla temas yüzeyleri '
     'korozyon önleyici sızdırmazlık maddesiyle ıslak montaj (ENV-03)',
     'STR-10, ENV-03, SAF-05', 'set (A357-T6, Decision 6 of step 2.8); TBR (class, grades)'),
    ('Ti64', 'P111 propeller bearing housing, P114 retention tube, L404 pitch oil tube, E501 mist accumulator',
     'Ti-6Al-4V, annealed', 'AMS 4928 (bar and forging)',
     'Forged (housing) or gun-drilled bar (tube), annealed, machined', 'Dövme (yuva) ya da derin delinmiş çubuk (tüp), '
     'tavlanmış, işlenmiş', 'About 36 HRC; no case',
     'Machined Ra 1.6 um; bearing seat of the housing Ra 0.8 um',
     'Ultrasonic of the bar or forging (AMS 2631), fluorescent penetrant (ASTM E1417)',
     'Anodized against galling on fits and threads (AMS 2488, TBR); installed wet on the A357 nose',
     'Geçme ve dişlerde sıvanmaya karşı anodize (AMS 2488, TBR); A357 burna ıslak montaj',
     'SAF-01, ENV-03', 'set (retention tube, Decision 4 of step 2.5); TBR (housing)'),
    ('C321', 'L402 external oil tubes, E503 mist lines, E504 bleed line', 'CRES 321, annealed tubing', 'AMS 5557',
     'Bent and welded or brazed to fittings; flared or beam-seal ends (TBR)', 'Bükülmüş, bağlantılara kaynaklı ya da '
     'sert lehimli; havşalı ya da kiriş contalı uçlar (TBR)', '-', 'As drawn',
     'Proof pressure test 1.5 x the 1100 kPa relief; radiography of welds (TBR)', 'Passivated; fire resistant by '
     'material (SAF-05); bleed line insulated (100 degC air)', 'Pasifleştirilmiş; malzemesiyle yangına dayanıklı '
     '(SAF-05); hava hattı yalıtımlı (100 °C hava)', 'SAF-05, LUB-07', 'TBR'),
    ('C155', 'L401 oil jets with last-chance strainers; F213, F214 diaphragm couplings (diaphragms from controlled sheet, polished faces, peened hub transitions)', '15-5PH, H1025', 'AMS 5659',
     'Machined, aged H1025', 'İşlenmiş, H1025 yaşlandırılmış', 'About 35 HRC', 'Jet bore reamed, edge sharp, '
     'length/diameter 2 (step 3.2)', 'Flow test of each jet at its design pressure (+-10%, TBR)', 'Passivated',
     'Pasifleştirilmiş', 'LUB-03, LUB-05', 'TBR'),
    ('S129', 'S601 case flange bolts (30 x M6)', 'Alloy steel bolts, property class 12.9 (the VDI 2230 run of step 3.5)',
     'ISO 898-1 class 12.9; aerospace bolt standard TBR (3.9)', 'Quenched and tempered; rolled threads after heat treatment',
     'Su verilmiş ve menevişlenmiş; ısıl işlemden sonra ovalanmış dişler', 'Rm 1220 MPa, Rp0.2 1080 MPa', '-', 'Supplier certification',
     'Zinc-nickel with bake (hydrogen embrittlement relief), installed in helical coil inserts', 'Çinko-nikel, hidrojen gevrekliği fırınlamasıyla; helisel tel insertlere takılır',
     'STR-04, ENV-03', 'TBR (3.9)'),
    ('A286', 'S600, S602-S612 bolts, studs and nuts', 'A286 (iron-base superalloy) fasteners', 'AMS 5737 bar; NAS/MS '
     'standard fasteners (TBR)', 'Solution treated and aged; rolled threads after heat treatment',
     'Çözeltiye alınmış ve yaşlandırılmış; ısıl işlemden sonra ovalanmış dişler', 'About 160 ksi (1100 MPa) class',
     '-', 'Supplier certification', 'Passivated; silver-plated or dry-film lubricated nuts in hot areas; wet '
     'installed in the A357 castings (self-locking helical coil inserts, NASM21209)', 'Pasifleştirilmiş; sıcak '
     'bölgelerde gümüş kaplı ya da kuru film yağlamalı somunlar; A357 dökümlerde ıslak montaj (kendinden kilitli '
     'helisel tel insertler, NASM21209)', 'STR-04, ENV-03', 'TBR (counts and sizes in 3.9)'),
]

# id, process_en, process_tr, specification, applies_to, key_values, status
PROCESSES = [
    ('PR-01', 'Carburizing and heat treatment of carburizing steels', 'Sementasyon çeliklerinin sementasyonu ve ısıl işlemi',
     'AMS 2759/7', 'P53 gears, M5N pins', 'case 0.5-0.7 mm (gears), 1.0-1.5 mm (pins); core >= 30 HRC; sub-zero; double temper', 'TBR'),
    ('PR-02', 'Gas nitriding', 'Gaz nitrürleme', 'AMS 2759/6', 'ring gear; quill splines, transfer sleeve',
     '>= 650 HV surface (ring); depth 0.5-0.7 mm (ring); white layer <= 10 um', 'TBR'),
    ('PR-03', 'Heat treatment of low-alloy steel parts', 'Düşük alaşımlı çelik parçaların ısıl işlemi', 'AMS 2759/1',
     'AISI 4340 parts', 'Q&T to 1240 MPa tensile, 38-42 HRC', 'TBR'),
    ('PR-04', 'Shot peening, computer monitored', 'Bilgisayar izlemeli bilye püskürtme', 'AMS 2432',
     'gear roots and fillets (flanks masked), carrier fillets, quill necks',
     'cast steel shot, intensity 0.008-0.012 A on gears, 0.010-0.014 A on the carrier, coverage 200% (TBR)', 'TBR'),
    ('PR-05', 'Gear grinding and flank modifications', 'Dişli taşlama ve diş yüzeyi düzeltmeleri', 'ISO 1328-1 class A4 (first stage), A5 (planetary)',
     'external gears', 'tip relief, helix correction and crowning of step 2.4 on the drawings', 'set (step 2.4)'),
    ('PR-06', 'Temper etch inspection after grinding', 'Taşlama sonrası menevişleme dağlama muayenesi', 'ISO 14104; AMS 2649',
     'all ground carburized and nitrided surfaces', 'class to the drawing (no rehardening, limited tempering on the flanks)', 'TBR'),
    ('PR-07', 'Isotropic superfinishing', 'İzotropik süper bitirme', 'drawing note per STR-09',
     'all gear flanks; planet bore raceway', 'Ra <= 0.15 um, Rz <= 0.8 um (STR-09); the step 2.4 ratings and films use Rz 0.8 '
     '(external) and Rz 1.0 (ring): film ratio at the pitch point with Type II at 100 degC: first stage 1.54, sun-planet 0.53, '
     'planet-ring 0.85', 'set (Decision 1)'),
    ('PR-08', 'Magnetic particle inspection', 'Manyetik parçacık muayenesi', 'ASTM E1444', 'all ferromagnetic parts', '-', 'TBR'),
    ('PR-09', 'Fluorescent penetrant inspection', 'Floresan penetrant muayenesi', 'ASTM E1417', 'A357 castings, Ti and CRES parts',
     'Type I, sensitivity level 3 (castings), 4 (Ti) (TBR)', 'TBR'),
    ('PR-10', 'Radiography of castings', 'Dökümlerin radyografisi', 'ASTM E1742; ASTM E155; AMS 2175',
     'A357 castings', 'P101: every casting after HIP of the whole casting; critical zones (R10 flange junction, nose, mount flange and pads, zone note on the 3.9 drawing) at a 0.5 mm pore limit by CT (preferred) or radiography at quality level 1-2T or better (ASTM E1742 with E1025 IQIs; POD of 0.5 mm demonstrated, 90/95), elsewhere 100% radiography at 0.8 mm; other castings: grade B critical zones, grade C elsewhere, 100% on first articles, then by sampling (TBR, STR-10)', 'TBR'),
    ('PR-11', 'Ultrasonic inspection of forgings and bar', 'Dövme ve çubukların ultrasonik muayenesi', 'AMS 2630 (steel); AMS 2631 (Ti)',
     'carrier forging, gear forgings, Ti bar and forgings', 'class AA for the carrier and the retention tube (TBR)', 'TBR'),
    ('PR-12', 'Heat treatment of aluminium castings', 'Alüminyum dökümlerin ısıl işlemi', 'AMS 2771', 'A357 castings', 'T6', 'set'),
    ('PR-13', 'Conversion coating and paint of aluminium', 'Alüminyumun dönüşüm kaplaması ve boyası',
     'MIL-DTL-5541 Type II; MIL-PRF-23377; MIL-PRF-85285', 'A357 castings', 'outside: coat + primer + topcoat; inside: coat only', 'TBR'),
    ('PR-14', 'Zinc-nickel plating and embrittlement relief', 'Çinko-nikel kaplama ve gevreklik giderme', 'AMS 2417; AMS 2759/9',
     'external 4340 surfaces (propeller shaft and flange)', 'bake within 4 h of plating (TBR)', 'TBR'),
    ('PR-15', 'Proof pressure test of oil passages and lines', 'Yağ kanalları ve hatlarının basınç testi', 'drawing note',
     'castings, tubes, manifold', '1650 kPa for 3 min, no leak (1.5 x the 1100 kPa relief, TBR)', 'TBR'),
    ('PR-16', 'Fire test of oil-carrying external parts', 'Yağ taşıyan dış parçaların yangın testi', 'ISO 2685; AS1055 (hoses)',
     'case and cover walls, external tubes and hoses, tank', 'fire resistant: 5 min, 1100 degC flame; tank fireproof: 15 min (SAF-05); by test in 3.11', 'TBR'),
    ('PR-17', 'Salt fog and sand-and-dust tests', 'Tuz sisi ve kum-toz testleri', 'MIL-STD-810H Methods 509 and 510 (proposal for ENV-03)',
     'coated castings, seals, external parts', 'test methods TBD in ENV-03; proposed here', 'proposed'),
]

# part, op, operation_en, operation_tr, gate
ROUTES = [
    ('planet gear P107', 10, 'Pyrowear 53 VIM-VAR bar (AMS 6308), certified heat; upset forging, normalize and anneal',
     'Pyrowear 53 VIM-VAR çubuk (AMS 6308), sertifikalı döküm; yığma dövme, normalizasyon ve tavlama', 'material certificate; UT of the forging (AMS 2630)'),
    ('planet gear P107', 20, 'Rough turn blank, bore and faces; hob the teeth with protuberance', 'Taslağın, deliğin ve alınların kaba tornalanması; çıkıntılı azdırma ile dişler', '-'),
    ('planet gear P107', 30, 'Carburize, harden, sub-zero, double temper (AMS 2759/7) with a test coupon',
     'Sementasyon, sertleştirme, sıfır altı işlem, çift menevişleme (AMS 2759/7), test kuponuyla', 'coupon: case depth 0.5-0.7 mm, surface 58-63 HRC, core >= 30 HRC (STR-06)'),
    ('planet gear P107', 40, 'Shot peen the roots and fillets, flanks masked (AMS 2432)', 'Diş dibi ve yuvarlatmaları bilye püskürtme, yüzler maskeli (AMS 2432)', 'Almen strip intensity and coverage'),
    ('planet gear P107', 50, 'Grind the bore (outer race), faces and teeth with the step 2.4 modifications', 'Delik (dış bilezik), alınlar ve dişlerin 2.4 düzeltmeleriyle taşlanması', 'ISO 1328-1 class A5; bore size and roundness'),
    ('planet gear P107', 60, 'Temper etch (ISO 14104) and magnetic particle (ASTM E1444)', 'Menevişleme dağlaması (ISO 14104) ve manyetik parçacık (ASTM E1444)', 'no grinding burn, no indications'),
    ('planet gear P107', 70, 'Isotropic superfinish of the flanks and the bore', 'Dişlerin ve deliğin izotropik süper bitirmesi', 'Ra <= 0.15 um, Rz <= 0.8 um (STR-09); bore Ra <= 0.1 um'),
    ('planet gear P107', 80, 'Measure tooth thickness and sort into matched sets of four (+-3 um, step 2.4); mark the phase tooth; serialize',
     'Diş kalınlığını ölçüp dörtlü eşleşmiş setlere ayırma (+-3 um, 2.4); faz dişini işaretleme; seri numarası', 'matched set record (load sharing K_gamma)'),
    ('carrier with propeller shaft P103', 10, 'AISI 4340 VAR billet (AMS 6414); closed-die forging of shaft, plate and posts with the grain along the shaft',
     'AISI 4340 VAR kütük (AMS 6414); mil, plaka ve dikmelerin lif yönü mil boyunca kapalı kalıpta dövülmesi', 'UT class AA (AMS 2630)'),
    ('carrier with propeller shaft P103', 20, 'Normalize; rough machine with stock; quench and temper to 1240 MPa (AMS 2759/1)',
     'Normalizasyon; paylı kaba işleme; 1240 MPa\'ya su verme ve menevişleme (AMS 2759/1)', 'hardness 38-42 HRC; tensile coupon'),
    ('carrier with propeller shaft P103', 30, 'Semi-finish machine; mill the planet windows, plate scallops and the second plate; stress relieve',
     'Yarı ince işleme; planet pencerelerinin, plaka oyuklarının ve ikinci plakanın frezelenmesi; gerilim giderme', '-'),
    ('carrier with propeller shaft P103', 40, 'Finish machine: line-bore the 4 pin bores, bore of the retention tube and transfer sleeve, thread for the KM24 nut',
     'İnce işleme: 4 pim deliğinin hat delinmesi, tutma tüpü ve transfer manşonu delikleri, KM24 somun dişi', 'pin bore true position 0.010 mm (step 2.4), CMM'),
    ('carrier with propeller shaft P103', 50, 'Shot peen fillets (AMS 2432), journals masked; grind the bearing journals', 'Yuvarlatmaların bilye püskürtmesi (AMS 2432), muylular maskeli; rulman muylularının taşlanması', 'journal size, Ra <= 0.4 um'),
    ('carrier with propeller shaft P103', 60, 'Magnetic particle (ASTM E1444); zinc-nickel and bake on the external shaft section (AMS 2417)',
     'Manyetik parçacık (ASTM E1444); dış mil bölümünde çinko-nikel ve fırınlama (AMS 2417)', 'no indications; coating thickness'),
    ('carrier with propeller shaft P103', 70, 'Shrink in the four M50NiL pins (LN2), retain; check pin position and parallelism under the assembly',
     'Dört M50NiL pimin (sıvı azotla) takılması ve sabitlenmesi; pim konumu ve paralelliğinin kontrolü', 'pin parallelism f_pin_par 5 um (step 2.4, TBR)'),
    ('carrier with propeller shaft P103', 80, 'Balance (propeller speed, G 6.3, TBR); serialize; critical-part record (SAF-01)', 'Balans (pervane devri, G 6.3, TBR); seri numarası; kritik parça kaydı (SAF-01)', 'balance report'),
    ('planetary case P101', 10, 'Pattern and bonded sand cores (oil passages), chills at the bearing bosses and the flange', 'Model ve bağlı kum maçaları (yağ kanalları), rulman göbekleri ve flanşta soğutucular', 'first article layout'),
    ('planetary case P101', 20, 'Melt A357, degas and filter; pour (tilt or low pressure, TBR); cast separate test bars from the same melt',
     'A357 ergitme, gaz alma ve süzme; döküm (devirmeli ya da alçak basınç, TBR); aynı ergiyikten ayrı test çubukları', 'melt record, test bars'),
    ('planetary case P101', 30, 'Shake out, cut gates and risers; optional HIP (TBR); solution treat, quench, age to T6 (AMS 2771)', 'Kumdan çıkarma, yolluk ve besleyici kesme; isteğe bağlı HIP (TBR); çözeltiye alma, su verme, T6 yaşlandırma (AMS 2771)', 'test bars: >= 310 MPa tensile, >= 240 MPa yield'),
    ('planetary case P101', 40, 'Radiography 100% (grade B critical zones, C elsewhere) and fluorescent penetrant', 'Yüzde 100 radyografi (kritik bölgelerde B, diğerlerinde C sınıfı) ve floresan penetrant', 'AMS 2175 grades (STR-10, TBR); no weld repair in critical zones'),
    ('planetary case P101', 50, 'Rough machine; stress relieve; finish machine flange face, holes (30 x 6.6 on PCD 290), nose cone, liner bores, ring seat; drill and plug oil passages',
     'Kaba işleme; gerilim giderme; flanş yüzü, delikler (PCD 290\'da 30 x 6,6), burun konisi, gömlek delikleri, halka yuvasının ince işlenmesi; yağ kanallarını delip tapalama', 'CMM; flange flatness'),
    ('planetary case P101', 60, 'Shrink in the steel seat liners (heat the case, TBR fit from step 3.5), finish bore the liners in one setup',
     'Çelik yuva gömleklerinin sıcak geçirilmesi (gövde ısıtılarak, geçme 3.5\'ten TBR), gömleklerin tek bağlamada ince delinmesi', 'liner bore coaxiality'),
    ('planetary case P101', 70, 'Install self-locking helical coil inserts; proof pressure test of the oil passages (1650 kPa, TBR)', 'Kendinden kilitli helisel tel insertlerin takılması; yağ kanallarının basınç testi (1650 kPa, TBR)', 'no leak'),
    ('planetary case P101', 80, 'Conversion coat inside and outside; prime and topcoat outside (masking the faces and bores); serialize', 'İçte ve dışta dönüşüm kaplaması; dışta astar ve son kat (yüzler ve delikler maskeli); seri numarası', 'coating record'),
    ('PT output shaft F212', 10, 'AISI 4340 VAR forged hollow (AMS 6414), grain along the axis', 'AISI 4340 VAR dövme boş mil (AMS 6414), lif ekseni boyunca', 'UT class AA (AMS 2630)'),
    ('PT output shaft F212', 20, 'Rough machine the tube and the integral flanges with stock (no welds)', 'Boru ve yekpare flanşların paylı kaba işlenmesi (kaynaksız)', '-'),
    ('PT output shaft F212', 30, 'Quench and temper to 1240 MPa (AMS 2759/1) with a test coupon', "Test kuponuyla 1240 MPa'ya su verme ve menevişleme (AMS 2759/1)", 'coupon tensile and hardness'),
    ('PT output shaft F212', 40, 'Finish machine the 1.5 mm wall and the tube-to-flange transitions', '1,5 mm duvarın ve borudan flanşa geçişlerin son işlenmesi', 'wall thickness map, transition radius'),
    ('PT output shaft F212', 50, 'Shot peen the tube-to-flange transitions (AMS 2432)', 'Borudan flanşa geçişlerin bilye püskürtülmesi (AMS 2432)', 'Almen strip intensity and coverage'),
    ('PT output shaft F212', 60, 'Eddy current of the tube and the transitions (NASA-STD-5009C sizes; procedure demonstrated on the 1.5 mm wall)', 'Boru ve geçişlerin girdap akımı muayenesi (NASA-STD-5009C boyları; yöntem 1,5 mm duvarda gösterilir)', 'no indications'),
    ('PT output shaft F212', 70, 'Balance, zinc-nickel outside with bake (PR-14), serialize', 'Balans, dışa fırınlamalı çinko-nikel (PR-14), seri numarası', 'balance grade, coating thickness'),
]

# id, component_en, component_tr, requirement, key_values, status
COMPONENTS = [
    ('C-01', 'Rolling bearings (NU1024 x2, QJ1024, NU2209 x2, NU2210 x2, QJ209, QJ210, 6305 x2, 6202 x2, 6203 x2) and the planet roller sets',
     'Rulmanlar (NU1024 x2, QJ1024, NU2209 x2, NU2210 x2, QJ209, QJ210, 6305 x2, 6202 x2, 6203 x2) ve planet makara setleri',
     'STR-02', 'aerospace grade, M50 VIM-VAR (AMS 6491) rings and rolling elements, M50NiL (AMS 6278) for the propeller bearings (hoop stress of the fits); '
     'silver-plated machined cages; the internal geometry of step 2.5; planet set speed limit at least 6,020 rpm at 110% (ICD)', 'TBR (supplier)'),
    ('C-02', 'Carbon face seals: propeller shaft, input, generator pad', 'Karbon yüz contaları: pervane mili, giriş, jeneratör pedi',
     'ENV-03, LUB-05', 'mating ring with a hard coating (tungsten carbide, HVOF, TBR); dust excluder lip on the propeller seal (ENV-03); '
     'leakage at most 2 cm3/h (TBR)', 'TBR (supplier)'),
    ('C-03', 'O-rings', 'O-halkalar', 'LUB-01, ENV-01',
     'low-temperature fluorocarbon (AMS 7287 type, -40 degC with MIL-PRF-23699), AS568 sizes', 'TBR'),
    ('C-04', 'Magnetic chip detectors (2) with self-closing valves and electrical indication', 'Kendinden kapanan valfli ve elektrik uyarılı manyetik talaş dedektörleri (2)',
     'LUB-05, MNT-02', 'in the planetary and first-stage sumps, reachable without removing the RGB', 'TBR'),
    ('C-05', 'Speed pickups: Np x2 on the input pinion (control and cross-check), Nr x2 on the propeller shaft P103 at z 400 (TBR), with two phonic wheels; the protection Np is the core PT-rotor signal (ICD-36)', "Hız algılayıcılar: giriş pinyonunda Np x2 (kontrol ve çapraz kontrol), pervane mili P103 üzerinde z 400'de Nr x2 (TBR), iki dişli tekerle; koruma Np'si çekirdeğin PT rotoru sinyali (ICD-36)",
     'CTL-02, SAF-03', 'variable reluctance; separate connectors and harness routes for the control and protection channels; control and protection read different phonic wheels; phonic wheels in 4340 (TBR); qualified with the harness for EMI and lightning (14 CFR 33.28(b)(2))', 'TBR'),
    ('C-06', 'Condition monitoring: accelerometers A1-A3, inline oil debris monitor, oil pressure and temperature, filter differential pressure, the PT-shaft tunnel air temperature sensor (step 2.2)',
     'Durum izleme: A1-A3 ivmeölçerleri, hat içi yağ talaş izleyicisi, yağ basıncı ve sıcaklığı, filtre fark basıncı, PT mili tüneli hava sıcaklığı algılayıcısı (adım 2.2)', 'CTL-03, LUB-05', 'positions of step 2.10; tunnel sensor of step 2.2', 'TBR'),
    ('C-07', 'Thermostatic valve at the RGB inlet', 'RGB girişindeki termostatik valf', 'LUB-02, LUB-04',
     'modulating (wax element), starts to open at 60 degC and full flow through the cooler by about 70 degC (band TBR); '
     'it sets the inlet on cold days (about 60 degC at -20 and -40 degC ambient at maximum continuous power); the 3.2 model '
     'treats it as on/off, so a valve with a stated band is required; fails to the cooler-open position', 'TBR'),
    ('C-08', 'Oil filter 3 um with bypass valve (170 kPa) and impending-bypass indication (120 kPa)', '3 um yağ filtresi, baypas valfi (170 kPa) ve tıkanma öncesi uyarısı (120 kPa)',
     'LUB-05', 'clean drop 35 kPa at 30 L/min, 100 degC (step 3.2)', 'TBR (supplier)'),
    ('C-09', 'Pressure regulating valve (550 kPa) and pump relief valve (1100 kPa)', 'Basınç ayar valfi (550 kPa) ve pompa emniyet valfi (1100 kPa)', 'LUB-03', 'step 3.2 values', 'TBR'),
    ('C-10', 'Low-oil-pressure switch: opens the mist valve and sends the 75% MCP limit to the FADEC', 'Düşük yağ basıncı anahtarı: sis valfini açar ve FADEC\'e %75 MCP sınırını gönderir',
     'LUB-07', 'set point TBR (3.10); redundant contacts (TBR)', 'TBR'),
    ('C-11', 'Mist shut-off and mixing valve', 'Sis kesme ve karışım valfi', 'LUB-07', 'opened by the C-10 switch; bleed air 10-20 SCFM at <= 100 degC', 'TBR (supplier)'),
    ('C-12', 'Fasteners and inserts', 'Bağlantı elemanları ve insertler', 'STR-04', '170 fasteners in 12 joints, 1.31 kg bottom-up (A286; 1.96 kg with x1.5) '
     'against the 5.21 kg allowance; self-locking helical coil inserts (NASM21209) in the castings; lockwire or self-locking nuts', 'TBR (3.9)'),
    ('C-13', 'Steel seat liners for the bearing outer rings in the castings', 'Dökümlerde rulman dış bilezikleri için çelik yuva gömlekleri', 'STR-04, DYN-05',
     '13 liners, +1.28 kg not in the roll-up; the shrink fit loosens by 0.19 mm (NU1024 liner) from 20 to 132 degC and tightens by 0.10 mm at -40 degC: fit and hoop stress in 3.5', 'TBR (3.5)'),
    ('C-14', 'External hoses to the cooler', 'Soğutucuya giden dış hortumlar', 'SAF-05', 'PTFE hose with CRES braid and fire sleeve, fire resistant (AS1055)', 'TBR'),
    ('C-15', 'Oil tank (airframe side)', 'Yağ tankı (uçak tarafı)', 'SAF-05, LUB-06', 'fireproof by construction (CRES or titanium sheet) or by a fire blanket; 6.8 L', 'TBR'),
]


def write(name, header, rows):
    with open(os.path.join(HERE, name), 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        w.writerow(header)
        for r in rows:
            w.writerow(r)
    print('%d rows written to %s' % (len(rows), name))


def main():
    write('materials_v1.csv', ['key', 'parts', 'material', 'specification', 'condition_en', 'condition_tr', 'hardness_case',
                               'finish', 'ndt', 'protection_en', 'protection_tr', 'requirements', 'status'], MATERIALS)
    write('processes_v1.csv', ['id', 'process_en', 'process_tr', 'specification', 'applies_to', 'key_values', 'status'], PROCESSES)
    write('routes_v1.csv', ['part', 'op', 'operation_en', 'operation_tr', 'gate'], ROUTES)
    write('components_v1.csv', ['id', 'component_en', 'component_tr', 'requirement', 'key_values', 'status'], COMPONENTS)


if __name__ == '__main__':
    main()
