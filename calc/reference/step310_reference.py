"""Expected values for the step 3.10 MATLAB tests (calc/tests/step310_test_cases.csv).

    python calc/reference/step310_reference.py        (numpy; use the anaconda python on Hamit's PC)

Re-codes the synthetic accelerometer signal (deterministic: no noise, no load scatter, no roller slip),
the time-synchronous average, the condition indicators and the threshold rule of calc/hums, independently
of the MATLAB code. The design values (tooth numbers, sun speed, planet bearing) are copied below from
steps 2.4, 2.5 and 2.10. Test cases:

TC119  Synthetic signal with a sun tooth crack (a 0.10, phase 0.10 rad) and a planet bore spall (b 1 m/s^2):
       rms, three samples, number of impacts; to 1e-6.
TC120  Indicators of that record: TSA periods, FM4, NA4 (own variance), sideband energy, envelope ENV and
       the defect frequency; to 1e-5.
TC121  Log-normal thresholds of the values 1..20 at false alarm 1e-3 and 1e-6; to 1e-6.

Source: Phase 3 report, Section 3.10 ("Tests").
"""
import csv
import math
import os

import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tests', 'step310_test_cases.csv')

Z1, Z2 = 31, 110                                # first stage (step 2.4)
ZS, ZP, ZR, N = 45, 37, 119, 4                  # planetary stage
N_PT = 22000.0                                  # rpm (SYS-02)
F_SUN = N_PT / 60 * Z1 / Z2                     # Hz, intermediate shaft
# planet bearing (step 2.5): full complement, Dw 7.5 mm, bore = outer race 53 mm, pitch gap 3%
DW, D_OR, GAP = 7.5, 53.0, 0.03
DPW = D_OR - DW
ZB = math.floor(math.pi * DPW / (DW * (1 + GAP)))
F_PLANET = (F_SUN - F_SUN * ZS / (ZS + ZR)) * ZS / ZP          # planet about its pin
K_BORE = ZB * F_PLANET / 2 * (1 - DW / DPW) / F_SUN           # bore defect per sun revolution

FS, NS = 51200, 2 ** 17
SPEED_VAR = (0.003, 0.5)
A_PM, PH_PM = (1.0, 0.4, 0.15), (0.0, 0.7, 1.9)
W_FLOOR = 0.2
A_FS, PH_FS = (0.6, 0.2), (0.0, 1.2)
A_SH, PH_SH = (0.05, 0.08, 0.10), (0.3, 1.1, 2.0)
CRACK = dict(a=0.10, beta=0.10, phi0=0.3, width=0.6)
SPALL = dict(b=1.0, fn=8400.0, zeta=0.03, tmax=0.006)
TSA_PTS, N_SIDE, BAND = 1024, 6, (7400.0, 9400.0)


def window(th_c, i):
    u = (1 + np.cos(th_c + 2 * np.pi * i / N)) / 2
    return W_FLOOR + (1 - W_FLOOR) * u ** 2


def synth():
    t = np.arange(NS) / FS
    w0 = 2 * np.pi * F_SUN
    e, fv = SPEED_VAR
    th_s = w0 * (t + e / (2 * np.pi * fv) * (1 - np.cos(2 * np.pi * fv * t)))
    th_c = th_s * ZS / (ZS + ZR)
    th_r = th_s * ZR / (ZS + ZR)
    th_in = th_s * Z2 / Z1
    x = np.zeros(NS)
    sg = CRACK['width'] * 2 * np.pi / ZS
    for i in range(N):
        w = window(th_c, i)
        d = np.mod(th_r + CRACK['phi0'] - 2 * np.pi * i / N + np.pi, 2 * np.pi) - np.pi
        c = np.exp(-0.5 * (d / sg) ** 2)
        for h in range(3):
            x += w * A_PM[h] * (1 - CRACK['a'] * c) * np.cos(
                (h + 1) * ZS * (th_r - 2 * np.pi * i / N) + PH_PM[h] + (h + 1) * CRACK['beta'] * c)
    for h in range(2):
        x += A_FS[h] * np.cos((h + 1) * Z1 * th_in + PH_FS[h])
    x += A_SH[0] * np.cos(th_in + PH_SH[0]) + A_SH[1] * np.cos(th_s + PH_SH[1]) + A_SH[2] * np.cos(th_c + PH_SH[2])
    ph = K_BORE * th_s / (2 * np.pi)
    k = np.arange(math.ceil(ph[0]), math.floor(ph[-1]) + 1, dtype=float)
    tk = np.interp(k, ph, t)
    thk_c = np.interp(tk, t, th_c)
    thk_r = np.interp(tk, t, th_r)
    spin = -thk_r * ZS / ZP
    amp = SPALL['b'] * window(thk_c, 0) * (1 + np.cos(spin)) / 2
    wn = 2 * np.pi * SPALL['fn']
    wd = wn * math.sqrt(1 - SPALL['zeta'] ** 2)
    m = round(SPALL['tmax'] * FS)
    for j in range(len(tk)):
        i0 = math.ceil(tk[j] * FS)
        idx = np.arange(i0, min(NS - 1, i0 + m) + 1)
        tau = t[idx] - tk[j]
        x[idx] += amp[j] * np.exp(-SPALL['zeta'] * wn * tau) * np.sin(wd * tau)
    return t, x, th_s, len(tk)


def tsa(t, x, tach, period, npts):
    k = np.arange(len(tach), dtype=float)
    sel = (t >= tach[0]) & (t <= tach[-1])
    th = np.interp(t[sel], tach, k)
    nrev = int(math.floor((th[-1] - th[0]) / period))
    g = th[0] + np.arange(nrev * npts) * period / npts
    xr = np.interp(g, th, x[sel])
    return xr.reshape(nrev, npts).mean(axis=0), nrev


def indicators(t, x, th_s):
    k = np.arange(math.ceil(th_s[0] / (2 * np.pi)), math.floor(th_s[-1] / (2 * np.pi)) + 1)
    tach = np.interp(2 * np.pi * k, th_s, t)
    a, nrev = tsa(t, x, tach, (ZS + ZR) / ZR, TSA_PTS)
    m = len(a)
    A = np.fft.fft(a)
    ords = np.arange(m)
    ords[ords > m / 2] -= m
    mesh = [ZS * h for h in range(1, (m // 2 - 1) // ZS + 1)]
    reg = set([1, 2] + mesh + [q - 1 for q in mesh] + [q + 1 for q in mesh])
    res = set([1, 2] + mesh)
    kr = np.array([abs(o) in reg or o == 0 for o in ords])
    ks = np.array([abs(o) in res or o == 0 for o in ords])
    d = np.real(np.fft.ifft(A * ~kr))
    r = np.real(np.fft.ifft(A * ~ks))
    d -= d.mean()
    r -= r.mean()
    fm4 = m * np.sum(d ** 4) / np.sum(d ** 2) ** 2
    na4 = np.mean(r ** 4) / np.mean(r ** 2) ** 2
    amp = np.abs(A) / m
    sb = [ZS - j for j in range(1, N_SIDE + 1)] + [ZS + j for j in range(1, N_SIDE + 1)]
    ser = amp[sb].sum() / math.sqrt(np.mean((a - a.mean()) ** 2))
    n = len(x)
    X = np.fft.fft(x)
    f = np.arange(n) * FS / n
    H = np.where((f >= BAND[0]) & (f <= BAND[1]) & (np.arange(n) < n / 2), 2.0, 0.0)
    env = np.abs(np.fft.ifft(X * H))
    env -= env.mean()
    E = np.abs(np.fft.fft(env)) / n * 2
    nh = n // 2
    fe, E = f[:nh], E[:nh]
    fb = K_BORE / np.mean(np.diff(tach))
    pk = E[(fe >= 0.985 * fb) & (fe <= 1.015 * fb)].max()
    fl = np.median(E[(fe >= 0.5 * fb) & (fe <= 1.5 * fb)])
    return dict(nrev=nrev, FM4=fm4, NA4=na4, SER=ser, ENV=pk / fl, f_bore=fb)


def erfcinv(y):
    lo, hi = 0.0, 10.0
    for _ in range(200):
        mid = (lo + hi) / 2
        if math.erfc(mid) > y:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


def thresholds(x, pfa):
    y = np.log(np.asarray(x, dtype=float))
    mu, sg = y.mean(), y.std(ddof=1)
    return [math.exp(mu + math.sqrt(2) * erfcinv(2 * p) * sg) for p in pfa]


def main():
    rows = []
    t, x, th_s, nimp = synth()
    rows += [('TC119', 'x_rms', math.sqrt(np.mean(x ** 2)), 1e-6), ('TC119', 'x_1000', x[999], 1e-6),
             ('TC119', 'x_50000', x[49999], 1e-6), ('TC119', 'x_100001', x[100000], 1e-6),
             ('TC119', 'n_impacts', nimp, 1e-9)]
    I = indicators(t, x, th_s)
    for q in ('nrev', 'FM4', 'NA4', 'SER', 'ENV', 'f_bore'):
        rows.append(('TC120', q, I[q], 1e-5))
    thr = thresholds(range(1, 21), (1e-3, 1e-6))
    rows += [('TC121', 'thr_caution', thr[0], 1e-6), ('TC121', 'thr_alarm', thr[1], 1e-6)]
    with open(OUT, 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['tc', 'quantity', 'expected', 'tol'])
        for r in rows:
            w.writerow([r[0], r[1], '%.10g' % r[2], r[3]])
    for r in rows:
        print('%-6s %-12s %.8g' % r[:3])


if __name__ == '__main__':
    main()
