classdef lteTransmissionChannel < handle
    % lteTransmissionChannel class to simulate lte radio channel
    %
    % Provide function of perform fading and noise addition to LTE time
    % domain waveform
    %
    % Matlab code written by Andi Soekartono, MSC Telecommunication
    % Date 15-June-2015
    
    properties
        fadingChannel ;             % fading channel toggle
        additiveNoise ;             % AWGN channel toggle
        chCfg = struct;             % fading channel configuration
        snr ;                       % AWGN signal to noise ratio
    end
    
    methods
        %%
        function obj = lteTransmissionChannel()
            % Radio channel constructor
            %   obj = lteTransmissionChannel()
            %     
            
            % LTE radio channel (fading channel) default parameter setting
            obj.chCfg.DelayProfile = 'EPA';         % LTE standarized delay profile, eg: 'EPA', 'ETU' and 'EVA'
            obj.chCfg.DopplerFreq = 5.0 ;           % Doppler Frequency in Hz
            obj.chCfg.NRxAnts = 1;                  % number of antenna in receiver
            obj.chCfg.Seed = 0;                     % random seed number
            obj.chCfg.MIMOCorrelation = 'Low';      
            obj.chCfg.InitPhase ='Random';
            obj.chCfg.ModelType = 'GMEDS' ;
            obj.chCfg.NTerms = 16 ;
            obj.chCfg.NormalizeTxAnts = 'On';
            obj.chCfg.NormalizePathGains = 'On';
            obj.chCfg.InitTime = 0;                 % time which LTE signal transmitted
            % SNR default setting
            obj.snr = 8;
            % all performed as default
            obj.fadingChannel = 'true' ;
            obj.additiveNoise = 'true' ;
            
        end
        
        %%
        function [] = setSeed(obj, lteChannelSeed, awgnChannelSeed)
            % method to set random seed for LTE and AWGN channel
            %   obj.setSeed(lteChannelSeed, awgnChannelSeed)
            %       lteChannelSeed  : lte channel random seed
            %       awgnChannelSeed : awgn channel random seed
            
            % set seed parameter
            obj.chCfg.Seed = lteChannelSeed;    % fading channel
            rng(awgnChannelSeed);               % awgn channel
        end
        
        %%
        function outSignal = perform(obj,inSignal,enb)
            % method to peform channel transmission
            %   outSignal = obj.perform(inSignal,enb)
            %       inSignal    : signal before radio channel(struct of signal data and info)
            %       enb         : eNodeB parameters
            %       outSignal   : signal after radio channel(struct of signal data and info)
            
            % set appropriate sampling rate and time (based on frame and
            % subframe)
            obj.chCfg.SamplingRate = inSignal.info.SamplingRate;
            obj.chCfg.InitTime = (enb.NFrame * 1e-2) + (enb.NSubframe * 1e-3);
            
            % perform fading channel if enabled
            if strcmpi(obj.fadingChannel, 'true') ;
                % Matlab LTE Toolbox to peform fading channel to signal
                inSignal.signal = lteFadingChannel(obj.chCfg, inSignal.signal);
            end
            
            % add AWGN if enabled
            if strcmpi(obj.additiveNoise, 'true') ;
                % Calculate noise power
                N0 = 1/(sqrt(2.0*enb.CellRefP*double(inSignal.info.Nfft))*(10^(obj.snr/20)));
                % Create additive white Gaussian noise
                noise = N0 *complex(randn(size(inSignal.signal)),randn(size(inSignal.signal)));
                % Add noise to the received time domain waveform
                inSignal.signal = inSignal.signal + noise;
                
            end
            % return signal after radio channel
            outSignal = inSignal;
        end
        
    end
    
end

