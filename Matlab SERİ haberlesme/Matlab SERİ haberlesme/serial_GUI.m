function varargout = serial_GUI(varargin)
% Modernized Serial GUI for STM32 / ESP32 UART communication
% GUIDE .fig compatible

gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @serial_GUI_OpeningFcn, ...
                   'gui_OutputFcn',  @serial_GUI_OutputFcn, ...
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


% ================= OPENING =================
function serial_GUI_OpeningFcn(hObject, eventdata, handles, varargin)

ports = serialportlist("available");

if isempty(ports)
    portData = {'Select a port'};
else
    portData = [{'Select a port'}; cellstr(ports(:))];
end

set(handles.portList, 'String', portData);
set(handles.portList, 'Value', min(2,length(portData)));
set(handles.history_box, 'String', {});
set(handles.Tx_send, 'Enable', 'Off');
set(handles.rxButton, 'Enable', 'Off');

handles.output = hObject;
guidata(hObject, handles);


% ================= OUTPUT =================
function varargout = serial_GUI_OutputFcn(hObject, eventdata, handles)
varargout{1} = handles.output;


% ================= PORT LIST =================
function portList_Callback(hObject, eventdata, handles)

function portList_CreateFcn(hObject, eventdata, handles)
if ispc
    set(hObject,'BackgroundColor','white');
end


% ================= HISTORY =================
function history_box_Callback(hObject, eventdata, handles)

function history_box_CreateFcn(hObject, eventdata, handles)
if ispc
    set(hObject,'BackgroundColor','white');
end


% ================= TX SEND =================
function Tx_send_Callback(hObject, eventdata, handles)

TxText = get(handles.Tx_send,'String');

if isempty(TxText)
    return;
end

if isfield(handles,'serConn')
    try
        writeline(handles.serConn, TxText);

        currList = get(handles.history_box,'String');
        currList{end+1} = ['Sent @ ' datestr(now) ': ' TxText];

        set(handles.history_box,'String',currList);
        set(handles.history_box,'Value',length(currList));
        set(handles.Tx_send,'String','');

    catch e
        errordlg(['Gönderme hatası: ' e.message]);
    end
end


function Tx_send_CreateFcn(hObject, eventdata, handles)
if ispc
    set(hObject,'BackgroundColor','white');
end


% ================= RX READ =================
function rxButton_Callback(hObject, eventdata, handles)
try
    if isfield(handles,'serConn')
        flush(handles.serConn);
        high = read(handles.serConn,1,"uint8");
       

        currList = get(handles.history_box,'String');
        currList{end+1} = ['High: ' num2str(high)];
        set(handles.history_box,'String',currList);
        set(handles.history_box,'Value',length(currList));
    end
catch e
    errordlg(['Veri okuma hatası: ' e.message]);
end


% ================= BAUD =================
function baudRateText_Callback(hObject, eventdata, handles)

function baudRateText_CreateFcn(hObject, eventdata, handles)
if ispc
    set(hObject,'BackgroundColor','white');
end


% ================= CONNECT BUTTON =================
function connectButton_Callback(hObject, eventdata, handles)

if strcmp(get(hObject,'String'),'Connect')

    portIndex = get(handles.portList,'Value');
    portList = get(handles.portList,'String');

    if portIndex == 1 || isempty(portList)
        errordlg('Geçerli bir COM port seç.');
        return;
    end

    baudRate = str2double(get(handles.baudRateText,'String'));
    if isnan(baudRate)
        errordlg('Geçerli baud rate gir.');
        return;
    end

    selectedPort = portList{portIndex};

    try
        handles.serConn = serialport(selectedPort, baudRate);
        configureTerminator(handles.serConn,"LF");
        flush(handles.serConn);

        set(handles.Tx_send,'Enable','On');
        set(handles.rxButton,'Enable','On');
        set(hObject,'String','Disconnect');

    catch e
        errordlg(['Bağlantı hatası: ' e.message]);
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

    set(handles.Tx_send,'Enable','Off');
    set(handles.rxButton,'Enable','Off');
    set(hObject,'String','Connect');
end

guidata(hObject,handles);


% ================= CLOSE =================
function figure1_CloseRequestFcn(hObject, eventdata, handles)

try
    if isfield(handles,'serConn')
        delete(handles.serConn);
    end
catch
end

delete(hObject);
