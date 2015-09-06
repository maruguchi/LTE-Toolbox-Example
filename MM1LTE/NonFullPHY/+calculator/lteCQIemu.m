classdef lteCQIemu < handle
    %LTECQISELECT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        pdfSampler = calculator.PDFsampler.empty;
        filename = '+calculator/snirs.mat';
    end
    
    methods
        function obj = lteCQIemu(awgnSNR)
            snir = load(obj.filename,'snirsMap');
            snirs = snir.snirsMap{awgnSNR + 1};
            obj.pdfSampler = calculator.PDFsampler(snirs);
        end
        function cqiVal = getCQI(obj)
            effsinr = obj.pdfSampler.nextRandom;
            SINRs90pc = polyval([2.11 -9.24],[2 2:15]); 
            cqiVal = find(SINRs90pc<effsinr,1,'last') - 1;
            if (isempty(cqiVal))
                cqiVal = 0;
            end
        end
        
        
    end
    
end

