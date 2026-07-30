function model = buildModel(G, rock, fluid)
%%--------------------------------------------------------------------------
% BUILDMODEL Construct Two-Phase Water-Gas AD Reservoir Model
%
% Inputs:
%   G     - MRST grid structure
%   rock  - Rock properties structure (porosity, permeability)
%   fluid - AD fluid structure
%
% Outputs:
%   model - Initialized TwoPhaseWaterGasModel instance
%%--------------------------------------------------------------------------

    %% ---------------------------------------------------------------------
    % Instantiate Reservoir Model
    %% ---------------------------------------------------------------------
    model = TwoPhaseWaterGasModel(G, rock, fluid);

    %% ---------------------------------------------------------------------
    % Configure Model Options
    %% ---------------------------------------------------------------------
    model.useCNVConvergence = true;
    model.extraStateOutput   = true;

    %% ---------------------------------------------------------------------
    % Display Summary
    %% ---------------------------------------------------------------------
    fprintf('\n=====================================\n');
    fprintf('AD Reservoir Model Created\n');
    fprintf('=====================================\n');
    fprintf('Model Class : %s\n', class(model));
    fprintf('Cells       : %d\n', model.G.cells.num);
    fprintf('=====================================\n');

end
