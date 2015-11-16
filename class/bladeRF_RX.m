classdef bladeRF_RX < matlab.System & matlab.system.mixin.Propagates
    % bladeRF RX Simulink block

    properties
        frequency           = 915e6;    % Frequency [230e6, 3.8e9]
        lna                 = 6         % LNA Gain  [0, 3, 6]
        vga1                = 30;       % VGA1 Gain [5, 30]
        vga2                = 0;        % VGA2 Gain [0, 30]
    end

    properties(Nontunable)
        device_string       = '';       % Device specification string

        bandwidth           = '1.5';    % Bandwidth (MHz)
        samplerate          = 3e6;      % Sample rate

        num_buffers         = 64;       % Number of stream buffers to use
        num_transfers       = 16;       % Number of USB transfers to use
        samples_per_buffer  = 16384;    % Size of each stream buffer, in samples (must be multiple of 1024)
        timeout_ms          = 5000;     % Stream timeout (ms)

        frame_size          = 16384;    % Number of samples to receive during each simulation step
    end

    %properties(Logical, Nontunable)
    %    xb200 = false % XB-200 Installed
    %end

    properties(Hidden, Transient)
        bandwidthSet = matlab.system.StringSet({ ...
            '1.5',  '1.75', '2.5',  '2.75',  ...
            '3',    '3.84', '5',    '5.5',   ...
            '6',    '7',    '8.75', '10',    ...
            '12',   '14',   '20',   '28'     ...
        });
    end

    properties (Access = private)
        device = []
        samples
        overrun

        % Cache previously set values to avoid querying the device
        % for all properties when only one changes.
        curr_frequency
        curr_lna
        curr_vga1
        curr_vga2
    end

    methods (Static, Access = protected)

        function groups = getPropertyGroupsImpl
            deviceGroup = matlab.system.display.Section(...
                'Title', 'Device', ...
                'PropertyList', {'device_string'} ...
            );

            streamGroup = matlab.system.display.Section(...
                'Title', 'Stream', ...
                'PropertyList', {'num_buffers', 'num_transfers', 'samples_per_buffer', 'frame_size' } ...
            );

            xcvrGroup = matlab.system.display.Section(...
                'Title', 'RF', ...
                'PropertyList', {'frequency', 'lna', 'vga1', 'vga2'} ...
            );

            bbGroup = matlab.system.display.Section(...
                'Title', 'Baseband', ...
                'PropertyList', {'samplerate', 'bandwidth'} ...
            );
        groups = [ deviceGroup, streamGroup, xcvrGroup, bbGroup ];
        end
    end

    methods (Access = protected)

        function [samples, overrun] = getOutputDataTypeImpl(~)
           samples = 'double';
           overrun = 'logical';
        end

        function [samples, overrun] = getOutputSizeImpl(obj)
            samples = [obj.frame_size 1];
            overrun = [obj.frame_size 1];
        end

        function [samples, overrun] = isOutputComplexImpl(~)
            samples = true;
            overrun = false;
        end

        function [samples, overrun] = isOutputFixedSizeImpl(~)
            samples = true;
            overrun = true;
        end

        function setupImpl(obj)
            %disp('setupImpl() called.');

            obj.samples = zeros(obj.frame_size, 1);
            obj.overrun = false(obj.frame_size, 1);

            obj.device = bladeRF(obj.device_string);

            obj.device.rx.config.num_buffers = obj.num_buffers;
            obj.device.rx.config.num_transfers = obj.num_transfers;
            obj.device.rx.config.buffer_size = obj.samples_per_buffer;
            obj.device.rx.config.timeout_ms = 5000;

            obj.device.rx.frequency  = obj.frequency;
            obj.curr_frequency       = obj.device.rx.frequency;

            obj.device.rx.samplerate = obj.samplerate;
            obj.device.rx.bandwidth  = str2num(obj.bandwidth) * 1e6;

            obj.device.rx.lna        = obj.lna;
            obj.curr_lna             = bladeRF.str2lna(obj.device.rx.lna);

            obj.device.rx.vga1       = obj.vga1;
            obj.curr_vga1            = obj.device.rx.vga1;

            obj.device.rx.vga2       = obj.vga2;
            obj.curr_vga2            = obj.device.rx.vga2;
        end

        function releaseImpl(obj)
            %disp('releaseImpl() called.');
            obj.device.close();
        end

        function resetImpl(obj)
            %disp('resetImpl() called.');

            if obj.device.rx.running ~=0
                obj.device.rx.stop();
            end
        end

        % Perform a read of received samples and an 'overrun' array that denotes whether
        % the associated samples is invalid due to a detected overrun.
        function [samples, overrun] = stepImpl(obj)
            if obj.device.rx.running == 0
                obj.device.rx.start();
            end

            [obj.samples, num_returned, overrun_occurred] = ...
                obj.device.rx.receive(obj.frame_size, 5000, 0);

            if overrun_occurred ~=0
                obj.overrun(1:num_returned)     = false(num_returned, 1);
                obj.overrun(num_returned+1:end) = true(obj.frame_size - num_returned, 1);
                %fprintf('Overrun occurred @ t=%d\n', cputime);
            else
                obj.overrun = false(obj.frame_size, 1);
            end

            samples = obj.samples;
            overrun = obj.overrun;
        end

        function processTunedPropertiesImpl(obj)
            %disp('processTunedPropertiesImpl() called.');

            if isChangedProperty(obj, 'frequency') && obj.frequency ~= obj.curr_frequency
                obj.device.rx.frequency      = obj.frequency;
                obj.curr_frequency = obj.device.rx.frequency;
                %disp('Updated RX frequency');
            end

            if isChangedProperty(obj, 'lna') && obj.lna ~= obj.curr_lna
                obj.device.rx.lna = obj.lna;
                obj.curr_lna      = bladeRF.str2lna(obj.device.rx.lna);
                %disp('Updated RX LNA gain');
            end


            if isChangedProperty(obj, 'vga1') && obj.vga1 ~= obj.curr_vga1
                obj.device.rx.vga1 = obj.vga1;
                obj.curr_vga1      = obj.device.rx.vga1;
                %disp('Updated RX VGA1 gain');
            end

            if isChangedProperty(obj, 'vga2') && obj.vga2 ~= obj.curr_vga2
                obj.device.rx.vga1 = obj.vga2;
                obj.curr_vga2      = obj.device.rx.vga2;
                %disp('Updated RX VGA2 gain');
            end
        end

        function validatePropertiesImpl(obj)
            %disp('validatePropertiesImpl() called.');

            if obj.num_buffers < 1
                error('Number of buffers must be > 0.');
            end

            if obj.num_transfers >= obj.num_buffers
                error('Number of transfers must be < number of buffers.');
            end

            if obj.samples_per_buffer < 1024 || mod(obj.samples_per_buffer, 1024) ~= 0
                error('# Sample per buffer must be a multiple of 1024.');
            end

            if obj.timeout_ms < 0
                error('Stream timeout must be >= 0.');
            end

            if obj.frame_size <= 0
                error('The specified frame size must be > 0.');
            end

            if obj.samplerate < 160.0e3
                error('Sample rate must be >= 160 kHz.');
            elseif obj.samplerate > 40e6
                error('Sample rate must be <= 40 MHz.')
            end

            if obj.frequency < 230.0e6
                error('Frequency must be > 230 MHz.');
            elseif obj.frequency > 3.8e9
                error('Frequency must be <= 3.8 GHz.');
            end

            if obj.lna ~= 0 && obj.lna ~= 3 && obj.lna ~= 6
                error('RX LNA gain must be one of the following: 0, 3, 6');
            end

            if obj.vga1 < 5
                error('RX VGA1 gain must be >= 5.')
            elseif obj.vga1 > 30
                error('RX VGA1 gain must be <= 30.');
            end

            if obj.vga2 < 0
                error('RX VGA2 gain must be >= 0.');
            elseif obj.vga2 > 30
                error('RX VGA2 gain must be <= 30.');
            end
        end
    end
end
