function W = buildWells(model, rock, fluid, wellTable, simCfg, flCfg)
%%--------------------------------------------------------------------------
% BUILDWELLS Construct well structure array delegating to buildPressureReliefWells
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
%   W - MRST well structure array containing injectors and pressure relief producers
%%--------------------------------------------------------------------------
    W = buildPressureReliefWells(model, rock, fluid, wellTable, simCfg, flCfg);
end