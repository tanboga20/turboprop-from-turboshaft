# Manufacturing data (step 3.4)

The basis is Section 3.4 of the Phase 3 report. Values are TBR unless the table marks them set. Specification numbers are checked against the current issue when the drawings of step 3.9 are released. Oil: MIL-PRF-23699 only (Hamit's decision).

| File | Contents |
| --- | --- |
| `bom_v1.csv` | Bill of materials: part number, part, description, quantity, make or buy, material key, mass and how the mass enters the SYS-06 roll-up (`CATIA`, `weighed 3.2`, `allowance 3.1`; `estimate 3.4` and `in parent` are not in the roll-up; `outside SYS-06`). Written by `calc/manufacturing/run_step34.m` |
| `materials_v1.csv` | One row per material key: specification, heat treatment, hardness and case depth, finish, inspection, protection, parts, requirements |
| `processes_v1.csv` | The process specifications the drawings call up, with their key values |
| `routes_v1.csv` | Manufacturing routes of the planet gear, the carrier with the propeller shaft and the planetary case, with the inspection gate of each operation |
| `components_v1.csv` | Bought and standard parts: bearings, seals, O-rings, chip detectors, speed pickups, sensors, valves, filter, fasteners, seat liners, hoses, tank |
| `make_mfg.py` | Writes the four text tables: `python manufacturing/make_mfg.py` |

Part numbers: `RGB-P1xx` planetary module, `F2xx` first stage, `A3xx` accessories, `L4xx` lubrication, `E5xx` LUB-07 mist system, `S6xx` standard parts, `H7xx` condition monitoring, `X8xx` outside SYS-06.

## Tolerances and fits (step 3.8)

Written by `calc/tolerances/run_step38.m` (Section 3.8 of the Phase 3 report). Drawing standard ASME Y14.5-2018 (metric), ISO 286 fits, ISO 1328-1:2013 gear accuracy, ISO 4156 splines.

| File | Contents |
| --- | --- |
| `drawing_checklist_v1.csv` | Step 3.9: every value placed on the four representative drawings (planet P107, carrier P103, case P101, assembly) with its source table and row (cad/scripts/make_dwg39.py) |
| `tolerances_v1.csv` | Tolerance and fits table for the 3.9 drawings: one row per callout (72), part, feature and callout in EN and TR, value, basis |
| `gdt_v1.csv` | Datums and geometric tolerances per part (E1) |
| `thermal_map_v1.csv` | Part temperatures per operating state (E2, lumped, TBR) |
| `gear_accuracy_v1.csv` | ISO 1328-1 tolerances, runout and tooth thickness allowances per gear (E6) |
| `stack_backlash_v1.csv`, `stack_kgamma_v1.csv`, `stack_axial_v1.csv` | Stack-ups (E3): backlash with temperature, K_gamma with the drawing tolerances, catcher-lip and retention tube gaps |
| `fits_bearings_v1.csv`, `fits_liners_v1.csv`, `fits_ring_seat_v1.csv`, `fits_splines_v1.csv` | Fits at temperature (E4, E5) |

# Üretim verileri (adım 3.4)

Esaslar Faz 3 raporunun 3.4 bölümünde. Tabloda set olarak işaretlenmeyen değerler TBR. Şartname numaraları 3.9 resimleri yayımlanırken güncel baskıya göre kontrol ediliyor. Yağ: yalnız MIL-PRF-23699 (Hamit'in kararı).

`bom_v1.csv` malzeme listesi (`calc/manufacturing/run_step34.m` yazar; her satırın kütlesinin SYS-06 toplamasına nasıl girdiği `basis` sütununda); `materials_v1.csv` malzeme anahtarı başına şartname, ısıl işlem, sertlik ve sementasyon derinliği, yüzey, muayene, koruma; `processes_v1.csv` resimlerin çağırdığı proses şartnameleri; `routes_v1.csv` planet dişlisi, pervane milli taşıyıcı ve planet gövdesinin üretim rotaları; `components_v1.csv` satın alınan ve standart parçalar. Dört metin tablosunu `python manufacturing/make_mfg.py` yazar.

Toleranslar ve geçmeler (adım 3.8): `calc/tolerances/run_step38.m` yazar. `tolerances_v1.csv` 3.9 resimleri için tolerans ve geçme tablosu (72 belirtim, EN ve TR); `gdt_v1.csv` referanslar ve geometrik toleranslar; `thermal_map_v1.csv` sıcaklık haritası; `gear_accuracy_v1.csv` dişli doğruluğu; `stack_backlash_v1.csv`, `stack_kgamma_v1.csv`, `stack_axial_v1.csv` tolerans zincirleri; `fits_bearings_v1.csv`, `fits_liners_v1.csv`, `fits_ring_seat_v1.csv`, `fits_splines_v1.csv` sıcaklıkta geçmeler. Adım 3.9: `drawing_checklist_v1.csv` dört temsilî resimdeki her değerin kaynak tablosu ve satırı.
