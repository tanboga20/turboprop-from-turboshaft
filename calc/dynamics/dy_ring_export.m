function D = dy_ring_export(in, W, pw, file)
%DY_RING_EXPORT  Damping ring and groove data of the first-stage gear for its drawing (step 3.9).
%   D = dy_ring_export(in, W, pw, file)
%
%   in = dy_inputs, W = dy_web output (the chosen ring), pw = the blank
%   (mm; rim = rim thickness under the tooth root, h_t = tooth height). The
%   groove is turned in the bore of the rim overhang, centred at W.ring.z
%   from the gear face z = 0 (in.ring.e from the rim mid-plane); its depth
%   in.ring.d_groove leaves s_R = rim - depth under the root, checked
%   against s_R / h_t >= in.ring.sR_ht_min (the full-rim threshold of
%   ISO 6336-3), so a ring thicker than the groove stands proud of the rim
%   bore towards the web. The split gap is an unbalance (a 1 mm gap of a
%   32 mm^2 ring is about 0.25 g at 0.1 m, 25 g mm, above the G2.5 allowance
%   of the gear), so the ring carries an anti-rotation tab at the split in a
%   slot of the groove land with +-0.2 mm circumferential clearance (far
%   above the um-level vibratory slip, so the damping is unchanged), and the
%   gear is balanced with the ring fitted and its orientation marked
%   (delegated by Hamit). It is turned to a free outside diameter
%   in.ring.oversize above the groove bottom, so it holds itself against
%   the groove bottom at rest, and the centrifugal preload does the rest.
%   Writes file (key = value, mm, kg, N/m).
%   Source: Phase 3 report, Section 3.6 ("Damping ring").

rr = in.ring;
D.groove_d = 2 * pw.r_rim + 2 * rr.d_groove * 1e3;        % groove bottom diameter
D.groove_z = W.ring.z;                                     % groove centre from the gear face z = 0
D.groove_w = W.ring.w + 2 * rr.c_ax * 1e3;
D.rim_beyond = pw.b - D.groove_z - D.groove_w / 2;            % full rim between the groove edge and the face
D.groove_depth = rr.d_groove * 1e3;
D.groove_root_r = rr.r_root * 1e3;                         % both bottom corners
D.groove_Ra = rr.Ra_groove;                                % um; turned before carburizing, ground-free
D.sR = pw.rim - D.groove_depth;                            % rim under the root at the groove
D.sR_ht = D.sR / pw.h_t;
D.sR_ht_ok = double(D.sR_ht >= rr.sR_ht_min);
D.ring_h = W.ring.h;
D.ring_w = W.ring.w;
D.ring_od_free = D.groove_d * (1 + rr.oversize);
D.ring_id = D.groove_d - 2 * W.ring.h;
D.split_gap = rr.gap * 1e3;                               % gap at the split, fitted in the groove
D.anti_rotation = 'tab at the split in a slot of the groove land, +-0.2 mm circumferential clearance';
D.split_unbalance_gmm = rr.rho * W.ring.h * 1e-3 * W.ring.w * 1e-3 * rr.gap * 1e3 * W.ring.R;   % g mm (gap mass x R)
D.balance = 'balance the gear with the ring fitted; mark the ring orientation';
D.proud = W.ring.h - D.groove_depth;                      % radial stand-out from the rim bore
D.mass = W.ring.mass;
D.preload_100 = W.ring.q100;                              % N/m at 100% speed
D.material = rr.material;
f = fopen(file, 'w');
fprintf(f, '# gear2_ring: written by calc/dynamics/dy_ring_export.m (step 3.6), do not edit\n');
fprintf(f, '# groove in the rim bore of the first-stage gear (RGB-F202) and the split damping ring; mm, um, kg, N/m\n');
fprintf(f, '# drawing notes (3.9): groove root radius both corners, no grinding burn on the groove (temper etch), split ends deburred;\n');
fprintf(f, '# anti-rotation tab at the split in a slot of the groove land (+-0.2 mm); balance the gear with the ring fitted, orientation marked\n');
for k = fieldnames(D)'
    v = D.(k{1});
    if ischar(v), fprintf(f, '%s = %s\n', k{1}, v); else, fprintf(f, '%s = %.6g\n', k{1}, v); end
end
fclose(f);
end
