"""Expected values for the step 3.5 MATLAB tests (calc/tests/step35_test_cases.csv).

    python calc/reference/step35_reference.py        (standard library only)

An independent Python implementation of the closed forms of step 3.5 (calc/structures). Inputs are copied from
st_inputs.m; the ring reaction torque at maximum continuous torque (from the step 2.4 gear design) and the step 3.4
fastener and liner masses are copied from their runs. Test cases:

TC85  Loads: LD-05 propeller bearing reactions (2.5 g, 250 mm overhang, 300 mm span, 7,190 N m gyroscopic
      moment) as a moment pair on the two seats, 1 g weight, 1P moment, ring torque at LD-01/02.
TC86  Seat liners (Lame compound cylinder, steel in A357): interference sized for the pressure at 149 degC,
      contact pressure at -40 and 149 degC, von Mises at the A357 bore at -40 degC and its yield safety with the
      casting factor; NU1024 and 6305.
TC87  VDI 2230 Part 1, flange 30 x M6 12.9 on PCD 290 into inserts in A357: preload, torque, resiliences, load
      factor, embedding, thermal preload change, bolt loads, residual clamp load, safety factors, dowel pins.
TC88  The engine mount ring, 12 x M8 and 12 x M10 on PCD 140: bolt load, minimum preload, residual clamp, slip.
TC89  Press fit of the hollow M50NiL planet pin in the carrier plate (Lame): pressure, hoop stress, yield safety.
TC90  Mass closure lines a (fastener basis), b (liners), c (dowels), e (shaft wall) and package A.
TC91  Mass of the finite element models (case and first-stage case A357, carrier 4340) against CATIA.
TC92  NU1024 liner fix: boss radius and its mass for an A357 yield safety of 1.25 at -40 degC (3-D / Lame ratio
      179.18 / 122.82 MPa copied from the case run), and the hold temperature with the present boss.

Source: Phase 3 report, Section 3.5 ("Tests").
"""
import csv
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tests', 'step35_test_cases.csv')

E_AL, NU_AL, CTE_AL, SY_AL = 72e3, 0.33, 21.5e-6, 240.0
E_ST, NU_ST, CTE_ST, SY_ST = 205e3, 0.29, 12.3e-6, 1100.0
K_CAST = 1.25
T_RING_MCT = 3645.4                                    # N m, copied (gear design, ring reaction at MCT), see TC85
T_MCT = 5024.2                                         # N m, copied (propeller torque at MCT)


def vdi(n, d, P, d2, d3, As, pcd, Lk, dw, dh, DA, dwash, Dins, Lins, z_prop, T_flange, F_rad):
    Rp, muG, muK, alphaA, nu, fZ, muT, qF, pG, nload = 1080, 0.12, 0.12, 1.6, 0.9, 0.008, 0.15, 1, 300, 0.5
    d0 = (d2 + d3) / 2
    r = {}
    r['F_Mzul'] = As * nu * Rp / math.sqrt(1 + 3 * (1.5 * d2 / d0 * (P / (math.pi * d2) + 1.155 * muG)) ** 2)
    r['F_Mmin'] = r['F_Mzul'] / alphaA
    r['M_A'] = r['F_Mzul'] * (0.16 * P + 0.58 * d2 * muG + (dw + dh) / 4 * muK) / 1e3
    AN, Ad3 = math.pi / 4 * d ** 2, math.pi / 4 * d3 ** 2
    dS = 0.4 * d / (E_ST * AN) + Lk / (E_ST * Ad3) + 0.5 * d / (E_ST * Ad3) + 0.33 * d / (E_ST * AN)
    tphi = 0.348 + 0.013 * math.log(Lk / dw) + 0.193 * math.log(DA / dw)
    w = 2
    if DA >= dw + w * Lk * tphi:
        dP = 2 * math.log((dw + dh) * (dw + w * Lk * tphi - dh) / ((dw - dh) * (dw + w * Lk * tphi + dh))) / (w * E_AL * math.pi * dh * tphi)
    else:
        dP = (2 / (w * dh * tphi) * math.log((dw + dh) * (DA - dh) / ((dw - dh) * (DA + dh)))
              + 4 / (DA ** 2 - dh ** 2) * (Lk - (DA - dw) / (w * tphi))) / (E_AL * math.pi)
    r['delta_S'], r['delta_P'] = dS, dP
    phin = nload * dP / (dS + dP)
    r['Phi_n'] = phin
    r['F_Z'] = fZ / (dS + dP)
    r['dF_cold'] = (CTE_AL - CTE_ST) * (-60) * Lk / (dS + dP)
    r['dF_hot'] = (CTE_AL - CTE_ST) * 129 * Lk / (dS + dP)
    M = 2.5 * 76.4 * 9.81 * z_prop + 7190
    r['F_A'] = 4 * M / (n * pcd * 1e-3) + 20e3 / n
    r['F_Q'] = 2 * T_flange / (n * pcd * 1e-3) + F_rad / n
    FS = r['F_Mzul'] + phin * r['F_A'] + max(r['dF_cold'], r['dF_hot'], 0)
    MG = r['F_Mzul'] * (0.16 * P + 0.58 * d2 * muG)
    sred = math.sqrt((FS / As) ** 2 + 3 * (0.5 * MG / (math.pi / 16 * d0 ** 3)) ** 2)
    r['S_F'] = Rp / sred
    r['S_D'] = 0.85 * (150 / d + 45) / (phin * 4 * 2000 / (n * pcd * 1e-3) / As)
    r['S_p'] = pG / ((r['F_Mzul'] / 0.9 + phin * r['F_A']) / (math.pi / 4 * (dwash ** 2 - dh ** 2)))
    r['F_KRmin'] = r['F_Mmin'] - r['F_Z'] - max(-min(r['dF_cold'], r['dF_hot']), 0) - (1 - phin) * r['F_A']
    r['S_G'] = max(r['F_KRmin'], 0) * qF * muT / r['F_Q']
    r['S_strip'] = 185 / (FS / (math.pi * Dins * Lins * 0.75))
    return r


def liner_fix():
    """NU1024 liner: boss radius for n = 1.25 (fit held to 149 degC) and hold temperature with the present boss."""
    k3 = 179.1831038550886 / 122.8171857658361
    ri, t, rb0, B, Fr = 90.0, 3.0, 108.0, 32.0, 27.4e3
    rm = ri + t
    preq = max(5.0, Fr / (0.15 * 2 * math.pi * rm * B))
    C = lambda rb: rm / E_AL * ((rb ** 2 + rm ** 2) / (rb ** 2 - rm ** 2) + NU_AL) + rm / E_ST * ((rm ** 2 + ri ** 2) / (rm ** 2 - ri ** 2) - NU_ST)
    dth = lambda T: (CTE_AL - CTE_ST) * (T - 20) * rm
    def vm(p, rb):
        h = (rb ** 2 + rm ** 2) / (rb ** 2 - rm ** 2)
        return p * math.sqrt(h * h + 1 + h)
    pc = lambda rb, Th: (preq * C(rb) + dth(Th) - dth(-40)) / C(rb)
    target = SY_AL / (K_CAST * 1.25 * k3)
    def bisect(f, a, b):
        fa = f(a)
        for _ in range(200):
            m = (a + b) / 2
            if (f(m) > 0) == (fa > 0):
                a, fa = m, f(m)
            else:
                b = m
        return (a + b) / 2
    rb = bisect(lambda x: vm(pc(x, 149), x) - target, rb0 + 0.1, 3 * rb0)
    Th = bisect(lambda T: vm(pc(rb0, T), rb0) - target, -30, 149)
    return {'r_boss': rb, 'dm_kg': math.pi * (rb ** 2 - rb0 ** 2) * (28 + 34) * 2680e-9, 'T_hold': Th,
            'n_now': SY_AL / (K_CAST * k3 * vm(pc(rb0, 149), rb0)), 'dm': math.pi * (rb ** 2 - rb0 ** 2) * (28 + 34) * 2680e-9}


def main():
    rows = []
    add = lambda tc, q, v, tol=1e-3: rows.append((tc, q, float(v), tol))

    # TC85
    W, sp, a = 76.4 * 9.81, 0.3, 0.25
    add('TC85', 'R_in', 2.5 * W * a / sp + 7190 / sp)
    add('TC85', 'R_out', -(2.5 * W * (1 + a / sp) + 7190 / sp))
    add('TC85', 'W1_out', -W * (1 + a / sp))
    add('TC85', 'P1_in', 2000 / sp)
    add('TC85', 'T_ring_lim', 1.375 * T_RING_MCT, 2e-3)

    # TC86: liners [bearing, r_i, t, r_boss, B, F_r]
    for b, ri, t, rb, B, Fr in (('NU1024', 90, 3, 108, 32, 27.4e3), ('6305', 31, 2, 45, 21, 2.0e3)):
        rm = ri + t
        C = rm / E_AL * ((rb ** 2 + rm ** 2) / (rb ** 2 - rm ** 2) + NU_AL) + rm / E_ST * ((rm ** 2 + ri ** 2) / (rm ** 2 - ri ** 2) - NU_ST)
        preq = max(5.0, Fr / (0.15 * 2 * math.pi * rm * B))
        dth = lambda T: (CTE_AL - CTE_ST) * (T - 20) * rm
        d20 = preq * C + dth(149)
        pc, ph = (d20 - dth(-40)) / C, (d20 - dth(149)) / C
        hoop = pc * (rb ** 2 + rm ** 2) / (rb ** 2 - rm ** 2)
        vm = math.sqrt(hoop ** 2 + pc ** 2 + hoop * pc)
        add('TC86', 'd20_' + b, 2 * d20 * 1e3)
        add('TC86', 'p_cold_' + b, pc)
        add('TC86', 'p_hot_' + b, ph)
        add('TC86', 'vm_cold_' + b, vm)
        add('TC86', 'n_cold_' + b, SY_AL / (K_CAST * vm))

    # TC87: flange
    F_rad = abs((2.5 * W * a / sp + 7190 / sp) - (2.5 * W * (1 + a / sp) + 7190 / sp))
    r = vdi(30, 6, 1.0, 5.350, 4.773, 20.1, 290, 12, 10, 6.6, 24, 12, 8.0, 9.0, 0.679, 1.375 * T_RING_MCT, F_rad)
    for k in ('F_Mzul', 'M_A', 'F_Mmin', 'delta_S', 'delta_P', 'Phi_n', 'F_Z', 'dF_cold', 'dF_hot', 'F_A', 'F_Q', 'F_KRmin',
              'S_F', 'S_D', 'S_p', 'S_G', 'S_strip'):
        add('TC87', k, r[k], 2e-3)
    Fd = 1.375 * T_RING_MCT / (6 * 0.145)
    add('TC87', 'F_dowel', Fd, 2e-3)
    add('TC87', 'S_dowel', 0.6 * 1240 / (Fd / (math.pi / 4 * 100)), 2e-3)
    add('TC87', 'S_dowel_bearing', 1.5 * 240 / 1.25 / (Fd / 120), 2e-3)

    # TC88: mount ring
    T_mount = 1.375 * T_MCT * (1 - 1 / 12.93)
    for sz, args in (('M8', (8, 1.25, 7.188, 6.466, 36.6, 140, 12, 13, 9, 22, 16, 10.4, 12)),
                     ('M10', (10, 1.5, 9.026, 8.160, 58.0, 140, 12, 16, 11, 26, 20, 13, 15))):
        d, P, d2, d3, As, pcd, Lk, dw, dh, DA, dwash, Dins, Lins = args
        rm = vdi(12, d, P, d2, d3, As, pcd, Lk, dw, dh, DA, dwash, Dins, Lins, 0.679 + 0.172, T_mount, F_rad)
        add('TC88', 'F_A_' + sz, rm['F_A'], 2e-3)
        add('TC88', 'F_Mmin_' + sz, rm['F_Mmin'], 2e-3)
        add('TC88', 'F_KRmin_' + sz, rm['F_KRmin'], 2e-3)
        if rm['S_G'] > 0:                              # M8 opens: no residual clamp, S_G = 0 (not a ratio test)
            add('TC88', 'S_G_' + sz, rm['S_G'], 2e-3)

    # TC89: pin press fit (hollow M50NiL pin 10..19 mm in a plate ring 19..40 mm, 30 um diametral)
    ap, bp, dp = 0.010, 0.019, 0.040
    delta = 0.030e-3 / 2
    p = delta / (bp / 205e9 * ((dp ** 2 + bp ** 2) / (dp ** 2 - bp ** 2) + 0.29) + bp / 202e9 * ((bp ** 2 + ap ** 2) / (bp ** 2 - ap ** 2) - 0.30))
    hoop = p * (dp ** 2 + bp ** 2) / (dp ** 2 - bp ** 2) / 1e6
    add('TC89', 'p', p / 1e6)
    add('TC89', 'hoop', hoop)
    add('TC89', 'n_y', SY_ST / math.sqrt(hoop ** 2 + (p / 1e6) ** 2 + hoop * p / 1e6))

    # TC90: mass closure (step 3.4: fasteners 1.958 kg with x1.5 against the 5.209 kg allowance; liners 1.281 kg)
    fa, allow, liners = 1.958092, 5.209043302, 1.281249
    add('TC90', 'a', fa - allow, 2e-3)
    add('TC90', 'b', liners, 2e-3)
    c = 6 * math.pi / 4 * 100 * 24 * 7830e-9
    add('TC90', 'c', c)
    add('TC90', 'e', -math.pi / 4 * (104 ** 2 - 100 ** 2) * (535 - 112) * 7830e-9)
    d = 23.103 - 25.007731182                         # CATIA carrier with 10 mm plates less the step 3.1 carrier
    add('TC90', 'd', d)
    f = liner_fix()['dm']
    add('TC90', 'f', f, 2e-3)
    add('TC90', 'pkg_A', 111.0899093 + fa - allow + liners + c + f, 2e-3)
    add('TC90', 'pkg_B', 111.0899093 + fa - allow + liners + c + f + d, 2e-3)

    # TC91: CATIA masses of step 3.1 (meshed volume within 0.5%)
    add('TC91', 'm_case', 10.978753464, 5e-3)
    add('TC91', 'm_carrier', 2933331.9 * 7830e-9, 5e-3)              # CATIA, 10 mm plates (mass card B)
    add('TC91', 'm_fscase', 3347668.2 * 2680e-9, 5e-3)                # CATIA, 16 mm rear wall (mount card A)
    X = liner_fix()
    for k in ('r_boss', 'dm_kg', 'T_hold', 'n_now'):
        add('TC92', k, X[k], 2e-3)

    with open(OUT, 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(['tc', 'quantity', 'expected', 'tol'])
        for tc, q, v, tol in rows:
            w.writerow([tc, q, '%.10g' % v, tol])
    print('%d rows written to %s' % (len(rows), os.path.normpath(OUT)))


if __name__ == '__main__':
    main()
