function e = beam_timoshenko(L, d_o, d_i, mat)
%BEAM_TIMOSHENKO  Matrices of a hollow circular Timoshenko beam element in one plane.
%   e = beam_timoshenko(L, d_o, d_i, mat)
%
%   Inputs
%     L          element length                                        [m]
%     d_o, d_i   outer and inner diameter                              [m]
%     mat        struct: E [Pa], nu [-], rho [kg/m^3]
%
%   Output struct e, matrices for the plane DOFs (w1, phi1, w2, phi2), with
%   phi = dw/dz the rotation of the cross-section in that plane
%     K       bending stiffness, shear included                        [N/m ...]
%     Mt      translational mass, consistent                           [kg ...]
%     Mr      rotary inertia of the cross-sections                     [kg m^2 ...]
%     MJ      polar version of Mr (J = 2 I); it builds the gyroscopic
%             matrix in rotor_model                                     [kg m^2 ...]
%     Phi     shear parameter 12 E I / (kappa G A L^2)                  [-]
%     kappa   shear coefficient                                         [-]
%
%   Shear coefficient of Cowper (1966) for a hollow circle, the one ROSS
%   uses. Element matrices of Friswell, Penny, Garvey and Lees, Dynamics of
%   Rotating Machines (2010), Section 5.4, the same as Nelson (1980).
%
%   Source: Phase 2 report, Section 2.1 ("Model"). Tested by test_step21
%   (TC18: simply supported beam against the Timoshenko frequency equation).

E = mat.E;
G = E / (2 * (1 + mat.nu));
A = pi / 4 * (d_o^2 - d_i^2);
I = pi / 64 * (d_o^4 - d_i^4);
m = d_i / d_o;
kappa = 6 * (1 + mat.nu) * (1 + m^2)^2 / ((7 + 6 * mat.nu) * (1 + m^2)^2 + (20 + 12 * mat.nu) * m^2);
Phi = 12 * E * I / (kappa * G * A * L^2);

K = E * I / ((1 + Phi) * L^3) * ...
    [ 12,          6*L,           -12,          6*L;
      6*L,   (4 + Phi)*L^2,      -6*L,   (2 - Phi)*L^2;
     -12,         -6*L,            12,         -6*L;
      6*L,   (2 - Phi)*L^2,      -6*L,   (4 + Phi)*L^2];

m1 = 312 + 588*Phi + 280*Phi^2;
m2 = (44 + 77*Phi + 35*Phi^2) * L;
m3 = 108 + 252*Phi + 140*Phi^2;
m4 = -(26 + 63*Phi + 35*Phi^2) * L;
m5 = (8 + 14*Phi + 7*Phi^2) * L^2;
m6 = -(6 + 14*Phi + 7*Phi^2) * L^2;
Mt = mat.rho * A * L / (840 * (1 + Phi)^2) * ...
     [ m1,  m2,  m3,  m4;
       m2,  m5, -m4,  m6;
       m3, -m4,  m1, -m2;
       m4,  m6, -m2,  m5];

r1 = (3 - 15*Phi) * L;
r2 = (4 + 5*Phi + 10*Phi^2) * L^2;
r3 = (-1 - 5*Phi + 5*Phi^2) * L^2;
Mr = mat.rho * I / (30 * (1 + Phi)^2 * L) * ...
     [ 36,   r1, -36,   r1;
       r1,   r2, -r1,   r3;
      -36,  -r1,  36,  -r1;
       r1,   r3, -r1,   r2];

e = struct('K', K, 'Mt', Mt, 'Mr', Mr, 'MJ', 2 * Mr, 'Phi', Phi, 'kappa', kappa, ...
           'A', A, 'I', I, 'd_o', d_o);
end
