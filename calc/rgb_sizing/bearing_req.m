function br = bearing_req(type, F, n, P0, d, in)
%BEARING_REQ  Required load ratings and DN value of a main bearing.
%   br = bearing_req(type, F, n, P0, d, in)
%
%   Inputs
%     type   'roller' (cylindrical roller bearing, life exponent p = 10/3),
%            'ball' (radial ball bearing, p = 3) or 'QJ' (four-point
%            contact ball bearing, p = 3)
%     F      load spectrum, one row per mission step: [time share, F_r, F_a]
%            [-, N, N]. The time shares add up to 1; a constant load is one
%            row [1, F_r, F_a]. F_a is used only for the QJ.
%     n      shaft speed, constant through the mission               [rpm]
%     P0     static equivalent load at limit load                    [N]
%     d      bore = shaft outer diameter                             [mm]
%     in     rgb_inputs: L10_req, s0_min, overspeed, DN_max
%
%   Output struct br
%     p        life exponent                                         [-]
%     P        equivalent dynamic load of each step                  [N]
%     P_eq     (sum of t_j P_j^p)^(1/p): the constant load that gives the
%              same L10 as the spectrum                              [N]
%     C_req    dynamic load rating for L10 = L10_req at speed n      [N]
%     C0_req   static load rating for s0 = s0_min                    [N]
%     DN       bore x speed at 110% speed                            [mm rpm]
%     DN_ok    DN <= DN_max
%
%   Equivalent load: P = F_r for 'roller' and 'ball'. For the QJ (SKF),
%   P = F_r + 0.66 F_a if F_a/F_r <= 0.95, otherwise P = 0.6 F_r + 1.07 F_a.
%   In the layout the QJ sits with radial clearance in its housing, so
%   F_r = 0 and P = 1.07 F_a.
%
%   Source: Phase 1 report, Section 3 ("Main bearings"). Tested by
%   test_rgb_sizing (TC7).

t = F(:, 1);
F_r = F(:, 2);
F_a = F(:, 3);
switch type
    case 'roller'
        p = 10/3;
        P = F_r;
    case 'ball'
        p = 3;
        P = F_r;
    case 'QJ'
        p = 3;
        P = F_r + 0.66 * F_a;
        high_axial = F_a ./ F_r > 0.95;
        P(high_axial) = 0.6 * F_r(high_axial) + 1.07 * F_a(high_axial);
    otherwise
        error('bearing_req: unknown bearing type ''%s''', type);
end
P_eq = sum(t .* P.^p)^(1 / p);
C_req = P_eq * (in.L10_req * 60 * n / 1e6)^(1 / p);
DN = d * n * in.overspeed;

br = struct('p', p, 'P', P, 'P_eq', P_eq, 'C_req', C_req, 'C0_req', in.s0_min * P0, ...
            'DN', DN, 'DN_ok', DN <= in.DN_max);
end
