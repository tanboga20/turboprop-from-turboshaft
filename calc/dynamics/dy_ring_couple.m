function R = dy_ring_couple(Fp, Hq, TE)
%DY_RING_COUPLE  Planet mesh forces with the ring and case coupled by receptance (used by dy_case_frf).
%   R = dy_ring_couple(Fp, Hq, TE)
%
%   Fp = dy_planet_forces output (D, B, As, Bsr per unit TE, one value per
%   frequency), Hq = the collective ring-seat receptance along the line of
%   action at the same frequencies [m/N], TE [m] the transmission error of
%   both meshes (amplitude). The ring moves away from the planet by
%   q = H F_ring, which lowers the ring-mesh TE: F_ring = (D TE_r + B TE_s) /
%   (1 + D H), and the sun-mesh force As TE_s + Bsr (TE_r - q). The sun-ring
%   phase phi is not known: TE_s = TE e^(i phi), TE_r = TE.
%   Output R: Fc, the envelope of |F_ring| over phi, (|D| + |B|) TE / |1 + D H|
%   (per frequency); Fs_max and Fr_max, the largest |sun-mesh| and
%   |ring-mesh| force over phi (25 points) and frequency [N].
%   Source: Phase 3 report, Section 3.6 ("Planet and case coupling").

R.Fc = TE * (abs(Fp.D) + abs(Fp.B)) ./ abs(1 + Fp.D .* Hq);
R.Fs_max = 0;  R.Fr_max = 0;
for phi = linspace(0, 2 * pi, 25)
    Fr = TE * (Fp.D + Fp.B * exp(1i * phi)) ./ (1 + Fp.D .* Hq);
    Fs = TE * (Fp.As * exp(1i * phi) + Fp.Bsr) - Fp.Bsr .* Hq .* Fr;
    R.Fs_max = max(R.Fs_max, max(abs(Fs)));  R.Fr_max = max(R.Fr_max, max(abs(Fr)));
end
end
