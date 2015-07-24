classdef ltePFscheduler < handle
    %LTERRSCHEDULER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        ue = model.lteUE.empty;             % served user list
        sduBuffer;                          % sdu Buffer
        sduBufferState;                     % TTI buffer state counter
        allocationState;                    % TTI user allocation counter
        feedbackScheduleN_1 ;               % scheduled feedback cache for N - 1
        feedbackScheduleN ;                 % scheduled feedback cache for N
        rateAdaptation ;                    % rate adaptation toggle flag
        MCS ;                               % used MCS if rate adapation set to 'false'
        alpha ;                             % propotional fair factor
        lastArrival_time;                   % previous inbound SDU packet arrival time
    end
    
    methods
        %%
        function obj = ltePFscheduler()
            % PF Scheduler constructor
            %   obj = ltePFscheduler()
            %
            
            % Setting default parameter
            obj.feedbackScheduleN_1 = [];
            obj.feedbackScheduleN = [];
            obj.rateAdaptation = 'true';
            obj.MCS = 10;
            obj.alpha = 0.1;
        end
        
        %%        
        function [] = addSDU (obj, ueIn, sdu)
            % method to register SDU into MAC controller buffer
            %   obj.addSDU (ueIn, sdu)
            %       ueIn : array of lteUE
            %       sdu  : array of lteMACsdu
            %
            
            % add UE of the SDU into proportional fair calculation
            sduUE = findobj(obj.ue, 'rnti', sdu.rnti);
            if isempty(sduUE)
                sduUE = findobj(ueIn, 'rnti', sdu.rnti);
                sduUE.schedulerBufferIdx = length(obj.ue) + 1;
                obj.ue(sduUE.schedulerBufferIdx) = sduUE;
                obj.sduBuffer(sduUE.schedulerBufferIdx).queue = model.lteMACsdu.empty;
                obj.sduBufferState(size(obj.sduBufferState,1),size(obj.sduBufferState,2) + 1,:) = [sdu.rnti 0];
                obj.ue(length(obj.ue)).alpha = obj.alpha;
                obj.ue(length(obj.ue)).avg = 1;
            end
            % add SDU into queue
            bufferState = obj.getBufferState(sduUE.schedulerBufferIdx);
            sdu.bufferSize = bufferState(1,2);
            sdu.interArrival_time = sdu.arrival_time - obj.lastArrival_time;
            obj.lastArrival_time = sdu.arrival_time;
            obj.sduBuffer(sduUE.schedulerBufferIdx). ...
                queue(length(obj.sduBuffer(sduUE.schedulerBufferIdx).queue) + 1) = sdu;
            sdu.status = 'queued';
        end
        
        %%
        function bufferState = getBufferState(obj, varargin)
            % method to query occupied sdu buffer
            %   bufferState = obj.getBufferState
            %       bufferState : array of buffer size for each UE in bits
            %       ueID        : optional parameter scheduler UE index
            %
            
            if isempty(varargin{1})
                min = 1;
                max = length(obj.ue);
                num = max;
            else
                min = varargin{1};
                max = varargin{1};
                num = 1;
            end
                        
            bufferState = zeros(num,2);
            
            % measure bits in buffer for each UE
            for i = min:max
                % find MAC sdu for spesific UE
                sdu = obj.sduBuffer(i).queue;
                ueBufferLength = 0;
                % sum all sdu length in bits
                for j = 1:length(sdu)
                    ueBufferLength = ueBufferLength + length(sdu(j).data);
                end
                % compact indexing
                if num == 1
                    idx = 1;
                else
                    idx = i;
                end
                % return 0 is buffer empty
                if isempty(ueBufferLength)
                    ueBufferLength = 0;
                end
                
                % return user RNTI and buffer length in bits
                bufferState(idx,1) = obj.ue(i).rnti;
                bufferState(idx,2) = ueBufferLength;
            end
            
        end
        
        %%        
        function [tb, ueMon] = schedule (obj, enb)
            % method to perform schedulling in MAC Layer
            %   [tb, ueMon] = obj.schedule (enb)
            %       enb     : eNodeB parameters
            %
            %       tb      : array of lteDownlinkTransportBlock object 
            %       ueMon   : array of lteUE object
            %
            
            % initialization 
            % create empty list of tb
            tb = model.lteDownlinkTransportBlock.empty;    
            
            % cycle feedback schedule
            % this because reporting of nth TTI is done at n+1th TTI at
            % minimum
            obj.feedbackScheduleN_1 = obj.feedbackScheduleN;
            obj.feedbackScheduleN = [];
            ueMon = obj.feedbackScheduleN_1;
            
            % if no UE return empty
            if isempty(obj.ue )
                obj.sduBufferState(size(obj.sduBufferState,1) + 1,:,:) = obj.getBufferState([]);
                return
            end
            
            % resource block mapping
            rbAvailable = zeros(enb.NDLRB,1);
            
            % proportional fairness turn parameter
            % calculate PF score for all user
            ueNo = length(obj.ue);
            for k = 1:ueNo
                obj.ue(k).calcPFscore
            end
            
            % sort UE based on score this turn 
            % this used as UE preferences from most to least preferred
            [~, Idx] = sort([obj.ue.score], 'descend');
            obj.ue = obj.ue(Idx);
            turnIdx = 1;
            ueServ = 0;
            
            % iterate resource allocatio until all resource block is
            % allocated (or can be allocated)
            while sum(rbAvailable == 0) > 0
                % Reset SDU list to sent
                sduList = [];
                % get this turn UE
                ueCandidate = obj.ue(turnIdx);
                % update UE CQI age
                ueCandidate(1).cqiAge = ueCandidate(1).cqiAge + 1;
                
                % increment counter (for each turn and track whether all user already processed)
                turnIdx = turnIdx + 1;
                ueServ = ueServ + 1;
                allocated = 0;
                
                % If CQI = 0 no transmission
                if ueCandidate(1).cqi ~= 0
                    
                    % check H-ARQ cache for current UE
                    tbCandidate = ueCandidate(1).getRetransmissionBlock;
                    ueCandidate(1).harqBuffer = circshift(ueCandidate(1).harqBuffer,[1 0]);
                    
                   if ~isempty(tbCandidate)
                        % retransmitt if there are transport blcok need to
                        % be retransmitted
                        
                        % if UE transmit in less than 1 TTI ago try to
                        % resent with appropriate CQI value if not resent
                        % regardless channel condition
                        % This is due to channel condition can differ from
                        % when initial HARQ process channel condition
                        if ueCandidate(1).cqiAge < 1
                            % recalculate transport block allocation
                            % according to current CQI
                            [ mcsAlloc, ~, rbAlloc, rbAvailable ] = ...
                                calculator.rateAdaptation( enb, rbAvailable, ueCandidate(1).cqi, length(tbCandidate(1).data)/8);
                        else
                            % sent using initial allocation
                            availRB = find(rbAvailable == 0);
                            if length(tbCandidate(1).pdsch.PRBSet) <= length(availRB)
                                mcsAlloc = tbCandidate(1).dci.ModCoding;
                                rbAlloc = [availRB(1)-1 length(tbCandidate(1).pdsch.PRBSet)];
                                rbAvailable((rbAlloc(1) + 1): (rbAlloc(1) + rbAlloc (2))) = 1;
                            else
                                % if not enough resource block to
                                % retransmission continue iteration
                                mcsAlloc = [];
                            end
                        end
                        
                        % add retransmitted transport block to current
                        % transmission
                        if ~isempty(mcsAlloc)
                            % update to current resource allocation
                            tbCandidate(1).updateVRB(enb, rbAlloc, mcsAlloc);                      
                            % reset rv loop in this version no packet is
                            % dropped
                            if tbCandidate(1).rv == 3
                                tbCandidate(1).setRV(1);
                            else
                                % increment RV for retransmission
                                tbCandidate(1).setRV(tbCandidate(1).rv + 1);                           
                            end
                            % reset crc acknowledgement
                            tbCandidate(1).crc = [];             
                            % track retransmission number
                            tbCandidate(1).retransmissionNo = tbCandidate(1).retransmissionNo + 1;  
                            % store candidate to transport block
                            tb(length(tb)+1) = tbCandidate(1);
                            % reset CQI age
                            ueCandidate(1).cqiAge = -1;
                            
                            % update feedback scheduler
                            obj.feedbackScheduleN(length(obj.feedbackScheduleN)+1).ue = ueCandidate(1);
                            obj.feedbackScheduleN(length(obj.feedbackScheduleN)).ackHARQNo = tbCandidate(1).HARQNo;
                            allocated = 1;
                        end
                    end
                    
                    % if no retransmission and there are available HARQ
                    % process, send new transport block
                    if allocated == 0 && ~isempty(ueCandidate(1).getHARQno)
                        
                        % find queued SDU for spesific UE
                        sduCandidate = obj.sduBuffer(ueCandidate(1).schedulerBufferIdx).queue;       % number available SDU
                        if ~isempty(sduCandidate)
                            sduDataLength = 0 ;                                                         % total length SDU in Bits
                            % calculate PDU length
                            % this iteration will try to include sdu one by
                            % one that fit into available resource bloc
                            for i = 1:length(sduCandidate)
                                sduList{i} = sduCandidate(i).data; %#ok<AGROW>
                                % add sdu
                                sduDataLength = sduDataLength + length(sduCandidate(i).data) + 16;
                                % check whether availabel resource block fit
                                [ mcsAlloc, ~, ~, ~ ] = ...
                                    calculator.rateAdaptation( enb, rbAvailable, ueCandidate(1).cqi, (sduDataLength + 8)/8);
                                if isempty(mcsAlloc)
                                    % if not fit return to previous
                                    % iteration state and stop
                                    sduList(i) = []; %#ok<AGROW>
                                    sduDataLength = sduDataLength - ( length(sduCandidate(i).data) + 16);
                                    break
                                end
                            end
                            
                            % construct ne transport block is there are sdu
                            % can be sent
                            if ~isempty(sduList)
                                % calculate resource allocation
                                [ mcsAlloc, tbsAlloc, rbAlloc, rbAvailable] = ...
                                    calculator.rateAdaptation( enb, rbAvailable, ueCandidate(1).cqi, (sduDataLength+8)/8);
                                
                                % PDU multiplexing
                                pdu = calculator.macMux( tbsAlloc, sduList );
                                % transport block generation
                                tbCandidate(1) = model.lteDownlinkTransportBlock(ueCandidate(1));
                                tbCandidate(1).build(enb,  mcsAlloc, rbAlloc, pdu);
                                % set HARQ process ID and store to UE HARQ
                                % register
                                tbCandidate(1).setHARQNo(ueCandidate(1).getHARQno);
                                ueCandidate(1).addHARQProcess(tbCandidate(1));
                                % update to current transmission transport
                                % block                                 
                                tb(length(tb)+1) = tbCandidate(1);
                                % update CQI age
                                ueCandidate(1).cqiAge = -1;
                                
                                % update n-1th resource block allocation 
                                ueCandidate(1).R_1 = ueCandidate(1).R;
                                
                                % update feedback scheduler
                                obj.feedbackScheduleN(length(obj.feedbackScheduleN)+1).ue = ueCandidate(1);
                                obj.feedbackScheduleN(length(obj.feedbackScheduleN)).ackHARQNo = tbCandidate(1).HARQNo;
                                % clear sent sdu from scheduler sdu buffer
                                for j = 1:length(sduList)
                                    sduCandidate(j).status = 'sent';
                                    sduCandidate(j).sent_time = enb.NFrame * 0.01 + enb.NSubframe * 0.001;
                                    tbCandidate(1).sdu(length( tbCandidate(1).sdu) + 1) = sduCandidate(j);
                                    ueCandidate(1).sentSDU(length(ueCandidate(1).sentSDU) + 1) = sduCandidate(j);
                                    obj.sduBuffer(ueCandidate(1).schedulerBufferIdx).queue(...
                                        obj.sduBuffer(ueCandidate(1).schedulerBufferIdx).queue == sduCandidate(j)) = [];
                                end
                            end
                        end
                    end
                end
                % schedule to update CQI if after 4 TTI UE never get scheduled
                if ueCandidate(1).cqiAge == 3
                     ueCandidate(1).cqiAge = -1;
                    obj.feedbackScheduleN(length(obj.feedbackScheduleN)+1).ue = ueCandidate(1);
                    obj.feedbackScheduleN(length(obj.feedbackScheduleN)).ackHARQNo = [];
                end
                % if all user served stop
                if  ueServ < ueNo
                    continue
                else
                    % save current buffer state
                    obj.sduBufferState(size(obj.sduBufferState,1) + 1,:,:) = obj.getBufferState([]);
                    return
                end
            end
            % save current buffer state
            obj.sduBufferState(size(obj.sduBufferState,1) + 1,:,:) = obj.getBufferState([]);
        end
    end
    
end

