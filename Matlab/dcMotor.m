function varargout = dcMotor(varargin)
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @dcMotor_OpeningFcn, ...
                   'gui_OutputFcn',  @dcMotor_OutputFcn, ...
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

function dcMotor_OpeningFcn(hObject, ~, handles, varargin)
    ports = serialportlist("available");
    if isempty(ports)
        set(handles.portList, 'String', {'No port found'});
    else
        set(handles.portList, 'String', cellstr(ports(:)));
    end

    set(handles.baud_rate,   'String', '9600');
    set(handles.calistirBtn, 'Enable', 'off');
    set(handles.hizPwm, 'Min', 0, 'Max', 100, 'Value', 0);

    handles.motorRunning = false;
    handles.direction    = 0;
    handles.lastCmd      = [];

    handles.updateTimer = timer( ...
        'ExecutionMode', 'fixedSpacing', ...
        'Period',        0.2, ...
        'TimerFcn',      @(~,~) sliderLiveUpdate(handles.figure1));

    handles.output = hObject;
    guidata(hObject, handles);
end

function varargout = dcMotor_OutputFcn(~, ~, handles)
    varargout{1} = handles.output;
end

function sendCmd(handles)
    if ~isfield(handles, 'serConn') || isempty(handles.serConn)
        return;
    end

    val = round(get(handles.hizPwm, 'Value'));

    if ~handles.motorRunning || val == 0
        write(handles.serConn, uint8('S'), "uint8");
        return;
    end

    % send direction
    if handles.direction == 0
        write(handles.serConn, uint8('F'), "uint8");
    else
        write(handles.serConn, uint8('R'), "uint8");
    end

    % small pause between bytes
    pause(0.02);

    % send speed 1-99
    spd = max(1, min(99, val));
    write(handles.serConn, uint8(spd), "uint8");
end

function connectBtn_Callback(hObject, ~, handles)
    handles = guidata(gcbf);

    if strcmp(get(gcbo, 'String'), 'Connect')
        portStr = get(handles.portList, 'String');
        idx     = get(handles.portList, 'Value');
        baud    = str2double(get(handles.baud_rate, 'String'));

        if isnan(baud) || baud <= 0
            errordlg('Gecersiz baud rate!');
            return;
        end

        try
            handles.serConn         = serialport(portStr{idx}, baud);
            handles.serConn.Timeout = 10;
            flush(handles.serConn);
            set(handles.calistirBtn, 'Enable', 'on');
            set(gcbo, 'String', 'Disconnect');
        catch e
            errordlg(['Error: ' e.message]);
            return;
        end
    else
        try
            if handles.motorRunning
                stop(handles.updateTimer);
                handles.motorRunning = false;
            end
            if isfield(handles, 'serConn')
                write(handles.serConn, uint8('S'), "uint8");
                pause(0.05);
                delete(handles.serConn);
                handles = rmfield(handles, 'serConn');
            end
        catch
        end
        set(handles.calistirBtn, 'Enable', 'off');
        set(handles.calistirBtn, 'String', 'Calistir');
        set(gcbo, 'String', 'Connect');
    end

    guidata(gcbf, handles);
end

function calistirBtn_Callback(hObject, ~, handles)
    handles = guidata(gcbf);

    if ~isfield(handles, 'serConn') || isempty(handles.serConn)
        errordlg('Connect first!');
        return;
    end

    if handles.motorRunning
        stop(handles.updateTimer);
        handles.motorRunning = false;
        set(handles.calistirBtn, 'String', 'Calistir');
        write(handles.serConn, uint8('S'), "uint8");
    else
        handles.motorRunning = true;
        set(handles.calistirBtn, 'String', 'Durdur');
        guidata(hObject, handles);
        sendCmd(handles);
        start(handles.updateTimer);
    end

    guidata(hObject, handles);
end

function saatYontag_Callback(hObject, ~, handles)
    if get(hObject, 'Value') == 1
        set(handles.saatYonTersitag, 'Value', 0);
        handles.direction = 0;
        guidata(hObject, handles);
        if handles.motorRunning
            sendCmd(handles);
        end
    end
end

function saatYonTersitag_Callback(hObject, ~, handles)
    if get(hObject, 'Value') == 1
        set(handles.saatYontag, 'Value', 0);
        handles.direction = 1;
        guidata(hObject, handles);
        if handles.motorRunning
            sendCmd(handles);
        end
    end
end

function hizPwm_Callback(hObject, ~, handles)
    handles = guidata(gcbf);
    val = round(get(hObject, 'Value'));
    set(handles.hizPwm, 'TooltipString', ['Hiz: ' num2str(val) '%']);
    guidata(gcbf, handles);
    if handles.motorRunning
        sendCmd(handles);
    end
end

function sliderLiveUpdate(figHandle)
    try
        handles = guidata(figHandle);
        if handles.motorRunning
            sendCmd(handles);
        end
    catch e
        fprintf('Timer error: %s\n', e.message);
    end
end

function hizPwm_CreateFcn(hObject, ~, ~)
    if isequal(get(hObject,'BackgroundColor'), ...
               get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor',[.9 .9 .9]);
    end
end
function baud_rate_Callback(~,~,~)
    if isnan(str2double(get(gcbo,'String')))
        set(gcbo,'String','9600');
    end
end
function baud_rate_CreateFcn(hObject,~,~)
    if ispc, set(hObject,'BackgroundColor','white'); end
end
function portList_Callback(~,~,~), end
function portList_CreateFcn(hObject,~,~)
    if ispc, set(hObject,'BackgroundColor','white'); end
end