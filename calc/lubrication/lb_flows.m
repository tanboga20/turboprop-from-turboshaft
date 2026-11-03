function F = lb_flows(L, N, in, oil)
%LB_FLOWS  Oil flow to each component and its jets, from the heat it makes.
%   F = lb_flows(L, N, in, oil)
%
%   L is the loss struct of lb_losses at the design point, N the number of
%   planets, in = lb_inputs, oil = oil_props at the design temperature.
%   Each component gets the flow that carries its heat with the design
%   temperature rise in.dT_oil, at least in.Q_min_brg per bearing; the
%   quill splines get in.Q_spline each. The main meshes are fed by a pair
%   of jets each (in.into_mesh of the flow on the into-mesh side, the rest
%   out of mesh), the accessory meshes by one out-of-mesh jet each, the
%   bearings by one jet each (planet bearings through their pins). A jet is
%   an orifice at in.dp_jet: Q = Cd pi d^2 / 4 sqrt(2 dp / rho). Jets
%   below in.d_jet_min are made in.d_jet_min (they pass more than needed);
%   a feed above in.d_jet_max is split into more jets.
%
%   Output struct F: comp (table rows: name, heat [W], need, flow [L/min],
%   jets, d [mm] of the largest jet), Q_lube, Q_need (with the PCU and
%   leaks), Q_main, Q_rear (flow into the RGB sump and the PT rear sump)
%   [L/min], v_jet [m/s].
%   Source: Phase 2 report, Section 2.7 ("Oil flows and jets"). Tested by
%   test_step27 (TC50).

rho = oil.rho;
v_id = sqrt(2 * in.dp_jet * 1e3 / rho);
q_jet = @(d) in.Cd_jet * pi / 4 * (d * 1e-3)^2 * v_id * 6e4;        % L/min through one jet of d [mm]
d_for = @(q) sqrt(4 * q / 6e4 / (in.Cd_jet * v_id * pi)) * 1e3;    % jet diameter for q [L/min]
Qh = @(P) P / (rho * oil.cp * in.dT_oil) * 6e4;                    % L/min that carries P [W]

% name, heat, number of meshes (a pair of jets each, or one jet each for 'mesh1') or feeds, kind.
% The ring meshes take the oil thrown out of the sun-planet meshes and the planet bearings; the OSG and
% PCU shaft bearings and the pad splines run on that splash; the quill splines are fed through the shaft
% bores; the generator shaft bearings (12,000 rpm) have a jet each.
c = {'first-stage mesh', L.mesh_s1 + L.wind_pinion + L.wind_gear2, 1, 'mesh'; ...
     'planetary meshes', L.mesh_sp + L.mesh_pr + L.wind_planetary, N, 'mesh'; ...
     'planet bearings', L.brg_planet, N, 'brg'; ...
     'input shaft bearings', L.brg_inp, 3, 'brg'; ...
     'intermediate shaft bearings', L.brg_mid, 3, 'brg'; ...
     'propeller shaft bearings', L.brg_prop, 3, 'brg'; ...
     'accessory meshes', L.mesh_gen + L.mesh_osg + L.mesh_pcu + L.wind_acc, 3, 'mesh1'; ...
     'generator shaft bearings', L.brg_acc, 2, 'brg'; ...
     'quill splines', 0, 2, 'spline'; ...
     'PT rear sump', L.rear_sump, 2, 'brg'};
for k = 1:size(c, 1)
    [nm, P, n, kind] = c{k, :};
    switch kind
        case 'mesh'
            need = Qh(P);
            shares = [in.into_mesh, 1 - in.into_mesh] / n;         % per mesh: into, out
            nj = 2 * n;
        case 'mesh1'
            need = Qh(P);
            shares = 1 / n;
            nj = n;
        case 'brg'
            need = max(Qh(P), n * in.Q_min_brg);
            shares = 1 / n;
            nj = n;
        otherwise
            need = n * in.Q_spline;
            shares = 1 / n;
            nj = n;
    end
    flow = 0;  dmax = 0;  jets = 0;
    for s = shares
        q = need * s;
        d = d_for(q);
        m = 1;
        if d > in.d_jet_max                                         % split a large feed
            m = ceil((d / in.d_jet_max)^2);
            d = d_for(q / m);
        end
        d = max(d, in.d_jet_min);
        nper = nj / numel(shares);
        flow = flow + nper * m * q_jet(d);
        jets = jets + nper * m;
        dmax = max(dmax, d);
    end
    comp(k) = struct('name', nm, 'heat', P, 'need', need, 'flow', flow, 'jets', jets, 'd', dmax); %#ok<AGROW>
end
Q_lube = sum([comp.flow]);
Q_rear = comp(end).flow;
F = struct('comp', comp, 'Q_lube', Q_lube, 'Q_need', (Q_lube + in.Q_pcu) * (1 + in.leak), ...
           'Q_main', Q_lube - Q_rear + in.Q_pcu, 'Q_rear', Q_rear, 'v_jet', in.Cd_jet * v_id);
end
