function WellCoordinateMapper()

%% ==========================================================
% WELL COORDINATE MAPPER
%
% Uses ONE known reference well.
% Assumes:
%   X increases eastwards
%   Y increases northwards
%
% Treats the entire field as a flat plane.
%% ==========================================================

%% ===========================
% HARD CODE YOUR REFERENCE WELL
%% ===========================

refLat = 60.576425;      % <-- CHANGE
refLon = 3.443367;       % <-- CHANGE

refX = 51;               % <-- CHANGE
refY = 51;               % <-- CHANGE

%% Approximate simulator cell size (metres)

cellSize = 100;          % <-- CHANGE IF REQUIRED

%% Earth radius

R = 6378137;

%% ===========================
% GUI
%% ===========================

f = figure( ...
    'Name','Well Coordinate Mapper', ...
    'Position',[500 300 420 260], ...
    'MenuBar','none', ...
    'NumberTitle','off', ...
    'Resize','off');

uicontrol(f,...
    'Style','text',...
    'Position',[20 220 150 20],...
    'String','New Well Latitude',...
    'HorizontalAlignment','left');

latBox = uicontrol(f,...
    'Style','edit',...
    'Position',[170 220 180 25]);

uicontrol(f,...
    'Style','text',...
    'Position',[20 180 150 20],...
    'String','New Well Longitude',...
    'HorizontalAlignment','left');

lonBox = uicontrol(f,...
    'Style','edit',...
    'Position',[170 180 180 25]);

resultText = uicontrol(f,...
    'Style','text',...
    'Position',[20 20 370 110],...
    'HorizontalAlignment','left',...
    'FontSize',11,...
    'String','');

uicontrol(f,...
    'Style','pushbutton',...
    'String','Suggest Coordinates',...
    'Position',[120 140 170 30],...
    'Callback',@calculate);

%% ===========================
% CALLBACK
%% ===========================

    function calculate(~,~)

        lat = str2double(latBox.String);
        lon = str2double(lonBox.String);

        if isnan(lat) || isnan(lon)

            errordlg('Enter valid latitude and longitude.');

            return

        end

        %% -----------------------------
        % Local planar approximation
        %% -----------------------------

        dLat = deg2rad(lat-refLat);
        dLon = deg2rad(lon-refLon);

        north = R*dLat;

        east = R*cosd(refLat)*dLon;

        %% Convert metres -> simulator coordinates

        simX = refX + east/cellSize;

        simY = refY + north/cellSize;

        %% Display

        resultText.String = sprintf([ ...
            'East Offset  : %.1f m\n' ...
            'North Offset : %.1f m\n\n' ...
            'Suggested X  : %.2f\n' ...
            'Suggested Y  : %.2f\n\n' ...
            'Rounded Cell : (%d,%d)'], ...
            east,...
            north,...
            simX,...
            simY,...
            round(simX),...
            round(simY));

    end

end