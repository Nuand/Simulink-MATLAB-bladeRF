classdef bladeRF_Simulink < matlab.System & ...
                            matlab.system.mixin.Propagates & ...
                            matlab.system.mixin.CustomIcon
    %% Properties
    properties
        verbosity           = 'info'    % libbladeRF verbosity

        rx_frequency        = 915e6;    % Frequency [230e6, 3.8e9]
        rx_lna              = 6         % LNA Gain  [0, 3, 6]
        rx_vga1             = 30;       % VGA1 Gain [5, 30]
        rx_vga2             = 0;        % VGA2 Gain [0, 30]

        tx_frequency        = 920e6;    % Frequency [230e6, 3.8e9]
        tx_vga1             = -8;       % VGA1 Gain [-35, -4]
        tx_vga2             = 16;       % VGA1 Gain [0, 25]
    end

    properties(Nontunable)
        device_string       = '';       % Device specification string
        loopback_mode       = 'None'    % Active loopback mode

        rx_bandwidth        = '1.5';    % LPF Bandwidth (MHz)
        rx_samplerate       = 3e6;      % Sample rate
        rx_num_buffers      = 64;       % Number of stream buffers to use
        rx_num_transfers    = 16;       % Number of USB transfers to use
        rx_buf_size         = 16384;    % Size of each stream buffer, in samples (must be multiple of 1024)
        rx_step_size        = 16384;    % Number of samples to RX during each simulation step
        rx_timeout_ms       = 5000;     % Stream timeout (ms)

        tx_bandwidth        = '1.5';    % LPF Bandwidth (MHz)
        tx_samplerate       = 3e6;      % Sample rate
        tx_num_buffers      = 64;       % Number of stream buffers to use
        tx_num_transfers    = 16;       % Number of USB transfers to use
        tx_buf_size         = 16384;    % Size of each stream buffer, in samples (must be multiple of 1024)
        tx_step_size        = 16384;    % Number of samples to TX during each simulation step
        tx_timeout_ms       = 5000;     % Stream timeout (ms)
    end

    properties(Logical, Nontunable)
        enable_rx           = true;     % Enable Receiver
        enable_tx           = false;    % Enable Transmitter
        xb200               = false     % Enable use of XB-200 (must be attached)
    end

    properties(Hidden, Transient)
        rx_bandwidthSet = matlab.system.StringSet({ ...
            '1.5',  '1.75', '2.5',  '2.75',  ...
            '3',    '3.84', '5',    '5.5',   ...
            '6',    '7',    '8.75', '10',    ...
            '12',   '14',   '20',   '28'     ...
        });

        tx_bandwidthSet = matlab.system.StringSet({ ...
            '1.5',  '1.75', '2.5',  '2.75',  ...
            '3',    '3.84', '5',    '5.5',   ...
            '6',    '7',    '8.75', '10',    ...
            '12',   '14',   '20',   '28'     ...
        });

        loopback_modeSet = matlab.system.StringSet({
            'None', ...
            'BB_TXLPF_RXVGA2', 'BB_TXVGA1_RXVGA2', 'BB_TXLPF_RXPLF', ...
            'RF_LNA1', 'RF_LNA2', 'RF_LNA3', ...
            'Firmware'
        });

        verbositySet = matlab.system.StringSet({
            'Verbose', 'Debug', 'Info', 'Warning', 'Critical', 'Silent' ...
        });
    end

    properties (Access = private)
        device

        % Cache previously set tunable values to avoid querying the device
        % for all properties when only one changes.
        curr_rx_frequency
        curr_rx_lna
        curr_rx_vga1
        curr_rx_vga2
        curr_tx_frequency
        curr_tx_vga1
        curr_tx_vga2
    end

    %% Static Methods
    methods (Static, Access = protected)
        function groups = getPropertyGroupsImpl
            device_section = matlab.system.display.Section(...
                'Title', 'Device', ...
                'PropertyList', {'device_string', 'loopback_mode', 'xb200' } ...
            );

            rx_gain_section = matlab.system.display.Section(...
                'Title', 'Gain', ...
                'PropertyList', { 'rx_lna', 'rx_vga1', 'rx_vga2'} ...
            );

            rx_stream_section = matlab.system.display.Section(...
                'Title', 'Stream', ...
                'PropertyList', {'rx_num_buffers', 'rx_num_transfers', 'rx_buf_size', 'rx_timeout_ms', 'rx_step_size', } ...
            );

            rx_section_group = matlab.system.display.SectionGroup(...
                'Title', 'RX Configuration', ...
                'PropertyList', { 'enable_rx', 'rx_frequency', 'rx_samplerate', 'rx_bandwidth' }, ...
                'Sections', [ rx_gain_section, rx_stream_section ] ...
            );

            tx_gain_section = matlab.system.display.Section(...
                'Title', 'Gain', ...
                'PropertyList', { 'tx_vga1', 'tx_vga2'} ...
            );

            tx_stream_section = matlab.system.display.Section(...
                'Title', 'Stream', ...
                'PropertyList', {'tx_num_buffers', 'tx_num_transfers', 'tx_buf_size', 'tx_timeout_ms', 'tx_step_size', } ...
            );

            tx_section_group = matlab.system.display.SectionGroup(...
                'Title', 'TX Configuration', ...
                'PropertyList', { 'enable_tx', 'tx_frequency', 'tx_samplerate', 'tx_bandwidth' }, ...
                'Sections', [ tx_gain_section, tx_stream_section ] ...
            );

            misc_section = matlab.system.display.Section(...
                'Title', 'Miscellaneous', ...
                'PropertyList', {'verbosity'} ...
            );

            groups = [ device_section, rx_section_group, tx_section_group, misc_section ];
        end

        function header = getHeaderImpl
            text = 'This block provides access to a Nuand bladeRF device via libbladeRF MATLAB bindings.';
            header = matlab.system.display.Header('bladeRF_Simulink', ...
                'Title', 'bladeRF', 'Text',  text ...
            );
        end
    end

    methods (Access = protected)
        %% Output setup
        function count = getNumOutputsImpl(obj)
            if obj.enable_rx == true
                count = 2;
            else
                count = 0;
            end

            if obj.enable_tx == true
                count = count + 1;
            end
        end

        function varargout = getOutputNamesImpl(obj)
            if obj.enable_rx == true
                varargout{1} = 'RX Samples';
                varargout{2} = 'RX Overrun';
                n = 3;
            else
                n = 1;
            end

            if obj.enable_tx == true
                varargout{n} = 'TX Underrun';
            end
        end

        function varargout = getOutputDataTypeImpl(obj)
            if obj.enable_rx == true
                varargout{1} = 'double';    % RX Samples
                varargout{2} = 'logical';   % RX Overrun
                n = 3;
            else
                n = 1;
            end

            if obj.enable_tx == true
                varargout{n} = 'logical';   % TX Underrun
            end
        end

        function varargout = getOutputSizeImpl(obj)
            if obj.enable_rx == true
                varargout{1} = [obj.rx_step_size 1];  % RX Samples
                varargout{2} = [1 1];                 % RX Overrun
                n = 3;
            else
                n = 1;
            end

            if obj.enable_tx == true
                varargout{n} = [1 1];                 % TX Underrun
            end
        end

        function varargout = isOutputComplexImpl(obj)
            if obj.enable_rx == true
                varargout{1} = true;    % RX Samples
                varargout{2} = false;   % RX Overrun
                n = 3;
            else
                n = 1;
            end

            if obj.enable_tx == true
                varargout{n} = false;   % TX Underrun
            end
        end

        function varargout  = isOutputFixedSizeImpl(obj)
            if obj.enable_rx == true
                varargout{1} = true;    % RX Samples
                varargout{2} = true;    % RX Overrun
                n = 3;
            else
                n = 1;
            end

            if obj.enable_tx == true
                varargout{n} = true;    % TX Underrun
            end
        end

        %% Input setup
        function count = getNumInputsImpl(obj)
            if obj.enable_tx == true
                count = 1;
            else
                count = 0;
            end
        end

        function varargout = getInputNamesImpl(obj)
            if obj.enable_tx == true
                varargout{1} = 'TX Samples';
            else
                varargout = [];
            end
        end

        function varargout = getInputDataTypeImpl(obj)
            if obj.enable_tx == true
                varargout{1} = 'double'; % TX Samples
            else
                varargout = [];
            end
        end

        function varargout = getInputSizeImpl(obj)
            if obj.enable_tx
                varargout{1} = [obj.tx_step_size 1]; % TX Samples
            else
                varargout = [];
            end
        end

        function varargout = isInputComplexImpl(obj)
            if obj.enable_tx
                varargout{1} = true; % TX Samples
            else
                varargout = [];
            end
        end

        function varargout = isInputFixedSizeImp(obj)
            if obj.enable_tx == true
                varargout{1} = true; % TX Samples
            else
                varargout = [];
            end
        end

        %% Property and Execution Handlers
        function icon = getIconImpl(~)
            icon = sprintf('Nuand\nbladeRF');
        end

        function setupImpl(obj)
            obj.device = bladeRF(obj.device_string);

            %% RX Setup
            obj.device.rx.config.num_buffers   = obj.rx_num_buffers;
            obj.device.rx.config.buffer_size   = obj.rx_buf_size;
            obj.device.rx.config.num_transfers = obj.rx_num_transfers;
            obj.device.rx.config.timeout_ms    = obj.rx_timeout_ms;

            obj.device.rx.frequency  = obj.rx_frequency;
            obj.curr_rx_frequency    = obj.device.rx.frequency;

            obj.device.rx.samplerate = obj.rx_samplerate;
            obj.device.rx.bandwidth  = str2double(obj.rx_bandwidth) * 1e6;

            obj.device.rx.lna        = obj.rx_lna;
            obj.curr_rx_lna          = bladeRF.str2lna(obj.device.rx.lna);

            obj.device.rx.vga1       = obj.rx_vga1;
            obj.curr_rx_vga1         = obj.device.rx.vga1;

            obj.device.rx.vga2       = obj.rx_vga2;
            obj.curr_rx_vga2         = obj.device.rx.vga2;
        end

        function releaseImpl(obj)
            obj.device.close();
        end

        function resetImpl(obj)
            obj.device.rx.stop();
            obj.device.tx.stop();
        end

        % Perform a read of received samples and an 'overrun' array that denotes whether
        % the associated samples is invalid due to a detected overrun.
        function [rx_samples, rx_overrun] = stepImpl(obj)

            if obj.enable_rx == true
                if obj.device.rx.running == false
                    obj.device.rx.start();
                end

                [rx_samples, ~, ~, rx_overrun] = obj.device.receive(obj.rx_step_size);
            end

            if obj.enable_tx == true
                if obj.device.tx.running == false
                    obj.device.tx.start();
                end
            end
        end

        function processTunedPropertiesImpl(obj)

            %% RX Properties
            if isChangedProperty(obj, 'rx_frequency') && obj.rx_frequency ~= obj.curr_rx_frequency
                obj.device.rx.frequency = obj.rx_frequency;
                obj.curr_rx_frequency   = obj.device.rx.frequency;
                disp('Updated RX frequency');
            end

            if isChangedProperty(obj, 'rx_lna') && obj.rx_lna ~= obj.curr_rx_lna
                obj.device.rx.lna = obj.rx_lna;
                obj.rx_curr_lna   = bladeRF.str2lna(obj.device.rx.lna);
                disp('Updated RX LNA gain');
            end

            if isChangedProperty(obj, 'rx_vga1') && obj.rx_vga1 ~= obj.curr_rx_vga1
                obj.device.rx.vga1 = obj.vga1;
                obj.curr_rx_vga1   = obj.device.rx.vga1;
                disp('Updated RX VGA1 gain');
            end

            if isChangedProperty(obj, 'rx_vga2') && obj.rx_vga2 ~= obj.curr_rx_vga2
                obj.device.rx.vga2 = obj.rx_vga2;
                obj.curr_rx_vga2   = obj.device.rx.vga2;
                disp('Updated RX VGA2 gain');
            end

            %% TX Properties
            if isChangedProperty(obj, 'tx_frequency') && obj.tx_frequency ~= obj.curr_tx_frequency
                obj.device.tx.frequency = obj.tx_frequency;
                obj.curr_tx_frequency   = obj.device.rx.frequency;
                disp('Updated TX frequency');
            end

            if isChangedProperty(obj, 'tx_vga1') && obj.tx_vga1 ~= obj.curr_tx_vga1
                obj.device.tx.vga1 = obj.vga1;
                obj.curr_tx_vga1   = obj.device.tx.vga1;
                disp('Updated TX VGA1 gain');
            end

            if isChangedProperty(obj, 'rx_vga2') && obj.tx_vga2 ~= obj.curr_tx_vga2
                obj.device.rx.vga2 = obj.tx_vga2;
                obj.curr_tx_vga2   = obj.device.tx.vga2;
                disp('Updated TX VGA2 gain');
            end

        end

        function validatePropertiesImpl(obj)
            if obj.enable_rx == false && obj.enable_tx == false
                warning('Neither bladeRF RX or TX is enabled. One or both should be enabled.');
            end

            %% Validate RX properties
            if obj.rx_num_buffers < 1
                error('rx_num_buffers must be > 0.');
            end

            if obj.rx_num_transfers >= obj.rx_num_buffers
                error('rx_num_transfers must be < rx_num_buffers.');
            end

            if obj.rx_buf_size < 1024 || mod(obj.rx_buf_size, 1024) ~= 0
                error('rx_buf_size must be a multiple of 1024.');
            end

            if obj.rx_timeout_ms < 0
                error('rx_timeout_ms must be >= 0.');
            end

            if obj.rx_step_size <= 0
                error('rx_step_size must be > 0.');
            end

            if obj.rx_samplerate < 160.0e3
                error('rx_samplerate must be >= 160 kHz.');
            elseif obj.rx_samplerate > 40e6
                error('rx_samplerate must be <= 40 MHz.')
            end

            if obj.rx_frequency < 230.0e6
                error('rx_frequency must be > 230 MHz.');
            elseif obj.rx_frequency > 3.8e9
                error('rx_frequency must be <= 3.8 GHz.');
            end

            if obj.rx_lna ~= 0 && obj.rx_lna ~= 3 && obj.rx_lna ~= 6
                error('rx_lna must be one of the following: 0, 3, 6');
            end

            if obj.rx_vga1 < 5
                error('rx_vga1 gain must be >= 5.')
            elseif obj.rx_vga1 > 30
                error('rx_vga1 gain must be <= 30.');
            end

            if obj.rx_vga2 < 0
                error('rx_vga2 gain must be >= 0.');
            elseif obj.rx_vga2 > 30
                error('rx_vga2 gain must be <= 30.');
            end

            %% Validate TX Properties
            if obj.tx_num_buffers < 1
                error('tx_num_buffers must be > 0.');
            end

            if obj.tx_num_transfers >= obj.tx_num_buffers
                error('tx_num_transfers must be < tx_num_transfers');
            end

            if obj.tx_buf_size < 1024 || mod(obj.tx_buf_size, 1024) ~= 0
                error('tx_buf_size must be a multiple of 1024.');
            end

            if obj.tx_timeout_ms < 0
                error('tx_timeout_ms must be >= 0.');
            end

            if obj.tx_step_size <= 0
                error('tx_step_size must be > 0.');
            end

            if obj.tx_samplerate < 160.0e3
                error('tx_samplerate must be >= 160 kHz.');
            elseif obj.tx_samplerate > 40e6
                error('tx_samplerate must be <= 40 MHz.')
            end

            if obj.tx_frequency < 230.0e6
                error('tx_frequency must be > 230 MHz.');
            elseif obj.tx_frequency > 3.8e9
                error('tx_frequency must be <= 3.8 GHz.');
            end

            if obj.tx_vga1 < -35
                error('tx_vga1 gain must be >= -35.')
            elseif obj.tx_vga1 > -4
                error('tx_vga1 gain must be <= -4.');
            end

            if obj.tx_vga2 < 0
                error('tx_vga2 gain must be >= 0.');
            elseif obj.tx_vga2 > 25
                error('tx_vga2 gain must be <= 25.');
            end
        end
    end
end
