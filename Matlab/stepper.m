function varargout = stepperMotor(varargin)
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @stepperMotor_OpeningFcn, ...
                   'gui_OutputFcn',  @stepperMotor_OutputFcn, ...
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
end

% --- Executes just before stepperMotor is made visible.
function stepperMotor_OpeningFcn(hObject, ~, handles, varargin)
    ports = serialportlist("available");
    if isempty(ports)
        set(handles.portList, 'String', {'Mevcut port bulunamadı.'});
    else
        set(handles.portList, 'String', cellstr(ports(:)));
    end

    % Dropdown now selects direction
    set(handles.methodPopup, 'String', { ...
        'Bir yön seçin...', ...
        'Saat yönü (CW)', ...
        'Saat yönünün tersi (CCW)'});
    set(handles.methodPopup, 'Value', 1);

    set(handles.ekran,   'String', '');
    set(handles.baud_rate,'String', '9600');
    set(handles.sendBtn, 'Enable', 'off');

    handles.output = hObject;
    guidata(hObject, handles);
end

function varargout = stepperMotor_OutputFcn(~, ~, handles)
    varargout{1} = handles.output;
end

% --- Connect / Disconnect ---
function connectBtn_Callback(~, ~, ~)
    handles = guidata(gcbf);

    if strcmp(get(gcbo, 'String'), 'Connect')
        portStr = get(handles.portList, 'String');
        idx     = get(handles.portList, 'Value');
        baud    = str2double(get(handles.baud_rate, 'String'));

        if isnan(baud) || baud <= 0
            errordlg('Geçersiz baud rate!');
            return;
        end

        try
            handles.serConn         = serialport(portStr{idx}, baud);
            handles.serConn.Timeout = 10;
            flush(handles.serConn);
            set(handles.sendBtn, 'Enable', 'on');
            set(gcbo, 'String', 'Disconnect');
        catch e
            errordlg(['Bağlantı hatası: ' e.message]);
            return;
        end
    else
        try
            if isfield(handles, 'serConn') && ~isempty(handles.serConn)
                delete(handles.serConn);
            end
            handles = rmfield(handles, 'serConn');
        catch
        end
        set(handles.sendBtn, 'Enable', 'off');
        set(gcbo, 'String', 'Connect');
    end

    guidata(gcbf, handles);
end

% --- Send Command ---
function sendBtn_Callback(~, ~, ~)

    handles = guidata(gcbf);

    persistent currentAngle

    if isempty(currentAngle)
        currentAngle = 0;
    end

    if ~isfield(handles, 'serConn') || isempty(handles.serConn)
        errordlg('Lütfen önce bağlantı kurun!');
        return;
    end

    % ---------- DRIVE METHOD ----------
    if get(handles.waveDrivetag, 'Value')
        method = 0;
    elseif get(handles.tamAdimtag, 'Value')
        method = 1;
    elseif get(handles.yarimAdimtag, 'Value')
        method = 2;
    else
        errordlg('Lütfen bir sürüş yöntemi seçin!');
        return;
    end

    % ---------- DIRECTION ----------
    dirVal = get(handles.methodPopup, 'Value') - 2;

    if dirVal < 0
        errordlg('Lütfen bir yön seçin!');
        return;
    end

    % ---------- ANGLE ----------
    angleVal = str2double(get(handles.ekran, 'String'));

    if isnan(angleVal) || angleVal < 0
        errordlg('Lütfen geçerli bir açı girin!');
        return;
    end

    try

        set(gcbo, 'Enable', 'off', 'String', 'Moving...');

        % =========================================================
        % 1. RETURN TO ZERO FIRST
        % =========================================================
        if currentAngle > 0

            returnSteps = round(currentAngle * 5.6888);

            returnHigh = floor(returnSteps / 256);
            returnLow  = mod(returnSteps, 256);

            % Reverse direction
            if dirVal == 0
                returnDir = 1;
            else
                returnDir = 0;
            end

            write(handles.serConn, ...
                uint8([method, returnHigh, returnLow, returnDir]), ...
                "uint8");

            returnTime = (returnSteps * 0.0035) + 0.5;

            pause(returnTime);
        end

        % =========================================================
        % 2. GO TO NEW ANGLE
        % =========================================================
        totalSteps = round(angleVal * 5.6888);

        if totalSteps > 65535
            errordlg('Açı çok büyük!');
            set(gcbo, 'Enable', 'on', 'String', 'Send');
            return;
        end

        highByte = floor(totalSteps / 256);
        lowByte  = mod(totalSteps, 256);

        write(handles.serConn, ...
            uint8([method, highByte, lowByte, dirVal]), ...
            "uint8");

        estimatedTime = (totalSteps * 0.0035) + 0.5;

        fprintf('Yeni açı: %.2f derece | Adım: %d | Yön: %d\n', ...
                angleVal, totalSteps, dirVal);

        pause(estimatedTime);

        % Save current position
        currentAngle = angleVal;

        set(gcbo, 'Enable', 'on', 'String', 'Send');

    catch e

        set(gcbo, 'Enable', 'on', 'String', 'Send');
        errordlg(['Gönderme hatası: ' e.message]);

    end
end

% --- Mutual exclusion callbacks ---
function waveDrivetag_Callback(hObject, ~, handles)
    if get(hObject,'Value') == 1
        set(handles.tamAdimtag,'Enable','off','Value',0);
        set(handles.yarimAdimtag,'Enable','off','Value',0);
    else
        set(handles.tamAdimtag,'Enable','on');
        set(handles.yarimAdimtag,'Enable','on');
    end
end

function tamAdimtag_Callback(hObject, ~, handles)
    if get(hObject,'Value') == 1
        set(handles.waveDrivetag,'Enable','off','Value',0);
        set(handles.yarimAdimtag,'Enable','off','Value',0);
    else
        set(handles.waveDrivetag,'Enable','on');
        set(handles.yarimAdimtag,'Enable','on');
    end
end

function yarimAdimtag_Callback(hObject, ~, handles)
    if get(hObject,'Value') == 1
        set(handles.waveDrivetag,'Enable','off','Value',0);
        set(handles.tamAdimtag,'Enable','off','Value',0);
    else
        set(handles.waveDrivetag,'Enable','on');
        set(handles.tamAdimtag,'Enable','on');
    end
end

% --- CreateFcn stubs ---
function portList_CreateFcn(hObject, ~, ~)
    if ispc, set(hObject, 'BackgroundColor', 'white'); end
end
function ekran_CreateFcn(hObject, ~, ~)
    if ispc, set(hObject, 'BackgroundColor', 'white'); end
end
function ekran_Callback(~, ~, ~)
end

function methodPopup_CreateFcn(hObject, ~, ~)
    if ispc, set(hObject, 'BackgroundColor', 'white'); end
end
function baud_rate_CreateFcn(hObject, ~, ~)
    if ispc, set(hObject, 'BackgroundColor', 'white'); end
end

function methodPopup_Callback(~, ~, ~)
% hObject    handle to methodPopup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Nothing needed here — dropdown value is read in sendBtn_Callback
end
