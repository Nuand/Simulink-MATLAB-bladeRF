classdef StreamConfig
    
    properties
        buffers
        buffer_length
        transfers
        timeout
    end
    
    methods
        function obj = StreamConfig
            obj.buffers = 32 ;
            obj.buffer_length = 4096 ;
            obj.transfers = 16 ;
            obj.timeout = 1000 ;
        end
    end
end