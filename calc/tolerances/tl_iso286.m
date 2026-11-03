function [lo, hi, IT] = tl_iso286(D, cls)
%TL_ISO286  Limit deviations of a hole or shaft tolerance class by the ISO 286-1 formulae.
%   [lo, hi, IT] = tl_iso286(D, cls)
%   D    nominal size [mm] (3 < D <= 500); cls e.g. 'H6', 'J6', 'K6', 'M6', 'N6', 'P6', 'T6', 'G6' (holes) or
%        'f6', 'g5', 'h5', 'js5', 'k5', 'm5', 'n6', 'p6', 'r6', 's6' (shafts)
%   lo, hi  lower and upper limit deviations [um]; IT the standard tolerance [um]
%
%   The size is the geometric mean of the ISO 286 size step that holds D; the tolerance unit is
%   i = 0.45 D^(1/3) + 0.001 D [um] and IT5 / IT6 / IT7 / IT8 / IT9 = 7 / 10 / 16 / 25 / 40 i. Fundamental
%   deviations of shafts from the ISO 286-1 formulae (f -5.5 D^0.41, g -2.5 D^0.34, h 0, k +0.6 D^(1/3),
%   m IT7 - IT6, n +5 D^0.34, p IT7 + 0 to 5, r the geometric mean of p and s, s IT8 + 1 to 4 up to 50 mm
%   and IT7 + 0.4 D above, t IT7 + 0.63 D); holes by
%   the general rule (EI = -es) and, for K, M, N and P, the special rule ES = -ei + (IT_n - IT_(n-1)). The
%   size-step boundaries above 180 mm (the 200 / 225 / 280 ... intermediate steps of the fundamental
%   deviations) are not split. Values rounded to whole micrometres; ISO 286-2 rounds its tables in steps,
%   so a value here can differ by about 1-2 um from the table (TBR: the drawings take the table values).
%   Source: Phase 3 report, Section 3.8 (E4).

steps = [3 6 10 18 30 50 80 120 180 250 315 400 500];
k = find(D > steps(1:end - 1) & D <= steps(2:end), 1);
assert(~isempty(k), 'tl_iso286: size %g mm outside 3-500 mm', D);
Dm = sqrt(steps(k) * steps(k + 1));
i = 0.45 * Dm^(1/3) + 0.001 * Dm;
mult = [0 0 0 0 7 10 16 25 40];
itf = @(n) mult(n) * i;
letter = regexprep(cls, '\d', '');
n = str2double(regexprep(cls, '\D', ''));
IT = round(itf(n));
hole = any(isstrprop(letter, 'upper'));
L = lower(letter);
pe = itf(7) + 1 + (Dm > 50) + (Dm > 120);               % p: IT7 + 1 / 2 / 3 um (the 0 to 5 um term, TBR)
if Dm <= 50, se = itf(8) + 4; else, se = itf(7) + 0.4 * Dm; end   % s: IT8 + 1 to 4, above 50 mm IT7 + 0.4 D
switch L
    case 'f', es = -5.5 * Dm^0.41;
    case 'g', es = -2.5 * Dm^0.34;
    case 'h', es = 0;
    case 'js', es = NaN;
    case 'k', ei = 0.6 * Dm^(1/3);
    case 'm', ei = itf(7) - itf(6);
    case 'n', ei = 5 * Dm^0.34;
    case 'p', ei = pe;
    case 'r', ei = sqrt(pe * se);
    case 's', ei = se;
    case 't', ei = itf(7) + 0.63 * Dm;
    case 'j', ei = NaN;
    otherwise, error('tl_iso286: class %s not covered', cls);
end
if ~hole
    switch L
        case {'f', 'g', 'h'}, hi = round(es);  lo = hi - IT;
        case 'js', hi = round(IT / 2);  lo = -hi;
        otherwise, lo = round(ei);  hi = lo + IT;
    end
    return
end
switch L
    case {'f', 'g', 'h'}, lo = -round(es);  hi = lo + IT;          % EI = -es
    case 'js', hi = round(IT / 2);  lo = -hi;
    case 'j', hi = round(0.6 * IT);  lo = hi - IT;                   % J: about 60% of IT above zero (TBR)
    otherwise                                                        % K, M, N, P, R, S: special rule
        hi = round(-ei + (itf(n) - itf(n - 1)));  lo = hi - IT;
end
end
