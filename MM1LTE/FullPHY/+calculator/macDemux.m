function [ sdu ] = macDemux( pdu )
% [ sdu ] = macDemux( pdu )
% function to perform MAC pdu demultiplexing into MAC sdu
%  pdu : pdu data bit
%
%  sdu : cell array of payload sdu bit
%

% Matlab code written by Andi Soekartono, MSC Telecommunication
% Date 15-June-2015

% find pdu header start and stop
pdu = pdu.';
headerStopIdx = find(bi2de(reshape(pdu,8,[]).','left-msb') == 31);
sduNo = (headerStopIdx(1) - 1) / 2;
headerStart = 0;
sduStart = sduNo*16 + 8;

% parse pdu into corresponding sdus
for i = 1 : sduNo
    % read sdu byte length
    byteLength = bi2de(pdu(headerStart + (10 : 16)),'left-msb');
    % store sdu bits
    sdu{i} = pdu(sduStart + (1 :  (byteLength * 8))).'; %#ok<AGROW>
    % next sdu information
    headerStart = 16 * i;
    sduStart = sduStart + (byteLength * 8);
end

end

