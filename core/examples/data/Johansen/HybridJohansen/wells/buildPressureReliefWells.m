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

    %% ---------------------------------------------------------------------
    % Loop over Well Table and Add Wells
    %% ---------------------------------------------------------------------
    for i = 1:nW
        wName = wellTable.WellID{i};
        wType = wellTable.Type{i};
        gridI = wellTable.GridI(i);
        gridJ = wellTable.GridJ(i);
        perfK = wellTable.PerfK{i};
        rate  = wellTable.TargetRate_m3s(i);

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
                'Name',   wName, ...
                'type',   'rate', ...
                'val',    rate, ...
                'comp_i', [0 1], ...  % 100% CO2 phase
                'sign',   1);
        elseif strcmpi(wType, 'Producer')
            W = addWell(W, G, rock, activeCellIndices, ...
                'Name',   wName, ...
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
        matchIdx = find(strcmp(wellTable.WellID, W(i).name), 1);
        if ~isempty(matchIdx)
            W(i).startYear = wellTable.StartYear(matchIdx);
            W(i).endYear   = wellTable.EndYear(matchIdx);
            W(i).wellRole  = wellTable.Type{matchIdx};
        else
            W(i).startYear = 0;
            W(i).endYear   = simCfg.injectionYears;
            W(i).wellRole  = 'Injector';
        end
    end

    fprintf('Successfully built %d wells (%d Injectors, %d Pressure Relief Producers).\n', ...
        numel(W), sum(strcmp({W.wellRole}, 'Injector')), sum(strcmp({W.wellRole}, 'Producer')));
    fprintf('=====================================\n');

end
