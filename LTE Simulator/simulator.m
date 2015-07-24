classdef simulator < handle
    % simulator class to simulate lte cross layer MAC and PHY
    %
    % Provide function of sdu packet generation, lte downlink transmission
    % and operation that follows
    %
    % THis simualtion is bound to single eNodeB serving multiple UE
    %
    % Matlab code written by Andi Soekartono, MSC Telecommunication
    % Date 15-June-2015
    
    properties
        enbPHY                              % physical ENB container
        ueDatabase = model.lteUE.empty;     % logical UE container
        uePHY = lteUEPhysical.empty;        % physical UE container
        event = model.simEvent.empty;       % simualtion event container
        sduList = model.lteMACsdu.empty;    % MAC Layer sdu buffer
        channel                             % lte fading channel container
        scheduler                           % lte MAC scheduler container
        schedulerType                       % lte MAC scheduler type
        time                                % current time
        simTime                             % total simulated time
        ttiCount                            % TTI clock counter
        packetGenerator                     % packet generator parameter
        gui                                 % result GUI container
    end
    
    methods
        %%
        function obj = simulator(enb, ueNo, scheduler, packetGenerator, simulationTime)
            % simulator constructor
            %   obj = simulator(enb, ueNo, scheduler, packetGenerator, simulationTime)
            %       enb               : lteENBPhysical object
            %       ueNo              : UE number
            %       scheduler         : lteRRscheduler, ltePFscheduler or lteMAXCIscheduler object
            %       packetGenerator   : struct of packet generation parameter
            %           packetGenerator.lamda : inter-arrival time
            %       simualtionTime    : total simualtion time length
            %
            
            
            % store eNodeB object
            obj.enbPHY = enb;
            
            % build UE database according specified UE number
            for i = 1:ueNo
                % generate logical UE
                obj.ueDatabase(i) = model.lteUE(obj.enbPHY.enb, 100 * i, 1 * i);
                % generate physical UE
                obj.uePHY(i) = lteUEPhysical(obj.enbPHY.enb, obj.ueDatabase(i).ue);
                % assign UE channel condition (in SNR dB)
                
                %obj.uePHY(i).channelSNR = randi([6 15]);
                obj.uePHY(i).channelSNR = 14;
            end
            
            % built lte channel and set initial random seed
            obj.channel = model.lteTransmissionChannel;
%             obj.channel.additiveNoise = 'false';
%             obj.channel.fadingChannel = 'false';
            obj.channel.setSeed(1,1);
            
            % store scheduler object and type
            obj.scheduler = scheduler;
            schType = whos('scheduler');
            obj.schedulerType = schType.class;
            
            % store packet generator and simualtion time parameter
            obj.packetGenerator = packetGenerator;
            obj.simTime = simulationTime;
            
            %% event generation
            % insert packet for all UE
            for j = 1:ueNo
                eventTime = 0;
                while eventTime < obj.simTime
                    %interArrivalTime =poissrnd(obj.packetGenerator.lamda)/1000000;
                    
                    % determine next arrival time
                    interArrivalTime = exprnd(obj.packetGenerator.lamda)/1000000;
                    eventTime = eventTime + interArrivalTime;
                    % generate UE spesific SDU with 100 bytes size
                    sdu = model.lteMACsdu(obj.ueDatabase(j).rnti, randi([0 1],1000,1));
                    % create sim event with 'packet' as type
                    packet = model.simEvent(eventTime,'packet', sdu);
                    % update time counter
                    packet.eventObject.arrival_time = eventTime;
                    packet.eventObject.interArrival_time = interArrivalTime;
                    % store sdu and event object
                    obj.sduList(length(obj.sduList) + 1) = sdu;
                    obj.event(length(obj.event) + 1) = packet;
                end
            end
            % insert TTI
            
            % TTI event occurs every 1 ms
            for k = 0:0.001:obj.simTime
                % create sim event with 'TTI' as type
                tti = model.simEvent(k,'TTI',[]);
                % store event object
                obj.event(length(obj.event) + 1) = tti;
            end
            
            % sorting events by event time
            [~, idx] = sort([obj.event.eventTime]);
            obj.event = obj.event(idx);
            
            % sorting SDUs by event time
            [~, idx] = sort([obj.sduList.arrival_time]);
            obj.sduList = obj.sduList(idx);
            
        end
        
        %%
        function [] = run(obj)
            % method to perform LTE simulation
            %   obj.run
            %
            
            % initalization
            obj.ttiCount = 0;
            obj.updateGUI([]);
            
            % execute all event chronologically
            for i = 1:length(obj.event)
                if isequal(obj.event(i).eventType,'packet')
                    % if event is packet, add to MAC sdu buffer
                    obj.scheduler.addSDU(obj.ueDatabase,obj.event(i).eventObject);
                    
                else
                    % if event is TTI, do lte PHY layer transmission
                    disp('========================================')
                    disp(['time ',num2str(double(obj.ttiCount)*0.001),' s'])
                    
                    if obj.ttiCount == 64
                        bug = 1;
                    end
                    
                    % schedule resource for this TTI
                    [tb, ue] = obj.scheduler.schedule(obj.enbPHY.enb);
                    
                    % insert scheduled ue monitoring and transport block
                    obj.enbPHY.insertUE(ue);
                    obj.enbPHY.insertTransportBlock(tb);
                    
                    % downlink transmission
                    downlinkSignal = obj.enbPHY.transmit();
                    
                    % UE receive and transmit
                    for j = 1:length(obj.uePHY)
                        % set radio condition for spesific user
                        obj.channel.snr = obj.uePHY(j).channelSNR;
                        % downlink reception
                        obj.uePHY(j).receive(obj.channel.perform(downlinkSignal, obj.enbPHY.enb), obj.sduList ...
                            , ~isempty(findobj(tb,'rnti',obj.uePHY(j).ue.RNTI)));
                        
                        % uplink transmission
                        uplinkSignal = obj.uePHY(j).transmit;
                        
                        % uplink signal combining for all UE
                        if j == 1
                            uplinkSignalTotal = uplinkSignal;
                        else
                            uplinkSignalTotal.signal = uplinkSignalTotal.signal + uplinkSignal.signal;
                        end
                        
                        % update UE TTI clock
                        obj.uePHY(j).tick;
                    end
                    
                    % ENB receiver
                    obj.enbPHY.receive(obj.channel.perform(uplinkSignalTotal,obj.enbPHY.enb));
                    
                    % update PHY enb TTI clock
                    obj.enbPHY.tick;
                    
                    % update clock
                    obj.ttiCount = obj.ttiCount + 1;
                end
                
                % update GUI
                obj.updateGUI(obj.event(i).eventType, i)
                
            end
        end
        
        %%
        function [] =  updateGUI(obj, type, varargin)
            % method to update GUI during simulation
            %   obj.updateGUI(type, eventIds)
            %       type        : event type 'packet' or 'TTI'
            %       eventIdx    : event index in event register
            %
            %  if empty parameter is given this method will reset GUI
            %
            
            
            if isempty(type)
                obj.gui.screen = get(0, 'MonitorPositions');
                % Event figure
                obj.gui.simEv.Fig = figure('Name',['Simulation Event Window (',obj.schedulerType,')'], 'NumberTitle', 'off');
                obj.gui.simEv.Axes = axes('Parent', obj.gui.simEv.Fig);
                xlabel('Simulation time (s)');
                obj.gui.simEv.TxPacket = text(0, 1, 'Packet Arrival', 'Color', calculator.colorMap('white'), 'BackgroundColor', ...
                    calculator.colorMap('midgreen'), 'VerticalAlignment', 'top');
                obj.gui.simEv.TxTti = text(0, 2,'TTI', 'Color', calculator.colorMap('white'), 'BackgroundColor', calculator.colorMap('midred'), 'VerticalAlignment', 'top');
                
                % Packet arrival rate (CCDF) figure
                obj.gui.simIntArrCCDF.Fig = figure('Name','Arrival Rate (CCDF)', 'NumberTitle', 'off');
                obj.gui.simIntArrCCDF.Axes = axes('Parent', obj.gui.simIntArrCCDF.Fig);
                obj.gui.simIntArrCCDF.hPlot = plot(0, 0, 'Color', calculator.colorMap('brightblue'), 'LineWidth', 2);
                set(obj.gui.simIntArrCCDF.Axes, 'YScale', 'log');
                xlabel('Arrival Rate (packet/s)');
                ylabel('CCDF');
                obj.gui.simIntArrCCDF.hText = text('Position',[0 , 0 , 0], 'Parent', obj.gui.simIntArrCCDF.Axes, ...
                        'String', '', 'Color', calculator.colorMap('white'), 'BackgroundColor', calculator.colorMap('midred'));
                obj.gui.simIntArrCCDF.hLine = line([0, 0], [0,0] , 'Parent', obj.gui.simIntArrCCDF.Axes, ...
                    'Color', calculator.colorMap('midred'), 'LineWidth', 2); 
                
                % MAC end to end packet delay (CCDF) figure
                obj.gui.simMacDelayCCDF.Fig = figure('Name','Packet Delay (CCDF)', 'NumberTitle', 'off');
                obj.gui.simMacDelayCCDF.Axes = axes('Parent', obj.gui.simMacDelayCCDF.Fig);
                obj.gui.simMacDelayCCDF.hPlot = plot(0, 0, 'Color', calculator.colorMap('brightblue'), 'LineWidth', 2);
                set(obj.gui.simMacDelayCCDF.Axes, 'YScale', 'log');
                xlabel('Delay (s)');
                ylabel('CCDF');
                obj.gui.simMacDelayCCDF.hText = text('Position',[0 , 0 , 0], 'Parent', obj.gui.simMacDelayCCDF.Axes, ...
                        'String', '', 'Color', calculator.colorMap('white'), 'BackgroundColor', calculator.colorMap('midred'));
                obj.gui.simMacDelayCCDF.hLine = line([0, 0], [0,0] , 'Parent', obj.gui.simMacDelayCCDF.Axes, ...
                    'Color', calculator.colorMap('midred'), 'LineWidth', 2); 
                
                % Buffer CCDF figure
                obj.gui.simMacBufferCCDF.Fig = figure('Name','MAC Buffer State (CCDF)', 'NumberTitle', 'off');
                obj.gui.simMacBufferCCDF.Axes = axes('Parent', obj.gui.simMacBufferCCDF.Fig);
                obj.gui.simMacBufferCCDF.hPlot = plot(0, 0, 'Color', calculator.colorMap('brightblue'), 'LineWidth', 2);
                set(obj.gui.simMacBufferCCDF.Axes, 'YScale', 'log');
                xlabel('Buffer size (bytes)');
                ylabel('CCDF');
                obj.gui.simMacBufferCCDF.hText = text('Position',[0 , 0 , 0], 'Parent', obj.gui.simMacBufferCCDF.Axes,...
                    'String', '', 'Color', calculator.colorMap('white'), 'BackgroundColor', calculator.colorMap('midred'));
                obj.gui.simMacBufferCCDF.hLine = line([0, 0], [0,0] , 'Parent', obj.gui.simMacBufferCCDF.Axes, ...
                    'Color', calculator.colorMap('midred'), 'LineWidth', 2);
                   
                
                
                % Delay and buffer state figure
                obj.gui.simDelayVsBuffer.Fig = figure('Name','Delay and buffer in time series', 'NumberTitle', 'off');
                obj.gui.simDelayVsBuffer.Axes = axes('Parent', obj.gui.simDelayVsBuffer.Fig);
                [obj.gui.simDelayVsBuffer.yAxes, obj.gui.simDelayVsBuffer.delayGraph, obj.gui.simDelayVsBuffer.bufferGraph] = ...
                    plotyy(0, 0, 0, 0, 'plot', 'plot');
                
                set(obj.gui.simDelayVsBuffer.delayGraph, 'Color', calculator.colorMap('midred'), 'LineWidth', 2);
                set(obj.gui.simDelayVsBuffer.bufferGraph, 'Color', calculator.colorMap('midgreen'), 'LineWidth', 2);
                set(obj.gui.simDelayVsBuffer.yAxes(1), 'YColor', calculator.colorMap('midred'));
                set(obj.gui.simDelayVsBuffer.yAxes(2), 'YColor', calculator.colorMap('midgreen'));
                ylabel(obj.gui.simDelayVsBuffer.yAxes(1),'Delay (ms)');
                ylabel(obj.gui.simDelayVsBuffer.yAxes(2),'Buffer size (bytes)');
                set(obj.gui.simDelayVsBuffer.Axes, 'XLabel', text('String','Simulation time (s)'), 'Box', 'On');
                                
                % UE delay CCDF figure
                obj.gui.simUEdelayCCDF.Fig = figure('Name','UE Packet Delay (CCDF)', 'NumberTitle', 'off');
                obj.gui.simUEdelayCCDF.Axes = axes('Parent', obj.gui.simUEdelayCCDF.Fig);
                obj.gui.simUEdelayCCDF.Label{1} = get(obj.gui.simUEdelayCCDF.Axes, 'XLabel');
                obj.gui.simUEdelayCCDF.Label{2} = get(obj.gui.simUEdelayCCDF.Axes, 'YLabel');
                
                
                axes(obj.gui.simEv.Axes);
            else
                i = varargin{1};
                if isequal(type, 'packet')
                    
                    % Event figure
                    hold(obj.gui.simEv.Axes, 'on')
                    plot(obj.gui.simEv.Axes, obj.event(i).eventTime, 1, 'Marker', 'o', 'MarkerEdgeColor', calculator.colorMap('midgreen'),...
                        'MarkerFaceColor', calculator.colorMap('midgreen'));
                    set(obj.gui.simEv.TxPacket, 'Position', [obj.event(i).eventTime + 0.001  1]);
                    hold(obj.gui.simEv.Axes, 'off')
                    
                else
                    % Event figure
                    hold(obj.gui.simEv.Axes, 'on')
                    plot(obj.gui.simEv.Axes, obj.event(i).eventTime, 2, 'Marker', 'o', 'MarkerEdgeColor', calculator.colorMap('midred'),...
                        'MarkerFaceColor', calculator.colorMap('midred'));
                    set(obj.gui.simEv.TxTti,'Position',[obj.event(i).eventTime + 0.002  2]);
                    hold(obj.gui.simEv.Axes, 'off')
                    
                    deliveredSDU = findobj(obj.sduList,'-not','delayENB_time','');
                    queuedSDU = findobj(obj.sduList,'-not','status','');
                    throughput = length(deliveredSDU) * 800 / ((obj.ttiCount - 1) * 0.001) / 1024 /1024;
                    delay = mean([deliveredSDU.delayENB_time]);
                    set(get(obj.gui.simEv.Axes, 'Title'), 'String', ['avg Throughput ', num2str(throughput), ' Mbps ; avg delay ',...
                        num2str(delay*1000), ' ms']);
                    
                    if obj.ttiCount < 10
                        simEvXLim = [0 0.015];
                    else
                        simEvXLim = [(obj.ttiCount - 10) (obj.ttiCount + 5)]/1000;
                        range = (obj.ttiCount - 10) : (obj.ttiCount + 5);
                        simEvXTick = range(mod(range,5) == 0)/1000;
                        simEvXTickLabel = textscan(num2str(simEvXTick,'%10.3f' ),'%s').';
                        set(obj.gui.simEv.Axes,'XTick',simEvXTick,'XTickLabel',simEvXTickLabel{1,1});
                        
                    end

                    set(obj.gui.simEv.Axes,'Box','on','YTick',[],'YTickLabel',{' '},'YLim',[0 3],'Xlim', simEvXLim)
                    
                    
                    % Buffer figure
                    bufferState = obj.scheduler.sduBufferState;
                    bufferState = sum(bufferState,2) / 8;
                    averageBufferSize = mean(bufferState(:,:,2));
                    if ~isempty(bufferState)
                        [f,x] = ecdf(bufferState(:,:,2));
                        f = 1 - f;
                    else
                        f = 0;
                        x = 0;
                    end
                    set(obj.gui.simMacBufferCCDF.hPlot,'YData',f,'XData',x);
                    xlim = get(obj.gui.simMacBufferCCDF.Axes,'XLim');
                    set(obj.gui.simMacBufferCCDF.hText, 'Position',[(averageBufferSize + (xlim(2) - averageBufferSize) / 10), 0.5 , 0],...
                        'String', ['Average buffer size ',num2str((averageBufferSize),'%6.0f'),' byte']);
                    set(obj.gui.simMacBufferCCDF.hLine, 'YData', get(obj.gui.simMacBufferCCDF.Axes,'YLim'), 'XData',[averageBufferSize, averageBufferSize]);
                    
                    % Delay CCDF Figure
                    if ~isempty([deliveredSDU.delayENB_time])
                        [f,x] = ecdf([deliveredSDU.delayENB_time]);
                        f = 1 - f;
                    else
                        f = 0;
                        x = 0;
                    end
                    set(obj.gui.simMacDelayCCDF.hPlot,'YData',f,'XData',x);
                    xlim = get(obj.gui.simMacDelayCCDF.Axes,'XLim');
                    set(obj.gui.simMacDelayCCDF.hText, 'Position',[(delay + (xlim(2) - delay) / 10), 0.5 , 0],...
                        'String',  ['Average delay ', num2str((delay * 1000),'%6.3f'),' ms']);
                    set(obj.gui.simMacDelayCCDF.hLine, 'YData', get(obj.gui.simMacDelayCCDF.Axes,'YLim'), 'XData', [delay, delay]);
                    
                    % Arrival Rate CCDF Figure
                    arrivalRate = 1 ./ [queuedSDU.interArrival_time];
                    avgArrivalRate = 1 / mean([queuedSDU.interArrival_time]);
                    if ~isempty(arrivalRate)
                        [f,x] = ecdf(arrivalRate);
                        f = 1 - f;
                    else
                        f = 0;
                        x = 0;
                    end
                    set(obj.gui.simIntArrCCDF.hPlot,'YData',f,'XData',x);
                    xlim = get(obj.gui.simIntArrCCDF.Axes,'XLim');
                    set(obj.gui.simIntArrCCDF.hText, 'Position',[(avgArrivalRate + (xlim(2) - avgArrivalRate) / 10), 0.5 , 0],...
                        'String',  ['Average arrival rate ', num2str((avgArrivalRate),'%6.0f'),' packet/s']);
                    set(obj.gui.simIntArrCCDF.hLine, 'YData', get(obj.gui.simIntArrCCDF.Axes,'YLim'), 'XData', [avgArrivalRate, avgArrivalRate]);
                    
                    

                    
                    % Delay and buffer state Figure
                    if isempty(deliveredSDU)
                        arrTime = 0;
                        delTime = 0;
                    else
                        arrTime = [deliveredSDU.arrival_time];
                        delTime = [deliveredSDU.delayENB_time] * 1000;
                    end
                    buffState = bufferState(:,:,2);
                    buffTime = ((0:size(bufferState,1)-1)*0.001);
                    
                    set(obj.gui.simDelayVsBuffer.delayGraph, 'YData', delTime , 'XData', arrTime);
                    set(obj.gui.simDelayVsBuffer.bufferGraph, 'YData', buffState, 'XData', buffTime);
                    set(obj.gui.simDelayVsBuffer.yAxes(1), 'XLim',[min([arrTime, buffTime]) max([arrTime, buffTime] + 0.01)],...
                        'YLimMode', 'Auto', 'YTickMode', 'Auto', 'Box', 'Off');
                    set(obj.gui.simDelayVsBuffer.yAxes(2), 'XLim',[min([arrTime, buffTime]) max([arrTime, buffTime] + 0.01)],... 
                        'YLimMode', 'Auto', 'YTickMode', 'Auto', 'Box', 'Off');

                    % UE Delay CCDF Figure
                    cla(obj.gui.simUEdelayCCDF.Axes)
                    hold(obj.gui.simUEdelayCCDF.Axes, 'on')
                    for k = 1:length(obj.ueDatabase)
                        ueSDU = findobj(deliveredSDU,'rnti', obj.ueDatabase(k).rnti);
                        if ~isempty([ueSDU.delayENB_time])
                            [f,x] = ecdf([ueSDU.delayENB_time]);
                            f = 1 - f;
                        else
                            f = 0;
                            x = 0;
                        end
                        plot(obj.gui.simUEdelayCCDF.Axes, x, f, 'Color', calculator.colorMap(k), 'LineWidth', 2);
                        legendText{k} = ['UE', num2str(k)]; %#ok<AGROW>
                    end
                    legend(obj.gui.simUEdelayCCDF.Axes, legendText, 'Location', 'EastOutside');
                    hold(obj.gui.simUEdelayCCDF.Axes, 'off');
                    set(obj.gui.simUEdelayCCDF.Axes, 'YScale', 'log', 'Box', 'On');
                    set(obj.gui.simUEdelayCCDF.Label{1}, 'String','Delay (s)');
                    set(obj.gui.simUEdelayCCDF.Label{2}, 'String', 'CCDF');
                    
                end
                
            end
            drawnow
            
        end
        
    end
    
end



