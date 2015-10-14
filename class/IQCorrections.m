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

%% IQ Corrections for DC offset and gain/phase imbalance
classdef IQCorrections
    properties(Access = private)
        bladerf
        module
    end

    properties
        dc
        gain
        phase
    end

    methods
        % Constructor
        function obj = IQCorrections(dev, module, dc, phase, gain)
            obj.bladerf = dev ;
            obj.module = module ;
            obj.dc = dc ;
            obj.phase = phase ;
            obj.gain = gain ;
        end

        % Property Setters/getters
        function obj = set.dc(obj, val)
%             x = real(val) ;
%             [rv, ~] = calllib('libbladeRF', 'bladerf_set_correction', ...
%                 obj.bladerf.device, ...
%                 obj.module, ...
%                 'BLADERF_CORR_LMS_DCOFF_I', ...
%                 x ) ;
%             obj.bladerf.set_status(rv) ;
%             obj.bladerf.check('bladerf_set_correction:dc') ;
%
%             x = imag(val) ;
%             [rv, ~] = calllib('libbladeRF', 'bladerf_set_correction', ...
%                 obj.bladerf.device, ...
%                 obj.module, ...
%                 'BLADERF_CORR_LMS_DCOFF_Q', ...
%                 x ) ;
%             obj.bladerf.set_status(rv) ;
%             obj.bladerf.check('bladerf_set_correction:dc') ;
        end

        function val = get.dc(obj)
            x = int16(0) ;
            [rv, ~, x] = calllib('libbladeRF', 'bladerf_get_correction', ...
                obj.bladerf.device, ...
                obj.module, ...
                'BLADERF_CORR_LMS_DCOFF_I', ...
                x ) ;
            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_get_correction:dc') ;
            disp( num2str(x) ) ;
            obj.dc = double(x) ;

            [rv, ~, x] = calllib('libbladeRF', 'bladerf_get_correction', ...
                obj.bladerf.device, ...
                obj.module, ...
                'BLADERF_CORR_LMS_DCOFF_Q', ...
                x ) ;
            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_get_correction:dc') ;
            disp( num2str(x) ) ;
            obj.dc = obj.dc + double(x) *1j ;
            val = obj.dc ;
        end

        function obj = set.phase(obj, val)
            [rv, ~] = calllib('libbladeRF', 'bladerf_set_correction', ...
                obj.bladerf.device, ...
                obj.module, ...
                'BLADERF_CORR_FPGA_PHASE', ...
                val / 360.0 * 8192.0 ) ;
            obj.bladerf.set_status(rv);
            obj.bladerf.check('bladerf_set_correction:phase') ;
        end

        function val = get.phase(obj)
            x = int16(0) ;
            [rv, ~, x] = calllib('libbladeRF', 'bladerf_get_correction', ...
                obj.bladerf.device, ...
                obj.module, ...
                'BLADERF_CORR_FPGA_PHASE', ...
                x ) ;
            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_get_correction:phase') ;
            disp(num2str(x)) ;
            obj.phase = double(x) * 360.0 / 8192.0 ;
            val = obj.phase ;
        end

        function obj = set.gain(obj, val)
            [rv, ~] = calllib('libbladeRF', 'bladerf_set_correction', ...
                obj.bladerf.device, ...
                obj.module, ...
                'BLADERF_CORR_FPGA_GAIN', ...
                val * 4096.0 ) ;
            obj.bladerf.set_status(rv);
            obj.bladerf.check('bladerf_set_correction:gain') ;
        end

        function val = get.gain(obj)
            x = int16(0) ;
            [rv, ~, x] = calllib('libbladeRF', 'bladerf_get_correction', ...
                obj.bladerf.device, ...
                obj.module, ...
                'BLADERF_CORR_FPGA_GAIN', ...
                x ) ;
            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_get_correction:gain') ;
            obj.phase = double(x) / 4096.0 ;
            val = obj.phase ;
        end
    end
end
