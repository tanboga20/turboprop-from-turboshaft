function F = hm_frequencies(gi, sb, ad, spd)
%HM_FREQUENCIES  Characteristic (fault) frequencies of the RGB shafts, gears and bearings.
%   F = hm_frequencies(gi, sb, ad, spd)
%
%   gi, sb, ad: the step 2.4, 2.5 and 2.6 inputs (gd_inputs, sb_inputs,
%   ad_inputs); spd: speed as a share of 100% (1.0 = 22,000 rpm at the
%   power turbine).
%
%   Shafts: the input (pinion) shaft at the power turbine speed, the
%   intermediate shaft (first-stage gear, sun, PCU pinion, oil pumps), the
%   carrier and propeller shaft (ring fixed), the planets about their pins,
%   and the accessory shafts (generator with the OSG pinion, OSG, PCU).
%   Meshes: tooth count times the speed of the gear; the planetary mesh
%   frequency is zr times the carrier speed (= zs times the sun speed
%   relative to the carrier). Local gear faults: a sun tooth meets N
%   planets per relative revolution, a planet tooth meets the sun and the
%   ring once each per planet revolution, a ring tooth is passed by N
%   planets per carrier revolution. Bearings, with g = Dw / Dpw cos(alpha)
%   and fr the speed of the rotating race relative to the stationary one:
%   cage fr/2 (1 - g), a defect on the rotating inner race Z fr/2 (1 + g),
%   on the stationary outer race Z fr/2 (1 - g), rolling element spin
%   Dpw/(2 Dw) fr (1 - g^2). The planet bearing turns the other way round
%   (the pin is the stationary inner race, the planet the rotating outer
%   race), so its cage turns at fr/2 (1 + g), a point of the pin is passed
%   Z fr/2 (1 + g) times and a point of the planet bore Z fr/2 (1 - g)
%   times a second; its frequencies are in the carrier frame.
%
%   Output struct F: shaft (name, rpm, Hz), mesh (name, Hz), gearfault
%   (name, Hz), bearing (name, shaft Hz, cage, inner, outer, spin [Hz],
%   frame).
%   Source: Phase 2 report, Section 2.10 ("Fault frequencies"). Tested by
%   test_step210 (TC57-TC59).

n_in = gi.n_PT * spd;                          % rpm, input (pinion) shaft
s1 = gi.s1;  s2 = gi.s2;
n_mid = n_in * s1.z1 / s1.z2;                  % intermediate shaft, sun
n_c = n_mid / (1 + s2.zr / s2.zs);             % carrier, propeller (ring fixed)
n_p = (n_mid - n_c) * s2.zs / s2.zp;           % planet about its pin
n_gen = n_mid * s1.z2 / ad.gen.z;              % generator shaft (gear on the first-stage gear)
n_osg = n_gen * ad.osg.z(1) / ad.osg.z(2);     % OSG (pinion on the generator shaft)
n_pcu = n_mid * ad.pcu.z(1) / ad.pcu.z(2);     % PCU (pinion on the intermediate shaft)
names = {'input shaft (pinion)', 'intermediate shaft (sun, pumps)', 'carrier and propeller shaft', ...
         'planet about its pin', 'generator shaft', 'OSG shaft', 'PCU shaft'};
rpm = [n_in, n_mid, n_c, n_p, n_gen, n_osg, n_pcu];
F.shaft = struct('name', names, 'rpm', num2cell(rpm), 'Hz', num2cell(rpm / 60));

f = rpm / 60;
F.mesh = struct('name', {'first stage and generator (z 31 / 110 / 57)', 'planetary (sun-planet-ring)', ...
                         'OSG pair (z 21 / 30)', 'PCU pair (z 20 / 73)'}, ...
                'Hz', {s1.z1 * f(1), s2.zr * f(3), ad.osg.z(1) * f(5), ad.pcu.z(1) * f(2)});
F.gearfault = struct('name', {'sun tooth (N per relative revolution)', 'planet tooth (sun and ring)', ...
                              'ring tooth (N planets per carrier revolution)', 'planet pass'}, ...
                     'Hz', {s2.N * (f(2) - f(3)), 2 * f(4), s2.N * f(3), s2.N * f(3)});

% bearings: [name, shaft Hz, Z, Dw, Dpw, alpha, frame]
B = {};
for b = sb.brg
    k = find(strcmp({'input', 'mid', 'prop'}, b.shaft));
    B(end + 1, :) = {b.name, f([1 2 3]) * ([1 2 3] == k)', b.Z, b.Dw, b.Dpw, b.alpha, 'case'}; %#ok<AGROW>
end
M = gd_meshes(gi);
Dpw_p = M(2).D_or - sb.planet.Dw;
Z_p = floor(pi * Dpw_p / (sb.planet.Dw * (1 + sb.planet.pitch_gap)));
B(end + 1, :) = {'planet (full complement)', f(4), Z_p, sb.planet.Dw, Dpw_p, 0, 'carrier'};
acc = [f(5) f(6) f(7)];
for j = 1:numel(ad.brg)
    a = ad.brg(j);
    B(end + 1, :) = {[a.name ' bearing'], acc(j), a.Z, a.Dw, a.Dpw, 0, 'case'}; %#ok<AGROW>
end
for j = 1:size(B, 1)
    fr = B{j, 2};  Z = B{j, 3};  g = B{j, 4} / B{j, 5} * cosd(B{j, 6});
    spin = B{j, 5} / (2 * B{j, 4}) * fr * (1 - g^2);
    if strcmp(B{j, 7}, 'carrier')              % rotating outer race, stationary inner race (pin)
        cage = fr / 2 * (1 + g);  inner = Z * fr / 2 * (1 + g);  outer = Z * fr / 2 * (1 - g);
    else                                       % rotating inner race, stationary outer race
        cage = fr / 2 * (1 - g);  inner = Z * fr / 2 * (1 + g);  outer = Z * fr / 2 * (1 - g);
    end
    F.bearing(j) = struct('name', B{j, 1}, 'shaft', fr, 'Z', Z, 'cage', cage, 'inner', inner, ...
                          'outer', outer, 'spin', spin, 'frame', B{j, 7});
end
end
