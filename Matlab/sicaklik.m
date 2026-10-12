function varargout = sicaklik(varargin)

% DHT11 Sicaklik ve Nem Monitoru
% Firmware paket formati: AA | TMP_INT | HUM_INT
% Hata byte'lari: E1-E6

gui_Singleton = 1;
gui_State = struct( ...
    'gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @sicaklik_OpeningFcn, ...
    'gui_OutputFcn',  @sicaklik_OutputFcn, ...
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

function sicaklik_OpeningFcn(hObject, ~, handles, varargin)

ports = serialportlist("available");

if isempty(ports)
    set(handles.portList,'String',{'No COM Ports'});
else
    set(handles.portList,'String',cellstr(ports(:)));
end

set(handles.dataList,'String',{});
set(handles.rxBtn,   'Enable','off');
set(handles.rxBtn,   'String','Receive');

set(handles.statusLight,'BackgroundColor',[1 0 0]);
set(handles.statusLight,'String','');
set(handles.statusLight,'TooltipString','Bagli degil');

handles.buffer = [];
guidata(hObject, handles);

function varargout = sicaklik_OutputFcn(hObject, ~, handles)
varargout{1} = hObject;

function portList_Callback(~, ~, ~)

function portList_CreateFcn(hObject, ~, ~)
if ispc
    set(hObject,'BackgroundColor','white');
end


function dataList_Callback(~, ~, ~)

function dataList_CreateFcn(hObject, ~, ~)
if ispc
    set(hObject,'BackgroundColor','yellow');
end


function baud_rate_Callback(~, ~, ~)

function baud_rate_CreateFcn(hObject, ~, ~)
if ispc
    set(hObject,'BackgroundColor','white');
end
set(hObject,'String','9600');


function connectBtn_Callback(hObject, ~, ~)

handles = guidata(gcbf);

if strcmp(get(hObject,'String'),'Connect')

    idx      = get(handles.portList,'Value');
    portList = get(handles.portList,'String');
    baud     = str2double(get(handles.baud_rate,'String'));

    if isnan(baud) || baud <= 0
        errordlg('Gecersiz baud rate!');
        return;
    end

    try
        handles.serConn         = serialport(portList{idx}, baud);
        handles.serConn.Timeout = 1;
        handles.buffer          = [];
        flush(handles.serConn);

        set(handles.rxBtn, 'Enable','on');
        set(handles.rxBtn, 'String','Receive');
        set(hObject,       'String','Disconnect');

        set(handles.statusLight,'BackgroundColor',[0 0.8 0]);
        set(handles.statusLight,'TooltipString','Bagli');

        list = get(handles.dataList,'String');
        list{end+1} = sprintf('[%s]   Baglandi. Veri almak icin Receive butonuna basin.', ...
                               datestr(now,'HH:MM:SS'));
        updateList(handles.dataList, list);

    catch e
        set(handles.statusLight,'BackgroundColor',[1 0 0]);
        set(handles.statusLight,'TooltipString','Baglanti basarisiz');
        errordlg(['Baglanti Hatasi: ' e.message]);
        return;
    end

else
    try
        if isfield(handles,'serConn')
            configureCallback(handles.serConn,"off");
            delete(handles.serConn);
            handles = rmfield(handles,'serConn');
        end
    catch
    end

    handles.buffer = [];
    set(handles.rxBtn, 'Enable','off');
    set(handles.rxBtn, 'String','Receive');
    set(hObject,       'String','Connect');

    set(handles.statusLight,'BackgroundColor',[1 0 0]);
    set(handles.statusLight,'TooltipString','Bagli degil');

    list = get(handles.dataList,'String');
    list{end+1} = sprintf('[%s]   Baglanti kesildi.', ...
                           datestr(now,'HH:MM:SS'));
    updateList(handles.dataList, list);
end

guidata(gcbf, handles);


function rxBtn_Callback(hObject, ~, ~)

handles = guidata(gcbf);

if strcmp(get(hObject,'String'),'Receive')

    % start continuous reception
    if ~isfield(handles,'serConn') || ~isvalid(handles.serConn)
        errordlg('Lutfen once COM portunu baglayin!');
        return;
    end

    handles.buffer = [];
    flush(handles.serConn);

    figHandle = gcbf;
    configureCallback( ...
        handles.serConn, ...
        "byte", 1, ...
        @(src,event)serialRX(src,event,figHandle));

    set(hObject,'String','Stop');

    list = get(handles.dataList,'String');
    list{end+1} = sprintf('[%s]   Veri alimi basladi...', ...
                           datestr(now,'HH:MM:SS'));
    updateList(handles.dataList, list);

else
    % stop reception
    try
        if isfield(handles,'serConn') && isvalid(handles.serConn)
            configureCallback(handles.serConn,"off");
        end
    catch
    end

    set(hObject,'String','Receive');

    list = get(handles.dataList,'String');
    list{end+1} = sprintf('[%s]   Veri alimi durduruldu.', ...
                           datestr(now,'HH:MM:SS'));
    updateList(handles.dataList, list);
end

guidata(gcbf, handles);


function serialRX(src, ~, figHandle)

if ~ishandle(figHandle)
    return;
end

handles = guidata(figHandle);

try
    count = src.NumBytesAvailable;
    if count <= 0
        return;
    end

    data = read(src, count, "uint8");
    handles.buffer = [handles.buffer data(:)'];

    % buffer overflow guard
    if length(handles.buffer) > 256
        handles.buffer = handles.buffer(end-255:end);
    end

    list    = get(handles.dataList,'String');
    changed = false;

    while ~isempty(handles.buffer)

        b = handles.buffer(1);

        % discard idle/noise bytes
        if b == hex2dec('FF')
            handles.buffer(1) = [];
            continue;
        end

        % firmware error bytes E1..E6
        if b >= hex2dec('E1') && b <= hex2dec('E6')
            handles.buffer(1) = [];
            switch b
                case hex2dec('E1'), msg = 'E1: DHT cevap vermiyor';
                case hex2dec('E2'), msg = 'E2: WAIT_HIGH zaman asimi';
                case hex2dec('E3'), msg = 'E3: WAIT_FALL zaman asimi';
                case hex2dec('E4'), msg = 'E4: Bit yukselis kenari yok';
                case hex2dec('E5'), msg = 'E5: Bit dusus kenari yok';
                case hex2dec('E6'), msg = 'E6: Checksum hatasi';
            end
            list{end+1} = sprintf('[%s]   %s', ...
                                   datestr(now,'HH:MM:SS'), msg);
            changed = true;
            continue;
        end

        % sync byte 0xAA
        if b ~= hex2dec('AA')
            handles.buffer(1) = [];
            continue;
        end

        % wait for full 3-byte packet: AA | TEMP | HUM
        if length(handles.buffer) < 3
            break;
        end

        temp = handles.buffer(2);
        hum  = handles.buffer(3);
        handles.buffer(1:3) = [];

        list{end+1} = sprintf('[%s]   Sicaklik: %d C      Nem: %d %%', ...
                               datestr(now,'HH:MM:SS'), temp, hum);
        changed = true;
    end

    if changed
        updateList(handles.dataList, list);
    end

    guidata(figHandle, handles);

catch e
    try
        configureCallback(src,"off");
        delete(src);
    catch
    end

    if isfield(handles,'serConn')
        handles = rmfield(handles,'serConn');
    end

    handles.buffer = [];
    guidata(figHandle, handles);

    hBtn = findobj(figHandle,'Tag','connectBtn');
    if ~isempty(hBtn)
        set(hBtn,'String','Connect');
    end

    hRx = findobj(figHandle,'Tag','rxBtn');
    if ~isempty(hRx)
        set(hRx,'Enable','off');
        set(hRx,'String','Receive');
    end

    set(handles.statusLight,'BackgroundColor',[1 0 0]);
    set(handles.statusLight,'TooltipString','Baglanti kesildi');

    errordlg(['Seri Port Hatasi: ' e.message]);
end


function updateList(hList, list)

if numel(list) > 100
    list = list(end-99:end);
end

set(hList,'String',list);
set(hList,'Value',numel(list));
drawnow;


function figure1_CloseRequestFcn(hObject, ~, ~)

handles = guidata(hObject);

try
    if isfield(handles,'serConn')
        configureCallback(handles.serConn,"off");
        delete(handles.serConn);
    end
catch
end

delete(hObject);
