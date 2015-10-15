function [ mcsAlloc, tbsAlloc, rbAlloc, rbMap ] = rateAdaptation( enb, rbMap, cqi, bytesNum, varargin)
% [ mcsAlloc, tbsAlloc, rbAlloc, rbMap ] = rateAdaptation( enb, rbMap, cqi, bytesNum, calcFlag)
% function to perform channel dependant rate adaptation.
%  enb      : eNodeB parameter
%  rbMap    : available resource block map, 1 X NDLRB vector of [0 and 1]
%               0 for free RB and 1 for occupied RB
%  cqi      : channel quality index
%  bytesNum : MAC pdu size in bytes
%  calcFlag : calculation flag (used by PF scheduler to determine RB capacity
%
%  mcsAlloc : allocated modulation and coding scheme
%  tbsAlloc : allocated transport block size
%  rbAlloc  : allocated resource block, 1 x2 vector of [ RB-start RB-length ]
%  rbMap    : updated available resource block map
%
% Matlab code written by Andi Soekartono, MSC Telecommunication
% Date 15-June-2015

%% CQI rate adaptation mapping
% based on Table 7.2.3-1: 4-bit CQI Table TS 36.213
cqiMap = [0   0   0   0;
    1	2	78	0.1523;
    2	2	120	0.2344;
    3	2	193	0.3770;
    4	2	308	0.6016;
    5	2	449	0.8770;
    6	2	602	1.1758;
    7	4	378	1.4766;
    8	4	490	1.9141;
    9	4	616	2.4063;
    10	6	466	2.7305;
    11	6	567	3.3223;
    12	6	666	3.9023;
    13	6	772	4.5234;
    14	6	873	5.1152;
    15	6	948	5.5547];

% Modulation order and effective code rate determination
modOrder = cqiMap(cqi+1,2);
maxCodeRate = double(cqiMap(cqi+1,3))/1024.0;

% find available resource block
availRB = find(rbMap == 0);
startRB = availRB(1) - 1;

% resource allocation iteration initialization
numRB = 0;
tbs = 0;

% search transport block size that can carry pdu bytes
while tbs < bytesNum * 8 
    mcsAlloc = [];
    
    % if calcFlag set, increase RB by 2 this necessary to give PF scheduler
    % score correct value due to anomaly in tbs table in TS 36.312
    if isempty(varargin)
        numRB = numRB + 1;
    else
        numRB = numRB + 2;
    end
    
    amcs = [];
    atbs = 0;
    
    % if required RB greater than available RB, retrun empty allocation
    if numRB > length(availRB)
        tbsAlloc = [];
        rbAlloc = [];
        return
    end
    
    % Determine modulation type
    switch modOrder
        case 2
            mcs = 0:9;
            modulation = 'QPSK';
        case 4
            mcs = 10:16;
            modulation = '16QAM';
        case 6
            mcs = 17:28;
            modulation = '64QAM';
    end
    
     % Matlab LTE Toolbox to get avaiable PDSCH bit
    [ ~, pdschInfo] = ltePDSCHIndices(enb, struct('Modulation', modulation),(startRB : (startRB + numRB-1)).');
    
    % iterate mcs to get desired effective code rate
    for imcs = mcs
        % get tbs for current mcs
        [ ~, itbs] = calculator.mcs2configuration(imcs);
        tbs = lteTBS(numRB,itbs);
        
        % test code rate
        if (double(tbs)/double(pdschInfo.G)) > maxCodeRate
            if numRB < availRB
                tbs = atbs;
            else
                amcs = [];
            end
            break
        end
        amcs = imcs;
        atbs = tbs;
        
        % if TBS is able to carry pdu bytes finish iteration
        if tbs > bytesNum * 8 && isempty(varargin)
            break
        end
    end
    
end

% return resource allocation
if ~isempty(amcs)
    mcsAlloc = amcs;
    tbsAlloc = atbs;
else
    mcsAlloc = imcs;
    tbsAlloc = tbs;
end
rbAlloc = [startRB numRB];
rbMap((startRB + 1): (startRB + numRB)) = 1;








end

