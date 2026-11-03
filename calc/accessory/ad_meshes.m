function A = ad_meshes(in, gi)
%AD_MESHES  The three accessory gear meshes in the form gd_rate takes.
%   A = ad_meshes(in, gi)
%
%   in = ad_inputs, gi = gd_inputs (the step 2.4 gear design). A(1) is the
%   generator mesh (gear 1 the generator gear, gear 2 the first-stage gear),
%   A(2) the OSG pair, A(3) the PCU pair; gear 1 is the smaller gear. Each
%   mesh has the fields of gd_meshes (name, g, mat1, mat2, T1 and n1 at the
%   maximum rated pad torque and 100% speed, Kgam 1, T_corr, cyc1, cyc2,
%   reversed1, reversed2, kv, k_sh, f_ma, C_R, Rz1, Rz2, Rz_root1,
%   Rz_root2, sR1, sR2) and n2 [rpm], the pad torque T_pad [N m] and the
%   blank of the larger gear for the web modes (hub_d, bore).
%
%   K_v by Method B with the reduced masses of solid blanks; K_Hbeta with
%   ISO 6336-1 Formula (59) for a gear midway between its bearings (s = 0).
%   The first-stage gear also carries the generator flank load: the
%   generator mesh rates its root with R = -1.2 (both flanks loaded), the
%   effect on the main mesh is in run_step26.
%   Source: Phase 2 report, Section 2.6 ("Gear pairs"). Tested by
%   test_step26 (TC45).

rho = gi.rho_steel;
mstar = @(dm, q, db) pi / 8 * rho * dm^4 * (1 - q^4) / db^2;   % ISO 6336-1 Formula (25) [kg/mm]
n_mid = gi.n_PT * gi.s1.z1 / gi.s1.z2;

% Generator mesh: z 57 on the first-stage gear
s = gi.s1;  p = in.gen;
g = gd_pair(p.z, s.z2, s.mn, s.beta, p.b, p.x, s.x2, false, gi.hob, gi.hob, p.A, gi);
dm1 = (g.da1 + g.df1) / 2;  dm2 = (g.da2 + g.df2) / 2;
di2 = g.df2 - 2 * gi.gear2_rim * s.mn;
bs_b = min(max(gi.gear2_web / p.b, 0.2), 1.2);
CR = 1 + log(bs_b) / (5 * exp(max(gi.gear2_rim, 1) / 5));
n1 = n_mid * s.z2 / p.z;
A(1) = mesh('generator', g, gi.mat.Eh, gi.mat.Eh, in.T_gen_max, n1, 1, p.z / s.z2, false, true, ...
            [mstar(dm1, p.bore / dm1, g.db1), mstar(dm2, di2 / dm2, g.db2)], p.b / g.d1, g, CR, ...
            p.Rz, gi.Rz_flank, (g.df1 - p.hub_d) / 2, gi.gear2_rim * s.mn, gi);
A(1).n2 = n_mid;  A(1).T_pad = in.T_gen_max;  A(1).hub_d = p.hub_d;  A(1).bore = p.bore;

% OSG and PCU spur pairs
names = {'OSG', 'PCU'};
P = {in.osg, in.pcu};
T = [in.T_osg, in.T_pcu];
n_drive = [n1, n_mid];
for k = 1:2
    p = P{k};
    g = gd_pair(p.z(1), p.z(2), p.m, 0, p.b, p.x(1), p.x(2), false, gi.hob, gi.hob, p.A, gi);
    dm1 = (g.da1 + g.df1) / 2;  dm2 = (g.da2 + g.df2) / 2;
    m = mesh(names{k}, g, gi.mat.Eh, gi.mat.Eh, T(k) * p.z(1) / p.z(2), n_drive(k), 1, p.z(1) / p.z(2), ...
             false, false, [mstar(dm1, p.bore(1) / dm1, g.db1), mstar(dm2, p.bore(2) / dm2, g.db2)], ...
             p.b / g.d1, g, 1, p.Rz, p.Rz, (g.df1 - p.bore(1)) / 2, (g.df2 - p.bore(2)) / 2, gi);
    m.n2 = n_drive(k) * p.z(1) / p.z(2);  m.T_pad = T(k);  m.hub_d = p.hub_d;  m.bore = p.bore(2);
    A(k + 1) = m;
end
end

function m = mesh(name, g, mat1, mat2, T1, n1, cyc1, cyc2, rev1, rev2, mst, b_d1, gg, CR, Rz1, Rz2, sR1, sR2, gi)
k_sh = 0.023 * (abs(1 + 0 - 0.3) + 0.3) * b_d1^2;           % ISO 6336-1 Formula (59), s = 0
f_ma = sqrt(gg.tol1.f_Hb^2 + gg.tol2.f_Hb^2);
m = struct('name', name, 'g', g, 'mat1', mat1, 'mat2', mat2, 'T1', T1, 'n1', n1, 'Kgam', 1, ...
           'T_corr', T1, 'cyc1', cyc1, 'cyc2', cyc2, 'reversed1', rev1, 'reversed2', rev2, ...
           'kv', struct('mode', 'pair', 'mstar', mst), 'k_sh', k_sh, 'f_ma', f_ma, 'C_R', CR, ...
           'Rz1', Rz1, 'Rz2', Rz2, 'Rz_root1', gi.Rz_root, 'Rz_root2', gi.Rz_root, 'sR1', sR1, 'sR2', sR2);
end
