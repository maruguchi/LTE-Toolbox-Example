%% Parameterization
clear

downlinkParameterization;
uplinkParameterization;


disp(['=========================================================='])
for i = 1:10                          % send 1 frame / 10 subframes
    %% Downlink transmit for each TTI subframe (0.1 ms)
    % eNodeB subframe number and SFN
    
    enb.NSubframe = mod(i-1,10);
    enb.NFrame = floor((i-1)/10);
    disp(['Time stamp ',num2str((enb.NFrame*4+enb.NSubframe)*0.001),'s'])
    disp(['eNodeB Downlink transmission SFN ',num2str(enb.NFrame),' Subframe ',num2str(enb.NSubframe)])
    
    % Initialize uplink channel
    
    uplinkRx = 0;
    
    % Generate subframe transmit grid given enb and user parameters
    
    txGrid = downlinkCellWide(enb,lteDLResourceGrid(enb));
    [txGrid, user] = downlinkUserSpesific(enb, user, txGrid);
    
    % Modulate transmit grid into signals
    [txDLWaveform, txDLWaveformInfo] = lteOFDMModulate(enb, txGrid);
    
    % Zero padded for delay channel time domain shift
    txDLWaveform((size(txDLWaveform,1)+1):(size(txDLWaveform,1)+20)) = zeros();
    
    
    %% Channel in SISO mode
    
    % AWGN channel
    rxDLWaveform = awgn(txDLWaveform,3,'measured');
    %rxDLWaveform = txDLWaveform;
    disp(' ')

    %% Downlink receiver for each TTI subframe (0.1 ms)
    
    for u=1:size(userUE,2)
        % Decode cell wide configuration enbUE for each start of the frames
        if isempty(userUE(u).enb) ||  mod(userUE(u).enb.NSubframe,10) == 0
            userUE(u).enb = downlinkCellWideDecode(userUE(u).enb, rxDLWaveform, txDLWaveformInfo, cec);
        end
        % Decode user spesific data
        userUE(u) = downlinkUserSpesificDecode(userUE(u), rxDLWaveform, txDLWaveformInfo, cec);
        
        
        %% Check recovery
        
        % compare user data transmit and received
        recovered = isequal(user(u).data,userUE(u).data);
        
        % bit error rate for single subframe
        ber = 1 - sum((user(u).data == userUE(u).data))/ size(user(u).data,1);
        
        disp(['Received by user number ',num2str(u),' RNTI ',num2str(userUE(u).RNTI),...
            ' : BER ',num2str(ber),' CRC ',num2str(userUE(u).dataCRC)])
        
        if userUE(u).dataCRC == 0
            ack = 'ACK';
        else
            ack = 'NACK';
        end
        
        % Sending HARQ ACK message to eNodeB
        [txULWaveform, txULWaveformInfo, grid, userUE(u) ] = uplinkUserSpesific(userUE(u),pucch);
        
        disp(['user number ',num2str(u),' sending ',ack])
        disp(' ')
        
        % Users uplink channel aggregation
        uplinkRx = uplinkRx + awgn(txULWaveform,12,'measured');       
        
        
        % UE next received Subframe
        userUE(u).enb.NSubframe = userUE(u).enb.NSubframe + 1;
        
    end
    %% Uplink receiver for each TTI subframe (0.1 ms)
    disp(' ')
    disp('eNodeB decoding HARQ feedback ')
    for u=1:size(user,2)
        % Match received subframe number
        user(u).ue.NSubframe = enb.NSubframe + 1;
        
        
        % HARQ ACK Decode
        [ user(u) ] = uplinkUserSpesificDecode(user(u), pucch, uplinkRx, cec );
        
        if user(u).dataACK == 0
            ack = 'ACK';
        else
            ack = 'NACK';
        end
        disp(['user number ',num2str(u),' ',ack,' received'])
        disp(' ')
        
    end
    
    disp(['=========================================================='])
end



