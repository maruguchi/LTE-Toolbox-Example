classdef lteACKemu < handle
    % lteACKemu class to emulate HARQ ACK under certain channel condition
    % Matlab code written by Andi Soekartono, MSC Telecommunication
    % Date 1-September-2015
    
    properties
        filename = '+calculator/bler.mat';          % BLER distribution profile file
        bler;                                       % BLER for current channel condition
    end
    
    methods
        function obj = lteACKemu()
            % ACK emulator constructor
            %   obj = lteACKemu()
            %    
            
            % load BLER file
            obj.bler = load(obj.filename,'BLER','SNRpad');
        end
        function ack = getACK(obj, mcs, snr)
            % generate ACK bit according to MCS and channel condition
            %   ack = obj.getACK( mcs, snr)
            %
            %   ack : ack bit
            %   mcs : modulation and coding scheme index
            %   snr : AWGN SNR number
            %
            
            % get errot probability
            prob = obj.bler.BLER(mcs + 1,snr + obj.bler.SNRpad);
            % generate random ack bit
            ack = rand < prob;
        end
    end
    
end

