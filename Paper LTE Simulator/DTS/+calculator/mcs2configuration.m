function [modulation, itbs] = mcs2configuration(mcs)
% [modulation, itbs] = mcs2configuration(mcs)
% function to translate mcs value to modulation type and transport block size index
%   mcs         : modulation and coding scheme index 
%
%   modulation  : mdoulation type: "QPSK", "16QAM", or "64QAM"
%   itbs        : transport block size index  
%
% Matlab code written by Andi Soekartono, MSC Telecommunication
% Date 15-June-2015


% MCS configuration for C-RNTI scrambled DLSCH using DCI 'Format-1A'
% TS 36.213 V12.5.0 Table 7.1.7.1-1
mcsTable = [0	2	0;
            1	2	1;
            2	2	2;
            3	2	3;
            4	2	4;
            5	2	5;
            6	2	6;
            7	2	7;
            8	2	8;
            9	2	9;
            10	4	9;
            11	4	10;
            12	4	11;
            13	4	12;
            14	4	13;
            15	4	14;
            16	4	15;
            17	6	15;
            18	6	16;
            19	6	17;
            20	6	18;
            21	6	19;
            22	6	20;
            23	6	21;
            24	6	22;
            25	6	23;
            26	6	24;
            27	6	25;
            28	6	26];

% determine modualtion type        
switch mcsTable(mcs+1,2)
    case 2
        modulation = 'QPSK';
    case 4
        modulation = '16QAM';
    case 6
        modulation = '64QAM';
end

% determine tbs index
itbs = mcsTable(mcs + 1,3);


