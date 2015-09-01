classdef IQCorrections
    properties(Access = private)
        bladerf
    end
    
    properties
        dc
        phase
        magnitude
    end
    
    methods
        % Constructor
        function obj = IQCorrections(dev, dc, phase, mag)
            obj.bladerf = dev ;
            obj.dc = dc ;
            obj.phase = phase ;
            obj.magnitude = mag ;
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
        
        function obj = set.magnitude(obj, val)
            obj.magnitude = val ;
        end
        
        function val = get.magnitude(obj)
            val = obj.magnitude ;
        end
    end
end
