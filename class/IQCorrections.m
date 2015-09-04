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
            x = real(val) ;
            [rv, ~] = calllib('libbladeRF', 'bladerf_set_correction', ...
                obj.bladerf.device, ...
                obj.module, ...
                'BLADERF_CORR_LMS_DCOFF_I', ...
                x ) ;
            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_set_correction:dc') ;
            
            x = imag(val) ;
            [rv, ~] = calllib('libbladeRF', 'bladerf_set_correction', ...
                obj.bladerf.device, ...
                obj.module, ...
                'BLADERF_CORR_LMS_DCOFF_Q', ...
                x ) ;
            obj.bladerf.set_status(rv) ;
            obj.bladerf.check('bladerf_set_correction:dc') ;
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
