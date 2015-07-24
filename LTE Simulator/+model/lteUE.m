classdef lteUE < handle
    % lteUE class to simulate logical lte UE that reside in eNodeB
    %
    % Provide function as UE related container, such as:
    %   - UE CQI value
    %   - UE RNTI and PUCCH (uplink feedback channel) container
    %   - HARQ process register
    %   - MAC scheduler related register (RR turn, PF score)
    %
    % Matlab code written by Andi Soekartono, MSC Telecommunication
    % Date 15-June-2015
    
    properties
        rnti                                                % UE RNTI number    
        cqi                                                 % UE CQI (channel quality index)
        cqiAge                                              % UE CQI reporting age in TTI
        ue = struct;                                        % UE PUCCH parameters container    
        harqBuffer = model.lteDownlinkTransportBlock.empty; % HARQ process register
        turnNo ;                                            % Round Robin turn (if RR scheduler is used)
        sentSDU = model.lteMACsdu.empty;                    % Sent SDU tracker
        schedulerBufferIdx;                                 % UE index in scheduller Buffer
        alpha ;                                             % PF scheduler alpha value
        avg ;                                               % PF scheduler avg value                    
        R ;                                                 % PF scheduler n RB available bytes
        R_1 ;                                               % PF scheduler n-1 RB available bytes
        score ;                                             % PC scheduler score
        enb;                                                % eNodeB parameter container
    end
    
    methods
        %%
        function obj = lteUE(enb, rnti, pucchRIdx)
            % logical UE constructor
            %   obj = lteUE(enb, rnti, pucchRIdx)
            %     enb       : eNodeB parameters
            %     rnti      : UE RNTI number
            %     pucchRIdx : UE PUCCH resource index
            %
            
            % set parameters
            obj.rnti = rnti;                                  % assign RNTI number  
            obj.cqi = 5;                                      % assign default CQI   
            obj.cqiAge = 0;                                   % initial CQI age  
            obj.enb = enb;                                    % assign enb 
            
            obj.ue.NULRB = enb.NDLRB;                         % Number Uplink Resource Block similar to downlink one
            obj.ue.CyclicPrefixUL = enb.CyclicPrefix;         % Uplink cyclic prefix similar to downlink
            obj.ue.Hopping = 'Off';                           % No frequency hopping
            obj.ue.NCellID = enb.NCellID;                     % Cell ID similar to downlink Physical Cell ID
            obj.ue.Shortened = 0;                             % No SRS transmission
            obj.ue.NTxAnts = 1;                               % Number of UE antenna (SISO system)
            obj.ue.NSubframe = enb.NSubframe;                 % subframe number
            obj.ue.RNTI = rnti;                               % user spesific C-RNTI
            
            obj.ue.pucch.ResourceIdx = pucchRIdx;             % UE spesific ResourceIdx
            
            % Set the size of resources allocated to PUCCH format 2. This affects the
            % location of PUCCH 1 transmission
            obj.ue.pucch.ResourceSize = 0;
            % Delta shift PUCCH parameter as specified in TS36.104 Appendix A9 [ <#8 1> ]
            obj.ue.pucch.DeltaShift = 2;
            % Number of cyclic shifts used for PUCCH format 1 in resource blocks with a
            % mixture of formats 1 and 2. This is the N1cs parameter as specified in
            % TS36.104 Appendix A9
            obj.ue.pucch.CyclicShifts = 0;
            
            % set scheduler related parameter            
            obj.turnNo = 0;                     % default turn number for Round Robind
                                 
            % calculate current RB capacity in bytes and store result
            [ ~, tbsAlloc, rbAlloc, ~ ] = calculator.rateAdaptation( enb, zeros(enb.NDLRB, 1), obj.cqi, 100, 'A');
            obj.R = double(tbsAlloc) / (rbAlloc(2) * 8.0);
            obj.R_1 = 0;
        end
        
        %%
        function [] = addHARQProcess(obj, tb)
            % method to add new HARQ process
            %   obj.addHARQProcess(tb)
            %       tb : lteDownlinktransportBlock object
            %       
            
            % check available HARQ slot in register
            tbNo = length(obj.harqBuffer);
            % store transport block in HARQ register
            obj.harqBuffer(tbNo + 1) = tb;
        end
        
        %%
        function [] = removeHARQProcess(obj, HARQNo)
            % method to remove completed HARQ process
            %   obj.removeHARQProcess(HARQNo)
            %       HARQNo : HARQ process ID
            %       
            
            % get register index for given HARQ process ID
            tb = findobj(obj.harqBuffer,'HARQNo',HARQNo);
            tbIdx = find(obj.harqBuffer == tb);
            % empty correspond register slot
            obj.harqBuffer(tbIdx) = []; %#ok<FNDSB>
        end
        %% round robin turn No
        function turnNo = getTurn(obj)
            % method to fetch UE, Round RObing turn number
            %   obj.getTurn
            %       turnNo : round robin turn number
            %       
                        
            turnNo = [obj.turnNo];
        end
                       
        %%
        function tb = getRetransmissionBlock(obj)
            % method to fetch transport block that need to be retransmitted
            %   tb  = obj.getRetransmissionBlock
            %       tb : lteDownlinkTransportBlock object
            %       
               
            % find trasport block that have decoding failure in HARQ
            % register
            tbCandidate = findobj(obj.harqBuffer, 'crc', 1);
            if isempty(tbCandidate)
                % if no transport block return empty
                tb = model.lteDownlinkTransportBlock.empty;
            else
                % reutrn first transport blcok that need to be
                % retransmitted
                tb = tbCandidate(1);
            end
        end
        
        %%
        function harqNo = getHARQno(obj)
            % method to return available HARQ process ID
            %   harqNo = obj.getHARQno
            %       harqNo : HARQ process ID
            %       
            % If HARQ process are full, ie: 8 process already running
            % harqNo return empty
            
            % collect running HARQ process
            listHARQno = obj.harqBuffer.getHARQno;
            if length(listHARQno) < 8
                % if les than 8 process currenlty running return next
                % avaialble ID
                avaiNo = find(ismember(0:7, listHARQno) == 0);
                harqNo = avaiNo(1) - 1;
            else
                % return empty if already 8 process running
                harqNo = [];
            end
        end
        
        %%
        function [] = addSentSDU(obj, sdu)
            % method to add transmitted sdu to UE register
            %   obj.addSentSDU(sdu)
            %       sdu : lteMACsdu object
            %       
            % this usefull for each UE sdu tracking 
            
            % store sdu to register
            sduNo = length(obj.sentSDU);
            obj.sentSDU(sduNo + 1) = sdu;
        end
        
        %%
        function runProcess = getRunHARQ(obj)
            % method to check running HARQ process number
            %   runProcess = obj.getRunHARQ
            %       runProcess : number active HARQ process 
            %       
            
            % calculate and return HARQ register length
            runProcess = length([obj.harqBuffer]);
        end
        
        %%
        function [] = calcPFscore(obj)
            % method to update current PF scheduler score
            %   obj.calcPFscore
            %        
            % this method is used when MAC scheduler is set as PF       
            
            % no transmission if CQI = 0
            if obj.cqi == 0
                return
            end
            
            % calculate RB capacity in bytes given CQI value
            [ ~, tbsAlloc, rbAlloc, ~ ] = calculator.rateAdaptation( obj.enb, zeros(obj.enb.NDLRB, 1), obj.cqi, 10, 'A');
            obj.R = double(tbsAlloc) / (rbAlloc(2) * 8.0);
            
            % calculate current average throughput
            obj.avg = (1 - obj.alpha) * obj.avg + obj.alpha * obj.R_1;
            
            % calculate PF score
            obj.score = obj.R / obj.avg;
            
            % reinitialize R n-1 (for next turn RB capacity)
            obj.R_1 = 0;
        end
    end
end
