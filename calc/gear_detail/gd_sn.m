function [G, N] = gd_sn(kind, type, G_static, G_ref, ZNT10, N_in, sigma_in)
%GD_SN  Life curve of the permissible stress, ISO 6336-2 and -3:2019 Method B.
%   G = gd_sn(kind, type, G_static, G_ref, ZNT10, N)          stress limit at N cycles
%   [~, N] = gd_sn(kind, type, G_static, G_ref, ZNT10, [], sigma)   cycles to failure at sigma
%
%   kind 'H' (pitting) or 'F' (tooth root); type 'Eh' (case carburized) or
%   'NT' (nitrided). G_static and G_ref are the stress limits with all
%   factors at the static and the reference points [MPa]; ZNT10 is the life
%   factor at 1e10 cycles (0.85 for critical service).
%
%   Knee points (ISO 6336-2 Table 5, ISO 6336-3 life factor table):
%     pitting Eh: static up to 1e5, reference 5e7;  NT: 1e5, 2e6
%     root    Eh and NT: static up to 1e3, reference 3e6
%   Between the knees the limit is log-log linear (the standard's limited
%   life interpolation, which also moves Z_L Z_v Z_R, Y_deltarelT, Y_RrelT,
%   Y_X from their static to their reference values); beyond the reference
%   point it falls to ZNT10 G_ref at 1e10 and keeps that slope.

if kind == 'H'
    Ns = 1e5;
    if strcmp(type, 'Eh'), Nr = 5e7; else, Nr = 2e6; end
else
    Ns = 1e3;
    Nr = 3e6;
end
k1 = log(G_static / G_ref) / log(Nr / Ns);   % slope between the knees (log-log)
k2 = -log(ZNT10) / log(1e10 / Nr);           % slope beyond the reference point
if nargin < 7 || isempty(sigma_in)
    N = N_in;
    G = zeros(size(N));
    for i = 1:numel(N)
        if N(i) <= Ns
            G(i) = G_static;
        elseif N(i) <= Nr
            G(i) = G_ref * (Nr / N(i))^k1;
        else
            G(i) = G_ref * (Nr / N(i))^k2;
        end
    end
else
    G = [];
    N = zeros(size(sigma_in));
    for i = 1:numel(sigma_in)
        s = sigma_in(i);
        if s >= G_static
            N(i) = Ns;                       % at or above the static limit: failure within the static range
        elseif s >= G_ref
            N(i) = Nr / (s / G_ref)^(1 / k1);
        else
            N(i) = Nr * (G_ref / s)^(1 / k2);
        end
    end
end
end
