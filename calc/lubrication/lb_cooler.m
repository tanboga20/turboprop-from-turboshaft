function C = lb_cooler(Q, m_oil, v_face, in)
%LB_COOLER  Air-oil cooler sized by effectiveness-NTU with offset strip fins on both sides.
%   C = lb_cooler(Q, m_oil, v_face, in)
%
%   Q duty [W], m_oil oil mass flow [kg/s], v_face air face velocity [m/s],
%   in = lb_inputs. The oil leaves at in.T_oil_out, the air enters at
%   in.T_amb with in.m_air; cross flow, both fluids unmixed:
%   eps = 1 - exp(NTU^0.22 / C_r (exp(-C_r NTU^0.78) - 1)), solved for the
%   NTU and UA the duty needs. Core: alternating air and oil layers of
%   offset strip fins (in.fin_air, in.fin_oil) between parting sheets, a
%   square face of area m_air / (rho v_face); the oil runs across the face
%   width. Heat transfer and friction of both sides by Manglik and Bergles
%   (1995): j = 0.6522 Re^-0.5403 a^-0.1541 d^0.1499 g^-0.0678 [1 + 5.269e-5
%   Re^1.340 a^0.504 d^0.456 g^-1.055]^0.1, f = 9.6243 Re^-0.7422 a^-0.1856
%   d^0.3053 g^-0.2659 [1 + 7.669e-8 Re^4.429 a^0.920 d^3.767 g^0.236]^0.1,
%   a = s/h, d = t/l, g = t/s, D_h = 4 s h l / (2 (s l + h l + t h) + t s);
%   straight-fin efficiency over half the layer height. The core depth L is
%   solved so that UA matches; air pressure drop with entrance and exit
%   losses of 0.6 velocity heads. The fan of option C moves the air through
%   the core and in.dp_ducts with in.eta_fan.
%
%   Output struct C: T_oil_in, T_air_out [degC]; eps, NTU [-]; UA [W/K];
%   A_fr [m^2], W, L [mm] (face side, depth); Re_a, j_a, f_a, h_a, eta_oa,
%   Re_o, h_o, eta_oo; dp_air, dp_oil [Pa]; m_core, m_cooler [kg]; P_fan [W].
%   Source: Phase 2 report, Section 2.7 ("Cooler"). Tested by test_step27
%   (TC51).

oil_in = oil_props(in.T_oil_out, in.oil);                  % first guess for the mean oil temperature
T_oil_in = in.T_oil_out + Q / (m_oil * oil_in.cp);
oil = oil_props((T_oil_in + in.T_oil_out) / 2, in.oil);
T_oil_in = in.T_oil_out + Q / (m_oil * oil.cp);
cpa = 1007;
Ca = in.m_air * cpa;
Co = m_oil * oil.cp;
T_air_out = in.T_amb + Q / Ca;
Cmin = min(Ca, Co);  Cr = Cmin / max(Ca, Co);
eps = Q / (Cmin * (T_oil_in - in.T_amb));
epsf = @(N) 1 - exp(N^0.22 / Cr * (exp(-Cr * N^0.78) - 1));
NTU = fzero(@(N) epsf(N) - eps, [1e-3, 50]);
UA = NTU * Cmin;

% Air properties at the mean air temperature
Ta = (in.T_amb + T_air_out) / 2 + 273.15;
rho_a = in.p_air * 1e3 / (287.05 * Ta);
mu_a = 1.716e-5 * (Ta / 273.15)^1.5 * (273.15 + 110.4) / (Ta + 110.4);
k_a = 0.0241 * (Ta / 273.15)^0.81;
Pr_a = mu_a * cpa / k_a;
% Oil properties
mu_o = oil.nu * 1e-6 * oil.rho;
Pr_o = mu_o * oil.cp / in.k_oil;

% Core geometry
fa = in.fin_air;  fo = in.fin_oil;
pitch = fa.h + fo.h + 2 * in.t_plate;                      % mm, one air and one oil layer
A_fr = in.m_air / (rho_a * v_face);
W = sqrt(A_fr);                                            % m, square face
sig_a = fa.h / pitch * fa.s / (fa.s + fa.t);
sig_o = fo.h / pitch * fo.s / (fo.s + fo.t);
[Dh_a, al_a, de_a, ga_a] = geom(fa);
[Dh_o, al_o, de_o, ga_o] = geom(fo);
G_a = in.m_air / (sig_a * A_fr);
Re_a = G_a * Dh_a / mu_a;
[j_a, f_a] = mb(Re_a, al_a, de_a, ga_a);
h_a = j_a * G_a * cpa / Pr_a^(2/3);
eta_oa = surf_eff(h_a, fa, in.k_al);
beta_a = 4 * sig_a / Dh_a;                                 % air heat transfer area per core volume [1/m]
beta_o = 4 * sig_o / Dh_o;
UAof = @(L) ua(L);
L = fzero(@(L) UAof(L) - UA, [1e-3, 2]);
[~, Re_o, h_o, eta_oo, G_o, f_o] = ua(L);
dp_air = G_a^2 / (2 * rho_a) * (4 * f_a * L / Dh_a + 0.6);
dp_oil = G_o^2 / (2 * oil.rho) * 4 * f_o * W / Dh_o;
m_core = in.rho_core * A_fr * L;
C = struct('T_oil_in', T_oil_in, 'T_air_out', T_air_out, 'eps', eps, 'NTU', NTU, 'UA', UA, ...
           'A_fr', A_fr, 'W', W * 1e3, 'L', L * 1e3, 'Re_a', Re_a, 'j_a', j_a, 'f_a', f_a, 'h_a', h_a, ...
           'eta_oa', eta_oa, 'Re_o', Re_o, 'h_o', h_o, 'eta_oo', eta_oo, 'dp_air', dp_air, 'dp_oil', dp_oil, ...
           'm_core', m_core, 'm_cooler', in.k_tanks * m_core, 'v_face', v_face, 'rho_a', rho_a, ...
           'P_fan', in.m_air * (dp_air + in.dp_ducts) / (rho_a * in.eta_fan));

    function [U, Re, h, eta, G, f] = ua(Lc)
        A_co = sig_o * W * Lc;                             % oil free-flow area: depth x stack height
        G = m_oil / A_co;
        Re = G * Dh_o / mu_o;
        [j, f] = mb(Re, al_o, de_o, ga_o);
        h = j * G * oil.cp / Pr_o^(2/3);
        eta = surf_eff(h, fo, in.k_al);
        V = A_fr * Lc;
        U = 1 / (1 / (eta_oa * h_a * beta_a * V) + 1 / (eta * h * beta_o * V));
    end
end

function [Dh, al, de, ga] = geom(f)
s = f.s;  h = f.h;  t = f.t;  l = f.l;
Dh = 4 * s * h * l / (2 * (s * l + h * l + t * h) + t * s) * 1e-3;    % m
al = s / h;  de = t / l;  ga = t / s;
end

function [j, f] = mb(Re, al, de, ga)
j = 0.6522 * Re^-0.5403 * al^-0.1541 * de^0.1499 * ga^-0.0678 ...
    * (1 + 5.269e-5 * Re^1.340 * al^0.504 * de^0.456 * ga^-1.055)^0.1;
f = 9.6243 * Re^-0.7422 * al^-0.1856 * de^0.3053 * ga^-0.2659 ...
    * (1 + 7.669e-8 * Re^4.429 * al^0.920 * de^3.767 * ga^0.236)^0.1;
end

function eta_o = surf_eff(h, f, k)
% Overall surface efficiency: fins over half the layer height, fin share of the area h / (h + s)
m = sqrt(2 * h / (k * f.t * 1e-3));
lf = f.h / 2 * 1e-3;
eta_f = tanh(m * lf) / (m * lf);
eta_o = 1 - f.h / (f.h + f.s) * (1 - eta_f);
end
