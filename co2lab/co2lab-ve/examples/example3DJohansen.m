%% 3D, two-phase Johansen CO2 Storage Simulation  ― CSV-Driven Version
%
%  PURPOSE
%  -------
%  Physically accurate CCS capacity assessment for the Johansen aquifer.
%  Uses real CO2 equation-of-state fluid properties, Corey relative
%  permeability with residual saturations, capillary pressure, and
%  hydrostatic open-boundary conditions.
%
%  SCENARIO CONTROL (NO CODE EDITING REQUIRED)
%  --------------------------------------------
%  Edit  data/Johansen/data/well_plan.csv  to:
%    - Change a well role:  Injector -> Producer (or vice versa)
%    - Change injection rate: Rate_MtPerYear column
%    - Change producer BHP:   BHP_bar column (or -1 = auto hydrostatic)
%    - Change active period:  Start_Year / End_Year columns
%  Then simply re-run this script.
%
%  OUTPUTS
%  -------
%    Figure 1-3  : Grid porosity + permeability maps
%    Figure 4-5  : Rel-perm curves (before/after endpoint scaling)
%    Figure 6    : Well location map (coloured by role)
%    Figure 7    : CO2 saturation 3D map at injection end
%    Figure 8    : CO2 saturation 3D map at simulation end
%    Figure 9    : Pressure buildup (delta-P) map at injection end
%    Figure 10   : Vertical cross-section CO2 saturation at injection end
%    Figure 11   : Vertical cross-section CO2 saturation at simulation end
%    Figure 12   : CO2 trapping inventory (postprocessStates3D / MRST canonical)
%    Figure 13   : CO2 injection rate vs brine production rate + BHPs
%
%  REFERENCE PHYSICS (unchanged from original example3DJohansen.m)
%  ----------------------------------------------------------------
%    Fluid  : CO2props() EOS tables at 94 deg-C, 300 bar
%    krW/krG: Corey n=2, srw=0.27, src=0.20
%    Pc     : pe * Sw^(-0.5), pe = 5 kPa
%    BC     : Open hydrostatic boundaries on all lateral faces

%% =========================================================================
%  Load modules
% =========================================================================
mrstModule add ad-core ad-props ad-blackoil
mrstModule add co2lab-common co2lab-ve co2lab-spillpoint
mrstModule add coarsegrid

%% =========================================================================
%  Grid and rock
% =========================================================================
[G, rock, bcIx] = makeJohansenVEgrid();

figure; plotCellData(G, rock.poro); view(-35,15); colorbar;
set(gcf,'position',[531 337 923 356]); axis tight;
title('Porosity','FontSize',12);

figure; plotCellData(G, rock.perm(:,1)/darcy); view(-55,60); colorbar;
set(gcf,'position',[152 419 1846 700],'color','white'); axis tight;
set(gca,'fontsize',24); title('Lateral Permeability (mD)','FontSize',12);

figure; plotCellData(G, rock.perm(:,3)/darcy); view(-55,60); colorbar;
set(gcf,'position',[152 419 1846 700],'color','white'); axis tight;
set(gca,'fontsize',24); title('Vertical Permeability (mD)','FontSize',12);

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
figure; hold on;
plot(sw, fluid.krW(sw),   'b', 'LineWidth', 1.5);
plot(sw, fluid.krG(1-sw), 'r', 'LineWidth', 1.5);
xlabel('Brine saturation'); ylabel('Relative permeability');
title('Rel-perm curves (before endpoint scaling)','FontSize',12);
set(gca,'FontSize',12); legend('krW','krG');

% Endpoint scaling: residual saturations
srw = 0.27;   % residual brine saturation
src = 0.20;   % residual CO2 saturation
fluid.krW = @(s) fluid.krW(max((s - srw)./(1 - srw), 0));
fluid.krG = @(s) fluid.krG(max((s - src)./(1 - src), 0));

% Rel-perm after endpoint scaling
figure; hold on;
sw2 = linspace(srw, 1, 200);
plot(sw2, fluid.krW(sw2),   'b', 'LineWidth', 1.5);
plot(sw2, fluid.krG(1-sw2), 'r', 'LineWidth', 1.5);
line([srw, srw], [0 1], 'color', 'k', 'linestyle', ':', 'LineWidth', 1);
xlabel('Brine saturation'); ylabel('Relative permeability');
title(sprintf('Rel-perm after endpoint scaling  (srw=%.2f, src=%.2f)', srw, src),'FontSize',12);
set(gca,'FontSize',12,'xlim',[0 1]); legend('krW','krG');

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
%  SECTION C: Lat/lon -> grid conversion + bounds check
% =========================================================================
%  Reference well 31/05/07 is at lat=60.576425, lon=3.443367 -> grid (51,51)
%  Scale factors for the Johansen sector grid:
%    1 deg latitude  ~ 111.0 km / 0.9 km_per_cell = 123.3 cells/deg
%    1 deg longitude ~ 55.5  km / 0.9 km_per_cell =  61.7 cells/deg (at 60 N)
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

%% =========================================================================
%  Boundary conditions  (unchanged from original)
% =========================================================================
bc    = [];
p_bc  = G.faces.centroids(bcIx, 3) * rhow * g(3);
bc    = addBC(bc, bcIx, 'pressure', p_bc, 'sat', [1, 0]);

%% =========================================================================
%  SECTION F: Build schedule from per-well active year ranges
%
%  Algorithm:
%    1. Collect all Start_Year / End_Year values as "breakpoints"
%    2. Sort + deduplicate to get intervals [b(k), b(k+1)]
%    3. For each interval, determine active wells -> one control struct
%    4. Deduplicate controls (same active-well set = same control index)
%    5. Within each interval: 1-yr timesteps if tEnd<=50, else 10-yr
% =========================================================================
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

fprintf('Running simulateScheduleAD ...\n');
[wellSol, states] = simulateScheduleAD(initState, model, schedule);
fprintf('Simulation complete.\n\n');

%% =========================================================================
%  Post-processing helpers
% =========================================================================
tYears = cumsum(schedule.step.val) / year;

% Step index closest to injection end
% injIdx contains indices of rate-type (injector) wells in W.
% wellEndYr(injIdx) gives the End_Year for each injector.
% Clip to T_sim_years first: disabled wells carry End_Year=9999 which
% must not contaminate this computation.
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
figure('Color','w');
plotCellData(G, states{injEndStep}.s(:,2)); view(-63,68); colorbar;
set(gcf,'position',[531 337 923 356]); axis tight;
title(sprintf('CO_2 Gas Saturation at Year %.0f (End of Injection)', ...
      tYears(injEndStep)), 'FontSize',13);
c = colorbar; c.Label.String = 'CO_2 Saturation (fraction)';

%% =========================================================================
%  Figure 8: CO2 saturation 3D at simulation end
% =========================================================================
figure('Color','w');
plotCellData(G, states{end}.s(:,2)); view(-63,68); colorbar;
set(gcf,'position',[531 337 923 356]); axis tight;
title(sprintf('CO_2 Gas Saturation at Year %.0f (End of Simulation)', ...
      tYears(end)), 'FontSize',13);
c = colorbar; c.Label.String = 'CO_2 Saturation (fraction)';

%% =========================================================================
%  Figure 9: Pressure buildup deltaP at injection end
%  Shows where producers are drawing down pressure
% =========================================================================
deltaP = (states{injEndStep}.pressure - initState.pressure) / barsa;
figure('Color','w');
plotCellData(G, deltaP); view(-63,68); colorbar;
set(gcf,'position',[531 337 923 356]); axis tight;
title(sprintf('Pressure Buildup \\DeltaP at Year %.0f (bar)', ...
      tYears(injEndStep)), 'FontSize',13);
c = colorbar; c.Label.String = '\DeltaP (bar)';

%% =========================================================================
%  Figures 10-11: Vertical cross-sections through grid j=48
% =========================================================================
[ic, jc, ~] = ind2sub(G.cartDims, G.cells.indexMap);
xsecMask = jc==48 & ic>18 & ic<75;

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

%% =========================================================================
%  Figure 12: CO2 trapping inventory (MRST canonical)
%
%  postprocessStates3D requires all wells to be rate-type injectors.
%  We pass an injector-only schedule: physics of states are unchanged.
% =========================================================================
% Build injector-only schedule for postprocessStates3D.
%
% CRITICAL: postprocessStates3D reads W.val to compute injected mass but
% does NOT check W.status. A shut-in injector (status=0, val=3.5 Mt/yr)
% would be counted as injecting for every timestep it appears, causing a
% massively overcounted "Exited" band in the trapping inventory.
%
% Fix: keep only rate-type wells AND zero out val for status=0 wells.
schedule_inj = schedule;
for ci = 1:numel(schedule_inj.control)
    Wci = schedule_inj.control(ci).W;
    % Step 1: drop all producer (bhp) wells
    Wci = Wci(strcmp({Wci.type}, 'rate'));
    % Step 2: for every rate well that is shut-in, zero its injection rate
    for ww = 1:numel(Wci)
        if ~Wci(ww).status
            Wci(ww).val = 0;
        end
    end
    schedule_inj.control(ci).W = Wci;
end

fprintf('Running postprocessStates3D for trapping inventory ...\n');
reports = postprocessStates3D(G, [{initState}; states], rock, fluid, ...
                               schedule_inj, srw, src);

h1 = figure('Color','w'); plot(1); ax = get(h1,'currentaxes');
plotTrappingDistribution(ax, reports, 'legend_location','northwest');
title('CO_2 Trapping Mass Inventory Distribution (Mt)','FontSize',13);

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

%%
% <html>
% <p><font size="-1">
% Copyright 2009-2026 SINTEF Digital, Mathematics & Cybernetics.
% </font></p>
% <p><font size="-1">
% This file is part of The MATLAB Reservoir Simulation Toolbox (MRST).
% </font></p>
% <p><font size="-1">
% MRST is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% </font></p>
% </html>
