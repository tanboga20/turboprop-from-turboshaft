# Maintenance data (step 3.10)

**EN.** The basis is Section 3.10 of the Phase 3 report. Times are estimates from a standard-time model and the HUMS thresholds come from a synthetic signal: both are TBR until the maintainability demonstration and the engine test of step 3.11.

| File | Contents |
| --- | --- |
| `mnt_tasks_v1.csv` | Maintenance tasks step by step (TR and EN): T01 RGB module removal and installation on the engine (MNT-01), T02 planetary module change and T03 first-stage and accessory module (shop), T04 line tasks with the RGB installed (MNT-02: borescope, chip detectors, oil sample, filter, sensors, accessories); counts of fasteners, connectors and lines, minutes to remove and install, people, the ICA items of `safety/ica_items_v1.csv` each step carries out |
| `make_mnt.py` | Writes `mnt_tasks_v1.csv` from the standard-time model (elemental minutes per fastener, connector, line, lift and check) and prints the totals: `python maintenance/make_mnt.py` |
| `hums_thresholds_v1.csv` | HUMS condition indicators (FM4, NA4, sideband energy, envelope ENV): definition (TR and EN), the fault each looks for, baseline mean and spread, caution and alarm thresholds, the smallest seeded fault that reaches them. Written by `calc/hums/run_step310.m` |

**TR.** Esaslar Faz 3 raporunun 3.10 bölümünde. Süreler bir standart zaman modelinden tahmin, HUMS eşikleri sentetik bir sinyalden: ikisi de 3.11 adımının bakım gösterimi ve motor testine kadar TBR.

| Dosya | İçerik |
| --- | --- |
| `mnt_tasks_v1.csv` | Adım adım bakım görevleri (TR ve EN): T01 RGB modülünün motordan sökülüp takılması (MNT-01), T02 planet modülü değişimi ve T03 birinci kademe ve aksesuar modülü (atölye), T04 RGB takılıyken hat görevleri (MNT-02: boroskop, talaş dedektörleri, yağ numunesi, filtre, algılayıcılar, aksesuarlar); cıvata, konektör ve hat sayıları, sökme ve takma dakikaları, kişi sayısı, her adımın yerine getirdiği `safety/ica_items_v1.csv` maddeleri |
| `make_mnt.py` | `mnt_tasks_v1.csv` dosyasını standart zaman modelinden (cıvata, konektör, hat, kaldırma ve kontrol başına dakika) yazar ve toplamları basar: `python maintenance/make_mnt.py` |
| `hums_thresholds_v1.csv` | HUMS durum göstergeleri (FM4, NA4, yan bant enerjisi, zarf ENV): tanım (TR ve EN), aradığı hata, temel ortalama ve yayılım, dikkat ve alarm eşikleri, onlara ulaşan en küçük ekilmiş hata. `calc/hums/run_step310.m` yazar |
