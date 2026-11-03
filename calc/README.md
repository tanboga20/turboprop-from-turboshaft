# calc

**EN.** MATLAB design calculations. Each tool is tested against expected values from the independent Python reference, so the tests show that the two implementations agree. Each script states its inputs, units and sources in its header. Step 1.3 sizes the reduction gearbox (`calc/rgb_sizing/`); step 1.4 adds the accessory drives, the gearbox losses and heat balance, the oil system and the shaft-break overspeed (`calc/agb_lube/`). Phase 2 (detail design) adds one folder per step, starting with the propeller shaft rotordynamics of step 2.1 (`calc/rotor_damper/`), the power turbine output shaft of step 2.2 (`calc/pt_shaft/`), the torsional model of step 2.3 (`calc/torsion/`), the gear detail rating of step 2.4 (`calc/gear_detail/`), the bearings, shafts and splines of step 2.5 (`calc/shafts_bearings/`), the accessory drives of step 2.6 (`calc/accessory/`), the lubrication system of step 2.7 (`calc/lubrication/`), the housing and planet finite element models of step 2.8 (`calc/housing/`), the CATIA parameter export of step 2.9 (`calc/cad_export/`) and the condition monitoring frequencies and sensor positions of step 2.10 (`calc/hums/`). Phase 3 starts with the complete model of step 3.1 (`calc/assembly/`) and the oil system of step 3.2 (`calc/oil_system/`). From Phase 2 on, the independent Python references that write the expected test values are kept in the repository too (`calc/reference/`, `rotordynamics/`).

Step 1.3, preliminary sizing of the reduction gearbox: the calculation basis (inputs, assumptions, formulas, tool structure and test cases) is Section 3 of the Phase 1 report. The tool scans every valid tooth-count set of layout O (an offset helical first stage, then a planetary stage with a floating sun, a fixed ring and carrier output), sizes the gears with a simplified ISO 6336, checks the shafts, bearings and critical speeds, and reports the lightest valid design for 3, 4 and 5 planets. Suggested files, each doing one job, in `calc/rgb_sizing/`:

| File | Task | Test |
| --- | --- | --- |
| `rgb_inputs.m` | All inputs and assumptions in one struct; no numbers inside the other functions | — |
| `gear_geometry.m` | Pair geometry: d, d_b, d_a, a, ε_α, ε_β, β_b (external and internal pair) | TC1–TC3 |
| `iso6336_lite.m` | Forces, pitch-line velocity, σ_H, σ_F, S_H, S_F; static option | TC1–TC3, TC5 |
| `tooth_set_check.m` | Rules for one tooth-count set: ratio, assembly, planet tip gap, hunting teeth | TC4a, TC4b |
| `tooth_sets.m` | Valid tooth-count sets | TC4c |
| `size_stage1.m` | First-stage module loop | Full run |
| `planet_stage.m` | Planetary stage at one module: both meshes and the planet bearing | TC5 |
| `size_stage2.m` | Planetary stage module loop, carrier post gap | Full run |
| `planet_bearing.m` | Planet bearing C, C0, centrifugal load, mission life, s0 | TC5 |
| `shaft_check.m` | Shaft stresses and safeties | TC6 |
| `size_shaft.m` | Smallest outer diameter d_o | Full run |
| `bearing_req.m` | P_eq, C_req, C0_req, DN | TC7 |
| `critical_speed.m` | The two critical speed models | TC8 |
| `rgb_mass.m` | Mass of each part from its main dimensions | TC9 |
| `rgb_layout.m` | One design: shafts, main bearings, critical speeds, mass breakdown | Full run |
| `run_rgb_sizing.m` | Runs everything; writes the tables, the plot and the test report to `calc/results/step13/` (not committed) | — |
| `test_rgb_sizing.m` | Compares results with `tests/step13_test_cases.csv` | All |

`tests/step13_test_cases.csv` holds the expected values of TC1–TC9: 109 rows with the columns `tc`, `quantity`, `expected` and `unit`. Values have up to six significant figures. A test passes when the relative difference is at most 0.1%; counts (unit `count`, the roller count `Z` and `assembly_ok`) must match exactly. In the `unit` column, `-` means dimensionless and `modules` is the planet tip gap divided by the module. In quantity names, `1` and `2` are gear 1 (the smaller gear of the pair) and gear 2, `_sp` the sun–planet mesh, `_pr` the planet–ring mesh, `_ring` the ring gear and `_static` the LD-01 check at 1.375 × torque. The inputs of each test case are in the report (Section 3, Test cases); the expected values are also in its "1.3 Testler / Tests" tab. Reading a value in MATLAB:

```matlab
T = readtable('calc/tests/step13_test_cases.csv', 'TextType', 'string');
ref = T.expected(T.tc == "TC1" & T.quantity == "S_H");
assert(abs(S_H / ref - 1) <= 1e-3)
```

The comparison of the MATLAB full run with the independent Python reference goes into Section 3 of the Phase 1 report.

Step 1.4, accessory drives, losses, oil system and shaft break: the calculation basis is Section 4 of the Phase 1 report. The tool builds the RGB chosen after the PDR (31/110 | 45/37/119, 4 planets; `in14.design` in `lube_inputs.m`) with the step 1.3 functions, so `calc/rgb_sizing/` must be on the path too. In `calc/agb_lube/`:

| File | Task | Test |
| --- | --- | --- |
| `lube_inputs.m` | All step 1.4 inputs and assumptions: oil, pad torques, loss model factors, operating points, oil system, shaft break | — |
| `oil_props.m` | Viscosity (Walther line through 40 and 100 °C, ASTM D341), density and dynamic viscosity of the oil | TC10 |
| `mesh_loss.m` | Mesh power loss: Schlenk friction coefficient with the Ohlendorf loss factor H_V (ISO/TR 14179-2 approach), external and internal pairs | TC11, TC12 |
| `windage_loss.m` | Gear windage, NASA TM-83716 formula | TC13 |
| `bearing_loss.m` | Bearing friction, Palmgren M0 + M1 | TC13 |
| `pad_mesh.m` | Smallest face width of an accessory pair that passes the three checks: rated torque, 1.5 × torque in fatigue, static at the shear-neck torque | TC14 |
| `accessory_pads.m` | Generator, overspeed governor (OSG), propeller control unit (PCU) and oil pump drives: speeds, gears, shear necks, mass | TC14 |
| `rgb_losses.m` | Every loss of the RGB at one operating point, followed from the propeller back to the power turbine; L_mech (SYS-05) and heat into the oil (LUB-04) | TC17 |
| `lube_sizing.m` | Oil flow, pumps, tank volume, air–oil cooler and oil jets | TC15 |
| `shaft_break.m` | Power turbine overspeed after the drive chain breaks (SAF-03), RK4 | TC16 |
| `run_step14.m` | Runs everything (oil system by a fixed point on pump power, four operating points, loss sensitivity, a shaft-break map); writes `summary.txt`, `losses.csv`, `shaft_break.csv`, two plots and the test report to `calc/results/step14/` (not committed) | — |
| `test_step14.m` | Compares results with `tests/step14_test_cases.csv` | All |

`tests/step14_test_cases.csv` holds the expected values of TC10–TC17: 78 rows in the same format and with the same 0.1% rule as step 1.3. Run from the repo root:

```matlab
addpath('calc/rgb_sizing', 'calc/agb_lube');
test_step14              % 78 values, 0 failures
R = run_step14();        % full run
```

Step 2.1, propeller shaft rotordynamics and DYN-05: the calculation basis is Section 2.1 of the Phase 2 report. The tool is a gyroscopic finite element model of the propeller shaft (Timoshenko beam elements, the carrier and the propeller as discs, each bearing as a chain of rolling bearing, journal, centring spring with squeeze film, and housing). It screens four concepts for the backward whirl of DYN-05 over a range of housing stiffness and finds that a thin-walled 120/100 mm shaft meets DYN-05 without a damper if the housing seats give at least 5e7 N/m in every direction. `calc/rgb_sizing/` (rgb_inputs, shaft_check) and `calc/agb_lube/` (oil_props) must be on the path. In `calc/rotor_damper/`:

| File | Task | Test |
| --- | --- | --- |
| `damper_inputs.m` | All step 2.1 inputs and assumptions: rotor, supports, housing range, damper limits, concepts screened | — |
| `beam_timoshenko.m` | Matrices of a hollow Timoshenko beam element in one plane (stiffness, translational and rotary mass, polar matrix for the gyroscopic terms) | TC18 |
| `support.m` | One support of the rotor model, direct to ground or as a bearing-journal-damper-housing chain | — |
| `rotor_model.m` | Global M, C, G, K of the shaft with carrier, propeller, optional flange and supports | TC19–TC21 |
| `rotor_campbell.m` | Damped natural frequencies, damping ratios and whirl directions over speed; 1 x crossings | TC19, TC21 |
| `rotor_unbalance.m` | Unbalance response: orbit major semi-axis at every node, journal orbit, bearing forces, steady and alternating shaft stress | TC20, TC21 |
| `sfd_coeffs.m` | Damping of a short squeeze-film land, circular centred orbits | TC22 |
| `squirrel_cage.m` | Stiffness and bar stress of a squirrel-cage centring spring | TC23 |
| `run_step21.m` | Validation against Phase 1, concepts, damper offset, housing stiffness map, final shaft; writes `summary.txt`, four CSV files, three plots in English and Turkish and the test report to `calc/results/step21/` (not committed) | — |
| `test_step21.m` | Compares results with `tests/step21_test_cases.csv` | All |

`tests/step21_test_cases.csv` holds the expected values of TC18–TC23: 27 rows in the same format and with the same 0.1% rule as steps 1.3 and 1.4. They come from ROSS and from closed forms, written by `rotordynamics/step21_reference.py`, so the tests show that the MATLAB rotor model and ROSS agree. Run from the repo root:

```matlab
addpath('calc/rotor_damper', 'calc/rgb_sizing', 'calc/agb_lube');
test_step21              % 27 values, 0 failures
S = run_step21();        % full run, about 6 minutes
run_step21([], 'plots'); % redraws the plots from calc/results/step21/step21.mat
```

Step 2.2, power turbine output shaft: the calculation basis is Section 2.2 of the Phase 2 report. In installation C a floating shaft with a diaphragm coupling at each end runs from the power turbine through a tunnel in the exhaust collector to the RGB. The tool sizes the diaphragm packs and the shaft, checks the phase-shift torque meter, the power turbine rear bearing and the tunnel temperatures. `calc/rotor_damper/` (beam_timoshenko) must be on the path. In `calc/pt_shaft/`:

| File | Task | Test |
| --- | --- | --- |
| `ptshaft_inputs.m` | All step 2.2 inputs and assumptions: torques, misalignment, materials, grids, torque meter, rear bearing, tunnel | — |
| `tube_shaft.m` | Floating shaft: shear stress, twist, buckling, Goodman fatigue, first bending critical speed (Timoshenko elements with end masses and springs) | TC24 |
| `annular_plate.m` | Flat diaphragm clamped at both edges: axial and angular stiffness, stress per unit offset and per unit tilt (closed-form plate solutions) | TC25 |
| `diaphragm.m` | One diaphragm pack: stresses, stiffness, loads on the shafts, fatigue, static, burst and buckling safeties | TC26 |
| `torque_meter.m` | Twist, resolution and temperature error of the phase-shift torque meter (CTL-01) | TC27 |
| `rear_bearing.m` | Power turbine rear bearing: loads, L10, static safety, minimum load against skidding | TC28 |
| `tunnel_thermal.m` | Temperatures along the shaft tunnel: insulation, buffer air, windage | TC29 |
| `run_step22.m` | Sizes the couplings and the shaft, length sensitivity, torque meter, rear bearing, tunnel and rear sump; writes `summary.txt`, two CSV files, two plots in English and Turkish and the test report to `calc/results/step22/` (not committed) | — |
| `test_step22.m` | Compares results with `tests/step22_test_cases.csv` | All |

`tests/step22_test_cases.csv` holds the expected values of TC24–TC29: 29 rows, same format and 0.1% rule. They come from an independent Python implementation, `calc/reference/step22_reference.py` (numpy and scipy, for example with `rotordynamics/.venv`), which solves the diaphragm plate problems with scipy's boundary value solver instead of the closed form. Run from the repo root:

```matlab
addpath('calc/pt_shaft', 'calc/rotor_damper');
test_step22              % 29 values, 0 failures
S = run_step22();        % full run, about 20 seconds
```

Step 2.3, torsional vibration and sudden stoppage: the calculation basis is Section 2.3 of the Phase 2 report. A torsional model of the whole chain (power turbine, floating shaft and couplings, input pinion, first-stage gear with the generator branch, sun, four planets, carrier, propeller shaft, propeller) gives the natural frequencies, checks them against the DYN-02 orders and the power turbine orders, and computes the propeller shaft torque when the power turbine seizes (LD-08). It sets the torsional stiffness floor of the step 2.2 floating shaft (`kt_min` in `ptshaft_inputs.m`). `calc/rgb_sizing/` must be on the path. In `calc/torsion/`:

| File | Task | Test |
| --- | --- | --- |
| `torsion_inputs.m` | All step 2.3 inputs and assumptions: orders, mesh stiffness, inertias, shafts, generator branch, stopping times | — |
| `gear_data.m` | Radii, face widths, masses and inertias of the design from the step 1.3 tool | — |
| `torsion_model.m` | Inertia and stiffness matrices with physical rotations; shafts, gear meshes along the line of action, purely torsional planetary stage; rigid speed ratios | TC30, TC31 |
| `torsion_modes.m` | Natural frequencies, strain energy share of each element, DYN-02 margin check | TC30 |
| `sudden_stop.m` | Peak torques when the power turbine stops in a given time: modal superposition with the exact pulse response | TC32 |
| `run_step23.m` | Modes and DYN-02, floating shaft study, sensitivity, sudden stoppage map; writes `summary.txt`, two CSV files, two plots in English and Turkish and the test report to `calc/results/step23/` (not committed) | — |
| `test_step23.m` | Compares results with `tests/step23_test_cases.csv` | All |

`tests/step23_test_cases.csv` holds the expected values of TC30–TC32: 12 rows, same format and 0.1% rule, from `calc/reference/step23_reference.py`, an independent Python model with its own eigensolution and a direct time integration (scipy Radau) of the sudden stoppage. Run from the repo root:

```matlab
addpath('calc/torsion', 'calc/rgb_sizing');
test_step23              % 12 values, 0 failures
S = run_step23();        % full run
```

Step 2.4, detail rating of the gears: the calculation basis is Section 2.4 of the Phase 2 report. It rates the three meshes of the PDR design by ISO 6336:2019 Methods B and C: tooth form and stress correction factors of Method B (hob for the external gears, shaper cutter for the ring), the dynamic factor of Method B (planetary stage by 6.5.8.4), the face load factor of Method C with the elastic misalignments of the pinion, the sun and the carrier, the transverse load factor, the planet load sharing factor from a Monte Carlo model with a floating sun, static and limited-life checks (LD-01, LD-02, LD-08), the mission spectrum (Palmgren-Miner), scuffing by the flash temperature method with the film thickness, the gear rim and web modes against the mesh frequencies (DYN-04) and the SYS-07 idler variant. Step 2.5 later widened the planetary stage to 70 mm and thickened the planet rim to 8 mm and the carrier posts to 60 mm (planet bearing life); `gd_inputs.m` holds the current design. Self-contained; in `calc/gear_detail/`:

| File | Task | Test |
| --- | --- | --- |
| `gd_inputs.m` | All step 2.4 inputs and assumptions: design, tools, accuracy, materials, roughness, carrier, tolerances for load sharing, oils | — |
| `gd_tolerances.m` | Flank tolerances by the ISO 1328-1:2013 formulae | — |
| `gd_root.m` | Method B tooth root values: s_Fn, rho_F, h_Fe, Y_F, Y_S (ISO 6336-3 Formulae (9) to (64)) | TC33 |
| `gd_pair.m` | Pair geometry with profile shift, path of contact, start of active profile, specific sliding, Z_H, Z_eps, Z_B, Z_D | TC34 |
| `gd_meshes.m` | The three meshes with their torques, speeds, reduced masses and elastic misalignment coefficients | TC35 |
| `gd_rate.m` | Stiffness, K_v, K_Hbeta, K_Halpha, pitting and root stresses, life factors, safety factors | TC35, TC36 |
| `gd_sn.m` | Life curve of the permissible stress (static, reference, long life) and its inverse | TC36 |
| `gd_loadshare.m` | Planet load sharing factor with a floating sun: Monte Carlo over the tolerances, or one given error set | TC37 |
| `gd_scuffing.m` | Load sharing along the path, Hertz stress, flash and contact temperature, scuffing safety, film thickness ratio | TC38 |
| `gd_modes.m` | Free thin ring modes and gear web modes with the rim (annular plate, Hermite elements) | TC39 |
| `run_step24.m` | Helix correction scan, design options, ratings, over-torque, LD-08 capacity, mission life, flank modifications, scuffing cases, DYN-04, idler variant; writes `summary.txt`, two CSV files, five plots in English and Turkish to `calc/results/step24/` (not committed) | — |
| `test_step24.m` | Compares results with `tests/step24_test_cases.csv` | All |

`tests/step24_test_cases.csv` holds the expected values of TC33–TC39: 96 rows, same format and 0.1% rule, from `calc/reference/step24_reference.py`. That reference finds the root values by simulating the generating cut (the hob rack and the shaper cutter) instead of the closed forms of the standard, solves the load sharing with the planet degrees of freedom instead of the series load path, and computes the web modes by a Rayleigh-Ritz model and, for the bare web, the exact Bessel-function solution. Run from the repo root:

```matlab
addpath('calc/gear_detail');
test_step24              % 96 values, 0 failures
S = run_step24();        % full run, about 20 seconds
```

Step 2.5, bearings, shafts, splines and propeller retention: the calculation basis is Section 2.5 of the Phase 2 report. It rates the main bearings (cylindrical roller bearings and radially free four-point contact ball bearings on the input, intermediate and propeller shafts) and the planet bearing (one row, full complement, the planet bore as the outer race) by the ISO 281 forms derived in ISO/TR 1281-1:2021, with the modified rating life over the mission and the static safety at the limit loads and in the sudden stoppage. It also checks the smallest shaft sections (Goodman, yield at limit load, rupture at ultimate load), the sun quill splines (Dudley), the propeller retention options of SAF-01 and the planet modes of DYN-04 in three models. It uses the gear design of `calc/gear_detail/` (on the path); in `calc/shafts_bearings/`:

| File | Task | Test |
| --- | --- | --- |
| `sb_inputs.m` | All step 2.5 inputs and assumptions: requirements, propeller loads, layout, bearings, planet bearing, oil, shaft material, splines, retention | — |
| `sb_rating.m` | C, C0 and C_u of roller and ball bearings (ISO/TR 1281-1 forms; ball C0 from the Hertz contact at 4,200 MPa) | TC40 |
| `sb_life.m` | Equivalent load, viscosity ratio, a_ISO and L10m over the mission (roller, four-point contact and, from step 2.6, deep groove ball bearings) | TC41, TC47 |
| `sb_shaft.m` | Goodman, yield and rupture of a hollow shaft section | TC42 |
| `sb_spline.m` | Tooth shear, flank pressure and root torsion of an involute spline | TC43 |
| `sb_planet_rim.m` | Planet rim modes: free ring, on the loaded rollers, with the mesh springs | TC44 |
| `run_step25.m` | Gear forces and K_gamma, bearing loads, ratings and lives, DYN-04 planet modes, shafts, splines, retention, planetary stage mass; writes `summary.txt`, `bearings.csv` and three plots in English and Turkish to `calc/results/step25/` (not committed) | — |
| `test_step25.m` | Compares results with `tests/step25_test_cases.csv` | All |

`tests/step25_test_cases.csv` holds the expected values of TC40–TC44: 64 rows, same format and 0.1% rule, from `calc/reference/step25_reference.py`. Every case gives the functions fixed inputs, so the cases do not depend on the gear model. The reference also prints two checks that are not test values: the free ring against the Hoppe closed form (0.7% apart) and the ball C0 with exact elliptic integrals (1.5% below the Hamrock-Brewe value used). Run from the repo root:

```matlab
addpath('calc/shafts_bearings', 'calc/gear_detail');
test_step25              % 64 values, 0 failures
S = run_step25();        % full run, about 10 seconds
```

Step 2.6, accessory drives: the calculation basis is Section 2.6 of the Phase 2 report. It rates the power-turbine-driven pads of ACC-02 (AC generator on the first-stage gear, overspeed governor, propeller control unit, oil pump): the three accessory gear pairs by ISO 6336 Methods B and C with the step 2.4 tools in three load cases (STR-01, 1.5 times the torque of ACC-03, static at the shear torque), the shear necks of ACC-03, the accessory shaft bearings with the step 2.5 tools, the web modes of the gear blanks against the mesh frequencies (DYN-04), the first-stage gear root with the generator on its other flank and the pad interface table. It needs `calc/gear_detail/` and `calc/shafts_bearings/` on the path; in `calc/accessory/`:

| File | Task | Test |
| --- | --- | --- |
| `ad_inputs.m` | All step 2.6 inputs and assumptions: pad torques, gear pairs and blanks, neck material and scatter, bearings, generator mass | — |
| `ad_meshes.m` | The three accessory meshes in the form `gd_rate` takes | TC45 |
| `ad_neck.m` | Shear neck: diameter, shear torque band, fatigue at 1.5 times the torque | TC46 |
| `run_step26.m` | Necks, gear ratings, first-stage gear root, bearings, blank modes, pad table, overhung moment, blank masses; writes `summary.txt`, `pads.csv` and two plots in English and Turkish to `calc/results/step26/` (not committed) | — |
| `test_step26.m` | Compares results with `tests/step26_test_cases.csv` | All |

`tests/step26_test_cases.csv` holds the expected values of TC45–TC48: 43 rows, same format and 0.1% rule, from `calc/reference/step26_reference.py`, which builds on the step 2.4 and 2.5 Python references (TC47 checks the deep groove ball bearings added to `sb_life.m`). Run from the repo root:

```matlab
addpath('calc/accessory', 'calc/gear_detail', 'calc/shafts_bearings');
test_step26              % 43 values, 0 failures
S = run_step26();        % full run, about 10 seconds
```

Step 2.7, lubrication system: the calculation basis is Section 2.7 of the Phase 2 report. It runs the step 1.4 loss model (`calc/agb_lube/`) on the detailed design of steps 2.4 to 2.6 to get the heat balance at four operating points (SYS-05, LUB-04), sizes the oil flow and the jets of every component by a fixed point with the pump power, the supply and scavenge pumps (with the PT rear sump of LUB-10), and the air-oil cooler of LUB-04 and LUB-09 with offset strip fins (effectiveness-NTU, Manglik and Bergles), and checks the tank, windmilling and the MIL-PRF-7808 limit. It needs `calc/agb_lube/`, `calc/gear_detail/`, `calc/shafts_bearings/` and `calc/accessory/` on the path; in `calc/lubrication/`:

| File | Task | Test |
| --- | --- | --- |
| `lb_inputs.m` | All step 2.7 inputs and assumptions: oil, operating points, loss factors, jets, pumps, cooler, tank | — |
| `lb_design.m` | The step 2.4 to 2.6 design in the form `lb_losses` takes | TC49 |
| `lb_losses.m` | Losses by item and the heat into the oil at one operating point | TC49 |
| `lb_flows.m` | Oil flow and jets of each component from its heat | TC50 |
| `lb_cooler.m` | Cross-flow plate-fin cooler: UA, core size, pressure drops, mass, fan power | TC51 |
| `run_step27.m` | Fixed point at maximum continuous power, operating points, pumps, cooler scan, decision 5 options, tank, windmilling; writes `summary.txt`, `jets.csv` and two plots in English and Turkish to `calc/results/step27/` (not committed) | — |
| `test_step27.m` | Compares results with `tests/step27_test_cases.csv` | All |

`tests/step27_test_cases.csv` holds the expected values of TC49–TC51: 55 rows, same format and 0.1% rule, from `calc/reference/step27_reference.py`, which takes the gear geometry from the step 2.4 and 2.6 Python references and re-codes the loss formulas, the jet schedule and the cooler model. Run from the repo root:

```matlab
addpath('calc/lubrication', 'calc/agb_lube', 'calc/gear_detail', 'calc/shafts_bearings', 'calc/accessory');
test_step27              % 55 values, 0 failures
S = run_step27();        % full run, about 10 seconds
```

Step 2.8, housing and planet finite element models: the calculation basis is Section 2.8 of the Phase 2 report. The tool is MATLAB's PDE Toolbox (linear elastic statics and modes with quadratic tetrahedra). The RGB case is revolved from its section (flange, planetary case around the ring gear, front wall, conical nose with the two propeller bearing seats) and checked for the bearing seat stiffness of DYN-05, its modes against the planetary mesh bands (DYN-04) and its stress at the LD-05 limit load; the planet is modelled in 3-D on its loaded rollers and with its two meshes, and the first-stage gear blank in 3-D for the web check step 2.4 handed on (DYN-04). A verification run shows how far the results can be trusted: a stress concentration benchmark (hole in a plate), the mesh convergence of the case, the flange support between rigid and bolted-joint springs, and submodels of the most loaded corners with their cast fillets, where the peak stress converges (a sharp corner of the global model does not). The first section (flat front wall, cylindrical nose) failed the seat stiffness floor and, with its fillets, the limit stress, which led to the conical nose. It needs `calc/gear_detail/` and `calc/shafts_bearings/` on the path; in `calc/housing/`:

| File | Task | Test |
| --- | --- | --- |
| `hs_inputs.m` | All step 2.8 inputs and assumptions: case section, materials, flange joint, limit loads, meshes, verification settings | — |
| `hs_poly.m` | Section region from rectangles and polygons | TC52 |
| `hs_revolve.m` | Closed STL surface of the revolved section | TC52 |
| `hs_housing.m` | Case: mass, seat stiffness, modes, limit-load stress; fixed or spring-supported flange | TC52 |
| `hs_planet3d.m` | Planet in 3-D: free, on its loaded rollers, with its two meshes | TC54 |
| `hs_gear_web.m` | First-stage gear blank in 3-D: out-of-plane web modes and their nodal diameters (the DYN-04 check step 2.4 handed on) | — |
| `hs_bench_hole.m` | Local-stress benchmark: hole in a tension plate | TC55 |
| `hs_section.m` | Section outline with cast fillets, clipped to a submodel window | — |
| `hs_sector.m` | Section revolved over a sector on the global facets, with caps | — |
| `hs_submodel.m` | Filleted submodel of one corner, driven by the global displacements | — |
| `hs_plot3d.m` | Colour map of a field on the deformed mesh | — |
| `hs_plot_sections.m` | The first and the final case sections side by side | — |
| `run_step28.m` | Both case materials, the three planet models and the first-stage gear web; writes `summary.txt`, the mode chart and the 3-D pictures (stress, seat deflection, mode shapes) in English and Turkish to `calc/results/step28/` (not committed) | — |
| `run_step28v.m` | Verification: benchmark, mesh convergence, flange bracketing, filleted submodels, the first section; writes `summary_verify.txt` and its plots | — |
| `test_step28.m` | Compares results with `tests/step28_test_cases.csv` | All |

`tests/step28_test_cases.csv` holds the expected values of TC52–TC56, one tolerance per row: the exact volume of the faceted case (Pappus over the section pieces) to 0.1%, a cantilever tube against Euler-Bernoulli and the free planet ring against Hoppe's ring to a few percent, and the hole in a plate against Heywood's fit to Howland's solution (3% in 3-D, 1% in 2-D), from `calc/reference/step28_reference.py`. Run from the repo root:

```matlab
addpath('calc/housing', 'calc/gear_detail', 'calc/shafts_bearings');
test_step28              % 7 values, 0 failures
S = run_step28();        % full run, about 25 minutes (run_step28([], 'quick') checks the script in 3)
V = run_step28v();       % verification after run_step28, about 20 minutes
```

Step 2.9, CATIA models: `calc/cad_export/cx_export.m` writes the design values the CATIA scripts read (`cad/params/*.txt`: gear data, bores, rims, the carrier, the case profile with its fillet arcs and flange holes), so that the models follow the calculations. The VBScript part, assembly and drawing scripts are in `cad/scripts/` (see `cad/README.md`). Run from the repo root:

```matlab
addpath('calc/gear_detail', 'calc/shafts_bearings', 'calc/accessory', 'calc/housing', 'calc/cad_export');
cx_export();             % cad/params/*.txt
```

Step 2.10, condition monitoring (Hamit's decision 7 = C, maintenance-driven design): the calculation basis is Section 2.10 of the Phase 2 report. It gives the characteristic frequencies that a health and usage monitoring system (HUMS) looks for in the RGB vibration: the speed of every shaft, the mesh frequencies, the local gear fault frequencies of the planetary stage and the cage, race and rolling element frequencies of the eleven bearings, at 100% speed and over the steady speed range of SYS-03. It lists the lines of different components that lie within 2% of each other (a spectrum cannot tell them apart, so they need time-synchronous averaging), and ranks accelerometer positions on the step 2.8 case by the static transfer compliance from the propeller bearing seats and the ring gear seat to the case surface (CTL-03). It needs `calc/housing/`, `calc/gear_detail/`, `calc/shafts_bearings/` and `calc/accessory/` on the path; in `calc/hums/`:

| File | Task | Test |
| --- | --- | --- |
| `hm_frequencies.m` | Shaft, mesh, local gear fault and bearing frequencies at a given speed | TC57–TC59 |
| `hm_sensors.m` | Static transfer compliance from each source to the outer surface of the case (PDE Toolbox) | — |
| `run_step210.m` | Frequency table at 90, 100 and 101% speed, close pairs, accelerometer positions; writes `summary.txt`, `fault_frequencies.csv` and two plots in English and Turkish to `calc/results/step210/` (not committed) | — |
| `test_step210.m` | Compares results with `tests/step210_test_cases.csv` | All |

`tests/step210_test_cases.csv` holds the expected values of TC57–TC59: 59 rows, same format and 0.1% rule, from `calc/reference/step210_reference.py`, which re-codes the kinematics and the bearing formulas from the design data (standard library only). Run from the repo root:

```matlab
addpath('calc/hums', 'calc/housing', 'calc/gear_detail', 'calc/shafts_bearings', 'calc/accessory');
test_step210             % 59 values, 0 failures
R = run_step210();       % full run, about 2 minutes
```

Step 3.1, complete model (Phase 3): the basis is Section 3.1 of the Phase 3 report. The tool lays out the parts Phase 2 left out and writes them for CATIA through `cx_export`: the first-stage case round the offset gear pair, the intermediate shaft and the sun quill, the accessory drives (generator gear-shaft in a cartridge, OSG gear on the propeller-side face, PCU gear and pump pack in a cover on the engine side) at angles chosen against packaging rules, bearing, nut and seal envelopes, the titanium nose housing of the propeller four-point contact bearing, the retention tube and a placeholder propeller flange (PIF-01 TBD), and the instance list of the three-module assembly. It checks the lightened carrier plate in plane stress and rolls the CATIA volumes up into the SYS-06 mass. It needs `calc/gear_detail/`, `calc/shafts_bearings/` and `calc/accessory/` on the path; in `calc/assembly/`:

| File | Task | Test |
| --- | --- | --- |
| `as_inputs.m` | All step 3.1 inputs and assumptions (TBD interface values marked) | — |
| `as_geom.m` | Gear tips, centre distances, bearing envelopes and outline radii from the Phase 2 designs | — |
| `as_hull.m` | Convex hull of circles as tangent lines and arcs (case outlines) | TC60 |
| `as_angles.m` | Generator, OSG and PCU angles: packaging margins, lightest case and cover | TC62 |
| `as_layout.m` | Axial stations, part profiles, case pads and pockets, gear phases, instances | TC61, TC63 |
| `as_carrier.m` | Carrier front plate, plain or lightened, plane stress; annulus benchmark | TC64 |
| `as_mass.m` | Mass roll-up from `cad/assy/part_volumes.csv` against SYS-06, and the input drive (PT output shaft, couplings, tunnel) against SYS-11 | TC65, TC66 |
| `as_lighten.m` | Further mass options (WE43 castings, titanium propeller shaft section) | — |
| `as_export.m` | `cad/params` files of the new parts and of the assembly (called by `cx_export`) | — |
| `run_step31.m` | Stations, angles and margins, carrier check, clash summary, mass table; three plots in English and Turkish to `calc/results/step31/` (not committed) | — |
| `test_step31.m` | Compares results with `tests/step31_test_cases.csv` | All |

`tests/step31_test_cases.csv` holds the expected values of TC60–TC66: 74 rows with a tolerance each, from `calc/reference/step31_reference.py` (numpy, scipy), which re-codes the geometry and the roll-up and checks the CATIA volumes against the exported profiles. Build the CATIA parts first (`cad/README.md`), then from the repo root:

```matlab
addpath('calc/assembly', 'calc/gear_detail', 'calc/shafts_bearings', 'calc/accessory');
test_step31              % 78 values, 0 failures
S = run_step31();        % about 1 minute
```

Step 3.2, oil system hardware and hydraulic network: the basis is Section 3.2 of the Phase 3 report. The tool routes the oil system on the step 3.1 layout (manifold with the regulating and thermostatic valves and the filter, external tubes round the cases, drillings to 32 jets, the two-groove carrier transfer sleeve that also carries the pitch oil of PIF-02), solves the network at maximum continuous power, ground idle and a -40 degC start, checks the pump inlet at 45,000 ft and at -1.27 g, the run without oil (LUB-07) with the emergency air-oil mist system of Hamit's decision, weighs the oil hardware and the mist system for SYS-06, and writes all of it for CATIA. It needs `calc/assembly/`, `calc/lubrication/`, `calc/agb_lube/`, `calc/gear_detail/`, `calc/shafts_bearings/` and `calc/accessory/` on the path, and the CATIA volumes of step 3.1; in `calc/oil_system/`:

| File | Task | Test |
| --- | --- | --- |
| `os_inputs.m` | All step 3.2 inputs and assumptions (TBD interface values marked) | — |
| `os_oil.m` | Oil properties from -40 to 150 degC | TC69 |
| `os_network.m` | Routes, entries, drillings and jets on the step 3.1 geometry | TC67 |
| `os_solve.m` | Pressures and flows at one operating point (pipes, jets with Cd(Re), strainers, valves, carrier rise) | TC67, TC68 |
| `os_coldstart.m` | Temperature from which the jets are fed after a -40 degC start, warm-up time | TC69 |
| `os_inlet.m` | Pump inlet at altitude, at negative g and cold; negative-g endurance | TC70 |
| `os_lub07.m`, `os_mist.m` | Run without oil: drip reservoirs and the emergency air-oil mist (heat balance, system mass) | TC71, TC72 |
| `os_lubmass.m` | Mass of the weighed oil hardware and of the mist system for SYS-06 | TC73 |
| `os_export.m` | `cad/params/oil_*.txt` for the CATIA scripts and the network for the reference | — |
| `os_schematic.m`, `run_step32.m` | Schematic and the full run; plots in English and Turkish to `calc/results/step32/` (not committed) | — |
| `test_step32.m` | Compares results with `tests/step32_test_cases.csv` | All |

`tests/step32_test_cases.csv` holds the expected values of TC67–TC73: 81 rows with a tolerance each, from `calc/reference/step32_reference.py` (numpy, scipy), which re-solves the network read from `cad/params/oil_network.txt`. From the repo root:

```matlab
addpath('calc/oil_system', 'calc/assembly', 'calc/lubrication', 'calc/agb_lube', 'calc/gear_detail', 'calc/shafts_bearings', 'calc/accessory');
S = run_step32();        % about 2 minutes
test_step32              % 81 values, 0 failures
```

Step 3.3, interfaces: the basis is Section 3.3 of the Phase 3 report. The interface control document is `requirements/icd_v1.csv` (written by `requirements/make_icd.py`); `calc/interfaces/` gives its sensitivity column numbers. `if_override.m` lets the input functions of steps 2.2, 2.5, 2.6, 2.7, 3.1 and 3.2 take a temporary override (they end with a guarded call to it, so nothing changes when `calc/interfaces` is not on the path); `if_sens.m` moves each interface value and reruns the tool that uses it, or applies the closed form where the relation is direct; `run_step33.m` writes `requirements/icd_sensitivity_v1.csv` and the margin plots; `test_step33.m` checks the 44 closed-form values against `calc/reference/step33_reference.py` (`tests/step33_test_cases.csv`). From the repo root:

```matlab
addpath('calc/interfaces', 'calc/shafts_bearings', 'calc/gear_detail', 'calc/accessory', 'calc/pt_shaft', 'calc/rotor_damper', ...
        'calc/oil_system', 'calc/assembly', 'calc/lubrication', 'calc/agb_lube');
T = run_step33();        % about 3 minutes
test_step33              % 44 values, 0 failures (TC79 after run_oilgrade)
```

`run_oilgrade.m` is the oil grade check behind Hamit's decision (MIL-PRF-23699 only, replacing step 2.4 Decision 2A; logged in `requirements/changes_phase3.csv`): S_S, film ratio and the ISO 281 mission life of every bearing for both oils at 60, 100 and 132 °C oil inlet (step 2.4 and 2.5 tools, the latter through the `if_override` hook), and the RGB oil inlet on hot and cold days with the step 2.7 cooler core and the 60 °C thermostatic valve. It writes `calc/interfaces/oil_grade_check.csv` (about 2 minutes, run after `run_step32`).

Step 3.4, materials, processes and the bill of materials: the basis is Section 3.4 of the Phase 3 report. The text tables (materials, processes, routes, components) are in `manufacturing/` (`manufacturing/make_mfg.py`); `calc/manufacturing/` gives their numbers.

| File | Purpose | Test cases |
| --- | --- | --- |
| `mf_inputs.m` | Materials (specification, density, CTE, temperature limit), case depth bands, fastener joints, seat liners | — |
| `mf_casedepth.m` | Hertz half width, depth of the largest shear stress and the case depth needed at MCT and LD-02, flanks and planet bearing raceways | TC80 |
| `mf_film.m` | Film ratio of the three meshes against the flank finish (MIL-PRF-23699, the step 2.4 film) | TC83 |
| `mf_fasteners.m` | Bottom-up fastener mass against the 5% allowance of step 3.1 | TC81 |
| `mf_liners.m` | Steel seat liners: mass not yet in the roll-up, fit change from -40 to 149 °C | TC82 |
| `mf_bom.m` | Bill of materials with the SYS-06 basis of each line; roll-up and bottom-up estimate | TC84 |
| `run_step34.m` | Full run: `manufacturing/bom_v1.csv`, CSV tables and plots in English and Turkish to `calc/results/step34/` (not committed) | — |
| `test_step34.m` | Compares results with `tests/step34_test_cases.csv` (40 values, `calc/reference/step34_reference.py`, standard library) | All |

```matlab
addpath('calc/manufacturing', 'calc/gear_detail', 'calc/shafts_bearings', 'calc/assembly');
S = run_step34();        % about 10 seconds, after run_step32
test_step34              % 40 values, 0 failures
```

Step 3.5, 3-D structural analysis: the basis is Section 3.5 of the Phase 3 report. The planetary case, the first-stage case and the carrier with the propeller shaft are meshed from their CATIA STEP files (`cad/step/case.stp`, `fs_case.stp`, `carrier.stp`) with the PDE Toolbox `femodel` (quadratic tetrahedra).

| File | Purpose | Test cases |
| --- | --- | --- |
| `st_inputs.m` | Materials, element sizes, face picking points, loads, carrier and liner data, VDI 2230 bolt data, dowel pins, mount ring | — |
| `st_loads.m` | Torques, K_gamma P99 at LD-01 and LD-08, propeller bearing reactions (LD-05, 1 g, 1P) | TC85 |
| `st_liners.m` | Steel seat liners in the A357: Lame shrink fit sized for 149 °C, pressure and stresses from −40 to 149 °C | TC86 |
| `st_bolts.m` | VDI 2230 Part 1 of a bolted circle (flange 30 x M6 on PCD 290, mount ring 12 x M8/M10 on PCD 140), dowel pins | TC87, TC88 |
| `st_case3d.m` | Case: seat stiffness (fixed and bolted springs), limit stress with the casting factor, liners at −40 °C, 1P fatigue (Goodman), ring seat twist | TC91 |
| `st_carrier3d.m` | Carrier: windup at MCT, LD-01 and LD-08 stresses, press fit of the separate M50NiL pins (Lame) | TC89, TC91 |
| `st_fscase3d.m` | First-stage case (`cad/step/fs_case.stp`: flange holes blind, 10 mm; rear wall 16 mm): held at the PT-axis mount ring (step 3.1 layout) or at the planetary case flange; gear forces on both half faces of each bore over the bearing width, with the axial-force moment (corrected in step 3.6); limit stress, fatigue, first-stage mesh tilt | TC91 |
| `st_khb.m` | K_Hbeta back-check of a mesh with an added misalignment (case twist, first-stage tilt), the step 2.4 rating | — |
| `st_liner_fix.m` | NU1024 liner: thicker boss or lower hold temperature for an A357 safety of 1.25 at −40 °C | TC92 |
| `st_mass.m` | SYS-06 mass closure options for Hamit's card (nothing applied) | TC90 |
| `run_step35.m` | Full run (about 30 minutes): tables, plots in English and Turkish to `calc/results/step35/` (not committed) | — |
| `test_step35.m` | Compares results with `tests/step35_test_cases.csv` (60 values, `calc/reference/step35_reference.py`, standard library) | All |

```matlab
addpath('calc/structures', 'calc/gear_detail', 'calc/manufacturing', 'calc/assembly');
S = run_step35();        % about 30 minutes, after run_step34
test_step35              % 60 values, 0 failures
```

Step 3.6, dynamics: the basis is Section 3.6 of the Phase 3 report. Forced response to the mesh excitation (DYN-03, DYN-04), the damping ring of the first-stage gear and the Campbell diagrams. The planet is a 3-D PDE Toolbox model on its rollers and meshes (exact spring tensors); the first-stage gear blank and the planetary case are axisymmetric harmonic models (one Fourier harmonic at a time, quadratic triangles on the section); the first-stage case is a coarse 3-D model. It needs `calc/gear_detail/`, `calc/shafts_bearings/`, `calc/housing/` and `calc/structures/` on the path; in `calc/dynamics/`:

| File | Purpose | Test cases |
| --- | --- | --- |
| `dy_inputs.m` | Transmission error, damping, ring rule, case brackets and Goodman inputs | — |
| `dy_axi_mesh.m`, `dy_axi_km.m`, `dy_axi_ring.m` | Harmonic axisymmetric element: section mesh, stiffness, mass and nodal stresses (optionally from selected elements only); free-ring check | TC95 |
| `dy_planet_frf.m`, `dy_face_weights.m`, `dy_tet10_stress.m`, `dy_planet_forces.m` | Planet modes and dynamic tooth forces, K_v,FE and S_F per mesh band; consistent face weights; tet10 stresses; mesh forces per unit TE | TC93, TC99 |
| `dy_shuttle.m` | Axial shuttle of the contact-line centroid of the helical first-stage mesh | TC93 |
| `dy_web.m`, `dy_ring.m`, `dy_web_check3d.m` | First-stage gear blank: in-band families, once-per-revolution stress, friction damping ring (slip, stick limit, energy balance), 3-D check | TC94, TC96, TC97 |
| `dy_case_frf.m`, `dy_ring_couple.m`, `dy_couple_check.m`, `dy_pass_amp.m`, `dy_case_stage.m` | Planetary case coupled to the planets by receptance; ring seat brackets slide / rim / mass; steady and planet-pass static fields; Goodman node by node on A357 nodes with the corner rule | TC98, TC99 |
| `dy_fscase_frf.m`, `dy_fscase_stage.m` | First-stage case, coarse 3-D, in the first-stage 1x band; reaction check | TC98 |
| `dy_vm_cycle.m` | Cycle maximum of von Mises of a harmonic stress state | TC99 |
| `dy_ring_export.m`, `dy_plots.m` | Groove and ring data for CATIA (`cad/params/gear2_ring.txt`); Campbell, response and ring plots in English and Turkish | — |
| `run_step36.m`, `run_step36_case.m` | Full run (about 70 min) to `calc/results/step36/` (not committed); rerun of the case stages on a saved step36.mat | — |
| `test_step36.m` | Compares results with `tests/step36_test_cases.csv` (201 values, `calc/reference/step36_reference.py`, standard library); a missing value counts as a failure | All |

```matlab
addpath('calc/dynamics', 'calc/gear_detail', 'calc/shafts_bearings', 'calc/housing', 'calc/structures');
S = run_step36();        % about 70 minutes
test_step36              % 201 values, 0 failures
```

Step 3.7, safety: the basis is Section 3.7 of the Phase 3 report. Fault trees of propeller release (SAF-01, CS-E 510) and of the two dual failures the FMEA points to, the FMEA of the RGB and its oil system, the critical parts (SAF-02, CS-E 515) with their surface damage tolerance (EASA CM-PIFS-007), and the fire assessment of the oil-wetted cases (SAF-05, CS-E 130). Core MATLAB only; the tables go to `safety/`. In `calc/safety/`:

| File | Purpose | Test cases |
| --- | --- | --- |
| `sf_inputs.m` | Fault tree events and rates, FMEA classes and groups, damage tolerance materials, NDT sizes, loads and locations, critical parts and plan items, fire inputs (all assumed values TBR with their source) | — |
| `sf_qj.m` | QJ1024 axial-loss follow-up (G1b): thrust floor, NJ1024 push-in standby rating and end play, limp thrust, the R4 branches given a QJ1024 axial loss, the E7 phases, the SYS-06 roll-up | TC118 |
| `sf_fta.m`, `sf_cutset.m`, `sf_lip.m`, `sf_plot_fta.m` | Propeller release: dual-path cut sets (one per-hour event, the standby failed at lambda t + q_d, exact mean over the interval, Weibull QJ1024 renewed at TBO, oil-loss dependent cause), the criterion per cut set, the never-inspected case (Airworthiness Limitations items), the sensitivity with the restoring inspection interval, the retention tube in the post-failure phase; the cut-set mean with active, Weibull, latent and demand events; the nose cover P116 (LD-04 sizing, lip rubbing) and the E7 oil-loss phases | TC100, TC114 |
| `sf_coupling.m` | Diaphragm coupling options (H4): the step 2.2 model with the pre-stretch and the angular budget, the Goodman, buckling and static rules, D4 at the thinnest section (base and the threshold -20%), the alignment stack; the lightest passing option goes into the D4 locations | TC103, TC117 |
| `sf_protect.m` | Shaft-break and load-loss protection coverage (SAF-03, CTL-02): protection Np from the core PT rotor, control Np on the pinion, Nr on P103; for each break location the PT-side inertia (step 2.3 model), the detecting signal (3% mismatch or absolute Np trip with a confirming cue), the time to a closed fuel valve and the peak speed (step 1.4 run-up; `calc/torsion`, `calc/rgb_sizing`, `calc/agb_lube` on the path) | TC115 |
| `sf_fta2.m`, `sf_plot_fta2.m` | D1b: (a) PT overspeed (the drive-chain breaks of the G2 coverage table with a protection element failed, each lambda T / 2 + q_d at the start check, spurious trips), (b) the hazardous propeller effect (PCU fail-to-fine, downstream breaks, cross-leak, blockage, common cause; OSG, low-pitch stop, FADEC feather, counterweights); allowances from each cut set, sums against 1e-7, x10 sensitivity | TC105 |
| `sf_fmea.m`, `sf_plot_fmea.m` | Checks of `safety/fmea_v1.csv` (classes, groups, IDs, critical parts, features, detection, an ICA task for every latent row, the critical parts as the derived set plus the parts kept by decision) and its summaries; the major-effects rate table against Remote | TC101 |
| `sf_nr.m`, `sf_nr_check.m` | Newman-Raju K of surface and corner cracks (NASA TM-85793) and its check against the published FE values (TP-1578, TM-85793, TM-89070) | TC102, TC103 |
| `sf_locations.m`, `sf_dt.m`, `sf_dt_all.m`, `sf_plot_dt.m` | Stress components of the ten critical locations (the coupling diaphragm and hub transition added) with their temperature and environment; through cracks with the shell bulging factor where the anomaly or an NDT pair is deeper than 0.8 t or at the NASA-STD-5009C thickness limits; the embedded flaw of CS-E 515(a); crack plane (fixed plane, 1 deg scan), HCF threshold size, LCF growth from the first cycle, critical size, inspection interval and NDT margin; sensitivity | TC103 |
| `sf_dt_design.m`, `sf_plot_dt_design.m` | Design studies: the P103 thread options (rule a_HCF >= 1.25 x the NDT depth), the carrier rim bosses, the 1P moment sweep and its limit | TC113 |
| `sf_parts.m` | Critical parts list with the minimum S-N life, the approved life and the plan items | TC104 |
| `sf_fire.m`, `sf_fire_all.m`, `sf_plot_fire.m` | D5: time to zero oil flow; cylindrical 1-D wall in the standard flame at its upper tolerance (pdepe, m = 1) with the drain-film h at the lowest flow, then the zero-flow phase; smallest passing h per wall | TC106 |
| `sf_fire_joint.m` | D5 F3: the P101 / F201 joint, 2-D r-z explicit finite volumes with the P101 rear wall, with and without the partition; seal, seat and insert temperatures, residual clamp | TC106 |
| `run_step37.m` | Full run (about 1 minute) to `calc/results/step37/` (not committed), tables to `safety/`, figures to `docs/figures/step37/` | — |
| `test_step37.m` | Compares results with `tests/step37_test_cases.csv` (416 values, `calc/reference/step37_reference.py`, standard library, about 1.5 minutes); a missing value counts as a failure | All |

```matlab
addpath('calc/safety');
S = run_step37();        % about 1 minute
test_step37              % 416 values, 0 failures
```

Step 3.8, tolerances and fits: the basis is Section 3.8 of the Phase 3 report. Drawing standard ASME Y14.5-2018 (metric) with ISO 286 fits, ISO 1328-1:2013 gear accuracy and ISO 4156 splines. Datums and geometric tolerances, the thermal map, the backlash, load-sharing and axial stack-ups (worst case and Monte Carlo with the tolerances as +-3 sigma), fits at temperature, spline fits and gear grades; the tables go to `manufacturing/`. Core MATLAB with `calc/gear_detail/` on the path. In `calc/tolerances/`:

| File | Purpose | Test cases |
| --- | --- | --- |
| `tl_inputs.m` | All step 3.8 inputs and assumptions (TBR marked) | — |
| `tl_iso286.m` | ISO 286-1 limit deviations from its formulae | TC109 |
| `tl_thermal.m`, `tl_plot_thermal.m` | Thermal map (E2): steady states and the lumped cold-start transient | TC107 |
| `tl_gears.m` | Gear accuracy per gear (E6, ISO 1328-1:2013) | TC108 |
| `tl_datums.m` | Datum schemes and geometric tolerances (E1) | — |
| `tl_backlash.m`, `tl_kgamma.m`, `tl_axial.m`, `tl_lame.m`, `tl_plot_stack.m` | Stack-ups (E3): backlash with temperature, K_gamma with the drawing tolerances, axial gaps | TC110 |
| `tl_fits.m`, `tl_plot_fits.m` | Fits at temperature (E4): bearing rings and operating clearance, liners, planet pins, ring gear seat | TC111 |
| `tl_splines.m` | Spline fits at temperature (E5) | TC112 |
| `tl_drawing_table.m` | Tolerance and fits table for the 3.9 drawings (EN / TR) | TC112 |
| `run_step38.m` | Full run (about 10 seconds) to `calc/results/step38/` (not committed), tables to `manufacturing/`, figures to `docs/figures/step38/` | — |
| `test_step38.m` | Compares results with `tests/step38_test_cases.csv` (187 values, `calc/reference/step38_reference.py`, standard library); a missing value counts as a failure | All |

```matlab
addpath('calc/tolerances', 'calc/gear_detail');
S = run_step38();        % about 10 seconds
test_step38              % 187 values, 0 failures
```

Step 3.10, maintenance demonstration and HUMS indicators: the basis is Section 3.10 of the Phase 3 report. A synthetic signal of the accelerometer over the ring gear (healthy, a cracked sun tooth, a spalled planet bore) stands in for the engine test; on it the time-synchronous average of the sun relative to the carrier, FM4, NA4, the sideband energy and an envelope indicator are computed, and caution and alarm thresholds are set from a healthy baseline (CTL-03). `hm_access.m` checks the line of sight from the two borescope ports to the meshes on the CATIA parts exported as STL (MNT-02); the module removal animation is `cad/anim/rgb_anim.m` mode `removal`, the task table `maintenance/`. Needs `calc/gear_detail/`, `calc/shafts_bearings/` and `calc/accessory/` on the path; in `calc/hums/`:

| File | Purpose | Test cases |
| --- | --- | --- |
| `hm_inputs.m` | Signal model, fault sizes and processing settings (assumptions TBR) | — |
| `hm_synth.m` | Synthetic signal: planetary mesh with sequential phasing and planet-pass window, first-stage mesh, shaft orders, sun tooth crack, planet bore spall ringing at a case resonance, noise | TC119 |
| `hm_tsa.m` | Time-synchronous average by angular resampling on a once-per-revolution tachometer | TC120 |
| `hm_indicators.m` | FM4, NA4, sideband energy on the TSA; envelope indicator ENV at the planet bore defect frequency | TC120 |
| `hm_threshold.m` | Log-normal caution and alarm thresholds from a healthy population | TC121 |
| `hm_access.m` | Borescope line of sight on the STL parts (ray casting); pictures | — |
| `run_step310.m` | Baseline of 50 healthy records, thresholds, fault size sweeps (about 20 seconds); `summary.txt` and plots to `calc/results/step310/` (not committed), `maintenance/hums_thresholds_v1.csv`; figures copied to `docs/figures/step310/` | — |
| `test_step310.m` | Compares results with `tests/step310_test_cases.csv` (13 values, `calc/reference/step310_reference.py`, numpy) | All |

```matlab
addpath('calc/hums', 'calc/gear_detail', 'calc/shafts_bearings', 'calc/accessory');
R = run_step310();       % about 20 seconds
test_step310             % 13 values, 0 failures
A = hm_access('<folder of the STL files from cad/anim/export_stl.vbs>', 'calc/results/step310');
```

**TR.** MATLAB tasarım hesapları. Her biri bağımsız Python referans hesabından gelen beklenen değerlerle test ediliyor; yani testler iki uygulamanın birbirini tuttuğunu gösteriyor. Her betik başlığında girdilerini, birimlerini ve kaynaklarını belirtir. 1.3 adımı redüksiyon dişli kutusunu boyutlandırıyor (`calc/rgb_sizing/`); 1.4 adımı aksesuar tahriklerini, dişli kutusu kayıplarını ve ısı dengesini, yağ sistemini ve mil kopmasındaki aşırı hızı ekliyor (`calc/agb_lube/`). Faz 2 (detay tasarım) her adım için bir klasör ekliyor; ilki 2.1 adımının pervane mili rotor dinamiği (`calc/rotor_damper/`), ardından 2.2 adımının güç türbini çıkış mili (`calc/pt_shaft/`), 2.3 adımının burulma modeli (`calc/torsion/`), 2.4 adımının dişli detay hesabı (`calc/gear_detail/`), 2.5 adımının yatakları, milleri ve kamalı bağlantıları (`calc/shafts_bearings/`), 2.6 adımının aksesuar tahrikleri (`calc/accessory/`), 2.7 adımının yağlama sistemi (`calc/lubrication/`), 2.8 adımının gövde ve planet sonlu eleman modelleri (`calc/housing/`), 2.9 adımının CATIA parametre aktarımı (`calc/cad_export/`) ve 2.10 adımının durum izleme frekansları ve sensör yerleri (`calc/hums/`). Faz 2'den itibaren beklenen test değerlerini yazan bağımsız Python referansları da depoda tutuluyor (`calc/reference/`, `rotordynamics/`).

1.3 adımı, redüksiyon dişli kutusunun ön boyutlandırması: hesap esasları (girdiler, kabuller, formüller, araç yapısı ve test durumları) Faz 1 raporunun 3. bölümünde. Araç, O düzeninin (kaçık helisel bir ilk kademe, ardından yüzer güneşli, sabit halkalı ve taşıyıcı çıkışlı bir planet kademesi) bütün geçerli diş sayısı takımlarını tarıyor, dişlileri sadeleştirilmiş ISO 6336 ile boyutlandırıyor, milleri, yatakları ve kritik hızları kontrol ediyor ve 3, 4 ve 5 planet için en hafif geçerli tasarımı raporluyor. Önerilen dosyalar, her biri tek bir iş yapıyor, `calc/rgb_sizing/` içinde:

| Dosya | Görev | Test |
| --- | --- | --- |
| `rgb_inputs.m` | Bütün girdi ve kabuller tek bir struct'ta; diğer fonksiyonların içine sayı gömülmez | — |
| `gear_geometry.m` | Çift geometrisi: d, d_b, d_a, a, ε_α, ε_β, β_b (dış ve iç çift) | TC1–TC3 |
| `iso6336_lite.m` | Kuvvetler, çevresel hız, σ_H, σ_F, S_H, S_F; statik seçeneği | TC1–TC3, TC5 |
| `tooth_set_check.m` | Tek bir diş sayısı takımının kuralları: oran, montaj, planet uç boşluğu, avcı diş | TC4a, TC4b |
| `tooth_sets.m` | Geçerli diş sayısı takımları | TC4c |
| `size_stage1.m` | İlk kademe modül döngüsü | Tam çalıştırma |
| `planet_stage.m` | Tek bir modülde planet kademesi: iki kavrama ve planet yatağı | TC5 |
| `size_stage2.m` | Planet kademesi modül döngüsü, taşıyıcı ayağı boşluğu | Tam çalıştırma |
| `planet_bearing.m` | Planet yatağı C, C0, merkezkaç yükü, görev ömrü, s0 | TC5 |
| `shaft_check.m` | Mil gerilmeleri ve emniyetleri | TC6 |
| `size_shaft.m` | En küçük dış çap d_o | Tam çalıştırma |
| `bearing_req.m` | P_eq, C_req, C0_req, DN | TC7 |
| `critical_speed.m` | İki kritik hız modeli | TC8 |
| `rgb_mass.m` | Her parçanın ana ölçülerinden kütlesi | TC9 |
| `rgb_layout.m` | Tek bir tasarım: miller, ana yataklar, kritik hızlar, kütle dökümü | Tam çalıştırma |
| `run_rgb_sizing.m` | Hepsini çalıştırır; tabloları, grafiği ve test raporunu `calc/results/step13/` içine yazar (commit edilmez) | — |
| `test_rgb_sizing.m` | Sonuçları `tests/step13_test_cases.csv` ile karşılaştırır | Hepsi |

`tests/step13_test_cases.csv`, TC1–TC9'un beklenen değerlerini tutuyor: 109 satır, sütunlar `tc`, `quantity`, `expected` ve `unit`. Değerlerde en çok altı anlamlı basamak var. Göreli fark en çok %0,1 ise test geçer; sayımlar (birimi `count` olanlar, makara sayısı `Z` ve `assembly_ok`) birebir tutmalı. `unit` sütununda `-` boyutsuz demek, `modules` ise planet uçları arasındaki boşluğun modüle bölümü. Büyüklük adlarında `1` ve `2` dişli 1 (çiftin küçük dişlisi) ve dişli 2, `_sp` güneş–planet kavraması, `_pr` planet–halka kavraması, `_ring` halka dişli, `_static` ise 1,375 × torkla LD-01 kontrolü. Her test durumunun girdileri raporda (3. bölüm, Test durumları); beklenen değerler raporun "1.3 Testler / Tests" sekmesinde de var. MATLAB'da bir değeri okumak için yukarıdaki kod parçası kullanılabilir.

MATLAB tam çalıştırmasının bağımsız Python referansıyla karşılaştırması Faz 1 raporunun 3. bölümüne yazılacak.

1.4 adımı, aksesuar tahrikleri, kayıplar, yağ sistemi ve mil kopması: hesap esasları Faz 1 raporunun 4. bölümünde. Araç PDR'nin ardından seçilen RGB'yi (31/110 | 45/37/119, 4 planet; `lube_inputs.m` içinde `in14.design`) 1.3 fonksiyonlarıyla kurduğu için `calc/rgb_sizing/` da yolda olmalı. `calc/agb_lube/` içinde:

| Dosya | Görev | Test |
| --- | --- | --- |
| `lube_inputs.m` | 1.4 adımının bütün girdi ve kabulleri: yağ, ped torkları, kayıp modeli katsayıları, çalışma noktaları, yağ sistemi, mil kopması | — |
| `oil_props.m` | Yağın viskozitesi (40 ve 100 °C'den geçen Walther doğrusu, ASTM D341), yoğunluğu ve dinamik viskozitesi | TC10 |
| `mesh_loss.m` | Kavrama güç kaybı: Schlenk sürtünme katsayısı ve Ohlendorf kayıp faktörü H_V (ISO/TR 14179-2 yaklaşımı), dış ve iç çiftler | TC11, TC12 |
| `windage_loss.m` | Dişli rüzgâr (windage) kaybı, NASA TM-83716 formülü | TC13 |
| `bearing_loss.m` | Yatak sürtünmesi, Palmgren M0 + M1 | TC13 |
| `pad_mesh.m` | Bir aksesuar çiftinin üç kontrolü geçen en dar diş genişliği: anma torku, yorulmada 1,5 × tork, kesme boynu torkunda statik | TC14 |
| `accessory_pads.m` | Jeneratör, aşırı hız regülatörü (OSG), pervane kontrol ünitesi (PCU) ve yağ pompası tahrikleri: hızlar, dişliler, kesme boyunları, kütle | TC14 |
| `rgb_losses.m` | Tek bir çalışma noktasında RGB'nin bütün kayıpları, pervaneden güç türbinine doğru izlenerek; L_mech (SYS-05) ve yağa giden ısı (LUB-04) | TC17 |
| `lube_sizing.m` | Yağ debisi, pompalar, tank hacmi, hava–yağ soğutucusu ve yağ jetleri | TC15 |
| `shaft_break.m` | Güç aktarım zinciri koptuktan sonra güç türbini aşırı hızı (SAF-03), RK4 | TC16 |
| `run_step14.m` | Hepsini çalıştırır (pompa gücü üzerinden sabit nokta ile yağ sistemi, dört çalışma noktası, kayıp duyarlılığı, mil kopması haritası); `summary.txt`, `losses.csv`, `shaft_break.csv`, iki grafik ve test raporunu `calc/results/step14/` içine yazar (commit edilmez) | — |
| `test_step14.m` | Sonuçları `tests/step14_test_cases.csv` ile karşılaştırır | Hepsi |

`tests/step14_test_cases.csv`, TC10–TC17'nin beklenen değerlerini tutuyor: 78 satır, 1.3 adımıyla aynı biçim ve aynı %0,1 kuralı. Depo kökünden çalıştırmak için yukarıdaki üç satırlık kod yeterli.

2.1 adımı, pervane mili rotor dinamiği ve DYN-05: hesap esasları Faz 2 raporunun 2.1 bölümünde. Araç pervane milinin jiroskopik sonlu eleman modeli (Timoshenko kiriş elemanları, disk olarak taşıyıcı ve pervane, her yatak için rulman, muylu halkası, merkezleme yayı ve yağ filmi, gövde zinciri). DYN-05'teki geri yönlü savrulma için dört kavramı bir gövde rijitliği aralığında karşılaştırıyor ve 120/100 mm ince cidarlı milin, gövde yuvaları her yönde en az 5e7 N/m verirse sönümleyicisiz DYN-05'i sağladığını buluyor. `calc/rgb_sizing/` (rgb_inputs, shaft_check) ve `calc/agb_lube/` (oil_props) da yolda olmalı. `calc/rotor_damper/` içinde:

| Dosya | Görev | Test |
| --- | --- | --- |
| `damper_inputs.m` | 2.1 adımının bütün girdi ve kabulleri: rotor, yataklar, gövde aralığı, sönümleyici sınırları, denenen kavramlar | — |
| `beam_timoshenko.m` | Tek düzlemde içi boş Timoshenko kiriş elemanının matrisleri (rijitlik, öteleme ve dönme kütlesi, jiroskopik terimler için kutupsal matris) | TC18 |
| `support.m` | Rotor modelinin bir yatağı: doğrudan yere ya da rulman, muylu, sönümleyici, gövde zinciri olarak | — |
| `rotor_model.m` | Taşıyıcı, pervane, isteğe bağlı flanş ve yataklarla milin M, C, G, K matrisleri | TC19–TC21 |
| `rotor_campbell.m` | Hıza göre sönümlü doğal frekanslar, sönüm oranları ve savrulma yönleri; 1× kesişimleri | TC19, TC21 |
| `rotor_unbalance.m` | Dengesizlik cevabı: her düğümde yörüngenin büyük yarı ekseni, muylu yörüngesi, yatak kuvvetleri, milde sabit ve değişken gerilme | TC20, TC21 |
| `sfd_coeffs.m` | Kısa sıkıştırılmış yağ filmi sönümleyicisinin sönümü, merkezli dairesel yörünge | TC22 |
| `squirrel_cage.m` | Sincap kafesi merkezleme yayının rijitliği ve çubuk gerilmesi | TC23 |
| `run_step21.m` | Faz 1 ile doğrulama, kavramlar, sönümleyici kayması, gövde rijitliği haritası, son mil; `summary.txt`, dört CSV, Türkçe ve İngilizce üç grafik ve test raporunu `calc/results/step21/` içine yazar (commit edilmez) | — |
| `test_step21.m` | Sonuçları `tests/step21_test_cases.csv` ile karşılaştırır | Hepsi |

`tests/step21_test_cases.csv`, TC18–TC23'ün beklenen değerlerini tutuyor: 27 satır, 1.3 ve 1.4 adımlarıyla aynı biçim ve aynı %0,1 kuralı. Değerler ROSS'tan ve kapalı formlardan geliyor ve `rotordynamics/step21_reference.py` tarafından yazılıyor; yani testler MATLAB rotor modelinin ROSS'u tuttuğunu gösteriyor. Depo kökünden:

```matlab
addpath('calc/rotor_damper', 'calc/rgb_sizing', 'calc/agb_lube');
test_step21              % 27 değer, 0 hata
S = run_step21();        % tam çalıştırma, yaklaşık 6 dakika
run_step21([], 'plots'); % grafikleri calc/results/step21/step21.mat dosyasından yeniden çizer
```

2.2 adımı, güç türbini çıkış mili: hesap esasları Faz 2 raporunun 2.2 bölümünde. Kurulum C'de, iki ucunda birer diyafram kaplin olan yüzer bir mil güç türbininden egzoz toplayıcısındaki bir tünelden geçerek RGB'ye gidiyor. Araç diyafram paketlerini ve mili boyutlandırıyor; faz kaymalı tork ölçeri, güç türbininin arka rulmanını ve tünel sıcaklıklarını kontrol ediyor. `calc/rotor_damper/` (beam_timoshenko) da yolda olmalı. `calc/pt_shaft/` içinde:

| Dosya | Görev | Test |
| --- | --- | --- |
| `ptshaft_inputs.m` | 2.2 adımının bütün girdi ve kabulleri: torklar, kaçıklıklar, malzemeler, ızgaralar, tork ölçer, arka rulman, tünel | — |
| `tube_shaft.m` | Yüzer mil: kayma gerilmesi, burulma, burkulma, Goodman yorulması, ilk eğilme kritik hızı (uç kütleli ve yaylı Timoshenko elemanları) | TC24 |
| `annular_plate.m` | İki kenarı ankastre düz diyafram: eksenel ve açısal rijitlik, birim kaçıklık ve birim eğilme başına gerilme (kapalı form levha çözümleri) | TC25 |
| `diaphragm.m` | Bir diyafram paketi: gerilmeler, rijitlik, millere yükler, yorulma, statik, patlama ve burkulma emniyetleri | TC26 |
| `torque_meter.m` | Faz kaymalı tork ölçerin burulması, çözünürlüğü ve sıcaklık hatası (CTL-01) | TC27 |
| `rear_bearing.m` | Güç türbini arka rulmanı: yükler, L10, statik emniyet, kaymaya karşı en küçük yük | TC28 |
| `tunnel_thermal.m` | Şaft tüneli boyunca sıcaklıklar: yalıtım, tampon hava, rüzgâr kaybı | TC29 |
| `run_step22.m` | Kaplinleri ve mili boyutlandırır; mil boyu duyarlılığı, tork ölçer, arka rulman, tünel ve arka karter; `summary.txt`, iki CSV, Türkçe ve İngilizce iki grafik ve test raporunu `calc/results/step22/` içine yazar (commit edilmez) | — |
| `test_step22.m` | Sonuçları `tests/step22_test_cases.csv` ile karşılaştırır | Hepsi |

`tests/step22_test_cases.csv`, TC24–TC29'un beklenen değerlerini tutuyor: 29 satır, aynı biçim ve aynı %0,1 kuralı. Değerler bağımsız bir Python uygulamasından, `calc/reference/step22_reference.py` (numpy ve scipy; örneğin `rotordynamics/.venv` ile) geliyor; bu uygulama diyafram levha problemlerini kapalı form yerine scipy'nin sınır değer çözücüsüyle çözüyor. Depo kökünden:

```matlab
addpath('calc/pt_shaft', 'calc/rotor_damper');
test_step22              % 29 değer, 0 hata
S = run_step22();        % tam çalıştırma, yaklaşık 20 saniye
```

2.3 adımı, burulma titreşimi ve ani durma: hesap esasları Faz 2 raporunun 2.3 bölümünde. Bütün zincirin (güç türbini, yüzer mil ve kaplinler, giriş pinyonu, jeneratör koluyla ilk kademe dişlisi, güneş, dört planet, taşıyıcı, pervane mili, pervane) burulma modeli doğal frekansları veriyor, onları DYN-02 mertebeleri ve güç türbini mertebeleriyle karşılaştırıyor ve güç türbini kilitlenince pervane milindeki torku hesaplıyor (LD-08). 2.2 adımının yüzer mili için burulma rijitliği tabanını (`ptshaft_inputs.m` içinde `kt_min`) bu adım belirliyor. `calc/rgb_sizing/` da yolda olmalı. `calc/torsion/` içinde:

| Dosya | Görev | Test |
| --- | --- | --- |
| `torsion_inputs.m` | 2.3 adımının bütün girdi ve kabulleri: mertebeler, kavrama rijitliği, ataletler, miller, jeneratör kolu, durma süreleri | — |
| `gear_data.m` | Tasarımın yarıçapları, diş genişlikleri, kütleleri ve ataletleri (1.3 aracından) | — |
| `torsion_model.m` | Fiziksel açılarla atalet ve rijitlik matrisleri; miller, kavrama çizgisi boyunca dişli kavramaları, saf burulmalı planet kademesi; rijit hız oranları | TC30, TC31 |
| `torsion_modes.m` | Doğal frekanslar, her elemanın şekil değiştirme enerjisi payı, DYN-02 pay kontrolü | TC30 |
| `sudden_stop.m` | Güç türbini belli bir sürede durunca tepe torklar: tam darbe cevabıyla modal süperpozisyon | TC32 |
| `run_step23.m` | Modlar ve DYN-02, yüzer mil taraması, duyarlılık, ani durma haritası; `summary.txt`, iki CSV, Türkçe ve İngilizce iki grafik ve test raporunu `calc/results/step23/` içine yazar (commit edilmez) | — |
| `test_step23.m` | Sonuçları `tests/step23_test_cases.csv` ile karşılaştırır | Hepsi |

`tests/step23_test_cases.csv`, TC30–TC32'nin beklenen değerlerini tutuyor: 12 satır, aynı biçim ve aynı %0,1 kuralı; değerler `calc/reference/step23_reference.py`'den, kendi öz değer çözümü ve ani durma için doğrudan zaman integrasyonu (scipy Radau) olan bağımsız bir Python modelinden geliyor. Depo kökünden:

```matlab
addpath('calc/torsion', 'calc/rgb_sizing');
test_step23              % 12 değer, 0 hata
S = run_step23();        % tam çalıştırma
```

2.4 adımı, dişlilerin detay hesabı: hesap esasları Faz 2 raporunun 2.4 bölümünde. PDR tasarımının üç kavramasını ISO 6336:2019 Yöntem B ve C ile değerlendiriyor: Yöntem B'nin diş formu ve gerilme düzeltme katsayıları (dış dişlilerde azdırma, halkada kesici çark), Yöntem B dinamik katsayısı (planet kademesi 6.5.8.4'e göre), pinyonun, güneşin ve taşıyıcının elastik kaçıklıklarıyla Yöntem C yüz yük katsayısı, enine yük katsayısı, yüzer güneşli Monte Carlo modelinden planet yük paylaşım katsayısı, statik ve sınırlı ömür kontrolleri (LD-01, LD-02, LD-08), görev spektrumu (Palmgren-Miner), yağ filmi kalınlığıyla birlikte anlık sıcaklık yöntemiyle sıvanma, kavrama frekanslarına karşı dişli jantı ve gövde modları (DYN-04) ve SYS-07 avara seçeneği. 2.5 adımı sonradan planet kademesini 70 mm'ye genişletti, planet jantını 8 mm'ye ve taşıyıcı ayaklarını 60 mm'ye kalınlaştırdı (planet yatağı ömrü); `gd_inputs.m` güncel tasarımı tutuyor. Başka klasöre ihtiyaç yok; `calc/gear_detail/` içinde:

| Dosya | Görev | Test |
| --- | --- | --- |
| `gd_inputs.m` | 2.4 adımının bütün girdi ve kabulleri: tasarım, takımlar, hassasiyet, malzemeler, pürüzlülük, taşıyıcı, yük paylaşımı toleransları, yağlar | — |
| `gd_tolerances.m` | ISO 1328-1:2013 formülleriyle yan yüzey toleransları | — |
| `gd_root.m` | Yöntem B diş kökü değerleri: s_Fn, rho_F, h_Fe, Y_F, Y_S (ISO 6336-3 Formül (9)–(64)) | TC33 |
| `gd_pair.m` | Profil kaydırmalı çift geometrisi, kavrama yolu, aktif profil başlangıcı, özgül kayma, Z_H, Z_eps, Z_B, Z_D | TC34 |
| `gd_meshes.m` | Torkları, hızları, indirgenmiş kütleleri ve elastik kaçıklık katsayılarıyla üç kavrama | TC35 |
| `gd_rate.m` | Rijitlik, K_v, K_Hbeta, K_Halpha, pitting ve kök gerilmeleri, ömür katsayıları, güvenlik katsayıları | TC35, TC36 |
| `gd_sn.m` | İzin verilen gerilmenin ömür eğrisi (statik, referans, uzun ömür) ve tersi | TC36 |
| `gd_loadshare.m` | Yüzer güneşle planet yük paylaşım katsayısı: toleranslar üzerinde Monte Carlo ya da verilen bir hata kümesi | TC37 |
| `gd_scuffing.m` | Kavrama yolu boyunca yük paylaşımı, Hertz gerilmesi, anlık ve temas sıcaklığı, sıvanma güvenliği, yağ filmi oranı | TC38 |
| `gd_modes.m` | Serbest ince halka modları ve jantıyla dişli gövdesi modları (dairesel halka plak, Hermite elemanları) | TC39 |
| `run_step24.m` | Helis düzeltmesi taraması, tasarım seçenekleri, değerlendirmeler, aşırı tork, LD-08 kapasitesi, görev ömrü, diş düzeltmeleri, sıvanma durumları, DYN-04, avara seçeneği; `summary.txt`, iki CSV, Türkçe ve İngilizce beş grafiği `calc/results/step24/` içine yazar (commit edilmez) | — |
| `test_step24.m` | Sonuçları `tests/step24_test_cases.csv` ile karşılaştırır | Hepsi |

`tests/step24_test_cases.csv`, TC33–TC39'un beklenen değerlerini tutuyor: 96 satır, aynı biçim ve aynı %0,1 kuralı; değerler `calc/reference/step24_reference.py`'den geliyor. Bu referans kök değerlerini standardın kapalı formülleri yerine dişi açan kesme işleminin (azdırma kremayeri ve kesici çark) sayısal benzetimiyle buluyor, yük paylaşımını seri yük yolu yerine planetlerin serbestlik dereceleriyle çözüyor, gövde modlarını Rayleigh-Ritz modeliyle ve çıplak gövde için Bessel fonksiyonlu kesin çözümle hesaplıyor. Depo kökünden:

```matlab
addpath('calc/gear_detail');
test_step24              % 96 değer, 0 hata
S = run_step24();        % tam çalıştırma, yaklaşık 20 saniye
```

2.5 adımı, yataklar, miller, kamalı bağlantılar ve pervane tutuşu: hesap esasları Faz 2 raporunun 2.5 bölümünde. Ana yatakları (giriş, ara ve pervane millerindeki silindirik makaralı yataklar ve radyal yönde serbest dört nokta temaslı bilyalı yataklar) ve planet yatağını (tek sıra, tam dolu, planet deliği dış bilezik) ISO/TR 1281-1:2021'in türettiği ISO 281 formlarıyla değerlendiriyor: görev boyunca değiştirilmiş anma ömrü, sınır yüklerde ve ani durmada statik güvenlik. Ayrıca en küçük mil kesitlerini (Goodman, sınır yükte akma, nihai yükte kopma), güneş ara milinin kamalı bağlantılarını (Dudley), SAF-01 için pervane tutuşu seçeneklerini ve DYN-04 için planet modlarını üç modelle kontrol ediyor. `calc/gear_detail/` dişli tasarımını kullanıyor (yolda olmalı); `calc/shafts_bearings/` içinde:

| Dosya | Görev | Test |
| --- | --- | --- |
| `sb_inputs.m` | 2.5 adımının bütün girdi ve kabulleri: gereksinimler, pervane yükleri, yerleşim, yataklar, planet yatağı, yağ, mil malzemesi, kamalı bağlantılar, tutuş | — |
| `sb_rating.m` | Makaralı ve bilyalı yatakların C, C0 ve C_u değerleri (ISO/TR 1281-1 formları; bilyalı C0 4.200 MPa Hertz temasından) | TC40 |
| `sb_life.m` | Eşdeğer yük, viskozite oranı, a_ISO ve görev boyunca L10m (makaralı, dört nokta temaslı ve 2.6'dan itibaren sabit bilyalı rulmanlar) | TC41, TC47 |
| `sb_shaft.m` | İçi boş mil kesitinde Goodman, akma ve kopma | TC42 |
| `sb_spline.m` | Evolvent kamalı bağlantıda diş kesmesi, yan yüzey basıncı ve kök burulması | TC43 |
| `sb_planet_rim.m` | Planet jantı modları: serbest halka, yüklü makaralar üzerinde, kavrama yaylarıyla | TC44 |
| `run_step25.m` | Dişli kuvvetleri ve K_gamma, yatak yükleri, kapasiteler ve ömürler, DYN-04 planet modları, miller, kamalı bağlantılar, tutuş, planet kademesi kütlesi; `summary.txt`, `bearings.csv` ve Türkçe ve İngilizce üç grafiği `calc/results/step25/` içine yazar (commit edilmez) | — |
| `test_step25.m` | Sonuçları `tests/step25_test_cases.csv` ile karşılaştırır | Hepsi |

`tests/step25_test_cases.csv`, TC40–TC44'ün beklenen değerlerini tutuyor: 64 satır, aynı biçim ve aynı %0,1 kuralı; değerler `calc/reference/step25_reference.py`'den geliyor. Her durum fonksiyonlara sabit girdiler veriyor, yani testler dişli modeline bağlı değil. Referans ayrıca test değeri olmayan iki kontrol yazdırıyor: serbest halkanın Hoppe kapalı formuyla karşılaştırması (aradaki fark %0,7) ve bilyalı C0'ın kesin eliptik integrallerle değeri (kullanılan Hamrock-Brewe değerinden %1,5 düşük). Depo kökünden:

```matlab
addpath('calc/shafts_bearings', 'calc/gear_detail');
test_step25              % 64 değer, 0 hata
S = run_step25();        % tam çalıştırma, yaklaşık 10 saniye
```

2.6 adımı, aksesuar tahrikleri: hesap esasları Faz 2 raporunun 2.6 bölümünde. ACC-02'nin güç türbiniyle dönen pedlerini (birinci kademe dişlisi üzerinden AC jeneratör, aşırı hız regülatörü, pervane kontrol ünitesi, yağ pompası) değerlendiriyor: üç aksesuar dişli çifti 2.4'ün araçlarıyla ISO 6336 Yöntem B ve C'ye göre üç yükleme durumunda (STR-01, ACC-03'ün 1,5 kat torku, kesme torkunda statik), ACC-03'ün kesme boyunları, 2.5'in araçlarıyla aksesuar mili rulmanları, dişli gövdelerinin kavrama frekanslarına karşı modları (DYN-04), jeneratörün öteki yanını yüklediği birinci kademe dişlisinin kökü ve ped arayüz tablosu. `calc/gear_detail/` ve `calc/shafts_bearings/` yolda olmalı; `calc/accessory/` içinde:

| Dosya | Görev | Test |
| --- | --- | --- |
| `ad_inputs.m` | 2.6 adımının bütün girdi ve kabulleri: ped torkları, dişli çiftleri ve gövdeleri, boyun malzemesi ve saçılımı, rulmanlar, jeneratör kütlesi | — |
| `ad_meshes.m` | Üç aksesuar kavraması, `gd_rate`'in aldığı biçimde | TC45 |
| `ad_neck.m` | Kesme boynu: çap, kesme torku bandı, 1,5 kat torkta yorulma | TC46 |
| `run_step26.m` | Boyunlar, dişli değerlendirmeleri, birinci kademe dişlisinin kökü, rulmanlar, gövde modları, ped tablosu, ped momenti, gövde kütleleri; `summary.txt`, `pads.csv` ve Türkçe ve İngilizce iki grafiği `calc/results/step26/` içine yazar (commit edilmez) | — |
| `test_step26.m` | Sonuçları `tests/step26_test_cases.csv` ile karşılaştırır | Hepsi |

`tests/step26_test_cases.csv`, TC45–TC48'in beklenen değerlerini tutuyor: 43 satır, aynı biçim ve aynı %0,1 kuralı; değerler 2.4 ve 2.5'in Python referanslarını kullanan `calc/reference/step26_reference.py`'den geliyor (TC47, `sb_life.m`'ye eklenen sabit bilyalı rulmanları kontrol ediyor). Depo kökünden:

```matlab
addpath('calc/accessory', 'calc/gear_detail', 'calc/shafts_bearings');
test_step26              % 43 değer, 0 hata
S = run_step26();        % tam çalıştırma, yaklaşık 10 saniye
```

2.7 adımı, yağlama sistemi: hesap esasları Faz 2 raporunun 2.7 bölümünde. 1.4 adımının kayıp modelini (`calc/agb_lube/`) 2.4–2.6'nın ayrıntılı tasarımına uygulayarak dört çalışma noktasında ısı dengesini (SYS-05, LUB-04) çıkarıyor; pompa gücüyle birlikte sabit noktaya giderek her bileşenin yağ akışını ve memelerini, besleme ve emme pompalarını (LUB-10'un PT arka yatak bölmesiyle) ve LUB-04 ile LUB-09'un hava-yağ soğutucusunu ofset şerit kanatçıklarla (etkinlik-NTU, Manglik ve Bergles) boyutlandırıyor; tankı, rüzgârla dönmeyi ve MIL-PRF-7808 sınırını kontrol ediyor. `calc/agb_lube/`, `calc/gear_detail/`, `calc/shafts_bearings/` ve `calc/accessory/` yolda olmalı; `calc/lubrication/` içinde:

| Dosya | Görev | Test |
| --- | --- | --- |
| `lb_inputs.m` | 2.7 adımının bütün girdi ve kabulleri: yağ, çalışma noktaları, kayıp katsayıları, memeler, pompalar, soğutucu, tank | — |
| `lb_design.m` | 2.4–2.6 tasarımı, `lb_losses`'ın aldığı biçimde | TC49 |
| `lb_losses.m` | Bir çalışma noktasında kalem kalem kayıplar ve yağa giren ısı | TC49 |
| `lb_flows.m` | Her bileşenin ısısından yağ akışı ve memeleri | TC50 |
| `lb_cooler.m` | Çapraz akışlı plaka-kanatçıklı soğutucu: UA, çekirdek boyutu, basınç kayıpları, kütle, fan gücü | TC51 |
| `run_step27.m` | Azami sürekli güçte sabit nokta, çalışma noktaları, pompalar, soğutucu taraması, karar 5 seçenekleri, tank, rüzgârla dönme; `summary.txt`, `jets.csv` ve Türkçe ve İngilizce iki grafiği `calc/results/step27/` içine yazar (commit edilmez) | — |
| `test_step27.m` | Sonuçları `tests/step27_test_cases.csv` ile karşılaştırır | Hepsi |

`tests/step27_test_cases.csv`, TC49–TC51'in beklenen değerlerini tutuyor: 55 satır, aynı biçim ve aynı %0,1 kuralı; değerler dişli geometrisini 2.4 ve 2.6'nın Python referanslarından alan ve kayıp formüllerini, meme düzenini ve soğutucu modelini yeniden kodlayan `calc/reference/step27_reference.py`'den geliyor. Depo kökünden:

```matlab
addpath('calc/lubrication', 'calc/agb_lube', 'calc/gear_detail', 'calc/shafts_bearings', 'calc/accessory');
test_step27              % 55 değer, 0 hata
S = run_step27();        % tam çalıştırma, yaklaşık 10 saniye
```

2.8 adımı, gövde ve planet sonlu eleman modelleri: hesap esasları Faz 2 raporunun 2.8 bölümünde. Araç MATLAB'ın PDE Toolbox'ı (ikinci dereceden dörtyüzlü elemanlarla doğrusal elastik statik ve modal analiz). RGB gövdesi kesitinden döndürülerek kuruluyor (flanş, halka dişliyi saran planet gövdesi, ön duvar, iki pervane rulman yuvasını taşıyan konik burun); DYN-05 için rulman yuvası direngenliği, planet kavrama bantlarına karşı modları (DYN-04) ve LD-05 sınır yükünde gerilmesi kontrol ediliyor; planet, yüklü makaraları üzerinde ve iki kavramasıyla, birinci kademe dişlisinin taslağı da 2.4'ün bıraktığı gövde kontrolü için 3B modelleniyor (DYN-04). Doğrulama çalıştırması sonuçlara ne kadar güvenilebileceğini gösteriyor: gerilme yığılması test problemi (delikli plaka), gövdenin ağ yakınsaması, flanş bağlantısında rijit ile cıvatalı bağlantı yayları arasındaki iki uç durum ve en yüklü köşelerin döküm yuvarlatmalı alt modelleri; yuvarlatmada tepe gerilme yakınsıyor, genel modelin keskin köşesinde yakınsamıyor. İlk kesit (düz ön duvar, silindirik burun) yuva direngenliği alt sınırını ve yuvarlatmalarla sınır yük gerilmesini sağlamadı; konik burun buradan çıktı. `calc/gear_detail/` ve `calc/shafts_bearings/` yolda olmalı; `calc/housing/` içinde:

| Dosya | Görev | Test |
| --- | --- | --- |
| `hs_inputs.m` | 2.8 adımının bütün girdi ve kabulleri: gövde kesiti, malzemeler, flanş bağlantısı, sınır yükler, ağlar, doğrulama ayarları | — |
| `hs_poly.m` | Dikdörtgen ve çokgenlerden kesit bölgesi | TC52 |
| `hs_revolve.m` | Döndürülmüş kesitin kapalı STL yüzeyi | TC52 |
| `hs_housing.m` | Gövde: kütle, yuva direngenliği, modlar, sınır yük gerilmesi; sabit ya da yaylı flanş | TC52 |
| `hs_planet3d.m` | 3B planet: serbest, yüklü makaraları üzerinde, iki kavramasıyla | TC54 |
| `hs_gear_web.m` | Birinci kademe dişlisinin 3B taslağı: gövdenin eksenel modları ve düğüm çapları (2.4'ün 2.8'e bıraktığı DYN-04 kontrolü) | — |
| `hs_bench_hole.m` | Yerel gerilme testi: çekmedeki delikli plaka | TC55 |
| `hs_section.m` | Döküm yuvarlatmalı kesit çizgisi, alt model penceresine kırpılmış | — |
| `hs_sector.m` | Genel modelin yüzeyleri üzerinde bir dilim boyunca döndürülmüş, kapaklı kesit | — |
| `hs_submodel.m` | Bir köşenin genel modelin yer değiştirmeleriyle sürülen yuvarlatmalı alt modeli | — |
| `hs_plot3d.m` | Şekil değiştirmiş ağ üzerinde bir alanın renk haritası | — |
| `hs_plot_sections.m` | İlk ve son gövde kesitini yan yana çizer | — |
| `run_step28.m` | İki gövde malzemesi, üç planet modeli ve birinci kademe dişlisinin gövdesi; `summary.txt`, mod grafiği ve 3B resimleri (gerilme, yuva çökmesi, mod şekilleri) Türkçe ve İngilizce olarak `calc/results/step28/` içine yazar (commit edilmez) | — |
| `run_step28v.m` | Doğrulama: test problemi, ağ yakınsaması, flanş uç durumları, yuvarlatmalı alt modeller, ilk kesit; `summary_verify.txt` ve grafiklerini yazar | — |
| `test_step28.m` | Sonuçları `tests/step28_test_cases.csv` ile karşılaştırır | Hepsi |

`tests/step28_test_cases.csv`, TC52–TC56'nın beklenen değerlerini tutuyor, her satırın kendi toleransı var: yüzeyli gövdenin tam hacmi (kesit parçaları üzerinden Pappus) %0,1 ile, konsol boru Euler-Bernoulli'ye ve serbest planet halkası Hoppe halkasına karşı birkaç yüzde ile, delikli plaka Heywood'un Howland çözümüne uydurmasına karşı (3B'de %3, 2B'de %1); değerler `calc/reference/step28_reference.py`'den geliyor. Depo kökünden:

```matlab
addpath('calc/housing', 'calc/gear_detail', 'calc/shafts_bearings');
test_step28              % 7 değer, 0 hata
S = run_step28();        % tam çalıştırma, yaklaşık 25 dakika (run_step28([], 'quick') betiği 3 dakikada dener)
V = run_step28v();       % doğrulama, run_step28'den sonra, yaklaşık 20 dakika
```

2.9 adımı, CATIA modelleri: `calc/cad_export/cx_export.m`, CATIA betiklerinin okuduğu tasarım değerlerini yazıyor (`cad/params/*.txt`: dişli verileri, delikler, çember kalınlıkları, taşıyıcı, yuvarlatma yaylarıyla gövde profili ve flanş delikleri); böylece modeller hesapları izliyor. Parça, montaj ve teknik resim VBScript betikleri `cad/scripts/` içinde (bkz. `cad/README.md`). Depo kökünden:

```matlab
addpath('calc/gear_detail', 'calc/shafts_bearings', 'calc/accessory', 'calc/housing', 'calc/cad_export');
cx_export();             % cad/params/*.txt
```

2.10 adımı, durum izleme (Hamit'in 7. kararı = C, bakım odaklı tasarım): hesap esasları Faz 2 raporunun 2.10 bölümünde. Bir sağlık ve kullanım izleme sisteminin (HUMS) RGB titreşiminde aradığı karakteristik frekansları veriyor: her milin hızı, kavrama frekansları, planet kademesinin yerel dişli hatası frekansları ve on bir rulmanın kafes, bilezik ve yuvarlanma elemanı frekansları, %100 hızda ve SYS-03'ün kararlı hız aralığında. Farklı bileşenlerin birbirine %2'den yakın çizgilerini listeliyor (spektrum bunları ayıramadığı için zaman eşzamanlı ortalama gerekiyor) ve 2.8 gövdesi üzerindeki ivmeölçer yerlerini pervane rulman yuvalarından ve halka dişli yuvasından gövde yüzeyine statik aktarım esnekliğine göre sıralıyor (CTL-03). `calc/housing/`, `calc/gear_detail/`, `calc/shafts_bearings/` ve `calc/accessory/` yolda olmalı; `calc/hums/` içinde:

| Dosya | Görev | Test |
| --- | --- | --- |
| `hm_frequencies.m` | Verilen hızda mil, kavrama, yerel dişli hatası ve rulman frekansları | TC57–TC59 |
| `hm_sensors.m` | Her kaynaktan gövdenin dış yüzeyine statik aktarım esnekliği (PDE Toolbox) | — |
| `run_step210.m` | %90, %100 ve %101 hızda frekans tablosu, yakın çiftler, ivmeölçer yerleri; `summary.txt`, `fault_frequencies.csv` ve Türkçe ve İngilizce iki grafiği `calc/results/step210/` içine yazar (commit edilmez) | — |
| `test_step210.m` | Sonuçları `tests/step210_test_cases.csv` ile karşılaştırır | Hepsi |

`tests/step210_test_cases.csv`, TC57–TC59'un beklenen değerlerini tutuyor: 59 satır, aynı biçim ve aynı %0,1 kuralı; değerler kinematiği ve rulman formüllerini tasarım verilerinden yeniden kodlayan `calc/reference/step210_reference.py`'den geliyor (yalnız standart kütüphane). Depo kökünden:

```matlab
addpath('calc/hums', 'calc/housing', 'calc/gear_detail', 'calc/shafts_bearings', 'calc/accessory');
test_step210             % 59 değer, 0 hata
R = run_step210();       % tam çalıştırma, yaklaşık 2 dakika
```

Adım 3.1, tam model (Faz 3): esaslar Faz 3 raporunun 3.1 bölümünde. Araç, Faz 2'nin dışarıda bıraktığı parçaları yerleştiriyor ve `cx_export` üzerinden CATIA'ya yazıyor: kaçık dişli çiftini saran birinci kademe gövdesi, ara mil ve güneş quill'i, yerleşim kurallarına göre seçilen açılarda aksesuar tahrikleri (kartuşta jeneratör dişli-mili, pervane tarafı yüzünde OSG dişlisi, motor tarafındaki kapakta PCU dişlisi ve pompa paketi), rulman, somun ve keçe zarfları, pervane dört noktadan temaslı rulmanının titanyum burun yuvası, tutma borusu, yer tutucu pervane flanşı (PIF-01 TBD) ve üç modüllü montajın örnek listesi. Hafifletilmiş taşıyıcı plakayı düzlem gerilmede kontrol ediyor ve CATIA hacimlerini SYS-06 kütlesine topluyor. `calc/gear_detail/`, `calc/shafts_bearings/` ve `calc/accessory/` yolda olmalı; `calc/assembly/` içinde:

| Dosya | Görev | Test |
| --- | --- | --- |
| `as_inputs.m` | 3.1'in bütün girdileri ve varsayımları (TBD arayüz değerleri işaretli) | — |
| `as_geom.m` | Faz 2 tasarımlarından dişli uçları, eksen aralıkları, rulman zarfları ve dış hat yarıçapları | — |
| `as_hull.m` | Çemberlerin konveks örtüsü, teğet doğrular ve yaylar olarak (gövde dış hatları) | TC60 |
| `as_angles.m` | Jeneratör, OSG ve PCU açıları: yerleşim payları, en hafif gövde ve kapak | TC62 |
| `as_layout.m` | Eksenel konumlar, parça profilleri, gövde göbek ve cepleri, dişli fazları, örnekler | TC61, TC63 |
| `as_carrier.m` | Taşıyıcı ön plakası, düz ya da hafifletilmiş, düzlem gerilme; halka kıyas testi | TC64 |
| `as_mass.m` | `cad/assy/part_volumes.csv`'den SYS-06'ya karşı kütle toplaması ve SYS-11'e karşı giriş tahriki (PT çıkış mili, kaplinler, tünel) | TC65, TC66 |
| `as_lighten.m` | Diğer kütle seçenekleri (WE43 dökümler, titanyum pervane mili bölümü) | — |
| `as_export.m` | Yeni parçaların ve montajın `cad/params` dosyaları (`cx_export` çağırır) | — |
| `run_step31.m` | Konumlar, açılar ve paylar, taşıyıcı kontrolü, çakışma özeti, kütle tablosu; Türkçe ve İngilizce üç grafiği `calc/results/step31/` içine yazar (commit edilmez) | — |
| `test_step31.m` | Sonuçları `tests/step31_test_cases.csv` ile karşılaştırır | Hepsi |

`tests/step31_test_cases.csv`, TC60–TC66'nın beklenen değerlerini tutuyor: her biri kendi toleransıyla 74 satır; değerler geometriyi ve toplamayı yeniden kodlayan, CATIA hacimlerini dışa aktarılan profillere göre kontrol eden `calc/reference/step31_reference.py`'den geliyor (numpy, scipy). Önce CATIA parçaları kurulur (`cad/README.md`), sonra depo kökünden:

```matlab
addpath('calc/assembly', 'calc/gear_detail', 'calc/shafts_bearings', 'calc/accessory');
test_step31              % 78 değer, 0 hata
S = run_step31();        % yaklaşık 1 dakika
```

Adım 3.2, yağ sistemi donanımı ve hidrolik ağ: esaslar Faz 3 raporunun 3.2 bölümünde. Araç yağ sistemini 3.1 yerleşimi üzerinde yönlendiriyor (düzenleme ve termostatik valfli, filtreli manifold; gövdelerin çevresinden dış borular; 32 memeye delikler; PIF-02'nin hatve yağını da taşıyan iki oluklu taşıyıcı transfer manşonu), ağı azami sürekli güçte, yer rölantisinde ve -40 °C ilk çalışmada çözüyor, pompa girişini 45.000 ft'te ve -1,27 g'de, yağsız çalışmayı (LUB-07) Hamit'in kararındaki acil hava-yağ sisi sistemiyle kontrol ediyor, yağ donanımını ve sis sistemini SYS-06 için tartıyor ve hepsini CATIA için yazıyor. `calc/assembly/`, `calc/lubrication/`, `calc/agb_lube/`, `calc/gear_detail/`, `calc/shafts_bearings/` ve `calc/accessory/` yolda olmalı, 3.1'in CATIA hacimleri hazır olmalı; dosyalar `calc/oil_system/` içinde (`os_inputs`, `os_oil`, `os_network`, `os_solve`, `os_coldstart`, `os_inlet`, `os_lub07`, `os_mist`, `os_lubmass`, `os_export`, `os_schematic`, `run_step32`, `test_step32`).

`tests/step32_test_cases.csv`, TC67–TC73'ün beklenen değerlerini tutuyor: her biri kendi toleransıyla 81 satır; değerler ağı `cad/params/oil_network.txt`'den okuyup yeniden çözen `calc/reference/step32_reference.py`'den geliyor (numpy, scipy). Depo kökünden:

```matlab
addpath('calc/oil_system', 'calc/assembly', 'calc/lubrication', 'calc/agb_lube', 'calc/gear_detail', 'calc/shafts_bearings', 'calc/accessory');
S = run_step32();        % yaklaşık 2 dakika
test_step32              % 81 değer, 0 hata
```

Adım 3.3, arayüzler: esaslar Faz 3 raporunun 3.3 bölümünde. Arayüz kontrol belgesi `requirements/icd_v1.csv` (`requirements/make_icd.py` yazar); `calc/interfaces/` duyarlılık sütununun sayılarını veriyor. `if_override.m`, 2.2, 2.5, 2.6, 2.7, 3.1 ve 3.2 adımlarının girdi fonksiyonlarının geçici bir değişiklik almasını sağlıyor (fonksiyonlar korumalı bir çağrıyla bitiyor; `calc/interfaces` yolda değilse hiçbir şey değişmiyor); `if_sens.m` her arayüz değerini oynatıp onu kullanan aracı yeniden çalıştırıyor ya da ilişki doğrudansa kapalı formu kullanıyor; `run_step33.m`, `requirements/icd_sensitivity_v1.csv` dosyasını ve pay grafiklerini yazıyor; `test_step33.m` 44 kapalı form değerini `calc/reference/step33_reference.py` ile karşılaştırıyor (`tests/step33_test_cases.csv`). Depo kökünden: `T = run_step33();` (yaklaşık 3 dakika), `test_step33` (44 değer, 0 hata). `run_oilgrade.m`, Hamit'in yağ kararının (yalnız MIL-PRF-23699; 2.4 Karar 2A'nın yerine, `requirements/changes_phase3.csv`) dayanağı: iki yağ için 60, 100 ve 132 °C yağ girişinde S_S, film oranı ve her rulmanın ISO 281 görev ömrü, ayrıca 2.7 soğutucusu ve 60 °C termostatik valfle sıcak ve soğuk günde RGB yağ girişi; `calc/interfaces/oil_grade_check.csv` dosyasını yazıyor.

Adım 3.4, malzemeler, prosesler ve malzeme listesi: esaslar Faz 3 raporunun 3.4 bölümünde. Metin tabloları (malzemeler, prosesler, rotalar, bileşenler) `manufacturing/` klasöründe (`manufacturing/make_mfg.py`); sayılarını `calc/manufacturing/` veriyor: `mf_casedepth.m` diş yüzleri ve planet rulmanı yolları için Hertz yarı genişliği, en büyük kayma gerilmesi derinliği ve gereken sementasyon derinliği (TC80); `mf_film.m` yüzey bitirmesine karşı film oranı (TC83); `mf_fasteners.m` 3.1'deki %5 paya karşı alttan bağlantı elemanı kütlesi (TC81); `mf_liners.m` çelik yuva gömlekleri (TC82); `mf_bom.m` malzeme listesi (TC84); `run_step34.m` tam çalıştırma, `manufacturing/bom_v1.csv` dosyasını yazar. Depo kökünden: `S = run_step34();` (run_step32'den sonra), `test_step34` (40 değer, 0 hata).

Adım 3.5, 3-B yapısal analiz: esaslar Faz 3 raporunun 3.5 bölümünde. Planet gövdesi, birinci kademe gövdesi ve pervane milli taşıyıcı CATIA STEP dosyalarından (`cad/step/case.stp`, `fs_case.stp`, `carrier.stp`) PDE Toolbox `femodel` ile ağlanıyor (ikinci derece dörtyüzlüler). `st_loads.m` yükler (TC85); `st_liners.m` A357 içindeki çelik yuva gömlekleri, −40 ile 149 °C arası Lamé sıkı geçmesi (TC86); `st_bolts.m` VDI 2230 Kısım 1: flanş 30 x M6 ve bağlantı halkası 12 x M8/M10, pimler (TC87, TC88); `st_case3d.m` gövde: yuva direngenliği, döküm katsayısıyla sınır gerilme, −40 °C gömlekler, 1P yorulması, halka yuvası burulması; `st_carrier3d.m` taşıyıcı: MCT'de burulma, LD-01 ve LD-08 gerilmeleri, ayrı M50NiL pimlerin pres geçmesi (TC89); `st_fscase3d.m` birinci kademe gövdesi, PT eksenindeki bağlantı halkasında ya da planet gövdesi flanşında tutulmuş (TC91); `st_khb.m` ek eksen kaçıklığıyla K_Hbeta kontrolü; `st_liner_fix.m` NU1024 gömleği için kalın göbek ya da düşük tutma sıcaklığı (TC92); `st_mass.m` Hamit'in kartı için SYS-06 kütle kapatma seçenekleri (TC90); sonlu eleman modellerinin kütlesi CATIA'ya karşı (TC91). Depo kökünden: `S = run_step35();` (yaklaşık 30 dakika, run_step34'ten sonra), `test_step35` (60 değer, 0 hata).


Adım 3.6, dinamik: esaslar Faz 3 raporunun 3.6 bölümünde. Kavrama uyarımına zorlanmış cevap (DYN-03, DYN-04), birinci kademe dişlisinin sönüm halkası ve Campbell diyagramları. Planet, makaraları ve kavramaları üzerinde 3-B PDE Toolbox modeli (tam yay tensörleri); birinci kademe dişli gövdesi ve planet gövdesi eksenel simetrik harmonik modeller; birinci kademe gövdesi kaba bir 3-B model. `calc/gear_detail/`, `calc/shafts_bearings/`, `calc/housing/` ve `calc/structures/` yolda olmalı; dosyalar `calc/dynamics/` içinde: `dy_inputs` girdiler; `dy_axi_mesh`, `dy_axi_km`, `dy_axi_ring` harmonik eleman (TC95); `dy_planet_frf`, `dy_face_weights`, `dy_tet10_stress`, `dy_planet_forces` planet modları, dinamik diş kuvvetleri, K_v,FE ve S_F (TC93, TC99); `dy_shuttle` helisel kavramanın eksenel mekiği (TC93); `dy_web`, `dy_ring`, `dy_web_check3d` birinci kademe dişli gövdesi ve sürtünmeli sönüm halkası (TC94, TC96, TC97); `dy_case_frf`, `dy_ring_couple`, `dy_couple_check`, `dy_pass_amp`, `dy_case_stage` planetlere bağlı planet gövdesi, kayar temas / bağlı jant / kütle katmanı senaryoları, sabit ve planet geçişi alanları, A357 düğümlerinde Goodman (TC98, TC99); `dy_fscase_frf`, `dy_fscase_stage` birinci kademe gövdesi (TC98); `dy_vm_cycle` çevrim maksimumu von Mises (TC99); `dy_ring_export`, `dy_plots` CATIA için oluk ve halka verileri ve grafikler; `run_step36` tam çalıştırma (yaklaşık 70 dakika), `run_step36_case` gövde aşamalarını kayıtlı step36.mat üzerinde yeniden çalıştırır. Depo kökünden: `S = run_step36();`, `test_step36` (201 değer, 0 hata; eksik değer hata sayılır).

Adım 3.7, emniyet: esaslar Faz 3 raporunun 3.7 bölümünde. Pervanenin ayrılmasının (SAF-01, CS-E 510) ve FMEA'nın gösterdiği iki çift hatanın hata ağaçları, RGB ve yağ sisteminin FMEA'sı, kritik parçalar (SAF-02, CS-E 515) ve yüzey hasar toleransları (EASA CM-PIFS-007), yağla ıslanan gövdelerin yangın değerlendirmesi (SAF-05, CS-E 130). Yalnız temel MATLAB; tablolar `safety/` klasörüne. Dosyalar `calc/safety/` içinde: `sf_inputs` girdiler (varsayılan değerler kaynaklarıyla TBR); `sf_qj` QJ1024 eksenel kayıp takibi (TC118); `sf_fta`, `sf_cutset`, `sf_lip`, `sf_plot_fta` pervanenin ayrılması, Uçuşa Elverişlilik Sınırlamaları maddeleri, hasar sonrası tutma tüpü, burun kapağı P116 ve dudak sürtünmesi, E7 yağ kaybı evreleri (TC100, TC114); `sf_coupling` diyafram kavrama seçenekleri (TC117); `sf_protect` mil kopması ve yük kaybı koruma kapsaması (TC115); `sf_fta2`, `sf_plot_fta2` PT aşırı devri ve pervane aşırı devir korumasının kaybı (TC105); `sf_fmea`, `sf_plot_fmea` FMEA kontrolleri (gizli her satır için KTT görevi, kritik parçalar türetilen küme artı karar gereği tutulanlar dahil), özetleri ve büyük etki oranları (TC101); `sf_nr`, `sf_nr_check` Newman-Raju K ve yayımlanmış FE değerleriyle kontrolü (TC102, TC103); `sf_locations`, `sf_dt`, `sf_dt_all`, `sf_plot_dt` on iki kritik konumda sabit düzlemde hasar toleransı, boydan boya çatlaklar ve gömülü kusur (TC103); `sf_dt_design`, `sf_plot_dt_design` P103 dişi seçenekleri, taşıyıcı çıkıntıları ve 1P momenti duyarlılığı (TC113); `sf_parts` kritik parça listesi (TC104); `sf_fire`, `sf_fire_all`, `sf_fire_joint`, `sf_plot_fire` yangın: sıfır yağ debisine süre, standart alevde silindirik 1-B duvarlar ve 2-B P101 / F201 birleşimi (TC106); `run_step37` tam çalıştırma (yaklaşık 1 dakika). Depo kökünden: `S = run_step37();`, `test_step37` (416 değer, 0 hata; eksik değer hata sayılır).

Adım 3.8, toleranslar ve geçmeler: esaslar Faz 3 raporunun 3.8 bölümünde. Resim standardı ASME Y14.5-2018 (metrik), ISO 286 geçmeleri, ISO 1328-1:2013 dişli doğruluğu ve ISO 4156 kamalar. Referanslar ve geometrik toleranslar, sıcaklık haritası, diş boşluğu, yük paylaşımı ve eksenel zincirler (en kötü durum ve toleranslar +-3 sigma alınarak Monte Carlo), sıcaklıkta geçmeler, kama geçmeleri ve dişli sınıfları; tablolar `manufacturing/` klasörüne. Temel MATLAB, `calc/gear_detail/` yolda. Dosyalar `calc/tolerances/` içinde: `tl_inputs` girdiler; `tl_iso286` ISO 286-1 sınır sapmaları (TC109); `tl_thermal`, `tl_plot_thermal` sıcaklık haritası (TC107); `tl_gears` dişli doğruluğu (TC108); `tl_datums` referanslar ve geometrik toleranslar; `tl_backlash`, `tl_kgamma`, `tl_axial`, `tl_lame`, `tl_plot_stack` zincirler (TC110); `tl_fits`, `tl_plot_fits` sıcaklıkta geçmeler (TC111); `tl_splines` kama geçmeleri (TC112); `tl_drawing_table` 3.9 resimleri için tolerans ve geçme tablosu (TC112); `run_step38` tam çalıştırma (yaklaşık 10 saniye). Depo kökünden: `S = run_step38();`, `test_step38` (187 değer, 0 hata; eksik değer hata sayılır).

Adım 3.10, bakım gösterimi ve HUMS göstergeleri: esaslar Faz 3 raporunun 3.10 bölümünde. Halka dişlinin üstündeki ivmeölçerin sentetik sinyali (sağlam, çatlak güneş dişi, oyuklu planet iç bileziği) motor testinin yerini tutuyor; üzerinde güneşin taşıyıcıya göre zaman eşzamanlı ortalaması, FM4, NA4, yan bant enerjisi ve bir zarf göstergesi hesaplanıyor, dikkat ve alarm eşikleri sağlam bir temel kayıt kümesinden kuruluyor (CTL-03). `hm_access.m` iki boroskop deliğinden kavramalara görüş hattını STL olarak dışa aktarılan CATIA parçaları üzerinde kontrol ediyor (MNT-02); modül söküm animasyonu `cad/anim/rgb_anim.m` içindeki `removal` kipi, görev tablosu `maintenance/` klasöründe. `calc/gear_detail/`, `calc/shafts_bearings/` ve `calc/accessory/` yolda olmalı; dosyalar `calc/hums/` içinde: `hm_inputs` sinyal modeli ve hata büyüklükleri (varsayımlar TBR); `hm_synth` sentetik sinyal (TC119); `hm_tsa` takometreyle açısal yeniden örnekleyerek zaman eşzamanlı ortalama (TC120); `hm_indicators` FM4, NA4, yan bant enerjisi ve zarf göstergesi ENV (TC120); `hm_threshold` log-normal dikkat ve alarm eşikleri (TC121); `hm_access` boroskop görüş hattı; `run_step310` tam çalıştırma (yaklaşık 20 saniye), `maintenance/hums_thresholds_v1.csv` dosyasını yazar. Depo kökünden: `R = run_step310();`, `test_step310` (13 değer, 0 hata).
