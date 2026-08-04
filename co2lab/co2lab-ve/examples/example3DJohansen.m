%% 3D, two-phase Johansen CO2 Storage Simulation  ― CSV-Driven Version  [v6]
% v6 CHANGES (from v5):
% - 31/2-5 removed from dirInjNames (retired: peaked 400-550 bar BHP,

%% =========================================================================
%  Load modules
% =========================================================================

%% --- Figure Display Control ------------------------------------------------
% DISPLAY_FIGURES: Set to FALSE (default) to suppress ALL figure windows.
% Figures are STILL created in memory and SAVED to disk; only the on-screen
DISPLAY_FIGURES = false;   % <-- TOGGLE HERE: true = show figs, false = silent mode

% Suppress all figure display when DISPLAY_FIGURES is false
if ~DISPLAY_FIGURES
    set(0, 'DefaultFigureVisible', 'off');
    fprintf('[SILENT MODE] Running without figure display — plots saved to disk only.\n');
else
    close all;
    set(0, 'DefaultFigureVisible', 'on');
    fprintf('[INTERACTIVE MODE] Figure windows will be displayed.\n');
end

%% --- Create output folder for this run ---
runName   = datestr(now, 'dd_mm_yyyy__HH_MM');
outputDir = fullfile('/Users/apple/Desktop/study/programming/Matlab/Plugins/', ...
                     'MRST-2026a/core/examples/data/Johansen/well_csvs', runName);
mkdir(outputDir);

mrstModule add ad-core ad-props ad-blackoil
mrstModule add co2lab-common co2lab-ve co2lab-spillpoint
mrstModule add coarsegrid

%% =========================================================================
%  Grid and rock
% =========================================================================
[G, rock, bcIx] = makeJohansenVEgrid();

if DISPLAY_FIGURES
figure; plotCellData(G, rock.poro); view(-35,15); colorbar;
set(gcf,'position',[531 337 923 356]); axis tight;
title('Porosity','FontSize',12);

figure; plotCellData(G, rock.perm(:,1)/darcy); view(-55,60); colorbar;
set(gcf,'position',[152 419 1846 700],'color','white'); axis tight;
set(gca,'fontsize',24); title('Lateral Permeability (mD)','FontSize',12);

figure; plotCellData(G, rock.perm(:,3)/darcy); view(-55,60); colorbar;
set(gcf,'position',[152 419 1846 700],'color','white'); axis tight;
set(gca,'fontsize',24); title('Vertical Permeability (mD)','FontSize',12);

end  % ~HEADLESS
%% =========================================================================
%  Initial state
% =========================================================================
gravity on;
g    = gravity;
rhow = 1000;   % brine density at 94 deg-C and 300 bar [kg/m3]
initState.pressure = rhow * g(3) * G.cells.centroids(:,3);
initState.s        = repmat([1, 0], G.cells.num, 1);
initState.sGmax    = initState.s(:,2);

%% =========================================================================
%  Fluid model  (identical to original example3DJohansen.m physics)
% =========================================================================
co2    = CO2props();
p_ref  = 30 * mega * Pascal;         % reference pressure  [Pa]
t_ref  = 94 + 273.15;                % reference temperature [K]
rhoc   = co2.rho(p_ref, t_ref);      % CO2 density at ref P/T [kg/m3]
cf_co2 = co2.rhoDP(p_ref, t_ref) / rhoc;   % CO2 compressibility [1/Pa]
cf_wat  = 0;                          % brine compressibility (zero)
cf_rock = 4.35e-5 / barsa;           % rock compressibility  [1/Pa]
muw     = 8e-4 * Pascal * second;    % brine viscosity       [Pa.s]
muco2   = co2.mu(p_ref, t_ref) * Pascal * second;  % CO2 viscosity [Pa.s]

mrstModule add ad-props;
fluid = initSimpleADIFluid('phases', 'WG'             , ...
                           'mu'   , [muw, muco2]       , ...
                           'rho'  , [rhow, rhoc]        , ...
                           'pRef' , p_ref               , ...
                           'c'    , [cf_wat, cf_co2]    , ...
                           'cR'   , cf_rock             , ...
                           'n'    , [2 2]);

% Rel-perm before endpoint scaling
sw = linspace(0, 1, 200);
if DISPLAY_FIGURES
figure; hold on;
plot(sw, fluid.krW(sw),   'b', 'LineWidth', 1.5);
plot(sw, fluid.krG(1-sw), 'r', 'LineWidth', 1.5);
xlabel('Brine saturation'); ylabel('Relative permeability');
title('Rel-perm curves (before endpoint scaling)','FontSize',12);
set(gca,'FontSize',12); legend('krW','krG');
end

% Endpoint scaling: residual saturations
srw = 0.27;   % residual brine saturation
src = 0.20;   % residual CO2 saturation
fluid.krW = @(s) fluid.krW(max((s - srw)./(1 - srw), 0));
fluid.krG = @(s) fluid.krG(max((s - src)./(1 - src), 0));

if DISPLAY_FIGURES
% Rel-perm after endpoint scaling
figure; hold on;
sw2 = linspace(srw, 1, 200);
plot(sw2, fluid.krW(sw2),   'b', 'LineWidth', 1.5);
plot(sw2, fluid.krG(1-sw2), 'r', 'LineWidth', 1.5);
line([srw, srw], [0 1], 'color', 'k', 'linestyle', ':', 'LineWidth', 1);
xlabel('Brine saturation'); ylabel('Relative permeability');
title(sprintf('Rel-perm after endpoint scaling  (srw=%.2f, src=%.2f)', srw, src),'FontSize',12);
set(gca,'FontSize',12,'xlim',[0 1]); legend('krW','krG');
end

% Capillary pressure
pe   = 5 * kilo * Pascal;
pcWG = @(sw_) pe * sw_.^(-1/2);
fluid.pcWG = @(sg) pcWG(max((1 - sg - srw)./(1 - srw), 1e-5));
%% =========================================================================
%  SECTION A: Configuration
% =========================================================================
T_sim_years = 1000;   % total simulation window [years]

% Paths to CSV files
dataDir      = fullfile(mrstPath('co2lab-ve'), '..', '..', ...
                        'core', 'examples', 'data', 'Johansen', 'data');
wellPlanFile = fullfile(dataDir, 'well_plan.csv');
wellLocFile  = fullfile(dataDir, 'well_loc.csv');

% Fallback: absolute paths if relative resolution fails
if ~exist(wellPlanFile, 'file')
    wellPlanFile = '/Users/apple/Desktop/study/programming/Matlab/Plugins/MRST-2026a/core/examples/data/Johansen/data/well_plan.csv';
    wellLocFile  = '/Users/apple/Desktop/study/programming/Matlab/Plugins/MRST-2026a/core/examples/data/Johansen/data/well_loc.csv';
end

%% =========================================================================
%  SECTION B: Load well_plan.csv and well_loc.csv
% =========================================================================
fprintf('\n=========================================================\n');
fprintf(' JOHANSEN CO2 STORAGE SIMULATION  ---  CSV-driven mode\n');
fprintf('=========================================================\n\n');

fprintf('Reading well_plan.csv ...  %s\n', wellPlanFile);
wellPlan = readtable(wellPlanFile, 'TextType', 'string');
fprintf('  Loaded %d entries from well_plan.csv\n\n', height(wellPlan));

fprintf('Reading well_loc.csv  ...  %s\n', wellLocFile);
wellLoc = readtable(wellLocFile, 'TextType', 'string');
fprintf('  Loaded %d entries from well_loc.csv\n\n', height(wellLoc));

%% =========================================================================
% SECTION C: Lat/lon -> grid conversion + bounds check
% Reference well 31/05/07 is at lat=60.576425, lon=3.443367 -> grid (51,51)
refLat    = 60.576425;  refLon = 3.443367;
refGridI  = 51;         refGridJ = 51;
scaleI    = 55.5  / 0.9;    % cells per degree longitude  (E-W -> I)
scaleJ    = 111.0 / 0.9;    % cells per degree latitude   (N-S -> J)

wellLoc.GridI = round(refGridI + (wellLoc.EW_DEC_DEG - refLon) * scaleI);
wellLoc.GridJ = round(refGridJ + (wellLoc.NS_DEC_DEG - refLat) * scaleJ);

inBounds = wellLoc.GridI >= 1 & wellLoc.GridI <= G.cartDims(1) & ...
           wellLoc.GridJ >= 1 & wellLoc.GridJ <= G.cartDims(2);

fprintf('Well location analysis:\n');
fprintf('  Total wells in well_loc.csv         : %d\n', height(wellLoc));
fprintf('  Within Cartesian bounds (1..%d x 1..%d): %d\n', ...
        G.cartDims(1), G.cartDims(2), sum(inBounds));
fprintf('  Outside bounds (skipped automatically): %d\n\n', sum(~inBounds));

%% =========================================================================
%  SECTION D: Build MRST well struct from plan
% =========================================================================
fprintf('Building wells from well_plan.csv ...\n');
fprintf('%-25s  %-10s  %12s  %10s  %8s  %8s  %6s\n', ...
        'Well', 'Role', 'Rate/BHP', 'Unit', 'StartYr', 'EndYr', 'Status');
fprintf('%s\n', repmat('-',1,85));

W           = [];
wellStartYr = [];   % store per-well for schedule building
wellEndYr   = [];

for p = 1:height(wellPlan)
    wName = char(wellPlan.Well_Bore_Name(p));

    % --- find in well_loc ---
    locIdx = find(strcmp(wellLoc.Well_Bore_Name, wName), 1);
    if isempty(locIdx)
        fprintf('%-25s  SKIPPED (not found in well_loc.csv)\n', wName);
        continue;
    end

    % --- bounds check ---
    if ~inBounds(locIdx)
        fprintf('%-25s  SKIPPED (outside grid bounds, Cartesian %d,%d)\n', ...
                wName, wellLoc.GridI(locIdx), wellLoc.GridJ(locIdx));
        continue;
    end

    gI = wellLoc.GridI(locIdx);
    gJ = wellLoc.GridJ(locIdx);

    % --- perforation layers: plan overrides loc if >0 ---
    perfFrom = wellPlan.Perf_From(p);
    perfTo   = wellPlan.Perf_To(p);
    if perfFrom <= 0
        perfFrom = wellLoc.PERF_FROM(locIdx);
        perfTo   = wellLoc.PERF_TO(locIdx);
    end
    perfK = perfFrom:perfTo;

    % --- active cells ---
    wc_global = false(G.cartDims);
    wc_global(gI, gJ, perfK) = true;
    wc = find(wc_global(G.cells.indexMap));

    if isempty(wc)
        fprintf('%-25s  SKIPPED (no active cells at grid %d,%d layers %d-%d)\n', ...
                wName, gI, gJ, perfFrom, perfTo);
        continue;
    end

    % --- start/end years ---
    startYr = wellPlan.Start_Year(p);
    endYr   = wellPlan.End_Year(p);
    if endYr < 0; endYr = T_sim_years; end

    % Skip wells that are entirely outside the simulation window.
    % Disabled wells use Start_Year=9999 / End_Year=9999 as convention.
    if startYr >= T_sim_years || endYr <= 0
        fprintf('%-25s  DISABLED (Start_Year=%.0f, End_Year=%.0f outside [0, %.0f])\n', ...
                wName, startYr, endYr, T_sim_years);
        continue;
    end

    % --- add well ---
    role = lower(char(wellPlan.Role(p)));
    if strcmp(role, 'injector')
        rateMtYr    = wellPlan.Rate_MtPerYear(p);
        rateKgPerS  = rateMtYr * 1e9 / (365.25 * 24 * 3600);
        rateM3PerS  = rateKgPerS / fluid.rhoGS;
        W = addWell(W, G, rock, wc, ...
                    'Name',   wName, ...
                    'type',   'rate', ...
                    'val',    rateM3PerS, ...
                    'comp_i', [0 1]);   % 100% CO2
        fprintf('%-25s  %-10s  %12.3f  %10s  %8.0f  %8.0f  ADDED\n', ...
                wName, 'Injector', rateMtYr, 'Mt/yr', startYr, endYr);
    else
        % Producer on BHP control
        bhpBar = wellPlan.BHP_bar(p);
        if bhpBar < 0
            % Auto: hydrostatic pressure at perforation depth
            bhpPa  = rhow * g(3) * mean(G.cells.centroids(wc, 3));
            bhpBar = bhpPa / barsa;
        else
            bhpPa = bhpBar * barsa;
        end
        W = addWell(W, G, rock, wc, ...
                    'Name',   wName, ...
                    'type',   'bhp', ...
                    'val',    bhpPa, ...
                    'comp_i', [1 0]);   % 100% brine
        fprintf('%-25s  %-10s  %12.1f  %10s  %8.0f  %8.0f  ADDED\n', ...
                wName, 'Producer', bhpBar, 'bar BHP', startYr, endYr);
    end

    wellStartYr(end+1) = startYr; %#ok<SAGROW>
    wellEndYr(end+1)   = endYr;   %#ok<SAGROW>
end

if isempty(W)
    error(['No valid wells found.\n' ...
           'Check that well_plan.csv names match well_loc.csv\n' ...
           'and that wells have active cells in the Johansen formation.']);
end

nWells = numel(W);
injIdx = find(strcmp({W.type}, 'rate'));
prodIdx= find(strcmp({W.type}, 'bhp'));
fprintf('\nSummary: %d active wells  (%d injectors, %d producers)\n\n', ...
        nWells, numel(injIdx), numel(prodIdx));

%% =========================================================================
%  SECTION E: Well location map
% =========================================================================
if DISPLAY_FIGURES
figure('Color','w');
plotGrid(G, 'facecolor','none','edgealpha',0.1);
hold on;
for w = 1:nWells
    if strcmp(W(w).type, 'rate')
        plotGrid(G, W(w).cells, 'facecolor','red');
    else
        plotGrid(G, W(w).cells, 'facecolor','blue');
    end
end
view(3); axis tight;
title('Well Locations: CO_2 Injectors (red) | Brine Producers (blue)','FontSize',13);

end  % ~HEADLESS
%% =========================================================================
%  Boundary conditions  (unchanged from original)
% =========================================================================
bc    = [];
p_bc  = G.faces.centroids(bcIx, 3) * rhow * g(3);
bc    = addBC(bc, bcIx, 'pressure', p_bc, 'sat', [1, 0]);

%% =========================================================================
% SECTION F: Build schedule from per-well active year ranges
% Algorithm:
fprintf('Building schedule ...\n');

% Gather breakpoints
bpSet = sort(unique([0; wellStartYr(:); wellEndYr(:); T_sim_years]));
bpSet = bpSet(bpSet >= 0 & bpSet <= T_sim_years);

% Containers.Map for control deduplication
ctlMap     = containers.Map('KeyType','char','ValueType','double');
schedule.control = struct('W', {}, 'bc', {});
schedule.step.val     = [];
schedule.step.control = [];

for b = 1:numel(bpSet)-1
    tStart = bpSet(b);
    tEnd   = bpSet(b+1);
    tMid   = 0.5*(tStart + tEnd);

    % Determine well status at tMid
    Wc = W;
    for w = 1:nWells
        sy = wellStartYr(w);
        ey = wellEndYr(w);
        Wc(w).status = double(tMid >= sy && tMid < ey);
        
        % FIX: MRST solvers require rate to be explicitly 0 when shut-in
        if ~Wc(w).status && strcmp(Wc(w).type, 'rate')
            Wc(w).val = 0;
        end
    end

    % Build deduplication key from status vector
    ctlKey = num2str([Wc.status], '%d');

    if isKey(ctlMap, ctlKey)
        ctlIdx = ctlMap(ctlKey);
    else
        ctlIdx = numel(schedule.control) + 1;
        schedule.control(ctlIdx).W  = Wc;
        schedule.control(ctlIdx).bc = bc;
        ctlMap(ctlKey) = ctlIdx;   % store as double
    end

    % Timestep size
    if tEnd <= 50
        dt     = year;
    else
        dt     = 10 * year;
    end
    nSteps = max(1, round((tEnd - tStart) * year / dt));

    schedule.step.val     = [schedule.step.val;     repmat(dt, nSteps, 1)];
    schedule.step.control = [schedule.step.control; repmat(ctlIdx, nSteps, 1)];
end

fprintf('  Controls: %d unique configurations\n', numel(schedule.control));
fprintf('  Timesteps: %d total  (%.0f yr window)\n\n', ...
        numel(schedule.step.val), T_sim_years);

%% =========================================================================
%  Model + Simulate
% =========================================================================
model = TwoPhaseWaterGasModel(G, rock, fluid, 0, 0);

%% =========================================================================
% DIRECTIONAL INJECTION — block all faces except +I (east = left in image)
% Wells 31/01/01, 31/1-3_S, 31/2-5, 31/05/02 are deep-formation injectors.
dirInjNames = {'31/01/01','31/1-3 S','31/05/02'};   % 31/2-5 retired (v6) — persistent BHP breach 400-550 bar
BLOCK_FACTOR = 1e-12;   % near-zero mult for blocked faces

for di = 1:numel(dirInjNames)
    tgtName = dirInjNames{di};
    wIdx    = find(strcmp({W.name}, tgtName));
    if isempty(wIdx)
        fprintf('[DirInj] Well %s not in W (disabled?) — skipping\n', tgtName);
        continue;
    end

    wCells = W(wIdx).cells;   % all perforated cells of this well

    for ci = 1:numel(wCells)
        cellId = wCells(ci);

        % ── Find all faces of this cell ────────────────────────────────
        fStart = G.cells.facePos(cellId);
        fEnd   = G.cells.facePos(cellId + 1) - 1;
        cellFaces = G.cells.faces(fStart:fEnd, 1);   % face global indices

        for fi = 1:numel(cellFaces)
            faceId = cellFaces(fi);
            nbrs   = G.faces.neighbors(faceId, :);

            % Skip boundary faces (one neighbour is 0)
            if any(nbrs == 0); continue; end

            % Centroid vector from this cell to its neighbour
            otherCell = nbrs(nbrs ~= cellId);
            dv = G.cells.centroids(otherCell,:) - G.cells.centroids(cellId,:);

            % Primary direction of the face connection
            [~, dir] = max(abs(dv));   % 1=I/x, 2=J/y, 3=K/z
            signDir  = sign(dv(dir));

            % Keep ONLY +I faces (dir==1, signDir==+1).
            % Block everything else: -I, ±J, ±K.
            if ~(dir == 1 && signDir > 0)
                % Find the index of this face in model.operators.internalConn
                opFaceIdx = find(model.operators.N(:,1) == cellId & ...
                                 model.operators.N(:,2) == otherCell, 1);
                if isempty(opFaceIdx)
                    opFaceIdx = find(model.operators.N(:,1) == otherCell & ...
                                     model.operators.N(:,2) == cellId, 1);
                end
                if ~isempty(opFaceIdx)
                    model.operators.T(opFaceIdx) = ...
                        model.operators.T(opFaceIdx) * BLOCK_FACTOR;
                end
            end
        end
    end
    fprintf('[DirInj] %s — faces blocked (keeping +I / eastward only)\n', tgtName);
end
fprintf('\n');

fprintf('Running simulateScheduleAD ...\n');
[wellSol, states] = simulateScheduleAD(initState, model, schedule);
fprintf('Simulation complete.\n\n');

%% =========================================================================
%  Post-processing helpers
% =========================================================================
tYears = cumsum(schedule.step.val) / year;

% Step index closest to injection end
% injIdx contains indices of rate-type (injector) wells in W.
if ~isempty(injIdx)
    activeInjEndYrs = wellEndYr(injIdx);
    activeInjEndYrs = min(activeInjEndYrs, T_sim_years);   % clip 9999 etc.
    injEndYr = max(activeInjEndYrs);
else
    injEndYr = 0;
end
injEndStep = find(tYears <= injEndYr, 1, 'last');
if isempty(injEndStep); injEndStep = 1; end

fprintf('Injection end year (from CSV): %.0f yr\n', injEndYr);
fprintf('Closest simulated timestep   : step %d / %d  (t = %.1f yr)\n', ...
        injEndStep, numel(tYears), tYears(injEndStep));
fprintf('Simulation end year          : %.1f yr\n\n', tYears(end));

%% =========================================================================
%  Figure 7: CO2 saturation 3D at injection end
% =========================================================================
if DISPLAY_FIGURES
figure('Color','w');
plotCellData(G, states{injEndStep}.s(:,2)); view(-63,68); colorbar;
set(gcf,'position',[531 337 923 356]); axis tight;
title(sprintf('CO_2 Gas Saturation at Year %.0f (End of Injection)', ...
      tYears(injEndStep)), 'FontSize',13);
c = colorbar; c.Label.String = 'CO_2 Saturation (fraction)';


end  % ~HEADLESS
%% =========================================================================
%  Figure 8: CO2 saturation 3D at simulation end
% =========================================================================
if DISPLAY_FIGURES
figure('Color','w');
plotCellData(G, states{end}.s(:,2)); view(-63,68); colorbar;
set(gcf,'position',[531 337 923 356]); axis tight;
title(sprintf('CO_2 Gas Saturation at Year %.0f (End of Simulation)', ...
      tYears(end)), 'FontSize',13);
c = colorbar; c.Label.String = 'CO_2 Saturation (fraction)';


end  % ~HEADLESS
%% =========================================================================
%  Figure 9: Pressure buildup deltaP at injection end
%  Shows where producers are drawing down pressure
% =========================================================================
deltaP = (states{injEndStep}.pressure - initState.pressure) / barsa;
if DISPLAY_FIGURES
figure('Color','w');
plotCellData(G, deltaP); view(-63,68); colorbar;
set(gcf,'position',[531 337 923 356]); axis tight;
title(sprintf('Pressure Buildup \\DeltaP at Year %.0f (bar)', ...
      tYears(injEndStep)), 'FontSize',13);
c = colorbar; c.Label.String = '\DeltaP (bar)';


end  % ~HEADLESS
%% =========================================================================
%  Figures 10-11: Vertical cross-sections through grid j=48
% =========================================================================
[ic, jc, ~] = ind2sub(G.cartDims, G.cells.indexMap);
xsecMask = jc==48 & ic>18 & ic<75;

if DISPLAY_FIGURES
figure('Color','w');
plotCellData(extractSubgrid(G, xsecMask), ...
             states{injEndStep}.s(xsecMask, 2));
view(0,0); axis tight; colorbar;
title(sprintf('Vertical X-Section CO_2 Saturation at Year %.0f (j=48)', ...
      tYears(injEndStep)), 'FontSize',13);
c = colorbar; c.Label.String = 'CO_2 Saturation';

figure('Color','w');
plotCellData(extractSubgrid(G, xsecMask), ...
             states{end}.s(xsecMask, 2));
view(0,0); axis tight; colorbar;
title(sprintf('Vertical X-Section CO_2 Saturation at Year %.0f (j=48)', ...
      tYears(end)), 'FontSize',13);
c = colorbar; c.Label.String = 'CO_2 Saturation';

end  % ~HEADLESS
%% =========================================================================
% Figure 12: CO2 trapping inventory — manual calculation
% postprocessStates3D is designed for a single injector and may silently
fprintf('Computing trapping inventory from simulation states ...\n');

% --- Cell pore volumes and CO2 density at reference conditions
cellPV     = poreVolume(G, rock);          % [m3]  pore volume per cell
rhoc_kgm3  = rhoc;                         % CO2 density at ref P/T [kg/m3]
Mt          = 1e9;                          % kg per Mt

% --- Per-timestep trapping mass (Mt)
nTrap     = numel(states);
t_trap    = tYears(1:nTrap);       % time axis [yr]

mass_free     = zeros(nTrap, 1);   % mobile CO2 in formation
mass_residual = zeros(nTrap, 1);   % immobile residually trapped CO2

for ts = 1:nTrap
    sCO2 = states{ts}.s(:, 2);    % CO2 saturation per cell

    % Free (mobile) CO2: saturation above residual
    s_mobile = max(sCO2 - src, 0);
    mass_free(ts) = sum(s_mobile .* cellPV) * rhoc_kgm3 / Mt;

    % Residual CO2: capped at src, only where CO2 has been
    s_res = min(sCO2, src);
    mass_residual(ts) = sum(s_res .* cellPV) * rhoc_kgm3 / Mt;
end

% --- Cumulative injected mass from wellSol
mass_injected = zeros(nTrap, 1);
sPerYr = 365.25 * 24 * 3600;
for ts = 1:nTrap
    dtThis = schedule.step.val(ts);   % [s]
    for w = 1:nWells
        ws = wellSol{ts}(w);
        if isfield(ws, 'qGs') && ws.qGs > 0
            mass_injected(ts) = mass_injected(ts) + ws.qGs * fluid.rhoGS * dtThis / Mt;
        end
    end
end
mass_injected_cum = cumsum(mass_injected);

% Exited = injected - (free + residual), clipped at 0
mass_exited = max(mass_injected_cum - mass_free - mass_residual, 0);

% --- Plot
if DISPLAY_FIGURES
h1 = figure('Color','w');
ax  = axes(h1);

% Stack: free on top, then residual, then exited (bottom)
% Use area() for stacked fill plot matching MRST canonical style
tPlot = [0; t_trap];   % prepend t=0 with zeros

areaData = [mass_exited, mass_residual, mass_free];
areaData  = [[0 0 0]; areaData];   % add zero row at t=0

ha = area(ax, tPlot, areaData);
ha(1).FaceColor = [1.0, 0.55, 0.0];   % orange   — Exited / Free plume
ha(2).FaceColor = [0.4, 0.85, 0.4];   % light green — Residual in plume
ha(3).FaceColor = [0.0, 0.65, 0.0];   % dark green  — Structural residual

legend(ax, {'Exited / Free plume', 'Residual in plume', 'Trapped residual'}, ...
       'Location', 'northwest', 'FontSize', 10);
xlabel(ax, 'Years since simulation start', 'FontSize', 12);
ylabel(ax, 'Mass (MT)', 'FontSize', 12);
title(ax, 'CO_2 Trapping Mass Inventory Distribution (Mt)', 'FontSize', 13, 'FontWeight', 'bold');
ax.FontSize = 11;
grid(ax, 'on');
xlim(ax, [0 t_trap(end)]);
% User requested: skip saving co2_trapping_inventory.png
fprintf('Trapping inventory plot complete.\n\n');

end  % ~HEADLESS
%% =========================================================================
%  Figure 13: Well performance - injection rate, brine rate, BHPs
% =========================================================================
nSteps  = numel(wellSol);
wellBHP = zeros(nSteps, nWells);
wellQGs = zeros(nSteps, nWells);   % CO2 surface rate [m3/s]
wellQWs = zeros(nSteps, nWells);   % brine surface rate [m3/s]

for s = 1:nSteps
    for w = 1:nWells
        ws = wellSol{s}(w);
        wellBHP(s,w) = ws.bhp / barsa;
        if isfield(ws,'qGs'); wellQGs(s,w) = ws.qGs; end
        if isfield(ws,'qWs'); wellQWs(s,w) = ws.qWs; end
    end
end

sPerYr = 365.25 * 24 * 3600;

% Total CO2 injected rate [Mt/yr]
if ~isempty(injIdx)
    co2MtYr = sum(abs(wellQGs(:,injIdx)), 2) * rhoc * sPerYr / 1e9;
else
    co2MtYr = zeros(nSteps, 1);
end

% Total brine produced rate [Mt/yr]
if ~isempty(prodIdx)
    brineMtYr = sum(abs(wellQWs(:,prodIdx)), 2) * rhow * sPerYr / 1e9;
else
    brineMtYr = zeros(nSteps, 1);
end

% Mass balance running totals [Mt]
dtYr         = schedule.step.val / year;
co2Total     = cumsum(co2MtYr   .* dtYr);
brineTotal   = cumsum(brineMtYr .* dtYr);

if DISPLAY_FIGURES
figure('Color','w','Position',[50 50 1400 550]);

% --- Subplot 1: Rates ---
subplot(1,3,1);
    plot(tYears, co2MtYr,   'r-', 'LineWidth',2.0); hold on;
    plot(tYears, brineMtYr, 'b--','LineWidth',2.0);
    xline(injEndYr,'k:','LineWidth',1.5,'Label','Injection end','LabelVerticalAlignment','bottom');
    xlabel('Time (years)','FontSize',12);
    ylabel('Rate (Mt/yr)','FontSize',12);
    title('CO_2 Injection & Brine Production Rate','FontSize',12);
    legend('CO_2 injected','Brine produced','Location','northeast');
    grid on; set(gca,'FontSize',11);

% --- Subplot 2: Cumulative mass balance ---
subplot(1,3,2);
    plot(tYears, co2Total,   'r-', 'LineWidth',2.0); hold on;
    plot(tYears, brineTotal, 'b--','LineWidth',2.0);
    xline(injEndYr,'k:','LineWidth',1.5,'Label','Injection end','LabelVerticalAlignment','bottom');
    xlabel('Time (years)','FontSize',12);
    ylabel('Cumulative (Mt)','FontSize',12);
    title('Cumulative CO_2 Injected & Brine Produced','FontSize',12);
    legend('CO_2 (total)','Brine (total)','Location','northwest');
    grid on; set(gca,'FontSize',11);

% --- Subplot 3: BHPs ---
subplot(1,3,3);
    colours = lines(nWells);
    wellNames = {W.name};
    for w = 1:nWells
        lStyle = '-';
        if strcmp(W(w).type,'bhp'); lStyle = '--'; end
        plot(tYears, wellBHP(:,w), lStyle, 'Color',colours(w,:), 'LineWidth',1.6);
        hold on;
    end
    xline(injEndYr,'k:','LineWidth',1.5,'Label','Injection end','LabelVerticalAlignment','bottom');
    xlabel('Time (years)','FontSize',12);
    ylabel('BHP (bar)','FontSize',12);
    title('Well Bottom-Hole Pressures','FontSize',12);
    legend(wellNames,'Location','northeast','FontSize',8);
    grid on; set(gca,'FontSize',11);

end  % ~HEADLESS
%% =========================================================================
%  Console summary
% =========================================================================
fprintf('\n=======================================================\n');
fprintf(' SIMULATION COMPLETE - WELL PERFORMANCE SUMMARY\n');
fprintf('=======================================================\n');
fprintf('Simulation window   : %.0f years\n', T_sim_years);
fprintf('Active wells        : %d injectors, %d producers\n', numel(injIdx), numel(prodIdx));
fprintf('Total CO2 injected  : %.3f Mt\n', co2Total(end));
fprintf('Total brine produced: %.3f Mt\n', brineTotal(end));
if ~isempty(injIdx)
    fprintf('Peak injector BHP   : %.1f bar\n', max(max(wellBHP(:,injIdx))));
end
if ~isempty(prodIdx)
    fprintf('Peak producer BHP   : %.1f bar\n', max(max(wellBHP(:,prodIdx))));
end
fprintf('=======================================================\n\n');

%% =========================================================================
% DATA EXPORT — per-well CSV + simulation summary TXT
% For EVERY well in well_loc.csv that has at least one active grid block

fprintf('\n=======================================================\n');
fprintf(' EXPORTING PER-WELL DATA\n');
fprintf('=======================================================\n');

% (outputDir was already created at the start of the script)

%% --- Re-scan ALL wells in well_loc.csv for active grid blocks ---
%  This is independent of well_plan.csv — every in-reservoir well location
%  becomes an observation point whose pressure/saturation is extracted from
%  the simulation states.

% Time vector (already computed)
tVec = tYears;   % [nSteps x 1]  years

% Active-well registry: name, cells, grid position
obsWells = struct('name',{},'gI',{},'gJ',{},'layers',{},'layerCells',{});

for r = 1:height(wellLoc)
    if ~inBounds(r); continue; end   % outside Cartesian box

    gI = wellLoc.GridI(r);
    gJ = wellLoc.GridJ(r);
    
    layersToExtract = 6:10;
    layerCells = cell(length(layersToExtract), 1);
    hasAnyActive = false;
    
    for k_idx = 1:length(layersToExtract)
        k = layersToExtract(k_idx);
        wc_g = false(G.cartDims);
        wc_g(gI, gJ, k) = true;
        wc = find(wc_g(G.cells.indexMap));
        layerCells{k_idx} = wc;
        if ~isempty(wc)
            hasAnyActive = true;
        end
    end

    if ~hasAnyActive; continue; end    % no active cells in layers 6-10

    wNameRaw = char(wellLoc.Well_Bore_Name(r));
    wNameSafe = regexprep(wNameRaw, '[/ ]', '_');
    skip_wells = {'31/5-2 R', '31/2-5 R2', '31/2-5 R', '31_5-2_R', '31_2-5_R2', '31_2-5_R'};
    if ismember(wNameRaw, skip_wells) || ismember(wNameSafe, skip_wells)
        continue;   % User requested: skip generating CSV data for these wells
    end

    entry.name       = wNameRaw;
    entry.gI         = gI;
    entry.gJ         = gJ;
    entry.layers     = layersToExtract;
    entry.layerCells = layerCells;
    obsWells(end+1)  = entry; %#ok<AGROW>
end

fprintf('Found %d in-reservoir observation wells.\n\n', numel(obsWells));

%% =========================================================================
% SECTION G: FULL-BOUNDARY CO2 BREACH SCAN
% Replaces the previous 4 hardcoded point-sample "surveillance wells"
fprintf('Scanning full western boundary for CO2 breach (topmost layer)...\n');

TOP_LAYER        = 6;     % shallowest layer of the old 6:10 perforation range
S_CO2_BREACH_THR = 0.15;  % 15% saturation threshold

nJgrid = G.cartDims(2);
boundary_gI     = [];
boundary_gJ     = [];
boundary_cellId = [];

for gJ = 1:nJgrid
    for gI = 1:G.cartDims(1)
        wc_g = false(G.cartDims);
        wc_g(gI, gJ, TOP_LAYER) = true;
        wc = find(wc_g(G.cells.indexMap));
        if ~isempty(wc)
            boundary_gI(end+1)     = gI;    %#ok<SAGROW>
            boundary_gJ(end+1)     = gJ;    %#ok<SAGROW>
            boundary_cellId(end+1) = wc(1); %#ok<SAGROW>
            break;   % stop at the first (westernmost) active cell for this J-row
        end
    end
end

nBoundaryCells = numel(boundary_cellId);
fprintf('  Found %d boundary cells across %d J-rows (topmost layer = %d)\n', ...
        nBoundaryCells, nJgrid, TOP_LAYER);

if nBoundaryCells > 0
    sCO2_end   = states{end}.s(boundary_cellId, 2);
    breachFlag = double(sCO2_end > S_CO2_BREACH_THR);
else
    breachFlag = [];
end

boundaryT = table(boundary_gI(:), boundary_gJ(:), breachFlag(:), ...
                   'VariableNames', {'cell_x', 'cell_y', 'breach'});
boundaryCsvPath = fullfile(outputDir, 'boundary_breach.csv');
writetable(boundaryT, boundaryCsvPath);

nBoundaryBreached = sum(breachFlag);
fprintf('  Breached cells: %d / %d (%.1f%%)\n', nBoundaryBreached, nBoundaryCells, ...
        100 * nBoundaryBreached / max(nBoundaryCells,1));
fprintf('  -> %s\n\n', boundaryCsvPath);

%% --- Extract and export per-well time-series CSVs ---
nSteps = numel(states);

for ow = 1:numel(obsWells)
    wName      = obsWells(ow).name;
    layers     = obsWells(ow).layers;
    layerCells = obsWells(ow).layerCells;

    % Sanitise well name for use as filename (remove / and spaces)
    safeName = regexprep(wName, '[/ ]', '_');
    skip_wells = {'31/5-2 R', '31/2-5 R2', '31/2-5 R', '31_5-2_R', '31_2-5_R2', '31_2-5_R'};
    if ismember(wName, skip_wells) || ismember(safeName, skip_wells)
        continue;   % Skip requested excluded wells
    end

    % Setup columns: Time_yr, (P_bar_Lx, S_CO2_Lx, Depth_m_Lx) per layer
    numCols = 1 + length(layers) * 3;
    tsMat = zeros(nSteps, numCols);
    
    varNames = {'Time_yr'};
    for k_idx = 1:length(layers)
        k = layers(k_idx);
        varNames{end+1} = sprintf('P_bar_L%d', k);
        varNames{end+1} = sprintf('S_CO2_L%d', k);
        varNames{end+1} = sprintf('Depth_m_L%d', k);
    end

    for t = 1:nSteps
        tsMat(t, 1) = tVec(t);
        col = 2;
        for k_idx = 1:length(layers)
            wc = layerCells{k_idx};
            if isempty(wc)
                tsMat(t, col)   = NaN;
                tsMat(t, col+1) = NaN;
                tsMat(t, col+2) = NaN;
            else
                tsMat(t, col)   = mean(states{t}.pressure(wc)) / barsa;
                tsMat(t, col+1) = mean(states{t}.s(wc, 2));
                tsMat(t, col+2) = mean(G.cells.centroids(wc, 3));
            end
            col = col + 3;
        end
    end

    % Write CSV
    T_export = array2table(tsMat, 'VariableNames', varNames);
    csvPath = fullfile(outputDir, [safeName, '.csv']);
    writetable(T_export, csvPath);

    fprintf('  [%2d/%2d] %-25s -> %s.csv  (%d rows)\n', ...
            ow, numel(obsWells), wName, safeName, nSteps);
end

%% --- Write simulation summary TXT ---
txtPath = fullfile(outputDir, 'simulation_summary.txt');
fid = fopen(txtPath, 'w');

fprintf(fid, '==========================================================\n');
fprintf(fid, '  JOHANSEN CO2 STORAGE SIMULATION — RUN SUMMARY\n');
fprintf(fid, '==========================================================\n');
fprintf(fid, 'Run timestamp        : %s\n', runName);
fprintf(fid, 'Output folder        : %s\n', outputDir);
fprintf(fid, '\n--- SIMULATION CONFIGURATION ---\n');
fprintf(fid, 'Simulation window    : %.0f years\n', T_sim_years);
fprintf(fid, 'Total timesteps      : %d\n', nSteps);
fprintf(fid, 'Injection end year   : %.0f years\n', injEndYr);
fprintf(fid, 'Grid dimensions      : %d x %d x %d (Cartesian)\n', ...
        G.cartDims(1), G.cartDims(2), G.cartDims(3));
fprintf(fid, 'Active cells         : %d\n', G.cells.num);
fprintf(fid, '\n--- FLUID MODEL ---\n');
fprintf(fid, 'Reference pressure   : %.1f bar\n', p_ref / barsa);
fprintf(fid, 'Reference temperature: %.1f deg C\n', t_ref - 273.15);
fprintf(fid, 'CO2 density (ref)    : %.2f kg/m3\n', rhoc);
fprintf(fid, 'Brine density        : %.1f kg/m3\n', rhow);
fprintf(fid, 'Residual brine sat.  : %.2f\n', srw);
fprintf(fid, 'Residual CO2 sat.    : %.2f\n', src);
fprintf(fid, '\n--- ACTIVE PLAN WELLS (from well_plan.csv) ---\n');
fprintf(fid, '%-25s  %-10s  %12s  %10s  %8s  %8s\n', ...
        'Well', 'Role', 'Rate/BHP', 'Unit', 'StartYr', 'EndYr');
fprintf(fid, '%s\n', repmat('-', 1, 78));
for w = 1:nWells
    if strcmp(W(w).type, 'rate')
        roleStr = 'Injector';
        valStr  = sprintf('%.3f Mt/yr', W(w).val * fluid.rhoGS * 3.1557e7 / 1e9);
        unitStr = 'Mt/yr';
    else
        roleStr = 'Producer';
        valStr  = sprintf('%.1f bar', W(w).val / barsa);
        unitStr = 'bar BHP';
    end
    fprintf(fid, '%-25s  %-10s  %12s  %10s  %8.0f  %8.0f\n', ...
            W(w).name, roleStr, valStr, unitStr, ...
            wellStartYr(w), wellEndYr(w));
end
fprintf(fid, '\n--- MASS BALANCE ---\n');
fprintf(fid, 'Total CO2 injected   : %.4f Mt\n', co2Total(end));
fprintf(fid, 'Total brine produced : %.4f Mt\n', brineTotal(end));
if ~isempty(injIdx)
    % Overall peak (kept for backward compatibility)
    fprintf(fid, 'Peak injector BHP    : %.2f bar\n', max(max(wellBHP(:,injIdx))));
    % Per-injector peak BHP — read by BO notebook for Condition 1
    fprintf(fid, '\n--- PER-INJECTOR PEAK BHP (bar) ---\n');
    for w_idx = 1:nWells
        if ismember(w_idx, injIdx)
            peak_bhp_w = max(wellBHP(:, w_idx));
            fprintf(fid, 'BHP_WELL %-25s : %.2f bar\n', W(w_idx).name, peak_bhp_w);
        end
    end
end
fprintf(fid, '\n--- BOUNDARY CO2 BREACH SCAN (Condition 2 — full-boundary scan) ---\n');
fprintf(fid, 'Topmost perforated layer scanned : %d\n', TOP_LAYER);
fprintf(fid, 'S_CO2 breach threshold           : %.0f%%\n', S_CO2_BREACH_THR * 100);
fprintf(fid, 'Boundary cells scanned           : %d (one per J-row, westernmost active cell)\n', nBoundaryCells);
fprintf(fid, 'Cells breached                   : %d (%.1f%%)\n', nBoundaryBreached, ...
        100 * nBoundaryBreached / max(nBoundaryCells,1));
fprintf(fid, 'CSV file                         : boundary_breach.csv\n');
fprintf(fid, '\n--- OBSERVATION WELLS IN RESERVOIR (all wells with active cells) ---\n');
fprintf(fid, '%-25s  %6s  %6s  %6s  %6s  %12s  %20s\n', ...
        'Well', 'GridI', 'GridJ', 'LayFr', 'LayTo', 'Depth_m', 'CSV_file');
fprintf(fid, '%s\n', repmat('-', 1, 90));
for ow = 1:numel(obsWells)
    safeName  = regexprep(obsWells(ow).name, '[/ ]', '_');
    
    % Compute mean depth over all extracted layers
    allCells = vertcat(obsWells(ow).layerCells{:});
    meanDepth = mean(G.cells.centroids(allCells, 3));
    minLayer = min(obsWells(ow).layers);
    maxLayer = max(obsWells(ow).layers);

    fprintf(fid, '%-25s  %6d  %6d  %6d  %6d  %12.1f  %20s\n', ...
            obsWells(ow).name, obsWells(ow).gI, obsWells(ow).gJ, ...
            minLayer, maxLayer, ...
            meanDepth, [safeName, '.csv']);
end
fprintf(fid, '\n--- CSV COLUMN DEFINITIONS ---\n');
fprintf(fid, 'Time_yr          : Simulation time [years since t=0]\n');
fprintf(fid, 'P_bar_L<k>       : Mean reservoir pressure at grid layer k [bar]\n');
fprintf(fid, 'S_CO2_L<k>       : Mean CO2 gas saturation at grid layer k [0-1 fraction]\n');
fprintf(fid, 'Depth_m_L<k>     : Mean depth of active cells in layer k [m below sea level]\n');
fprintf(fid, '\nNOTE: Pressure and saturation are per-layer spatial means over all active\n');
fprintf(fid, 'cells at that well location. For plan wells (injectors\n');
fprintf(fid, 'and producers), the wellSol BHP is the true wellbore pressure.\n');
fprintf(fid, '\nNOTE: boundary_breach.csv (cell_x, cell_y, breach) covers the FULL western\n');
fprintf(fid, 'boundary of the reservoir footprint at layer %d, checked at simulation end\n', TOP_LAYER);
fprintf(fid, 'against the %.0f%% S_CO2 threshold -- this is the authoritative source for\n', S_CO2_BREACH_THR*100);
fprintf(fid, 'Condition 2 (CO2 plume boundary breach), not the per-well CSVs above.\n');
fprintf(fid, '==========================================================\n');

fclose(fid);

%% --- Save Figures to Output Folder ---
try
    fprintf('Saving figures to output folder ...\n');
    allowedFigs = { ...
        'pressure_buildup_injection_end.png', ...
        'saturation_3d_injection_end.png', ...
        'saturation_3d_simulation_end.png', ...
        'saturation_xsec_injection_end.png', ...
        'saturation_xsec_simulation_end.png', ...
        'well_performance.png' ...
    };

    figHandles = findobj('Type', 'figure');
    for f = 1:numel(figHandles)
        figObj = figHandles(f);
        % Find axes inside this figure to retrieve the title
        axObj = findobj(figObj, 'Type', 'axes');
        figTitle = '';
        if ~isempty(axObj)
            for a = 1:numel(axObj)
                if ~isempty(axObj(a).Title.String)
                    figTitle = axObj(a).Title.String;
                    if iscell(figTitle)
                        figTitle = strjoin(figTitle, ' ');
                    end
                    break;
                end
            end
        end
        
        % Map title string to safe file name (only for allowed figures)
        figName = '';
        if contains(lower(figTitle), 'pressure buildup')
            figName = 'pressure_buildup_injection_end.png';
        elseif contains(lower(figTitle), 'end of injection')
            figName = 'saturation_3d_injection_end.png';
        elseif contains(lower(figTitle), 'end of simulation')
            figName = 'saturation_3d_simulation_end.png';
        elseif contains(lower(figTitle), 'vertical x-section') && contains(lower(figTitle), sprintf('year %.0f', tYears(injEndStep)))
            figName = 'saturation_xsec_injection_end.png';
        elseif contains(lower(figTitle), 'vertical x-section') && contains(lower(figTitle), sprintf('year %.0f', tYears(end)))
            figName = 'saturation_xsec_simulation_end.png';
        elseif contains(lower(figTitle), 'brine production rate') || contains(lower(figTitle), 'bottom-hole pressures') || contains(lower(figTitle), 'cumulative co_2')
            figName = 'well_performance.png';
        end
        
        % Fallback for well performance figure (multi-subplot)
        if isempty(figName) && figObj.Number == 13
            figName = 'well_performance.png';
        end
        
        % Save ONLY if figName is in the 6 requested figures!
        if ~isempty(figName) && ismember(figName, allowedFigs)
            % Add well markers for 3D plots
            if contains(figName, 'saturation_3d') || contains(figName, 'pressure_buildup')
                figure(figObj);
                hold on;
                h_inj = []; h_obs = [];
                injNames = {};
                % 1. Plot injectors from W
                for w_idx = 1:numel(W)
                    if strcmp(W(w_idx).type, 'rate')
                        injNames{end+1} = W(w_idx).name;
                        wc = W(w_idx).cells(1);
                        xw = G.cells.centroids(wc,1); yw = G.cells.centroids(wc,2); zw = G.cells.centroids(wc,3) - 100;
                        h1 = plot3(xw, yw, zw, 'kv', 'MarkerFaceColor', 'r', 'MarkerSize', 8);
                        if isempty(h_inj), h_inj = h1; end
                    end
                end
                % 2. Plot surveillance from obsWells
                for ow = 1:numel(obsWells)
                    % Skip injectors (they are already plotted as red triangles)
                    if ismember(obsWells(ow).name, injNames)
                        continue;
                    end
                    % obsWells is defined after W but before this save loop
                    allCells = vertcat(obsWells(ow).layerCells{:});
                    if ~isempty(allCells)
                        wc = allCells(1);
                        xw = G.cells.centroids(wc,1); yw = G.cells.centroids(wc,2); zw = G.cells.centroids(wc,3) - 100;
                        h2 = plot3(xw, yw, zw, 'ko', 'MarkerFaceColor', 'b', 'MarkerSize', 8);
                        if isempty(h_obs), h_obs = h2; end
                    end
                end
                leg_h = []; leg_str = {};
                if ~isempty(h_inj), leg_h(end+1) = h_inj; leg_str{end+1} = 'Injector'; end
                if ~isempty(h_obs), leg_h(end+1) = h_obs; leg_str{end+1} = 'Surveillance'; end
                if ~isempty(leg_h), legend(leg_h, leg_str, 'Location', 'northeast'); end
            end
            
            saveas(figObj, fullfile(outputDir, figName));
            fprintf('  Saved Figure %d -> %s\n', figObj.Number, figName);
        end
    end
catch figErr
    fprintf('Warning: Could not save figures: %s\n', figErr.message);
end

fprintf('\n  Summary TXT -> simulation_summary.txt\n');
fprintf('=======================================================\n');
fprintf(' Export complete. %d CSVs, Figures + 1 TXT written to:\n', numel(obsWells));
fprintf(' %s\n', outputDir);
fprintf('=======================================================\n\n');

%% =========================================================================
% BO Handshake Signal
% Write bo_signal.json so the Python optimizer knows this run is complete.
boSignalPath = fullfile('/Users/apple/Desktop/study/programming/Matlab/Plugins/', ...
    'MRST-2026a/core/examples/data/Johansen/python/bo_signal.json');
boSignalData = sprintf('{"run_folder": "%s", "timestamp": "%s", "status": "done"}', ...
    strrep(outputDir, '\', '/'), datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fid = fopen(boSignalPath, 'w');
if fid ~= -1
    fprintf(fid, '%s\n', boSignalData);
    fclose(fid);
    fprintf('[BO Signal] Written -> %s\n', boSignalPath);
else
    fprintf('[BO Signal] WARNING: Could not write signal file.\n');
end



%%