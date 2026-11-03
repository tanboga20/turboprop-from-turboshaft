% TEST_STEP31  Compares the step 3.1 tool with calc/tests/step31_test_cases.csv.
%   Run from the repo root after the CATIA parts are built (cad/assy/part_volumes.csv):
%     addpath('calc/assembly', 'calc/gear_detail', 'calc/shafts_bearings', 'calc/accessory');  test_step31
%   Expected values come from an independent Python implementation
%   (calc/reference/step31_reference.py): hulls of circles, axial stations,
%   packaging margins and the mass proxy at the chosen angles, gear phases,
%   the carrier plate benchmark and scallops, the CATIA volumes against the
%   exported profiles, and the mass roll-up. Each row carries its own
%   relative tolerance.

T = readtable('calc/tests/step31_test_cases.csv', 'TextType', 'string');
in = as_inputs();
gi = gd_inputs();  ad = ad_inputs();  sb = sb_inputs();
G = as_geom(in, gi, ad, sb);
L = as_layout(in, G, gi, ad, sb);
a = L.ang;
res = struct();

% TC60: hulls
H = as_hull([0 0 10; 30 0 5]);
res.TC60 = struct('two_area', H.area, 'two_perim', H.perim, 'fs_area', L.fs.out.area, 'fs_perim', L.fs.out.perim, ...
                  'cov_area', L.cov.out.area, 'cov_perim', L.cov.out.perim);

% TC61: axial stations
z = L.z;
res.TC61 = struct('z_bf', z.bf, 'z_c', z.c, 'z_br', z.br, 'z_qj_mid', z.qj_mid(1), 'z_nut_pt', z.nut_pt(1), ...
                  'z_wr', z.wr, 'z_rear', z.rear, 'z_cov', z.cov(1), 'z_pcu', z.pcu, 'z_gen', z.gen, 'z_osg', z.osg);

% TC62: margins at the chosen angles and the mass proxies
mg = containers.Map(a.margin(:, 1), a.margin(:, 2));
res.TC62 = struct('theta_g', a.theta_g, 'gen_tip_pin', mg('gen gear tip to pinion tip'), ...
                  'gen_unit_tunnel', mg('generator unit to PT tunnel keep-out'), ...
                  'osg_unit_flange', mg('OSG unit to planetary case flange'), ...
                  'osg_tip_gear2', mg('OSG gear tip to first-stage gear tip'), ...
                  'gen_unit_cover', mg('generator unit to accessory cover'), ...
                  'gen_unit_pcu_unit', mg('generator unit to PCU unit'), ...
                  'pcu_unit_tunnel', mg('PCU unit to PT tunnel keep-out'), ...
                  'cover_tunnel', mg('accessory cover to PT tunnel keep-out'), ...
                  'm_fs_proxy', a.m_fs, 'm_cov_proxy', a.m_cov);

% TC63: gear phases
pin = L.inst.rot(strcmp(L.inst.part, 'pinion'));
res.TC63 = struct('rot_gen', L.rot.gen, 'rot_osg', L.rot.osg, ...
                  'rot_pcu', L.rot.pcu, 'rot_pinion', pin(1));

% TC64: carrier plate
B = as_carrier(in, gi, 'bench');
C = as_carrier(in, gi, true);
res.TC64 = struct('bench_u_mm', B.u_fe, 'A_scallop', C.A_scallop, 'm_saved', C.m_saved, 'T_MCT', C.T_MCT);

% TC65: CATIA volumes
vol = readtable('cad/assy/part_volumes.csv', 'TextType', 'string');
vm = containers.Map(cellstr(vol.part), num2cell(vol.volume_mm3));
for k = 1:numel(L.rev)
    nm = L.rev(k).name;
    if isempty(L.rev(k).teeth) && isempty(L.rev(k).holes) && isKey(vm, nm)
        res.TC65.(['V_' nm]) = vm(nm);
    end
end
res.TC65.V_acc_cover = vm('acc_cover');

% TC66: mass roll-up
% with the step 3.2 lines (weighed oil hardware, LUB-07 mist system) when run_step32 has written them
X = struct('lub_hw', 0, 'mist', 0);
fn = fullfile('cad', 'params', 'oil_network.txt');
if exist(fn, 'file')
    pn = LoadKV(fn);
    X = struct('lub_hw', pn.m_lub_hw, 'mist', pn.m_mist);
end
M = as_mass(in, L, vol, X);
res.TC66 = struct('m_planetary', M.module.planetary, 'm_first_stage', M.module.first_stage, ...
                  'm_accessories', M.module.accessories, 'modelled', M.modelled, 'allowances', M.allowances, ...
                  'total', M.total, 'margin', M.margin, 'margin_110', M.margin_tbr, ...
                  'tunnel', M.tunnel, 'drive', M.drive, 'margin_drive', M.margin_drive, 'total_with_drive', M.total_with_drive);

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
    ok = abs(v / e - 1) <= T.tol(i);
    verdict = 'PASS';
    if ~ok
        nfail = nfail + 1;
        verdict = 'FAIL';
    end
    fprintf('%-5s %-22s %14.6g %14.6g %8.3f%% (tol %.1f%%)  %s\n', tc, q, v, e, 100 * (v / e - 1), 100 * T.tol(i), verdict);
end
fprintf('%d values, %d failures, %d missing\n', height(T), nfail, nmiss);

function s = LoadKV(fn)
% numeric key = value lines of a cad/params file
s = struct();
for line = splitlines(string(fileread(fn)))'
    t = strtrim(line);
    if t == "" || startsWith(t, "#") || ~contains(t, "="), continue, end
    kv = split(t, "=");
    k = matlab.lang.makeValidName(strtrim(kv(1)));
    v = str2double(split(strtrim(kv(2))));
    if all(~isnan(v)), s.(k) = v(1); end
end
end
