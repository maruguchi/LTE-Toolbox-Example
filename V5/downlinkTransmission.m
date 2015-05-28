% Matlab code for running LTE downlink physical layer
% written by Andi Soekartono, MSC Telecommunication
% Date 05-May-2015

clear

% Loop for each TTI (one subframe)
% written by Andi Soekartono, MSC Telecommunication
% Date 06-May-2015
% Last edited 28-May-2015

% Simulation parameter

snrMin = 1;             % minimum SNR
snrMax = 15;            % maximum SNR
totalSubframe = 20;     % total subframe iteration
mcsTest = [ 11 ];       %#ok<NBRAK> % MCS number tested

%  waitbar GUI for monitoring simulation progress
waitBar = waitbar( 0 , 'Start Calculating ....' );
progress = 0;
done = length(mcsTest) * (snrMax - snrMin + 1 ) * (totalSubframe + 1);

% LTE radio channel (fading channel) parameter setting
chcfg = struct('Seed',1,'DelayProfile','EPA','NRxAnts',1);
chcfg.DopplerFreq = 5.0;
chcfg.MIMOCorrelation = 'Low';
chcfg.InitPhase ='Random';
chcfg.ModelType = 'GMEDS' ;
chcfg.NTerms = 16;
chcfg.NormalizeTxAnts = 'On';
chcfg.NormalizePathGains = 'On';


%% Loop for all tested MCS
for mcsIdx = 1:length(mcsTest)
    %% Loop for all tested SNR
    for SNR = snrMin:snrMax
        % Setting parameter
        mcs = mcsTest(mcsIdx);              % get current MCS
        helperDownlinkParameters;           % run parameter setting (m-file script)
        
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
        fullCQI = [];                       % cqi calculation placeholder
        
        processId = 0;                      % HARQ identifier
        fullProcess = [];                   % full identifier placeholder
        
        messageNumber = 0;                  % total PDSCH sent
        messageResend = 0;                  % total PDSCH resent
        
        % iteration number in subframes
        for i = 0 : totalSubframe
            progress = progress + 1;
            waitbar(progress/done, waitBar, ['Calculating DLSCH MCS = ', num2str(mcs), ' for SNR = ', num2str(SNR)]);
            
            enb.NSubframe = mod(i,10);                                     % set current subframe number
            enb.NFrame = floor(i/10);                                      % set current frame number
            sharedChannel.ue.NSubframe = enb.NSubframe;                    % set current ue subframe number

            
            %% prototype for HARQ will be separate function later;
            if ~( mod(enb.NSubframe,5) == 0 )
                if sharedChannel(1).dataACK  == 0
                    processId = processId + 1;
                    sharedChannel(1).dci.HARQNo = processId;
                    sharedChannel(1).dci.RV = 0;
                else
                    sharedChannel(1).dci.RV = sharedChannel(1).dci.RV + 1 ;
                    messageResend = messageResend + 1;
                end
                sharedChannel(1).pdsch.RV = sharedChannel(1).dci.RV ;
                fullProcess = [fullProcess, processId]; %#ok<AGROW>
                messageNumber = messageNumber + 1;
            end
            
            
            %% Generate downlink transmit signal
            
            [ waveform, waveformInfo, resourceGrid, info ] = lteDLPHYTX(enb, sharedChannel);
            
            % put transmitted signal and data to placeholder
            fullWaveform = [fullWaveform ; waveform]; %#ok<AGROW>
            fullMIB = [fullMIB ; info.mibBits]; %#ok<AGROW>
            fullCFI = [fullCFI ; info.cfiBits]; %#ok<AGROW>
            fullDCI = [fullDCI ; info.dciBits]; %#ok<AGROW>
            
            
            %% LTE radio channel EPA 5 Downlink
            
            chcfg.SamplingRate = waveformInfo.SamplingRate;
            chcfg.InitTime = enb.NSubframe * 1e-3;
            fdWaveform = lteFadingChannel(chcfg, waveform);
            
            %% AWGN channel Uplink
            
            [ rxWaveform ] = channel(fdWaveform, 'AWGN', SNR, waveformInfo, enb.CellRefP, mcs);
            

            
            %% Demodulate and decode receive signal
            [ userChannel(1), infoUE ] = lteDLPHYRX( rxWaveform, waveformInfo , userChannel(1).enb, userChannel(1));
            
            
            
            %% Sending HARQ ACK
            
            [ waveformACK, waveformACKInfo ] = lteULPHYTX( userChannel(1) );
                         
            %% LTE radio channel EPA 5 Downlink
            
            chcfg.SamplingRate = waveformACKInfo.SamplingRate;
            chcfg.InitTime = enb.NSubframe*1e-3;
            fdWaveformACK = lteFadingChannel(chcfg, waveformACK);
            
            %% AWGN channel Uplink
            [ rxWaveformACK ] = channel(fdWaveformACK, 'AWGN', SNR, waveformACKInfo, enb.CellRefP, mcs);
            
            %% Decoding HARQ ACK
            
            [ sharedChannel(1)] = lteULPHYRX( rxWaveformACK, sharedChannel(1) );
            
            
            
            % put received signal and data to placeholder
            fullRxWaveform = [fullRxWaveform ; rxWaveform]; %#ok<AGROW>
            fullRxMIB = [fullRxMIB ; infoUE.mibBits]; %#ok<AGROW>
            fullRxCFI = [fullRxCFI ; infoUE.cfiBits]; %#ok<AGROW>
            
            % if failure to decode mark as block error
            if sum(size(infoUE.dciBits) == size(info.dciBits)) < 2
                fullRxDCI = [fullRxDCI ; ones(size(info.dciBits)) + 1]; %#ok<AGROW>
            else
                fullRxDCI = [fullRxDCI ; infoUE.dciBits]; %#ok<AGROW>
            end
            
            % if failure to decode mark as block error and set ack
            % accordingly
            if ~isempty(info.dataBits)
                if sharedChannel(1).dataACK == 0 || sharedChannel(1).dci.RV == 3
                    fullData = [fullData ; info.dataBits]; %#ok<AGROW>
                    if sum(size(infoUE.dataBits) == size(info.dataBits)) < 2
                        fullRxData = [fullRxData ; ones(size(info.dataBits)) + 1]; %#ok<AGROW>
                    else
                        fullRxData = [fullRxData ; infoUE.dataBits]; %#ok<AGROW>
                    end
                    sharedChannel(1).dataACK = 0;
                end
                fullCQI = [fullCQI ; infoUE.cqi]; %#ok<AGROW>
            end
            
        end
        % calculating BER for each data
        % written by Andi Soekartono, MSC Telecommunication
        % Date 06-May-2015
        mibBER(mcsIdx,SNR) = 1 - sum((fullMIB == fullRxMIB))/ size(fullMIB,1);       %#ok<SAGROW>
        cfiBER(mcsIdx,SNR) = 1 - sum((fullCFI == fullRxCFI))/ size(fullCFI,1);       %#ok<SAGROW>
        dciBER(mcsIdx,SNR) = 1 - sum((fullDCI == fullRxDCI))/ size(fullDCI,1);       %#ok<SAGROW>   
        dataBER(mcsIdx,SNR) = 1 - sum((fullData == fullRxData))/ size(fullData,1);   %#ok<SAGROW>
        cqi(mcsIdx,SNR) = mean(fullCQI);                                             %#ok<SAGROW>
        totalMessage(mcsIdx,SNR) = messageNumber;                                    %#ok<SAGROW>
        totalResend(mcsIdx,SNR) = messageResend;                                     %#ok<SAGROW>
        codeRate(mcsIdx) = sharedChannel(1).pdsch.codeRate;                          %#ok<SAGROW>
        modulation{mcsIdx} = sharedChannel(1).pdsch.Modulation;                      %#ok<SAGROW>
    end
end
% terminate waitbar UI
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

plotHARQ
plotBER