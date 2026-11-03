# Comparison with the CT7-9 and the PT6A-67A (step 3.12)

**EN.** The basis is Section 3.12 of the Phase 3 report. Neither type certificate data sheet gives the gearbox mass, so it is derived from the dry weights of the same data sheet and marked as derived: CT7-9B/C 365.1 kg minus the CT7-2A turboshaft 194.6 kg = 170.5 kg (gearbox with its accessory pads, drive shaft and front-drive structure; an upper bound), PT6A-67A 57–72 kg from the PT6A-66 / -67A weight and torque difference with gearbox mass scaling as torque^0.75–1.0.

| File | Contents |
| --- | --- |
| `comparison_v1.csv` | One row per quantity (ratio, power, torque, gearbox mass, power and torque density, CT7-9 scaled to our torque, layout, accessories, size, efficiency, heat into the oil, oil system, TBO, engine dry mass, payload cost on the Heron TP), Turkish and English, with the basis of each value |
| `sources_v1.csv` | The pages the values come from (EASA TCDS IM.E.010 and IM.E.008, GE, Basler Turbo, IAI) |
| `make_comparison.py` | Writes both tables and `docs/figures/step312/rgb_mass_en.png` / `_tr.png`, with self-checks (speed ratio, torques, mass split): `python comparison/make_comparison.py` (matplotlib) |

**TR.** Esaslar Faz 3 raporunun 3.12 bölümünde. İki tip sertifikası veri sayfası da dişli kutusu kütlesini vermiyor; bu yüzden kütle aynı veri sayfasının kuru ağırlıklarından türetiliyor ve türetilmiş diye işaretleniyor: CT7-9B/C 365,1 kg eksi CT7-2A turboşaft 194,6 kg = 170,5 kg (aksesuar pedleri, tahrik mili ve önden tahrik yapısıyla birlikte dişli kutusu; üst sınır), PT6A-67A için PT6A-66 / -67A ağırlık ve tork farkından, dişli kutusu kütlesinin torkun 0,75–1,0 kuvvetiyle ölçeklendiği varsayımıyla 57–72 kg.

| Dosya | İçerik |
| --- | --- |
| `comparison_v1.csv` | Her büyüklük için bir satır (oran, güç, tork, dişli kutusu kütlesi, güç ve tork yoğunluğu, torkumuza ölçeklenmiş CT7-9, düzen, aksesuarlar, boyut, verim, yağa giden ısı, yağ sistemi, TBO, motor kuru kütlesi, Heron TP'de faydalı yük bedeli), Türkçe ve İngilizce, her değerin dayanağıyla |
| `sources_v1.csv` | Değerlerin geldiği sayfalar (EASA TCDS IM.E.010 ve IM.E.008, GE, Basler Turbo, IAI) |
| `make_comparison.py` | İki tabloyu ve `docs/figures/step312/rgb_mass_en.png` / `_tr.png` grafiğini yazar, öz kontrollerle (devir oranı, torklar, kütle dağılımı): `python comparison/make_comparison.py` (matplotlib) |
