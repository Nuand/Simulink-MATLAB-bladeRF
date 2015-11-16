% bladeRF_DevMgr    bladeRF device manager. User by bladeRF MATLAB library. Do not use this directly.

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

classdef bladeRF_DevMgr

    methods(Static, Access = private)

        function [entry] = open_device(devices, device_str)
            entry = [];

            % Convert the device string into a device info structure that we use to compare two entries
            [status, ~, info] = calllib('libbladeRF', 'bladerf_get_devinfo_from_str', device_str, []);
            bladeRF.check_status('bladerf_get_devinfo_from_str', status);

            for n = 1:length(devices)
                other_info = devices{n}.devinfo;
            end

            % We did not find an existing handle in our devices cache. Try to open the device.
            if isempty(entry)
                fprintf('Did not find cached device handle. Attempting to open device...');

            end
        end
    end


    methods(Static)
        % Load libbladeRF, if it's not already loaded
        function load_libbladeRF
            if libisloaded('libbladeRF') == true
                disp('libbladeRF is already loaded. Not attempting to load it.');
                return
            end

            disp('Attempting to load libbladeRF...');

            arch = computer('arch');
            switch arch
                case 'glnxa64'
                    [notfound, warnings] = loadlibrary('libbladeRF', @libbladeRF_proto, 'notempdir') ;
                    %[notfound, warnings] = loadlibrary('libbladeRF', '/tmp/libbladeRF.h', 'notempdir') ;
                otherwise
                    error(['libbladeRF MATLAB bindings are not currently supported for: ' arch]);

            end

            if isempty(notfound) == false
                error('Failed to load library');
            end

            if isempty(warnings) == false
                warning('loadlibrary() returned warnings:\n%s\n', warnings);
            end
        end

        % Probe for devices
        function devs = probe
            bladeRF_DevMgr.load_libbladeRF();
            pdevlist = libpointer('bladerf_devinfoPtr') ;
            [status, ~] = calllib('libbladeRF', 'bladerf_get_device_list', pdevlist) ;

            if status < 0
                bladeRF.check_status('bladerf_get_device_list', status);
            elseif status > 0
                for x = 0:(status - 1)
                    ptr = pdevlist + x;
                    devs(x+1) = ptr.Value;
                    devs(x+1).serial = char(devs(x+1).serial(1:end-1));
                end
            else
                devs = [];
            end

            calllib('libbladeRF', 'bladerf_free_device_list', pdevlist);
        end

        % Update device manager state by opening or closing a device
        function update(op, device_str)
            % Manages all opened devices
            persistent devices;

            if isempty(devices)
                devices = [];
            end

            bladeRF_DevMgr.load_libbladeRF();

            if nargin < 2
                device_str = '';
            end

            switch op
                case 'open'
                    entry = bladeRF_DevMgr.open_device(devices, device_str);

                case 'close'
                    if length(devices) == 0
                        disp('Unloading libbladeRF...');
                        unloadlibrary('libbladeRF');
                    end

                otherwise
                    error('Invalid bladeRF_DeviceMgr operation: %s', op);
            end

        end
    end
end

