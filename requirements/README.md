# requirements

**EN.** Requirements and the traceability matrix. Version 1 was written in Phase 0, step 0.4, and is explained in Section 5 of the Phase 0 report, together with the derived values behind the numbers and the decisions taken at the system requirements review (SRR). Version 2 added what Phase 1 decided and found (steps 1.1 to 1.4) and was set at the preliminary design review (PDR); Section 5 of the Phase 1 report explains every change. Version 3 is the current list. It adds what Phase 2 (detail design, steps 2.1 to 2.11) decided and found and was approved by Hamit at the critical design review (CDR); Section 2.11 of the Phase 2 report explains every change. Certification sources are EASA CS-E and FAA 14 CFR Part 33.

| File | Content |
| --- | --- |
| `requirements_v4.csv` | Current list (end of Phase 3): 69 system requirements, one per row, in Turkish and English; 3 are new (SYS-11, STR-11, CTL-04) and 10 changed since v3 (SYS-06, SAF-03, DYN-04, LUB-01, LUB-02, LUB-06, LUB-07, PIF-01, PIF-05, MNT-01). Status: Agreed 28, TBR 34, TBD 7 |
| `needs_assumptions_v4.csv` | The 8 needs and 10 assumptions; A-08 changed (MIL-PRF-23699 only, ground preheat at cold bases) |
| `compliance_final.csv` | Final compliance matrix: verdict and evidence of every v4 requirement after Phase 3 (TR and EN) and how it is closed: `shown` by analysis, inspection or design, `test` a planned test or demonstration (`planned_tests`), `ICD` an interface value from a partner (`icd_items`). Verdicts: met 34, partial 19, open 7, tbd 9, risk 0 |
| `make_v4.py` | Writes the v4 files and the final matrix from v3, the requirement rows of `changes_phase3.csv` and `verification_v1.csv` |
| `requirements_v3.csv` | List at the CDR: 66 system requirements, one per row, in Turkish and English; 1 is new and 12 changed since v2 |
| `needs_assumptions_v3.csv` | The 8 customer needs (N) and 10 assumptions (A) the requirements come from; unchanged since v2 |
| `compliance_cdr.csv` | Compliance matrix at the CDR: the Phase 2 status of every v3 requirement, with its evidence in Turkish and English |
| `changes_phase3.csv` | Phase 3 changes to v3, each with its step, date, old and new value, who decided and why (TR and EN); `make_v4.py` folds the requirement changes into v4. So far: SYS-06 100 → 110 kg, Agreed → TBR (Hamit's decision in step 3.1); LUB-07 30 min goal → at least 6 min at 75% MCP with an emergency air-oil mist system, shall, Agreed (Hamit's decision in step 3.2) |
| `icd_v1.csv`, `make_icd.py` | Interface control document of step 3.3: 34 values taken from or set for the aircraft, nacelle, propeller and core makers and the suppliers, with the value assumed, where it is used, its sensitivity, what is needed and the status (TBD, TBR, set, open), in Turkish and English; `icd_sensitivity_v1.csv` holds the sensitivity runs (calc/interfaces) |
| `verification_v1.csv`, `test_plan_v1.csv`, `test_cell_v1.csv`, `make_verification.py` | Step 3.11: verification matrix (69 requirements: method, planned tests, status after Phase 3 and its evidence in Turkish and English) and the plan of 25 tests (coupon, inspection, rig, engine, demonstration) with rule, article, measurements, pass criterion (TR and EN), sequence and measuring points; the 9 measuring points of the water-brake test cell. The script checks that every requirement verified by test has a planned test and every engine test has measuring points. All tests are planned only |
| `make_v3.py` | Writes version 3 and the CDR matrix from version 2 and one list of changes, so that every change can be reviewed in one place |
| `requirements_v2.csv`, `needs_assumptions_v2.csv`, `compliance_pdr.csv` | Version 2 and its compliance matrix as set at the PDR, kept unchanged |
| `requirements_v1.csv`, `needs_assumptions_v1.csv` | Version 1 as agreed at the SRR: 53 requirements, kept unchanged for traceability |
| `check_requirements.py` | Checks IDs, codes and cross-references, the changes from the previous version and the compliance matrix, then prints a summary |

Columns of the requirement files: `id`, `group`, `type` (`shall` or `goal`), `title_tr` and `title_en`, `text_tr` and `text_en`, `source_tr` and `source_en` (the need, assumption, requirement or document each requirement comes from), `source_type`, `rationale_tr` and `rationale_en`, `verification`, `verification_phase`, `allocation` and `status`. A cell with several codes separates them with `;`.

| Column | Codes |
| --- | --- |
| `group` | `SYS` system, `LD` load cases, `SAF` safety and certification, `DYN` dynamics, `STR` strength and life, `LUB` lubrication, `ACC` accessory drives, `PIF` propeller interface, `CTL` control and monitoring, `MNT` maintainability, `ENV` environment |
| `source_type` | `cus` customer, `crt` CS-E or Part 33, `ref` reference engine (CT7-9, PT6A-67A), `acr` aircraft rule (14 CFR Parts 23, 25 and 29), `asm` assumption or own calculation |
| `allocation` | `shf` shafts (power turbine and RGB input), `ger` gears, `brg` bearings, `prs` propeller shaft and retention, `hsg` housing, `lub` lubrication, `acc` accessory drives, `pif` propeller interface (flange, pitch oil, control units), `sen` sensors |
| `verification` | `A` analysis, `T` test, `I` inspection, `D` demonstration |
| `verification_phase` | `P1` to `P3`, the project phase in which the requirement is verified |
| `status` | `Agreed` firm from its source or a review decision (SRR, PDR or one of Hamit's decisions), `TBR` value provisional, `TBD` value not known yet |
| `v2_change`, `v3_change`, `v4_change` | Only in the v2, v3 and v4 files: `new` (not in the previous version), `changed` (text, source, status or codes differ from it) or empty (identical to it) |

Columns of `compliance_pdr.csv` and `compliance_cdr.csv`: `id`, `verdict`, `evidence_tr` and `evidence_en` (the result of the phase, or why there is none yet). Verdicts: `met` shown in the phase for everything the requirement covers (at the CDR: by analysis or inspection, with the planned Phase 3 tests still to come); `partial` shown for part of it, or only under a named condition; `risk` the result does not meet it yet and an action is set; `open` not checked yet, planned for a later phase; `tbd` waits for a value from the aircraft, propeller or core maker, or from the customer.

Run the check from the repository root with Python 3: `python requirements/check_requirements.py` checks v4, `python requirements/check_requirements.py v3` (or `v2`, `v1`) an earlier version. `python requirements/make_v4.py` writes the v4 files and `compliance_final.csv` again, `python requirements/make_v3.py` the v3 files. The files are UTF-8; in Excel, open them through Data > From Text/CSV so that the Turkish characters show correctly.

**TR.** Gereksinimler ve izlenebilirlik matrisi. Sürüm 1, Faz 0'ın 0.4 adımında yazıldı; açıklamaları Faz 0 raporunun 5. bölümünde, sayıların dayandığı türetilmiş değerler ve sistem gereksinimleri gözden geçirmesinde (SRR) verilen kararlarla birlikte. Sürüm 2, Faz 1'de (1.1–1.4 adımları) verilen kararları ve bulunanları ekledi; ön tasarım gözden geçirmesinde (PDR) kesinleşti. Her değişiklik Faz 1 raporunun 5. bölümünde açıklanıyor. Güncel liste sürüm 3. Faz 2'de (detay tasarım, 2.1–2.11 adımları) verilen kararları ve bulunanları ekliyor; kritik tasarım gözden geçirmesinde (CDR) Hamit onayladı; her değişiklik Faz 2 raporunun 2.11 bölümünde açıklanıyor. Sertifikasyon kaynakları EASA CS-E ve FAA 14 CFR Part 33.

| Dosya | İçerik |
| --- | --- |
| `requirements_v4.csv` | Güncel liste (Faz 3 sonu): 69 sistem gereksinimi, her satırda bir tane, Türkçe ve İngilizce; v3'e göre 3'ü yeni (SYS-11, STR-11, CTL-04), 10'u değişti (SYS-06, SAF-03, DYN-04, LUB-01, LUB-02, LUB-06, LUB-07, PIF-01, PIF-05, MNT-01). Durum: Agreed 28, TBR 34, TBD 7 |
| `needs_assumptions_v4.csv` | 8 ihtiyaç ve 10 varsayım; A-08 değişti (yalnız MIL-PRF-23699, soğuk üslerde yer ön ısıtması) |
| `compliance_final.csv` | Final uyum matrisi: her v4 gereksiniminin Faz 3 sonrası hükmü ve kanıtı (TR ve EN) ve nasıl kapandığı: `shown` analiz, inceleme ya da tasarımla gösterildi, `test` planlı bir test ya da gösterim (`planned_tests`), `ICD` bir ortaktan gelecek arayüz değeri (`icd_items`). Hükümler: met 34, partial 19, open 7, tbd 9, risk 0 |
| `make_v4.py` | v4 dosyalarını ve final matrisi v3'ten, `changes_phase3.csv`'nin gereksinim satırlarından ve `verification_v1.csv`'den yazar |
| `requirements_v3.csv` | CDR'deki liste: 66 sistem gereksinimi, her satırda bir tane, Türkçe ve İngilizce; v2'ye göre 1'i yeni, 12'si değişti |
| `needs_assumptions_v3.csv` | Gereksinimlerin türediği 8 müşteri ihtiyacı (N) ve 10 varsayım (A); v2'den değişmedi |
| `compliance_cdr.csv` | CDR'deki uyum matrisi: her v3 gereksiniminin Faz 2 durumu ve kanıtı, Türkçe ve İngilizce |
| `changes_phase3.csv` | Faz 3'te v3'e yapılan değişiklikler; her biri adımı, tarihi, eski ve yeni değeri, kimin karar verdiği ve nedeniyle (TR ve EN); `make_v4.py` gereksinim değişikliklerini v4'e katıyor. Şimdiye kadar: SYS-06 100 → 110 kg, Agreed → TBR (3.1'de Hamit'in kararı); LUB-07 30 dk hedefi → acil hava-yağ sisi sistemiyle %75 MCP'de en az 6 dk, shall, Agreed (3.2'de Hamit'in kararı) |
| `icd_v1.csv`, `make_icd.py` | 3.3 adımının arayüz kontrol belgesi: uçak, nasel, pervane ve çekirdek üreticilerinden ve tedarikçilerden alınan ya da onlar için belirlenen 34 değer; varsayılan değer, kullanıldığı yer, duyarlılık, gereken bilgi ve durum (TBD, TBR, set, open), Türkçe ve İngilizce; duyarlılık çalıştırmaları `icd_sensitivity_v1.csv` içinde (calc/interfaces) |
| `verification_v1.csv`, `test_plan_v1.csv`, `test_cell_v1.csv`, `make_verification.py` | 3.11 adımı: doğrulama matrisi (69 gereksinim: yöntem, planlı testler, Faz 3 sonrası durum ve Türkçe ve İngilizce kanıtı) ve 25 testlik plan (numune, muayene, düzenek, motor, gösterim); kural, test parçası, ölçümler, geçme ölçütü (TR ve EN), sıra ve ölçüm noktalarıyla; su frenli test hücresinin 9 ölçüm noktası. Betik, testle doğrulanan her gereksinimin planlı bir testi, her motor testinin ölçüm noktaları olduğunu kontrol eder. Testlerin hepsi yalnız planlı |
| `make_v3.py` | Sürüm 3'ü ve CDR matrisini sürüm 2'den ve tek bir değişiklik listesinden yazar; böylece her değişiklik tek yerde incelenebilir |
| `requirements_v2.csv`, `needs_assumptions_v2.csv` | PDR'de kesinleşen sürüm 2; v1'e göre 12'si yeni, 10'u değişmişti |
| `requirements_v1.csv`, `needs_assumptions_v1.csv` | SRR'de kabul edilen sürüm 1: 53 gereksinim, izlenebilirlik için değiştirilmeden saklanıyor |
| `compliance_pdr.csv` | PDR'deki uyum matrisi: her v2 gereksiniminin Faz 1 durumu ve kanıtı, Türkçe ve İngilizce |
| `check_requirements.py` | Kimlikleri, kodları, çapraz başvuruları, önceki sürüme göre değişiklikleri ve uyum matrisini kontrol eder, ardından bir özet yazar |

Gereksinim dosyalarının sütunları: `id`, `group`, `type` (`shall` zorunlu, `goal` hedef), `title_tr` ve `title_en`, `text_tr` ve `text_en`, `source_tr` ve `source_en` (gereksinimin türediği ihtiyaç, varsayım, gereksinim ya da belge), `source_type`, `rationale_tr` ve `rationale_en` (gerekçe), `verification`, `verification_phase`, `allocation` ve `status`. Birden çok kod içeren hücrede kodlar `;` ile ayrılır.

| Sütun | Kodlar |
| --- | --- |
| `group` | `SYS` sistem, `LD` yük durumları, `SAF` emniyet ve sertifikasyon, `DYN` dinamik, `STR` mukavemet ve ömür, `LUB` yağlama, `ACC` aksesuar tahrikleri, `PIF` pervane arayüzü, `CTL` kontrol ve izleme, `MNT` bakım, `ENV` çevre |
| `source_type` | `cus` müşteri, `crt` CS-E ya da Part 33, `ref` referans motor (CT7-9, PT6A-67A), `acr` uçak kuralı (14 CFR Part 23, 25 ve 29), `asm` varsayım ya da kendi hesabımız |
| `allocation` | `shf` miller (güç türbini ve RGB girişi), `ger` dişliler, `brg` yataklar, `prs` pervane mili ve tutuşu, `hsg` gövde, `lub` yağlama, `acc` aksesuar tahrikleri, `pif` pervane arayüzü (flanş, hatve yağı, kontrol üniteleri), `sen` sensörler |
| `verification` | `A` analiz, `T` test, `I` inceleme, `D` gösterim |
| `verification_phase` | `P1`–`P3`, gereksinimin doğrulanacağı proje fazı (raporda F1–F3) |
| `status` | `Agreed` kaynağıyla ya da bir gözden geçirme kararıyla (SRR, PDR ya da Hamit'in bir kararı) kesin (raporda Kabul), `TBR` değer geçici, `TBD` değer henüz yok |
| `v2_change`, `v3_change`, `v4_change` | Yalnız v2, v3 ve v4 dosyalarında: `new` yeni (önceki sürümde yok), `changed` değişti (metin, kaynak, durum ya da kodlar öncekinden farklı), boş (öncekiyle aynı) |

`compliance_pdr.csv` ve `compliance_cdr.csv` sütunları: `id`, `verdict` (hüküm), `evidence_tr` ve `evidence_en` (fazın sonucu ya da henüz neden olmadığı). Hükümler: `met` gereksinimin kapsadığı her şey için o fazda gösterildi (CDR'de analiz ya da incelemeyle; planlanan Faz 3 testleri ayrıca yapılacak); `partial` bir kısmı için ya da yalnız adı konmuş bir koşulla gösterildi; `risk` sonuç henüz karşılamıyor ve bir eylem belirlendi; `open` henüz kontrol edilmedi, sonraki bir fazda; `tbd` uçak, pervane ya da çekirdek üreticisinden ya da müşteriden bir değer bekliyor.

Kontrol, depo kökünden Python 3 ile çalışır: `python requirements/check_requirements.py` v4'ü, `python requirements/check_requirements.py v3` (ya da `v2`, `v1`) önceki bir sürümü kontrol eder. `python requirements/make_v4.py` v4 dosyalarını ve `compliance_final.csv`'yi, `python requirements/make_v3.py` v3 dosyalarını yeniden yazar. Dosyalar UTF-8; Excel'de Türkçe karakterlerin doğru görünmesi için Veri > Metinden/CSV'den yoluyla açılmalı.
