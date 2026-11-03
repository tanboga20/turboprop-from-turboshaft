function P = windage_loss(d, b, n, mu_mist)
%WINDAGE_LOSS  Windage loss of one gear spinning in the air-oil mist (NASA TM-83716).
%   P = windage_loss(d, b, n, mu_mist)
%
%   Inputs
%     d         pitch diameter                                       [mm]
%     b         face width                                           [mm]
%     n         speed; for planets and the sun, relative to the carrier [rpm]
%     mu_mist   absolute viscosity of the air-oil mist               [cP]
%
%   Output
%     P         windage loss                                         [W]
%
%   P = 2.82e-7 (1 + 2.3 b/R) n^2.8 R^4.6 (0.028 mu + 0.019)^0.2 in kW,
%   with R the pitch radius in m and n in rpm: the SI form of Anderson,
%   Loewenthal and Black (NASA TM-83716, 1984), C4 = 2.82e-7 and C5 = 0.019.
%
%   Source: Phase 1 report, Section 4 ("Power losses and efficiency").
%   Tested by test_step14 (TC13).

R = d / 2000;
P = 1000 * 2.82e-7 * (1 + 2.3 * b / (d / 2)) * n^2.8 * R^4.6 * (0.028 * mu_mist + 0.019)^0.2;
end
