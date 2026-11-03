function I = os_inlet(in, li, Qp)
%OS_INLET  Pump inlet pressure at the ENV-02 ceiling and the negative-g endurance (LUB-08).
%   I = os_inlet(in, li, Qp)
%
%   Absolute pressure at the supply element inlet: ambient pressure at the
%   altitude (ISA, 45,000 ft) plus the tank pressurising valve plus the oil
%   head, minus the suction line loss at the pump flow Qp [L/min] and hot
%   oil (100 degC); compared with in.p_inlet_min (aerated oil, TBR). The
%   same at sea level with -40 degC oil (start) and at -1.27 g (the head
%   reverses). Negative g: the flexible pick-up keeps the inlet in oil while
%   the scavenge stops returning oil, so the usable tank volume lasts
%   V_usable / Qp. Output I: p_amb, p_in (hot, altitude), margin, p_in_cold,
%   p_in_negg [kPa abs], t_negg [s].
%   Source: Phase 3 report, Section 3.2 ("Pump inlet").

h = in.alt_ft * 0.3048;
p_amb = 22.632 * exp(-9.80665 * (h - 11000) / (287.053 * 216.65));     % kPa, ISA above 11 km
if h < 11000, p_amb = 101.325 * (1 - 2.25577e-5 * h)^5.25588; end
dp = @(o) suction(in, o, Qp);
oh = os_oil(100, li);  oc = os_oil(-40, li);
head = @(o, g) o.rho * 9.80665 * g * in.h_tank * 1e-3 / 1e3;               % kPa
I.p_amb = p_amb;
I.p_in = p_amb + in.p_tank_valve + head(oh, 1) - dp(oh);
I.margin = I.p_in - in.p_inlet_min;
I.dp_suction_hot = dp(oh);
I.p_in_cold = 101.325 + head(oc, 1) - dp(oc);       % sea level start: the valve is not yet pressurised
I.dp_suction_cold = dp(oc);
I.p_in_negg = p_amb + in.p_tank_valve + head(oh, in.g_neg) - dp(oh);
I.t_negg = in.V_usable / Qp * 60;
end

function dp = suction(in, o, Q)
s = in.line.suction;
A = pi / 4 * (s(2) * 1e-3)^2;
v = Q / 6e4 / A;
Re = v * s(2) * 1e-3 / (o.nu * 1e-6);
if Re < 2300
    f = 64 / Re;  K = 0;
else
    f = 0.316 * Re^-0.25;  K = in.K_bend * s(3);
end
dp = (f * s(1) / s(2) + K + 1) * o.rho * v^2 / 2 / 1e3;    % + 1: inlet loss
end
