function [ waveform ] = channel( waveform, varargin )
%[ waveform ] = channel( waveform, channel type, SNR, timeDomainInfo, antennaPort ) Summary of this function goes here
%   Detailed explanation goes here
%   Calculate noise gain
switch varargin{1}
    case 'AWGN'
        SNR = varargin {2};
        timeDomainInfo = varargin{3};
        antennaPort = varargin{4};
        
        N0 = 1/(sqrt(2.0*antennaPort*double(timeDomainInfo.Nfft))*(10^(SNR/20)));
        
        % Create additive white Gaussian noise
        noise = N0*complex(randn(size(waveform)),randn(size(waveform)));
        
        % Add noise to the received time domain waveform
        waveform = waveform + noise;
    
    otherwise
        
end

