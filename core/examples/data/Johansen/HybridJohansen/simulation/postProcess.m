function resStats = postProcess(model, states, ws, schedule)
%%--------------------------------------------------------------------------
% POSTPROCESS Extract diagnostic time-series and spatial metrics
%
% Description:
%   Processes raw simulation states and well solutions to calculate:
%     1. Spatial pressure buildup (Delta P) relative to initial state.
%     2. Maximum and average reservoir pressure trajectories over time.
%     3. CO2 plume thickness (h) and maximum footprint.
%     4. Mass inventory of stored CO2 (in Megatonnes).
%     5. Time-series of individual well injection rates and BHPs.
%
% Inputs:
%   model    - Upscaled Hybrid-VE model
%   states   - Array/cell array of simulation states
%   ws       - Cell array of well solution structures
%   schedule - Simulation schedule
%
% Outputs:
%   resStats - Structure containing processed diagnostic metrics
%%--------------------------------------------------------------------------

    fprintf('\n=====================================\n');
    fprintf('Running Simulation Post-Processing\n');
    fprintf('=====================================\n');

    nSteps = numel(states);
    G      = model.G;

    %% ---------------------------------------------------------------------
    % Extract Time Vector
    %% ---------------------------------------------------------------------
    dtVec = schedule.step.val;
    tVecSeconds = cumsum(dtVec);
    tVecYears   = tVecSeconds / year;
    resStats.tYears = [0; tVecYears];
    resStats.dt = dtVec;

    %% ---------------------------------------------------------------------
    % Preallocate Pressure Trajectories
    %% ---------------------------------------------------------------------
    if isfield(states{1}, 'pressure')
        pInitial = states{1}.pressure;
    elseif isfield(states{1}, 'p')
        pInitial = states{1}.p;
    else
        pInitial = zeros(G.cells.num, 1);
    end
    resStats.pInitial = pInitial;
    
    pMax      = zeros(nSteps + 1, 1);
    pAvg      = zeros(nSteps + 1, 1);
    deltaPMax = zeros(nSteps + 1, 1);

    pMax(1)      = max(pInitial) / barsa;
    pAvg(1)      = mean(pInitial) / barsa;
    deltaPMax(1) = 0;

    %% ---------------------------------------------------------------------
    % Preallocate Plume and Inventory Trajectories
    %% ---------------------------------------------------------------------
    plumeMaxHeight = zeros(nSteps + 1, 1);
    co2MassTotal   = zeros(nSteps + 1, 1);

    rhoCO2 = 700; % kg/m^3

    %% ---------------------------------------------------------------------
    % Loop over Simulation Timesteps
    %% ---------------------------------------------------------------------
    for s = 1:nSteps
        st = states{s};

        % Robust pressure extraction
        if isfield(st, 'pressure')
            pCurrent = st.pressure;
        elseif isfield(st, 'p')
            pCurrent = st.p;
        else
            pCurrent = pInitial;
        end

        pMax(s+1)      = max(pCurrent) / barsa;
        pAvg(s+1)      = mean(pCurrent) / barsa;
        deltaP         = pCurrent - pInitial;
        deltaPMax(s+1) = max(deltaP) / barsa;

        % Robust plume height extraction (Hybrid-VE vs Standard 3D)
        if isfield(st, 'h')
            plumeMaxHeight(s+1) = max(st.h);
        elseif isfield(st, 'sG')
            plumeMaxHeight(s+1) = max(st.sG);
        elseif isfield(st, 's') && size(st.s, 2) >= 2
            plumeMaxHeight(s+1) = max(st.s(:, 2));
        end

        % Robust CO2 Mass Inventory estimation (in Megatonnes)
        if isfield(st, 'sG') && isfield(G.cells, 'volumes')
            massKg = sum(st.sG .* G.cells.volumes * rhoCO2);
            co2MassTotal(s+1) = massKg / 1e9;
        elseif isfield(st, 'h') && isfield(G.cells, 'volumes')
            if isfield(G.cells, 'H')
                area = G.cells.volumes ./ G.cells.H;
            else
                area = G.cells.volumes / 10;
            end
            if isfield(model, 'rock') && isfield(model.rock, 'poro')
                poro = model.rock.poro;
            else
                poro = 0.2;
            end
            massKg = sum(st.h .* area .* poro * rhoCO2);
            co2MassTotal(s+1) = massKg / 1e9;
        elseif isfield(st, 's') && size(st.s, 2) >= 2 && isfield(G.cells, 'volumes')
            if isfield(model, 'rock') && isfield(model.rock, 'poro')
                pv = G.cells.volumes .* model.rock.poro;
            else
                pv = G.cells.volumes * 0.2;
            end
            massKg = sum(st.s(:, 2) .* pv * rhoCO2);
            co2MassTotal(s+1) = massKg / 1e9;
        end
    end

    resStats.pMax        = pMax;
    resStats.pAvg        = pAvg;
    resStats.deltaPMax   = deltaPMax;
    if isfield(states{end}, 'pressure')
        resStats.finalDeltaP = (states{end}.pressure - pInitial) / barsa;
    elseif isfield(states{end}, 'p')
        resStats.finalDeltaP = (states{end}.p - pInitial) / barsa;
    else
        resStats.finalDeltaP = zeros(G.cells.num, 1);
    end
    resStats.plumeMaxH   = plumeMaxHeight;
    resStats.co2MassMt   = co2MassTotal;

    %% ---------------------------------------------------------------------
    % Robust Well Performance Metrics Extraction
    %% ---------------------------------------------------------------------
    if ~isempty(ws) && ~isempty(ws{1})
        nW = numel(ws{1});
        wellNames = cell(nW, 1);
        for w = 1:nW
            if isfield(ws{1}(w), 'name')
                wellNames{w} = ws{1}(w).name;
            else
                wellNames{w} = sprintf('Well %d', w);
            end
        end

        wellBHP  = zeros(nSteps, nW);
        wellRate = zeros(nSteps, nW);

        secondsPerYear = 365.25 * 24 * 3600;

        for s = 1:nSteps
            for w = 1:nW
                wSol = ws{s}(w);

                % Robust BHP extraction
                if isfield(wSol, 'bhp')
                    wellBHP(s, w) = wSol.bhp / barsa;
                elseif isfield(wSol, 'P')
                    wellBHP(s, w) = wSol.P / barsa;
                else
                    wellBHP(s, w) = 0;
                end

                % Robust Volumetric Rate extraction (qG, qg, qs, cqs, or q)
                qVol = 0;
                if isfield(wSol, 'qG')
                    qVol = wSol.qG;
                elseif isfield(wSol, 'qg')
                    qVol = wSol.qg;
                elseif isfield(wSol, 'qs') && numel(wSol.qs) >= 2
                    qVol = wSol.qs(2);
                elseif isfield(wSol, 'cqs') && numel(wSol.cqs) >= 2
                    qVol = wSol.cqs(2);
                elseif isfield(wSol, 'q')
                    qVol = sum(abs(wSol.q));
                end

                % Convert m^3/s -> Mt/yr
                wellRate(s, w) = (abs(qVol) * rhoCO2 * secondsPerYear) / 1e9;
            end
        end

        resStats.wellNames = wellNames;
        resStats.wellBHP   = wellBHP;
        resStats.wellRate  = wellRate;
    end

    fprintf('Post-processing complete.\n');
    fprintf('  Max Pressure Buildup : %.2f bar\n', max(resStats.deltaPMax));
    fprintf('  Total Stored CO2     : %.2f Mt\n', resStats.co2MassMt(end));
    fprintf('=====================================\n');

end
