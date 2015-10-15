classdef PDFsampler
    %PDFsampler is a class that allows to sample from a custom probability
    %distribution. This is particularly useful for Monte Carlo simulations
    %where one needs to sample from custom distributions.
    %
    % One may construct a PDFsampler object from available instances of a
    % distribution and may specify the number of bins to be used to
    % reconstruct that distribution function using its histogram. For
    % example:
    %
    %   y = randn(3e4,1); % vector with random numbers
    %   pdfs = PDFsampler(y);
    %   r = pdfs.nextRandom;
    %
    % will reconstruct the PDF of y based on the samples of y and using the
    % default number of 10 bins. Choosing the number of bins carefully is
    % instrumental for the performance of the sampler. You may modify the
    % number of bins using the following constructor:
    %
    %   nBins=30;
    %   pdfs = PDFsampler(y, nBins);
    %
    % See Also:
    % PDFsampler/nextRandom
    % PDFsampler/getNumData
    %
    % Author: Pantelis Sopasakis
    
    properties (Hidden=true)
        % xi and fi are the vectors that are generated by the function
        % [fi,xi]=hist(data) for some set of data instances and correspond
        % to the
        xi=[];
        fi=[];
        N=0;
        name='Custom Distribution';
        deltaX = 0;
        quartiles = [];
        nData=-1;
    end % END OF PROPERTIES
    
    properties(Constant=true)
        className='PDFSampler';
        defaultBins=10;
    end
    
    properties
        pdfName = 'Custom PDF';
    end
    
    methods
        function obj = PDFsampler(varargin)
            % Constructor of a PDF Sampler
            if (isempty(varargin))
                obj.nData=0;
                return;
            elseif (length(varargin)==1)
                data = varargin{1};
                obj.nData=length(data);
                obj.N=obj.defaultBins;
                [obj.fi,obj.xi]=hist(data, obj.N);
            elseif (length(varargin)==2)
                if (numel(varargin{2})==1 && numel(varargin{1}>1))
                    data = varargin{1};
                    obj.nData=length(data);
                    obj.N=varargin{2};
                    [obj.fi,obj.xi]=hist(data, obj.N);
                elseif (length(varargin{1})==length(varargin{2}))
                    obj.xi=varargin{1};
                    obj.fi=varargin{2};
                    obj.N=length(obj.xi);
                end
            end
            obj.fi=obj.fi/sum(obj.fi);
            obj.deltaX = obj.xi(2)-obj.xi(1);
            obj.quartiles = zeros(obj.N-1,1);
            obj.quartiles(1)=norminv(obj.fi(1),0,1);
            mySum = obj.fi(1);
            if (obj.N>=2)
                for i=2:obj.N
                    mySum = mySum + obj.fi(i);
                    obj.quartiles(i)=norminv(mySum,0,1);
                end
            end
            
        end %end of constructor method
        
        
        function x = nextRandom(obj)
            %NEXTRANDOM returns the next random number that follows this
            %custom probability distribution.
            %
            % Example of use:
            %
            %   % Define a vector with random sampled from the
            %   distribution:
            %   y = ...;
            %   pdfs = PDFsampler(y, 20);
            %   r = pdfs.nextRandom;
            %
            % Or you may use the equivalent syntax:
            %
            %   r = nextRandom(a);
            %            
            
            r = randn;
            if (r<obj.quartiles(1))
                x = (rand-0.50)*obj.deltaX + obj.xi(1);
                return;
            elseif (r>=obj.quartiles(end-1))
                x = (rand-0.50)*obj.deltaX + obj.xi(end);
                return;
            else
                for i=1:obj.N-1
                    if (r>=obj.quartiles(i) && r<obj.quartiles(i+1))
                        x = (rand-0.50)*obj.deltaX + obj.xi(i+1);
                        return;
                    end
                end
            end
        end % end of method 'nextRandom'
        
        
        function display(obj)
            disp(['PDF Sampler - Distribution: ' obj.pdfName]);
            disp('');
            disp(['Reconstructed PDF using ' num2str(obj.nData) ...
                ' data points and ' num2str(obj.N) ' bins.']);
            disp('');
        end % end of method 'display'
        
        function nData = getNumData(obj)
            %GETNUMDATA returns the number of data points used to reconstruct
            %this PDF, or -1 if not available.
            nData = obj.nData;
        end
        
    end % END OF ALL METHODS    
    
end