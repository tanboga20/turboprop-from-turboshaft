function G = sf_fta2(in)
%SF_FTA2  Dual-failure trees (D1b): (a) PT overspeed, (b) hazardous propeller effect; allowances and sensitivity.
%   G = sf_fta2(in)   in = sf_inputs
%
%   Rule (AC 33.75-1A 8.c(1)): each cut set (individual failure) at most in.target_h per hour, and the sum of all
%   hazardous effects (D1 plus D1b) at most in.ft.band. Each allowance comes from its own cut set (no shared budget).
%   A protection element is unavailable with the mean lambda T / 2 + q_d over its check interval T (latent failures
%   found by the check, q_d the failure on demand).
%   (a) PT overspeed (uncontained PT disc): a break anywhere in the drive chain that the G2 coverage table protects
%       (lam_break: 1e-6 per hour for a non-critical structural element, 1e-7 for a CS-E 515 part) AND a failure of
%       the protection channel: both probes of a speed pair lost (1-out-of-2: ((1 - beta) lambda T)^2 / 3 + beta lambda
%       T / 2 per pair, n_ch pairs), the fuel shut-off valve or the logic
%       (lambda T / 2 + q_d), the whole channel checked at each start (14 CFR 33.28(f)(2): T one A-05 mission).
%       Allowance of each protection element: target / lam_break. Spurious trips (in-flight shutdown): the pickups
%       with a false confirming cue, against an aircraft-side allowance (TBR).
%   (b) Hazardous propeller effect: excessive drag, or overspeed leading to blade release or excessive unbalance
%       (14 CFR 35.15(g)(1); AC 33.75-1A 19.g(2) for unintended travel below the in-flight low-pitch position).
%       Initiators: PCU fail-to-fine with its drive and pump intact; a break downstream of the take-offs (the
%       propeller decoupled from the PCU and the OSG, which stay on the PT side: no OSG credit); a lube-to-pitch
%       cross-leak at L403 (drives the pitch fine against the PCU: no OSG credit); a blockage of L403 / L404 (pitch
%       frozen: excessive drag only with a later in-flight shutdown in the mission); the common cause of the PCU and
%       OSG drives (gear 2 web FM05 and the F204 stub FM63). Layers: OSG (internal and drive latent rates, test
%       solenoid), in-flight low-pitch stop, FADEC feather command (tested at each start), counterweight feathering
%       (checked at each shutdown). Cut sets with layers checked at different intervals take the product of their
%       mean unavailabilities. The layers handed to the propeller maker (low-pitch stop, counterweight feathering)
%       are evaluated at their allowances, each from its own cut set; the common-cause set at its allowance. The OSG
%       test interval is derived from its own cut set.
%   G.Ta, G.Tb: cut-set tables; G.allow: allowances; G.sens: one-at-a-time x10 sensitivity.
%   Source: Phase 3 report, Section 3.7 (D1b).

G = evaluate(in.ft2, in.target_h);
G.sum_D1b = G.sum_a + G.sum_b;
% sensitivity: each rate and demand term x10, one at a time
sv = in.ft2.sens;
rows = {};
for k = 1:numel(sv)
    p = in.ft2;  f = sv{k};
    v = getfield(p, f{:});
    if iscell(v), v(:, 2) = num2cell(10 * [v{:, 2}]'); else, v = 10 * v; end
    p = setfield(p, f{:}, v);
    H = evaluate(p, in.target_h);
    rows(end + 1, :) = {string([strjoin(f, '.') ' x10']), max(H.Ta.P_per_h), H.sum_a, max(H.Tb.P_per_h), ...
        H.sum_b, H.allow.q_p, H.allow.q_lps, H.allow.T_lps, H.allow.q_cw, H.allow.T_osg, H.allow.T_osg_noFF}; %#ok<AGROW>
end
G.sens = cell2table(rows, 'VariableNames', {'case', 'P_max_a', 'sum_a', 'P_max_b', 'sum_b', 'q_p_allow', ...
    'q_lps_allow', 'T_lps_allow_h', 'q_cw_allow', 'T_osg_allow_h', 'T_osg_allow_noFF_h'});
G.range = struct('q_p', [min(G.sens.q_p_allow), G.allow.q_p], 'q_lps', [min(G.sens.q_lps_allow), G.allow.q_lps], ...
    'T_lps', [min(G.sens.T_lps_allow_h), G.allow.T_lps], 'q_cw', [min(G.sens.q_cw_allow), G.allow.q_cw], ...
    'T_osg', [min(G.sens.T_osg_allow_h), G.allow.T_osg], 'T_osg_noFF', [min(G.sens.T_osg_allow_noFF_h), G.allow.T_osg_noFF]);
end

function G = evaluate(p, tgt)
q = @(x) x.lam * x.T / 2 + x.qd;                          % mean unavailability of a checked element
a = p.a;  b = p.b;
% (a) PT overspeed
lb = sum([a.rows{:, 2}]);
lt = a.ch.lam * a.ch.T;
q_ch = a.n_ch * (((1 - a.beta) * lt)^2 / 3 + a.beta * lt / 2) + a.ch.qd;   % 1-out-of-2 pairs with a common cause
Pa = lb * [q_ch; q(a.valve); q(a.logic)];
G.lam_break = lb;
G.q_ch = q_ch;  G.q_valve = q(a.valve);  G.q_logic = q(a.logic);
G.Ta = table(["drive-chain break AND both probes of a protection speed pair lost (1-out-of-2, common cause beta)"; ...
              "drive-chain break AND the fuel shut-off valve fails (latent or on demand)"; ...
              "drive-chain break AND the detection logic fails (latent or on demand)"], ...
             ["tahrik zinciri kopması VE bir koruma hız çiftinin iki algılayıcısı da kayıp (2'den 1, ortak neden beta)"; ...
              "tahrik zinciri kopması VE yakıt kesme vanası arızalı (gizli veya talepte)"; ...
              "tahrik zinciri kopması VE algılama mantığı arızalı (gizli veya talepte)"], Pa, ...
             ["protection channel (pickups) of the FADEC"; "fuel shut-off valve"; "FADEC protection logic"], ...
             'VariableNames', {'cut_set_en', 'cut_set_tr', 'P_per_h', 'credits'});
G.sum_a = sum(Pa);
G.spurious = a.n_probe * a.ch.lam * a.p_false;
G.spurious_ok = G.spurious <= a.spur_allow;
% (b) hazardous propeller effect: layers
q_osg = (b.osg.lam + b.osg.lam_drive) * b.osg.T / 2 + b.osg.qd;
q_ff = q(b.ff);
q_ifsd = b.ifsd.lam * b.ifsd.T / 2;
l_down = sum([b.down{:, 2}]);  l_cc = sum([b.cc{:, 2}]);
% allowances, each from its own cut set
A.q_lps = tgt / max(b.fine.lam, b.cross.lam);             % fine-ward initiators with the low-pitch stop alone
A.T_lps = max(0, 2 * (A.q_lps - b.lps.qd) / b.lps.lam);   % 0: the demand failure alone reaches the allowance
A.q_cw = tgt / l_down;                                    % decoupled propeller with the feathering alone
A.T_cw = max(0, 2 * (A.q_cw - b.cw.qd) / b.cw.lam);
A.q_cc = tgt / l_cc;                                      % common cause with the feathering alone
A.q_osg = tgt / (b.fine.lam * q_ff);                      % PCU fail-to-fine with the OSG and the FADEC feather
A.T_osg = max(0, 2 * (A.q_osg - b.osg.qd) / (b.osg.lam + b.osg.lam_drive));
A.q_osg_noFF = tgt / b.fine.lam;                          % the same without the FADEC feather credit
A.T_osg_noFF = max(0, 2 * (A.q_osg_noFF - b.osg.qd) / (b.osg.lam + b.osg.lam_drive));
A.q_p = tgt / lb;
G.allow = A;
q_lps = min(A.q_lps, q(b.lps));  q_cw = min([A.q_cw, A.q_cc, q(b.cw)]);   % at the allowance or the actual, the lower
cut = {"PCU fail-to-fine AND the OSG fails AND the FADEC feather command fails", "PCU fail-to-fine VE OSG arızalı VE FADEC tüyleme komutu arızalı", ...
       b.fine.lam * q_osg * q_ff, "OSG (actual, test interval T_osg), FADEC feather command"; ...
       "PCU fail-to-fine AND the in-flight low-pitch stop fails (travel below the in-flight low pitch: excessive drag)", "PCU ince hatveye kaçar VE uçuş alt hatve durdurucusu arızalı (aşırı sürükleme)", ...
       b.fine.lam * q_lps, "low-pitch stop at its allowance"; ...
       "break downstream of the take-offs AND the counterweight feathering fails (decoupled propeller)", "alımların sonrasında kopma VE karşı ağırlıklı tüyleme arızalı (ayrılmış pervane)", ...
       l_down * q_cw, "counterweight feathering at its allowance (no OSG credit)"; ...
       "lube-to-pitch cross-leak at L403 AND the FADEC feather command fails", "L403'te yağlama-hatve çapraz kaçağı VE FADEC tüyleme komutu arızalı", ...
       b.cross.lam * q_ff, "FADEC feather command (no OSG credit)"; ...
       "lube-to-pitch cross-leak at L403 AND the in-flight low-pitch stop fails", "L403'te yağlama-hatve çapraz kaçağı VE uçuş alt hatve durdurucusu arızalı", ...
       b.cross.lam * q_lps, "low-pitch stop at its allowance"; ...
       "blockage of L403 / L404 (pitch frozen) AND an in-flight shutdown later in the mission (excessive drag)", "L403 / L404 tıkanması (hatve donuk) VE görevde sonra uçuşta kapatma (aşırı sürükleme)", ...
       b.block.lam * q_ifsd, "none (no governor or OSG credit)"; ...
       "common cause of the PCU and OSG drives (gear 2 web FM05, F204 stub FM63) AND the feathering fails", "PCU ve OSG tahriklerinin ortak nedeni (dişli 2 gövdesi FM05, F204 ucu FM63) VE tüyleme arızalı", ...
       l_cc * A.q_cc, "counterweight feathering, the set at its allowance"};
G.Tb = table(string(cut(:, 1)), string(cut(:, 2)), cell2mat(cut(:, 3)), string(cut(:, 4)), ...
             'VariableNames', {'cut_set_en', 'cut_set_tr', 'P_per_h', 'credits'});
G.sum_b = sum(G.Tb.P_per_h);
G.q = struct('osg', q_osg, 'ff', q_ff, 'lps', q(b.lps), 'cw', q(b.cw), 'ifsd', q_ifsd, 'lps_used', q_lps, 'cw_used', q_cw);
G.lam = struct('down', l_down, 'cc', l_cc);
end
