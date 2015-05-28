function [ waveform ] = channel( waveform, varargin )
%[ waveform ] = channel( waveform, channel type, SNR, timeDomainInfo, antennaPort ) Summary of this function goes here
%   Detailed explanation goes here
%   Calculate noise gain
switch varargin{1}
    case 'AWGN'
        SNR = varargin {2};
        timeDomainInfo = varargin{3};
        antennaPort = varargin{4};
        mcs = varargin{5};
        [modulation, ~] = hMCSConfiguration(mcs);
        switch modulation
            case 'QPSK'
                modOrder = 2;
            case '16QAM'
                modOrder = 4;
            case '64QAM' 
                modOrder = 6;
        end
                
        
        N0 = 1/(sqrt(modOrder*2.0*antennaPort*double(timeDomainInfo.Nfft))*(10^(SNR/20)));
        
        % Create additive white Gaussian noise
        noise = N0*complex(randn(size(waveform)),randn(size(waveform)));
        
        % Add noise to the received time domain waveform
        waveform = waveform + noise;
    
   
    otherwise
        
end

