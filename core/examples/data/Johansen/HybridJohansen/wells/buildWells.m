function W = buildWells(model, rock, fluid, T, simCfg, flCfg)
%%--------------------------------------------------------------------------
% BUILDWELLS Construct MRST well structure from converted well table
%
% Inputs:
%   model  - TwoPhaseWaterGasModel object
%   rock   - Rock properties structure
%   fluid  - AD fluid structure
%   T      - Well table with Grid_X, Grid_Y, perforation ranges, and controls
%   simCfg - (Optional) Simulation config from simulationConfig()
%   flCfg  - (Optional) Fluid config from fluidConfig()
%
% Outputs:
%   W      - MRST well structure array with startYear and endYear metadata
%%--------------------------------------------------------------------------

    if nargin < 5 || isempty(simCfg)
        simCfg = simulationConfig();
    end
    if nargin < 6 || isempty(flCfg)
        flCfg = fluidConfig();
    end

    secondsPerYear = 365.25 * 24 * 3600;
    rhoCO2          = flCfg.rhoG; % Supercritical CO2 density from config

    fprintf('\n=====================================\n');
    fprintf('Building MRST Well Specifications\n');
    fprintf('=====================================\n');

    W = [];
    G = model.G;

    nx = G.cartDims(1);
    ny = G.cartDims(2);
    nz = G.cartDims(3);

    %% ---------------------------------------------------------------------
    % Build Cartesian to Active-Cell Lookup Map
    %% ---------------------------------------------------------------------
    cartToActive = zeros(prod(G.cartDims), 1);
    cartToActive(G.cells.indexMap) = 1:G.cells.num;

    nInj  = 0;
    nProd = 0;

    %% ---------------------------------------------------------------------
    % Process Each Well Entry in Table
    %% ---------------------------------------------------------------------
    for i = 1:height(T)
        ix = T.Grid_X(i);
        iy = T.Grid_Y(i);

        k1 = T.PERF_FROM(i);
        k2 = T.PERF_TO(i);

        % Validate perforation range within Cartesian dimensions
        if ix < 1 || ix > nx || iy < 1 || iy > ny || ...
           k1 < 1 || k2 > nz || k1 > k2
            error("Invalid spatial/perforation coordinates for well %s.", ...
                string(T.Well_Bore_Name{i}));
        end

        % Map Cartesian perforations to active MRST grid cells
        cells = zeros(k2 - k1 + 1, 1);
        idx = 1;
        for k = k1:k2
            cartCell = sub2ind([nx, ny, nz], ix, iy, k);
            activeCell = cartToActive(cartCell);
            if activeCell == 0
                error("Well %s perforates an inactive grid cell (%d,%d,%d).", ...
                    string(T.Well_Bore_Name{i}), ix, iy, k);
            end
            cells(idx) = activeCell;
            idx = idx + 1;
        end

        %% -----------------------------------------------------------------
        % Configure Well Control & Nature
        %% -----------------------------------------------------------------
        natureVal = T.Nature(i);
        if iscell(natureVal) || isstring(natureVal)
            natureVal = str2double(string(natureVal));
        end

        if natureVal == 1
            % Injector Setup (Mass rate target -> Volumetric rate m^3/s)
            type = 'rate';
            targetTonnes = T.Target_tonnes_per_year(i);
            targetKgPerSec = targetTonnes * 1000 / secondsPerYear;
            val = targetKgPerSec / rhoCO2;

            fprintf("Injector %-15s : %.2f Mt/yr -> %.5f m^3/s\n", ...
                char(T.Well_Bore_Name{i}), targetTonnes / 1e6, val);

            sign  = 1;
            compi = [0, 1]; % Pure CO2 phase injection
            nInj  = nInj + 1;
        else
            % Producer Setup (BHP control from config)
            type = 'bhp';
            val  = simCfg.defaultProducerBHP;

            fprintf("Producer %-15s : %.1f bar BHP\n", ...
                char(T.Well_Bore_Name{i}), val / barsa);

            sign  = -1;
            compi = [1, 0]; % Water phase default
            nProd = nProd + 1;
        end

        %% -----------------------------------------------------------------
        % Add Well to MRST Well Array
        %% -----------------------------------------------------------------
        W = addWell( ...
            W, ...
            G, ...
            rock, ...
            cells, ...
            'Type',   type, ...
            'Val',    val, ...
            'Radius', simCfg.wellRadius, ...
            'Dir',    'z', ...
            'Name',   char(T.Well_Bore_Name{i}), ...
            'Comp_i', compi, ...
            'Sign',   sign);
    end

    %% ---------------------------------------------------------------------
    % Attach Schedule Metadata Post-Concatenation
    %% ---------------------------------------------------------------------
    for i = 1:numel(W)
        W(i).startYear = T.Start_Year(i);
        W(i).endYear   = T.End_Year(i);
    end

    %% ---------------------------------------------------------------------
    % Display Summary
    %% ---------------------------------------------------------------------
    fprintf("Summary: %d Injectors, %d Producers (Total: %d wells)\n", ...
        nInj, nProd, numel(W));
    fprintf("=====================================\n");

end