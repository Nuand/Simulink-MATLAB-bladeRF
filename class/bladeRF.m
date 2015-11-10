%%
% bladeRF MATLAB interface
%
% This object is a MATLAB wrapper around libbladeRF.
%
% TODO: Summaryize API here

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

%% Top-level bladeRF object
classdef bladeRF < handle
    % Read-only handle properties
    properties(Access={?XCVR, ?IQCorrections, ?StreamConfig, ?VCTCXO})
        status  % Device status of last call
        device  % Device handle
    end

    properties
        rx      % Receive chain
        tx      % Transmit chain
        vctcxo  % VCTCXO control
    end

    properties(SetAccess=immutable)
        info
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

    methods(Static, Access = private)
        function load_library
            % Load the library
            if libisloaded('libbladeRF') == false
                arch = computer('arch') ;
                switch arch
                    case 'win32'
                        error( 'bladeRF:constructor', 'win32 not supported' ) ;
                    case 'win64'
                        error ('bladeRF:constructor', 'win64 not supported' ) ;
                    case 'glnxa64'
                        [notfound, warnings] = loadlibrary('libbladeRF', @libbladeRF_proto, 'notempdir') ;
                        %[notfound, warnings] = loadlibrary('libbladeRF', '/tmp/libbladeRF.h', 'notempdir') ;
                    case 'maci64'
                        [notfound, warnings] = loadlibrary('libbladeRF.dylib', @libbladeRF_proto, 'notempdir') ;
                    otherwise
                        error(strcat('Unexpected architecture: ', arch))
                end
                if isempty(notfound) == false
                    error('bladeRF:loadlibrary', 'functions missing from library' ) ;
                end

                if isempty(warnings) == false
                    warning('bladeRF:loadlibrary', 'loadlibrary returned warning messages \n%s\n', warnings) ;
                end
            end
        end

        % Get an empty version structure initialized to known values
        function [ver, ver_ptr] = empty_version
            ver = libstruct('bladerf_version');
            ver.major = 0;
            ver.minor = 0;
            ver.patch = 0;
            ver.describe = 'Unknown';

            ver_ptr = libpointer('bladerf_version', ver);
        end
    end

    methods(Static)
        function devs = devices
            bladeRF.load_library() ;
            pdevlist = libpointer('bladerf_devinfoPtr') ;
            [rv, ~] = calllib('libbladeRF', 'bladerf_get_device_list', pdevlist) ;
            if rv < 0
                error('bladeRF:devices', strcat('Error retrieving devices: ', calllib('libbladeRF', 'bladerf_strerror', rv))) ;
            end

            if rv > 0
                for x=0:rv-1
                    ptr = pdevlist+x ;
                    devs(x+1) = ptr.Value ;
                    devs(x+1).serial = char(devs(x+1).serial(1:end-1)) ;
                end
            else
                devs = [] ;
            end
            calllib('libbladeRF', 'bladerf_free_device_list', pdevlist) ;
        end

        %% Set libbladeRF's log level. Options are: verbose, debug, info, error, warning, critical, silent
        function log_level(level)
            level = lower(level);

            switch level
                case 'verbose'
                    enum_val = 'BLADERF_LOG_LEVEL_VERBOSE';
                case 'debug'
                    enum_val = 'BLADERF_LOG_LEVEL_DEBUG';
                case 'info'
                    enum_val = 'BLADERF_LOG_LEVEL_INFO';
                case 'warning'
                    enum_val = 'BLADERF_LOG_LEVEL_WARNING';
                case 'error'
                    enum_val = 'BLADERF_LOG_LEVEL_ERROR';
                case 'critical'
                    enum_val = 'BLADERF_LOG_LEVEL_CRITICAL';
                case 'silent'
                    enum_val = 'BLADERF_LOG_LEVEL_SILENT';
                otherwise
                    error(strcat('Invalid log level: ', level));
            end

            bladeRF.load_library();
            calllib('libbladeRF', 'bladerf_log_set_verbosity', enum_val);
        end
    end

    methods
        % Constructor
        function obj = bladeRF(devstring)
            bladeRF.load_library() ;

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Open the device
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            if nargin < 1
                devstring = '';
            end

            dptr = libpointer('bladerfPtr') ;
            obj.status = calllib('libbladeRF', 'bladerf_open',dptr, devstring) ;

            % Check the return value
            obj.check('bladeRF_open') ;

            % Save off the device pointer
            obj.device = dptr ;

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % TODO: Load/Check FPGA
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Populate version information
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            % Version of this MATLAB code
            obj.versions.matlab.major = 1 ;
            obj.versions.matlab.minor = 0 ;
            obj.versions.matlab.patch = 0 ;

            % libbladeRF version
            [ver, ver_ptr] = bladeRF.empty_version();
            calllib('libbladeRF', 'bladerf_version', ver_ptr) ;
            obj.versions.lib = ver_ptr.value;

            % FX3 firmware version
            [ver, ver_ptr] = bladeRF.empty_version();
            obj.status = calllib('libbladeRF', 'bladerf_fw_version', dptr, ver_ptr);
            obj.check('bladerf_fw_version');
            obj.versions.firmware = ver_ptr.value;

            % FPGA version
            [ver, ver_ptr] = bladeRF.empty_version();
            obj.status = calllib('libbladeRF', 'bladerf_fpga_version', dptr, ver_ptr);
            obj.check('bladerf_fpga_version');
            obj.versions.fpga = ver_ptr.value;

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Populate information
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            % Serial number (Needs to be allocated >= 33 bytes)
            serial = repmat(' ', 1, 33);
            [obj.status, ~, serial] = calllib('libbladeRF', 'bladerf_get_serial', dptr, serial);
            obj.check('bladerf_get_serial');
            obj.info.serial = serial;

            % FPGA size
            fpga_size = 'BLADERF_FPGA_UNKNOWN';
            [obj.status, ~, fpga_size] = calllib('libbladeRF', 'bladerf_get_fpga_size', dptr, fpga_size);
            obj.check('bladerf_get_fpga_size');

            switch fpga_size
                case 'BLADERF_FPGA_40KLE'
                    obj.info.fpga_size = '40 kLE';
                case 'BLADERF_FPGA_115KLE'
                    obj.info.fpga_size = '115 kLE';
                otherwise
                    error(strcat('Unexpected FPGA size: ', fpga_size))
            end

            % USB Speed
            usb_speed = calllib('libbladeRF', 'bladerf_device_speed', dptr);
            switch usb_speed
                case 'BLADERF_DEVICE_SPEED_HIGH'
                    obj.info.usb_speed = 'Hi-Speed (2.0)';
                case 'BLADERF_DEVICE_SPEED_SUPER'
                    obj.info.usb_speed = 'SuperSpeed (3.0)';
                otherwise
                    error(strcat('Unexpected device speed: ', usb_speed))
            end

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % VCTCXO control
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            obj.vctcxo = VCTCXO(obj);

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Create transceiver chain
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            obj.rx = XCVR(obj, 'RX') ;
            obj.tx = XCVR(obj, 'TX') ;
        end


        % Destructor
        function delete(obj)
            disp('Delete bladeRF called') ;
            calllib('libbladeRF', 'bladerf_close', obj.device) ;
        end

        % Just a convenience wrapper
        function close(obj)
            obj.delete;
        end

        % TX samples immediately
        function ret = send(obj, x)
            % Send something
            disp('Sending something') ;
            % device.send(x) ;
        end

        % RX samples immediately
        function ret = receive(obj, n)
            % Receive something
            disp('Receiving something') ;
            % ret = device.receive(x) ;
        end

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
