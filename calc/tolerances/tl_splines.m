function P = tl_splines(in, Th)
%TL_SPLINES  Spline fits and their clearance at temperature (E5, ISO 4156-1, 30 deg, flat root).
%   P = tl_splines(in, Th)   in = tl_inputs, Th = tl_thermal(in)
%
%   For each spline: pitch diameter D = m z, basic space width E = pi m / 2;
%   the total tolerance (T + lambda) of the class (class 5: 10 i* + 40 i**,
%   class 6: 16 i* + 64 i**, with i* = 0.45 D^(1/3) + 0.001 D and
%   i** = 0.45 E^(1/3) + 0.001 E [um]; TBR against ISO 4156-1) on the
%   internal space width and on the external tooth thickness; the
%   fundamental deviation es_v of the external spline (ISO 286 values on D:
%   f negative, h zero, k positive as the k lower deviation); the effective
%   circular clearance [min max] = [-es_v, 2 (T + lambda) - es_v] (negative:
%   interference). At temperature the hub and shaft grow by D alpha dT; a
%   diametral difference dD changes the circular clearance by dD tan(30 deg).
%   P.T: one row per spline and state.
%   Source: Phase 3 report, Section 3.8 (E5).

st = in.th.states;
rows = {};
for k = 1:numel(in.spl)
    sp = in.spl(k);
    D = sp.m * sp.z;  E = pi * sp.m / 2;
    i1 = 0.45 * D^(1/3) + 0.001 * D;  i2 = 0.45 * E^(1/3) + 0.001 * E;
    mult = [0 0 0 6.3 10 16 25];  mult2 = [0 0 0 25 40 64 100];
    Tl = mult(sp.cls) * i1 + mult2(sp.cls) * i2;               % (T + lambda) [um]
    shaft = sp.fit(3);
    switch shaft
        case 'f', [~, es] = tl_iso286(max(D, 3.01), 'f6');
        case 'h', es = 0;
        case 'k', [es, ~] = tl_iso286(max(D, 3.01), 'k5');       % lower deviation of k
    end
    c20 = [-es, 2 * Tl - es];                                    % circular clearance at 20 degC [um]
    for s = 1:numel(st)
        T = Th.map(st{s}, :);
        dD = D * in.cte.P53 * ((T.(sp.T_hub) - in.T_ref) - (T.(sp.T_shaft) - in.T_ref));   % mm
        dc = 1000 * dD * tand(30);
        rows(end + 1, :) = {string(sp.name), sp.m, sp.z, D, string(sprintf('%s, class %d', sp.fit, sp.cls)), Tl, es, ...
                            string(st{s}), c20(1) + dc, c20(2) + dc}; %#ok<AGROW>
    end
end
P.T = cell2table(rows, 'VariableNames', {'spline', 'm', 'z', 'D_mm', 'fit', 'T_lambda_um', 'es_v_um', 'state', ...
                                       'clear_min_um', 'clear_max_um'});
end
