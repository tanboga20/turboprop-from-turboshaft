function sh = size_shaft(T, M_alt, F_a, T_lim, M_lim, F_a_lim, d_start, in)
%SIZE_SHAFT  Smallest hollow shaft that meets the fatigue and static criteria.
%   sh = size_shaft(T, M_alt, F_a, T_lim, M_lim, F_a_lim, d_start, in)
%
%   Loads as in shaft_check. Steps the outer diameter up from d_start [mm]
%   in shaft_step steps, with d_i = shaft_bore d_o, and returns the
%   shaft_check output of the first diameter that passes (n_f >= nf_min, no
%   yield at limit load, no failure at 1.5 x limit load). sh is empty if no
%   diameter up to shaft_d_max passes.
%
%   Source: Phase 1 report, Section 3 ("Shafts"). Checked in the full run;
%   shaft_check is tested by TC6.

for d_o = d_start : in.shaft_step : in.shaft_d_max
    sh = shaft_check(d_o, in.shaft_bore * d_o, T, M_alt, F_a, T_lim, M_lim, F_a_lim, in);
    if sh.ok
        return
    end
end
sh = [];
end
