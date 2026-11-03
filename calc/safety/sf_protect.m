function P = sf_protect(in)
%SF_PROTECT  Shaft-break and load-loss protection coverage (SAF-03, CTL-02): which signal detects each break, trip time.
%   P = sf_protect(in)   in = sf_inputs; calc/torsion, calc/rgb_sizing and calc/agb_lube on the path
%
%   Speed signals (in.prot): the protection Np from the core's own PT-rotor wheel, upstream of the PT-end coupling
%   (ICD-36, core maker); the control Np on the input pinion (C-05), also a cross-check; the Nr wheel on P103
%   between the carrier and the front NU1024 bearing. Logic: (a) a mismatch of 3% between the protection Np and
%   the propeller-equivalent Nr; (b) an absolute Np trip for a load loss with the gear train intact (a break
%   outboard of the Nr wheel, a blade loss); (c) signal validation: a lost or implausible signal raises an alarm and
%   inhibits the comparison, and a trip needs a confirming cue (PT acceleration above the governing limit, or a
%   torque collapse). For each break location of the drive chain the inertia left on the PT side (rigid rotation
%   of the step 2.3 torsional model, the propeller excluded) runs up from the MCT torque (shaft_break, step 1.4):
%   the time to a closed fuel valve and the peak PT speed. Breaks between the gear 2 and the PCU / pump stub do not
%   unload the PT: they lose the PCU and the pumps at power (uncommanded feather and oil loss).
%   P.T: coverage table; P.abs: the absolute-trip case; P.t_above: time the PT stays above 100% after a break.
%   Source: Phase 3 report, Section 3.7 (D1b, G2).

pr = in.prot;
in23 = torsion_inputs();  g = gear_data(in23.design);  M = torsion_model(in23, g);
J = diag(M.M);  r = M.ratio;
Jr = @(names) sum(J(ismember(M.names, names)) .* r(ismember(M.names, names)).^2);
up = {'PT', 'coupling 1', 'coupling 2', 'pinion', 'gear 2', 'accessory gear', 'generator', 'sun', ...
      'planet 1', 'planet 2', 'planet 3', 'planet 4', 'carrier'};
in14 = lube_inputs();
delay = in14.t_proc + in14.t_valve;
b = pr.breaks;
n = numel(b);
rows = cell(n, 12);
for k = 1:n
    nm = up(1:b(k).n_up);
    if b(k).n_up == 1, nm = {'PT'}; end
    Ju = Jr(nm) + b(k).J_add;
    switch b(k).logic
        case 'mismatch'
            x = in14;  x.mismatch = pr.mismatch;  x.t_end = pr.t_end;
            s = shaft_break(Ju, pr.Q0, pr.n0, delay, in14.tau_cut, x);
            sig_en = 'protection Np (core PT wheel) against Nr: 3% mismatch; pinion Np cross-check';
            sig_tr = 'koruma Np (çekirdek PT tekerleği) ile Nr: %3 fark; pinyon Np çapraz kontrol';
        case 'absolute'
            x = in14;  x.mismatch = pr.abs_trip - 1;  x.t_end = pr.t_end;
            s = shaft_break(Ju, pr.Q0, pr.n0, delay, in14.tau_cut, x);
            sig_en = sprintf('absolute protection Np trip at %.0f%% with the PT-acceleration or torque-collapse cue (Nr rises with Np)', 100 * pr.abs_trip);
            sig_tr = sprintf('mutlak koruma Np kesmesi %%%.0f, PT ivmesi veya tork çöküşü teyidiyle (Nr Np ile yükselir)', 100 * pr.abs_trip);
        otherwise
            s = struct('t_det', NaN, 'peak', NaN, 't', NaN, 'n', NaN);
            sig_en = 'no PT overspeed (load path intact): pitch-oil and oil pressure, uncommanded feather';
            sig_tr = 'PT aşırı devri yok (yük yolu sağlam): hatve yağı ve yağ basıncı, istenmeyen tüyleme';
    end
    t_trip = s.t_det + delay;
    rows(k, :) = {string(b(k).fm), string(b(k).en), string(b(k).tr), string(b(k).zone), Ju, string(b(k).logic), ...
                  string(sig_en), string(sig_tr), 1e3 * s.t_det, 1e3 * t_trip, 100 * s.peak, b(k).n_up};
end
P.T = cell2table(rows(:, 1:11), 'VariableNames', {'fmea', 'break_en', 'break_tr', 'between', 'J_PT_side_kgm2', ...
    'logic', 'signal_en', 'signal_tr', 't_detect_ms', 't_valve_closed_ms', 'peak_pct'});
% the absolute-trip case at the largest PT-side inertia, and the time above 100% after a downstream break
x = in14;  x.mismatch = pr.abs_trip - 1;  x.t_end = pr.t_end;
P.abs = shaft_break(Jr(up), pr.Q0, pr.n0, delay, in14.tau_cut, x);
x.mismatch = pr.mismatch;
s1 = shaft_break(Jr({'PT'}), pr.Q0, pr.n0, delay, in14.tau_cut, x);
s2 = shaft_break(Jr(up), pr.Q0, pr.n0, delay, in14.tau_cut, x);
P.t_above = [s1.t(find(s1.n > pr.n0, 1, 'last')), s2.t(find(s2.n > pr.n0, 1, 'last'))];
P.J_range = [Jr({'PT'}), Jr(up)];
end
