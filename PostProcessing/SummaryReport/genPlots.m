% GENPLOTS Generate plots for the summary report and save them as .png
% figures.
%
% We will process all the data collected and duplicate the folder structure
% for them into a "PostProcessingResults/SummaryReport/plots" folder under
% the shared Google Drive folder.
%
% Yaguang Zhang, Purdue, 07/11/2017

clear; clc; close all;

%% Configurations

% The absolute path to the shared Google Drive folder "Annapolis
% Measurement Campaign". Please make sure it is correct for the machine
% which will run this script.
%     On Mac Lemma: '/Users/zhan1472/Google Drive/Annapolis Measurement
%      Campaign';
%  On Windows Dell: '\\LEMMA\Google Drive\Annapolis Measurement Campaign';
ABS_PATH_TO_EARS_SHARED_FOLDER = ...
    '/Users/zhan1472/Google Drive/Annapolis Measurement Campaign';

% Flags to enable coresponding plot functions.
FLAG_PLOT_GPS_FOR_EACH_DAY = false;
FLAG_PLOT_FIRST_SEVERAL_MEAS_PER_SERIES = true;

% Configure other paths accordingly.
ABS_PATH_TO_DATA = fullfile(ABS_PATH_TO_EARS_SHARED_FOLDER, 'Data');
ABS_PATH_TO_SAVE_PLOTS = fullfile(ABS_PATH_TO_EARS_SHARED_FOLDER, ...
    'PostProcessingResults', 'SummaryReport', 'plots');

% The number of measurements that are considered for each site, i.e. there
% will be numMeasToPlotPerSeries plots generated for the signals located in
% one "Series_xx" folder.
numMeasToPlotPerSeries = 3;

%% Before Generating the Plots

disp(' ---------- ')
disp('  genPlots')
disp(' ---------- ')

% Disable the tex interpreter in figures.
set(0,'DefaultTextInterpreter','none');

% Add libs to current path.
cd(fileparts(mfilename('fullpath')));
addpath(fullfile(pwd));
cd('..'); setPath;

% Create directories if necessary.
if exist(ABS_PATH_TO_SAVE_PLOTS, 'dir')~=7
    mkdir(ABS_PATH_TO_SAVE_PLOTS);
end

% Find all the parent directories for "Series_xx" data folders using regex.
disp(' ')
disp('    Searching for "Series" data folders...')
allSeriesParentDirs = rdir(fullfile(ABS_PATH_TO_DATA, '**', '*'), ...
    'regexp(name, ''(_LargeScale$)|(_SIMO$)|(_Conti$)'')');
% Also locate all the "Series_xx" data folders for each parent directory.
allSeriesDirs = cell(length(allSeriesParentDirs),1);
for idxPar = 1:length(allSeriesParentDirs)
    assert(allSeriesParentDirs(idxPar).isdir, ...
        ['#', num2str(idxPar), ' series parent dir should be a folder!']);
    
    curSeriesDirs = rdir(fullfile(allSeriesParentDirs(idxPar).name, '**', '*'), ...
        'regexp(name, ''(Series_\d+$)'')');
    if(isempty(curSeriesDirs))
        warning(['#', num2str(idxPar), ...
            ' series parent dir does not have any series subfolders!']);
    end
    allSeriesDirs{idxPar} = curSeriesDirs;
end
disp('    Done!')

%% Google Maps for Each Parent Folder

if FLAG_PLOT_GPS_FOR_EACH_DAY
    disp(' ')
    disp('  => Plotting GPS samples on Google map...')
    for idxPar = 1:length(allSeriesParentDirs)
        disp([num2str(idxPar), '/', num2str(length(allSeriesParentDirs))])
        PATH_FOLDER_TO_PROCESS = allSeriesParentDirs(idxPar).name;
        
        % For each folder, read in all the GPS log files.
        dirsToProcess = dir(PATH_FOLDER_TO_PROCESS);
        seriesGpsS = cell(length(dirsToProcess),1);
        for idxDir = 1:length(dirsToProcess)
            if dirsToProcess(idxDir).isdir
                % Check the folder's name.
                idxSeriesTokens = regexp(dirsToProcess(idxDir).name, ...
                    '^Series_(\d+)$', 'tokens');
                if(length(idxSeriesTokens)==1)
                    idxSeries = str2double(idxSeriesTokens{1}{1});
                    gpsLogs = rdir(fullfile(PATH_FOLDER_TO_PROCESS, ...
                        ['Series_', num2str(idxSeries)],'*_GPS.log'));
                    % Load the GPS samples.
                    seriesGpsS{idxDir} = arrayfun(...
                        @(log) parseGpsLog(log.name), gpsLogs);
                end
            end
        end
        % Remove empty cells.
        seriesGpsS = seriesGpsS(~cellfun('isempty',seriesGpsS));
        
        % Plot each GPS sample on a google map.
        seriesColors = colormap(parula);
        [numSeriesColors, ~] = size(seriesColors);
        indicesColorToUse = randi([1 numSeriesColors],1,length(seriesGpsS));
        close all;
        hFigGpsOnMap = figure; hold on;
        markerSize = 10;
        for idxSeries = 1:length(seriesGpsS)
            colorToUse = seriesColors(indicesColorToUse(idxSeries),:);
            for idxGpsS = 1:length(seriesGpsS{idxSeries})
                gpggaStr = seriesGpsS{idxSeries}(idxGpsS).gpsLocation;
                gpsLoc = nmealineread(gpggaStr);
                % Add a minus sign if it is W or S.
                if(isW(gpggaStr))
                    gpsLoc.longitude = -gpsLoc.longitude;
                end
                if(isS(gpggaStr))
                    gpsLoc.latitude = -gpsLoc.latitude;
                end
                % Only plot valid points.
                if (gpsLoc.latitude~=0 && gpsLoc.longitude~=0)
                    % Differenciate GPS locked samples and not locked ones.
                    if(str2double(seriesGpsS{idxSeries}(idxGpsS).gpsLocked))
                        % Locked.
                        hLockedNew = plot(gpsLoc.longitude, gpsLoc.latitude, ...
                            '.', 'Color', colorToUse, 'MarkerSize', markerSize);
                        if isvalid(hLockedNew)
                            hLocked = hLockedNew;
                        end
                    else
                        % Not locked.
                        hUnLockedNew = plot(gpsLoc.longitude, gpsLoc.latitude, ...
                            'x', 'Color', colorToUse, 'MarkerSize', markerSize);
                        if isvalid(hUnLockedNew)
                            hUnLocked = hUnLockedNew;
                        end
                    end
                end
            end
        end
        plot_google_map('MapType', 'satellite');
        hold off;
        if exist('hUnLocked', 'var')
            legend([hLocked, hUnLocked], 'Locked','Unlocked');
        elseif exist('hLocked', 'var')
            legend([hLocked], 'Locked');
        end
        clear hLocked hUnLocked;
        [~, seriesParentDirName] = fileparts(allSeriesParentDirs(idxPar).name);
        title(seriesParentDirName, 'Interpreter', 'none');
        
        % Save the plot.
        pathFileToSave = fullfile(ABS_PATH_TO_SAVE_PLOTS, ...
            [seriesParentDirName, '_gpsSamplesOnMap']);
        saveas(hFigGpsOnMap, [pathFileToSave, '.fig']);
        saveas(hFigGpsOnMap, [pathFileToSave, '.png']);
    end
    disp('     Done!')
end

%% Verify Signal Present for the First numMeasToPlotPerSeries Measurements

if FLAG_PLOT_FIRST_SEVERAL_MEAS_PER_SERIES
    disp(' ')
    disp('  => Plotting the first estimated signal for a few measurement on each site...')
    for idxPar = 1:length(allSeriesParentDirs)
        disp(['Loading data for parent dir ', num2str(idxPar), '/', ...
            num2str(length(allSeriesParentDirs)), '...'])
        PATH_FOLDER_TO_PROCESS = allSeriesParentDirs(idxPar).name;
        % Use this to limit what subfolders will be processed.
        subfolderPattern = '^Series_(\d+)$';
        
        % For each folder, read in all the .out files needed. To save
        % memory, we will generate plots for each series, one by one.
        dirsToProcess = dir(PATH_FOLDER_TO_PROCESS);
        numSeriesInParDir = length(rdir(fullfile(PATH_FOLDER_TO_PROCESS, '*'), ...
            'regexp(name, ''(Series_\d+$)'')'));
        for idxDir = 1:length(dirsToProcess)
            if dirsToProcess(idxDir).isdir
                % Check the folder's name.
                idxSeriesTokens = regexp(dirsToProcess(idxDir).name, ...
                    subfolderPattern, 'tokens');
                if(length(idxSeriesTokens)==1)
                    idxSeries = str2double(idxSeriesTokens{1}{1});
                    signalFilteredLogs = rdir(fullfile(PATH_FOLDER_TO_PROCESS, ...
                        ['Series_', num2str(idxSeries)],'*_filtered.out'));
                    % Ignore measurements that will not be used.
                    signalFilteredLogs = signalFilteredLogs(1:min( ...
                        [numMeasToPlotPerSeries; length(signalFilteredLogs)]));
                    % Load the signal samples. The integer countSam is to limit the number samples to load.
                    countSam = 1.04*(10^6); % ~ 1s of the signal.
                    seriesSignalFiltered = arrayfun(...
                        @(log) read_complex_binary(log.name, countSam), ...
                        signalFilteredLogs, ...
                        'UniformOutput', false);
                    seriesSignal = arrayfun(...
                        @(log) read_complex_binary(...
                        regexprep(log.name, '_filtered',''), countSam),...
                        signalFilteredLogs, ...
                        'UniformOutput', false);
                    if (length(seriesSignal)<numMeasToPlotPerSeries)
                        warning(['#', num2str(idxPar), ...
                            ' series parent folder does not have enough valid measuremnts loaded!']);
                    end
                    if ~isempty(seriesSignalFiltered)
                        % Plot the signals. We will try to find the "tallest" bump for each
                        % measurement.
                        numPreSamples = 200;
                        numPostSamples = 2000;
                        
                        disp(['Generating plots for series ', num2str(idxSeries), '/', ...
                            num2str(numSeriesInParDir), '...'])
                        for idxSignalFiles = 1:length(seriesSignal)
                            close all;
                            [~, seriesParentDirName] = fileparts(allSeriesParentDirs(idxPar).name);
                            figureSupTitle = [seriesParentDirName, ': Series ', num2str(idxSeries), ...
                                ' - ', num2str(idxSignalFiles)];
                            hFigSigFiltered = plotOnePresentSignal(...
                                seriesSignalFiltered{idxSignalFiles}, ...
                                numPreSamples, numPostSamples, [figureSupTitle, ' (Filtered)']);
                            hFigSig = plotOnePresentSignal(...
                                seriesSignal{idxSignalFiles}, ...
                                numPreSamples, numPostSamples, figureSupTitle);
                            % Save the plots.
                            pathFileToSave = fullfile(ABS_PATH_TO_SAVE_PLOTS, ...
                                [seriesParentDirName, '_oneSigPerMeas_series_', ...
                                num2str(idxSeries), '_meas_', num2str(idxSignalFiles)]);
                            saveas(hFigSigFiltered, [pathFileToSave, '_filtered.fig']);
                            saveas(hFigSigFiltered, [pathFileToSave, '_filtered.png']);
                            saveas(hFigSig, [pathFileToSave, '.fig']);
                            saveas(hFigSig, [pathFileToSave, '.png']);                            
                        end
                    end
                end
            end
        end
    end
    disp('     Done!')
end
% EOF