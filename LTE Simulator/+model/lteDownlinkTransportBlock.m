classdef lteDownlinkTransportBlock < handle
    % lteDownlinkTranportBlock class to simulate lte downlink transport block
    %
    % Provide function of MAC PDU container and provide parameter needed for PDCCH and PDSCH generation
    % in PHY later
    %
    % Matlab code written by Andi Soekartono, MSC Telecommunication
    % Date 15-June-2015
    
    
    
    properties
        pdsch = struct;                             % PDSCH parameters container
        dci = struct;                               % DCI parameters container
        pdcch = struct;                             % PDCCH parameters container
        data = [];                                  % MAC PDU data payload
        ue = model.lteUE.empty ;                    % lteUE class container (for tracking)
        rnti ;                                      % UE RNTI
        sdu = model.lteMACsdu.empty ;               % lteMACsdu class container (for tracking)
        tbs ;                                       % transport block size in bits
        crc ;                                       % transport block size CRC/ACK status
        rv ;                                        % transport block redudancy version
        retransmissionNo ;                          % number of retransmission
        HARQNo ;                                    % HARQ process ID
        state = struct;                             % state placeholder
    end
    
    methods
        %%
        function obj = lteDownlinkTransportBlock(ue)
            % Downlink transport block constructor
            %   obj = lteDownlinkTransportBlock(ue)
            %     ue  : lteUE class object
            %
            % this will create object with empty parameters
            % use 'build' method to populate the parameters
            
            % Parameter storing and initialization
            obj.ue = ue;
            obj.rnti = ue.ue.RNTI;
        end
        
        %%
        function [] = build(obj, enb, mcs, rb, data)
            % method to build transport block parameters
            %   obj.build(enb, mcs, rb, data)
            %       enb  : eNodeB parameter
            %       mcs  : modulation and coding scheme
            %       rb   : 1 x 2 vector containing [start-RB RB-number]
            %       data : payload PDU in bits
            %
            
            
            % Initialization
            obj.rv = 0;
            obj.HARQNo = 0;
            obj.data = data;
            obj.retransmissionNo = 0;
            
            % Determine PDSCH modulation scheme
            [modulation, ~] = calculator.mcs2configuration(mcs);
            
            % PDSCH parameter settings
            obj.pdsch.NLayers = 1;                                                  % No of layers
            obj.pdsch.TxScheme = 'Port0';                                           % Transmission scheme SISO
            obj.pdsch.Modulation = modulation;                                      % Modulation scheme
            obj.pdsch.RNTI = obj.ue.ue.RNTI;                                        % 16-bit UE-specific mask
            obj.pdsch.RV = obj.rv;                                                  % Redundancy Version
            obj.pdsch.PRBSet = (rb(1) : rb(1) + rb(2) - 1).';                       % Subframe resource allocation
            
            % DCI parameter settings
            obj.dci.DCIFormat = 'Format1A';                                         % DCI message format
            obj.dci.Allocation.RIV = calculator.allocation2RIV(enb, rb(1), rb(2));  % Resource indication value
            obj.dci.ModCoding = mcs;                                                % MCS data
            obj.dci.RV = obj.rv;                                                    % Redudancy version
            obj.dci.HARQNo = obj.HARQNo;                                            % HARQ process id
            
            % PDCCH parameter settings
            obj.pdcch.NDLRB = enb.NDLRB;                                            % Number of DL-RB in total BW
            obj.pdcch.RNTI =  obj.ue.ue.RNTI;                                       % 16-bit value number
            obj.pdcch.PDCCHFormat = 2;                                              % 2-CCE of aggregation level 2
            
        end
        %% 
        function [] = setRV (obj, rv)
            % method to update transport block redudancy version
            %   obj.setRV (rv)
            %       rv   : redudancy version
            %
            % use this method to change redudancy version for each HARQ
            % transmission (IR)
            
            % set redudancy version to rv number
            obj.rv = rv;
            obj.pdsch.RV = obj.rv;
            obj.dci.RV = obj.rv;
        end
        
        %%
        function [] = setHARQNo (obj, harqNo)
            % method to assign transport block process ID
            %   obj.setHARQNo (harqNo)
            %       harqNo   : HARQ process ID
            %
            % use this method to assign corresponding UE HARQ process ID
            
            % set HARQ process ID
            obj.HARQNo = harqNo;
            obj.dci.HARQNo = obj.HARQNo;
        end
        
        %%
        function [] = updateVRB(obj, enb, rb, mcs)
            % method to update transport block VRB allocation
            %   obj.updateVRB(enb, rb, mcs)
            %       enb  : eNodeB parameter
            %       mcs  : modulation and coding scheme
            %       rb   : 1 x 2 vector containing [start-RB RB-number]
            %
            % use this method when VRB allocation is changed during
            % retransmission
            
            % Determine PDSCH modulation scheme
            [modulation, ~] = calculator.mcs2configuration(mcs);
            
            % Update PDSCH and DCI modulation scheme 
            obj.pdsch.Modulation = modulation;
            obj.dci.ModCoding = mcs;
            
            % set PRB according to new VRB allocation
            obj.pdsch.PRBSet = (rb(1) : rb(1) + rb(2) - 1).';
            
            % calcualte and set RIV (resource indication value) according
            % to new VRB alocation
            obj.dci.Allocation.RIV = calculator.allocation2RIV(enb, rb(1), rb(2));
        end
        
        %%
        function harqNo = getHARQno(obj)
            % method to query HARQ process ID from array of transport block
            %   harqNo = obj.getHARQno
            %   harqNo : HARQ process ID
            %
            % note: this method is unnecessary in Matlab object, thus planned to replace by
            % properties access.
            
            % output HARQ process ID
            harqNo = [obj.HARQNo];
        end
        
        
    end
    
end

