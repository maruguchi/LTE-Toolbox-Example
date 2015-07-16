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
                obj.uePHY(i).channelSNR = randi([8 15]);
            end
            
            % built lte channel and set initial random seed
            obj.channel = model.lteTransmissionChannel;
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
                    sdu = model.lteMACsdu(obj.ueDatabase(j).rnti, randi([0 1],800,1));
                    % create sim event with 'packet' as type
                    packet = model.simEvent(eventTime,'packet', sdu);
                    % update time counter
                    packet.eventObject.create_time = eventTime;
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
%                 obj.gui.simEv.Fig = figure('Name',['Simulation Event Window (',obj.schedulerType,')'], 'NumberTitle', 'off', 'OuterPosition',...
%                     [ceil((obj.gui.screen(3)-obj.gui.screen(3)/4)/2) ceil((obj.gui.screen(4) - 180)/2) obj.gui.screen(3)/4 180],...
%                     'MenuBar', 'none');
                obj.gui.simEv.Fig = figure('Name',['Simulation Event Window (',obj.schedulerType,')'], 'NumberTitle', 'off');
                obj.gui.simEv.Axes = axes('Parent', obj.gui.simEv.Fig);
                obj.gui.simEv.TxPacket = text(0, 1, 'Packet Arrival', 'Color', calculator.colorMap('white'), 'BackgroundColor', ...
                    calculator.colorMap('midgreen'), 'VerticalAlignment', 'top');
                obj.gui.simEv.TxTti = text(0, 2,'TTI', 'Color', calculator.colorMap('white'), 'BackgroundColor', calculator.colorMap('midred'), 'VerticalAlignment', 'top');
                
                % Packet inter arrival figure
%                 obj.gui.simIntArr.Fig = figure('Name','Inter arrival time', 'NumberTitle', 'off', 'OuterPosition',...
%                     [ceil((obj.gui.screen(3)-obj.gui.screen(3)/4)) ceil((obj.gui.screen(4) - obj.gui.screen(4)/3)) obj.gui.screen(3)/4 obj.gui.screen(4)/3],...
%                     'MenuBar', 'none');
                obj.gui.simIntArr.Fig = figure('Name','Inter arrival time', 'NumberTitle', 'off');
                obj.gui.simIntArr.Axes = axes('Parent', obj.gui.simIntArr.Fig);
                hist(obj.gui.simIntArr.Axes, [obj.sduList.interArrival_time], 20);
                h = findobj(gca,'Type','patch');
                set(h,'FaceColor', calculator.colorMap('orange'), 'EdgeColor', calculator.colorMap('white'));
                set(obj.gui.simIntArr.Axes,'XLabel',text('String','inter arrival time (s)'))

                % MAC end to end packet delay figure
%                 obj.gui.simMacDelay.Fig = figure('Name','Packet Delay', 'NumberTitle', 'off', 'OuterPosition',...
%                     [ceil((obj.gui.screen(3)-obj.gui.screen(3)/4)) ceil((obj.gui.screen(4) - obj.gui.screen(4)*2/3)) obj.gui.screen(3)/4 obj.gui.screen(4)/3],...
%                     'MenuBar', 'none');
                obj.gui.simMacDelay.Fig = figure('Name','Packet Delay', 'NumberTitle', 'off');
                obj.gui.simMacDelay.Axes = axes('Parent', obj.gui.simMacDelay.Fig);
                
                
                % Buffer Figure
                
                
                
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
                    axes(obj.gui.simEv.Axes)
                    deliveredSDU = findobj(obj.sduList,'status','delivered');
                    throughput = length(deliveredSDU) * 800 / ((obj.ttiCount - 1) * 0.001) / 1024 /1024;
                    delay = mean([deliveredSDU.queue_time]);
                    set(obj.gui.simEv.Axes, 'Title', text('String', ['avg Throughput ', num2str(throughput), ' Mbps ; avg delay ',...
                         num2str(delay*1000), ' ms']));
                    
                    if obj.ttiCount < 10
                        simEvXLim = [0 0.015];
                    else
                        simEvXLim = [(obj.ttiCount - 10) (obj.ttiCount + 5)]/1000;
                        range = (obj.ttiCount - 10) : (obj.ttiCount + 5);
                        simEvXTick = range(mod(range,5) == 0)/1000;
                        simEvXTickLabel = textscan(num2str(simEvXTick,'%10.3f' ),'%s').';
                        set(obj.gui.simEv.Axes,'XTick',simEvXTick,'XTickLabel',simEvXTickLabel{1,1});
                        
                    end
                    set(obj.gui.simEv.Axes,'Box','on','YTick',[],'YTickLabel',{' '},'XLabel',...
                        text('String','Simulation time (s)'),'YLim',[0 3],'Xlim', simEvXLim)
                    
                    % Delay Figure
                    axes(obj.gui.simMacDelay.Axes)
                    hist(obj.gui.simMacDelay.Axes, [deliveredSDU.queue_time], 20);
                    h = findobj(gca,'Type','patch');
                    set(h,'FaceColor', calculator.colorMap('lightpurple'), 'EdgeColor', calculator.colorMap('white'));
                    set(obj.gui.simMacDelay.Axes,'XLabel',text('String','delay (s)'))
                    
                end

            end
            drawnow
            
        end
        
    end
    
end



