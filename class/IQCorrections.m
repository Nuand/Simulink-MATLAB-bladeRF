%%
% IQCorrections - This is a submodule used by the bladeRF MATLAB wrapper.
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

%% IQ Corrections for DC offset and gain/phase imbalance
classdef IQCorrections
    properties(Access = private)
        bladerf
        module
    end

    properties
        dc_i
        dc_q
        gain
        phase
    end

    methods
        % Constructor
        function obj = IQCorrections(dev, module, dc_i, dc_q, phase, gain)
            obj.bladerf = dev ;
            obj.module = module ;
            obj.dc_i = dc_i ;
            obj.dc_q = dc_q ;
            obj.phase = phase ;
            obj.gain = gain ;
        end


        % Property Setters/getters
        function obj = set.dc_i(obj, val)
            if val < -2048 || val > 2048
                error('DC offset correction value for Q channel is outside allowed range.');
            end

            %fprintf('Setting I DC offset correction: %d\n', val);

            [rv, ~] = calllib('libbladeRF', 'bladerf_set_correction', ...
                              obj.bladerf.device, ...
                              obj.module, ...
                              'BLADERF_CORR_LMS_DCOFF_I', ...
                              val) ;

            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_set_correction:dc_i') ;
        end

        function obj = set.dc_q(obj, val)
            if val < -2048 || val > 2048
                error('DC offset correction value for Q channel is outside allowed range.');
            end

            %fprintf('Setting Q DC offset correction: %d\n', val);

            [rv, ~] = calllib('libbladeRF', 'bladerf_set_correction', ...
                              obj.bladerf.device, ...
                              obj.module, ...
                              'BLADERF_CORR_LMS_DCOFF_Q', ...
                              val) ;

            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_set_correction:dc_q') ;
        end

        function val = get.dc_i(obj)

            val = int16(0) ;
            [rv, ~, val] = calllib('libbladeRF', 'bladerf_get_correction', ...
                                   obj.bladerf.device, ...
                                   obj.module, ...
                                   'BLADERF_CORR_LMS_DCOFF_I', ...
                                   val ) ;

            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_get_correction:dc_i') ;
        end

        function val = get.dc_q(obj)
            val = int16(0);
            [rv, ~, val] = calllib('libbladeRF', 'bladerf_get_correction', ...
                                 obj.bladerf.device, ...
                                 obj.module, ...
                                 'BLADERF_CORR_LMS_DCOFF_Q', ...
                                 val ) ;

            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_get_correction:dc_q') ;
        end

        function obj = set.phase(obj, val_deg)
            if val_deg < -10 || val_deg > 10
                error('Phase correction value must be within [-10, 10] degrees.');
            end

            val_counts = round((val_deg * 4096 / 10));

            [rv, ~] = calllib('libbladeRF', 'bladerf_set_correction', ...
                obj.bladerf.device, ...
                obj.module, ...
                'BLADERF_CORR_FPGA_PHASE', ...
                val_counts ) ;

            obj.bladerf.set_status(rv);
            obj.bladerf.check('bladerf_set_correction:phase') ;

            %fprintf('Set phase correction: %f (%d)\n', val_deg, val_counts);
        end

        function val_deg = get.phase(obj)
            val_counts = int16(0) ;
            [rv, ~, x] = calllib('libbladeRF', 'bladerf_get_correction', ...
                obj.bladerf.device, ...
                obj.module, ...
                'BLADERF_CORR_FPGA_PHASE', ...
                val_counts ) ;
            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_get_correction:phase') ;


            val_deg = double(x) / (4096 / 10);
            obj.phase = val_deg;

            %fprintf('Get phase correction: %f (%d)\n', val_deg, val_counts);
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
