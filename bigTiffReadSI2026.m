function varargout = bigTiffReadSI2026(fPath, castType, isSilent)
% bigTiffRead
%
% Usage:
%   img = bigTiffRead(fPath);
%   [img, metadata] = bigTiffRead(fPath);
%   [img, metadata, frameDescriptions] = bigTiffRead(fPath);
%   [img, metadata, frameDescriptions, rawMetadataText] = bigTiffRead(fPath);
%
% This function reads a ScanImage BigTIFF file using ScanImageTiffReader.
% It also reads the full ScanImage metadata text and parses as many fields as
% possible into a MATLAB struct.
%
% Compared with the older version, this version does not depend on splitting
% the header by occurrences of 'SI.'. Instead, it parses the metadata line by
% line and also keeps the original raw metadata text.
%
% Outputs:
%   img               : image stack, permuted to [Y X frame]
%   metadata          : struct containing parsed metadata and raw text
%   frameDescriptions : raw per-frame description text from ScanImageTiffReader
%   rawMetadataText   : full raw metadata text returned by ScanImageTiffReader

%% Defaults
if ~exist('castType', 'var')
    castType = [];
end

if ~exist('isSilent', 'var') || isempty(isSilent)
    isSilent = false;
end

%% Gracefully handle missing extension
if exist(fPath, 'file') ~= 2
    if exist([fPath, '.tif'], 'file') == 2
        fPath = [fPath, '.tif'];
    elseif exist([fPath, '.tiff'], 'file') == 2
        fPath = [fPath, '.tiff'];
    else
        error('Could not find %s.', fPath);
    end
end

%% Add ScanImageTiffReader DLL folder to PATH, if it exists
[thisPath, ~, ~] = fileparts(which(mfilename));
readerBinPath = fullfile(thisPath, 'ScanImageTiffReader', 'bin');

if exist(readerBinPath, 'dir') == 7
    setenv('PATH', [readerBinPath pathsep getenv('PATH')]);
end

%% Open file
siTifObj = ScanImageTiffReader(fPath);
cleanupObj = onCleanup(@() close(siTifObj));

%% Read image stack
if ~isSilent
    fprintf('Reading image data from: %s\n', fPath);
end

rawImgStack = data(siTifObj);

if isempty(castType)
    imgStack = rawImgStack;
else
    switch lower(castType)
        case 'double'
            imgStack = double(rawImgStack);
        case 'single'
            imgStack = single(rawImgStack);
        case 'int16'
            imgStack = int16(rawImgStack);
        case 'uint16'
            imgStack = uint16(rawImgStack);
        otherwise
            error('Unsupported castType: %s', castType);
    end
end

% ScanImageTiffReader returns [X Y frame]. Keep compatibility with your
% original function by returning [Y X frame].
varargout{1} = permute(imgStack, [2 1 3]);

%% Read metadata only if requested
if nargout > 1
    rawMetadataText = metadata(siTifObj);

    metadataStruct = struct();
    metadataStruct.sourceFile = fPath;
    metadataStruct.rawText = rawMetadataText;

    % Parse global ScanImage metadata into metadataStruct.SI.
    metadataStruct.SI = parseScanImageText(rawMetadataText, 'SI');

    % Keep all raw key-value lines too. This is useful for fields that could
    % not be safely converted into MATLAB values.
    metadataStruct.globalLines = extractKeyValueLines(rawMetadataText);

    % Read per-frame descriptions. These often contain frame timestamps and
    % acquisition numbers that are not present in the global metadata.
    try
        frameDescriptions = descriptions(siTifObj);
    catch
        frameDescriptions = [];
    end

    metadataStruct.frameDescriptions = frameDescriptions;
    metadataStruct.frameMetadata = parseFrameDescriptions(frameDescriptions);

    % Convenience fields for common ScanImage timing information.
    metadataStruct.timing = extractTimingFields(metadataStruct);

    varargout{2} = metadataStruct;

    if nargout > 2
        varargout{3} = frameDescriptions;
    end

    if nargout > 3
        varargout{4} = rawMetadataText;
    end
end

end

%% ------------------------------------------------------------------------
function S = parseScanImageText(txt, rootName)
% Parse lines like:
%   SI.hRoiManager.scanFrameRate = 15.23
% into:
%   S.hRoiManager.scanFrameRate = 15.23

S = struct();

if isempty(txt)
    return;
end

lines = splitlines(string(txt));
rootPrefix = rootName + ".";

for iLine = 1:numel(lines)
    line = strtrim(lines(iLine));

    if strlength(line) == 0
        continue;
    end

    if ~startsWith(line, rootPrefix)
        continue;
    end

    eqIdx = strfind(char(line), '=');
    if isempty(eqIdx)
        continue;
    end

    eqIdx = eqIdx(1);
    lineChar = char(line);
    lhs = strtrim(lineChar(1:eqIdx-1));
    rhs = strtrim(lineChar(eqIdx+1:end));

    % Remove root prefix, for example SI.
    fieldPath = extractAfter(string(lhs), strlength(rootPrefix));
    fieldPath = char(fieldPath);

    if isempty(fieldPath)
        continue;
    end

    value = parseScanImageValue(rhs);
    S = setNestedField(S, fieldPath, value);
end

end

%% ------------------------------------------------------------------------
function value = parseScanImageValue(rhs)
% Convert a ScanImage metadata right-hand side to a MATLAB value when safe.
% If conversion fails, return the original text.

rhs = strtrim(rhs);

if isempty(rhs)
    value = [];
    return;
end

% Remove trailing semicolon, if present.
if endsWith(rhs, ';')
    rhs = rhs(1:end-1);
    rhs = strtrim(rhs);
end

% Empty array.
if strcmp(rhs, '[]')
    value = [];
    return;
end

% Logical values.
if strcmp(rhs, 'true')
    value = true;
    return;
elseif strcmp(rhs, 'false')
    value = false;
    return;
end

% Quoted character vector.
if numel(rhs) >= 2 && rhs(1) == '''' && rhs(end) == ''''
    value = rhs(2:end-1);
    value = strrep(value, '''''', '''');
    return;
end

% Numeric scalar.
numVal = str2double(rhs);
if ~isnan(numVal)
    value = numVal;
    return;
end

% Try numeric vector or matrix in square brackets.
if startsWith(rhs, '[') && endsWith(rhs, ']')
    try
        value = str2num(rhs); %#ok<ST2NM>
        return;
    catch
    end
end

% Try cell arrays and other simple MATLAB literals. This can handle entries
% such as {'Channel 1' 'Channel 2'}.
% If a class or package is unavailable, this will fail and we keep the text.
try
    value = eval(rhs); %#ok<EVLDIR>
catch
    value = rhs;
end

end

%% ------------------------------------------------------------------------
function S = setNestedField(S, fieldPath, value)
% Set a nested field from a dot-separated path.
% Invalid field names are converted using matlab.lang.makeValidName.

parts = strsplit(fieldPath, '.');
parts = parts(~cellfun(@isempty, parts));

for i = 1:numel(parts)
    parts{i} = matlab.lang.makeValidName(parts{i});
end

if isempty(parts)
    return;
end

S = setNestedFieldRecursive(S, parts, value);

end

%% ------------------------------------------------------------------------
function S = setNestedFieldRecursive(S, parts, value)

thisField = parts{1};

if numel(parts) == 1
    S.(thisField) = value;
else
    if ~isfield(S, thisField) || ~isstruct(S.(thisField))
        S.(thisField) = struct();
    end

    S.(thisField) = setNestedFieldRecursive(S.(thisField), parts(2:end), value);
end

end

%% ------------------------------------------------------------------------
function linesOut = extractKeyValueLines(txt)
% Return all key-value lines as a table-like struct array.

linesOut = struct('key', {}, 'valueText', {}, 'lineNumber', {});

if isempty(txt)
    return;
end

lines = splitlines(string(txt));

for iLine = 1:numel(lines)
    line = strtrim(lines(iLine));

    if strlength(line) == 0
        continue;
    end

    eqIdx = strfind(char(line), '=');
    if isempty(eqIdx)
        continue;
    end

    eqIdx = eqIdx(1);
    lineChar = char(line);

    newEntry.key = strtrim(lineChar(1:eqIdx-1));
    newEntry.valueText = strtrim(lineChar(eqIdx+1:end));
    newEntry.lineNumber = iLine;

    linesOut(end+1) = newEntry; %#ok<AGROW>
end

end

%% ------------------------------------------------------------------------
function frameMetadata = parseFrameDescriptions(frameDescriptions)
% Parse per-frame descriptions into a struct array.
% This function keeps the raw text for every frame and extracts common
% key-value pairs such as frameTimestamps_sec.

frameMetadata = struct('rawText', {}, 'values', {});

if isempty(frameDescriptions)
    return;
end

if ischar(frameDescriptions)
    frameDescriptions = cellstr(frameDescriptions);
end

if isstring(frameDescriptions)
    frameDescriptions = cellstr(frameDescriptions);
end

if ~iscell(frameDescriptions)
    frameDescriptions = {frameDescriptions};
end

for iFrame = 1:numel(frameDescriptions)
    desc = frameDescriptions{iFrame};

    if isstring(desc)
        desc = char(desc);
    end

    thisValues = struct();
    kvLines = extractKeyValueLines(desc);

    for iLine = 1:numel(kvLines)
        key = kvLines(iLine).key;
        valueText = kvLines(iLine).valueText;

        % Frame description keys are often simple, but make them safe.
        key = matlab.lang.makeValidName(key);
        thisValues.(key) = parseScanImageValue(valueText);
    end

    frameMetadata(iFrame).rawText = desc; %#ok<AGROW>
    frameMetadata(iFrame).values = thisValues; %#ok<AGROW>
end

end

%% ------------------------------------------------------------------------
function timing = extractTimingFields(metadataStruct)
% Collect common timing fields in a convenient location.

timing = struct();

SI = metadataStruct.SI;

% Global metadata from SI.hRoiManager.
timing.scanFrameRate_Hz = getNestedFieldOrNaN(SI, {'hRoiManager', 'scanFrameRate'});
timing.scanFramePeriod_s = getNestedFieldOrNaN(SI, {'hRoiManager', 'scanFramePeriod'});
timing.scanVolumeRate_Hz = getNestedFieldOrNaN(SI, {'hRoiManager', 'scanVolumeRate'});
timing.linePeriod_s = getNestedFieldOrNaN(SI, {'hRoiManager', 'linePeriod'});
timing.linesPerFrame = getNestedFieldOrNaN(SI, {'hRoiManager', 'linesPerFrame'});
timing.pixelsPerLine = getNestedFieldOrNaN(SI, {'hRoiManager', 'pixelsPerLine'});

% Per-frame timestamps from frame descriptions, when available.
frameMetadata = metadataStruct.frameMetadata;
frameTimestamps = nan(numel(frameMetadata), 1);
acqTriggerTimestamps = nan(numel(frameMetadata), 1);

for iFrame = 1:numel(frameMetadata)
    vals = frameMetadata(iFrame).values;

    if isfield(vals, 'frameTimestamps_sec')
        frameTimestamps(iFrame) = vals.frameTimestamps_sec;
    end

    if isfield(vals, 'acqTriggerTimestamps_sec')
        acqTriggerTimestamps(iFrame) = vals.acqTriggerTimestamps_sec;
    end
end

timing.frameTimestamps_sec = frameTimestamps;
timing.acqTriggerTimestamps_sec = acqTriggerTimestamps;

validTs = frameTimestamps(~isnan(frameTimestamps));
if numel(validTs) > 1
    timing.estimatedFramePeriod_s = median(diff(validTs));
    timing.estimatedFrameRate_Hz = 1 / timing.estimatedFramePeriod_s;
else
    timing.estimatedFramePeriod_s = NaN;
    timing.estimatedFrameRate_Hz = NaN;
end

end

%% ------------------------------------------------------------------------
function value = getNestedFieldOrNaN(S, fieldList)

value = NaN;

try
    tmp = S;
    for i = 1:numel(fieldList)
        if ~isstruct(tmp) || ~isfield(tmp, fieldList{i})
            return;
        end
        tmp = tmp.(fieldList{i});
    end
    value = tmp;
catch
    value = NaN;
end

end
