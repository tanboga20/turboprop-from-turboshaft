function Mc = st_mass(in, Mx, S34, Cr, X)
%ST_MASS  SYS-06 mass closure options for Hamit's card (step 3.5); the roll-up basis is not changed.
%   Mc = st_mass(in, Mx, S34, Cr, X)
%
%   in = st_inputs, Mx = the step 3.2 roll-up (step32.mat S.mass), S34 =
%   step34.mat S (bottom-up fasteners x1.5, seat liners), Cr = st_carrier3d,
%   X = st_liner_fix (thicker NU1024 bosses).
%   Lines:
%     a  fastener basis: the step 3.1 allowance (5% of the modelled mass)
%        replaced by the step 3.4 bottom-up list x 1.5;
%     b  the steel seat liners of step 3.4 (not in the CATIA bodies);
%     c  the flange dowel pins of step 3.5 (in.dowel, steel, 24 mm long);
%     d  carrier plates thinned from 15 to 10 mm: the CATIA mass of the
%        rebuilt carrier (in.carr.m_10, a copy built with plate_t 10) less
%        the step 3.1 carrier; its 3-D check is the option B rerun;
%     f  the thicker NU1024 bosses of the liner fix (st_liner_fix);
%     e  propeller shaft wall 120/100 -> 120/104 mm from the front plate to
%        the flange (a decided item: needs the DYN-05 rerun of step 2.1).
%   Packages: A = a + b + c + f (bookkeeping and the liner fix), B = A + d,
%   C = A + d + e. Output Mc: table Mc.lines (line, kg change), Mc.pkg
%   (package, total kg, margin to 110 kg TBR, to 100 kg).
%   The lines and packages are the record of Hamit's mass card: they use the
%   roll-up the card was based on (in.card, step 3.2), not Mx.total, which
%   has package B applied since the decision.
%   Source: Phase 3 report, Section 3.5 ("Mass closure").

F = S34.fasteners;  Ln = S34.liners;
a = F.with_k - in.allow_share * in.card.modelled;   % against the 5% share of the card's roll-up
b = Ln.kg;
dw = in.dowel;
c = dw.n * pi / 4 * dw.d^2 * 24 * in.st.rho * 1e-9;
t0 = 15;  t1 = 10;
d = in.carr.m_10 - in.card.carrier;
f = X.dm_kg;
Lsh = 535 - 112;                                     % mm, shaft section of the carrier body
e = -pi / 4 * (104^2 - 100^2) * Lsh * in.st.rho * 1e-9;
Mc.t_plate = t1;
Mc.lines = table({'a fastener basis: bottom-up x1.5 instead of 5%'; 'b steel seat liners'; 'c flange dowel pins'; ...
                  sprintf('d carrier plates %g -> %g mm (CATIA)', t0, t1); 'e propeller shaft wall 120/100 -> 120/104 (DYN-05 rerun)'; ...
                  'f NU1024 bosses for the liner fit'}, [a; b; c; d; e; f], 'VariableNames', {'line', 'kg'});
A = a + b + c + f;
tot = in.card.total + [A; A + d; A + d + e];
Mc.pkg = table({'A: bookkeeping and liner fix (a + b + c + f)'; 'B: A + carrier plates (d)'; 'C: B + shaft wall (e)'}, tot, ...
               110 - tot, 100 - tot, 'VariableNames', {'package', 'total_kg', 'margin_110', 'margin_100'});
Mc.roll_up = in.card.total;
Mc.roll_up_now = Mx.total;                           % after Hamit's decision (package B applied)
end
