function varargout = stepperMotor(varargin)

gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @stepperMotor_OpeningFcn, ...
                   'gui_OutputFcn',  @stepperMotor_OutputFcn, ...
                   'gui_LayoutFcn',  [], ...
                   'gui_Callback',   []);

if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
end

% =========================================================
% STEPS-PER-DEGREE CONSTANTS  (28BYJ-48, 1:64 gear ratio)
%
%  Rotor has 32 full steps/revolution (internal shaft).
%  After the 64:1 gearbox:
%
%   Wave Drive : 32 phases  × 64 = 2048 steps/rev
%                2048 / 360 = 5.6889 steps/deg
%
%   Full Step  : 32 phases  × 64 = 2048 steps/rev
%                2048 / 360 = 5.6889 steps/deg
%
%   Half Step  : 64 phases  × 64 = 4096 steps/rev
%                4096 / 360 = 11.3778 steps/deg
%
% =========================================================

% =========================================================
% OPENING FUNCTION
% =========================================================
function stepperMotor_OpeningFcn(hObject, ~, handles, varargin)

ports = serialportlist("available");
if isempty(ports)
    set(handles.portList, 'String', {'No ports'});
else
    set(handles.portList, 'String', cellstr(ports(:)));
end

set(handles.methodPopup, 'String', {'CW', 'CCW'});
set(handles.methodPopup, 'Value',  1);

set(handles.speedSlider, 'Min',        0,     ...
                         'Max',        3,     ...
                         'Value',      2,     ...
                         'SliderStep', [1/3 1/3]);

set(handles.ekran,     'String', '');
set(handles.baud_rate, 'String', '9600');
set(handles.sendBtn,   'Enable', 'off');

set(handles.waveDrivetag,  'Value', 1);
set(handles.tamAdimtag,    'Value', 0);
set(handles.yarimAdimtag,  'Value', 0);

handles.currentAngle = 0;
handles.output = hObject;
guidata(hObject, handles);
end

function varargout = stepperMotor_OutputFcn(~, ~, handles)
varargout{1} = handles.output;
end

% =========================================================
% CONNECT BUTTON
% =========================================================
function connectBtn_Callback(~, ~, ~)

handles = guidata(gcbf);

if strcmp(get(gcbo, 'String'), 'Connect')

    ports = get(handles.portList, 'String');
    idx   = get(handles.portList, 'Value');
    baud  = str2double(get(handles.baud_rate, 'String'));

    if isnan(baud) || baud <= 0
        errordlg('Invalid baud rate. Enter a positive number (e.g. 9600).');
        return;
    end
    if strcmp(ports{idx}, 'No ports')
        errordlg('No serial ports available. Check your connection.');
        return;
    end

    try
        handles.serConn         = serialport(ports{idx}, baud);
        handles.serConn.Timeout = 300;
        flush(handles.serConn);

        handles.currentAngle = 0;

        set(handles.sendBtn, 'Enable', 'on', 'String', 'DÖN');
        set(gcbo, 'String', 'Disconnect');
    catch e
        errordlg(e.message);
    end

else
    try; delete(handles.serConn); catch; end
    if isfield(handles, 'serConn')
        handles = rmfield(handles, 'serConn');
    end
    handles.currentAngle = 0;
    set(handles.sendBtn, 'Enable', 'off', 'String', 'DÖN');
    set(gcbo, 'String', 'Connect');
end

guidata(gcbf, handles);
end

% =========================================================
% SEND BUTTON
%
% Packet (5 bytes):
%   Byte 0 : mode   (0=Wave, 1=Full, 2=Half)
%   Byte 1 : steps HIGH byte
%   Byte 2 : steps LOW  byte
%   Byte 3 : dir    (0=CW,  1=CCW)
%   Byte 4 : speed  (0=slowest .. 3=fastest)
% =========================================================
function sendBtn_Callback(~, ~, ~)

handles = guidata(gcbf);

if ~isfield(handles, 'serConn')
    errordlg('No connection. Please connect first.');
    return;
end

% --- Read and validate angle ---
angle = str2double(get(handles.ekran, 'String'));
if isnan(angle) || angle < 0
    errordlg('Enter a valid angle (0 or a positive number).');
    return;
end

% --- Mode and its correct steps/degree constant ---
if get(handles.waveDrivetag, 'Value')
    mode        = 0;
    stepsPerDeg = 2048 / 360;   % = 5.6889  Wave Drive
elseif get(handles.tamAdimtag, 'Value')
    mode        = 1;
    stepsPerDeg = 2048 / 360;   % = 5.6889  Full Step
else
    mode        = 2;
    stepsPerDeg = 4096 / 360;   % = 11.3778 Half Step (2× more phases)
end

% --- Speed ---
speed = uint8(round(get(handles.speedSlider, 'Value')));

% ----------------------------------------------------------
% ZERO = return to home position
% ----------------------------------------------------------
if angle == 0
    returnAngle = abs(handles.currentAngle);

    if returnAngle < (1 / stepsPerDeg)
        msgbox('Motor is already at 0°.', 'Info', 'modal');
        return;
    end

    if handles.currentAngle >= 0
        dir = 1;    % was CW  → go back CCW
    else
        dir = 0;    % was CCW → go back CW
    end

    steps = round(returnAngle * stepsPerDeg);

else
    % --- Normal move ---
    maxAngle = 65535 / stepsPerDeg;
    if angle > maxAngle
        errordlg(sprintf('Angle too large for this mode. Maximum is %.1f degrees.', maxAngle));
        return;
    end

    dir   = get(handles.methodPopup, 'Value') - 1;   % 0=CW, 1=CCW
    steps = round(angle * stepsPerDeg);

    if steps == 0
        errordlg('Angle too small — results in 0 steps. Enter a larger value.');
        return;
    end
end

% --- Split steps into two bytes ---
high = uint8(bitshift(steps, -8));
low  = uint8(bitand(steps,   255));

% --- Disable UI during motion ---
set(handles.sendBtn,      'Enable', 'off', 'String', 'Dönüyor...');
set(handles.ekran,        'Enable', 'off');
set(handles.methodPopup,  'Enable', 'off');
set(handles.speedSlider,  'Enable', 'off');
set(handles.waveDrivetag, 'Enable', 'off');
set(handles.tamAdimtag,   'Enable', 'off');
set(handles.yarimAdimtag, 'Enable', 'off');
drawnow;

success = false;
try
    write(handles.serConn, uint8([mode, high, low, dir, speed]), "uint8");

    ack = read(handles.serConn, 1, "uint8");
    if ack ~= 6
        error('Unexpected response: 0x%02X (expected 0x06)', ack);
    end
    success = true;
catch e
    errordlg(e.message);
end

% --- Update tracked position on success ---
if success
    if angle == 0
        handles.currentAngle = 0;
    else
        movedDeg = steps / stepsPerDeg;
        if dir == 0
            handles.currentAngle = handles.currentAngle + movedDeg;
        else
            handles.currentAngle = handles.currentAngle - movedDeg;
        end
    end
end

% --- Re-enable UI ---
set(handles.sendBtn,      'Enable', 'on', 'String', 'DÖN');
set(handles.ekran,        'Enable', 'on');
set(handles.methodPopup,  'Enable', 'on');
set(handles.speedSlider,  'Enable', 'on');
set(handles.waveDrivetag, 'Enable', 'on');
set(handles.tamAdimtag,   'Enable', 'on');
set(handles.yarimAdimtag, 'Enable', 'on');

guidata(gcbf, handles);
end

% =========================================================
% RADIO BUTTONS — mutual exclusion
% =========================================================
function waveDrivetag_Callback(hObject, ~, handles)
set(hObject,              'Value', 1);
set(handles.tamAdimtag,   'Value', 0);
set(handles.yarimAdimtag, 'Value', 0);
end

function tamAdimtag_Callback(hObject, ~, handles)
set(hObject,              'Value', 1);
set(handles.waveDrivetag, 'Value', 0);
set(handles.yarimAdimtag, 'Value', 0);
end

function yarimAdimtag_Callback(hObject, ~, handles)
set(hObject,              'Value', 1);
set(handles.waveDrivetag, 'Value', 0);
set(handles.tamAdimtag,   'Value', 0);
end

% =========================================================
% CREATE / CALLBACK STUBS
% =========================================================
function portList_CreateFcn(hObject, ~, ~)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end
end

function baud_rate_CreateFcn(hObject, ~, ~)
if ispc; set(hObject, 'BackgroundColor', 'white'); end
end

function ekran_CreateFcn(hObject, ~, ~)
if ispc; set(hObject, 'BackgroundColor', 'white'); end
end

function methodPopup_CreateFcn(hObject, ~, ~)
if ispc; set(hObject, 'BackgroundColor', 'white'); end
end

function speedSlider_CreateFcn(hObject, ~, ~)
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', [0.9 0.9 0.9]);
end
end

function methodPopup_Callback(~, ~, ~); end
function ekran_Callback(~, ~, ~);       end
function speedSlider_Callback(~, ~, ~); end