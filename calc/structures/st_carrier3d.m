function Cr = st_carrier3d(in, L, Hmax)
%ST_CARRIER3D  3-D check of the lightened carrier with the propeller shaft (step 3.5).
%   Cr = st_carrier3d(in, L)
%   Cr = st_carrier3d(in, L, Hmax)
%
%   in = st_inputs; L: T_mct [N m] (propeller torque at maximum continuous
%   torque), cases (struct array name, T [N m], Kgam): the torque and the
%   K_gamma P99 of each limit case (LD-01, LD-08). The carrier is
%   cad/step/carrier.stp (step 3.1: two 15 mm plates with eight rim scallops,
%   four posts, four hollow pins, the 120/100 propeller shaft to z = 535 mm),
%   AISI 4340, quadratic tetrahedra. The CATIA body has the pins in one
%   piece; step 3.4 makes them separate M50NiL pins pressed into the plates,
%   so the press fit is added at the pin bores by the Lame solution (pin
%   ring r_bore..r_pin in a plate ring r_pin..r_out_eff, diametral
%   interference delta_pin) and superposed on the finite element stress at
%   the plate around the bore. Support: the shaft end face (the propeller
%   flange) fixed. Load: the planet force of each pin, F = T / (N a), as a
%   uniform tangential traction on the pin surface; the most loaded pin
%   carries K_gamma F, the other three share the rest.
%   Windup: mean tangential displacement of the pin axes over a, minus the
%   rotation of the shaft section at z = 150 mm, i.e. the carrier's own
%   windup at MCT [deg and um at the pin circle].
%   Stress: von Mises in the plates and posts (z < 112 mm, away from the
%   loaded pin surfaces), yield safety 1100 / sig, with and without the
%   press fit; the press fit alone: contact pressure, hoop stress at the
%   plate bore and its yield safety.
%   Output Cr: windup_deg, windup_um, sig [MPa] and n_y per limit case,
%   press (p, sig_hoop, n_y), sig_with_press, n_y_with_press, m [kg],
%   n_nodes; R (LD-08 result for the plots).
%   Source: Phase 3 report, Section 3.5 ("Carrier").

if nargin < 3, Hmax = in.Hmax_carrier; end
c = in.carr;
g = fegeometry(in.carrier_step);
m0 = femodel(AnalysisType='structuralStatic', Geometry=g);
m0.MaterialProperties = materialProperties(YoungsModulus=in.st.E, PoissonsRatio=in.st.nu);
m0 = generateMesh(m0, Hmax=Hmax, GeometricOrder='quadratic');
msh = m0.Geometry.Mesh;
N = msh.Nodes;
Cr.n_nodes = size(N, 2);
Cr.m = volume(msh) * in.st.rho;
f_end = nearestFace(g, [0.055 0 0.535]);
ang = (0:3) * pi / 2;
for k = 1:4                                          % the two half-cylinder faces of each pin
    cx = c.a * cos(ang(k));  cy = c.a * sin(ang(k));
    for s = [-1 1]
        t = ang(k) + s * pi / 2 + 0.3 * s;
        fp(k, (s + 3) / 2) = nearestFace(g, [cx + c.r_pin * cos(t), cy + c.r_pin * sin(t), 0.056]); %#ok<AGROW>
    end
end
Lp = c.z_plates(2, 1) - c.z_plates(1, 2);            % free pin length between the plates [m]
tr = @(F, k) F / (2 * pi * c.r_pin * Lp) * [-sin(ang(k)); cos(ang(k)); 0];   % tangential traction on pin k

    function R = run(T, Kg)
        mm = m0;
        mm.FaceBC(f_end) = faceBC(Constraint='fixed');
        F = T / (4 * c.a);
        Fk = [Kg, (4 - Kg) / 3 * [1 1 1]] * F;
        for kk = 1:4
            for ss = 1:2
                mm.FaceLoad(fp(kk, ss)) = faceLoad(SurfaceTraction=tr(Fk(kk), kk));
            end
        end
        R = solve(mm);
    end

% windup at MCT (equal pins)
R = run(L.T_mct, 1);
th = atan2(N(2, :), N(1, :));
ut = -R.Displacement.ux' .* sin(th) + R.Displacement.uy' .* cos(th);
r = hypot(N(1, :), N(2, :));
z = N(3, :);
pinax = false(size(r));
for k = 1:4
    pinax = pinax | (hypot(N(1, :) - c.a * cos(ang(k)), N(2, :) - c.a * sin(ang(k))) < c.r_bore + 1e-3 & z > 0.04 & z < 0.07);
end
rot_pin = mean(ut(pinax) ./ r(pinax));
sec = abs(z - 0.150) < 0.003 & r > 0.0595;
rot_sh = mean(ut(sec) ./ r(sec));
Cr.windup_deg = abs(rot_pin - rot_sh) * 180 / pi;
Cr.windup_um = abs(rot_pin - rot_sh) * c.a * 1e6;
Cr.rot_shaft_deg = abs(rot_sh) * 180 / pi;
% pin tilt at MCT: tangential displacement of the pin axis near the rear and the front plate, over
% the 70 mm face width (adds to the helix misalignment of both planet meshes)
pinb = false(size(r));
for k = 1:4
    pinb = pinb | hypot(N(1, :) - c.a * cos(ang(k)), N(2, :) - c.a * sin(ang(k))) < c.r_bore + 1e-3;
end
zr = c.z_plates(1, 2) + 0.010;  zf = c.z_plates(2, 1) - 0.010;
u1 = mean(ut(pinb & abs(z - zr) < 0.004));  u2 = mean(ut(pinb & abs(z - zf) < 0.004));
Cr.pin_tilt_um = abs(u2 - u1) / (zf - zr) * 0.070 * 1e6;

% press fit of the separate pins (Lame): hollow pin in a plate ring, same E
a = c.r_bore;  b = c.r_pin;  d = c.r_out_eff;  E = in.st.E;
delta = c.delta_pin * 1e-3 / 2;                      % radial interference [m]
p = delta / (b / E * ((d^2 + b^2) / (d^2 - b^2) + in.st.nu) + b / in.m50.E * ((b^2 + a^2) / (b^2 - a^2) - in.m50.nu));
Cr.press = struct('p', p / 1e6, 'sig_hoop', p * (d^2 + b^2) / (d^2 - b^2) / 1e6);
Cr.press.n_y = in.st.sy / sqrt(Cr.press.sig_hoop^2 + Cr.press.p^2 + Cr.press.sig_hoop * Cr.press.p);

% limit cases: stress in the plates and posts, away from the loaded pin faces
plate = z < c.z_plates(2, 2) + 1e-4;
nearpin = false(size(r));
for k = 1:4
    nearpin = nearpin | hypot(N(1, :) - c.a * cos(ang(k)), N(2, :) - c.a * sin(ang(k))) < c.r_pin + 1.5e-3 & ...
              z > c.z_plates(1, 2) + 2e-3 & z < c.z_plates(2, 1) - 2e-3;
end
bore = false(size(r));
for k = 1:4
    bore = bore | hypot(N(1, :) - c.a * cos(ang(k)), N(2, :) - c.a * sin(ang(k))) < c.r_pin + 4e-3 & ...
           (z < c.z_plates(1, 2) + 1e-3 | z > c.z_plates(2, 1) - 1e-3);
end
for q = 1:numel(L.cases)
    R = run(L.cases(q).T, L.cases(q).Kgam);
    vm = R.VonMisesStress' / 1e6;
    ok = plate & ~nearpin;
    Cr.sig(q) = max(vm(ok));
    Cr.n_y(q) = in.st.sy / Cr.sig(q);
    Cr.sig_bore(q) = max(vm(bore));
    Cr.sig_with_press(q) = max(Cr.sig(q), Cr.sig_bore(q) + Cr.press.sig_hoop);
    Cr.n_y_with_press(q) = in.st.sy / Cr.sig_with_press(q);
    Cr.sig_shaft(q) = max(vm(z > 0.130 & z < 0.500));
end
Cr.R = R;
Cr.names = {L.cases.name};
end
