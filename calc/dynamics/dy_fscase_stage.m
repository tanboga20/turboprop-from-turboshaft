function S = dy_fscase_stage(S, in, Ld, band1)
%DY_FSCASE_STAGE  Step 3.6 first-stage case stage: coarse 3-D modes and forced response (dy_fscase_frf).
%   S = dy_fscase_stage(S, in, Ld, band1)
%
%   Called by run_step36 and run_step36_case. in = dy_inputs, Ld = the
%   first-stage mesh loads (with the working pitch radii rw), band1 = the
%   first-stage 1x band [Hz]. Adds S.fscase.
%   Source: Phase 3 report, Section 3.6 ("First-stage case").

Qf = dy_fscase_frf(in, st_inputs(), Ld, band1, in.fs_Hmax);
fprintf(['\n== First-stage case (3-D, Hmax %g m, %d nodes): %d modes up to %.0f Hz, %d in the 1x band; peak %.2f MPa at %.0f Hz, ' ...
         'Goodman %.2f\n   reaction check (pinion bosses alone): applied %s N, bolt faces %s N\n'], in.fs_Hmax, Qf.n_nodes, ...
        numel(Qf.f), max(Qf.f), Qf.n_band, Qf.sig_pk, Qf.f_pk, Qf.sf, mat2str(round(Qf.check.applied', 1)), ...
        mat2str(round(Qf.check.reaction', 1)));
S.fscase = Qf;
end
