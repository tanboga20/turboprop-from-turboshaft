function M = sf_fmea(in)
%SF_FMEA  Check the RGB FMEA (safety/fmea_v1.csv) and build its summary tables.
%   M = sf_fmea(in)   in = sf_inputs
%
%   Each row is one failure mode with its engine effect classed by CS-E 510
%   (hazardous / major / minor): 'class' with the design features in place,
%   'class_unmitigated' without them. Checks:
%   1. both classes are one of the three, the group is known, the ID unique;
%   2. a mode still hazardous names a CS-E 515 critical part of D3;
%   3. a mode hazardous before mitigation names a critical part or a design
%      feature that removes the hazard;
%   4. every mode has a detection means and a 3.10 / 3.11 item; a mode marked latent (failure mode or detection)
%      or found by no means in service cites an ICA task of in.ica (safety/ica_items_v1.csv) with an interval;
%   5. every critical part of D3 is named by at least one mode, and the critical parts are the derived set (named by
%      a mode whose primary failure stays hazardous) plus the parts kept by decision (in.cp_decision).
%   M.fails lists the failed checks (empty when the table is consistent).
%   Source: Phase 3 report, Section 3.7 (D2).

f = in.fmea;
T = readtable(f.file, 'TextType', 'string', 'Delimiter', ',', 'Encoding', 'UTF-8', 'VariableNamingRule', 'preserve');
n = height(T);
fails = strings(0, 1);
cls = string(f.classes);
bad = ~ismember(T.class, cls) | ~ismember(T.class_unmitigated, cls);
if any(bad), fails(end + 1) = "unknown class: " + strjoin(T.id(bad), ', '); end
bad = ~ismember(T.group, string(f.groups));
if any(bad), fails(end + 1) = "unknown group: " + strjoin(T.id(bad), ', '); end
if numel(unique(T.id)) < n, fails(end + 1) = "duplicate IDs"; end
cp = string(in.cp_names);
named = arrayfun(@(s) any(contains(s, cp)), T.critical_part);
bad = T.class == "hazardous" & ~named;
if any(bad), fails(end + 1) = "hazardous without a critical part: " + strjoin(T.id(bad), ', '); end
bad = T.class_unmitigated == "hazardous" & ~named & (T.design_feature == "-" | T.design_feature == "");
if any(bad), fails(end + 1) = "hazardous before mitigation without a part or feature: " + strjoin(T.id(bad), ', '); end
bad = T.detection == "" | T.verification == "" | T.verification == "-";
if any(bad), fails(end + 1) = "no detection or 3.10 / 3.11 item: " + strjoin(T.id(bad), ', '); end
lat = ~cellfun(@isempty, regexpi(cellstr(T.failure_mode + " " + T.detection), f.latent, 'once'));
ica = string(in.ica(:, 1));
cited = arrayfun(@(v) any(arrayfun(@(c) contains(v, c), ica)), T.verification);
bad = lat & ~cited;
if any(bad), fails(end + 1) = "latent mode without an ICA task: " + strjoin(T.id(bad), ', '); end
for c = cp
    if ~any(contains(T.critical_part, c)), fails(end + 1) = "critical part not named by any mode: " + c; end %#ok<AGROW>
end
% the critical parts: the derived set (named by a mode that stays hazardous) plus the parts kept by decision
hz = T.critical_part(T.class == "hazardous");
M.cp_derived = cp(arrayfun(@(c) any(contains(hz, c)), cp));
M.cp_decision = string(in.cp_decision);
bad = setxor(cp, union(M.cp_derived, M.cp_decision));
if ~isempty(bad), fails(end + 1) = "critical parts not the derived set plus the decision: " + strjoin(bad, ', '); end
% counts: by class with features, before them, and by group
M.n = n;
M.count = arrayfun(@(c) sum(T.class == c), cls);
M.count_unmit = arrayfun(@(c) sum(T.class_unmitigated == c), cls);
G = zeros(numel(f.groups), numel(cls));
for g = 1:numel(f.groups)
    for k = 1:numel(cls), G(g, k) = sum(T.group == f.groups{g} & T.class == cls(k)); end
end
M.by_group = array2table(G, 'VariableNames', f.classes, 'RowNames', f.groups);
M.unmit_by_group = arrayfun(@(g) sum(T.group == f.groups{g} & T.class_unmitigated == "hazardous"), 1:numel(f.groups))';
% the modes hazardous before mitigation, with what removes or controls the hazard
k = T.class_unmitigated == "hazardous";
M.haz = T(k, {'id', 'item', 'failure_mode', 'class', 'critical_part', 'design_feature', 'owner'});
% detection means: number of modes that name each; a mode found by no means in service counts as latent only
% (a means named as TBR in its text does not count)
X = false(n, numel(f.detect));
for j = 1:numel(f.detect), X(:, j) = ~cellfun(@isempty, regexpi(cellstr(T.detection), f.detect{j}, 'once')); end
X(X(:, end), 1:end - 1) = false;
M.detect = sum(X, 1)';
% major effects against Remote (CS-E 510(a)(2) and (a)(4))
mj = f.major;
M.major = table(string(mj(:, 1)), string(mj(:, 2)), string(mj(:, 3)), cell2mat(mj(:, 4)), cell2mat(mj(:, 4)) <= f.remote, ...
                string(mj(:, 5)), 'VariableNames', {'effect_en', 'effect_tr', 'fmea', 'rate_per_h', 'remote', 'source'});
M.n_latent = sum(lat);
M.T = T;
M.fails = fails;
end
