classdef bladeRF_RX < matlab.System & matlab.system.mixin.Propagates
    % bladeRF RX Simulink block
    
    properties
        frequency           = 915e6;    % Frequency
        lnagain             = 'MAX';    % LNA Gain
        vga1                = 30;       % VGA1 Gain
        vga2                = 0;        % VGA2 Gain        
        bandwidth           = 1.5e6;    % Bandwidth
        samplerate          = 40e6;     % Sample rate
    end
    
    properties(Nontunable)
        device_string       = '';       % Device specification string
       
        num_buffers         = 64;       % Number of stream buffers to use
        num_transfers       = 16;       % Number of USB transfers to use
        samples_per_buffer  = 16384;    % Size of each stream buffer, in samples (must be multiple of 1024)
        frame_size          = 32758;    % Number of samples to receive during each simulation step
    end
    
    properties(Logical, Nontunable)
        xb200 = false % XB-200 Installed
    end

    properties(Hidden, Transient)
        lnagainSet = matlab.system.StringSet({'Max', 'Mid', 'Bypass'});
    end

    properties (Access = private)
        device
        samples
        overrun
    end

    methods (Static, Access = protected)
        
        function groups = getPropertyGroupsImpl
            deviceGroup = matlab.system.display.Section(...
                'Title', 'Device', ...
                'PropertyList', {'device_string', 'xb200'} ...
            );
        
            streamGroup = matlab.system.display.Section(...
                'Title', 'Stream', ...
                'PropertyList', {'num_buffers', 'num_transfers', 'samples_per_buffer', 'frame_size' } ...
            );
            
            xcvrGroup = matlab.system.display.Section(...
                'Title', 'RF', ...
                'PropertyList', {'frequency', 'lnagain', 'vga1', 'vga2'} ...
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
            obj.samples = zeros(obj.frame_size, 1);
            obj.overrun = false(obj.frame_size, 1);
            
            obj.device = bladeRF(obj.device_string);

            obj.device.rx.config.num_buffers = obj.num_buffers;
            obj.device.rx.config.num_transfers = obj.num_transfers;
            obj.device.rx.config.buffer_size = obj.samples_per_buffer;
            obj.device.rx.config.timeout_ms = 5000;
            
            obj.device.rx.samplerate = obj.samplerate;  
            
            obj.device.rx
            
            disp('setupImpl called');
        end

        function [samples, overrun] = stepImpl(obj)
            if obj.device.rx.running == 0
                obj.device.rx.start();
            end
            
            [obj.samples, num_returned, overrun_occurred] = ...
                obj.device.rx.receive(obj.frame_size, 5000, 0);
            
            if overrun_occurred ~=0
                obj.overrun(1:num_returned)     = false(num_returned, 1);
                obj.overrun(num_returned+1:end) = true(obj.frame_size - num_returned, 1);
            else
                obj.overrun = false(obj.frame_size, 1);
            end
            
            samples = obj.samples;
            overrun = obj.overrun;
        end
        
        function resetImpl(obj)
            if obj.device.rx.running ~=0
                obj.device.rx.stop();
            end
            
            disp('reset called');
        end
        
        function validatePropertiesImpl(obj)
            
            if obj.num_buffers < 1
                error( 'Number of buffers must be positive' );
            end
            
            if obj.num_transfers >= obj.num_buffers
                error( 'Number of transfers must be < number of buffers' );
            end
            
            if obj.frequency < 230.0e6
                error('Frequency must be > 230 MHz');
            elseif obj.frequency > 3.8e9
                error('Frequency must be <= 3.8 GHz');
            end
            
            if obj.samplerate < 160.0e3
                error('Sample rate must be >= 160 kHz');
            elseif obj.samplerate > 40e6
                error('Sample rate must be <= 40 MHz')
            end
        end
    end
    
    methods     
        function set.bandwidth(obj, value)
            obj.device.rx.bandwidth = value;
        end
        
        function set.samplerate(obj, value)
            obj.device.rx.samplerate = value;
        end
    end
end
