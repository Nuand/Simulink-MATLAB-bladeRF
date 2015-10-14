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

    val = handles.bladerf.rx.samplerate ;
    set(handles.samplerate, 'String', num2str(val)) ;
    set(handles.samplerate, 'Value', val ) ;

    val = handles.bladerf.rx.frequency ;
    set(handles.frequency, 'String', num2str(val)) ;
    set(handles.frequency, 'Value', val) ;

    set(handles.corr_dc, 'String', num2str(handles.bladerf.rx.corrections.dc)) ;
    set(handles.corr_gain, 'String', num2str(handles.bladerf.rx.corrections.gain)) ;
    set(handles.corr_phase, 'String', num2str(handles.bladerf.rx.corrections.phase)) ;

    % Update handles structure
    guidata(hObject, handles);
end

function varargout = bladeRF_fft_OutputFcn(hObject, eventdata, handles)
    varargout{1} = handles.output;
end

function displaytype_Callback(hObject, eventdata, handles)
    items = get(hObject,'String') ;
    index = get(hObject,'Value') ;
    switch items{index}
        case 'FFT (dB)'
            set(handles.xlabel, 'String', 'Frequency (MHz)') ;

        case 'FFT (linear)'
            set(handles.xlabel, 'String', 'Frequency (MHz)') ;

        case 'Time (2-Channel)'
            set(handles.axes1, 'XScale', 'linear') ;
            set(handles.xlabel, 'String', 'Time (s)') ;

        case 'Time (XY)'
            set(handles.axes1,'XScale','linear') ;
            set(handles.xlabel,'String', 'X (counts)') ;

        otherwise
            disp(strcat('Cannot figure out ', items{index}))

    end
end

function displaytype_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function plot_data(handles, f, s, x)
    items = get(handles.displaytype,'String') ;
    index = get(handles.displaytype,'Value') ;
    selected = items{index} ;
    axes(handles.axes1) ;
    switch selected
        case 'FFT (dB)'
            plot(linspace(f-s/2, f+s/2, length(x)), 20*log10(abs(fftshift(fft(x))))) ;
            axis([f-s/2, f+s/2 0 140]) ;

        case 'FFT (linear)'
            plot(linspace(f-s/2, f+s/2, length(x)), abs(fftshift(fft(x)))) ;
            axis([f-s/2, f+s/2, 0, 10^6]) ;

        case 'Time (2-Channel)'
            plot(linspace(0,(length(x)-1)/s,length(x)), real(x), linspace(0,(length(x)-1)/s,length(x)), imag(x)) ;
            axis([0, (length(x)-1)/s, -2500, 2500]) ;

        case 'Time (XY)'
            plot(x, 'b.') ;
            axis([-2500, 2500, -2500, 2500]) ;

        otherwise
            disp(strcat('Dunno what to do with ', selected))
    end
    grid on ;
end

function actionbutton_Callback(hObject, eventdata, handles)
    switch get(hObject,'String')
        case 'Start'
            set(hObject,'String','Stop') ;
            handles.running = true ;
            f = double(handles.bladerf.rx.frequency) ;
            s = double(handles.bladerf.rx.samplerate) ;
            handles.bladerf.rx.start
            guidata(hObject, handles);
            % Why can't I check handles.running here?
            % while handles.running == true
            while strcmp(get(hObject,'String'), 'Stop') == true
                f = get(handles.frequency,'Value') ;
                s = get(handles.samplerate,'Value') ;
                x = handles.bladerf.rx.receive(4096, 5000, 0) ;
                plot_data(handles, f, s, x) ;
                drawnow ;
                guidata(hObject, handles) ;
            end
            handles.bladerf.rx.stop

        case 'Stop'
            set(hObject,'String','Start') ;
            handles.running = false ;
            guidata(hObject, handles);

        otherwise
            warning('No idea what you''re talking about') ;
    end
end

function lnagain_Callback(hObject, eventdata, handles)
    items = get(hObject,'String') ;
    index = get(hObject,'Value') ;
    handles.bladerf.rx.lna = items{index} ;
    guidata(hObject, handles);
end

function lnagain_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function vga1_Callback(hObject, eventdata, handles)
    val = str2double(get(hObject, 'String')) ;
    if isnan(val) == true
        val = handles.bladerf.rx.vga1 ;
        disp('Not numeric') ;
    end
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
    val = str2double(get(hObject,'String')) ;
    if isnan(val) == true
        val = handles.bladerf.rx.vga2 ;
        disp( 'Not Numeric' ) ;
    end
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
    selected = str2double(values{index}) ;
    handles.bladerf.rx.bandwidth = selected * 1.0e6 ;
end

function bandwidth_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function corr_dc_Callback(hObject, eventdata, handles)

end

function corr_dc_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function corr_gain_Callback(hObject, eventdata, handles)

end

function corr_gain_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function corr_phase_Callback(hObject, eventdata, handles)

end

function corr_phase_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function samplerate_Callback(hObject, eventdata, handles)
    val = str2num(get(hObject, 'String')) ;
    if isnan(val) == true
        val = handles.bladerf.rx.samplerate ;
    end
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
    if isnan(val) == true
        val = handles.bladerf.rx.frequency ;
    end
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
