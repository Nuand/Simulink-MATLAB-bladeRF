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
    % This function has no output args, see OutputFcn.
    % hObject    handle to figure
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    % varargin   command line arguments to bladeRF_fft (see VARARGIN)

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

% --- Outputs from this function are returned to the command line.
function varargout = bladeRF_fft_OutputFcn(hObject, eventdata, handles) 
    varargout{1} = handles.output;
end

% --- Executes on selection change in popupmenu1.
function popupmenu1_Callback(hObject, eventdata, handles)
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

function popupmenu1_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function popupmenu1_KeyPressFcn(hObject, eventdata, handles)

end

function popupmenu1_ButtonDownFcn(hObject, eventdata, handles)

end

function plot_data(handles, f, s, x)
    items = get(handles.popupmenu1,'String') ;
    index = get(handles.popupmenu1,'Value') ;
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
            handles.bladerf.rx.samplerate = 40.0e6 ;
            handles.running = true ;
            f = double(handles.bladerf.rx.frequency) ;
            s = double(handles.bladerf.rx.samplerate) ;
            handles.bladerf.rx.start
            guidata(hObject, handles);
            % Why can't I check handles.running here?
            while strcmp(get(hObject,'String'), 'Stop') == true
                f = get(handles.frequency,'Value') ;
                s = get(handles.samplerate,'Value') ;
                x = handles.bladerf.rx.receive(4096, 5000) ;
                plot_data(handles, f, s, x) ;
                drawnow ;
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

function popupmenu3_Callback(hObject, eventdata, handles)
    values = get(hObject,'String') ;
    index = get(hObject,'Value') ;
    selected = str2double(values{index}) ;
    handles.bladerf.rx.bandwidth = selected * 1.0e6 ;
end

function popupmenu3_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

function corr_dc_Callback(hObject, eventdata, handles)

end

% --- Executes during object creation, after setting all properties.
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
    % hObject    handle to corr_phase (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    empty - handles not created until after all CreateFcns called

    % Hint: edit controls usually have a white background on Windows.
    %       See ISPC and COMPUTER.
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
