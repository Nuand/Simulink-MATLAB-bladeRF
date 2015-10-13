classdef XCVR

    properties(SetAccess = immutable)
        bladerf
        module
        direction
    end

    properties
        config          % Stream configuration
        samplerate      % Samplerate must be between 160kHz and 40MHz
        frequency       % Frequency must be between 240M and 3.8G
        bandwidth       % Bandwidth is discrete
        vga1            % VGA1
        vga2            % VGA2
        lna             % LNA
        timestamp       % Placeholder
        corrections     % IQ corrections
    end

    methods
        %% Property handling

        % Samplerate
        function obj = set.samplerate(obj, val)
            % Create the holding structures
            rate = libstruct('bladerf_rational_rate') ;
            actual = libstruct('bladerf_rational_rate') ;

            % Requested rate
            rate.integer = floor(val) ;
            [rate.num, rate.den] = rat(mod(val,1)) ;

            % Set the samplerate
            [rv, ~, ~, actual] = calllib('libbladeRF', 'bladerf_set_rational_sample_rate', obj.bladerf.device, obj.module, rate, rate) ;
            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_set_rational_sample_rate') ;
            % x = sprintf( 'Requested: %d + %d/%d    Actual: %d + %d/%d\n', rate.integer, rate.num, rate.den, actual.integer, actual.num, actual.den ) ;
            % %disp( x ) ;
            obj.samplerate = actual.integer + actual.num / actual.den ;
            %disp('Changed samplerate')
        end

        function val = get.samplerate(obj)
            rate = libstruct('bladerf_rational_rate') ;
            rate.integer = 0 ;
            rate.num = 0 ;
            rate.den = 1 ;

            % Get the sample rate from the hardware
            [rv, ~, rate] = calllib('libbladeRF', 'bladerf_get_rational_sample_rate', obj.bladerf.device, obj.module, rate) ;
            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_get_rational_sample_rate') ;

            % Set it locally
            obj.samplerate = rate.integer + rate.num / rate.den ;
            val = obj.samplerate ;
            %disp('Got samplerate') ;
        end

        % Frequency
        function obj = set.frequency(obj, val)
            [rv, ~] = calllib('libbladeRF', 'bladerf_set_frequency', obj.bladerf.device, obj.module, val) ;
            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_set_frequency') ;
            obj.frequency = val ;
            %disp('Changed frequency') ;
        end

        function val = get.frequency(obj)
            freq = uint32(0) ;
            [rv, ~, freq] = calllib('libbladeRF', 'bladerf_get_frequency', obj.bladerf.device, obj.module, freq) ;
            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_get_frequency') ;
            obj.frequency = freq ;
            val = obj.frequency ;
            %disp('Got frequency') ;
        end

        % Bandwidth
        function obj = set.bandwidth(obj, val)
            actual = uint32(0) ;
            [rv, ~, actual] = calllib('libbladeRF', 'bladerf_set_bandwidth', obj.bladerf.device, obj.module, val, actual) ;
            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_set_bandwidth') ;
            obj.bandwidth = actual ;
            %disp('Changed bandwidth') ;
        end

        function val = get.bandwidth(obj)
            bw = uint32(0) ;
            [rv, ~, bw] = calllib('libbladeRF', 'bladerf_get_bandwidth', obj.bladerf.device, obj.module, bw) ;
            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_get_bandwidth') ;
            obj.bandwidth = bw ;
            val = obj.bandwidth ;
            %disp('Got bandwidth') ;
        end

        % VGA1
        function obj = set.vga1(obj, val)
            if strcmp(obj.direction,'RX') == true
                [rv, ~] = calllib('libbladeRF', 'bladerf_set_rxvga1', obj.bladerf.device, val) ;
            else
                [rv, ~] = calllib('libbladeRF', 'bladerf_set_txvga1', obj.bladerf.device, val) ;
            end
            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_set_vga1') ;
            obj.vga1 = val ;
            %disp('Changed VGA1') ;
        end

        function val = get.vga1(obj)
            gain = int32(0) ;
            if strcmp(obj.direction,'RX') == true
                [rv, ~, gain] = calllib('libbladeRF', 'bladerf_get_rxvga1', obj.bladerf.device, gain) ;
            else
                [rv, ~, gain] = calllib('libbladeRF', 'bladerf_get_txvga1', obj.bladerf.device, gain) ;
            end
            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_get_vga1') ;
            obj.vga1 = gain ;
            val = obj.vga1 ;
            %disp('Got VGA1') ;
        end

        % VGA2
        function obj = set.vga2(obj, val)
            if strcmp(obj.direction,'RX') == true
                [rv, ~] = calllib('libbladeRF', 'bladerf_set_rxvga2', obj.bladerf.device, val) ;
            else
                [rv, ~] = calllib('libbladeRF', 'bladerf_set_txvga2', obj.bladerf.device, val) ;
            end
            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_set_vga2') ;
            obj.vga2 = val ;
            %disp('Changed VGA2') ;
        end

        function val = get.vga2(obj)
            gain = int32(0) ;
            if strcmp(obj.direction,'RX') == true
                [rv, ~, gain] = calllib('libbladeRF', 'bladerf_get_rxvga2', obj.bladerf.device, gain) ;
            else
                [rv, ~, gain] = calllib('libbladeRF', 'bladerf_get_txvga2', obj.bladerf.device, gain) ;
            end
            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_get_vga2') ;
            obj.vga2 = gain ;
            val = obj.vga2 ;
            %disp('Got VGA2') ;
        end

        % LNA
        function obj = set.lna(obj, val)
            if strcmp(obj.direction,'TX') == true
                msgID = 'XCVR:lna' ;
                msg = 'Cannot set LNA Gain for TX path' ;
                throw(MException(msgID, msg)) ;
            end

            if strcmpi(val,'bypass')  == true
                lna = 'BLADERF_LNA_GAIN_BYPASS' ;
            elseif strcmpi(val, 'mid') == true
                lna = 'BLADERF_LNA_GAIN_MID' ;
            elseif strcmpi(val, 'max') == true
                lna = 'BLADERF_LNA_GAIN_MAX' ;
            else
                msgID = 'XCVR:lna' ;
                msg = 'Valid LNA values are [BYPASS, MID, MAX]' ;
                throw(MException(msgID, msg)) ;
            end

            [rv, ~] = calllib('libbladeRF', 'bladerf_set_lna_gain', obj.bladerf.device, lna) ;
            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_set_lna_gain') ;
            obj.lna = val ;
            %disp('Changed LNA') ;
        end

        function val = get.lna(obj)
            if strcmp(obj.direction,'TX') == true
                msgID = 'XCVR:lna' ;
                msg = 'Cannot get LNA Gain for TX path' ;
                throw(MException(msgID, msg)) ;
            end
            lna = 0 ;
            [rv, ~, lna] = calllib('libbladeRF', 'bladerf_get_lna_gain', obj.bladerf.device, lna) ;
            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_get_lna_gain') ;
            if strcmp(lna, 'BLADERF_LNA_GAIN_BYPASS') == true
                obj.lna = 'BYPASS' ;
            elseif strcmp(lna, 'BLADERF_LNA_GAIN_MID') == true
                obj.lna = 'MID' ;
            elseif strcmp(lna, 'BLADERF_LNA_GAIN_MAX') == true
                obj.lna = 'MAX' ;
            else
                obj.lna = 'UNKNOWN' ;
            end
            val = obj.lna ;
            %disp( 'Got LNA') ;
        end

        % Timestamp
        function obj = set.timestamp(obj, ~)
            warning( 'bladeRF:XCVR:timestamp', 'Cannot set the timestamp' ) ;
        end

        function val = get.timestamp(obj)
            t = uint64(0) ;
            [rv, ~, t] = calllib('libbladeRF', 'bladerf_get_timestamp', obj.bladerf.device, obj.module, t) ;
            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_get_timestamp') ;
            val = t ;
        end

        %% Constructor
        function obj = XCVR(dev, dir)
            if strcmp(dir,'RX') == false && strcmp(dir,'TX') == false
                % Throw an exception
            end
            % Set the direction of the transceiver
            obj.direction = dir ;
            obj.bladerf = dev ;
            if strcmp(dir,'RX') == true
                obj.module = 'BLADERF_MODULE_RX' ;
            else
                obj.module = 'BLADERF_MODULE_TX' ;
            end

            % Setup defaults
            obj.config = StreamConfig ;
            obj.samplerate = 1234567.89 ;
            obj.frequency = 1.0e9 ;
            obj.bandwidth = 1.5e6 ;
            if strcmp(dir, 'RX') == true
                obj.vga1 = 30 ;
                obj.vga2 = 30 ;
                obj.lna = 'MAX' ;
            else
                obj.vga1 = -8 ;
                obj.vga2 = 16 ;
            end
            obj.corrections = IQCorrections(dev, obj.module, 0+0j, 0, 1) ;
        end

        %% Usage
        function start(obj)
            %disp(strcat('Start ', obj.direction))
            % Lock down the config
            obj.config.lock() ;

            % Configure the sync config
            [rv, ~] = calllib('libbladeRF', 'bladerf_sync_config', ...
                obj.bladerf.device, ...
                obj.module, ...
                'BLADERF_FORMAT_SC16_Q11_META', ...
                obj.config.num_buffers, ...
                obj.config.buffer_size, ...
                obj.config.num_transfers, ...
                obj.config.timeout_ms ) ;
            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_sync_config') ;

            % Enable the module
            [rv, ~] = calllib('libbladeRF', 'bladerf_enable_module', ...
                obj.bladerf.device, ...
                obj.module, ...
                true ) ;
            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_enable_module') ;
        end

        function samples = receive(obj, num_samples, timeout_ms, time)
            if strcmp( obj.direction, 'RX' ) == true
                if isempty(timeout_ms) == true
                    timeout_ms = 5000 ;
                end
                s16 = int16(zeros(1, 2*num_samples)) ;
                metad = libstruct('bladerf_metadata') ;
                metad.actual_count = 0 ;
                metad.flags = bitshift(1,31) ;
                metad.reserved = 0 ;
                metad.status = 0 ;
                metad.timestamp = time ;
                pmetad = libpointer('bladerf_metadata', metad) ;
                [rv, ~, s16, ~] = calllib('libbladeRF', 'bladerf_sync_rx', ...
                    obj.bladerf.device, ...
                    s16, ...
                    num_samples, ...
                    pmetad, ...
                    timeout_ms ) ;
                obj.bladerf.set_status(rv) ;
                obj.bladerf.check('bladerf_sync_rx') ;
                samples = double(s16(1:2:end)) + double(s16(2:2:end))*1j ;
            else
                error('Cannot receive on TX transceiver') ;
            end
        end

        function transmit(obj, samples, timeout_ms)
            if strcmp(obj.direction, 'TX') == true
                if isempty(timeout_ms) == true
                    timeout_ms = 5000 ;
                end
                metad = libstruct('bladerf_metadata') ;
                metad.actual_count = 0 ;
                metad.flags = bitshift(1,0) | bitshift(1,1) | bitshift(1,2) ;
                metad.reserved = 0 ;
                metad.status = 0 ;
                metad.timestamp = 0 ;
                pmetad = libpointer('bladerf_metadata', metad) ;
                s16 = zeros(1, 2*length(samples)) ;
                s16(1:2:end) = samples(1:2:end) ;
                s16(2:2:end) = samples(2:2:end) ;
                rv = calllib('libbladeRF', 'bladerf_sync_tx', ...
                    obj.bladerf.device, ...
                    s16, ...
                    length(samples), ...
                    pmetad, ...
                    timeout_ms ) ;
                obj.bladerf.set_status(rv) ;
                obj.bladerf.check('bladerf_sync_tx') ;
            else
                error('Cannot transmit on RX transceiver') ;
            end
        end

        function stop(obj)
            %disp(strcat('Stop ', obj.direction)) ;
            % Disable the module
            [rv, ~] = calllib('libbladeRF', 'bladerf_enable_module', ...
                obj.bladerf.device, ...
                obj.module, ...
                false ) ;
            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_enable_module') ;

            % Unlock the configuration for changing
            obj.config.unlock() ;
        end

    end
end
