function L = rgb_layout(t, s1, s2, in)
%RGB_LAYOUT  Shafts, main bearings, critical speeds and mass of one layout O design.
%   L = rgb_layout(t, s1, s2, in)
%
%   t is a tooth-count set (tooth_set_check), s1 its first stage
%   (size_stage1), s2 its planetary stage (size_stage2); in comes from
%   rgb_inputs.
%   Input and intermediate shafts: the first-stage gear sits midway between
%   two roller bearings, span b1 + span1_extra, and a QJ carries the axial
%   force. Propeller shaft: roller + QJ at the outer bearing, a roller at
%   the inner one, the propeller overhung by prop_overhang; the carrier
%   delivers pure torque.
%
%   Output struct L
%     t, s1, s2       the inputs
%     inp, mid        input and intermediate shaft: M (bending moment at the
%                     gear) [N m], R (the more heavily loaded roller bearing)
%                     and F_a [N], n [rpm], sh (size_shaft), roller and QJ
%                     (bearing_req), n_cr [rpm], ncr_ok (DYN-01)
%     prop            propeller shaft: M_lim, M_alt [N m], R_out_lim,
%                     R_in_lim, R_out_1, R_in_1 (outer and inner bearing at
%                     limit load and at 1 g) [N], sh, QJ, roller_out,
%                     roller_in, n_cr, ncr_ok
%     mass            breakdown [kg]: pinion, gear2, sun, planets, ring,
%                     carrier, shafts, bearings, housing, accessory, misc, total
%     env             housing envelope: a, D_h (ring outer diameter), D_z, L_g [mm]
%     checks_ok       DN <= DN_max on every shaft and DYN-01 met on every shaft
%   L is empty if size_shaft finds no diameter for a shaft.
%
%   On the propeller shaft the bearing reactions are F_w (1 + a/L_p) + M/L_p
%   and F_w a/L_p + M/L_p, with M the moment applied at the propeller:
%   M_gyro at limit load, M_1P in the life case (the moment of the weight
%   itself is in the F_w terms).
%
%   Source: Phase 1 report, Section 3 ("Method: planet bearing, shafts,
%   main bearings, critical speed" and "Method: mass and selection").
%   Checked in the full run; the functions it calls are tested by TC6-TC9.

L = [];
g1 = s1.g;
b1 = s1.b;
L1 = b1 + in.span1_extra;                   % first-stage shaft span
Ts = in.T_PT * t.u1;                        % intermediate shaft = sun torque and speed
ns = in.n_PT / t.u1;

% Input and intermediate shafts. The gear masses are the discs of the critical speed model.
mass.pinion = rgb_mass('pinion', in, g1.d1, b1);
mass.gear2 = rgb_mass('gear2', in, g1.d2, b1);
inp = stage1_shaft(s1.r, g1.d1 / 2, in.T_PT, in.n_PT, L1, mass.pinion, in);
mid = stage1_shaft(s1.r, g1.d2 / 2, Ts, ns, L1, mass.gear2, in);
if isempty(inp) || isempty(mid), return, end

% Propeller shaft
a = in.prop_overhang;
Lp = in.prop_span;
Fw1 = in.m_prop * in.g;                     % propeller weight at 1 g
Fw_lim = in.m_prop * in.nz_gyro * in.g;     % at the LD-05 load factor
prop.M_lim = Fw_lim * a / 1e3 + in.M_gyro;  % at the outer bearing (LD-05)
prop.M_alt = in.M_1P + Fw1 * a / 1e3;       % fatigue: 1P moment and 1 g weight
prop.sh = size_shaft(in.T_prop, prop.M_alt, in.thrust, in.K_over * in.T_prop, prop.M_lim, ...
                     in.thrust, in.shaft_d0_prop, in);
if isempty(prop.sh), return, end
prop.R_out_lim = Fw_lim * (1 + a / Lp) + in.M_gyro * 1e3 / Lp;
prop.R_in_lim = Fw_lim * a / Lp + in.M_gyro * 1e3 / Lp;
prop.R_out_1 = Fw1 * (1 + a / Lp) + in.M_1P * 1e3 / Lp;
prop.R_in_1 = Fw1 * a / Lp + in.M_1P * 1e3 / Lp;
d_pr = prop.sh.d_o;
th = in.thrust_spectrum;
prop.QJ = bearing_req('QJ', [th(:, 1), zeros(size(th, 1), 1), th(:, 2)], in.n_prop, in.thrust, d_pr, in);
prop.roller_out = bearing_req('roller', [1, prop.R_out_1, 0], in.n_prop, prop.R_out_lim, d_pr, in);
prop.roller_in = bearing_req('roller', [1, prop.R_in_1, 0], in.n_prop, prop.R_in_lim, d_pr, in);
prop.n_cr = critical_speed('overhung', d_pr, prop.sh.d_i, Lp, in.m_prop, a, in);
prop.ncr_ok = prop.n_cr >= in.ncr_margin * in.n_cont_max * in.n_prop;

% Mass breakdown
mass.sun = rgb_mass('sun', in, s2.ds, s2.b);
mass.planets = t.N * s2.m_planet;
[mass.ring, D_h] = rgb_mass('ring', in, s2.dr, s2.m, s2.b);
[mass.carrier, t_c] = rgb_mass('carrier', in, s2.ds, s2.dp, s2.brg.d_pin, t.N, s2.b);
mass.shafts = rgb_mass('shaft', in, inp.sh.d_o, inp.sh.d_i, L1 + 60) ...
              + rgb_mass('shaft', in, mid.sh.d_o, mid.sh.d_i, L1 + 60) ...
              + rgb_mass('shaft', in, d_pr, prop.sh.d_i, Lp + 0.5 * a + 50) ...
              + rgb_mass('flange', in, d_pr);
mass.bearings = 0;
for d = [inp.sh.d_o, mid.sh.d_o]            % two roller bearings and a QJ per shaft
    mass.bearings = mass.bearings + (2 * rgb_mass('bearing', in, d, 1) + rgb_mass('bearing', in, d, 1));
end
mass.bearings = mass.bearings + (2 * rgb_mass('bearing', in, d_pr, 1) + rgb_mass('bearing', in, d_pr, 1.2));
env.a = g1.a;
env.D_h = D_h;
env.D_z = max(g1.d2 + 2 * s1.mn, D_h) + 30;
env.L_g = (b1 + 60) + (s2.b + 2 * t_c + 30) + 200;    % stage 1, carrier, propeller bearings and seal
mass.housing = rgb_mass('housing', in, env.a, env.D_z, env.L_g);
mass.accessory = in.m_accessory;
subtotal = mass.pinion + mass.gear2 + mass.sun + mass.planets + mass.ring + mass.carrier ...
           + mass.shafts + mass.bearings + mass.housing + mass.accessory;
mass.misc = in.misc_share * subtotal;
mass.total = subtotal + mass.misc;

DN = [inp.roller.DN, mid.roller.DN, prop.QJ.DN];      % the bearings of one shaft share d and n
checks_ok = all(DN <= in.DN_max) && inp.ncr_ok && mid.ncr_ok && prop.ncr_ok;
L = struct('t', t, 's1', s1, 's2', s2, 'inp', inp, 'mid', mid, 'prop', prop, ...
           'mass', mass, 'env', env, 'checks_ok', checks_ok);
end

function x = stage1_shaft(r, rg, T, n, L1, m_gear, in)
% Shaft with a first-stage gear of pitch radius rg midway between two roller
% bearings; r is the 100% torque rating of the mesh (iso6336_lite)
x = [];
s.M = sqrt((r.Ft * L1 / 4)^2 + (r.Fr * L1 / 4 + r.Fa * rg / 2)^2) / 1e3;
s.R = hypot(r.Ft / 2, r.Fr / 2 + r.Fa * rg / L1);
s.F_a = r.Fa;
s.n = n;
s.sh = size_shaft(T, s.M, r.Fa, in.K_over * T, in.K_over * s.M, in.K_over * r.Fa, in.shaft_d0_stage1, in);
if isempty(s.sh), return, end
mis = in.mission;                           % loads follow the torque, speed constant
zero = zeros(size(mis, 1), 1);
s.roller = bearing_req('roller', [mis(:, 1), s.R * mis(:, 2), zero], n, in.K_over * s.R, s.sh.d_o, in);
s.QJ = bearing_req('QJ', [mis(:, 1), zero, r.Fa * mis(:, 2)], n, in.K_over * r.Fa, s.sh.d_o, in);
s.n_cr = critical_speed('simply_supported', s.sh.d_o, s.sh.d_i, L1, m_gear, [], in);
s.ncr_ok = s.n_cr >= in.ncr_margin * in.n_cont_max * n;
x = s;
end
