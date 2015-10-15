classdef lteMACsdu < handle
    % lteMACsdu class to simulate higher layer Service Data Unit (SDU)
    %
    % Provide function of to contains data bits and designated UE
    % 
    % Also time register is provided to track the object process to the simulator
    % such as: created, sent, delivered and queued time
    %
    % Matlab code written by Andi Soekartono, MSC Telecommunication
    % Date 15-June-2015
    
    properties
        rnti                    % UE spesific RNTI
        data                    % data bits container
        arrival_time            % SDU arrival time stamp
        sent_time               % SDU 1st transmission time (in TTI ms)
        delivered_time          % SDU demodulation in UE (in TTI ms)
        delayUE_time            % time spent from arrival time until delivered time, UE point of view
        delayENB_time           % time spent from arrival time until delivered time, ENB point of view
        interArrival_time       % time interval between this SDU to previous SDU
        bufferSize              % UE spesific buffer size at arrival
        status                  % SDU status
    end
    
    methods
        %%
        function obj = lteMACsdu (rnti, data)
            % MAC SDU constructor
            %   obj = lteMACsdu (rnti, data)
            %     rnti : UE RNTI number
            %     data : data payload bits
            
            % paramater storing
            obj.rnti = rnti;
            obj.data = data;
        end
        
    end
    
end

