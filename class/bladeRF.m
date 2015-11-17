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
    properties(Access={?bladeRF_XCVR, ?bladeRF_IQCorr, ?bladeRF_VCTCXO})
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

    methods(Static, Hidden)
        function check_status(fn, status)
            if status ~= 0
                err_num = num2str(status);
                err_str = calllib('libbladeRF', 'bladerf_strerror', status);
                error([ 'libbladeRF error (' err_num ') in ' fn '(): ' err_str]);
            end
        end
    end

    methods(Static)
        % Convert RX LNA setting string to its associated numeric value
        function [val] = str2lna(str)
            if strcmpi(str, 'MAX') == 1
                val = 6;
            elseif strcmpi(str, 'MID') == 1
                val = 3;
            elseif strcmpi(str, 'BYPASS') == 1
                val = 0;
            else
                error('Invalid RX LNA string provided')
            end
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
            bladeRF.load_library();

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Open the device
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            % Use wildcard empty string if no device string was provided
            if nargin < 1
                devstring = '';
            end

            dptr = libpointer('bladerfPtr') ;
            status = calllib('libbladeRF', 'bladerf_open', dptr, devstring);

            % Check the return value
            bladeRF.check_status('bladeRF_open', status);

            % Save off the device pointer
            obj.device = dptr;

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
            status = calllib('libbladeRF', 'bladerf_fw_version', dptr, ver_ptr);
            bladeRF.check_status('bladerf_fw_version', status);
            obj.versions.firmware = ver_ptr.value;

            % FPGA version
            [ver, ver_ptr] = bladeRF.empty_version();
            status = calllib('libbladeRF', 'bladerf_fpga_version', dptr, ver_ptr);
            bladeRF.check_status('bladerf_fpga_version', status);
            obj.versions.fpga = ver_ptr.value;

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Populate information
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            % Serial number (Needs to be allocated >= 33 bytes)
            serial = repmat(' ', 1, 33);
            [status, ~, serial] = calllib('libbladeRF', 'bladerf_get_serial', dptr, serial);
            bladeRF.check_status('bladerf_get_serial', status);
            obj.info.serial = serial;

            % FPGA size
            fpga_size = 'BLADERF_FPGA_UNKNOWN';
            [status, ~, fpga_size] = calllib('libbladeRF', 'bladerf_get_fpga_size', dptr, fpga_size);
            bladeRF.check_status('bladerf_get_fpga_size', status);

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
            obj.vctcxo = bladeRF_VCTCXO(obj);

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Create transceiver chain
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            obj.rx = bladeRF_XCVR(obj, 'RX') ;
            obj.tx = bladeRF_XCVR(obj, 'TX') ;
        end


        % Destructor
        function delete(obj)
            %disp('Delete bladeRF called') ;
            calllib('libbladeRF', 'bladerf_close', obj.device) ;
        end

        % Just a convenience wrapper
        function close(obj)
            obj.delete;
        end

        % Low level peek function
        function val = peek(obj, dev, addr)
            switch dev
                case { 'lms', 'lms6', 'lms6002d' }
                    x = uint8(0);
                    [status, ~, x] = calllib('libbladeRF', 'bladerf_lms_read', obj.device, addr, x);
                    bladeRF.check_status('bladerf_lms_read', status);
                    val = x;

                case { 'si', 'si5338' }
                    x = uint8(0);
                    [status, ~, x] = calllib('libbladeRF', 'bladerf_si5338_read', obj.device, addr, x);
                    bladeRF.check_status('bladerf_si5338_read', status);
                    val = x;
            end
        end

        % Low level poke function
        function poke(obj, dev, addr, val)
            switch dev
                case { 'lms', 'lms6', 'lms6002d' }
                    status = calllib('libbladeRF', 'bladerf_lms_write', obj.device, addr, val);
                    bladeRF.check_status('bladerf_lms_write', status);

                case { 'si', 'si5338' }
                    status = calllib('libbladeRF', 'bladerf_si5338_write', obj.device, addr, val);
                    bladeRF.check_status('bladerf_si5338_write', status);
            end
        end

        % Load the FPGA from MATLAB
        function load_fpga(obj, filename)
            status = calllib('libbladeRF', 'bladerf_load_fpga', obj.device, filename);
            bladeRF.check_status('bladerf_load_fpga', status);
        end
    end
end
