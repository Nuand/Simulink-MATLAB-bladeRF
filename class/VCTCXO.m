classdef VCTCXO

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Properties
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    properties(SetAccess=immutable, Hidden=true)
        bladerf
    end

    properties(SetAccess=immutable)
        stored_trim
    end

    properties
        current_trim
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Property Handling
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = set.current_trim(obj, val)
            val_u16 = uint16(val);
            if val_u16 ~= val
                error('Provided VCTCXO Trim DAC value is outside allowed range.')
            end

            rv = calllib('libbladeRF', 'bladerf_dac_write', obj.bladerf.device, val_u16);
            obj.bladerf.set_status(rv);
            obj.bladerf.check('bladerf_dac_write');
        end

        function curr = get.current_trim(obj)
            curr = uint16(0);
            [rv, ~, curr] = calllib('libbladeRF', 'bladerf_dac_read', obj.bladerf.device, curr);
            obj.bladerf.set_status(rv);
            obj.bladerf.check('bladerf_dac_read');
        end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Methods
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods

        %% Construtor
        function obj = VCTCXO(dev)
            obj.bladerf = dev;

            % Fetch the VCTCXO trim stored in flash
            stored = uint16(0);
            [rv, ~, stored] = calllib('libbladeRF', 'bladerf_get_vctcxo_trim', obj.bladerf.device, stored);

            obj.bladerf.set_status(rv);
            obj.bladerf.check('bladerf_get_vctcxo_trim');
            obj.stored_trim = stored;

        end
    end
end
