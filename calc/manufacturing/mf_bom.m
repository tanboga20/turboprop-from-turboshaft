function B = mf_bom(Mx, W, ai, F, Ln)
%MF_BOM  Bill of materials of the RGB with the SYS-06 mass basis of each line (step 3.4).
%   B = mf_bom(Mx, W, ai, F, Ln)
%
%   Mx = the step 3.2 roll-up (step32.mat S.mass: as_mass with the oil
%   hardware and the mist system), W = os_lubmass (S.lubmass), ai =
%   as_inputs (allowances, external parts), F = mf_fasteners, Ln =
%   mf_liners. One line per part number: the CATIA parts of step 3.1 with
%   their measured mass, the weighed oil hardware and mist parts of step
%   3.2, the allowances, the standard parts, and the external oil system
%   parts (outside SYS-06). Column basis says how each mass enters the
%   roll-up: 'CATIA', 'weighed 3.2', 'allowance 3.1', 'estimate 3.4' (not
%   in the roll-up: the liners and the bottom-up fasteners, shown for step
%   3.5), 'in parent' (counted in another line), 'outside SYS-06'.
%   material is a key of mf_inputs (or 'supplier'). The sum of the
%   'CATIA', 'weighed 3.2' and 'allowance 3.1' lines equals Mx.total.
%   Output B: table B.T, B.rollup (that sum), B.bottom_up (roll-up with the
%   fastener allowance replaced by F.with_k and the liners added).
%   Source: Phase 3 report, Section 3.4 ("Bill of materials").

% part, part number, description, make/buy, material
P = {
 'case',           'RGB-P101', 'Planetary case, conical nose, attachment flange 30 x M6 on PCD 290', 'make', 'A357';
 'ring',           'RGB-P102', 'Ring gear z 119, m 2, b 70, nitrided', 'make', 'N13';
 'carrier',        'RGB-P103', 'Planet carrier with the propeller shaft 120/100 (one piece), 4 posts, scalloped plates', 'make', 'S43';
 'planet_pin',     'RGB-P104', 'Planet pin, hollow (bore 20), inner race of the planet bearing; press fit in the carrier (mass in P103)', 'make', 'M5N';
 'sun',            'RGB-P105', 'Sun gear z 45, m 2, b 70, crowned internal spline', 'make', 'P53';
 'sun_quill',      'RGB-P106', 'Sun quill shaft 50/30, fixed and crowned splines', 'make', 'S43';
 'planet',         'RGB-P107', 'Planet gear z 37, m 2, b 70; bore = outer race of the planet bearing', 'make', 'P53';
 'planet_rollers', 'RGB-P108', 'Planet bearing roller set, 18 rollers 7.5 x 56, full complement (matched set per planet)', 'buy', 'supplier';
 'brg_NU1024',     'RGB-P109', 'Propeller shaft roller bearing NU1024 class (aerospace)', 'buy', 'supplier';
 'brg_QJ1024',     'RGB-P110', 'Propeller shaft four-point contact bearing QJ1024 class (aerospace)', 'buy', 'supplier';
 'qj_housing',     'RGB-P111', 'Propeller bearing housing on the case nose', 'make', 'Ti64';
 'nut_KM24',       'RGB-P112', 'Propeller shaft nut M120 with locking key', 'make', 'S43';
 'seal_prop',      'RGB-P113', 'Propeller shaft carbon face seal, 122 x 160 (TBR)', 'buy', 'supplier';
 'ret_tube',       'RGB-P114', 'Propeller retention tube 90/80 x 600 (SAF-01, Decision 4)', 'make', 'Ti64';
 'prop_flange',    'RGB-P115', 'Propeller flange (placeholder, PIF-01 TBD)', 'make', 'S43';
 'fs_case',        'RGB-F201', 'First-stage (offset) case with engine mount ring', 'make', 'A357';
 'gear2',          'RGB-F202', 'First-stage gear z 110, mn 2, helical, damping ring groove', 'make', 'P53';
 'pinion',         'RGB-F203', 'Input pinion z 31, mn 2, with its bearing journals', 'make', 'P53';
 'mid_shaft',      'RGB-F204', 'Intermediate shaft 50/30 with the PCU pinion z 20', 'make', 'P53';
 'brg_NU2210',     'RGB-F205', 'Intermediate shaft roller bearing NU2210 class', 'buy', 'supplier';
 'brg_NU2209',     'RGB-F206', 'Input shaft roller bearing NU2209 class', 'buy', 'supplier';
 'brg_QJ210',      'RGB-F207', 'Intermediate shaft four-point contact bearing QJ210 class', 'buy', 'supplier';
 'brg_QJ209',      'RGB-F208', 'Input shaft four-point contact bearing QJ209 class', 'buy', 'supplier';
 'nut_KM10',       'RGB-F209', 'Intermediate shaft nut M50 with lock washer', 'make', 'S43';
 'nut_KM9',        'RGB-F210', 'Input shaft nut M45 with lock washer', 'make', 'S43';
 'seal_input',     'RGB-F211', 'Input carbon face seal, 40 x 82 (TBR)', 'buy', 'supplier';
 'acc_cover',      'RGB-A301', 'Accessory cover with the pump and PCU pads', 'make', 'A357';
 'gen_gear',       'RGB-A302', 'Generator gear (one piece with the generator shaft)', 'make', 'P53';
 'gen_shaft',      'RGB-A303', 'Generator shaft with the OSG pinion z 21, m 2', 'make', 'P53';
 'gen_cartridge',  'RGB-A304', 'Generator bearing cartridge and pad (MNT-02)', 'make', 'A357';
 'brg_6305',       'RGB-A305', 'Generator shaft ball bearing 6305 class', 'buy', 'supplier';
 'seal_gen',       'RGB-A306', 'Generator pad carbon face seal, 27 x 60 (TBR)', 'buy', 'supplier';
 'quill_gen',      'RGB-A307', 'Generator pad quill, shear neck 10.5', 'make', 'S43';
 'osg_gear',       'RGB-A308', 'OSG gear z 30, m 2, with its shaft', 'make', 'P53';
 'osg_adapter',    'RGB-A309', 'OSG pad adapter with the outer OSG bearing seat', 'make', 'S43';
 'brg_6202',       'RGB-A310', 'OSG shaft ball bearing 6202 class', 'buy', 'supplier';
 'quill_osg',      'RGB-A311', 'OSG pad quill, shear neck 5', 'make', 'S43';
 'pcu_gear',       'RGB-A312', 'PCU gear z 73, m 1.5, with its shaft', 'make', 'P53';
 'pcu_adapter',    'RGB-A313', 'PCU pad adapter', 'make', 'S43';
 'brg_6203',       'RGB-A314', 'PCU shaft ball bearing 6203 class', 'buy', 'supplier';
 'quill_pcu',      'RGB-A315', 'PCU pad quill, shear neck 5', 'make', 'S43';
 'pump_pack',      'RGB-A316', 'Supply and scavenge pump pack (2.2 kg, TBR)', 'buy', 'supplier';
 'quill_pump',     'RGB-A317', 'Pump pad quill, shear neck 5', 'make', 'S43'};
rows = {};
add = @(pn, part, desc, qty, mb, mat, kg, basis, mod) {pn, part, desc, qty, mb, mat, kg, basis, mod};
for i = 1:size(P, 1)
    p = P{i, 1};
    j = find(strcmp(Mx.parts.part, p));
    if isempty(j)                                        % the planet pins are inside the carrier body
        qty = 4;  kg = 0;  basis = 'in parent';  mod = 'planetary';
    else
        qty = Mx.parts.count(j);  kg = Mx.parts.kg(j);  basis = 'CATIA';
        mod = Mx.items.module{find(strcmp(Mx.items.part, p), 1)};
    end
    rows(end + 1, :) = add(P{i, 2}, p, P{i, 3}, qty, P{i, 4}, P{i, 5}, kg, basis, mod); %#ok<AGROW>
end
% oil hardware weighed in step 3.2 (replaces the 3.1 allowance "oil jets, tubes and manifolds")
rows(end + 1, :) = add('RGB-L401', 'oil_jets', 'Oil jets with last-chance strainers (26 nozzles; 6 more are drilled feeds)', 26, 'make', 'C155', W.jets, 'weighed 3.2', 'lubrication');
rows(end + 1, :) = add('RGB-L402', 'oil_tubes', 'External oil tubes 8 and 6 mm bore, fittings and clamps', 1, 'make', 'C321', W.tubes, 'weighed 3.2', 'lubrication');
rows(end + 1, :) = add('RGB-L403', 'transfer_sleeve', 'Carrier oil transfer sleeve (two grooves: planet oil, PIF-02 pitch oil)', 1, 'make', 'S43', W.sleeve, 'weighed 3.2', 'lubrication');
rows(end + 1, :) = add('RGB-L404', 'pitch_tube', 'Pitch oil tube on the propeller axis (PIF-02)', 1, 'make', 'Ti64', W.pitch_tube, 'weighed 3.2', 'lubrication');
% LUB-07 mist system (Hamit's decision)
mp = W.mist_parts;
rows(end + 1, :) = add('RGB-E501', 'mist_accumulator', 'Mist oil accumulator (0.28 kg oil charge in E505)', 1, 'make', 'Ti64', mp.accumulator, 'weighed 3.2', 'lub07_mist');
rows(end + 1, :) = add('RGB-E502', 'mist_valve', 'Mist shut-off and mixing valve, opened by the low-oil-pressure switch', 1, 'buy', 'supplier', mp.valve, 'weighed 3.2', 'lub07_mist');
rows(end + 1, :) = add('RGB-E503', 'mist_lines', 'Mist lines from the valve to the tie-in', 1, 'make', 'C321', mp.lines, 'weighed 3.2', 'lub07_mist');
rows(end + 1, :) = add('RGB-E504', 'bleed_line', 'Bleed air line from the core port, insulated (TBD)', 1, 'make', 'C321', mp.bleed_line, 'weighed 3.2', 'lub07_mist');
rows(end + 1, :) = add('RGB-E505', 'mist_oil', 'Accumulator oil charge', 1, '-', 'oil', mp.oil, 'weighed 3.2', 'lub07_mist');
% allowances of step 3.1 that stay
for k = 2:numel(ai.allow)
    pn = sprintf('RGB-%s', ifelse(k == 2, 'H701', 'L405'));
    rows(end + 1, :) = add(pn, ifelse(k == 2, 'hums', 'filter_valves'), ai.allow(k).name, 1, 'buy', 'supplier', ...
                           ai.allow(k).m, 'allowance 3.1', ifelse(k == 2, 'hums', 'lubrication')); %#ok<AGROW>
end
if isfield(Mx, 'extra') && Mx.extra > 0                % Hamit's mass card B (step 3.5): bottom-up basis and the extras
    rows(end + 1, :) = add('RGB-S600', 'fasteners', 'Bolts, studs, washers, locking: bottom-up list of step 3.4 x 1.5 (mass card B)', 1, 'buy', 'A286', Mx.bolts, 'allowance 3.1', 'standard');
    rows(end + 1, :) = add('RGB-S640', 'extras_card_B', 'Seat liners, flange dowel pins, thicker NU1024 bosses (mass card B; the liner lines S621-S628 are its detail)', 1, 'make', 'S43', Mx.extra, 'allowance 3.1', 'standard');
else
    rows(end + 1, :) = add('RGB-S600', 'fasteners_allowance', 'Bolts, studs, washers, locking: 5% of the modelled mass (step 3.1 allowance)', 1, 'buy', 'A286', Mx.bolts, 'allowance 3.1', 'standard');
end
% estimates of step 3.4, not in the roll-up
for j = 1:height(F.T)
    mk = 'A286';
    if contains(F.T.joint(j), 'planetary case to first-stage case flange'), mk = 'S129'; end   % 12.9 as in the VDI 2230 run
    rows(end + 1, :) = add(sprintf('RGB-S6%02d', j), 'fastener', char(F.T.joint(j) + " (" + F.T.size(j) + ")"), F.T.n(j), 'buy', mk, ...
                           F.T.kg(j), 'estimate 3.4', 'standard'); %#ok<AGROW>
end
for j = 1:height(Ln.T)
    rows(end + 1, :) = add(sprintf('RGB-S6%02d', 20 + j), 'seat_liner', char("Steel seat liner for " + Ln.T.bearing(j) + " (net of the A357 it replaces)"), ...
                           Ln.T.n(j), 'make', 'S43', Ln.T.kg_added(j), 'estimate 3.4', 'standard'); %#ok<AGROW>
end
rows(end + 1, :) = add('RGB-S650', 'o_rings', 'O-rings, low-temperature fluorocarbon, AS568 sizes (mass negligible)', 1, 'buy', 'supplier', 0, 'estimate 3.4', 'standard');
% outside SYS-06
for k = 1:numel(ai.ext)
    rows(end + 1, :) = add(sprintf('RGB-X8%02d', k), ifelse(k == 1, 'oil_cooler', 'oil_tank'), ai.ext(k).name, 1, 'buy', 'supplier', ...
                           ai.ext(k).m, 'outside SYS-06', 'external'); %#ok<AGROW>
end
% G1b nose parts (3.7): masses estimated (3.9 CAD); the SYS-06 roll-up of 3.7 carries them (sf_qj)
rows(end + 1, :) = add('RGB-P116', 'nose_cover', 'Nose cover with the axial catcher lip, Ti-6Al-4V, 2.9 mm lip disc, bolted to the P111 front face', 1, 'make', 'Ti64', 0.2765, 'estimate 3.7', 'planetary');
rows(end + 1, :) = add('RGB-P117', 'shoulder_ring', 'QJ1024 pull-out shoulder ring, split ring in a P103 groove with a retaining sleeve (CS-E 515)', 1, 'make', 'S43', 0.30, 'estimate 3.7', 'planetary');
rows(end + 1, :) = add('RGB-P118', 'collar', 'P103 collar for the catcher lip, shrink fit, z 512-516', 1, 'make', 'S43', 0.16, 'estimate 3.7', 'planetary');
rows(end + 1, :) = add('RGB-P119', 'qj_retainer', 'QJ1024 outer-ring retainer (-z abutment) at z 446 in P111', 1, 'make', 'Ti64', 0.05, 'estimate 3.7', 'planetary');
rows(end + 1, :) = add('RGB-P120', 'nj_spacer', 'NJ1024 selective end-play spacer and the flanged S621 liner change', 1, 'make', 'S43', 0.07, 'estimate 3.7', 'planetary');
rows(end + 1, :) = add('RGB-S613', 'fastener', 'nose cover P116 to P111 (8 x M5 x 16, inserts, locked)', 8, 'buy', 'A286', 0.04, 'estimate 3.7', 'standard');
rows(end + 1, :) = add('RGB-H704', 'thermocouples', 'NJ1024 outer-ring thermocouples (2) and P116 skirt thermocouple (1) with harness', 1, 'buy', 'supplier', 0.08, 'estimate 3.7', 'monitoring');
% the PT output shaft and the diaphragm couplings: CS-E 515 critical parts of the input drive (SYS-11 roll-up, not SYS-06)
rows(end + 1, :) = add('RGB-F212', 'pt_shaft', 'PT output shaft 66 x 1.5, integral flanges machined from a forged hollow, no welds (CS-E 515)', 1, 'make', 'S43', 1.6, 'outside SYS-06', 'input drive');
rows(end + 1, :) = add('RGB-F213', 'coupling_pt', 'Diaphragm coupling, PT end, 3 x 0.3 mm 15-5PH diaphragms with spacer flange and bolts (CS-E 515)', 1, 'make', 'C155', 1.2, 'outside SYS-06', 'input drive');
rows(end + 1, :) = add('RGB-F214', 'coupling_rgb', 'Diaphragm coupling, RGB end, 3 x 0.3 mm 15-5PH diaphragms with spacer flange and bolts (CS-E 515)', 1, 'make', 'C155', 1.2, 'outside SYS-06', 'input drive');
B.T = cell2table(rows, 'VariableNames', {'part_no', 'part', 'description', 'qty', 'make_buy', 'material', 'kg', 'basis', 'module'});
in_roll = ismember(B.T.basis, {'CATIA', 'weighed 3.2', 'allowance 3.1'});
B.rollup = sum(B.T.kg(in_roll));
if isfield(Mx, 'extra') && Mx.extra > 0
    B.bottom_up = B.rollup;                            % the roll-up already has the bottom-up basis (mass card B)
else
    B.bottom_up = B.rollup - Mx.bolts + F.with_k + Ln.kg;
end
end

function v = ifelse(c, a, b)
if c, v = a; else, v = b; end
end
