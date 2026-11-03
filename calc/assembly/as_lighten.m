function O = as_lighten(in, L, M, gi)
%AS_LIGHTEN  Further mass reduction options against SYS-06 (step 3.1).
%   O = as_lighten(in, L, M, gi)
%
%   in = as_inputs, L = as_layout, M = as_mass, gi = gd_inputs. The model
%   already carries package A (lightened placeholder propeller flange,
%   6 mm side walls and 8 mm end walls on the first-stage case and the
%   cover, hollow planet pins). Two options remain, each estimated from the
%   modelled geometry (strength in step 3.5, dynamics in step 3.6):
%     m5  castings in WE43-T6 magnesium instead of A357-T6 (reverses
%         decision 6: bearing seat stiffness 1.2 x the floor instead of
%         1.9 x, ENV-03 corrosion and SAF-05 fire)
%     m6  propeller shaft section from the front carrier plate to the flange
%         in Ti-6Al-4V (bending stiffness -44%: DYN-05 must be re-run)
%   Packages: A (as modelled), B = A + m6, C = A + m5, D = A + m5 + m6; the
%   bolt allowance follows the modelled mass. Output O: table O.measures
%   (measure, kg saved), table O.pkg (package, total kg, margin to SYS-06).
%   Source: Phase 3 report, Section 3.1 ("Mass").

kg = @(part) M.parts.kg(strcmp(M.parts.part, part));
cast = kg('case') + kg('fs_case') + kg('acc_cover') + kg('gen_cartridge');
m5 = cast * (1 - 1840 / in.rho.A357);
v_sh = pi * (60^2 - 50^2) * (L.carrier.ze - (2 * 15 + gi.carrier.L_pin));
m6 = v_sh * (in.rho.steel - in.rho.Ti) * 1e-9;
O.measures = table({'m5 WE43 magnesium castings (reverses decision 6)'; ...
                    'm6 titanium propeller shaft section (DYN-05 re-run)'}, [m5; m6], ...
                   'VariableNames', {'measure', 'kg_saved'});
tot = M.total - [0; m6; m5; m5 + m6] * (1 + in.allow_share);
O.pkg = table({'A: as modelled'; 'B: A + m6'; 'C: A + m5'; 'D: A + m5 + m6'}, tot, in.m_limit - tot, ...
              'VariableNames', {'package', 'total_kg', 'margin_kg'});
end
