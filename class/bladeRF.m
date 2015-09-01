classdef bladeRF < handle
    % Read-only handle properties
    properties(Access={?XCVR, ?IQCorrections, ?StreamConfig})
        status  % Device status of last call
        device  % Device handle
    end
    
    properties
        rx      % Receive chain
        tx      % Transmit chain
    end
    
    properties(SetAccess=immutable)
        versions
    end
    
    methods(Hidden)
        function check(obj, name)
            if obj.status ~= 0
                msgID = strcat('bladeRF:',name) ;
                msg = calllib('libbladeRF', 'bladerf_strerror', obj.status) ;
                throw(MException(msgID, msg)) ;
            end
        end
        
        function set_status(obj, status)
            obj.status = status ;
        end
    end
    
    methods
        % Constructor
        function obj = bladeRF(devstring)
            % Load the library
            if libisloaded('/usr/local/lib/libbladeRF.so') == false
                [notfound, warnings] = loadlibrary('/usr/local/lib/libbladeRF.so', '/usr/local/include/libbladeRF.h') ;
                notfound
                warnings
            end
            % Populate version information
            % TODO: Not sure why MATLAB doesn't like getting version
            % information
            %ver = libstruct('bladerf_version') ;
            %ver = calllib('libbladeRF', 'bladerf_version', ver) ;
            obj.versions.lib.major = 0 ;
            obj.versions.lib.minor = 0 ;
            obj.versions.lib.patch = 0 ;

            obj.versions.matlab.major = 1 ;
            obj.versions.matlab.minor = 0 ;
            obj.versions.matlab.patch = 0 ;
            
            % Open the instance
            dptr = libpointer('bladerfPtr') ;
            obj.status = calllib('libbladeRF', 'bladerf_open',dptr, devstring) ;
            
            % Check the return value
            obj.check('bladeRF_open') ;
            
            % Save off the device pointer
            obj.device = dptr ;
            
            % Create the device transceiver chain
            obj.rx = XCVR(obj, 'RX') ;
            obj.tx = XCVR(obj, 'TX') ;
        end

        % Destructor
        function delete(obj)
            disp('Delete bladeRF called') ;
            calllib('libbladeRF', 'bladerf_close', obj.device) ;
        end
        
        % TX samples immediately
        function ret = send(obj, x)
            % Send something
            disp('Sending something') ;
            % device.send(x) ;
        end
        
        % TX samples at a specific time
        % TODO: Implement this
        
        % RX samples immediately
        function ret = receive(obj, n)
            % Receive something
            disp('Receiving something') ;
            % ret = device.receive(x) ;
        end
        
        % RX samples at a specific time
        % TODO: Implement this
        
        % Low level peek function
        function val = peek(obj, dev, addr)
            switch dev
                case 'dac'
                    x = uint16(0) ;
                    [obj.status,~,x]  = calllib('libbladeRF', 'bladerf_dac_read', obj.device, x) ;
                    obj.check('bladerf_dac_read') ;
                    val = x ;
                    
                case 'lms'
                    x = uint8(0) ;
                    [obj.status,~,x] = calllib('libbladeRF', 'bladerf_lms_read', obj.device, addr, x) ;
                    obj.check('bladerf_lms_read') ;
                    val = x ;
                    
                case 'si'
                    x = uint8(0) ;
                    [obj.status,~,x] = calllib('libbladeRF', 'bladerf_si5338_read', obj.device, addr, x) ;
                    obj.check('bladerf_si5338_read') ;
                    val = x ;

            end
        end
        
        % Low level poke function
        function poke(obj, dev, addr, val)
            switch dev
                case 'dac'
                    obj.status = calllib('libbladeRF', 'bladerf_dac_write', obj.device, val) ;
                    obj.check('bladerf_dac_write') ;
                    
                case 'lms'
                    obj.status = calllib('libbladeRF', 'bladerf_lms_write', obj.device, addr, val) ;
                    obj.check('bladerf_lms_write') ;
                    
                case 'si'
                    obj.status = calllib('libbladeRF', 'bladerf_si5338_write', obj.device, addr, val) ;
                    bladeRF.check('bladerf_si5338_write') ;
            end
        end
        
        % Load the FPGA from MATLAB
        function load_fpga(obj, filename)
            rv = calllib('libbladeRF', 'bladerf_load_fpga', obj.device, filename) ;
            bladeRF.check('bladerf_load_fpga', rv) ;
        end
        
    end
end
