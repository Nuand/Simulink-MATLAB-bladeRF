%%
% StreamConfig - This is a submodule used by the bladeRF MATLAB wrapper.
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

%% Configuration of synchronous RX/TX sample stream
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
