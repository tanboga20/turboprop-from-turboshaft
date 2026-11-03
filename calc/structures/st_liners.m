function Ln = st_liners(in)
%ST_LINERS  Shrink fit of the steel bearing seat liners in the A357 castings from -40 to 149 degC (step 3.5).
%   Ln = st_liners(in)
%
%   in = st_inputs. Each liner of in.liner is a steel ring r_i..r_m (r_m =
%   r_i + t) shrunk into an A357 boss r_m..r_boss (Lame compound cylinder,
%   plane stress, the bearing outer ring inside not counted: TBR). The
%   radial interference falls as the aluminium grows faster than the steel:
%   d(T) = d20 - (cte_A357 - cte_steel) (T - 20) r_m. The fit is sized so
%   that at 149 degC (LD-02 oil) the contact pressure is still the larger of
%   in.p_min and the pressure whose friction holds the largest radial
%   bearing load, F_r / (mu 2 pi r_m B); d20 follows, and the pressure is
%   largest at -40 degC. Checks: A357 hoop and von Mises stress at the bore
%   at -40 degC with the casting factor (yield sy / (1.25 sig_vm)), at 149
%   degC against the over-aged yield sy_hot, and the steel liner hoop
%   stress. Output Ln: table Ln.T per liner: r_m, p_req [MPa], d20 [um,
%   diametral], p at each in.T_fit [MPa], sig_vm_cold [MPa], n_cold,
%   sig_vm_hot, n_hot, sig_liner [MPa]; Ln.p_seat_cold (NU1024, MPa) for
%   the 3-D case model.
%   Source: Phase 3 report, Section 3.5 ("Seat liners").

al = in.al;  st = in.st;
n = numel(in.liner);
rows = zeros(n, 8 + numel(in.T_fit));
for k = 1:n
    l = in.liner(k);
    ri = l.r_i;  rm = l.r_i + l.t;  rb = l.r_boss;
    C = rm / (al.E / 1e6) * ((rb^2 + rm^2) / (rb^2 - rm^2) + al.nu) + ...
        rm / (st.E / 1e6) * ((rm^2 + ri^2) / (rm^2 - ri^2) - st.nu);   % radial interference per MPa [mm/MPa]
    p_req = max(in.p_min, l.F_r / (in.mu_fit * 2 * pi * rm * l.B));
    dth = @(T) (al.cte - st.cte) * (T - 20) * rm;    % radial loss [mm]
    d20 = p_req * C + dth(max(in.T_fit));
    p = (d20 - dth(in.T_fit)) / C;
    pc = p(1);  ph = p(end);
    hoop = @(pp) pp * (rb^2 + rm^2) / (rb^2 - rm^2);
    vm = @(pp) sqrt(hoop(pp)^2 + pp^2 + hoop(pp) * pp);     % hoop and radial (-p) at the bore
    sl = pc * 2 * rm^2 / (rm^2 - ri^2);              % liner hoop compression at its bore [MPa]
    rows(k, :) = [rm, p_req, 2 * d20 * 1e3, p, vm(pc), al.sy / (in.k_cast * vm(pc)), vm(ph), al.sy_hot / (in.k_cast * vm(ph)), sl];
end
names = [{'r_m_mm', 'p_req_MPa', 'd20_um'}, compose('p_%gC_MPa', in.T_fit), {'sig_vm_cold', 'n_cold', 'sig_vm_hot', 'n_hot', 'sig_liner'}];
names = matlab.lang.makeValidName(names);
Ln.T = [table(string({in.liner.brg}'), 'VariableNames', {'bearing'}), array2table(rows, 'VariableNames', names)];
Ln.p_seat_cold = rows(1, 4);                         % NU1024, both propeller roller seats
end
