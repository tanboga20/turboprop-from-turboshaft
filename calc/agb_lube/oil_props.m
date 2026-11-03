function o = oil_props(T, oil)
%OIL_PROPS  Properties of the MIL-PRF-23699 oil at one temperature.
%   o = oil_props(T, oil)
%
%   Inputs
%     T     oil temperature                                          [degC]
%     oil   struct from lube_inputs: nu40, nu100 [cSt], rho15 [kg/m^3],
%           alpha_rho [1/K], cp [J/(kg K)]
%
%   Output struct o
%     nu    kinematic viscosity                                      [cSt = mm^2/s]
%     rho   density                                                  [kg/m^3]
%     eta   dynamic viscosity                                        [mPa s = cP]
%     cp    specific heat                                            [J/(kg K)]
%     A, B  constants of the Walther line                            [-]
%
%   Viscosity: Walther equation of ASTM D341, log10(log10(nu + 0.7)) =
%   A - B log10(T + 273.15), through the data sheet values at 40 and 100 degC.
%   It is meant for 40 to 150 degC; at -40 degC it gives about 19,000 cSt
%   against the 11,000 cSt measured, so cold starts use the data sheet value.
%   Density falls linearly with temperature from its 15 degC value.
%
%   Source: Phase 1 report, Section 4 ("Power losses and efficiency").
%   Tested by test_step14 (TC10).

T1 = 40 + 273.15;
T2 = 100 + 273.15;
Y1 = log10(log10(oil.nu40 + 0.7));
Y2 = log10(log10(oil.nu100 + 0.7));
B = (Y1 - Y2) / (log10(T2) - log10(T1));
A = Y1 + B * log10(T1);

nu = 10^(10^(A - B * log10(T + 273.15))) - 0.7;
rho = oil.rho15 * (1 - oil.alpha_rho * (T - 15));
o = struct('nu', nu, 'rho', rho, 'eta', nu * rho / 1000, 'cp', oil.cp, 'A', A, 'B', B);
end
