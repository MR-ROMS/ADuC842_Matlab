function varargout = suSeviyesi(varargin)
% SUSEVIYESI MATLAB code for suSeviyesi.fig
%      SUSEVIYESI, by itself, creates a new SUSEVIYESI or raises the existing
%      singleton*.
%
%      H = SUSEVIYESI returns the handle to a new SUSEVIYESI or the handle to
%      the existing singleton*.
%
%      SUSEVIYESI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in SUSEVIYESI.M with the given input arguments.
%
%      SUSEVIYESI('Property','Value',...) creates a new SUSEVIYESI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before suSeviyesi_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to suSeviyesi_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help suSeviyesi

% Last Modified by GUIDE v2.5 22-Apr-2026 20:56:40

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @suSeviyesi_OpeningFcn, ...
                   'gui_OutputFcn',  @suSeviyesi_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before suSeviyesi is made visible.
function suSeviyesi_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to suSeviyesi (see VARARGIN)
ports = serialportlist("available");

if isempty(ports)
    set(handles.portList,'String',{'No Ports Found'});
else
    set(handles.portList,'String',cellstr(ports(:)));
end
set(handles.baud_rate,'String','9600');
% Choose default command line output for suSeviyesi
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes suSeviyesi wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = suSeviyesi_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on selection change in dataList.
function dataList_Callback(hObject, eventdata, handles)
% hObject    handle to dataList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns dataList contents as cell array
%        contents{get(hObject,'Value')} returns selected item from dataList


% --- Executes during object creation, after setting all properties.
function dataList_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dataList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in portList.
function portList_Callback(hObject, eventdata, handles)
% hObject    handle to portList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns portList contents as cell array
%        contents{get(hObject,'Value')} returns selected item from portList


% --- Executes during object creation, after setting all properties.
function portList_CreateFcn(hObject, eventdata, handles)
% hObject    handle to portList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in rxBtn.
% --- Executes on button press in rxBtn.
function rxBtn_Callback(hObject, eventdata, handles)
handles = guidata(gcbf);

if ~isfield(handles,'serConn') || ~isvalid(handles.serConn)
    errordlg('Not connected. Please reconnect.');
    return;
end

ADC_MAX = 4095;
VCC     = 5.0;

try
    % ===== WAIT FOR SYNC BYTE (WITH TIMEOUT SAFETY) =====
    t_start = tic;
    while true
        if handles.serConn.NumBytesAvailable > 0
            b = read(handles.serConn, 1, "uint8");
            if b == 170   % 0xAA
                break;
            end
        end
        if toc(t_start) > 2
            error('Timeout waiting for sync byte');
        end
    end

    % ===== WAIT FOR ADC BYTES =====
    t_start = tic;
    while handles.serConn.NumBytesAvailable < 2
        if toc(t_start) > 2
            error('Timeout waiting for ADC data');
        end
    end

    % ===== READ ADC =====
    high = read(handles.serConn, 1, "uint8");
    low  = read(handles.serConn, 1, "uint8");

    adc_val = bitand(double(high)*256 + double(low), 4095);
    disp(adc_val);   % Debug print

    % ===== VOLTAGE =====
    V_Rx = (adc_val / ADC_MAX) * VCC;

    % ===== HYSTERESIS DRY DETECTION =====
    persistent dryCount
    if isempty(dryCount), dryCount = 0; end

    if adc_val < 200
        dryCount = dryCount + 1;
    else
        dryCount = 0;
    end

    if dryCount >= 5   % 5 consecutive dry readings
        level = 0;
        handles.adc_min = adc_val;
        handles.adc_max = adc_val;
    else
        % ===== DYNAMIC CALIBRATION =====
        if ~isfield(handles,'adc_min')
            handles.adc_min = adc_val;
        end
        if ~isfield(handles,'adc_max')
            handles.adc_max = adc_val;
        end

        handles.adc_min = min(handles.adc_min, adc_val);
        handles.adc_max = max(handles.adc_max, adc_val);

        if handles.adc_max > handles.adc_min
            level = (adc_val - handles.adc_min) / ...
                    (handles.adc_max - handles.adc_min) * 100;
        else
            level = 0;
        end
    end

    % Clamp to [0,100]
    level = max(0, min(100, level));

    % ===== SMOOTHING =====
    if ~isfield(handles,'prev_level')
        handles.prev_level = level;
    end
    alpha = 0.2;
    level = alpha * level + (1 - alpha) * handles.prev_level;
    handles.prev_level = level;

    % ===== STORE AND DISPLAY =====
    handles.level = level;
    guidata(gcbf, handles);

    list = get(handles.dataList,'String');
    if ischar(list)
        list = cellstr(list);
    elseif isempty(list)
        list = {};
    end

    list{end+1} = sprintf('Voltage: %.3f V   Level: %.1f %%', V_Rx, level);

    if numel(list) > 100
        list = list(end-99:end);
    end

    set(handles.dataList,'String', list);
    set(handles.dataList,'Value', numel(list));

catch e
    errordlg(['RX Error: ' e.message]);
end


% Executes on button press in connectBtn.
function connectBtn_Callback(hObject, eventdata, handles)
% hObject    handle to connectBtn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles = guidata(gcbf);

if strcmp(get(gcbo,'String'),'Connect')

    portList = get(handles.portList,'String');

    % ===== CHECK IF NO PORTS =====
    if isempty(portList) || strcmp(portList{1}, 'No Ports Found')
        errordlg('No COM ports available. Please connect your device.');
        return;
    end

    idx  = get(handles.portList,'Value');
    baud = str2double(get(handles.baud_rate,'String'));

    % ===== EXTRA SAFETY CHECK =====
    if idx > numel(portList)
        errordlg('Invalid port selection.');
        return;
    end

    try
        handles.serConn = serialport(portList{idx}, baud);
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



% hObject    handle to baud_rate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
function baud_rate_Callback(hObject, eventdata, handles)

baud = str2double(get(hObject,'String'));

if isnan(baud) || baud <= 0
    errordlg('Invalid baud rate. Resetting to 9600.');
    set(hObject,'String','9600');
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

% Hints: get(hObject,'String') returns contents of baud_rate as text
%        str2double(get(hObject,'String')) returns contents of baud_rate as a double


% --- Executes during object creation, after setting all properties.
function baud_rate_CreateFcn(hObject, eventdata, handles)
% hObject    handle to baud_rate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
