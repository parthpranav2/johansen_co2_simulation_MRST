%% ========================================================================
% Generate 25 years of realistic CO2 injection history
% Keeps original storage_injection.csv unchanged
%% ========================================================================

clear
clc

%% ------------------------------------------------------------------------
% FILES
%% ------------------------------------------------------------------------

inputFile = "/Users/apple/Desktop/study/programming/Matlab/Plugins/MRST-2026a/core/examples/data/Johansen/data/storage_injection.csv";

outputFile = "/Users/apple/Desktop/study/programming/Matlab/Plugins/MRST-2026a/core/examples/data/Johansen/data/storage_injection_25years.csv";

%% ------------------------------------------------------------------------
% READ ORIGINAL DATA
%% ------------------------------------------------------------------------

T = readtable(inputFile,'TextType','string');

%% ------------------------------------------------------------------------
% Find latest record
%% ------------------------------------------------------------------------

[~,idx] = max(T.csdYear*100 + T.csdMonth);
last = T(idx,:);

%% ------------------------------------------------------------------------
% PARAMETERS
%% ------------------------------------------------------------------------

yearsToGenerate = 25;

monthsToGenerate = yearsToGenerate*12;

annualTarget = 1500000;      % tonnes/year

rng(42);                     % reproducible

%% ------------------------------------------------------------------------
% Formatting helper
%% ------------------------------------------------------------------------

fmt = @(x) string(regexprep(num2str(round(x)), ...
    '\B(?=(\d{3})+(?!\d))', ','));

%% ------------------------------------------------------------------------
% Start month
%% ------------------------------------------------------------------------

currentYear = last.csdYear;
currentMonth = last.csdMonth + 1;

if currentMonth==13
    currentMonth = 1;
    currentYear = currentYear + 1;
end

%% ------------------------------------------------------------------------
% Preallocate
%% ------------------------------------------------------------------------

futureRows = repmat(last,monthsToGenerate,1);

row = 1;

%% ========================================================================
% GENERATE DATA
%% ========================================================================

for y = 1:yearsToGenerate

    %% ---------------- Seasonal profile ----------------

    season = [...
        0.90
        0.95
        1.00
        1.05
        1.10
        1.15
        1.15
        1.10
        1.05
        1.00
        0.95
        0.90];

    %% random operational variation

    noise = 0.85 + 0.30*rand(12,1);

    weights = season .* noise;

    %% occasional maintenance month

    if rand < 0.40

        shut = randi([2 11]);

        weights(shut) = weights(shut)*0.20;

    end

    %% normalise

    monthly = annualTarget * weights / sum(weights);

    monthly = round(monthly);

    %% guarantee exact annual total

    monthly(end) = monthly(end) + ...
        (annualTarget - sum(monthly));

    %% cumulative

    cumulative = cumsum(monthly);

    %% --------------------------------------------------

    for m = 1:12

        futureRows.cslNpdidLicence(row) = last.cslNpdidLicence;
        futureRows.cslLicenceName(row) = last.cslLicenceName;

        futureRows.wlbNpdidWellbore(row) = last.wlbNpdidWellbore;
        futureRows.wlbWellboreName(row) = last.wlbWellboreName;

        futureRows.csdYear(row) = currentYear;
        futureRows.csdMonth(row) = currentMonth;

        futureRows.csdVolumeInjectedMonth(row) = fmt(monthly(m));
        futureRows.csdVolumeInjectedTotalYear(row) = fmt(cumulative(m));

        %% Modified date (changes every row)

        futureRows.csdModifiedDate(row) = ...
            datetime(currentYear,currentMonth,...
                     eomday(currentYear,currentMonth),...
                     12,0,row);

        futureRows.csdModifiedDate.Format = ...
            T.csdModifiedDate.Format;

        %% advance month

        currentMonth = currentMonth + 1;

        if currentMonth==13

            currentMonth = 1;
            currentYear = currentYear + 1;

        end

        row = row + 1;

    end

end

futureRows = futureRows(1:row-1,:);

%% ========================================================================
% APPEND ORIGINAL + FUTURE
%% ========================================================================

Tout = [T; futureRows];

%% Keep newest first (same ordering as original file)

Tout = sortrows(Tout,...
    {'csdYear','csdMonth'},...
    {'descend','descend'});

%% ========================================================================
% WRITE
%% ========================================================================

writetable(Tout,outputFile);

fprintf('\n');
fprintf('---------------------------------------------\n');
fprintf('Original rows : %d\n',height(T));
fprintf('Rows added    : %d\n',height(futureRows));
fprintf('Final rows    : %d\n',height(Tout));
fprintf('Final year    : %d\n',max(Tout.csdYear));
fprintf('Saved to:\n%s\n',outputFile);
fprintf('---------------------------------------------\n');