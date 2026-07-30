function cfg = economicConfig()
%%--------------------------------------------------------------------------
% ECONOMICCONFIG Centralized financial and economic parameters for CO2 storage
%
% Description:
%   Defines economic parameters including CAPEX (well drilling, pipeline),
%   OPEX per tonne of CO2, carbon credit/tax revenue, discount rate, and
%   financial evaluation horizons.
%
% Outputs:
%   cfg - Structure containing economic configuration parameters
%%--------------------------------------------------------------------------

    %% ---------------------------------------------------------------------
    % Capital Expenditure (CAPEX) Parameters
    %% ---------------------------------------------------------------------
    cfg.fixedCapexUSD     = 150e6;   % Infrastructure, pipeline & platform ($150M USD)
    cfg.wellCapexUSD      = 15e6;    % Drilling & completion cost per well ($15M USD)

    %% ---------------------------------------------------------------------
    % Operational Expenditure (OPEX) Parameters
    %% ---------------------------------------------------------------------
    cfg.opexPerTonneUSD   = 15.00;   % Transport, injection & monitoring OPEX ($/tonne CO2)

    %% ---------------------------------------------------------------------
    % Carbon Credit & Revenue Parameters
    %% ---------------------------------------------------------------------
    cfg.carbonValueUSD    = 85.00;   % Carbon credit / avoided tax value ($/tonne CO2)

    %% ---------------------------------------------------------------------
    % Discount Rate & Evaluation Timeframe
    %% ---------------------------------------------------------------------
    cfg.discountRate      = 0.08;    % Annual discount rate (8%)

end
