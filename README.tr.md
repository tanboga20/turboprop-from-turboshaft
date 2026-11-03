[English](README.md) | **Türkçe**

# Turboprop Güç Aktarımı

1.200 shp'lik bir turbopropun güç aktarım ve aksesuar tahrik sistemlerinin mekanik tasarımı. Kapsam güç türbini milinden pervane flanşına kadar: miller ve yataklar, redüksiyon dişli kutusu (RGB), aksesuar tahrikleri ve yağlama.

Bu, teorik bir öğrenci tasarım çalışmasıdır. Bir uçak motoru tasarım sürecini izler (gereksinimler, konsept karşılaştırmaları, detay tasarım ve analiz, imalat resimleri) ve her aşama resmi bir gözden geçirmeyle kapanır. Hiçbir parça üretilmez; buradaki hiçbir şey gerçek bir uçakta kullanılmak için değildir.

## Senaryo

- **Çekirdek:** T700 sınıfı bir turboşaft gaz üreteci; hazır kabul edilip turboproba dönüştürülüyor. Emsal GE CT7 turboprop ailesi.
- **Müşteri:** Heron TP sınıfı, tek motorlu, itici pervaneli bir İHA.
- **Temel değerler:**

| Büyüklük | Değer | Dayanak |
| --- | --- | --- |
| Güç, sabit (flat-rated) | 1.200 shp (895 kW) | Müşteri sınıfı (Heron TP'deki PT6A-67A) |
| Güç türbini hızı | 22.000 rpm | CT7-9 tip sertifikası veri sayfası |
| Pervane hızı | 1.700 rpm | PT6A-67A tip sertifikası veri sayfası |
| Redüksiyon oranı | ≈12,9:1 | 22.000 / 1.700 |
| Güç türbini torku | ≈389 N·m | 22.000 rpm'de 895 kW |
| Pervane torku | ≈5,03 kN·m | 1.700 rpm'de 895 kW |

## Plan

| Faz | İçerik | Gözden geçirme |
| --- | --- | --- |
| 0 | Literatür, sertifikasyon temeli, gereksinimler ve izlenebilirlik matrisi | SRR |
| 1 | Konsept ve karşılaştırma çalışmaları: kurulum düzeni, RGB mimarisi, yağlama | PDR |
| 2 | Detay tasarım ve analiz: dişliler, miller, yataklar, rotor dinamiği, yağlama | CDR |
| 3 | GD&T resimleri, doğrulama planı, CT7-9 ile karşılaştırma, final raporu | Final gözden geçirme |

**Durum:** Tamamlandı. Dört faz da kapandı (SRR, PDR, CDR ve final gözden geçirme). Gereksinimler v4: 69 gereksinimin 34'ü karşılandı, 19'u kısmen karşılandı, 7'si açık (testler ve ortak değerleri), 9'u bir tedarikçi değeri bekliyor (TBD); riskte olan yok. Tasarım: arkadan tahrikli kurulum, kaçık eksenli helisel birinci kademe ve onu izleyen dört planetli ikinci kademe (31/110 | 45/37/119, 12,93:1), 109,95 kg, %98,71 verim.

**Yöntem:** Gereksinimler, ödünleşimler ve bütün tasarım kararları Hamit Tanboğa'ya aittir. Hesap araçları, CAD betikleri ve rapor taslakları bir yapay zekâ asistanının desteğiyle geliştirildi ve yazar tarafından incelendi; her MATLAB aracı bağımsız bir Python referansıyla kontrol edilir.

**CAD:** CATIA modeli, 3.1–3.5 adımlarının Faz 3 modelidir. Sonraki ayrıntı değişiklikleri (gövde flanşının 308 mm cıvata dairesi, birinci kademe dişlisinin sönüm halkası oluğu, P116–P120 burun parçaları ve OI-16 açık maddesinin kalemleri) hesaplarda ve resim tablolarında var, modelde henüz yok.

## Depo yapısı

| Klasör | İçerik |
| --- | --- |
| [`docs/`](docs/) | Şekiller ve kısa faz notları |
| [`requirements/`](requirements/) | Gereksinimler ve izlenebilirlik matrisi |
| [`manufacturing/`](manufacturing/) | Malzeme listesi, malzemeler, prosesler, üretim rotaları ve standart parçalar (adım 3.4) |
| [`calc/`](calc/) | MATLAB tasarım hesapları: dişliler, miller, yataklar, yağlama |
| [`rotordynamics/`](rotordynamics/) | ROSS ile kurulan Python rotor dinamiği modelleri |
| [`cad/`](cad/) | CAD modelleri ve teknik resimler |

## Veri ve kurallar

- Yalnızca açık kaynaklar: EASA tip sertifikası veri sayfaları, NASA teknik raporları, patentler, ABD Ordusu sahra el kitapları ve üretici broşürleri. Raporlardaki her sayı kaynağını gösterir.
- Birimler SI; kaynaklar shp ve rpm kullandığında bunlar korunur.
- Her rapor ve README Türkçe ve İngilizce yazılır.
