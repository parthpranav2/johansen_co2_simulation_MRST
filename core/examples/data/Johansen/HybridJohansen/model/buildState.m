function state0 = buildState(model)
%%--------------------------------------------------------------------------
% BUILDSTATE Initialize hydrostatic reservoir pressure and initial saturations
%
% Inputs:
%   model  - TwoPhaseWaterGasModel instance
%
% Outputs:
%   state0 - Initial state structure containing pressure and saturations
%%--------------------------------------------------------------------------

    G     = model.G;
    fluid = model.fluid;

    %% ---------------------------------------------------------------------
    % Hydrostatic Pressure Calculation
    %% ---------------------------------------------------------------------
    pRef = 300 * barsa;
    z    = G.cells.centroids(:, 3);
    rhoW = fluid.rhoWS;

    pInitial = pRef + rhoW * norm(gravity()) * (z - min(z));

    %% ---------------------------------------------------------------------
    % Initial Phase Saturations (100% Brine)
    %% ---------------------------------------------------------------------
    sW = ones(G.cells.num, 1);
    sG = zeros(G.cells.num, 1);

    %% ---------------------------------------------------------------------
    % Construct Reservoir State Structure
    %% ---------------------------------------------------------------------
    state0   = initResSol(G, pInitial);
    state0.s = [sW, sG];

    %% ---------------------------------------------------------------------
    % Display Summary
    %% ---------------------------------------------------------------------
    fprintf('\n=====================================\n');
    fprintf('Initial Reservoir State Created\n');
    fprintf('=====================================\n');
    fprintf('Pressure Range : %.2f - %.2f bar\n', ...
        min(pInitial) / barsa, max(pInitial) / barsa);
    fprintf('=====================================\n');

end
