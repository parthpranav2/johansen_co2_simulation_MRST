function schedule = buildSchedule(W, simCfg, flCfg)
%%--------------------------------------------------------------------------
% BUILDSCHEDULE Construct simulation schedule wrapper
%
% Description:
%   High-level schedule builder function that delegates control block
%   generation and time-stepping to buildControls.m.
%
% Inputs:
%   W      - Array of MRST well structures
%   simCfg - (Optional) Simulation configuration structure from simulationConfig()
%   flCfg  - (Optional) Fluid configuration structure from fluidConfig()
%
% Outputs:
%   schedule - MRST schedule structure with steps and control blocks
%%--------------------------------------------------------------------------

    if nargin < 2 || isempty(simCfg)
        simCfg = simulationConfig();
    end
    if nargin < 3 || isempty(flCfg)
        flCfg = fluidConfig();
    end

    schedule = buildControls(W, simCfg, flCfg);

end
