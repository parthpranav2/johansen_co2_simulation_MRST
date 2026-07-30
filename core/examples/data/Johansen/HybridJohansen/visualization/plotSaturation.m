function plotSaturation(model, states)
%%--------------------------------------------------------------------------
% PLOTSATURATION Visualize spatial CO2 gas saturation at final timestep
%
% Inputs:
%   model  - Upscaled Hybrid-VE model
%   states - Cell array of simulation states
%%--------------------------------------------------------------------------

    G  = model.G;
    st = states{end};

    figure('Name', 'Johansen CO2 Saturation Field', ...
           'Color', 'w', ...
           'Position', [200, 200, 900, 650]);

    if isfield(st, 'sG')
        sG_val = st.sG;
    elseif isfield(st, 's')
        sG_val = st.s(:, 2);
    else
        sG_val = zeros(G.cells.num, 1);
    end

    plotCellData(G, sG_val, 'EdgeColor', 'none');
    colormap(jet);
    colorbar;
    title('Final CO_2 Phase Saturation Field S_g(t_{end})', 'FontSize', 12, 'FontWeight', 'bold');
    xlabel('X [m]'); ylabel('Y [m]');
    shading interp;
    axis equal tight;
    view(2);

end
