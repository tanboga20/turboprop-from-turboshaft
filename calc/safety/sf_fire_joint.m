function J = sf_fire_joint(in, partition)
%SF_FIRE_JOINT  The P101 / F201 flange joint in the fire (D5 F3): transient 2-D r-z, explicit finite volumes.
%   J = sf_fire_joint(in, partition)   in = sf_inputs; partition true: the flame only on the F201 side (ICD-39),
%                                      false: also on the P101 flange ring (no partition, the fallback case)
%
%   Axisymmetric section on a 2 mm grid, r 45-163 mm, z -12..12 mm (joint plane z = 0): the F201 flange (r 129-163,
%   z -12..0, fire side), the P101 flange and shell (r 129-163, z 0..12) and the P101 rear wall (r 45-129, z 0..10),
%   in perfect contact at the joint plane. Flame (upper tolerance, radiation-scaled flux at the cell temperature) on
%   the F201 flange outside diameter and its fire-side face outside the shell (r > 137); without the partition also
%   on the P101 flange ring. Oil at the sink with the film h of the F201 wall (in.fire.joint.h) on the F201 bore, the
%   P101 shell bore and the inner face of the rear wall; the cuts into the shells are adiabatic (conservative). The
%   bolt holes are not modelled. Reported at the end of the flow phase (5 min): the bolt-head seat on P101 (r 154,
%   outer face), the insert in F201 (r 154, mid depth), the F201 outer face at the bolt circle, the O-ring groove
%   (r 140) on both sides of the joint plane, the hottest P101 temperature.
%   Source: Phase 3 report, Section 3.7 (D5 F3).

fw = in.fire;  jn = fw.joint;
d = 2e-3;  rc = (46:2:162)' * 1e-3;  zc = (-11:2:11) * 1e-3;     % cell centres [m]
[Z, R] = meshgrid(zc, rc);                                       % rows r, columns z
solid = (R > 0.129 & Z < 0) | (R > 0.129 & Z > 0) | (R < 0.129 & Z > 0 & Z < 0.010);
TK = @(T) T + 273.15;
qf = @(T) fw.q0 * (TK(fw.T_f)^4 - TK(T).^4) / (TK(fw.T_f)^4 - TK(fw.T0)^4);
heff = 1 / (1 / jn.h + d / 2 / fw.k);
nr = numel(rc);  nz = numel(zc);
% neighbours present
S = false(nr + 2, nz + 2);  S(2:end - 1, 2:end - 1) = solid;
nE = S(3:end, 2:end - 1) & solid;  nW = S(1:end - 2, 2:end - 1) & solid;
nN = S(2:end - 1, 3:end) & solid;  nS = S(2:end - 1, 1:end - 2) & solid;
% boundary faces: oil on the F201 bore and P101 shell bore (west faces at r 129), the rear-wall inner face (north
% face at z 10); flame on the F201 outside diameter and its fire-side face outside the shell; P101 ring without the
% partition
oilW = solid & ~nW & abs(R - 0.130) < 1e-6;
oilN = solid & ~nN & R < 0.129 & abs(Z - 0.009) < 1e-6;
flE = solid & ~nE & Z < 0;
flS = solid & ~nS & Z < 0 & R > 0.137;
if ~partition
    flE = flE | (solid & ~nE & Z > 0);
    flN = solid & ~nN & Z > 0 & R > 0.137;
else
    flN = false(size(solid));
end
Ae = (R + d / 2) * d;  Aw = (R - d / 2) * d;  Az = R * d;  V = R * d * d;   % per radian
T = fw.T_sink * ones(nr, nz);
dt = jn.dt;  n = round(fw.t_flow / dt);
Tmax = T;
for it = 1:n
    Tp = zeros(nr + 2, nz + 2);  Tp(2:end - 1, 2:end - 1) = T;     % edges masked by the neighbour flags
    q = fw.k / d * (nE .* Ae .* (Tp(3:end, 2:end - 1) - T) + nW .* Aw .* (Tp(1:end - 2, 2:end - 1) - T) ...
        + nN .* Az .* (Tp(2:end - 1, 3:end) - T) + nS .* Az .* (Tp(2:end - 1, 1:end - 2) - T));
    q = q + heff * (fw.T_sink - T) .* (oilW .* Aw + oilN .* Az) + qf(T) .* (flE .* Ae + (flS | flN) .* Az);
    T(solid) = T(solid) + dt * q(solid) ./ (fw.rho * fw.cp(T(solid)) .* V(solid));
    Tmax = max(Tmax, T);
end
cell = @(r, z) Tmax(abs(rc - r * 1e-3) < 1e-6, abs(zc - z * 1e-3) < 1e-6);
J.T_seat_P101 = cell(154, 11);
J.T_insert_F201 = (cell(154, -7) + cell(154, -5)) / 2;
J.T_face_F201 = cell(154, -11);
J.T_oring_F201 = cell(140, -1);
J.T_oring_P101 = cell(140, 1);
J.T_P101_max = max(Tmax(solid & Z > 0));
J.T_F201_max = max(Tmax(solid & Z < 0));
J.T = Tmax;  J.solid = solid;  J.rc = rc;  J.zc = zc;  J.partition = partition;
end
