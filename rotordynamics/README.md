# rotordynamics

**EN.** Rotordynamics models of the RGB shafts and the power turbine shaft, built with [ROSS](https://github.com/petrobras/ross) (Rotordynamic Open-Source Software). Phase 2 adds the power turbine shaft and the RGB input shaft, the support stiffness from the housing model and the bearing dampers. The T700 power turbine shaft already runs above its bending critical speed, so this analysis is central to the shaft design.

Step 1.4: `prop_shaft_campbell.py`, the Campbell diagram of the propeller shaft (Section 4 of the Phase 1 report). Results with bearings of 5e7 to 1e9 N/m:

- No forward-whirl critical speed up to 3,000 rpm. At 1,700 rpm the first forward mode is at 3,136 to 4,158 cpm, 1.8 to 2.4 times the running speed.
- The first backward-whirl mode crosses 1 × running speed at 1,403 to 1,677 rpm, in or just below the steady range (1,534–1,715 rpm, SYS-03) and always inside DYN-01's 20% margin. The cause is the propeller's diametral inertia (Id 7.5 kg·m²): its gyroscopic effect pulls the backward mode down.
- Unbalance response with a G6.3 propeller unbalance (2,704 g·mm), bearings 1e8 N/m: on isotropic supports there is no resonance from 200 to 2,600 rpm and the propeller orbit is 7.3 µm at 1,700 rpm. With supports half as stiff in one direction (kyy = kxx / 2) the mode is excited at 1,462 rpm and the orbit reaches 1.08 mm with the 1e3 N·s/m damping of the model. Bearing damping of 3e4 N·s/m brings that peak down to 46 µm, 4.3 times the orbit at 1,700 rpm, and 1e5 N·s/m to 1.6 times (the printout's damping sweep, also for kyy = 0.8 kxx). Phase 2 needs the real support stiffness and a squeeze-film damper on the propeller shaft.
- With a point-mass propeller on very stiff bearings ROSS gives 5,098 cpm against 5,373 rpm from the step 1.3 formula (5% apart), which checks that formula.

The script writes `results/campbell.csv`, `results/crossings.csv`, `results/unbalance.csv`, `results/campbell.png` and `results/unbalance.png` (not committed).

Step 2.1: `step21_reference.py` writes the expected values of the step 2.1 MATLAB tests (`calc/tests/step21_test_cases.csv`, TC18–TC23) from ROSS and closed forms: the Phase 1 model above, and the 120/100 mm shaft chosen in step 2.1 with each bearing in series with a housing seat (ROSS point masses and linked bearing elements). The MATLAB rotor model in `calc/rotor_damper/` matches all 27 values within 0.008%. Section 2.1 of the Phase 2 report explains the result: the backward whirl is solved by a stiffer thin-walled shaft, not by a squeeze-film damper.

**TR.** [ROSS](https://github.com/petrobras/ross) (Rotordynamic Open-Source Software) ile kurulan RGB milleri ve güç türbini mili rotor dinamiği modelleri. Faz 2'de güç türbini mili ve RGB giriş mili, gövde modelinden gelen yatak yuvası rijitlikleri ve yatak sönümleyicileri eklenecek. T700'ün güç türbini mili zaten eğilme kritik hızının üzerinde çalıştığı için bu analiz mil tasarımının merkezinde.

1.4 adımı: `prop_shaft_campbell.py`, pervane milinin Campbell diyagramı (Faz 1 raporunun 4. bölümü). 5e7 ile 1e9 N/m arası yatak rijitlikleriyle sonuçlar:

- 3.000 rpm'e kadar ileri yönlü (forward whirl) kritik hız yok. 1.700 rpm'de ilk ileri yönlü mod 3.136 ile 4.158 cpm arasında, yani dönme hızının 1,8 ile 2,4 katı.
- İlk geri yönlü (backward whirl) mod 1 × dönme hızı çizgisini 1.403 ile 1.677 rpm arasında kesiyor: sürekli hız aralığının (1.534–1.715 rpm, SYS-03) içinde ya da hemen altında, her durumda DYN-01'in %20'lik payının içinde. Sebep pervanenin çapsal atalet momenti (Id 7,5 kg·m²): jiroskopik etkisi geri yönlü modu aşağı çekiyor.
- Pervanede G6.3 dengesizlikle (2.704 g·mm) ve 1e8 N/m yataklarla dengesizlik cevabı: eş rijitlikli yataklarda 200–2.600 rpm arasında rezonans yok, pervanenin yörüngesi 1.700 rpm'de 7,3 µm. Yataklar bir yönde yarı rijit olunca (kyy = kxx / 2, anizotropik) mod 1.462 rpm'de uyarılıyor ve modeldeki 1e3 N·s/m sönümle yörünge 1,08 mm'ye çıkıyor. Yatak sönümü 3e4 N·s/m olunca bu tepe 46 µm'ye, yani 1.700 rpm'deki yörüngenin 4,3 katına, 1e5 N·s/m olunca 1,6 katına iniyor (çıktıdaki sönüm taraması, kyy = 0,8 kxx için de). Faz 2'de gerçek yatak yuvası rijitliği ve pervane milinde sıkıştırılmış yağ filmi sönümleyicisi (squeeze-film damper) gerekiyor.
- Pervane noktasal kütle ve yataklar çok rijit alınınca ROSS 5.098 cpm veriyor; 1.3 formülü 5.373 rpm vermişti (%5 fark). Bu, o formülü doğruluyor.

Betik `results/campbell.csv`, `results/crossings.csv`, `results/unbalance.csv`, `results/campbell.png` ve `results/unbalance.png` dosyalarını yazıyor (commit edilmez).

2.1 adımı: `step21_reference.py`, 2.1 adımının MATLAB testlerinin beklenen değerlerini (`calc/tests/step21_test_cases.csv`, TC18–TC23) ROSS'tan ve kapalı formlardan yazıyor: yukarıdaki Faz 1 modeli ve 2.1'de seçilen 120/100 mm mil, her yatağı bir gövde yuvasıyla seri bağlı olarak (ROSS'ta noktasal kütleler ve bağlı yatak elemanları). `calc/rotor_damper/` içindeki MATLAB rotor modeli 27 değerin hepsini %0,008'den yakın tutuyor. Sonucu Faz 2 raporunun 2.1 bölümü anlatıyor: geri yönlü savrulma sıkıştırılmış yağ filmi sönümleyicisiyle değil, daha rijit ince cidarlı bir milde çözülüyor.

## Setup / Kurulum

Python 3.13 or newer for ROSS 3.1 / ROSS 3.1 için Python 3.13 ya da daha yeni:

```
python -m venv .venv
source .venv/bin/activate      # Windows: .venv\Scripts\activate
pip install -r requirements.txt
python prop_shaft_campbell.py
python step21_reference.py     # writes ../calc/tests/step21_test_cases.csv
```
