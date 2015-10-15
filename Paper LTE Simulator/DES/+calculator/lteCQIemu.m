classdef lteCQIemu < handle
    % lteCQIemu class to emulate CQI value under certain channel condition
    % Matlab code written by Andi Soekartono, MSC Telecommunication
    % Date 1-September-2015
    
    properties
        pdfSampler = calculator.PDFsampler.empty;      % create pdf sample class
        filename = '+calculator/snirs.mat';            % SNIR distribution file
    end
    
    methods
        function obj = lteCQIemu(awgnSNR)
            % CQI emulator constructor
            %   obj = lteCQIemu()
            %    
            
            % load SNIR distribution
            snir = load(obj.filename,'snirsMap');
            snirs = snir.snirsMap{awgnSNR + 1};
            
            % create pdf for the SNIR
            obj.pdfSampler = calculator.PDFsampler(snirs);
        end
        function cqiVal = getCQI(obj)
            % generate CQI value 
            %   cqi = obj.getCQI();
            %
            %   cqi : cqi value
            
            % generate snir for current TTI
            effsinr = obj.pdfSampler.nextRandom;
            % SINR to CQI mapping
            SINRs90pc = polyval([2.11 -9.24],[2 2:15]); 
            cqiVal = find(SINRs90pc<effsinr,1,'last') - 1;
            if (isempty(cqiVal))
                cqiVal = 0;
            end
        end
        
        
    end
    
end

