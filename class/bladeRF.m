% bladeRF MATLAB interface
%
% This object is a MATLAB wrapper around libbladeRF. As such, much
% of the documentation for the libbladeRF API is applicable. It may be
% found here:
%                   http://www.nuand.com/libbladeRF-doc
%
% The below series of steps illustrates how to perform a simple reception.
% However, the process for configuring the device for transmission is
% largely the same. Note the same device handle may be used to transmit and
% receive.
%
% (1) Open a device handle:
%
%   b = bladeRF('*:serial=43b'); % Open device via first 3 serial # digits
%
% (2) Setup device parameters. These may be changed while the device
%     is actively streaming.
%
%   b.rx.frequency  = 917.45e6;
%   b.rx.samplerate = 5e6;
%   b.rx.bandwidth  = 2.5e6;
%   b.rx.lna        = 'MAX';
%   b.rx.vga1       = 30;
%   b.rx.vga2       = 5;
%
% (3) Setup stream parameters. These may NOT be changed while the device
%     is streaming.
%
%   b.rx.config.num_buffers   = 64;
%   b.rx.config.buffer_size   = 16384;
%   b.rx.config.num_transfers = 16;
%   b.rx.timeout_ms           = 5000;
%
%
% (4) Start the module
%
%   b.rx.start();
%
% (5) Receive 0.250 seconds of samples
%
%  samples = b.receive(0.250 * b.rx.samplerate);
%
% (6) Cleanup and shutdown by stopping the RX stream and having MATLAB
%     delete the handle object.
%
%  b.rx.stop();
%  clear b;
%
%
% Below is a list of submodules within the bladeRF handle. See the help
% text of each of these for the properties and methods exposed by modules.
%
% See also: bladeRF_XCVR, bladeRF_VCTCXO, bladeRF_StreamConfig, bladeRF_IQCorr

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
        info        % Information about device properties and state
        versions    % Device and library version information
    end

    methods(Static, Hidden)
        % Test the libbladeRF status code and error out if it is != 0
        function check_status(fn, status)
            if status ~= 0
                err_num = num2str(status);
                err_str = calllib('libbladeRF', 'bladerf_strerror', status);
                error([ 'libbladeRF error (' err_num ') in ' fn '(): ' err_str]);
            end
        end
    end

    methods(Static)

        function [val] = str2lna(str)
        % Convert RX LNA setting string to its associated numeric value.
        %
        %  val = bladeRF.str2lna('MAX');
        %
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

        function [major, minor, patch] = version()
        % Get the version of this MATLAB libbladeRF wrapper.
        %
        % [major, minor, patch] = bladeRF.version()
        %
            major = 0;
            minor = 1;
            patch = 0;
        end

        function [major, minor, patch, version_string] = library_version()
        % Get the libbladeRF version being used.
        %
        % [major, minor, patch, version_string] = bladeRF.library_version()
        %
            bladeRF.load_library();

            [~, ver_ptr] = bladeRF.empty_version();
            calllib('libbladeRF', 'bladerf_version', ver_ptr);
            major = ver_ptr.Value.major;
            minor = ver_ptr.Value.minor;
            patch = ver_ptr.Value.patch;
            version_string = ver_ptr.Value.describe;
        end

        function devs = devices
        % Probe the system for attached bladeRF devices.
        %
        % [device_list] = bladeRF.devices();
        %
            bladeRF.load_library();
            pdevlist = libpointer('bladerf_devinfoPtr');
            [count, ~] = calllib('libbladeRF', 'bladerf_get_device_list', pdevlist);
            if count < 0
                error('bladeRF:devices', strcat('Error retrieving devices: ', calllib('libbladeRF', 'bladerf_strerror', rv)));
            end

            if count > 0
                devs = repmat(struct('backend', [], 'serial', [], 'usb_bus', [], 'usb_addr', [], 'instance', []), 1, count);
                for x = 0:(count-1)
                    ptr = pdevlist+x;
                    devs(x+1) = ptr.Value;
                    devs(x+1).serial = char(devs(x+1).serial(1:end-1));
                end
            else
                devs = [];
            end

            calllib('libbladeRF', 'bladerf_free_device_list', pdevlist);
        end

        function log_level(level)
        % Set libbladeRF's log level.
        %
        % bladeRF.log_level(level_string)
        %
        % Options for level_string are:
        %   'verbose'
        %   'debug'
        %   'info'
        %   'error'
        %   'warning'
        %   'critical'
        %   'silent'
        %
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

    methods(Static, Access = private)
        function load_library
            % Load the library
            if libisloaded('libbladeRF') == false
                arch = computer('arch');
                switch arch
                    case 'win32'
                        error( 'bladeRF:constructor', 'win32 not supported' );
                    case 'win64'
                        error ('bladeRF:constructor', 'win64 not supported' );
                    case 'glnxa64'
                        [notfound, warnings] = loadlibrary('libbladeRF', @libbladeRF_proto, 'notempdir');
                        %[notfound, warnings] = loadlibrary('libbladeRF', '/tmp/libbladeRF.h', 'notempdir');
                    case 'maci64'
                        [notfound, warnings] = loadlibrary('libbladeRF.dylib', @libbladeRF_proto, 'notempdir');
                    otherwise
                        error(strcat('Unexpected architecture: ', arch))
                end
                if isempty(notfound) == false
                    error('bladeRF:loadlibrary', 'functions missing from library' );
                end

                if isempty(warnings) == false
                    warning('bladeRF:loadlibrary', 'loadlibrary returned warning messages \n%s\n', warnings);
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

    methods
        function obj = bladeRF(devstring, fpga_bitstream)
        % Create a device handle to the bladeRF specified by devstring.
        %
        % device = bladeRF(devstring)
        %
        % The syntax for devstring may be found in the libbladeRF
        % documentation for the bladerf_open() function. If devstring
        % is not provided or is empty, the first available device will be
        % used.
        %
        % If multiple devices are present, it is helpful to open then via
        % their serial numbers. This can be done by specifying at least
        % 3 characters from their serial number:
        %
        % device = bladeRF('*:serial=f39')
        %
        % Note that there can only be one active handle to a device at any
        % given time. The device will be closed when all references to the
        % device handle are cleared from the workspace.
        %
        % If FPGA autoloading [1] is not being used to have libbladeRF
        % automatically load FPGA images, an FPGA bitstream filename must
        % be provided to the constructor. For example, with a bladeRF x115:
        %
        % device = bladeRF(devstring, 'path/to/hostedx115.rbf');
        %
        % [1] https://github.com/Nuand/bladeRF/wiki/FPGA-Autoloading#Host_softwarebased
        %
            bladeRF.load_library();

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Open the device
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            % Use wildcard empty string if no device string was provided
            if nargin < 1
                devstring = '';
            end

            % Don't attempt to load an FPGA unless specified
            if nargin < 2
                fpga_bitstream = '';
            end

            dptr = libpointer('bladerfPtr');
            status = calllib('libbladeRF', 'bladerf_open', dptr, devstring);

            % Check the return value
            bladeRF.check_status('bladeRF_open', status);

            % Save off the device pointer
            obj.device = dptr;

            if ~isempty(fpga_bitstream)
                obj.load_fpga(fpga_bitstream);
            end

            % Verify we have an FPGA loaded before continuing.
            status = calllib('libbladeRF', ...
                             'bladerf_is_fpga_configured', obj.device);

            if status < 0
                bladeRF.check_status('bladerf_is_fpga_configured', status);
            elseif status == 0
                calllib('libbladeRF', 'bladerf_close', obj.device);
                error(['No bladeRF FPGA bitstream is loaded. Place one' ...
                       ' in an autoload location, or pass the filename' ...
                       ' to the bladeRF constructor']);
            end

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Populate version information
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            [obj.versions.matlab.major, ...
             obj.versions.matlab.minor, ...
             obj.versions.matlab.patch] = bladeRF.version();

            [obj.versions.libbladeRF.major, ...
             obj.versions.libbladeRF.minor, ...
             obj.versions.libbladeRF.patch, ...
             obj.versions.libbladeRF.string] = bladeRF.library_version();

            % FX3 firmware version
            [~, ver_ptr] = bladeRF.empty_version();
            status = calllib('libbladeRF', 'bladerf_fw_version', dptr, ver_ptr);
            bladeRF.check_status('bladerf_fw_version', status);
            obj.versions.firmware = ver_ptr.value;

            % FPGA version
            [~, ver_ptr] = bladeRF.empty_version();
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

            obj.rx = bladeRF_XCVR(obj, 'RX');
            obj.tx = bladeRF_XCVR(obj, 'TX');
        end


        function [samples, timestamp_out, actual_count, overrun] = receive(obj, num_samples, timeout_ms, timestamp_in)
        % RX samples immediately or at a future timestamp.
        %
        %  [samples, timestamp_out, actual_count, overrun] = ...
        %       bladeRF.receive(num_samples, timeout_ms, timestamp_in)
        %
        %   samples = bladeRF.receive(4096) immediately receives 4096 samples.
        %
        %   [samples, ~, ~, overrun] = bladeRF.receive(1e6, 3000, 12345678) receives
        %   1 million samples at RX timestamp 12345678, with a 3 second timeout,
        %   and fetches the overrun flag.
        %
        % Preconditions:
        %   The bladeRF receiver has been previously configured via the
        %   parameters in bladeRF.rx.config (the defaults may suffice),
        %   and bladeRF.rx.start() has been called.
        %
        % Inputs:
        %   num_samples     Number of samples to receive
        %
        %   timeout_ms      Reception operation timeout, in ms. 0 implies no timeout.
        %                   Default = 2 * bladeRF.rx.config.timeout_ms
        %
        %   timestamp_in    Timestamp to receive sample at. 0 implies "now." Default=0.
        %
        % Outputs:
        %
        %   samples         Received complex samples with real and imaginary component
        %                   amplitudes within [-1.0, 1.0]. These samples should be
        %                   contiguous if `overrun` is false. If `overrun`
        %                   is true, a discontinuity may have occurred and
        %                   only the first `actual_count` samples are
        %                   contiguous and valid.
        %
        %   timestamp_out   Timestamp of first sample in `samples`.
        %
        %   actual_count    Set to `num_samples` if no overrun occurred,
        %                   or the number of valid samples if an overrun
        %                   was detected.
        %
        %   overrun         Set to `true` if an overrun was detected
        %                   in this group of samples, and `false` otherwise.
        %
        % See also: bladeRF_XCVR/start, bladeRF_StreamConfig

            if nargin < 3
                timeout_ms = 2 * obj.rx.config.timeout_ms;
            end

            if nargin < 4
                timestamp_in = 0;
            end

            s16 = int16(zeros(2*num_samples, 1));

            metad = libstruct('bladerf_metadata');
            metad.actual_count = 0;
            metad.reserved     = 0;
            metad.status       = 0;

            if timestamp_in == 0
                % BLADERF_META_FLAG_RX_NOW
                metad.flags = bitshift(1,31);
            else
                metad.flags = 0;
            end

            metad.timestamp = timestamp_in;

            pmetad = libpointer('bladerf_metadata', metad);

            overrun = false;

            [status, ~, s16, ~] = calllib('libbladeRF', 'bladerf_sync_rx', ...
                                          obj.device, ...
                                          s16, ...
                                          num_samples, ...
                                          pmetad, ...
                                          timeout_ms);

            bladeRF.check_status('bladerf_sync_rx', status);

            actual_count = pmetad.value.actual_count;
            if actual_count ~= num_samples
                overrun = true;
            end

            % Deinterleve and scale to [-1.0, 1.0).
            samples = (double(s16(1:2:end)) + double(s16(2:2:end))*1j) ./ 2048.0;
            timestamp_out = metad.timestamp;
        end

        function transmit(obj, samples, timeout_ms, timestamp, sob, eob)
        % TX samples as part of a stream or as a burst immediately or at a specified timestamp.
        %
        % bladeRF.transmit(samples, timeout_ms, timestamp, sob, eob)
        %
        % bladeRF.transmit(samples) transmits samples as part of a larger
        % stream. Under the hood, this is implemented as a single
        % long-running burst. If successive calls are provided with a
        % timestamp, the stream will be "padded" with 0+0j up to that
        % timestamp.
        %
        % bladeRF.transmit(samples, 3000, 0, 1, 1) immediately transmits
        % a single burst of samples with a 3s timeout. The use of the
        % sob and eob flags ensures the end of the burst will be
        % zero padded by libbladeRF in order to hold the TX DAC at
        % 0+0j after the burst completes.
        %
        % Preconditions:
        %   The bladeRF transmitter has been previously configured via
        %   parameters in bladeRF.tx.config (the defaults may suffice),
        %   and bladeRF.tx.start() has been called.
        %
        % Inputs:
        %   samples     Complex samples to transmit. The amplitude of the real and
        %               imaginary components are expected to be within [-1.0, 1.0].
        %
        %   timeout_ms  Timeout for transmission function call. 0 implies no timeout.
        %               Default = 2 * bladeRF.tx.config.timeout_ms
        %
        %   timestamp   Timestamp counter value at which to transmit samples.
        %               0 implies "now."
        %
        %   sob         "Start of burst" flag. Should be `true` or `false`.
        %               This informs libbladeRF to consider all provided
        %               samples to be within a burst until an eob flags
        %               is provided. This value should be `true` or `false`.
        %
        %   eob         "End of burst" flag. This informs libbladeRF
        %               that after the provided samples, the burst
        %               should be ended. libbladeRF will zero-pad
        %               the remainder of a buffer to ensure that
        %               TX DAC is held at 0+0j after a burst. This
        %
        % For more information about utilizing timestamps and bursts, see the
        % "TX with metadata" topic in the libbladeRF API documentation:
        %
        %               http://www.nuand.com/libbladeRF-doc
        %
        % See also: bladeRF_XCVR/start, bladeRF_StreamConfig
        %
            if nargin < 3
                timeout_ms = 2 * obj.tx.config.timeout_ms;
            end

            if nargin < 4
                timestamp = 0;
            end

            if nargin < 6
                % If the user has not specified SOB/EOB flags, we'll assume
                % they just want to stream samples and not worry about
                % these flags. We can support this by just starting a burst
                % that is as long as the transmission is active.
                sob = obj.tx.sob;
                eob = obj.tx.eob;

                % Ensure the next calls are "mid-burst"
                if obj.tx.sob == true
                    obj.tx.sob = false;
                end
            else
                % The caller has specified the end of the burst.
                % Reset cached values to be ready to start a burst if
                % they call transmit() later with no flags.
                if eob == true
                    obj.tx.sob = true;
                    obj.tx.eob = false;
                end
            end

            assert(islogical(sob), 'Error: sob flag must be a `true` or `false` (logical type)');
            assert(islogical(eob), 'Error: eob flag must be a `true` or `false` (logical type)');

            metad = libstruct('bladerf_metadata');
            metad.actual_count = 0;
            metad.reserved     = 0;
            metad.status       = 0;
            metad.flag         = 0;

            if timestamp == 0
                % Start the burst "Now"
                if sob == true
                    % BLADERF_META_FLAG_TX_NOW
                    metad.flags = bitor(metad.flags, bitshift(1, 2));
                end
            else
                % If we're mid-burst, we need to use this flag to tell
                % libbladeRF that we want it to zero-pad up to the
                % specified timestamp (or at least until the end of the
                % current internal buffer).
                if sob == false
                    % BLADERF_META_FLAG_TX_UPDATE_TIMESTAMP
                    metad.flags = bitor(metad.flags, bitshift(1, 3));
                end
            end

            metad.timestamp = timestamp;


            if sob == true
                % BLADERF_META_FLAG_TX_BURST_START
                metad.flags = bitor(metad.flags, bitshift(1, 0));
            end

            if eob == true
                % BLADERF_META_FLAG_TX_BURST_END
                metad.flags = bitor(metad.flags, bitshift(1, 1));
            end

            pmetad = libpointer('bladerf_metadata', metad);

            % Interleave and scale. We scale by 2047.0 rather than 2048.0
            % here because valid values are only [-2048, 2047]. However,
            % it's simpler to allow users to assume they can just input
            % samples within [-1.0, 1.0].
            samples = samples .* 2047;

            s16 = zeros(2 * length(samples), 1, 'int16');
            s16(1:2:end) = real(samples);
            s16(2:2:end) = imag(samples);


            %fprintf('SOB=%d, EOB=%d, TS=0x%s, flags=0x%s\n', ...
            %        sob, eob, dec2hex(metad.timestamp), dec2hex(metad.flags));

            status = calllib('libbladeRF', 'bladerf_sync_tx', ...
                             obj.device, ...
                             s16, ...
                             length(samples), ...
                             pmetad, ...
                             timeout_ms);

            bladeRF.check_status('bladerf_sync_tx', status);
        end

        function delete(obj)
        % Destructor. Stops all running stream and close the device handle.
        %
        % Do not call directly. Clear references to the handle from your
        % workspace and MATLAB will call this once the last reference is
        % cleared.

            %disp('Delete bladeRF called');
            obj.rx.stop;
            obj.tx.stop;
            calllib('libbladeRF', 'bladerf_close', obj.device);
        end

        function val = peek(obj, dev, addr)
        % Read from a device register.
        %
        % [value] = bladeRF.peek(device, address)
        %
        % Device may be one of the following:
        %   'lms6002d', 'lms6', 'lms'   - LMS6002D Transceiver registers
        %   'si5338', 'si'              - Si5338 Clock Generator
        %
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

        function poke(obj, dev, addr, val)
        % Write to a device register.
        %
        % bladeRF/poke(device, address, value)
        %
        % Device may be one of the following:
        %   'lms6002d', 'lms6', 'lms'   - LMS6002D Transceiver registers
        %   'si5338', 'si'              - Si5338 Clock Generator
        %
            switch dev
                case { 'lms', 'lms6', 'lms6002d' }
                    status = calllib('libbladeRF', 'bladerf_lms_write', obj.device, addr, val);
                    bladeRF.check_status('bladerf_lms_write', status);

                case { 'si', 'si5338' }
                    status = calllib('libbladeRF', 'bladerf_si5338_write', obj.device, addr, val);
                    bladeRF.check_status('bladerf_si5338_write', status);
            end
        end

        function load_fpga(obj, filename)
        % Load the FPGA using the provided bitstream filename.
        %
        % load_fpga('./path/to/hostedx40.rbf')
        %
            status = calllib('libbladeRF', 'bladerf_load_fpga', obj.device, filename);
            bladeRF.check_status('bladerf_load_fpga', status);
        end
    end
end
