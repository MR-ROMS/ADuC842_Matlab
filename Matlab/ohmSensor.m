function varargout = ohmSensor(varargin)

gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @ohmSensor_OpeningFcn, ...
                   'gui_OutputFcn',  @ohmSensor_OutputFcn, ...
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


% ================= OPENING =================
function ohmSensor_OpeningFcn(hObject, ~, handles, varargin)

ports = serialportlist("available");

if isempty(ports)
    set(handles.portList,'String',{'No Ports Found'});
else
    set(handles.portList,'String',cellstr(ports(:)));
end

set(handles.stagePopup,'String',{ ...
    'Choose a stage...', ...
    '0–1 kΩ  (Rpot = 1 kΩ)',  ...
    '0–10 kΩ  (Rpot = 10 kΩ)', ...
    '0–100 kΩ  (Rpot = 100 kΩ)', ...
    '0–1 MΩ  (Rpot = 1 MΩ)'});

set(handles.stagePopup,'Value',1);

set(handles.baud_rate,'String','9600');
set(handles.dataList,'String',{});
set(handles.rxBtn,'Enable','off');

handles.stage = 0;
guidata(hObject, handles);


% ================= OUTPUT =================
function varargout = ohmSensor_OutputFcn(hObject, ~, handles)
varargout{1} = hObject;


% ================= CONNECT =================
function connectBtn_Callback(~, ~, ~)

handles = guidata(gcbf);

if strcmp(get(gcbo,'String'),'Connect')

    idx  = get(handles.portList,'Value');
    baud = str2double(get(handles.baud_rate,'String'));

    try
        portStr              = get(handles.portList,'String');
        handles.serConn      = serialport(portStr{idx}, baud);
        handles.serConn.Timeout = 10;
        flush(handles.serConn);

        set(handles.rxBtn,'Enable','on');
        set(gcbo,'String','Disconnect');

    catch e
        errordlg(['Connection Error: ' e.message]);
        return;
    end

else
    try
        if isfield(handles,'serConn')
            delete(handles.serConn);
            handles = rmfield(handles,'serConn');
        end
    catch
    end

    set(handles.rxBtn,'Enable','off');
    set(gcbo,'String','Connect');
end

guidata(gcbf, handles);


% ================= RX =================
function rxBtn_Callback(~, ~, ~)

handles = guidata(gcbf);

if handles.stage == 0
    errordlg('Please select a stage first.');
    return;
end

if ~isfield(handles,'serConn') || ~isvalid(handles.serConn)
    errordlg('Not connected. Please reconnect.');
    return;
end

ADC_MAX    = 4095;
VCC        = 5.0;
Rpot_base  = 1000;
stage_mult = [1 10 100 1000];

try
    % ===== REQUEST HIGH BYTE =====
    write(handles.serConn, uint8(0), "uint8");
    high = read(handles.serConn, 1, "uint8");   % blocking read

    % ===== REQUEST LOW BYTE =====
    write(handles.serConn, uint8(1), "uint8");
    low  = read(handles.serConn, 1, "uint8");   % blocking read

    % ===== RECONSTRUCT ADC =====
    adc_val = bitand(double(high)*256 + double(low), 4095);

    % ===== RANGE =====
    Rpot = Rpot_base * stage_mult(handles.stage);

    % ===== VOLTAGE =====
    V_Rx = (adc_val / ADC_MAX) * VCC;

    % ===== CORRECT FORMULA FOR POT =====
    Rx = (V_Rx / VCC) * Rpot;

    % ===== DISPLAY =====
    list = get(handles.dataList,'String');

    if Rx >= 1e6
        list{end+1} = sprintf('%.3f V     %.4f MOhm', V_Rx, Rx/1e6);
    elseif Rx >= 1e3
        list{end+1} = sprintf('%.3f V     %.3f kOhm', V_Rx, Rx/1e3);
    else
        list{end+1} = sprintf('%.3f V     %.1f Ohm', V_Rx, Rx);
    end

    if numel(list) > 100
        list = list(end-99:end);
    end

    set(handles.dataList,'String', list);
    set(handles.dataList,'Value', numel(list));

catch e
    errordlg(['RX Error: ' e.message]);
end



% ================= STAGE =================
function stagePopup_Callback(~, ~, ~)

handles = guidata(gcbf);
val     = get(gcbo,'Value');

if val == 1
    handles.stage = 0;
else
    handles.stage = val - 1;
end

guidata(gcbf, handles);


% ================= BAUD =================
function baud_rate_Callback(~, ~, ~)

validBauds = [300 600 1200 2400 4800 9600 19200 38400 57600 115200];
val        = str2double(get(gcbo,'String'));

if isnan(val) || ~ismember(val, validBauds)
    set(gcbo,'String','9600');
end

function baud_rate_CreateFcn(~, ~, ~)
if ispc
    set(gcbo,'BackgroundColor','white');
end


% ================= CLOSE =================
function figure1_CloseRequestFcn(hObject, ~, ~)

handles = guidata(hObject);

try
    if isfield(handles,'serConn')
        delete(handles.serConn);
    end
catch
end

delete(hObject);
