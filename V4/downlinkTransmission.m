% Matlab code for running LTE downlink physical layer
% written by Andi Soekartono, MSC Telecommunication
% Date 05-May-2015

clear

% Loop for each TTI (one subframe)
% written by Andi Soekartono, MSC Telecommunication
% Date 06-May-2015
waitBar = waitbar(0,'Start Calculating ....');
snrMin = 1;
snrMax = 15;
totalSubframe = 10;
mcsTest = [16,25,28];
progress = 0;
done = size(mcsTest,2)*(snrMax-snrMin+1)*(totalSubframe+1);

for mcsIdx = 1:size(mcsTest,2)
    for SNR = snrMin:snrMax
        % Setting parameter
        mcs = mcsTest(mcsIdx);
        helperDownlinkParameterization;
        
        fullWaveform = [];                  % waveform place holder
        fullMIB = [];                       % transmitted MIB bits placeholder
        fullCFI = [];                       % transmitted CFI bits placeholder
        fullDCI = [];                       % transmitted DCI bits placeholder
        fullData = [];                      % transmitted Data bits placeholder
        fullRxWaveform = [];                % received waveform placeholder
        fullRxMIB = [];                     % received MIB bits placeholder
        fullRxCFI = [];                     % received CFI bits placeholder
        fullRxDCI = [];                     % received DCI bits placeholder
        fullRxData = [];                    % received Data bits placeholder
        
        hARQCache = [];
        hARQFeedback = [];
        processId = 0;
        fullProcess = [];
        
        
        for i = 0:totalSubframe
            progress = progress + 1;
            waitbar(progress/done,waitBar,['Calculating DLSCH MCS = ',num2str(mcs),' for SNR = ',num2str(SNR)]);
            
            enb.NSubframe = mod(i,10);          % set current subframe number
            enb.NFrame = floor(i/10);
            sharedChannel.ue.NSubframe = enb.NSubframe;

            
            %% prototype for HARQ will be separate function later;
            if ~( mod(enb.NSubframe,5) == 0 )
                if sharedChannel(1).dataACK  == 0
                    processId = processId + 1;
                    sharedChannel(1).dci.HARQNo = processId;
                    sharedChannel(1).dci.RV = 0;
                else
                    sharedChannel(1).dci.RV = sharedChannel(1).dci.RV +1 ;
                end
                sharedChannel(1).pdsch.RV = sharedChannel(1).dci.RV ;
                fullProcess = [fullProcess,processId];
            end
            
            
            %% Generate downlink transmit signal
            
            [ waveform, waveformInfo, resourceGrid, info ] = lteDLPHYTX(enb, sharedChannel);
            
            % put transmitted signal and data to placeholder
            fullWaveform = [fullWaveform ; waveform];
            fullMIB = [fullMIB ; info.mibBits];
            fullCFI = [fullCFI ; info.cfiBits];
            fullDCI = [fullDCI ; info.dciBits];
            
            
            %% AWGN channel
            %rxWaveform = awgn(waveform,SNR,'measured');
            
            
            [ rxWaveform ] = channel(waveform,'AWGN', SNR, waveformInfo, enb.CellRefP, mcs);
            
            %rxWaveform = waveform;
            
            %% Demodulate and decode receive signal
            [ userChannel(1), infoUE ] = lteDLPHYRX( rxWaveform, waveformInfo , userChannel(1).enb, userChannel(1));
            
            
            
            %% Sending HARQ ACK
            
            [ waveformACK, waveformACKInfo ] = lteULPHYTX( userChannel(1) );
            
            %% Uplink channel
            [ rxWaveformACK ] = channel(waveformACK,'AWGN', SNR, waveformACKInfo, enb.CellRefP, mcs);
            
            %% Decoding HARQ ACK
            [ sharedChannel(1)] = lteULPHYRX( rxWaveformACK,sharedChannel(1) );
            
            
            
            % put received signal and data to placeholder
            fullRxWaveform = [fullRxWaveform ; rxWaveform];
            fullRxMIB = [fullRxMIB ; infoUE.mibBits];
            fullRxCFI = [fullRxCFI ; infoUE.cfiBits];
            % if failure to decode mark as block error
            if sum(size(infoUE.dciBits) == size(info.dciBits)) < 2
                fullRxDCI = [fullRxDCI ; ones(size(info.dciBits))+1];
            else
                fullRxDCI = [fullRxDCI ; infoUE.dciBits];
            end
            
            if ~isempty(info.dataBits)
                if sharedChannel(1).dataACK == 0 || sharedChannel(1).dci.RV == 3
                    fullData = [fullData ; info.dataBits];
                    if sum(size(infoUE.dataBits) == size(info.dataBits)) < 2
                        fullRxData = [fullRxData ; ones(size(info.dataBits))+1];
                    else
                        fullRxData = [fullRxData ; infoUE.dataBits];
                    end
                    sharedChannel(1).dataACK = 0;
                end
                
            end
            
        end
        %  calculating BER for each data
        % written by Andi Soekartono, MSC Telecommunication
        % Date 06-May-2015
        mibBER(mcsIdx,SNR) = 1 - sum((fullMIB == fullRxMIB))/ size(fullMIB,1);
        cfiBER(mcsIdx,SNR) = 1 - sum((fullCFI == fullRxCFI))/ size(fullCFI,1);
        dciBER(mcsIdx,SNR) = 1 - sum((fullDCI == fullRxDCI))/ size(fullDCI,1);
        dataBER(mcsIdx,SNR) = 1 - sum((fullData == fullRxData))/ size(fullData,1);
        codeRate(mcsIdx) = sharedChannel(1).pdsch.codeRate;
        modulation{mcsIdx} = sharedChannel(1).pdsch.Modulation;
    end
end
delete(waitBar);


% Plotting signal

% plot(0:1/waveformInfo.SamplingRate:1/waveformInfo.SamplingRate*(size(fullWaveform,1)-1),abs(fullWaveform));

screen = get(0, 'MonitorPositions');
plotSize = [(screen(3)/2)- 40,(screen(4)/2)- 120];

% spectrum analyzer
% spectrumAnalyzer = dsp.SpectrumAnalyzer();
% spectrumAnalyzer.Name = 'Transmitted signal spectrum';
% spectrumAnalyzer.Position = [20,screen(4)-plotSize(2)-120,plotSize(1),plotSize(2)];
% spectrumAnalyzer.SampleRate = waveformInfo.SamplingRate;
%
% step(spectrumAnalyzer,fullWaveform);
%
% spectrumAnalyzer2 = dsp.SpectrumAnalyzer();
% spectrumAnalyzer2.Name = 'Received signal spectrum';
% spectrumAnalyzer2.Position = [60+plotSize(1),screen(4)-plotSize(2)-120,plotSize(1),plotSize(2)];
% spectrumAnalyzer2.SampleRate = waveformInfo.SamplingRate;
%
% step(spectrumAnalyzer2,fullRxWaveform);

% plot BER
plotBER