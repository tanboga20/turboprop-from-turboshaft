function Ln = mf_liners(in)
%MF_LINERS  Steel bearing seat liners in the A357 castings: mass not yet in the roll-up, and fit change (step 3.4).
%   Ln = mf_liners(in)
%
%   in = mf_inputs. Each liner of in.liner: a steel sleeve of wall t and
%   length B + in.liner_extra_B around a bearing of outer diameter D. The
%   CATIA castings are solid there, so the roll-up counts the liner volume
%   as A357; the missing mass is (rho_steel - rho_A357) x volume. The
%   shrink fit of the liner in the casting changes with temperature by
%   (cte_A357 - cte_steel) x (T - 20 degC) x liner outer diameter (free
%   expansion, diametral; positive = the fit loosens). The fit itself and
%   the hoop stresses at -40 degC are step 3.5 (3-D model).
%   Output Ln: table Ln.T (bearing, count, D_out, volume [cm3], kg added),
%   Ln.kg (sum), Ln.dfit (rows: liners, columns: in.T_fit) [mm].
%   Source: Phase 3 report, Section 3.4 ("Bill of materials").

st = in.mat(strcmp({in.mat.key}, 'S43'));
al = in.mat(strcmp({in.mat.key}, 'A357'));
D = [in.liner.D]';  t = [in.liner.t]';  n = [in.liner.n]';
Do = D + 2 * t;
V = pi / 4 * (Do.^2 - D.^2) .* ([in.liner.B]' + in.liner_extra_B);
kg = n .* V * (st.rho - al.rho) * 1e-9;
Ln.T = table(string({in.liner.brg}'), n, Do, V / 1e3, kg, ...
             'VariableNames', {'bearing', 'n', 'D_out_mm', 'volume_cm3', 'kg_added'});
Ln.kg = sum(kg);
Ln.dfit = (al.cte - st.cte) * Do * (in.T_fit - 20);
end
