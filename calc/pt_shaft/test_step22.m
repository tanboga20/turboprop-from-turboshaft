% TEST_STEP22  Compares the step 2.2 tool with calc/tests/step22_test_cases.csv.
%   Run from the repo root:  addpath('calc/pt_shaft', 'calc/rotor_damper');  test_step22
%   Expected values come from an independent Python implementation
%   (calc/reference/step22_reference.py), which solves the diaphragm plate problems with a
%   boundary value solver instead of the closed form used here. Same 0.1% rule as before.

T = readtable('calc/tests/step22_test_cases.csv', 'TextType', 'string');
in = ptshaft_inputs();
res = struct();

% TC24: floating shaft 60 x 2 mm, 0.55 m, k_theta 50 N m/rad, M_bend 0.5 N m
s = tube_shaft(0.060, 0.002, 0.55, in, 50, 0.5);
res.TC24 = struct('tau_MC', s.tau_MC, 'tau_lim', s.tau_lim, 'twist_100', s.twist_100, ...
                  'n_buck', s.n_buck, 'n_f', s.n_f, 'n_cr', s.n_cr);
in_ss = in;  in_ss.k_rad = 1e15;  in_ss.m_half = 0;
res.TC24.n_ss = tube_shaft(0.060, 0.002, 0.55, in_ss, 0, 0).n_cr;

% TC25: flat diaphragm a 65 mm, b 32.5 mm, t 1.0 mm
p = annular_plate(0.065, 0.0325, 0.0010, in.dia.E, in.dia.nu);
res.TC25 = struct('k_ax', p.k_ax, 's_ax', p.s_ax, 'k_th', p.k_th, 's_th', p.s_th);
res.TC25.k_ax_point_load = annular_plate(0.065, 0.065e-3, 0.0010, in.dia.E, in.dia.nu).k_ax;

% TC26: the same diaphragm with the step 2.2 loads at 100% speed
c = diaphragm(0.065, 0.0325, 0.0010, in, in.n_PT);
res.TC26 = struct('n_f', c.n_f, 'n_static', c.n_static, 'n_burst', c.n_burst, 'n_buck', c.n_buck, ...
                  'F_ax', c.F_ax, 'M_mis', c.M_mis);

% TC27: torque meter on the TC24 shaft
tm = torque_meter(s, in);
res.TC27 = struct('twist_100', tm.twist_100, 'res', tm.res, 'err_res', tm.err_res);

% TC28: PT rear bearing with the TC26 coupling moment over an 80 mm stub
rb = rear_bearing(in, c.M_mis / 0.08);
res.TC28 = struct('P', rb.P, 'P_lim', rb.P_lim, 'L10', rb.L10, 'F_rm', rb.F_rm);

% TC29: shaft tunnel, 60 mm shaft, 0.55 m, 7.5 g/s, gas 700 degC
th = tunnel_thermal(0.060, 0.55, 0.0075, 700, in);
res.TC29 = struct('T_air_out', th.T_air_out, 'T_shaft_max', th.T_shaft_max, 'Q_in', th.Q_in, ...
                  'P_wind', th.P_wind);

% Compare
nfail = 0;
nmiss = 0;
for i = 1:height(T)
    tc = char(T.tc(i));
    q = char(T.quantity(i));
    if ~isfield(res, tc) || ~isfield(res.(tc), q)
        fprintf('MISSING %s %s\n', tc, q);
        nmiss = nmiss + 1;
        continue
    end
    v = res.(tc).(q);
    e = T.expected(i);
    ok = abs(v / e - 1) <= 1e-3;
    verdict = 'PASS';
    if ~ok
        nfail = nfail + 1;
        verdict = 'FAIL';
    end
    fprintf('%-5s %-16s %14.6g %14.6g %9.4f%%  %s\n', tc, q, v, e, 100 * (v / e - 1), verdict);
end
fprintf('%d values, %d failures, %d missing\n', height(T), nfail, nmiss);
