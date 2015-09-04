classdef StreamConfig
    properties(Access=private)
        locked
    end
    
    properties
        num_buffers
        buffer_size
        num_transfers
        timeout_ms
    end
    
    methods
        function obj = lock(obj)
            obj.locked = true ;
        end
        
        function obj = unlock(obj)
            obj.locked = false ;
        end
        
        function obj = set.num_buffers(obj, val)
            if obj.locked == false
                obj.num_buffers = val ;
            else
                disp('Cannot modify stream config while streaming' ) ;
            end
        end
        
        function obj = set.buffer_size(obj, val)
            if obj.locked == false
                obj.buffer_size = val ;
            else
                disp('Cannot modify stream config while streaming' ) ;
            end
        end
        
        function obj = set.num_transfers(obj, val)
            if obj.locked == false
                obj.num_transfers = val ;
            else
                disp('Cannot modify stream config while streaming' ) ;
            end
        end
        
        function obj = set.timeout_ms(obj, val)
            if obj.locked == false
                obj.timeout_ms = val ;
            else
                disp('Cannot modify stream config while streaming' ) ;
            end
        end
        
        function obj = StreamConfig
            obj.locked = false ;
            obj.num_buffers = 32 ;
            obj.buffer_size = 4096 ;
            obj.num_transfers = 16 ;
            obj.timeout_ms = 1000 ;
        end
    end
end