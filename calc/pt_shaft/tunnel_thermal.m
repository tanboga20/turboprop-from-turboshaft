function th = tunnel_thermal(D, L, m_air, T_gas, in)
%TUNNEL_THERMAL  Temperatures in the shaft tunnel through the exhaust collector (SYS-10, ENV-04).
%   th = tunnel_thermal(D, L, m_air, T_gas, in)
%
%   Inputs
%     D       outer diameter of the floating shaft                      [m]
%     L       tunnel length                                             [m]
%     m_air   buffer air flow along the tunnel                          [kg/s]
%     T_gas   exhaust gas temperature around the tunnel                 [degC]
%     in      ptshaft_inputs (in.tun, in.air, in.n_PT)
%
%   Output struct th
%     x, T_air, T_liner, T_shaft   temperatures along the tunnel       [m, degC]
%     T_air_out, T_shaft_max       buffer air at the exit, hottest shaft [degC]
%     Q_in                         heat through the insulation         [W]
%     P_wind                       windage power of the shaft           [W]
%     h_air                        heat transfer coefficient in the gap [W/(m^2 K)]
%     ok                           T_shaft_max <= in.tun.T_shaft_max
%
%   Thermal network per segment: gas -> outer skin (h_gas) -> insulation
%   (cylindrical wall, k_ins) -> liner -> buffer air (h_air) -> shaft. The
%   shaft only exchanges heat with the air and gains the windage heat, so
%   T_shaft = T_air + P_wind' / (h_air pi D). h_air: annulus of hydraulic
%   diameter 2 gap, Dittus-Boelter Nu = 0.023 Re^0.8 Pr^0.4 on the velocity
%   sqrt(u^2 + (omega r / 2)^2) (axial flow plus the swirl the shaft gives).
%   Windage: moment coefficient C_M = 0.065 (gap / r)^0.3 Re^-0.2 of a
%   cylinder turning in an annulus, Re = rho w r gap / mu > 1e4 (Bilgen and
%   Boulos, 1973), with M = C_M pi rho w^2 r^4 L / 2 and P = M w.
%
%   Source: Phase 2 report, Section 2.2 ("Shaft tunnel"). Tested by
%   test_step22 (TC29).

tun = in.tun;  air = in.air;
rs = D / 2;
ri = rs + tun.gap;                          % liner inner radius
ro = ri + tun.t_ins;                        % insulation outer radius
w = in.n_PT * pi / 30;
N = tun.N_seg;
dx = L / N;
R_out = 1 / (tun.h_gas * 2 * pi * ro) + log(ro / ri) / (2 * pi * tun.k_ins);   % K m / W

T_a = zeros(N + 1, 1);  T_l = zeros(N, 1);  T_s = zeros(N, 1);
T_a(1) = tun.T_air_in;
Q = 0;  Pw = 0;  h = 0;
for k = 1:N
    rho = air.p / (air.R * (T_a(k) + 273.15));
    u = m_air / (rho * pi * (ri^2 - rs^2));
    Dh = 2 * tun.gap;
    Re = rho * sqrt(u^2 + (w * rs / 2)^2) * Dh / air.mu;
    h = 0.023 * Re^0.8 * air.Pr^0.4 * air.k / Dh;
    % windage of this segment
    Re_w = rho * w * rs * tun.gap / air.mu;
    CM = 0.065 * (tun.gap / rs)^0.3 * Re_w^-0.2;
    pw = 0.5 * CM * pi * rho * w^3 * rs^4 * dx;
    % liner: heat through the insulation = heat into the air
    T_l(k) = (T_gas / R_out + h * 2 * pi * ri * T_a(k)) / (1 / R_out + h * 2 * pi * ri);
    q = (T_gas - T_l(k)) / R_out * dx;
    T_s(k) = T_a(k) + pw / (h * pi * D * dx);
    T_a(k + 1) = T_a(k) + (q + pw) / (m_air * air.cp);
    Q = Q + q;
    Pw = Pw + pw;
end
th.x = (0.5:N)' * dx;
th.T_air = T_a;
th.T_liner = T_l;
th.T_shaft = T_s;
th.T_air_out = T_a(end);
th.T_shaft_max = max(T_s);
th.Q_in = Q;
th.P_wind = Pw;
th.h_air = h;
th.ok = th.T_shaft_max <= tun.T_shaft_max;
end
