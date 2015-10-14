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

%% VCTCXO trim control
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
