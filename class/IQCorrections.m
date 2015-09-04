classdef IQCorrections
    properties(Access = private)
        bladerf
    end
    
    properties
        dc
        gain
        phase
    end
    
    methods
        % Constructor
        function obj = IQCorrections(dev, dc, phase, gain)
            obj.bladerf = dev ;
            obj.dc = dc ;
            obj.phase = phase ;
            obj.gain = gain ;
        end
        
        % Property Setters/getters
        function obj = set.dc(obj, val)
            obj.dc = val ;
        end
        
        function val = get.dc(obj)
            val = obj.dc ;
        end
        
        function obj = set.phase(obj, val)
            obj.phase = val ;
        end
        
        function val = get.phase(obj)
            val = obj.phase ;
        end
        
        function obj = set.gain(obj, val)
            obj.gain = val ;
        end
        
        function val = get.gain(obj)
            val = obj.gain ;
        end
    end
end
