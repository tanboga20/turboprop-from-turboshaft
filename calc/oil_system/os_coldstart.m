function C = os_coldstart(in, N, li, Qp100, cool)
%OS_COLDSTART  Cold start at -40 degC: oil temperature at which every jet is fed, and the warm-up time.
%   C = os_coldstart(in, N, li, Qp100, cool)
%
%   Solves the network at ground idle speed for oil temperatures from
%   -40 degC up (os_oil viscosity) and finds the lowest temperature T_ok at
%   which every jet passes at least in.Q_ok of its design flow. The
%   warm-up time to T_ok is the heat to raise the oil and in.m_metal_warm
%   of the RGB mass, over the RGB losses at idle in.P_idle plus the pump
%   power (outlet pressure times pump flow), a lumped estimate (TBR with an
%   engine cold soak test, step 3.11). Output C: T [degC] scanned, the
%   lowest jet flow ratio and the manifold pressure at each T, T_ok, the
%   warm-up time t_ok [s], and the -40 degC solution S40.
%   Source: Phase 3 report, Section 3.2 ("Cold start").

op = in.ops(3);
T = [-40 -30 -20 -10 0 10 20 30 40];
r = zeros(size(T));  pm = r;  P_pump = r;
for k = 1:numel(T)
    op.T = T(k);
    S = os_solve(in, N, li, op, os_oil(T(k), li), Qp100, cool);
    r(k) = min(S.jets.Q ./ S.jets.Q_design);
    pm(k) = S.p_m;
    P_pump(k) = S.p_out * S.Q_pump / 60;            % W
    if k == 1, C.S40 = S; end
end
k = find(r >= in.Q_ok, 1);
assert(~isempty(k), 'os_coldstart: the jets are not fed below 40 degC');
if k == 1
    T_ok = T(1);
else
    T_ok = interp1(r(k - 1:k), T(k - 1:k), in.Q_ok);
end
m_oil = in.V_oil_total * li.oil.rho15 / 1000;
m_met = in.m_metal_warm * 107.66;                     % step 3.1 mass (package A)
E = (m_oil * li.oil.cp / 1000 + m_met * in.c_metal) * (T_ok - T(1));    % kJ
P = in.P_idle + mean(P_pump(1:k)) / 1000;             % kW
C = struct('T', T, 'ratio', r, 'p_m', pm, 'P_pump', P_pump, 'T_ok', T_ok, 't_ok', E / P, 'E', E, 'P', P, ...
           'S40', C.S40);
end
