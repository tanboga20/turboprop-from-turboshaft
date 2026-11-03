function M = as_mass(in, L, vol, X)
%AS_MASS  Mass roll-up of the complete RGB against SYS-06 (step 3.1).
%   M = as_mass(in, L, vol)
%   M = as_mass(in, L, vol, X)
%
%   in = as_inputs, L = as_layout, vol: table of part volumes measured in
%   CATIA (cad/assy/part_volumes.csv, columns part and volume_mm3, written
%   by every part script through SaveParts in cad/scripts/catlib.vbs). Each instance of L.inst gets the volume of
%   its part times the density of its material times its fill factor
%   (bearings and seals are solid envelopes); the pump pack has a fixed
%   mass; customer equipment (generator, OSG, PCU units) is listed but not
%   counted. Then the allowances of as_inputs: bolts and locking (a share
%   of the modelled mass until step 3.4; from Hamit's mass card the bottom-up
%   list in.fasteners, with the in.extra parts: seat liners, dowels, bosses),
%   oil jets and tubes, HUMS sensors, filter housing.
%   SYS-06 (dry RGB with propeller shaft and accessory drives) <= 100 kg;
%   the airframe-mounted oil cooler and tank are shown separately.
%   Output M: per-instance table M.items (part, module, kg), per-part
%   table M.parts, module totals M.module, M.modelled, M.allowances,
%   M.total, M.margin (against the v3 limit, 100 kg), M.margin_tbr (against
%   110 kg TBR, Hamit's decision in step 3.1), M.with_ext; the input drive
%   (SYS-11): M.tunnel (estimate from in.tunnel), M.drive (PT output shaft,
%   couplings and tunnel), M.margin_drive against in.m_drive_limit, and
%   M.total_with_drive (RGB + input drive; the report always shows it).
%   With X (step 3.2: X.lub_hw, the weighed oil hardware, and X.mist, the
%   LUB-07 mist system, kg; read from cad/params/oil_network.txt) both are
%   added to the modelled mass and the weighed oil hardware replaces the
%   allowance "oil jets, tubes and manifolds".
%   Source: Phase 3 report, Sections 3.1 and 3.2 ("Mass").

steel = {'planet', 'sun', 'ring', 'carrier', 'gear2', 'pinion', 'gen_gear', 'planet_rollers'};
alu = {'case', 'fs_case', 'acc_cover'};             % gen_cartridge carries its own A357 density
rv = containers.Map({L.rev.name}, num2cell(1:numel(L.rev)));
vm = containers.Map(cellstr(vol.part), num2cell(vol.volume_mm3));
n = height(L.inst);
kg = zeros(n, 1);
for i = 1:n
    p = L.inst.part{i};
    if strcmp(L.inst.module{i}, 'equipment'), continue, end
    if strcmp(p, 'pump_pack'), kg(i) = in.pump.m; continue, end
    v = vm(p);
    if any(strcmp(p, steel))
        kg(i) = v * in.rho.steel * 1e-9;
    elseif any(strcmp(p, alu))
        kg(i) = v * in.rho.A357 * 1e-9;
    else
        r = L.rev(rv(p));
        kg(i) = v * r.rho * r.fill * 1e-9;
    end
end
M.items = table(L.inst.part, L.inst.module, kg, 'VariableNames', {'part', 'module', 'kg'});
[u, ~, j] = unique(M.items.part, 'stable');
M.parts = table(u, accumarray(j, 1), accumarray(j, kg), 'VariableNames', {'part', 'count', 'kg'});
mods = {'planetary', 'first_stage', 'accessories'};
for k = 1:numel(mods)
    M.module.(mods{k}) = sum(kg(strcmp(M.items.module, mods{k})));
end
M.modelled = sum(kg);
am = [in.allow.m];
if nargin >= 4
    M.lub_hw = X.lub_hw;  M.mist = X.mist;
    M.modelled = M.modelled + X.lub_hw + X.mist;
    am(1) = 0;                                         % replaced by the weighed oil hardware
end
if isfield(in, 'fasteners')                            % package B basis (step 3.5): bottom-up fasteners and extras
    M.bolts = in.fasteners;
    M.extra = sum([in.extra.m]);
else
    M.bolts = in.allow_share * M.modelled;
    M.extra = 0;
end
M.allowances = M.bolts + sum(am) + M.extra;
M.total = M.modelled + M.allowances;
M.margin = in.m_limit - M.total;                       % against v3 (100 kg)
M.margin_tbr = in.m_limit_tbr - M.total;               % against 110 kg (TBR)
M.with_ext = M.total + sum([in.ext.m]);
% input drive (SYS-11): shells of the tunnel between the diaphragms, plus end rings and supports
t = in.tunnel;
shell = @(r, th, rho) pi * ((r + th)^2 - r^2) * t.L * rho * 1e-9;
r1 = t.r_in + t.t_liner;  r2 = r1 + t.t_ins;
M.tunnel = shell(t.r_in, t.t_liner, t.rho_liner) + shell(r1, t.t_ins, t.rho_ins) + shell(r2, t.t_skin, t.rho_skin) + t.m_ends;
M.drive = in.drive.shaft + in.drive.couplings + M.tunnel;
M.margin_drive = in.m_drive_limit - M.drive;
M.total_with_drive = M.total + M.drive;
end
