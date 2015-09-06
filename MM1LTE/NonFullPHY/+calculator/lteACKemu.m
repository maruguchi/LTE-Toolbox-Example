classdef lteACKemu < handle
    %LTEACKEMU Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        filename = '+calculator/bler.mat';
        bler;
    end
    
    methods
        function obj = lteACKemu()
            obj.bler = load(obj.filename,'BLER','SNRpad');
        end
        function ack = getACK(obj, mcs, snr)
            prob = obj.bler.BLER(mcs + 1,snr + obj.bler.SNRpad);
            ack = rand < prob;
        end
    end
    
end

