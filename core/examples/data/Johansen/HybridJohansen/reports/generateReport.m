function reportFilePath = generateReport(model, simCfg, flCfg, resStats, econResults)
%%--------------------------------------------------------------------------
% GENERATEREPORT Generate automated Markdown summary report for simulation
%
% Inputs:
%   model       - Reservoir model object (or model_hyb)
%   simCfg      - Simulation config structure
%   flCfg       - Fluid config structure
%   resStats    - Processed simulation statistics
%   econResults - Economic evaluation results
%
% Outputs:
%   reportFilePath - Path to generated report Markdown file
%%--------------------------------------------------------------------------

    if ~exist('output', 'dir')
        mkdir('output');
    end

    reportFilePath = fullfile('output', sprintf('Johansen_Report_%s.md', simCfg.scenarioName));
    fid = fopen(reportFilePath, 'w');

    if fid == -1
        error('Failed to create report file: %s', reportFilePath);
    end

    %% ---------------------------------------------------------------------
    % Robust Grid Dimension Extraction (Handles 3D vs 2D TopSurfaceGrid)
    %% ---------------------------------------------------------------------
    if isfield(model.G, 'cartDims')
        nx = model.G.cartDims(1);
        ny = model.G.cartDims(2);
        nz = model.G.cartDims(3);
    elseif isfield(model.G, 'parent') && isfield(model.G.parent, 'cartDims')
        nx = model.G.parent.cartDims(1);
        ny = model.G.parent.cartDims(2);
        nz = model.G.parent.cartDims(3);
    else
        nx = 100; ny = 100; nz = 11;
    end

    fprintf(fid, '# HybridJohansen CO2 Storage Simulation & Economic Report\n\n');
    fprintf(fid, '**Scenario:** %s  \n', simCfg.scenarioName);
    fprintf(fid, '**Generated On:** %s  \n\n', datestr(now));

    fprintf(fid, '---\n\n');

    fprintf(fid, '## 1. Simulation & Model Specifications\n');
    fprintf(fid, '- **Grid Dimensions:** %d x %d x %d  \n', nx, ny, nz);
    fprintf(fid, '- **Active Grid Cells:** %d  \n', model.G.cells.num);
    fprintf(fid, '- **Injection Window:** %.1f Years  \n', simCfg.injectionYears);
    fprintf(fid, '- **Shut-in / Monitoring:** %.1f Years  \n', simCfg.shutinYears);
    fprintf(fid, '- **Total Simulation Window:** %.1f Years  \n', simCfg.totalTimeYears);
    fprintf(fid, '- **Injection Profile:** %s  \n\n', simCfg.injectionProfile);

    fprintf(fid, '## 2. Reservoir Physics & Diagnostic Performance\n');
    fprintf(fid, '- **Total Stored CO2 Mass:** %.2f Megatonnes (Mt)  \n', resStats.co2MassMt(end));
    fprintf(fid, '- **Max Field Pressure Buildup (\\Delta P_max):** %.2f bar  \n', max(resStats.deltaPMax));
    fprintf(fid, '- **Initial Reservoir Pressure:** %.2f bar  \n', min(resStats.pInitial) / barsa);
    fprintf(fid, '- **Peak Field Pressure:** %.2f bar  \n', max(resStats.pMax));
    fprintf(fid, '- **Max Free Plume Height:** %.2f m  \n\n', max(resStats.plumeMaxH));

    fprintf(fid, '## 3. Financial & Economic Assessment\n');
    fprintf(fid, '- **Total Initial CAPEX:** $%.2f Million USD  \n', econResults.totalCapexUSD / 1e6);
    fprintf(fid, '- **Net Present Value (NPV @ 8%%):** $%.2f Million USD  \n', econResults.npvUSD / 1e6);
    fprintf(fid, '- **Levelized Cost of Storage (LCOS):** $%.2f / tonne CO2  \n', econResults.lcosUSD);
    fprintf(fid, '- **Assumed Carbon Value:** $%.2f / tonne CO2  \n\n', econResults.econCfg.carbonValueUSD);

    fprintf(fid, '---\n');
    fprintf(fid, '*Report automatically compiled by HybridJohansen Framework.*\n');

    fclose(fid);

    fprintf('\n=====================================\n');
    fprintf('Report Generated Successfully:\n');
    fprintf('File: %s\n', reportFilePath);
    fprintf('=====================================\n');

end
