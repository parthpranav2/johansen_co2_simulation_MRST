function scenarios = defineScenarios()
%%--------------------------------------------------------------------------
% DEFINESCENARIOS Define reservoir development scenarios for Johansen
%
% Description:
%   Constructs a dictionary/structure of pre-configured field development
%   scenarios to test different operational plans:
%     1. Base Case ('base_case'): 10yr injection (ramp-up), 20yr shut-in.
%     2. High Rate ('high_rate'): 10yr injection at 2.0x target rate.
%     3. Constant Rate ('constant_rate'): 10yr injection without ramp-up.
%     4. Extended Injection ('extended_inj'): 20yr injection, 10yr shut-in.
%
% Outputs:
%   scenarios - Structure array containing scenario configuration overrides
%%--------------------------------------------------------------------------

    scenarios = struct([]);

    %% ---------------------------------------------------------------------
    % Scenario 1: Base Case (Standard Commercial Target)
    %% ---------------------------------------------------------------------
    s1.name             = 'base_case';
    s1.description      = 'Base Case: 10yr injection (rampup), 20yr monitoring';
    s1.injectionYears   = 10;
    s1.shutinYears      = 20;
    s1.injectionProfile = 'rampup';
    s1.rampupYears      = 3;
    s1.rateMultiplier   = 1.0;
    scenarios = [scenarios; s1];

    %% ---------------------------------------------------------------------
    % Scenario 2: High Rate Injection (2.0x Capacity Expansion)
    %% ---------------------------------------------------------------------
    s2.name             = 'high_rate';
    s2.description      = 'High Rate: 10yr injection at 2.0x capacity, 20yr monitoring';
    s2.injectionYears   = 10;
    s2.shutinYears      = 20;
    s2.injectionProfile = 'rampup';
    s2.rampupYears      = 3;
    s2.rateMultiplier   = 2.0;
    scenarios = [scenarios; s2];

    %% ---------------------------------------------------------------------
    % Scenario 3: Constant Injection Rate (No Ramp-up Phase)
    %% ---------------------------------------------------------------------
    s3.name             = 'constant_rate';
    s3.description      = 'Constant Rate: 10yr injection at 100% capacity from Day 1';
    s3.injectionYears   = 10;
    s3.shutinYears      = 20;
    s3.injectionProfile = 'constant';
    s3.rampupYears      = 0;
    s3.rateMultiplier   = 1.0;
    scenarios = [scenarios; s3];

    %% ---------------------------------------------------------------------
    % Scenario 4: Extended Injection Window (20 Years)
    %% ---------------------------------------------------------------------
    s4.name             = 'extended_inj';
    s4.description      = 'Extended: 20yr active injection, 10yr monitoring';
    s4.injectionYears   = 20;
    s4.shutinYears      = 10;
    s4.injectionProfile = 'rampup';
    s4.rampupYears      = 3;
    s4.rateMultiplier   = 1.0;
    scenarios = [scenarios; s4];

end
