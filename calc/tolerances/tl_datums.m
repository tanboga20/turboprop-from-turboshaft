function D = tl_datums(in, G)
%TL_DATUMS  Datum schemes and the main geometric tolerances of the parts drawn in 3.9 (E1, ASME Y14.5-2018).
%   D = tl_datums(in, G)   in = tl_inputs, G = tl_gears(in)
%
%   Datums from function: on shafts and gears the common axis of the two
%   bearing journals (A-B), with a shoulder or face as C where an axial
%   location is needed; on the cases the mating flange face (A), its pilot
%   (B) and a dowel or the second pilot (C). Values: bearing seats
%   cylindricity IT5 / 2 and shoulder total runout IT5 of the seat diameter
%   (aerospace bearing practice, TBR); tooth radial runout F_r of E6 to the
%   journal axis; the carrier pin bores at position 0.010 mm (STR-07) and
%   parallel to the axis within the step 2.4 f_pin_par; the first-stage bore
%   axes at position 0.020 mm (the +-0.010 mm centre distance of E3) and
%   parallel within 0.010 mm over the bearing span (K_Hbeta of step 2.4);
%   flange face flatness 0.03 mm (step 3.4). Values in mm.
%   Source: Phase 3 report, Section 3.8 (E1).

it5 = @(d) tl_it(d, 5) / 1000;
Fr = @(key) G.T.F_r_um(G.T.key == key) / 1000;
r = {};
add = @(part, f_en, f_tr, ch, v, dat, basis) {string(part), string(f_en), string(f_tr), string(ch), v, string(dat), string(basis)};
% gears and shafts
r(end + 1, :) = add('Input pinion shaft F203', 'NU2209 / QJ209 journals (dia 45)', 'NU2209 / QJ209 muyluları (çap 45)', 'cylindricity', round(it5(45) / 2, 3), '-', 'bearing seat, IT5/2');
r(end + 1, :) = add('Input pinion shaft F203', 'journals, datum axis A-B', 'muylular, referans eksen A-B', 'datum feature', NaN, 'A, B', 'function: the bearing journals');
r(end + 1, :) = add('Input pinion shaft F203', 'teeth', 'dişler', 'radial runout (F_r)', Fr("pinion"), 'A-B', 'E6, ISO 1328-1 class 4');
r(end + 1, :) = add('Input pinion shaft F203', 'bearing shoulders', 'rulman omuzları', 'total runout (axial)', round(it5(45), 3), 'A-B', 'IT5 of the seat');
r(end + 1, :) = add('Gear 2 F202 on F204', 'bore / journals, datum axis A-B', 'delik / muylular, referans eksen A-B', 'datum feature', NaN, 'A, B', 'function: the NU2210 / QJ210 journals');
r(end + 1, :) = add('Gear 2 F202 on F204', 'teeth', 'dişler', 'radial runout (F_r)', Fr("gear2"), 'A-B', 'E6, ISO 1328-1 class 4');
r(end + 1, :) = add('Gear 2 F202 on F204', 'web reference face', 'gövde referans yüzü', 'axial runout', round(it5(228), 3), 'A-B', 'helix to axis, IT5');
r(end + 1, :) = add('Gear 2 F202 on F204', 'damping-ring groove (3.6)', 'sönüm halkası oluğu (3.6)', 'position (axial)', 0.05, 'A-B|C', 'groove offset 16 mm (3.6), TBR');
r(end + 1, :) = add('Sun P105', 'internal spline (datum A, major-diameter fit)', 'iç kama (referans A, büyük çap)', 'datum feature', NaN, 'A', 'function: the floating sun runs on its spline');
r(end + 1, :) = add('Sun P105', 'teeth', 'dişler', 'radial runout (F_r)', Fr("sun"), 'A', 'E6, ISO 1328-1 class 5');
r(end + 1, :) = add('Planets P107', 'bore (outer raceway), datum A', 'delik (dış yuvarlanma yolu), referans A', 'cylindricity', 0.003, '-', 'raceway of the full-complement bearing, TBR');
r(end + 1, :) = add('Planets P107', 'teeth', 'dişler', 'radial runout (F_r)', Fr("planet"), 'A', 'E6, class 5 pitch, class 4 profile');
r(end + 1, :) = add('Planets P107', 'matched set: tooth thickness', 'eşleşmiş takım: diş kalınlığı', 'size spread within the set', 2 * in.ls.planet_set, '-', 'STR-07, +-3 um');
r(end + 1, :) = add('Ring gear P102', 'outer seat dia 259, datum A', 'dış yuva çap 259, referans A', 'cylindricity', round(it5(259) / 2, 3), '-', 'ring seat (E4 fit), IT5/2');
r(end + 1, :) = add('Ring gear P102', 'teeth', 'dişler', 'radial runout (F_r)', Fr("ring"), 'A', 'E6, class 5');
% carrier with the propeller shaft
r(end + 1, :) = add('Carrier with propeller shaft P103', 'NU1024 journals (dia 120), datum axis A-B', 'NU1024 muyluları (çap 120), referans eksen A-B', 'cylindricity', round(it5(120) / 2, 3), 'A, B', 'bearing seat, IT5/2');
r(end + 1, :) = add('Carrier with propeller shaft P103', 'front plate inner face, datum C', 'ön plaka iç yüzü, referans C', 'perpendicularity', 0.010, 'A-B', 'axial location of the planets, TBR');
r(end + 1, :) = add('Carrier with propeller shaft P103', 'four planet pin bores (dia 38)', 'dört planet pim deliği (çap 38)', 'position (diametral zone)', in.ls.pin_tp, 'A-B|C', 'STR-07: 0.010 mm');
r(end + 1, :) = add('Carrier with propeller shaft P103', 'planet pin bores', 'planet pim delikleri', 'parallelism to A-B over the pin length', 0.005, 'A-B', 'step 2.4 f_pin_par 5 um over 82 mm');
r(end + 1, :) = add('Carrier with propeller shaft P103', 'QJ1024 seat and shoulder', 'QJ1024 yuvası ve omzu', 'total runout (axial)', round(it5(120), 3), 'A-B', 'IT5 of the seat; catcher-lip collar on the same setup');
r(end + 1, :) = add('Carrier with propeller shaft P103', 'flange P115 pilot and face', 'P115 flanşı merkezleme ve yüzü', 'total runout', 0.020, 'A-B', 'propeller balance (PIF-01), TBR');
% cases
r(end + 1, :) = add('Planetary case P101', 'mount flange face, datum A', 'bağlantı flanşı yüzü, referans A', 'flatness', 0.03, '-', 'step 3.4');
r(end + 1, :) = add('Planetary case P101', 'flange pilot, datum B; dowel, datum C', 'flanş merkezleme, referans B; pim, referans C', 'datum feature', NaN, 'A, B, C', 'function: the joint to F201 and the mounts');
r(end + 1, :) = add('Planetary case P101', 'ring gear seat bore dia 259', 'halka dişli yuva deliği çap 259', 'cylindricity', round(it5(259) / 2, 3), '-', 'E4 seat fit, IT5/2');
r(end + 1, :) = add('Planetary case P101', 'ring gear seat bore', 'halka dişli yuva deliği', 'position (diametral zone)', 0.020, 'A|B', 'coaxial with the carrier bearings, TBR');
r(end + 1, :) = add('Planetary case P101', 'NU1024 liner bores (two)', 'NU1024 gömlek delikleri (iki)', 'position (diametral zone)', 0.015, 'A|B', 'DYN-05 seats, coaxial with the ring seat, TBR');
r(end + 1, :) = add('Planetary case P101', 'ring seat shoulder', 'halka yuva omzu', 'perpendicularity', 0.010, 'A', 'ring alignment (STR-04 twist), TBR');
r(end + 1, :) = add('First-stage case F201', 'flange face, datum A', 'flanş yüzü, referans A', 'flatness', 0.03, '-', 'step 3.4');
r(end + 1, :) = add('First-stage case F201', 'pilot, datum B; dowel, datum C', 'merkezleme, referans B; pim, referans C', 'datum feature', NaN, 'A, B, C', 'function: the joint to P101');
r(end + 1, :) = add('First-stage case F201', 'pinion and gear-2 liner bores (four)', 'pinyon ve dişli 2 gömlek delikleri (dört)', 'position (diametral zone)', 2 * in.s1.fa / 1000, 'A|B|C', 'E3: centre distance +-0.010 mm');
r(end + 1, :) = add('First-stage case F201', 'gear-2 bore axis', 'dişli 2 delik ekseni', 'parallelism to the pinion axis, over the 102 mm span', 0.010, 'pinion bores', 'step 2.4 K_Hbeta (f_ma), TBR');
r(end + 1, :) = add('Bearing housing P111', 'flange face to the nose, datum A; pilot, datum B', 'buruna flanş yüzü, referans A; merkezleme, referans B', 'datum feature', NaN, 'A, B', 'function: the axial load path (D1)');
r(end + 1, :) = add('Bearing housing P111', 'QJ1024 outer-ring seat dia 180', 'QJ1024 dış bilezik yuvası çap 180', 'cylindricity', round(it5(180) / 2, 3), '-', 'IT5/2');
r(end + 1, :) = add('Bearing housing P111', 'QJ shoulder and catcher lip', 'QJ omzu ve yakalama dudağı', 'total runout (axial)', round(it5(180), 3), 'A|B', 'IT5; lip gap of E3c');
D.T = cell2table(r, 'VariableNames', {'part', 'feature_en', 'feature_tr', 'characteristic', 'tolerance_mm', ...
                                     'datums', 'basis'});
end

function v = tl_it(d, n)
[~, ~, v] = tl_iso286(d, sprintf('h%d', n));
end
