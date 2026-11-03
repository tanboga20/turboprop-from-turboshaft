function c = tooth_set_check(z1, z2, zs, zp, N, in)
%TOOTH_SET_CHECK  Ratio, assembly and planet spacing of one tooth-count set.
%   c = tooth_set_check(z1, z2, zs, zp, N, in)
%
%   z1, z2 are the first-stage pinion and gear, zs and zp the sun and planet;
%   the ring has zr = zs + 2 zp teeth. N is the planet count and in comes from
%   rgb_inputs.
%
%   Output struct c: the set (z1, z2, zs, zp, zr, N) and
%     u1, i2, i          first-stage, planetary and overall ratio          [-]
%     ratio_error        100 (i / i_target - 1)                            [%]
%     assembly_ok        (zs + zr)/N is a whole number, so the planets can
%                        be spaced equally                                 [true/false]
%     gap                clearance between neighbouring planet tips        [modules]
%     hunt_1, hunt_sp, hunt_pr   gcd = 1 in the first-stage, sun-planet and
%                        planet-ring mesh                                  [true/false]
%     valid              meets every rule: ratio within i_tol, hunt_1 (required
%                        in the first stage), assembly_ok, gap >= tip_clear_min
%   Hunting teeth in the planetary stage are only a preference in the
%   selection. The post gap at module m, m * gap, is checked in size_stage2.
%
%   Source: Phase 1 report, Section 3 ("Method: gears", tooth counts).
%   Tested by test_rgb_sizing (TC4a, TC4b).

zr = zs + 2 * zp;
u1 = z2 / z1;
i2 = 1 + zr / zs;
i = u1 * i2;
err = i / in.i_target - 1;

c.z1 = z1;  c.z2 = z2;  c.zs = zs;  c.zp = zp;  c.zr = zr;  c.N = N;
c.u1 = u1;
c.i2 = i2;
c.i = i;
c.ratio_error = 100 * err;
c.assembly_ok = mod(zs + zr, N) == 0;
c.gap = (zs + zp) * sin(pi / N) - (zp + 2);     % centre spacing minus one tip diameter
c.hunt_1 = gcd(z1, z2) == 1;
c.hunt_sp = gcd(zs, zp) == 1;
c.hunt_pr = gcd(zp, zr) == 1;
c.valid = abs(err) <= in.i_tol && c.hunt_1 && c.assembly_ok && c.gap >= in.tip_clear_min;
end
