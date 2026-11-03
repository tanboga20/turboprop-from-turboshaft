function in = hs_inputs()
%HS_INPUTS  Inputs and assumptions of step 2.8: housing and component finite element models.
%   in = hs_inputs()
%
%   The RGB case is modelled axisymmetric about the propeller axis: the
%   attachment flange on the engine side, the rear wall with the
%   intermediate shaft bearing, the planetary case around the ring gear, the
%   front wall (a diaphragm carrying the inner propeller bearing) and the
%   conical nose to the outer propeller bearing seat (step 2.5 bearings, 300
%   mm apart in the step 2.5 layout model, 283 mm here between seat
%   centres). The offset first-stage case is not in this model.
%   in.case0 is the first section (flat front wall, cylindrical nose): it
%   failed the seat stiffness floor and, with cast fillets, the limit
%   stress, which led to the conical nose (Section 2.8, "Design iteration").
%   Every value is an assumption listed in Section 2.8 of the Phase 2
%   report. Units: mm, N, Pa, kg/m^3, MPa, Hz unless noted.

% Half section: pieces that touch but do not overlap, rectangles [r1 r2 z1 z2] and polygons
% [r z] [mm]; z from the engine side (flange face, z = 0) to the propeller
in.case.rects = {[45 137.5 2 12], ...                 % rear wall, intermediate shaft bearing bore 90
                 [137.5 153.5 0 12], ...              % attachment flange outside the wall
                 [129.5 137.5 0 2], ...               % flange face under the wall
                 [129.5 137.5 12 130], ...            % planetary case wall, bore 259 = ring gear OD (root 243 + 2 x 8 rim)
                 [86 90 130 132], ...                 % inner propeller bearing shoulder, bore 172
                 [90 137.5 130 140], ...              % front wall
                 [90 108 140 160], ...                % inner propeller bearing boss (seat bore 180, z 132-160)
                 [129.5 140; 137.5 140; 108 412; 100 412], ...   % conical nose, 8 mm radial wall
                 [90 108 412 446]};                   % outer roller and QJ seat and boss
in.case0 = [ 45 137.5   2  12;                        % first section: rear wall
            129.5 153.5 0  12;                        % attachment flange
            129.5 137.5 2 140;                        % planetary case wall
             92 137.5 130 140;                        % flat front wall
             92 100 130 446;                          % cylindrical nose, relief bore 184 between the seats
             90 108 132 160;                          % inner propeller bearing seat and boss (seat bore 180)
             90 108 412 446];                         % outer roller and QJ seat and boss
in.case.rf = 5;                                       % cast fillet radius at re-entrant corners (TBR)
in.case.pt_flange = [0.140 0 0];            % m, points that pick the faces
in.case.pt_seat_in = [0 -0.090 0.146];
in.case.pt_seat_out = [0 -0.090 0.429];
in.case.seat_in = [28 90];                  % [width radius] mm
in.case.seat_out = [34 90];

% Materials: sand-cast A357-T6 aluminium and WE43-T6 magnesium (typical design values, TBR)
in.mat(1) = struct('name', 'A357-T6', 'E', 72e9, 'nu', 0.33, 'rho', 2680, 'sy', 240, 'su', 310);
in.mat(2) = struct('name', 'WE43-T6', 'E', 44.2e9, 'nu', 0.27, 'rho', 1840, 'sy', 160, 'su', 230);
in.k_floor = 5e7;                           % N/m, seat stiffness floor for DYN-05 (step 2.1, Hamit's decision A)
in.k_target = 2e8;                          % N/m, seat stiffness step 2.1 asked for

% Bolted attachment flange (TBR, VDI 2230 check in Phase 3): 30 x M6 12.9 on PCD 290, 24 mm grip
in.flange = struct('n', 30, 'As', 20.1, 'L_grip', 24, 'E_bolt', 206e9, 'A', pi * (153.5^2 - 129.5^2));

% Limit loads on the propeller bearings (LD-05 with 2.5 g, LD-03/04 thrust; step 2.5 layout)
in.m_prop = 76.4;  in.g = 9.81;  in.a = 250;  in.span = 300;  in.nz = 2.5;  in.M_gyro = 7190;
in.F_ax = 20e3;

% Mesh and modes
in.Hmax = 0.008;                            % m, about one quadratic element through the walls
in.n_seg = 120;
in.f_max = 7600;                            % Hz, up to the top of the planetary 2x band
in.f_bands = [2733 3749; 5466 7497];        % Hz, planetary mesh 1x and 2x with the speed range and +-10%

% Verification (Section 2.8): global meshes for the convergence study, filleted submodels of the
% most loaded re-entrant corners (window half size, facets each side, element sizes on the fillet)
in.verify = struct('Hmax', [0.012 0.010 0.008], 'n_corners', 2, 'half', 30, 'n_fac', 6, 'n_sub', 2, ...
                   'Hmax_sub', 3, 'h_sub', [3 2 1.5 1 0.7], 'h_hole', [4 2 1 0.5 0.35 0.25]);

% First-stage gear blank in 3-D (DYN-04 web check handed on by step 2.4): hub length as in the CAD model
in.web = struct('Hmax', 0.004, 'f_max', 16000, 'L_hub', 40);

% Planet 3-D model (DYN-04)
in.planet.Hmax = 0.004;
in.planet.f_max = 12000;
end
