function varargout = RobotProje(varargin)
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @RobotProje_OpeningFcn, ...
                   'gui_OutputFcn',  @RobotProje_OutputFcn, ...
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

function RobotProje_OpeningFcn(hObject, ~, handles, varargin)
handles.output = hObject;

ports = serialportlist("available");
if isempty(ports)
    set(handles.portList, 'String', {'No ports'});
else
    set(handles.portList, 'String', cellstr(ports(:)));
end

set(handles.baud_rate, 'String', '9600');

% Home positions
handles.homePosition = [90, 150, 60, 90, 90];

handles.servo1_angle = 0;
handles.servo2_angle = 0;
handles.servo3_angle = 0;
handles.servo4_angle = 0;
handles.servo5_angle = 0;

handles.baseSpeed    = 0;
handles.leftSpeed    = 0;
handles.rightSpeed   = 0;
handles.motorRunning = false;
handles.turnActive   = false;
handles.sysEnabled   = false;

set(handles.artiA1edit, 'String', '0');
set(handles.artiA2edit, 'String', '0');
set(handles.artiA3edit, 'String', '0');
set(handles.artiA4edit, 'String', '0');
set(handles.artiA5edit, 'String', '0');
set(handles.eksiA1edit, 'String', '');
set(handles.eksiA2edit, 'String', '');
set(handles.eksiA3edit, 'String', '');
set(handles.eksiA4edit, 'String', '');
set(handles.eksiA5edit, 'String', '');

set(handles.speedSlider, 'Min', 0, 'Max', 100, 'Value', 0, ...
    'SliderStep', [1/100 5/100]);

set(handles.startBtn,    'Enable', 'off');
set(handles.stopBtn,     'Enable', 'off');
set(handles.homeBtn,     'Enable', 'off');
set(handles.speedSlider, 'Enable', 'off');
set(handles.solaDonBtn,  'Enable', 'off');
set(handles.sagDonBtn,   'Enable', 'off');
set(handles.devamBtn,    'Enable', 'off');
set(handles.ileriBtn,    'Enable', 'off');
set(handles.geriBtn,     'Enable', 'off');

handles.motorTimer = timer( ...
    'ExecutionMode', 'fixedSpacing', ...
    'Period', 0.1, ...
    'TimerFcn', @(~,~) motorUpdate(handles.figure1));

handles.isRunning   = false;
handles.isConnected = false;

if isfield(handles, 'statusLight')
    set(handles.statusLight, 'BackgroundColor', [1 0 0]);
    set(handles.statusLight, 'TooltipString',   'Not connected');
end

guidata(hObject, handles);
end

function varargout = RobotProje_OutputFcn(~, ~, handles)
varargout{1} = handles.output;
end

function send_servo_command(handles, channel, angle)
if ~isfield(handles, 'serConn') || isempty(handles.serConn)
    fprintf('send_servo_command: no serial connection\n');
    return;
end

angle = max(0, min(180, round(angle)));
h = guidata(handles.figure1);
if ~h.sysEnabled
    fprintf('Auto-sending A (system enable)\n');
    write(h.serConn, uint8('A'), "uint8");
    pause(0.05);
    h.sysEnabled = true;
    guidata(handles.figure1, h);
end

try
    cmd = sprintf('S%d%03d', channel, angle);
    fprintf('Sending servo cmd: [%s]  (bytes: %d %d %d %d %d)\n', ...
        cmd, uint8(cmd(1)), uint8(cmd(2)), uint8(cmd(3)), ...
        uint8(cmd(4)), uint8(cmd(5)));
    write(h.serConn, uint8(cmd), "uint8");
catch e
    fprintf('send_servo_command ERROR: %s\n', e.message);
end
end


function motorUpdate(figHandle)
try
    handles = guidata(figHandle);
    if isfield(handles, 'serConn') && ~isempty(handles.serConn) ...
            && handles.motorRunning
    end
catch
end
end


function doStop(figHandle)
handles = guidata(figHandle);
if ~isfield(handles, 'serConn') || isempty(handles.serConn)
    return;
end
try
    write(handles.serConn, uint8('X'), "uint8");
catch; end

handles.isRunning    = false;
handles.motorRunning = false;
handles.turnActive   = false;
handles.sysEnabled   = false;

try
    if isvalid(handles.motorTimer) && strcmp(handles.motorTimer.Running, 'on')
        stop(handles.motorTimer);
    end
catch; end

set(handles.startBtn,    'Enable', 'on');
set(handles.stopBtn,     'Enable', 'off');
set(handles.speedSlider, 'Enable', 'off');
set(handles.solaDonBtn,  'Enable', 'off');
set(handles.sagDonBtn,   'Enable', 'off');
set(handles.devamBtn,    'Enable', 'off');
set(handles.ileriBtn,    'Enable', 'off');
set(handles.geriBtn,     'Enable', 'off');

guidata(figHandle, handles);
end

function connectBtn_Callback(hObject, ~, ~)
handles = guidata(hObject);

if ~handles.isConnected
    idx      = get(handles.portList, 'Value');
    portList = get(handles.portList, 'String');
    baud     = str2double(get(handles.baud_rate, 'String'));

    if isnan(baud) || baud <= 0
        errordlg('Invalid baud rate!');
        return;
    end

    try
        handles.serConn         = serialport(portList{idx}, baud);
        handles.serConn.Timeout = 1;
        flush(handles.serConn);

        handles.isConnected = true;
        handles.sysEnabled  = false;

        set(hObject,           'String', 'DISCONNECT');
        set(handles.startBtn,  'Enable', 'on');
        set(handles.stopBtn,   'Enable', 'off');
        set(handles.homeBtn,   'Enable', 'on');

        if isfield(handles, 'statusLight')
            set(handles.statusLight, 'BackgroundColor', [0 0.8 0]);
            set(handles.statusLight, 'TooltipString', ...
                ['Connected to ' portList{idx}]);
        end
    catch e
        handles.isConnected = false;
        errordlg(['Connection Error: ' e.message]);
    end

else
    try
        doStop(handles.figure1);
        handles = guidata(handles.figure1);
    catch; end

    try
        if isfield(handles, 'serConn') && ~isempty(handles.serConn)
            try
                write(handles.serConn, uint8('X'), "uint8");
                pause(0.05);
            catch; end
            delete(handles.serConn);
            handles.serConn = [];
        end
    catch; end

    handles.isConnected = false;
    handles.sysEnabled  = false;

    set(hObject,          'String', 'Connect');
    set(handles.startBtn, 'Enable', 'off');
    set(handles.stopBtn,  'Enable', 'off');
    set(handles.homeBtn,  'Enable', 'off');

    if isfield(handles, 'statusLight')
        set(handles.statusLight, 'BackgroundColor', [1 0 0]);
        set(handles.statusLight, 'TooltipString',   'Disconnected');
    end
end

guidata(hObject, handles);
end

function portList_Callback(~, ~, ~); end
function portList_CreateFcn(~, ~, ~); end
function baud_rate_Callback(~, ~, ~); end
function baud_rate_CreateFcn(~, ~, ~); end


function startBtn_Callback(hObject, ~, ~)
handles = guidata(hObject);

if ~isfield(handles, 'serConn') || isempty(handles.serConn)
    errordlg('No connection. Please connect first.');
    return;
end

try
    fprintf('Sending A - Enable System\n');
    write(handles.serConn, uint8('A'), "uint8");
    pause(0.1);

    handles.sysEnabled   = true;
    handles.isRunning    = true;
    handles.motorRunning = true;
    handles.baseSpeed    = round(get(handles.speedSlider, 'Value'));
    handles.leftSpeed    = handles.baseSpeed;
    handles.rightSpeed   = handles.baseSpeed;

    try
        if strcmp(handles.motorTimer.Running, 'off')
            start(handles.motorTimer);
        end
    catch; end

    % Start grayed out, Stop active; motion controls enabled
    set(handles.startBtn,    'Enable', 'off');
    set(handles.stopBtn,     'Enable', 'on');
    set(handles.speedSlider, 'Enable', 'on');
    set(handles.solaDonBtn,  'Enable', 'on');
    set(handles.sagDonBtn,   'Enable', 'on');
    set(handles.devamBtn,    'Enable', 'on');
    set(handles.ileriBtn,    'Enable', 'on');
    set(handles.geriBtn,     'Enable', 'on');

    guidata(hObject, handles);
catch e
    errordlg(e.message);
end
end


function stopBtn_Callback(hObject, ~, ~)
handles = guidata(hObject);

if ~isfield(handles, 'serConn') || isempty(handles.serConn)
    errordlg('No connection. Please connect first.');
    return;
end

doStop(handles.figure1);
end

function solaDonBtn_Callback(hObject, ~, ~)
handles = guidata(hObject);
if ~isfield(handles,'serConn') || isempty(handles.serConn) || ~handles.motorRunning
    errordlg('Motor not running. Start first.');
    return;
end
handles.turnActive = true;
handles.rightSpeed = min(100, handles.rightSpeed + 10);
handles.leftSpeed  = max(0,   handles.leftSpeed  - 10);
guidata(hObject, handles);
end

function sagDonBtn_Callback(hObject, ~, ~)
handles = guidata(hObject);
if ~isfield(handles,'serConn') || isempty(handles.serConn) || ~handles.motorRunning
    errordlg('Motor not running. Start first.');
    return;
end
handles.turnActive = true;
handles.leftSpeed  = min(100, handles.leftSpeed  + 10);
handles.rightSpeed = max(0,   handles.rightSpeed - 10);
guidata(hObject, handles);
end

function devamBtn_Callback(hObject, ~, ~)
handles = guidata(hObject);
if ~isfield(handles,'serConn') || isempty(handles.serConn) || ~handles.motorRunning
    errordlg('Motor not running. Start first.');
    return;
end
handles.turnActive = false;
handles.leftSpeed  = handles.baseSpeed;
handles.rightSpeed = handles.baseSpeed;
guidata(hObject, handles);
end

function speedSlider_Callback(hObject, ~, ~)
handles = guidata(hObject);
val = round(get(hObject, 'Value'));
handles.baseSpeed = val;
if ~handles.turnActive
    handles.leftSpeed  = val;
    handles.rightSpeed = val;
else
    offset = handles.leftSpeed - handles.rightSpeed;
    handles.leftSpeed  = max(0, min(100, val + offset/2));
    handles.rightSpeed = max(0, min(100, val - offset/2));
end
guidata(hObject, handles);
end

function speedSlider_CreateFcn(hObject, ~, ~)
if isequal(get(hObject,'BackgroundColor'), ...
        get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end
end

function ileriBtn_Callback(hObject, ~, ~)
handles = guidata(hObject);
if handles.motorRunning
    handles.leftSpeed  = handles.baseSpeed;
    handles.rightSpeed = handles.baseSpeed;
    handles.turnActive = false;
    guidata(hObject, handles);
end
end

function geriBtn_Callback(hObject, ~, ~)
handles = guidata(hObject);
if handles.motorRunning
    fprintf('Reverse requested\n');
    guidata(hObject, handles);
end
end


function homeBtn_Callback(hObject, ~, ~)
handles = guidata(hObject);
if ~ishandle(handles.homeBtn); return; end
if ~isfield(handles, 'serConn') || isempty(handles.serConn)
    errordlg('No connection. Please connect first.');
    return;
end
try
    set(handles.homeBtn, 'Enable', 'off');
    drawnow;

    fprintf('Sending A then H - Enable + Home All\n');
    write(handles.serConn, uint8('A'), "uint8");
    pause(0.05);
    handles.sysEnabled = true;
    write(handles.serConn, uint8('H'), "uint8");
    pause(0.1);

    handles.servo1_angle = handles.homePosition(1);
    handles.servo2_angle = handles.homePosition(2);
    handles.servo3_angle = handles.homePosition(3);
    handles.servo4_angle = handles.homePosition(4);
    handles.servo5_angle = handles.homePosition(5);

    set(handles.artiA1edit, 'String', num2str(handles.homePosition(1)));
    set(handles.artiA2edit, 'String', num2str(handles.homePosition(2)));
    set(handles.artiA3edit, 'String', num2str(handles.homePosition(3)));
    set(handles.artiA4edit, 'String', num2str(handles.homePosition(4)));
    set(handles.artiA5edit, 'String', num2str(handles.homePosition(5)));

    guidata(hObject, handles);
catch e
    errordlg(e.message);
end
if ishandle(handles.homeBtn)
    set(handles.homeBtn, 'Enable', 'on');
end
end

%  Servo axis +/- buttons
function artiA1eksen_Callback(hObject, ~, ~)
handles = guidata(hObject);
newAngle = min(180, handles.servo1_angle + 5);
handles.servo1_angle = newAngle;
send_servo_command(handles, 0, newAngle);
set(handles.artiA1edit, 'String', num2str(newAngle));
guidata(hObject, handles);
end

function eksiA1eksen_Callback(hObject, ~, ~)
handles = guidata(hObject);
newAngle = max(0, handles.servo1_angle - 5);
handles.servo1_angle = newAngle;
send_servo_command(handles, 0, newAngle);
set(handles.artiA1edit, 'String', num2str(newAngle));
guidata(hObject, handles);
end

function artiA2eksen_Callback(hObject, ~, ~)
handles = guidata(hObject);
newAngle = min(180, handles.servo2_angle + 5);
handles.servo2_angle = newAngle;
send_servo_command(handles, 1, newAngle);
set(handles.artiA2edit, 'String', num2str(newAngle));
guidata(hObject, handles);
end

function eksiA2eksen_Callback(hObject, ~, ~)
handles = guidata(hObject);
newAngle = max(0, handles.servo2_angle - 5);
handles.servo2_angle = newAngle;
send_servo_command(handles, 1, newAngle);
set(handles.artiA2edit, 'String', num2str(newAngle));
guidata(hObject, handles);
end

function artiA3eksen_Callback(hObject, ~, ~)
handles = guidata(hObject);
newAngle = min(180, handles.servo3_angle + 5);
handles.servo3_angle = newAngle;
send_servo_command(handles, 2, newAngle);
set(handles.artiA3edit, 'String', num2str(newAngle));
guidata(hObject, handles);
end

function eksiA3eksen_Callback(hObject, ~, ~)
handles = guidata(hObject);
newAngle = max(0, handles.servo3_angle - 5);
handles.servo3_angle = newAngle;
send_servo_command(handles, 2, newAngle);
set(handles.artiA3edit, 'String', num2str(newAngle));
guidata(hObject, handles);
end

function artiA4eksen_Callback(hObject, ~, ~)
handles = guidata(hObject);
newAngle = min(180, handles.servo4_angle + 5);
handles.servo4_angle = newAngle;
send_servo_command(handles, 3, newAngle);
set(handles.artiA4edit, 'String', num2str(newAngle));
guidata(hObject, handles);
end

function eksiA4eksen_Callback(hObject, ~, ~)
handles = guidata(hObject);
newAngle = max(0, handles.servo4_angle - 5);
handles.servo4_angle = newAngle;
send_servo_command(handles, 3, newAngle);
set(handles.artiA4edit, 'String', num2str(newAngle));
guidata(hObject, handles);
end

function artiA5eksen_Callback(hObject, ~, ~)
handles = guidata(hObject);
newAngle = min(180, handles.servo5_angle + 5);
handles.servo5_angle = newAngle;
send_servo_command(handles, 4, newAngle);
set(handles.artiA5edit, 'String', num2str(newAngle));
guidata(hObject, handles);
end

function eksiA5eksen_Callback(hObject, ~, ~)
handles = guidata(hObject);
newAngle = max(0, handles.servo5_angle - 5);
handles.servo5_angle = newAngle;
send_servo_command(handles, 4, newAngle);
set(handles.artiA5edit, 'String', num2str(newAngle));
guidata(hObject, handles);
end

function artiA1edit_Callback(hObject, ~, ~)
handles = guidata(hObject);
val = str2double(get(hObject, 'String'));
if ~isnan(val) && val >= 0 && val <= 180
    handles.servo1_angle = val;
    send_servo_command(handles, 0, val);
    guidata(hObject, handles);
else
    set(hObject, 'String', num2str(handles.servo1_angle));
    errordlg('Enter value between 0-180');
end
end
function artiA1edit_CreateFcn(~, ~, ~); end

function artiA2edit_Callback(hObject, ~, ~)
handles = guidata(hObject);
val = str2double(get(hObject, 'String'));
if ~isnan(val) && val >= 0 && val <= 180
    handles.servo2_angle = val;
    send_servo_command(handles, 1, val);
    guidata(hObject, handles);
else
    set(hObject, 'String', num2str(handles.servo2_angle));
    errordlg('Enter value between 0-180');
end
end
function artiA2edit_CreateFcn(~, ~, ~); end

function artiA3edit_Callback(hObject, ~, ~)
handles = guidata(hObject);
val = str2double(get(hObject, 'String'));
if ~isnan(val) && val >= 0 && val <= 180
    handles.servo3_angle = val;
    send_servo_command(handles, 2, val);
    guidata(hObject, handles);
else
    set(hObject, 'String', num2str(handles.servo3_angle));
    errordlg('Enter value between 0-180');
end
end
function artiA3edit_CreateFcn(~, ~, ~); end

function artiA4edit_Callback(hObject, ~, ~)
handles = guidata(hObject);
val = str2double(get(hObject, 'String'));
if ~isnan(val) && val >= 0 && val <= 180
    handles.servo4_angle = val;
    send_servo_command(handles, 3, val);
    guidata(hObject, handles);
else
    set(hObject, 'String', num2str(handles.servo4_angle));
    errordlg('Enter value between 0-180');
end
end
function artiA4edit_CreateFcn(~, ~, ~); end

function artiA5edit_Callback(hObject, ~, ~)
handles = guidata(hObject);
val = str2double(get(hObject, 'String'));
if ~isnan(val) && val >= 0 && val <= 180
    handles.servo5_angle = val;
    send_servo_command(handles, 4, val);
    guidata(hObject, handles);
else
    set(hObject, 'String', num2str(handles.servo5_angle));
    errordlg('Enter value between 0-180');
end
end
function artiA5edit_CreateFcn(~, ~, ~); end

function eksiA1edit_Callback(hObject, ~, ~)
handles = guidata(hObject);
val = str2double(get(hObject, 'String'));
if ~isnan(val) && val >= 0 && val <= 180
    handles.servo1_angle = val;
    send_servo_command(handles, 0, val);
    guidata(hObject, handles);
else
    set(hObject, 'String', num2str(handles.servo1_angle));
    errordlg('Enter value between 0-180');
end
end
function eksiA1edit_CreateFcn(~, ~, ~); end

function eksiA2edit_Callback(hObject, ~, ~)
handles = guidata(hObject);
val = str2double(get(hObject, 'String'));
if ~isnan(val) && val >= 0 && val <= 180
    handles.servo2_angle = val;
    send_servo_command(handles, 1, val);
    guidata(hObject, handles);
else
    set(hObject, 'String', num2str(handles.servo2_angle));
    errordlg('Enter value between 0-180');
end
end
function eksiA2edit_CreateFcn(~, ~, ~); end

function eksiA3edit_Callback(hObject, ~, ~)
handles = guidata(hObject);
val = str2double(get(hObject, 'String'));
if ~isnan(val) && val >= 0 && val <= 180
    handles.servo3_angle = val;
    send_servo_command(handles, 2, val);
    guidata(hObject, handles);
else
    set(hObject, 'String', num2str(handles.servo3_angle));
    errordlg('Enter value between 0-180');
end
end
function eksiA3edit_CreateFcn(~, ~, ~); end

function eksiA4edit_Callback(hObject, ~, ~)
handles = guidata(hObject);
val = str2double(get(hObject, 'String'));
if ~isnan(val) && val >= 0 && val <= 180
    handles.servo4_angle = val;
    send_servo_command(handles, 3, val);
    guidata(hObject, handles);
else
    set(hObject, 'String', num2str(handles.servo4_angle));
    errordlg('Enter value between 0-180');
end
end
function eksiA4edit_CreateFcn(~, ~, ~); end

function eksiA5edit_Callback(hObject, ~, ~)
handles = guidata(hObject);
val = str2double(get(hObject, 'String'));
if ~isnan(val) && val >= 0 && val <= 180
    handles.servo5_angle = val;
    send_servo_command(handles, 4, val);
    guidata(hObject, handles);
else
    set(hObject, 'String', num2str(handles.servo5_angle));
    errordlg('Enter value between 0-180');
end
end
function eksiA5edit_CreateFcn(~, ~, ~); end

function pushbutton15_Callback(~, ~, ~); end


function figure1_CloseRequestFcn(hObject, ~, handles)
try
    if isfield(handles, 'motorTimer') && isvalid(handles.motorTimer)
        stop(handles.motorTimer);
        delete(handles.motorTimer);
    end
    if isfield(handles, 'serConn') && ~isempty(handles.serConn)
        try
            write(handles.serConn, uint8('X'), "uint8");
            pause(0.05);
        catch; end
        delete(handles.serConn);
    end
catch; end
delete(hObject);
end