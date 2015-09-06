classdef simEvent < handle
    % simEvent class to simulate event in simulator
    %
    % Provide function of emulate input event in simulator
    % There are two type event:
    %   1. Packet arrival from higher level
    %   2. TTI periods
    % This object also hold event time
    %
    % Matlab code written by Andi Soekartono, MSC Telecommunication
    % Date 15-June-2015
    
    properties
        eventTime               % Time when the event occurs (in seconds)
        eventType               % Event type: 'packet' or 'TTI'
        eventObject             % event objcet container: empty for TTI event
                                % and lteMACsdu object for packet event
    end
    
    methods
        %%
        function obj = simEvent(time ,type , object)
            % simulator event constructor
            %   obj = simEvent(time ,type , object)
            %     time   : event time
            %     type   : 'packet' or 'TTI'
            %     object : lteMACsdu object for packet, empty for TTI
            
            % store parameters
            obj.eventTime = time;
            obj.eventType = type;
            obj.eventObject = object;
        end
        
    end
    
end

