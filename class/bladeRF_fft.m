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

function update_plot_config(hObject, handles)
    id    = get(handles.displaytype, 'Value');
    if id < 1 || id > length(handles.plots)
        error('Bug: Got invalid display type ID');
    end

    info = handles.plots{id};

    for n = 1:length(handles.plots)
        if n == id
            for l = 1:length(handles.plots{n}.lines)
                handles.plots{n}.lines(l).Visible = 'on';
                %fprintf('plot %s ch %d = %s\n', handles.plots{n}.name, l, handles.plots{n}.lines(l).Visible);
            end
        else
           for l = 1:length(handles.plots{n}.lines)
                handles.plots{n}.lines(l).Visible = 'off';
                %fprintf('plot %s ch %d = %s\n', handles.plots{n}.name, l, handles.plots{n}.lines(l).Visible);
           end
        end
    end

    num_samples = getappdata(hObject, 'num_samples');
    if isempty(num_samples)
        error('Application property "num_samples" is unexpectedly empty.');
    end

    % Reset data so we don't see "random" junk when switching displays
    switch handles.plots{id}.name
        case { 'FFT (dB)', 'FFT (linear)' }
            x = linspace(double(info.xmin), double(info.xmax), num_samples);
            handles.plots{id}.lines(1).XData = x;
            handles.plots{id}.lines(1).YData = zeros(1, num_samples);

        case 'Time (2-Channel)'
            x = linspace(double(info.xmin), double(info.xmax), num_samples);

            handles.plots{id}.lines(1).XData = x;
            handles.plots{id}.lines(1).YData = zeros(1, num_samples);

            handles.plots{id}.lines(2).XData = x;
            handles.plots{id}.lines(2).YData = zeros(1, num_samples);

        case 'Time (XY)'
            handles.plots{id}.lines(1).XData = zeros(1, num_samples);
            handles.plots{id}.lines(1).YData = zeros(1, num_samples);
    end

    % Update the axes limits for this plot
    handles.axes1.XLim = [info.xmin info.xmax];
    handles.axes1.YLim = [info.ymin info.ymax];

    % Update the plot label
    set(handles.xlabel, 'String', info.xlabel);
end

function [plot_info] = init_plot_type(hObject, handles, type)

    Fc = handles.bladerf.rx.frequency;
    Fs = handles.bladerf.rx.samplerate;

    plot_info.name = type;

    blue = [0 0 1];
    red  = [1 0 0];

    num_samples = getappdata(hObject, 'num_samples');
    if isempty(num_samples)
        error('Application property "num_samples" is unexpectedly empty.');
    end

    switch type
        case 'FFT (dB)'
            plot_info.xlabel = 'Frequency (MHz)';

            plot_info.xmin = (Fc - Fs/2);
            plot_info.xmax = (Fc + Fs/2);
            plot_info.ymin = 0;
            plot_info.ymax = 140;

            x = linspace(double(plot_info.xmin), double(plot_info.xmax), num_samples);
            y = zeros(1, num_samples);
            plot_info.lines(1) = line(x, y);
            plot_info.lines(1).Color = blue;
            plot_info.lines(1).Marker = 'none';
            plot_info.lines(1).LineStyle = '-';

        case 'FFT (linear)'
            plot_info.xlabel = 'Frequency (MHz)';

            plot_info.xmin = (Fc - Fs/2);
            plot_info.xmax = (Fc + Fs/2);
            plot_info.ymin = 0;
            plot_info.ymax = 1e6;

            x = linspace(double(plot_info.xmin), double(plot_info.xmax), num_samples);
            y = zeros(1, num_samples);

            plot_info.lines(1) = line(x, y);
            plot_info.lines(1).Color = blue;
            plot_info.lines(1).Marker = 'none';
            plot_info.lines(1).LineStyle = '-';

        case 'Time (2-Channel)'
            plot_info.xlabel = 'Time (s)';

            plot_info.xmin = 0;
            plot_info.xmax = (num_samples - 1) / Fs;
            plot_info.ymin = -2500;
            plot_info.ymax = 2500;

            x = linspace(double(plot_info.xmin), double(plot_info.xmax), num_samples);
            y = zeros(1, num_samples);

            plot_info.lines(1) = line(x, y);
            plot_info.lines(1).Color = blue;
            plot_info.lines(1).Marker = 'none';
            plot_info.lines(1).LineStyle = '-';

            plot_info.lines(2) = line(x, y);
            plot_info.lines(2).Color = red;
            plot_info.lines(2).Marker = 'none';
            plot_info.lines(2).LineStyle = '-';

        case 'Time (XY)'
            plot_info.marker = 'b-';
            plot_info.xlabel = 'X (counts)';

            plot_info.xmin = -2500;
            plot_info.xmax = 2500;
            plot_info.ymin = -2500;
            plot_info.ymax = 2500;

            x = zeros(1, num_samples);
            y = zeros(1, num_samples);

            plot_info.lines(1) = line(x, y);
            plot_info.lines(1).Color = blue;
            plot_info.lines(1).Marker = '.';
            plot_info.lines(1).LineStyle = 'none';
            plot_info.lines(1).Visible = 'off';

        otherwise
            error('Invalid plot type encountered');
    end
end

function bladeRF_fft_OpeningFcn(hObject, ~, handles, varargin)
    % Choose default command line output for bladeRF_fft
    handles.output = hObject;

    % UIWAIT makes bladeRF_fft wait for user response (see UIRESUME)
    % uiwait(handles.figure1);
    handles.bladerf = bladeRF('*:instance=0') ;

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

    % "Running" flag
    setappdata(hObject.Parent, 'run', 0);

    % Number of samples we'll read from the device at each iteraion
    setappdata(hObject.Parent, 'num_samples', 4096);

    %  Create plot information for each type of lot
    type_strs = get(handles.displaytype, 'String');

    handles.plots = cell(1, length(type_strs));
    for n = 1:length(handles.plots)
        handles.plots{n} = init_plot_type(hObject.Parent, handles, type_strs{n});
    end

    update_plot_config(hObject.Parent, handles);

    % Update handles structure
    guidata(hObject, handles);
end

function varargout = bladeRF_fft_OutputFcn(~, ~, handles)
    varargout{1} = handles.output;
end

function displaytype_Callback(hObject, ~, handles)
    update_plot_config(hObject.Parent.Parent, handles);
end

function displaytype_CreateFcn(hObject, ~, ~)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function actionbutton_Callback(hObject, ~, handles)
    action = get(hObject,'String');
    switch action
        case 'Start'
            set(hObject,'String','Stop') ;
            handles.bladerf.rx.start;
            guidata(hObject, handles);

            start = cputime;
            update = 1;
            framerate = 30;

            num_samples = getappdata(hObject.Parent.Parent, 'num_samples');
            if isempty(num_samples)
                error('Application property "num_samples" is unexpectedly empty.');
            end

            samples = zeros(1, num_samples);

            run = 1;
            setappdata(hObject.Parent.Parent, 'run', 1);

            while run == 1

                [samples(:), ~, underrun] = ...
                    handles.bladerf.rx.receive(num_samples, 5000, 0);

                if underrun
                    fprintf('Underrun @ t=%f\n', cputime - start);
                elseif update
                    update = 0;
                    id = get(handles.displaytype, 'Value');

                    switch handles.plots{id}.name
                        case 'FFT (dB)'
                            handles.plots{id}.lines(1).YData = 20*log10(abs(fftshift(fft(samples))));

                        case 'FFT (linear)'
                            handles.plots{id}.lines(1).YData = abs(fftshift(fft(samples)));

                        case 'Time (2-Channel)'
                            handles.plots{id}.lines(1).YData = real(samples);
                            handles.plots{id}.lines(2).YData = imag(samples);


                        case 'Time (XY)'
                            handles.plots{id}.lines(1).XData = real(samples);
                            handles.plots{id}.lines(1).YData = imag(samples);

                        otherwise
                            error('Invalid plot selection encountered');
                    end

                    drawnow;
                    tic;
                else
                    t = toc;
                    update = (t > (1/framerate));
                end

                run = getappdata(hObject.Parent.Parent, 'run');
            end

            handles.bladerf.rx.stop;
            figHandle = getappdata(hObject.Parent.Parent, 'ready_to_delete');
            if ~isempty(figHandle)
                delete(figHandle);
            end

        case 'Stop'
            setappdata(hObject.Parent.Parent, 'run', 0);
            set(hObject,'String','Start') ;
            guidata(hObject, handles);

        otherwise
            error(strcat('Unexpected button action: ', action))
    end
end

function lnagain_Callback(hObject, ~, handles)
    items = get(hObject,'String') ;
    index = get(hObject,'Value') ;

    %fprintf('GUI Request to set LNA gain to: %s\n', items{index})

    handles.bladerf.rx.lna = items{index} ;
    guidata(hObject, handles);
end

function lnagain_CreateFcn(hObject, ~, ~)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function vga1_Callback(hObject, ~, handles)
    val = str2num(get(hObject, 'String')) ;
    if isempty(val)

        val = handles.bladerf.rx.vga1 ;
    end

    %fprintf('GUI request to set VGA1: %d\n', val);

    handles.bladerf.rx.vga1 = val ;
    set(hObject,'String', num2str(handles.bladerf.rx.vga1)) ;
    guidata(hObject, handles);
end

function vga1_CreateFcn(hObject, ~, ~)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function vga2_Callback(hObject, ~, handles)
    val = str2num(get(hObject,'String')) ;
    if isempty(val)
        val = handles.bladerf.rx.vga2 ;
    end

    %fprintf('GUI request to set VGA2: %d\n', val);

    handles.bladerf.rx.vga2 = val ;
    set(hObject, 'String', num2str(handles.bladerf.rx.vga2)) ;
    guidata(hObject, handles);
end

function vga2_CreateFcn(hObject, ~, ~)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function bandwidth_Callback(hObject, ~, handles)
    values = get(hObject,'String') ;
    index = get(hObject,'Value') ;
    selected = str2num(values{index}) ;

    bw = selected * 1.0e6;
    %fprintf('GUI request to set bandwidth to: %f\n', bw);

    handles.bladerf.rx.bandwidth = bw;
end

function bandwidth_CreateFcn(hObject, ~, ~)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function corr_dc_i_Callback(hObject, ~, handles)
    val = str2num(get(hObject, 'String'));
    if isempty(val)
        val = handles.bladerf.rx.corrections.dc_i;
    end

    %fprintf('GUI request to set I DC correction to: %f\n', val)
    handles.bladerf.rx.corrections.dc_i = val;

    set(hObject, 'String', num2str(val));
    set(hObject, 'Value',  val);
end

function corr_dc_i_CreateFcn(hObject, ~, ~)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function corr_dc_q_CreateFcn(hObject, ~, ~)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function corr_dc_q_Callback(hObject, ~, handles)
    val = str2num(get(hObject, 'String'));
    if isempty(val)
        val = handles.bladerf.rx.corrections.dc_q;
    end

    %fprintf('GUI request to set IQ DC correction to: %f\n', val)
    handles.bladerf.rx.corrections.dc_q = val;

    set(hObject, 'String', num2str(val));
    set(hObject, 'Value',  val);
end

function corr_gain_Callback(hObject, ~, handles)
    val = str2num(get(hObject, 'String'));
    if isempty(val)
        val = handles.bladerf.rx.corrections.gain;
    end

    %fprintf('GUI request to set IQ gain correction to: %f\n', val)
    handles.bladerf.rx.corrections.gain = val;

    set(hObject, 'String', num2str(val));
    set(hObject, 'Value',  val);
end


function corr_gain_CreateFcn(hObject, ~, ~)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function corr_phase_Callback(hObject, ~, handles)
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

function corr_phase_CreateFcn(hObject, ~, ~)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function samplerate_Callback(hObject, ~, handles)
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

function samplerate_CreateFcn(hObject, ~, ~)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function frequency_Callback(hObject, ~, handles)
    val = str2num(get(hObject, 'String')) ;
    if isempty(val)
        val = handles.bladerf.rx.frequency ;
    end

    %fprintf('GUI request to set frequency: %d\n', val);

    handles.bladerf.rx.frequency = val ;
    set(hObject, 'String', num2str(val)) ;
    set(hObject, 'Value', val) ;
end

function frequency_CreateFcn(hObject, ~, ~)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function devicelist_Callback(hObject, ~, handles)
    items = get(hObject,'String') ;
    index = get(hObject,'Value') ;
    devstring = items{index} ;
    handles.bladerf.delete ;
    guidata(hObject, handles) ;
    handles.bladerf = bladeRF(devstring) ;
    guidata(hObject, handles);
end

function devicelist_CreateFcn(hObject, ~, ~)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    devs = bladeRF.devices;
    list = cell(1, length(devs));
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

function figure1_CloseRequestFcn(hObject, ~, handles)
    running = getappdata(hObject.Parent, 'run');
    if running == 1
        % Our hackish receive loop is still running. Flag it to shut
        % down and have it take care of the final delete().
        setappdata(hObject.Parent, 'run', 0);
        setappdata(hObject.Parent, 'ready_to_delete', hObject)
    else
        % We can shut down now.
        delete(hObject);
    end
end
