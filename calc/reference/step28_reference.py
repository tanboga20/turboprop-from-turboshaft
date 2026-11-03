"""Expected values for the step 2.8 MATLAB tests (calc/tests/step28_test_cases.csv).

    python calc/reference/step28_reference.py        (needs numpy)

Step 2.8 uses the MATLAB PDE Toolbox finite element solver. These cases check that pipeline (the revolved
geometry, the mesh, materials, boundary conditions and both solvers) against closed-form results, so each
row carries its own tolerance: the exact geometric volume to 0.1%, beam and ring theory to a few percent
(the 3-D solid differs from those theories by its shear, rotary inertia and plane-strain effects). Test cases:

TC52  Volume of the faceted housing solid: Pappus for the section pieces (they touch but do not overlap),
      times the polygon factor N sin(2 pi / N) / (2 pi) of the faceted surface of revolution, and its
      A357 mass.
TC53  Cantilever steel tube, 400 mm long, 40/30 mm: first bending frequency and tip deflection
      under a tip force (Euler-Bernoulli), 3%.
TC54  Free planet ring of step 2.5 (bore 53, root 69, 70 mm wide, tooth layer as mass): first in-plane
      bending mode (n = 2) by Hoppe's ring with the plate modulus E / (1 - nu^2) of a wide ring, 6%.
TC55  Local-stress benchmark: hole of 20 mm in a 100 mm wide, 4 mm thick plate in tension, 3-D with 0.5 mm
      elements on the hole: gross stress concentration factor against Heywood's fit to Howland's plane
      stress solution, Ktn = 2 + (1 - d/W)^3 on the net section, 3% (the 3-D value at the mid-plane is
      expected slightly above plane stress).
TC56  The same plate in 2-D plane stress with 0.25 mm elements on the hole, 1%.

Source: Phase 2 report, Section 2.8 ("Tests").
"""
import csv
import os

import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tests', 'step28_test_cases.csv')

# Case section (calc/housing/hs_inputs.m): pieces that touch but do not overlap, rectangles (r1, r2, z1, z2)
# and polygons [(r, z), ...] in mm
SECTION = [(45, 137.5, 2, 12), (137.5, 153.5, 0, 12), (129.5, 137.5, 0, 2), (129.5, 137.5, 12, 130),
           (86, 90, 130, 132), (90, 137.5, 130, 140), (90, 108, 140, 160),
           [(129.5, 140), (137.5, 140), (108, 412), (100, 412)], (90, 108, 412, 446)]
N_SEG = 120
RHO_AL = 2680.0


def first_moment(piece):
    """Integral of r dA over one piece of the section [mm^3] (polygon formula, any orientation)."""
    if len(piece) == 4 and not isinstance(piece[0], tuple):
        r1, r2, z1, z2 = piece
        piece = [(r1, z1), (r2, z1), (r2, z2), (r1, z2)]
    s = 0.0
    for (ra, za), (rb, zb) in zip(piece, piece[1:] + piece[:1]):
        s += (ra + rb) * (ra * zb - rb * za)
    return abs(s) / 6.0


def main():
    rows = []
    add = lambda tc, q, v, tol: rows.append((tc, q, float(v), tol))
    # TC52
    V = sum(first_moment(p) for p in SECTION) * N_SEG * np.sin(2 * np.pi / N_SEG)
    add('TC52', 'volume_cm3', V / 1e3, 1e-3)
    add('TC52', 'mass_A357_kg', V * 1e-9 * RHO_AL, 1e-3)
    # TC53
    E, rho = 206e9, 7830.0
    do, di, L = 0.040, 0.030, 0.400
    I = np.pi / 64 * (do ** 4 - di ** 4)
    A = np.pi / 4 * (do ** 2 - di ** 2)
    add('TC53', 'f1_Hz', 1.875104 ** 2 / (2 * np.pi) * np.sqrt(E * I / (rho * A * L ** 4)), 0.03)
    add('TC53', 'tip_mm', 1000.0 * L ** 3 / (3 * E * I) * 1e3, 0.03)
    # TC54
    Dor, droot, b, ht = 53.0, 69.0, 70.0, 2.25
    h = (droot - Dor) / 2
    R = (droot + Dor) / 4 / 1000
    Ep = 206e9 / (1 - 0.3 ** 2)
    Ib = b * h ** 3 / 12 * 1e-12
    m = 7830 * b * (h + ht) * 1e-6
    n = 2
    add('TC54', 'ring_n2_Hz', n * (n ** 2 - 1) / np.sqrt(n ** 2 + 1) * np.sqrt(Ep * Ib / (m * R ** 4)) / (2 * np.pi), 0.06)
    # TC55, TC56
    dW = 20.0 / 100.0
    Kt = (2 + (1 - dW) ** 3) / (1 - dW)
    add('TC55', 'Kt_3d', Kt, 0.03)
    add('TC56', 'Kt_2d', Kt, 0.01)
    with open(OUT, 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['tc', 'quantity', 'expected', 'tol'])
        for tc, q, v, tol in rows:
            w.writerow([tc, q, '%.10g' % v, tol])
    for tc, q, v, tol in rows:
        print('%-5s %-16s %.6g  (tol %.3f)' % (tc, q, v, tol))
    print('%d values written to %s' % (len(rows), os.path.normpath(OUT)))


if __name__ == '__main__':
    main()
