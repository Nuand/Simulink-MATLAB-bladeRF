%%
% bladeRF_XCVR - Transceiver object used by the bladeRF MATLAB wrapper.
%
% Do not use this directly.
%

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

%% Control and configuration of transceiver properties
classdef bladeRF_XCVR < handle

    properties(SetAccess = immutable)
        bladerf
        module
        direction
    end

    properties(SetAccess = private)
        running         % Denotes whether or not the module is enabled to stream samples
        timestamp       % Provides a coarse readback of the timestamp counter
    end

    properties
        config          % Stream configuration
        corrections     % IQ corrections
    end

    properties(Dependent = true)
        samplerate      % Samplerate must be between 160kHz and 40MHz
        frequency       % Frequency must be between 240M and 3.8G
        bandwidth       % Bandwidth is discrete
        vga1            % VGA1
        vga2            % VGA2
        lna             % LNA
    end

    methods
        %% Property handling

        % Samplerate
        function set.samplerate(obj, val)
            % Create the holding structures
            rate = libstruct('bladerf_rational_rate');
            actual = libstruct('bladerf_rational_rate');

            % Requested rate
            rate.integer = floor(val);
            [rate.num, rate.den] = rat(mod(val,1));

            % Set the samplerate
            [rv, ~, ~, actual] = calllib('libbladeRF', 'bladerf_set_rational_sample_rate', obj.bladerf.device, obj.module, rate, rate);
            obj.bladerf.set_status(rv);
            obj.bladerf.check('bladerf_set_rational_sample_rate');

            retval = actual.integer + actual.num / actual.den;
            %fprintf('Set %s samplerate. Requested: %d + %d/%d, Actual: %d + %d/%d\n', ...
            %        obj.direction, ...
            %        rate.integer, rate.num, rate.den, ...
            %        actual.integer, actual.num, actual.den);
        end

        function samplerate_val = get.samplerate(obj)
            rate = libstruct('bladerf_rational_rate');
            rate.integer = 0;
            rate.num = 0;
            rate.den = 1;

            % Get the sample rate from the hardware
            [rv, ~, rate] = calllib('libbladeRF', 'bladerf_get_rational_sample_rate', obj.bladerf.device, obj.module, rate);
            obj.bladerf.set_status(rv);
            obj.bladerf.check('bladerf_get_rational_sample_rate');

            %fprintf('Read %s samplerate: %d + %d/%d\n', ...
            %        obj.direction, rate.integer, rate.num, rate.den);

            samplerate_val = rate.integer + rate.num / rate.den;
        end

        % Frequency
        function set.frequency(obj, val)
            [rv, ~] = calllib('libbladeRF', 'bladerf_set_frequency', obj.bladerf.device, obj.module, val);
            obj.bladerf.set_status(rv);
            obj.bladerf.check('bladerf_set_frequency');

            %fprintf('Set %s frequency: %f\n', obj.direction, val);
        end

        function freq_val = get.frequency(obj)
            freq_val = uint32(0);
            [rv, ~, freq_val] = calllib('libbladeRF', 'bladerf_get_frequency', obj.bladerf.device, obj.module, freq_val);
            obj.bladerf.set_status(rv);
            obj.bladerf.check('bladerf_get_frequency');

            %fprintf('Read %s frequency: %f\n', obj.direction, freq_val);
        end

        % Configures the LPF bandwidth on the associated module
        function set.bandwidth(obj, val)
            actual = uint32(0);
            [rv, ~, actual] = calllib('libbladeRF', 'bladerf_set_bandwidth', obj.bladerf.device, obj.module, val, actual);

            obj.bladerf.set_status(rv);
            obj.bladerf.check('bladerf_set_bandwidth');

            %fprintf('Set %s bandwidth. Requested: %f, Actual: %f\n', ...
            %        obj.direction, val, actual)
        end

        % Reads the LPF bandwidth configuration on the associated module
        function bw_val = get.bandwidth(obj)
            bw_val = uint32(0);
            [rv, ~, bw_val] = calllib('libbladeRF', 'bladerf_get_bandwidth', obj.bladerf.device, obj.module, bw_val);
            obj.bladerf.set_status(rv);
            obj.bladerf.check('bladerf_get_bandwidth');

            %fprintf('Read %s bandwidth: %f\n', obj.direction, bw_val);
        end

        % Configures the gain of VGA1
        function set.vga1(obj, val)
            if strcmpi(obj.direction,'RX') == true
                [rv, ~] = calllib('libbladeRF', 'bladerf_set_rxvga1', obj.bladerf.device, val);
            else
                [rv, ~] = calllib('libbladeRF', 'bladerf_set_txvga1', obj.bladerf.device, val);
            end

            obj.bladerf.set_status(rv);
            obj.bladerf.check('bladerf_set_vga1');

            %fprintf('Set %s VGA1: %d\n', obj.direction, val);
        end

        % Reads the current VGA1 gain configuration
        function val = get.vga1(obj)
            val = int32(0);
            if strcmpi(obj.direction,'RX') == true
                [rv, ~, val] = calllib('libbladeRF', 'bladerf_get_rxvga1', obj.bladerf.device, val);
            else
                [rv, ~, val] = calllib('libbladeRF', 'bladerf_get_txvga1', obj.bladerf.device, val);
            end

            obj.bladerf.set_status(rv);
            obj.bladerf.check('bladerf_get_vga1');

            %fprintf('Read %s VGA1: %d\n', obj.direction, val);
        end

        % Configures the gain of VGA2
        function set.vga2(obj, val)
            if strcmpi(obj.direction,'RX') == true
                [rv, ~] = calllib('libbladeRF', 'bladerf_set_rxvga2', obj.bladerf.device, val);
            else
                [rv, ~] = calllib('libbladeRF', 'bladerf_set_txvga2', obj.bladerf.device, val);
            end

            obj.bladerf.set_status(rv);
            obj.bladerf.check('bladerf_set_vga2');

            %fprintf('Set %s VGA2: %d\n', obj.direction, obj.vga2);
        end

        % Reads the current VGA2 configuration
        function val = get.vga2(obj)
            val = int32(0);
            if strcmpi(obj.direction,'RX') == true
                [rv, ~, val] = calllib('libbladeRF', 'bladerf_get_rxvga2', obj.bladerf.device, val);
            else
                [rv, ~, val] = calllib('libbladeRF', 'bladerf_get_txvga2', obj.bladerf.device, val);
            end

            obj.bladerf.set_status(rv);
            obj.bladerf.check('bladerf_get_vga2');

            %fprintf('Read %s VGA2: %d\n', obj.direction, val);
        end

        % Configure the RX LNA gain
        function obj = set.lna(obj, val)
            if strcmpi(obj.direction,'TX') == true
                error('LNA gain is not applicable to the TX path');
            end

            valid_value = true;

            if isnumeric(val)
                switch val
                    case 0
                        lna_val = 'BLADERF_LNA_GAIN_BYPASS';

                    case 3
                        lna_val = 'BLADERF_LNA_GAIN_MID';

                    case 6
                        lna_val = 'BLADERF_LNA_GAIN_MAX';

                    otherwise
                        valid_value = false;
                end
            else
                if strcmpi(val,'bypass')   == true
                    lna_val = 'BLADERF_LNA_GAIN_BYPASS';
                elseif strcmpi(val, 'mid') == true
                    lna_val = 'BLADERF_LNA_GAIN_MID';
                elseif strcmpi(val, 'max') == true
                    lna_val = 'BLADERF_LNA_GAIN_MAX';
                else
                    valid_value = false;
                end
            end

            if valid_value ~= true
                error('Valid LNA values are [''BYPASS'', ''MID'', ''MAX''] or [0, 3, 6], respectively.');
            else
                [rv, ~] = calllib('libbladeRF', 'bladerf_set_lna_gain', obj.bladerf.device, lna_val);
                obj.bladerf.set_status(rv);
                obj.bladerf.check('bladerf_set_lna_gain');

                %fprintf('Set RX LNA gain to: %s\n', lna_val);
            end
        end

        % Read current RX LNA gain setting
        function val = get.lna(obj)
            if strcmpi(obj.direction,'TX') == true
                error('LNA gain is not applicable to the TX path');
            end

            val = 0;
            [rv, ~, lna] = calllib('libbladeRF', 'bladerf_get_lna_gain', obj.bladerf.device, val);

            obj.bladerf.set_status(rv);
            obj.bladerf.check('bladerf_get_lna_gain');

            if strcmpi(val, 'BLADERF_LNA_GAIN_BYPASS') == true
                val = 'BYPASS';
            elseif strcmpi(lna, 'BLADERF_LNA_GAIN_MID') == true
                val = 'MID';
            elseif strcmpi(lna, 'BLADERF_LNA_GAIN_MAX') == true
                val = 'MAX';
            else
                val = 'UNKNOWN';
            end

            %fprintf('Got RX LNA gain: %s\n', val);
        end

        % Read the timestamp counter from the associated module
        function val = get.timestamp(obj)
            val = uint64(0);
            [rv, ~, val] = calllib('libbladeRF', 'bladerf_get_timestamp', obj.bladerf.device, obj.module, val);
            obj.bladerf.set_status(rv);
            obj.bladerf.check('bladerf_get_timestamp');
        end

        % Constructor
        function obj = bladeRF_XCVR(dev, dir)
            if strcmpi(dir,'RX') == false && strcmpi(dir,'TX') == false
                error('Invalid direction specified');
            end

            % Set the direction of the transceiver
            obj.direction = dir;
            obj.bladerf = dev;
            if strcmpi(dir,'RX') == true
                obj.module = 'BLADERF_MODULE_RX';
            else
                obj.module = 'BLADERF_MODULE_TX';
            end

            % Setup defaults
            obj.config = StreamConfig;
            obj.samplerate = 3e6;
            obj.frequency = 1.0e9;
            obj.bandwidth = 1.5e6;

            if strcmpi(dir, 'RX') == true
                obj.vga1 = 30;
                obj.vga2 = 0;
                obj.lna = 'MAX';
            else
                obj.vga1 = -8;
                obj.vga2 = 16;
            end

            obj.corrections = IQCorrections(dev, obj.module, 0, 0, 0, 0);
            obj.running = false;
        end

        % Configure stream and enable module
        function start(obj)
            %fprintf('Starting %s stream.\n', obj.direction);

            obj.running = true;
            obj.config.lock();

            % Configure the sync config
            [rv, ~] = calllib('libbladeRF', 'bladerf_sync_config', ...
                              obj.bladerf.device, ...
                              obj.module, ...
                              'BLADERF_FORMAT_SC16_Q11_META', ...
                              obj.config.num_buffers, ...
                              obj.config.buffer_size, ...
                              obj.config.num_transfers, ...
                              obj.config.timeout_ms);

            obj.bladerf.set_status(rv);
            obj.bladerf.check('bladerf_sync_config');

            % Enable the module
            [rv, ~] = calllib('libbladeRF', 'bladerf_enable_module', ...
                               obj.bladerf.device, ...
                               obj.module, ...
                               true);

            obj.bladerf.set_status(rv);
            obj.bladerf.check('bladerf_enable_module');
        end

        % Receive samples
        function [samples, actual_count, underrun] = receive(obj, num_samples, timeout_ms, time)
            if strcmpi( obj.direction, 'TX' ) == true
                error('receive() is invalid for TX module');
            end

            if nargin < 4
                timeout_ms = 5000;
            end

            if nargin < 5
                time = 0;
            end

            s16 = int16(zeros(2*num_samples, 1));

            metad = libstruct('bladerf_metadata');
            metad.actual_count = 0;
            metad.flags = bitshift(1,31);
            metad.reserved = 0;
            metad.status = 0;
            metad.timestamp = time;
            pmetad = libpointer('bladerf_metadata', metad);

            underrun = false;

            [rv, ~, s16, ~] = calllib('libbladeRF', 'bladerf_sync_rx', ...
                                      obj.bladerf.device, ...
                                      s16, ...
                                      num_samples, ...
                                      pmetad, ...
                                      timeout_ms);

            actual_count = pmetad.value.actual_count;
            if actual_count ~= num_samples
                underrun = true;
            end

            obj.bladerf.set_status(rv);
            obj.bladerf.check('bladerf_sync_rx');

            % Deinterleve and scale to [-1.0, 1.0).
            samples = (double(s16(1:2:end)) + double(s16(2:2:end))*1j) ./ 2048.0;
        end

        % Transmit the provided samples
        function transmit(obj, samples, timeout_ms)
            if strcmpi(obj.direction, 'RX') == true
                error('transmit() is invalid for RX module');
            end

            if nargin < 3
                timeout_ms = 5000;
            end

            metad = libstruct('bladerf_metadata');
            metad.actual_count = 0;
            metad.flags = bitshift(1,0) | bitshift(1,1) | bitshift(1,2);
            metad.reserved = 0;
            metad.status = 0;
            metad.timestamp = 0
            pmetad = libpointer('bladerf_metadata', metad);

            % Interleave and scale. We scale by 2047.0 rather than 2048.0
            % here because valid values are only [-2048, 2047]. However,
            % it's simpler to allow users to assume they can just input [-1.0, 1.0].
            s16 = zeros(1, 2*length(samples));
            s16(1:2:end) = samples(1:2:end) .* 2047.0;
            s16(2:2:end) = samples(2:2:end) .* 2047.0;

            rv = calllib('libbladeRF', 'bladerf_sync_tx', ...
                         obj.bladerf.device, ...
                         s16, ...
                         length(samples), ...
                         pmetad, ...
                         timeout_ms);

            obj.bladerf.set_status(rv);
            obj.bladerf.check('bladerf_sync_tx');
        end

        % Stop streaming and disable the module
        function stop(obj)
            %fprintf('Stopping %s module.\n', obj.direction);

            % Disable the module
            [rv, ~] = calllib('libbladeRF', 'bladerf_enable_module', ...
                              obj.bladerf.device, ...
                              obj.module, ...
                              false);

            obj.bladerf.set_status(rv);
            obj.bladerf.check('bladerf_enable_module');

            % Unlock the configuration for changing
            obj.config.unlock();
            obj.running = false;
        end
    end
end
