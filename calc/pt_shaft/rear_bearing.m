function rb = rear_bearing(in, F_coupling)
%REAR_BEARING  Loads, life and minimum load of the PT rear roller bearing (LUB-10, STR-02).
%   rb = rear_bearing(in, F_coupling)
%
%   Inputs
%     in           ptshaft_inputs (in.brg, PT rotor mass and balance grade)
%     F_coupling   radial force from the coupling's restoring moment     [N]
%
%   Output struct rb
%     F_1g, F_unb    rotor weight share and unbalance force at 100%     [N]
%     P              equivalent radial load in running (1 g)            [N]
%     P_lim          static load at the limit load factor               [N]
%     L10            basic rating life at 100% speed                    [h]
%     s0             static safety C0 / P_lim                           [-]
%     DN             bore x speed at 110%                               [mm rpm]
%     F_rm           minimum radial load against roller skidding        [N]
%     skid           true if P < F_rm
%
%   Life L10 = (C / P)^(10/3) 1e6 / (60 n) for roller bearings. Minimum
%   load (SKF rolling bearings catalogue, cylindrical roller bearings):
%   F_rm = k_r (6 + 4 n / n_ref) (d_m / 100)^2 kN, d_m in mm. A lightly
%   loaded roller bearing at high speed skids; the usual cure in aero
%   engines is an out-of-round (lobed) outer ring that preloads a few
%   rollers, or a preloaded ball bearing pair.
%
%   Source: Phase 2 report, Section 2.2 ("Rear bearing"). Tested by
%   test_step22 (TC28).

b = in.brg;
w = in.n_PT * pi / 30;
m = in.m_PT * in.rear_share;
rb.F_1g = m * 9.81;
rb.F_unb = m * in.G_PT / w * w^2;
rb.P = rb.F_1g + rb.F_unb + F_coupling;
rb.P_lim = in.n_g_limit * rb.F_1g + rb.F_unb * (in.n_over / in.n_PT)^2 + F_coupling;
rb.L10 = (b.C / rb.P)^(10 / 3) * 1e6 / (60 * in.n_PT);
rb.s0 = b.C0 / rb.P_lim;
rb.DN = b.d * 1e3 * in.n_over;
dm = (b.d + b.D) / 2 * 1e3;
rb.F_rm = b.k_r * (6 + 4 * in.n_PT / b.n_ref) * (dm / 100)^2 * 1e3;
rb.skid = rb.P < rb.F_rm;
end
