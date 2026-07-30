function W = buildPressureReliefWells(model, rock, fluid, wellTable, simCfg, flCfg)
%%--------------------------------------------------------------------------
% BUILDPRESSURERELIEFWELLES Build combined injector and brine producer well set
%
% Description:
%   Constructs MRST well structure array containing both CO2 injectors and
%   down-flank brine production wells for active pressure relief.
%
% Inputs:
%   model     - Reservoir model object
%   rock      - Reservoir rock object
%   fluid     - AD fluid object
%   wellTable - Filtered and grid-mapped well table
%   simCfg    - Simulation configuration structure
%   flCfg     - Fluid configuration structure
%
% Outputs:
%   W - Complete MRST well structure array containing injectors and producers
%%--------------------------------------------------------------------------

    fprintf('\n=====================================\n');
    fprintf('Building Active Pressure Management Well Set\n');
    fprintf('=====================================\n');

    G  = model.G;
    nW = height(wellTable);
    W  = [];

    targetBHP = simCfg.defaultProducerBHP;

    vars = wellTable.Properties.VariableNames;

    %% ---------------------------------------------------------------------
    % Loop over Well Table and Add Wells
    %% ---------------------------------------------------------------------
    for i = 1:nW
        % Well Name
        if ismember('Well_Bore_Name', vars)
            wName = string(wellTable.Well_Bore_Name{i});
        elseif ismember('WellID', vars)
            wName = string(wellTable.WellID{i});
        else
            wName = sprintf('Well_%d', i);
        end

        % Well Nature / Type (1 = Injector, 0 = Producer)
        if ismember('Nature', vars)
            natVal = wellTable.Nature(i);
            if natVal == 1
                wType = 'Injector';
            else
                wType = 'Producer';
            end
        elseif ismember('Type', vars)
            wType = string(wellTable.Type{i});
        else
            wType = 'Injector';
        end

        % Grid Location
        if ismember('Grid_X', vars)
            gridI = wellTable.Grid_X(i);
        elseif ismember('GridI', vars)
            gridI = wellTable.GridI(i);
        else
            gridI = 51;
        end

        if ismember('Grid_Y', vars)
            gridJ = wellTable.Grid_Y(i);
        elseif ismember('GridJ', vars)
            gridJ = wellTable.GridJ(i);
        else
            gridJ = 51;
        end

        % Perforation Layers
        if ismember('PERF_FROM', vars) && ismember('PERF_TO', vars)
            perfK = wellTable.PERF_FROM(i):wellTable.PERF_TO(i);
        elseif ismember('PerfK', vars)
            perfK = wellTable.PerfK{i};
        else
            perfK = 6:10;
        end

        % Injection Rate Target (m^3/s)
        if ismember('Target_tonnes_per_year', vars)
            targetTonnes = wellTable.Target_tonnes_per_year(i);
            targetKgPerSec = targetTonnes * 1e3 / (365.25 * 24 * 3600);
            rate = targetKgPerSec / flCfg.rhoG;
        elseif ismember('TargetRate_m3s', vars)
            rate = wellTable.TargetRate_m3s(i);
        else
            rate = (3.5e9 / (365.25 * 24 * 3600)) / flCfg.rhoG;
        end

        % Map Cartesian (I, J, K) -> Active 3D Grid Cells
        gridCells = false(G.cartDims);
        gridCells(gridI, gridJ, perfK) = true;
        activeCellIndices = find(gridCells(G.cells.indexMap));

        if isempty(activeCellIndices)
            warning("Well %s at (%d,%d) has no active grid cells. Skipping.", wName, gridI, gridJ);
            continue;
        end

        if strcmpi(wType, 'Injector')
            W = addWell(W, G, rock, activeCellIndices, ...
                'Name',   char(wName), ...
                'type',   'rate', ...
                'val',    rate, ...
                'comp_i', [0 1], ...  % 100% CO2 phase
                'sign',   1);
        else
            W = addWell(W, G, rock, activeCellIndices, ...
                'Name',   char(wName), ...
                'type',   'bhp', ...
                'val',    targetBHP, ...
                'comp_i', [1 0], ...  % 100% Brine phase
                'sign',   -1);
        end
    end

    %% ---------------------------------------------------------------------
    % Append Custom Metadata Fields Post-Loop Across Entire Struct Array
    %% ---------------------------------------------------------------------
    for i = 1:numel(W)
        if ismember('Start_Year', vars)
            W(i).startYear = wellTable.Start_Year(i);
        elseif ismember('StartYear', vars)
            W(i).startYear = wellTable.StartYear(i);
        else
            W(i).startYear = 0;
        end

        if ismember('End_Year', vars)
            W(i).endYear = wellTable.End_Year(i);
        elseif ismember('EndYear', vars)
            W(i).endYear = wellTable.EndYear(i);
        else
            W(i).endYear = simCfg.injectionYears;
        end

        if W(i).sign > 0
            W(i).wellRole = 'Injector';
        else
            W(i).wellRole = 'Producer';
        end
    end

    fprintf('Successfully built %d wells (%d Injectors, %d Pressure Relief Producers).\n', ...
        numel(W), sum(strcmp({W.wellRole}, 'Injector')), sum(strcmp({W.wellRole}, 'Producer')));
    fprintf('=====================================\n');

end
