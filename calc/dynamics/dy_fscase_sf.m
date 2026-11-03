function [sf, sf_hot] = dy_fscase_sf(Q, in, st)
%DY_FSCASE_SF  Goodman factors of the first-stage case (DYN-03) from its peak vibratory stress, coded and hot.
%   [sf, sf_hot] = dy_fscase_sf(Q, in, st)
%
%   Q = dy_fscase_frf output (sig_pk [MPa]), in = dy_inputs, st = st_inputs
%   (A357-T6 in st.al). Coded: the sand-cast endurance x in.cs.k_gc
%   (2.4e11 cycles) and the room-temperature ultimate, with the casting
%   factor in.k_cast and the steady bound in.fs_sm (the step 3.5
%   first-stage case peak at limit). Hot: the endurance x in.hot.k_T x
%   in.hot.k_fs (the first-stage mesh cycles, 8.2e11) and the hot ultimate
%   in.hot.su. DYN-03 takes the lower of the two. The stress solve does
%   not depend on these inputs, so the factors can be reapplied to a saved
%   Q (run_step36_case, stage 'fs_post').
%   Source: Phase 3 report, Section 3.6 ("First-stage case").

se = in.sigma_e.A357;
sf = 1 / (in.k_cast * (Q.sig_pk / (se * in.cs.k_gc) + in.fs_sm / st.al.su));
sf_hot = 1 / (in.k_cast * (Q.sig_pk / (in.hot.k_T * in.hot.k_fs * se) + in.fs_sm / in.hot.su));
end
