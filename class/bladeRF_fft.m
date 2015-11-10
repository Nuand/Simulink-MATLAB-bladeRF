%
% bladeRF_fft A simple demo that receives and displays samples
%
% TODO Summarize usage here

%
% Copyright (c) 2015 Nuand LLC
%
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be included in
% all copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
% THE SOFTWARE.
%

function varargout = bladeRF_fft(varargin)
    gui_Singleton = 1;
    gui_State = struct('gui_Name',       mfilename, ...
                       'gui_Singleton',  gui_Singleton, ...
                       'gui_OpeningFcn', @bladeRF_fft_OpeningFcn, ...
                       'gui_OutputFcn',  @bladeRF_fft_OutputFcn, ...
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

function set_bandwidth_selection(bandwidth_widget, value)
    strings = get(bandwidth_widget, 'String');

    for n = 1:length(strings)
        if value == (str2num(strings{n}) * 1e6)
            set(bandwidth_widget, 'Value', n);
        end
    end
end

function set_lnagain_selection(lnagain_widget, value)
    strings = get(lnagain_widget, 'String');
    for n = 1:length(strings)
        if strcmpi(strings{n}, value)
            set(lnagain_widget, 'Value', n)
        end
    end
end

function [x, y, p] = new_plot(handles, type)
    linkdata off;

    fprintf('Request to set plot type to: %s\n', type);

    % We need the center frequency and sample rate to derive X values
    Fc = handles.bladerf.rx.frequency;
    Fs = handles.bladerf.rx.samplerate;

    % Reset sample values
    xlen = length(handles.plot_data.x);
    ylen = length(handles.plot_data.y);

    x = zeros(1, xlen);
    y = zeros(1, ylen);

    % Configure plot properties based upon type
    switch type
        case 'FFT (dB)'
            marker = 'b-';
            set(handles.xlabel, 'String', 'Frequency (MHz)');

            xmin = (Fc - Fs/2);
            xmax = (Fc + Fs/2);
            ymin = 0;
            ymax = 140;

            x = linspace(double(xmin), double(xmax), xlen);

        case 'FFT (linear)'
            marker = 'b-';
            set(handles.xlabel, 'String', 'Frequency (MHz)');

            xmin = (Fc - Fs/2);
            xmax = (Fc + Fs/2);
            ymin = 0;
            ymax = 10e6;

            x = linspace(double(xmin), double(xmax), xlen);

        case 'Time (2-Channel)'
            %set(handles.axes1, 'XScale', 'linear') ;
            marker = 'b-';
            set(handles.xlabel, 'String', 'Time (s)');

            xmin = 0;
            xmax = (length(handles.plot_data(y)) - 1) / Fs;
            ymin = -2500;
            ymax = -2500;

            x = 0;

        case 'Time (XY)'
            %set(handles.axes1,'XScale','linear') ;
            marker = 'b-';
            set(handles.xlabel,'String', 'X (counts)');

            xmin = -2500;
            xmax = 2500;
            ymin = -2500;
            ymax = 2500;

            handles.plot_data.x(:) = 0;

        otherwise
            error('Invalid plot type encountered');
    end;

    % Plot the initial values
    p = plot(x, y, marker);
    axis([xmin, xmax, ymin, ymax]);
end

function bladeRF_fft_OpeningFcn(hObject, eventdata, handles, varargin)
    % Choose default command line output for bladeRF_fft
    handles.output = hObject;

    % UIWAIT makes bladeRF_fft wait for user response (see UIRESUME)
    % uiwait(handles.figure1);
    handles.bladerf = bladeRF('*:instance=0') ;

    % Running flag
    handles.running = false ;

    % Set text labels
    set(handles.vga1, 'String', num2str(handles.bladerf.rx.vga1)) ;
    set(handles.vga2, 'String', num2str(handles.bladerf.rx.vga2)) ;
    set_lnagain_selection(handles.lnagain, handles.bladerf.rx.lna);

    val = handles.bladerf.rx.samplerate ;
    set(handles.samplerate, 'String', num2str(val)) ;
    set(handles.samplerate, 'Value', val ) ;

    set_bandwidth_selection(handles.bandwidth, handles.bladerf.rx.bandwidth);

    val = handles.bladerf.rx.frequency ;
    set(handles.frequency, 'String', num2str(val)) ;
    set(handles.frequency, 'Value', val) ;

    set(handles.corr_dc_i, 'String', num2str(handles.bladerf.rx.corrections.dc_i)) ;
    set(handles.corr_dc_q, 'String', num2str(handles.bladerf.rx.corrections.dc_q)) ;
    set(handles.corr_gain, 'String', num2str(handles.bladerf.rx.corrections.gain)) ;
    set(handles.corr_phase, 'String', num2str(handles.bladerf.rx.corrections.phase)) ;

    % Initialize plot for default display mode
    handles.plot_data.x = zeros(1, 4096);
    handles.plot_data.y = zeros(1, 4096);

    display_types = get(handles.displaytype, 'String');
    default_type  = get(handles.displaytype, 'Value');
    [handles.plot_data.x, handles.plot_data.y, handles.plot] = ...
        new_plot(handles, display_types{default_type});

    % Update handles structure
    guidata(hObject, handles);
end

function varargout = bladeRF_fft_OutputFcn(hObject, eventdata, handles)
    varargout{1} = handles.output;
end

function displaytype_Callback(hObject, eventdata, handles)
    items = get(hObject,'String') ;
    index = get(hObject,'Value') ;
    [handles.plot_data.x, handles.plot_data.y, handles.plot] = ...
        new_plot(handles, items{index});
end

function displaytype_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function actionbutton_Callback(hObject, eventdata, handles)
    action = get(hObject,'String');
    switch action
        case 'Start'
            set(hObject,'String','Stop') ;
            handles.running = true ;
            handles.bladerf.rx.start
            guidata(hObject, handles);

            num_samples = length(handles.plot_data.y);

            % Why can't I check handles.running here?
            % while handles.running == true
            while strcmp(get(hObject,'String'), 'Stop') == true
                [handles.plot_data.y(:), actual, underrun] =...
                    handles.bladerf.rx.receive(num_samples, 5000, 0);

                handles.plot.YData(:) = abs(handles.plot_data.y);
                guidata(hObject, handles) ;
                %refreshdata(handles.plot);

                if underrun
                    disp 'Underrun'
                end
            end
            handles.bladerf.rx.stop

        case 'Stop'
            set(hObject,'String','Start') ;
            handles.running = false ;
            guidata(hObject, handles);

        otherwise
            error(strcat('Unexpected button action: ', action))
    end
end

function lnagain_Callback(hObject, eventdata, handles)
    items = get(hObject,'String') ;
    index = get(hObject,'Value') ;

    %fprintf('GUI Request to set LNA gain to: %s\n', items{index})

    handles.bladerf.rx.lna = items{index} ;
    guidata(hObject, handles);
end

function lnagain_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function vga1_Callback(hObject, eventdata, handles)
    val = str2num(get(hObject, 'String')) ;
    if isempty(val)

        val = handles.bladerf.rx.vga1 ;
    end

    %fprintf('GUI request to set VGA1: %d\n', val);

    handles.bladerf.rx.vga1 = val ;
    set(hObject,'String', num2str(handles.bladerf.rx.vga1)) ;
    guidata(hObject, handles);
end

function vga1_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function vga2_Callback(hObject, eventdata, handles)
    val = str2num(get(hObject,'String')) ;
    if isempty(val)
        val = handles.bladerf.rx.vga2 ;
    end

    %fprintf('GUI request to set VGA2: %d\n', val);

    handles.bladerf.rx.vga2 = val ;
    set(hObject, 'String', num2str(handles.bladerf.rx.vga2)) ;
    guidata(hObject, handles);
end

function vga2_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function figure1_DeleteFcn(hObject, eventdata, handles)

end

function bandwidth_Callback(hObject, eventdata, handles)
    values = get(hObject,'String') ;
    index = get(hObject,'Value') ;
    selected = str2num(values{index}) ;

    bw = selected * 1.0e6;
    %fprintf('GUI request to set bandwidth to: %f\n', bw);

    handles.bladerf.rx.bandwidth = bw;
end

function bandwidth_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function corr_dc_i_Callback(hObject, eventdata, handles)
    val = str2num(get(hObject, 'String'));
    if isempty(val)
        val = handles.bladerf.rx.corrections.dc_i;
    end

    fprintf('GUI request to set I DC correction to: %f\n', val)
    handles.bladerf.rx.corrections.dc_i = val;

    set(hObject, 'String', num2str(val));
    set(hObject, 'Value',  val);
end

function corr_dc_i_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function corr_dc_q_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function corr_dc_q_Callback(hObject, eventdata, handles)
    val = str2num(get(hObject, 'String'));
    if isempty(val)
        val = handles.bladerf.rx.corrections.dc_q;
    end

    fprintf('GUI request to set IQ DC correction to: %f\n', val)
    handles.bladerf.rx.corrections.dc_q = val;

    set(hObject, 'String', num2str(val));
    set(hObject, 'Value',  val);
end

function corr_gain_Callback(hObject, eventdata, handles)
    val = str2num(get(hObject, 'String'));
    if isempty(val)
        val = handles.bladerf.rx.corrections.gain;
    end

    fprintf('GUI request to set IQ gain correction to: %f\n', val)
    handles.bladerf.rx.corrections.gain = val;

    set(hObject, 'String', num2str(val));
    set(hObject, 'Value',  val);
end


function corr_gain_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function corr_phase_Callback(hObject, eventdata, handles)
    val = str2num(get(hObject, 'String'));
    if isempty(val)
        val = handles.bladerf.rx.corrections.phase;
    end

    %fprintf('GUI request to set phase correction to: %f\n', val)
    handles.bladerf.rx.corrections.phase = val;

    val = handles.bladerf.rx.corrections.phase;
    set(hObject, 'String', num2str(val));
    set(hObject, 'Value', val);
end

function corr_phase_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function samplerate_Callback(hObject, eventdata, handles)
    val = str2num(get(hObject, 'String')) ;
    if isempty(val)
        val = handles.bladerf.rx.samplerate ;
    end

    %fprintf('GUI request to set samplerate to: %f\n', val);

    handles.bladerf.rx.samplerate = val ;
    val = handles.bladerf.rx.samplerate ;
    set(hObject, 'String', num2str(val)) ;
    set(hObject, 'Value', val) ;
end

function samplerate_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function frequency_Callback(hObject, eventdata, handles)
    val = str2num(get(hObject, 'String')) ;
    if isempty(val)
        val = handles.bladerf.rx.frequency ;
    end

    %fprintf('GUI request to set frequency: %d\n', val);

    handles.bladerf.rx.frequency = val ;
    set(hObject, 'String', num2str(val)) ;
    set(hObject, 'Value', val) ;
end

function frequency_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function devicelist_Callback(hObject, eventdata, handles)
    items = get(hObject,'String') ;
    index = get(hObject,'Value') ;
    devstring = items{index} ;
    handles.bladerf.delete ;
    guidata(hObject, handles) ;
    handles.bladerf = bladeRF(devstring) ;
    guidata(hObject, handles);
end

function devicelist_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    devs = bladeRF.devices ;
    list = {} ;
    for idx=1:length(devs)
        switch devs(idx).backend
            case 'BLADERF_BACKEND_LIBUSB'
                backend = 'libusb' ;
            case 'BLADERF_BACKEND_CYPRESS'
                backend = 'cypress' ;
            otherwise
                disp('Not sure which backend is being used') ;
                backend = '*' ;
        end
        list{idx} = strcat(backend, ':serial=', devs(idx).serial) ;
    end
    set(hObject, 'String', list) ;
end
