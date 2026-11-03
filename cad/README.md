# cad

**EN.** CAD models and drawings, starting with the layout in Phase 1 and the detail parts in Phase 2. Each part and assembly is kept as a native file plus a STEP export; drawings are PDFs with GD&T to ASME Y14.5 or ISO GPS. Large binary files may move to Git LFS.

Phase 2, step 2.9: the RGB parts are built in CATIA V5 R19 by VBScript from the design values of the calculations, so a model never drifts from its calculation. MATLAB writes the values (`calc/cad_export/cx_export.m` → `params/*.txt`), a script per part reads them and builds, weighs, saves and photographs the part. The basis is Section 2.9 of the Phase 2 report.

| Folder | Content |
| --- | --- |
| `params/` | Design values per part, `key = value`, written by `cx_export` (do not edit) |
| `scripts/` | `catlib.vbs` (shared helpers: parameters, documents, pictures, revolved profiles with fillet arcs, involute spur and helical teeth, hole patterns, prismatic pads and pockets at a z range, part volumes); one script per part (`planet`, `sun`, `ring`, `carrier`, `gear2`, `pinion`, `case`); since step 3.1 `boxcase.vbs` (first-stage case, accessory cover), `revolved.vbs` (shafts, accessory gears, bearing, nut and seal envelopes, quills, nose housing, retention tube, propeller flange placeholder, accessory unit envelopes), `rollers.vbs` (planet roller sets); `assembly.vbs`, `drawing.vbs`, `capture_all.vbs`, `crop_img.py` (cleans the pictures); step 3.9: `make_dwg39.py` (sheet tables from the manufacturing and safety tables, `params/dwg39_*.txt`, and `manufacturing/drawing_checklist_v1.csv`) and `drawing39.vbs` (views, tables, title block: `drawings/<sheet>_39.CATDrawing` and `.pdf` for planet P107, carrier P103, case P101 and the assembly) |
| `parts/`, `step/` | Native CATParts and their STEP AP214 copies (`step/rgb_assembly.stp` is the whole RGB); since step 3.5 the 30 tapped flange holes of the first-stage case are blind, 10 mm deep (through the 12 mm pad they broke onto the wall edge and the body was not a closed solid), and its rear wall is 16 mm (Hamit's mount card A) |
| `assy/` | `rgb_assembly.CATProduct` with the three modules of MNT-01 (`mod_planetary`, `mod_first_stage`, `mod_accessories`) and `mod_equipment` (accessory unit envelopes, not RGB mass); every placement and gear phase comes from `params/assembly.txt`. `part_volumes.csv` (written by every part script) feeds the mass roll-up of `calc/assembly`; `clash_report.csv` is the CATIA clash analysis (step 3.1: 0 clashes, 83 intended contacts) |
| `drawings/` | First drawings (A3, end view and axial section, design data table, title block in English and Turkish) as CATDrawing and PDF; dimensions, tolerances and surface symbols follow in Phase 3 |
| `img/` | Pictures for the reports |
| `anim/` | Animations of the summary report: `export_stl.vbs` writes the parts as STL to `anim/stl/`, `rgb_anim.m` renders the gear train turning at the true speed ratios, the assembly sequence and the shop removal of the modules (step 3.10), `lube_anim.m` the oil jets (jet positions illustrative, flows from step 2.7), `make_webp.py` makes animated WebP files (`stl/` and `out/` are not committed) |

CATIA V5 R19 is a 32-bit program: run the scripts with the 32-bit script host while CATIA is open (no document needed), from the repo root:

```
C:\Windows\SysWOW64\cscript.exe //nologo cad\scripts\planet.vbs <full path of the cad folder>
C:\Windows\SysWOW64\cscript.exe //nologo cad\scripts\assembly.vbs <full path of the cad folder>
C:\Windows\SysWOW64\cscript.exe //nologo cad\scripts\drawing.vbs <full path of the cad folder> case
```

Step 3.1 order: `cx_export` in MATLAB, then the part scripts (`planet`, `sun`, `ring`, `carrier`, `gear2`, `pinion`, `gen_gear`, `case`, `rollers`), `boxcase.vbs <cad folder> fs_case` and `acc_cover`, `revolved.vbs <cad folder>` (all revolved parts, or the names given), and last `assembly.vbs <cad folder>` (add `noclash` to skip the clash analysis). Step 3.2 adds the oil system: `run_step32` in MATLAB, then `revolved.vbs <cad folder> @oil_revolved` (jets, valves, filter, sleeve, pitch tube, chip detectors, the LUB-07 mist accumulator and valve) and `oilroutes.vbs <cad folder>` (tubes and drillings as oil volumes, one part per branch), then `assembly.vbs`; the assembly gets `mod_lubrication` and `mod_lub07_mist`. `python cad/scripts/clash_classes.py` gives every conflict of `assy/clash_report.csv` a class and a reason (`assy/clash_classes.csv`; step 3.2: 149 contacts, 109 intended overlaps, no unintended interference).

Each script closes the documents it opens, and a picture never changes a document, so no "save changes?" question can stop an unattended run. If CATIA stops answering, closing and restarting it loses nothing: every part is on disk and the scripts rebuild everything from `params/`.

**TR.** CAD modelleri ve teknik resimler; Faz 1'de yerleşimle, Faz 2'de detay parçalarla başlıyor. Her parça ve montaj yerel dosya ve STEP çıktısı olarak tutulur; teknik resimler ASME Y14.5 ya da ISO GPS'e göre GD&T içeren PDF'lerdir. Büyük ikili dosyalar Git LFS'e taşınabilir.

Faz 2, 2.9 adımı: RGB parçaları CATIA V5 R19'da, hesapların tasarım değerlerinden VBScript ile oluşturuluyor; böylece bir model hesabından hiç ayrılmıyor. Değerleri MATLAB yazıyor (`calc/cad_export/cx_export.m` → `params/*.txt`); her parçanın betiği bunları okuyup parçayı kuruyor, tartıyor, kaydediyor ve resmini çekiyor. Esaslar Faz 2 raporunun 2.9 bölümünde.

| Klasör | İçerik |
| --- | --- |
| `params/` | Parça başına tasarım değerleri, `anahtar = değer`, `cx_export` yazar (elle değiştirilmez) |
| `scripts/` | `catlib.vbs` (ortak yardımcılar: parametreler, belgeler, resimler, yuvarlatma yaylı döndürülmüş profiller, evolvent düz ve helis dişler, delik dizileri); her parça için bir betik (`planet`, `sun`, `ring`, `carrier`, `gear2`, `pinion`, `case`), `assembly.vbs`, `drawing.vbs`, `capture_all.vbs`, `crop_img.py` (resimleri temizler); adım 3.9: `make_dwg39.py` (pafta tabloları ve `manufacturing/drawing_checklist_v1.csv`) ve `drawing39.vbs` (planet P107, taşıyıcı P103, gövde P101 ve montaj için `drawings/<pafta>_39.CATDrawing` ve `.pdf`) |
| `parts/`, `step/` | CATPart dosyaları ve STEP AP214 kopyaları |
| `assy/` | `rgb_assembly.CATProduct`, MNT-01'in üç modülüyle (`mod_planetary`, `mod_first_stage`, `mod_accessories`) ve `mod_equipment` (aksesuar ünite zarfları, RGB kütlesine girmez); her yerleşim ve dişli fazı `params/assembly.txt`'den. `part_volumes.csv` (her parça betiği yazar) `calc/assembly` kütle toplamasını besliyor; `clash_report.csv` CATIA çakışma analizi (adım 3.1: 0 çakışma, 83 istenen temas). 3.1'den beri yeni betikler: `boxcase.vbs`, `revolved.vbs`, `rollers.vbs`; `step/rgb_assembly.stp` RGB'nin tamamı |
| `drawings/` | İlk teknik resimler (A3, uçtan görünüş ve eksenel kesit, tasarım verileri tablosu, Türkçe ve İngilizce antet) CATDrawing ve PDF olarak; ölçüler, toleranslar ve yüzey işaretleri Faz 3'te |
| `img/` | Raporlar için resimler |
| `anim/` | Özet raporun animasyonları: `export_stl.vbs` parçaları STL olarak `anim/stl/` içine yazar, `rgb_anim.m` dişli takımını gerçek devir oranlarıyla dönerken, montaj sırasını ve modüllerin atölyede sökülmesini (adım 3.10), `lube_anim.m` yağ memelerini çizer (meme yerleri temsilî, debiler 2.7'den), `make_webp.py` hareketli WebP dosyaları yapar (`stl/` ve `out/` commit edilmez) |

CATIA V5 R19 32 bitlik bir program: betikleri CATIA açıkken (belge açık olması gerekmez) 32 bitlik betik çalıştırıcısıyla, depo kökünden çalıştırın (komutlar yukarıda). Her betik açtığı belgeleri kapatıyor ve resim çekmek bir belgeyi hiç değiştirmiyor; böylece "değişiklikler kaydedilsin mi?" sorusu gözetimsiz bir çalıştırmayı durduramıyor. CATIA yanıt vermezse kapatıp yeniden açmak hiçbir şey kaybettirmez: bütün parçalar diskte ve betikler her şeyi `params/` içinden yeniden kuruyor.
