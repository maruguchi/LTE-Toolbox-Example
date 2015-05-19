function [ sharedChannel, hARQCache ] = eNBMAC( enb, hARQCache,hARQFeedback, mcs)
%ENBMAC Summary of this function goes here
%   Detailed explanation goes here
    if size(hARQCache,2) < 8
        
[sharedChannel(1) userChannel(1)] = sharedChannelBuilder(enb,'Downlink-DTCH',2,100,0,100,mcs,0);
    end
end

