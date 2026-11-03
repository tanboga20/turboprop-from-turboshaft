function hs_plot3d(msh, data, u, scale, ttl, clab, file, view_az)
%HS_PLOT3D  Colour map of a 3-D field on the deformed mesh, saved as a PNG.
%   hs_plot3d(msh, data, u, scale, ttl, clab, file, view_az)
%
%   msh: FEMesh; data: nodal values for the colours (empty: displacement
%   magnitude); u: struct with nodal ux, uy, uz [m]; scale: deformation
%   scale factor; ttl, clab: title and colour bar label; file: PNG path;
%   view_az: [azimuth elevation] of the view.
%   Source: Phase 2 report, Section 2.8 ("Results").

if isempty(data)
    data = sqrt(u.ux.^2 + u.uy.^2 + u.uz.^2);
end
fig = figure('Visible', 'off', 'Position', [100 100 900 700], 'Color', 'w');
pdeplot3D(msh, 'ColorMapData', data, 'Deformation', u, 'DeformationScaleFactor', scale);
colormap(fig, turbo(256));
cb = findobj(fig, 'Type', 'ColorBar');
if ~isempty(cb)
    cb.Label.String = clab;
end
view(view_az);
title(ttl, 'FontWeight', 'normal', 'FontSize', 11);
exportgraphics(fig, file, 'Resolution', 120);
close(fig);
end
