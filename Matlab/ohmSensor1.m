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

% =========================================================================
function ohmSensor_OpeningFcn(hObject, ~, handles, varargin)
% =========================================================================
    % --- Populate port list ---
    serialInfo = instrhwinfo('serial');
    if ~isempty(serialInfo.SerialPorts)
        set(handles.portList, 'String', cellstr(serialInfo.SerialPorts));
        set(handles.portList, 'Value', 1);
    else
        set(handles.portList, 'String', {'No Ports Found'});
    end

    % --- Populate stage selector ---
    set(handles.stagePopup, 'String', {
        'Range 1:  0 – 1 kΩ    (Rpot = 1 kΩ)',  ...
        'Range 2:  0 – 10 kΩ   (Rpot = 10 kΩ)', ...
        'Range 3:  0 – 100 kΩ  (Rpot = 100 kΩ)',...
        'Range 4:  0 – 1 MΩ    (Rpot = 1 MΩ)'});
    set(handles.stagePopup, 'Value', 1);

    % --- Defaults ---
    set(handles.baud_rate, 'String', '9600');
    set(handles.dataList,  'String', {});
    set(handles.dataList,  'Value',  1);
    set(handles.rxBtn,     'Enable', 'off');

    % --- Store serial object and stage in handles ---
    handles.ser   = [];
    handles.stage = 1;

    guidata(hObject, handles);


% =========================================================================
function varargout = ohmSensor_OutputFcn(hObject, ~, handles)
    varargout{1} = hObject;


% =========================================================================
function connectBtn_Callback(~, ~, ~)
    handles = guidata(gcbf);
    hObject = gcbo;

    if strcmp(get(gcbo, 'String'), 'Connect')
        try
            fullList    = cellstr(get(handles.portList, 'String'));
            serPort     = fullList{get(handles.portList, 'Value')};
            baudVal     = str2double(get(handles.baud_rate, 'String'));
            handles.ser = serial(serPort, 'BaudRate', baudVal, 'Timeout', 1);
            fopen(handles.ser);
            set(gcbo,          'String', 'Disconnect');
            set(handles.rxBtn, 'Enable', 'on');
            guidata(gcbf, handles);
        catch e
            errordlg(['Port Error: ' e.message]);
        end
    else
        if ~isempty(handles.ser)
            fclose(handles.ser);
            delete(handles.ser);
            handles.ser = [];
        end
        set(gcbo,          'String', 'Connect');
        set(handles.rxBtn, 'Enable', 'off');
        guidata(gcbf, handles);
    end

% =========================================================================
function rxBtn_Callback(hObject, ~, handles)
% =========================================================================
    VCC         = 5.0;
    ADC_MAX     = 4095;
    Rpot_base   = 1000;
    stage_mult  = [1, 10, 100, 1000];
    stage_names = {'0-1 kΩ', '0-10 kΩ', '0-100 kΩ', '0-1 MΩ'};
    Rpot_labels = {'Rpot=1kΩ', 'Rpot=10kΩ', 'Rpot=100kΩ', 'Rpot=1MΩ'};

    try
        flushinput(handles.ser);
        data = fread(handles.ser, 2, 'uint8');

        if length(data) == 2
            adc_val = min(max(double(data(1))*256 + double(data(2)), 0), ADC_MAX);
            Rpot    = Rpot_base * stage_mult(handles.stage);

            % Voltages
            V_Rx   = (adc_val / ADC_MAX) * VCC;   % across Rx  → 0 to 5V
            V_Rpot = VCC - V_Rx;                  % across Rpot → 5 to 0V

            % Resistance
            if adc_val >= ADC_MAX
                r_str = 'OL (Open Circuit)';
            elseif adc_val == 0
                r_str = 'SHORT (0 Ohm)';
            else
                Rx = Rpot * (adc_val / (ADC_MAX - adc_val));
                if Rx >= 1e6
                    r_str = sprintf('%.4f MOhm', Rx/1e6);
                elseif Rx >= 1e3
                    r_str = sprintf('%.3f kOhm', Rx/1e3);
                else
                    r_str = sprintf('%.1f Ohm', Rx);
                end
            end

            timestamp = datestr(now, 'HH:MM:SS');
            newEntry  = sprintf(...
                '[%s] Range:%s | %s  ADC:%4d  V_Rpot:%.3fV  V_Rx:%.3fV  R:%s', ...
                timestamp, ...
                stage_names{handles.stage}, ...
                Rpot_labels{handles.stage}, ...
                adc_val, V_Rpot, V_Rx, r_str);

            curList = get(handles.dataList, 'String');
            set(handles.dataList, 'String', [curList; {newEntry}]);
            set(handles.dataList, 'Value',  length(get(handles.dataList,'String')));
        else
            disp(['Expected 2 bytes, got: ' num2str(length(data))]);
        end

    catch e
        disp(['Receive Error: ' e.message]);
    end


% =========================================================================
% Stage popup — user selects which Rpot is physically installed
% =========================================================================
function stagePopup_Callback(~, ~, ~)
    handles       = guidata(gcbf);
    handles.stage = get(gcbo, 'Value');
    guidata(gcbf, handles)


% =========================================================================
function baud_rate_Callback(~, ~, ~)
    validBauds = [300, 600, 1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200];
    val = str2double(get(gcbo, 'String'));
    
    if isnan(val) || ~ismember(val, validBauds)
        set(gcbo, 'String', '9600');
    end