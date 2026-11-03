function W = os_lubmass(in, N, vol, li)
%OS_LUBMASS  Mass of the modelled oil hardware and of the LUB-07 mist system, for the SYS-06 roll-up.
%   W = os_lubmass(in, N, vol, li)
%
%   in = os_inputs, N = os_network, vol = cad/assy/part_volumes.csv (CATIA
%   volumes), li = lb_inputs. The CATIA bodies of tubes and drillings are
%   oil volumes, so they are not weighed as such:
%     jets: nozzle volume x count, steel;
%     carrier transfer sleeve: CATIA volume, steel; pitch oil tube: CATIA
%       volume, Ti-6Al-4V;
%     external tubes: route length x tube wall area (in.tube_wall), steel,
%       plus in.k_fittings for fittings, clamps and bosses; drillings remove
%       casting metal that the roll-up still counts (a small conservative
%       error, W.drill_metal [kg], not subtracted);
%     the filter housing, valves and the HUMS items stay as the allowances of
%     step 3.1.
%   These replace the step 3.1 allowance "oil jets, tubes and manifolds".
%   LUB-07 mist system (Hamit's decision): accumulator for 6 min at
%   1 mL/min per contact on the 31 contacts with a volume margin
%   in.mist.V_margin, plus the shut-off/mixing valve, the tie-in and mist
%   lines and the bleed line (in.mist masses, TBR).
%   Output W: jets, sleeve, pitch_tube, tubes, lub_hw (their sum), V_acc [L],
%   mist (kg) and its parts, drill_metal.
%   Source: Phase 3 report, Section 3.2 ("Mass").

vm = containers.Map(cellstr(vol.part), num2cell(vol.volume_mm3));
st = 7830e-9;  ti = 4430e-9;
B = N.branch;
W.jets = 0;  L8 = 0;  L6 = 0;  Ld = 0;
for k = 1:numel(B)
    for j = 1:numel(B(k).jet)
        jj = B(k).jet(j);
        if jj.nozzle && B(k).catia
            W.jets = W.jets + vm(sprintf('oil_jet_%03d', round(jj.d * 100))) * st;
        end
        Ld = Ld + sum(vecnorm(diff(jj.feed), 2, 2));
    end
    if B(k).d_gal >= 8, L8 = L8 + B(k).L_gal; else, L6 = L6 + B(k).L_gal; end
end
tw = in.tube_wall;
A8 = pi / 4 * ((8 + 2 * tw(1))^2 - 8^2);
A6 = pi / 4 * ((6 + 2 * tw(2))^2 - 6^2);
W.tubes = (L8 * A8 + L6 * A6) * st * (1 + in.k_fittings);
W.sleeve = vm('oil_transfer_sleeve') * st;
W.pitch_tube = vm('oil_pitch_tube') * ti;
W.lub_hw = W.jets + W.tubes + W.sleeve + W.pitch_tube;
W.L_tubes = L8 + L6;
W.drill_metal = Ld * pi / 4 * in.d_branch^2 * 2680e-9;
% LUB-07 mist system
ms = in.mist;
W.V_acc = 1.0e-3 * 31 * 6 * ms.V_margin;              % L: 1 mL/min per contact, 6 min, margin
W.mist_parts = struct('oil', W.V_acc * li.oil.rho15 / 1000, 'accumulator', max(W.V_acc * ms.m_acc_per_L, ms.m_acc_min), ...
                      'valve', ms.m_valve, 'lines', ms.m_lines, 'bleed_line', ms.m_air_line);
W.mist = sum(struct2array(W.mist_parts));
end
