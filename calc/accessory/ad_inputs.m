function in = ad_inputs()
%AD_INPUTS  Inputs and assumptions of step 2.6: the accessory drives of the RGB.
%   in = ad_inputs()
%
%   The power-turbine-driven pads of ACC-02 come off the step 2.4 gear
%   design (calc/gear_detail on the path): the generator gear meshes with
%   the first-stage gear, the overspeed governor (OSG) pair runs from the
%   generator shaft, the propeller control unit (PCU) pinion is cut on the
%   front stub of the intermediate shaft and the oil pump pack sits on a
%   quill inside that stub (Phase 1 step 1.4 layout). Requirement IDs are in
%   the comments; every other value is an assumption listed in Section 2.6
%   of the Phase 2 report. Units: mm, N, N m, MPa, rpm unless noted.

% Pad torques (ACC-02, CT7-9 TCDS) and the oil pump torque of step 2.7
in.T_gen_cont = 41.8;                       % N m, AC generator, continuous
in.T_gen_max = 46.89;                       % N m, AC generator, overload
in.T_osg = 1.13;                            % N m, overspeed governor
in.T_pcu = 1.81;                            % N m, propeller control unit
in.T_pump = 3.69;                           % N m, supply and scavenge pump pack (step 2.7)
in.ratio_ct7 = struct('gen', 0.54650, 'osg', 0.38091);   % CT7-9 pad speed / power turbine speed

% Gear pairs. Gear 1 is the smaller gear of each pair.
%   gen: generator gear (z 57, driven) on the first-stage gear (z 110 of step 2.4, its helix and module)
%   osg: pinion cut on the generator shaft (driver) / OSG gear
%   pcu: pinion cut on the intermediate shaft stub (driver) / PCU gear
% x: profile shifts that balance the specific sliding at the roots; b: face width; A: ISO 1328-1 class;
% Rz: flank roughness [um] (the generator gear runs on the superfinished first-stage gear);
% hub_d: hub (or shaft shoulder) diameter of the larger gear's blank, a solid disc of width b; bore:
% bores of the gear bodies (the generator shaft and the intermediate shaft stub carry quills) [mm]
in.gen = struct('z', 57, 'x', 0.0, 'b', 16, 'A', 5, 'Rz', 0.8, 'hub_d', 80, 'bore', 16);
in.osg = struct('z', [21 30], 'm', 2.0, 'x', [0.1 -0.1], 'b', 6, 'A', 5, 'Rz', 2.0, 'hub_d', 20, 'bore', [16 10]);
in.pcu = struct('z', [20 73], 'm', 1.5, 'x', [0.4 -0.4], 'b', 10, 'A', 5, 'Rz', 2.0, 'hub_d', 40, 'bore', [14 12]);
% OSG: 21/30 at module 2 keeps the step 1.4 ratio (28/40) and centre distance but takes the pair out of the
% main resonance range of ISO 6336-1 (N 0.70 at 28/40 under this light load); PCU gear hub 40 mm for DYN-04
in.KA = 1.25;                               % STR-01 application factor on the maximum rated torque

% Pad safety (ACC-03)
in.k_fatigue = 1.5;                         % drives carry 1.5 x maximum rated torque in fatigue
in.k_shear = 4;                             % nominal shear torque of the neck / maximum rated torque
in.k_shear_min = 3;                         % lowest shear torque in the scatter band / maximum rated torque
in.d_neck_min = 5;                          % mm, smallest neck that can be made and inspected
in.neck_mat = struct('su', 1240, 'sy', 1100, 'tau_u_ratio', 0.67);   % AISI 4340 quill shafts
in.neck_scatter = 0.10;                     % +- share of the ultimate shear strength (heat treatment lot)
in.neck_tol = 0.02;                         % mm, +- neck diameter tolerance
in.Kfs_neck = 1.3;                          % fatigue notch factor of the neck fillet in torsion (r/d 0.15)
in.ripple = 0.10;                           % alternating torque / steady torque at the pads
in.ka_exp = [1.38 -0.067];                  % Marin surface factor, ground
in.ke = 0.753;                              % reliability 99.9%

% Accessory shaft bearings: deep groove ball bearings in ISO 02 envelopes, two per shaft, the gear midway
mk = @(name, d, D, B, Z, Dw, Dpw, span) struct('name', name, 'type', 'DGBB', 'd', d, 'D', D, 'B', B, ...
    'Z', Z, 'Dw', Dw, 'Lwe', 0, 'Dpw', Dpw, 'alpha', 0, 'i', 1, 'span', span);
in.brg(1) = mk('generator shaft', 25, 62, 17, 8, 11.0, 43.5, 60);     % 6305 envelope (6205: 7,000 h)
in.brg(2) = mk('OSG shaft', 15, 35, 11, 8, 5.953, 25, 40);            % 6202 envelope
in.brg(3) = mk('PCU shaft', 17, 40, 12, 8, 6.747, 28.5, 45);          % 6203 envelope
in.L10_req = 12000;                         % h, the STR-02 target applied to the accessory bearings

% Generator on its pad: mass and centre of gravity for the housing loads of step 2.8 (TBR)
in.m_gen = 16;                              % kg, 52 kW AC generator
in.x_cg_gen = 140;                          % mm, centre of gravity from the pad face
in.nz_man = 3.17;                           % LD-06 manoeuvre load factor
% step 3.3 sensitivity runs may override inputs (calc/interfaces/if_override; no effect otherwise)
if exist('if_override', 'file') == 2, in = if_override(in, mfilename); end
end
