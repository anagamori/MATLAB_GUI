
function varargout = ForceTracking(varargin)
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @ForceTracking_OpeningFcn, ...
    'gui_OutputFcn',  @ForceTracking_OutputFcn, ...
    'gui_LayoutFcn',  [] , ...
    'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end

function ForceTracking_OpeningFcn(hObject, eventdata, handles, varargin)

cd ('C:\Users\cadaverProject\Desktop\Shoulder')
handles.output = hObject;
%% Access to trial information entered upon initialization of this gui
[basename,subjectCode,sampleRate] = trialInformation();

set(handles.subjectCodeEdit,'String',subjectCode);
set(hObject,'toolbar','figure');

%sampling frequency
set(handles.sampleRateEdit,'String',num2str(sampleRate));
handles.samplerate = str2double(get(handles.sampleRateEdit,'String'));
requested_samplerate = handles.samplerate;
%data collection duration
handles.Duration = str2double(get(handles.duration_edit,'String'));

%% initialization of parameters
handles.TOTALCH = 6;%for mcc use 1,2,3,4,5,6 (nidaq is 0-5)
handles.Index =0;

%MVC/calibration related
set(handles.MaxTag,'String',num2str(0));
set(handles.Offset_Value,'String',num2str(0));
set(handles.MVC_value,'String','0');
handles.mean_offset=0;

% JR3 Calibration
handles.CalibrationMatrix = [12.6690 0.2290 0.1050; 0.1600 13.2370 -0.3870; 1.084 0.6050 27.0920];

%force target related
set(handles.TargetForceLevel,'String',num2str(0));
set(handles.HoldDuration,'String',num2str(10));
handles.FORCEPLOTDURATION = str2double(get(handles.HoldDuration,'String'));
handles.feedback_style = 1;
handles.baseline_std = 1; 

%
set(handles.Feedback_HG,'Value',1);
set(handles.Feedback_LG,'Value',0);
set(handles.Feedback_Visual,'Value',1);
set(handles.Feedback_Auditory,'Value',0);
set(handles.Feedback_Continuous,'Value',1);
set(handles.Feedback_Discrete,'Value',0);
set(handles.TrackingChannel,'String',num2str(10));
handles.ChannelNumber = str2double(get(handles.TrackingChannel,'String'));

handles.Threshold = 0;
handles.LowerThreshold = 0;
handles.UpperThreshold = 0;

%stimulation/EMG related
set(handles.PulseInterval,'String',num2str(0));
set(handles.StimulationInterval,'String',num2str(1));
set(handles.Raw,'Value',1);


%% define input
handles.ChannelInfo = cell(13,3);
handles.ChannelInfo(1,:) = {'Force',0 10};
handles.ChannelInfo(2,:) = {'Force 2',1 10};
handles.ChannelInfo(3,:) = {'EMG1',2 10};
handles.ChannelInfo(4,:) = {'EMG2',3 10};
handles.ChannelInfo(5,:) = {'EMG3',4 10};
handles.ChannelInfo(6,:) = {'EMG4',5 10};
handles.ChannelInfo(7,:) = {'Trigger',6 10};
handles.ChannelInfo(8,:) = {'Force X',7 10};
handles.ChannelInfo(9,:) = {'Force Y',8 10};
handles.ChannelInfo(10,:) = {'Force Z',9 10};
handles.ChannelInfo(11,:) = {'Moment X',10 10};
handles.ChannelInfo(12,:) = {'Moment Y',11 10};
handles.ChannelInfo(13,:) = {'Moment Z',12 10};

figure('Name','Force')

ms_per_sample = 1000/handles.samplerate;
handles.N = round(50/ms_per_sample);

handles.ai = analoginput('nidaq','Dev2');
set(handles.ai,'InputType','SingleEnded');
hardwareChannel = cell2mat(handles.ChannelInfo(:,2));
addchannel(handles.ai,hardwareChannel);

set(handles.ai,'SampleRate',requested_samplerate);
actualAIRate = setverify(handles.ai,'SampleRate',requested_samplerate);
set(handles.ai,'SamplesPerTrigger',handles.samplerate*handles.Duration);
set(handles.ai,'SamplesAcquiredFcnCount',handles.N);
set(handles.ai,'SamplesAcquiredFcn',{@sample_acq_fcn,handles});
set(handles.ai,'LoggingMode','Disk&Memory');
fName = 'datatrial.daq';
handles.ai.LogFileName = fName;


%% define output
handles.ao = analogoutput('nidaq','Dev2');
addchannel(handles.ao,[0 1]);
output_samplerate = 10000;
setverify(handles.ao,'SampleRate',output_samplerate);
handles.OutputSampleRate = output_samplerate;

%% Set figure properties here
%set axis properties for force data
handles.LinePlotForce = line(0:1/handles.samplerate:(handles.samplerate*handles.Duration-1)/handles.samplerate,zeros(1,handles.samplerate*handles.Duration),'Parent',handles.ForcePlot,'Linewidth',2);
set(get(handles.LinePlotForce,'Parent'),'YLim',[0 250]);
set(get(handles.LinePlotForce,'Parent'),'XLim',[0 handles.Duration]);
%set(handles.LinePlotForce,'xlabel','Time(sec)','ylabel','Force')

%create a sperate figure for force tracking
handles.FIG2=gca(figure(1));
handles.FORCEPLOT2LINE1 =line([1:handles.samplerate*handles.FORCEPLOTDURATION],zeros(1,handles.samplerate*handles.FORCEPLOTDURATION),'Parent',handles.FIG2,'Color',[.7 .7 .7],'Linewidth',5);

%create a cursor for force tracking
handles.CURSOR2 = line([1],0,'Parent',handles.FIG2,'Linewidth',2,'Marker','o','MarkerEdgeColor',[0 0 0],'MarkerFaceColor',[0 0 0],'MarkerSize',14);
set(get(handles.CURSOR2,'Parent'),'YLim',[0 100]);
set(get(handles.CURSOR2,'Parent'),'XLim',[0 handles.Duration]);

% %set axis properties for EMG1 data
% handles.LinePlotEMG1 = line(0:handles.samplerate*handles.Duration,zeros(1,handles.samplerate*handles.Duration+1),'Parent',handles.EMG1Plot,'Linewidth',2);
% set(get(handles.LinePlotEMG1,'Parent'),'YLim',[-10 10]);
% set(get(handles.LinePlotEMG1,'Parent'),'XLim',[0 handles.Duration]);
% %set(handles.LinePlotEMG1,'xlabel','Time(sec)','ylabel','EMG')
%
% %set axis properties for EMG2 data
% handles.LinePlotEMG2 = line(0:handles.samplerate*handles.Duration,zeros(1,handles.samplerate*handles.Duration+1),'Parent',handles.EMG2Plot,'Linewidth',2);
% set(get(handles.LinePlotEMG2,'Parent'),'YLim',[-10 10]);
% set(get(handles.LinePlotEMG2,'Parent'),'XLim',[0 handles.Duration]);
% %set(handles.LinePlotEMG2,'xlabel','Time(sec)','ylabel','EMG')

%% Update handles structure
guidata(hObject,handles);


function StartDataCollection_CreateFcn(hObject, eventdata, handles)
% hObject    handle to StartDataCollection (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
guidata(hObject, handles);

function StartDataCollection_Callback(hObject, eventdata, handles)

%% modify sampling parameters based on inputs
handles.Duration = str2double(get(handles.duration_edit,'String'));
set(handles.ai,'SamplesPerTrigger',handles.samplerate*handles.Duration);
set(handles.ai,'SamplesAcquiredFcnCount',handles.N);
set(handles.ai,'SamplesAcquiredFcn',{@sample_acq_fcn,hObject});
% figure
set(handles.LinePlotForce,'xdata',0:1/handles.samplerate:(handles.samplerate*handles.Duration-1)/handles.samplerate,'ydata',zeros(1,handles.samplerate*handles.Duration),'Parent',handles.ForcePlot,'Linewidth',2);
set(get(handles.LinePlotForce,'Parent'),'XLim',[0 handles.Duration]);
set(handles.CURSOR2,'xdata',1,'ydata',0,'Parent',handles.FIG2,'Linewidth',2,'Marker','o','MarkerEdgeColor',[0 0 0],'MarkerFaceColor',[0 0 0],'MarkerSize',10);

%% initialization
handles.data = [];
handles.time = [];

%% Create output vector for stimulator
handles.OutputDuratinoInSamples = handles.OutputSampleRate*handles.Duration;
Stimulation_Vector = [];
Stimulation_Interval = str2double(get(handles.StimulationInterval,'String'))*handles.OutputSampleRate;
Pulse_Interval = str2double(get(handles.PulseInterval,'String'))/1000*handles.OutputSampleRate;

%
if get(handles.Single,'Value') == 1
    Stimulation_N = (handles.OutputDuratinoInSamples-1*handles.OutputSampleRate)./Stimulation_Interval-1;
    for i=1:Stimulation_N
        Stimulation_Vector = [Stimulation_Vector 4 zeros(1,Stimulation_Interval)];
    end
elseif get(handles.Double,'Value') == 1
    Stimulation_N = (handles.OutputDuratinoInSamples-1*handles.OutputSampleRate)./(Stimulation_Interval+Pulse_Interval)-1;
    for i=1:Stimulation_N
        Stimulation_Vector = [Stimulation_Vector 4 zeros(1,Pulse_Interval) 4 zeros(1,Stimulation_Interval)];
    end
end


%% set a channel used for MVC and tracking
handles.ChannelNumber = str2double(get(handles.TrackingChannel,'String'));

%% start data collection
% if input to MVC_value = 0, MVC trial will automatically start
% if there is a number in MVC_value, it will switch to force tracking
% trials

%--------------------------------------------------------------------------
% MVC trial
if strcmp(get(handles.MVC_value,'String'),'0');
    %reset ylim to display the entire range of force signal
    %currently set for interface force transducer
    %for biometrics force transducer, set ylim to [2 5]
    set(get(handles.LinePlotForce,'Parent'),'YLim',[0 150]);
    
    start(handles.ai);
    
    %start datalink
    pstatus = libpointer('int32Ptr',0);
    calllib('OnLineInterface','OnLineStatus',0,5,pstatus);
    
    wait(handles.ai,handles.Duration+10);
    stop(handles.ai);
    
    %start datalink
    calllib('OnLineInterface','OnLineStatus',0,6,pstatus);
    
    %store data
    %[data,time] = getdata(handles.ai);
    [data, time, absTime, events,daqInfo] = daqread('datatrial.daq');
    delete datatrial.daq
    
    data_temp = data;
    
    % calculate the baseline input voltage on channel for force
    % 1.5 sec prior to max
    
    % calculate max
    if handles.ChannelNumber == 10 % Z-Force
        forceJR3_rawVoltage = data_temp(:,8:10);
        forceJR3_Newton = handles.CalibrationMatrix*forceJR3_rawVoltage';
        % 1.5 sec after max
        % end_baseline = data_temp(end-round((1000/handles.samplerate)*3000):end,handles.ChannelNumber);
        end_baseline = forceJR3_Newton(3,end-round((1000/handles.samplerate)*3000):end);
        % calculate offset and pass it to handles
        handles.mean_offset = mean(end_baseline);
        handles.mvc_endtime = mean(end_baseline);
        % maxval = max(abs(data_temp(:,handles.ChannelNumber)));
        maxval = max(abs(forceJR3_Newton(3,:)));
        % change the Offset_Value static text on gui
        set(handles.Offset_Value,'String',num2str(handles.mean_offset));
        % change the MVC_value edit text
        set(handles.MVC_value,'String',num2str((maxval-handles.mean_offset)));
        set(handles.MaxTag,'String',num2str(maxval));
    elseif handles.ChannelNumber == 9 % Y-Force
        forceJR3_rawVoltage = data_temp(:,8:10);
        forceJR3_Newton = handles.CalibrationMatrix*forceJR3_rawVoltage';
        % 1.5 sec after max
        % end_baseline = data_temp(end-round((1000/handles.samplerate)*3000):end,handles.ChannelNumber);
        end_baseline = forceJR3_Newton(2,end-round((1000/handles.samplerate)*3000):end);
        % calculate offset and pass it to handles
        handles.mean_offset = mean(abs(end_baseline));
        handles.mvc_endtime = mean(end_baseline);
        % maxval = max(abs(data_temp(:,handles.ChannelNumber)));
        maxval = max(abs(forceJR3_Newton(2,:)));
        % change the Offset_Value static text on gui
        set(handles.Offset_Value,'String',num2str(handles.mean_offset));
        % change the MVC_value edit text
        set(handles.MVC_value,'String',num2str((maxval-handles.mean_offset)));
        set(handles.MaxTag,'String',num2str(maxval));
    elseif handles.ChannelNumber == 8 % X-Force
        forceJR3_rawVoltage = data_temp(:,8:10);
        forceJR3_Newton = handles.CalibrationMatrix*forceJR3_rawVoltage';
        % 1.5 sec after max
        % end_baseline = data_temp(end-round((1000/handles.samplerate)*3000):end,handles.ChannelNumber);
        end_baseline = forceJR3_Newton(1,end-round((1000/handles.samplerate)*3000):end);
        % calculate offset and pass it to handles
        handles.mean_offset = mean(end_baseline);
        handles.mvc_endtime = mean(end_baseline);
        % maxval = max(abs(data_temp(:,handles.ChannelNumber)));
        maxval = max(abs(forceJR3_Newton(1,:)));
        % change the Offset_Value static text on gui
        set(handles.Offset_Value,'String',num2str(handles.mean_offset));
        % change the MVC_value edit text
        set(handles.MVC_value,'String',num2str((maxval-handles.mean_offset)));
        set(handles.MaxTag,'String',num2str(maxval));
        
        %--------------------------------------------------------------------------
        %--------------------------------------------------------------------------
        % EMG feedback
        %     elseif handles.ChannelNumber == 3
        %         Fs = handles.samplerate;
        %         F_Nyquest = Fs/2;
        %         [b,a] = butter(4,200/F_Nyquest,'high');
        %         dataEMG = data_temp(:,handles.ChannelNumber);
        %         dataEMG_filt = filtfilt(b,a,dataEMG);
        %         dataEMG_rect = abs(dataEMG_filt);
        %         dataEMG_enov = conv(dataEMG_rect,gausswin(1*Fs)./sum(gaisswin(1*Fs)),'same');
        %
        %         end_baseline = dataEMG(end-round((1000/handles.samplerate)*3000):end);
        %         handles.mean_offset = mean(end_baseline);
        %         handles.mvc_endtime = mean(end_baseline);
        %         dataEMG_temp = abs(dataEMG-handles.mean_offset);
        %         maxval = max(dataEMG_temp);
        %         % change the Offset_Value static text on gui
        %         set(handles.Offset_Value,'String',num2str(handles.mean_offset));
        %         % change the MVC_value edit text
        %         set(handles.MVC_value,'String',num2str((maxval)));
        %         set(handles.MaxTag,'String',num2str(maxval));
        %--------------------------------------------------------------------------
        %--------------------------------------------------------------------------
        
    end
    
    handles.mvc_range = str2double(get(handles.MVC_value,'String'));
    
    % set parameters for thresholding
    handles.Threshold_MVC = handles.MVC_value;
    handles.Threshold_Offset = handles.Offset_Value;
    
else
    % Force target trials
    handles.Index = 0;
    
    %start data collection
    if get(handles.AutoStimulation,'Value') == 1
        putdata(handles.ao, [zeros(1,1*handles.OutputSampleRate) Stimulation_Vector]');
        start(handles.ai);
        start(handles.ao);
    elseif get(handles.AutoStimulation,'Value') == 0
        start(handles.ai);
    end
    
    %start datalink
    pstatus = libpointer('int32Ptr',0);
    calllib('OnLineInterface','OnLineStatus',0,5,pstatus);
    wait(handles.ai,handles.Duration+10);
    stop(handles.ai);
    %stop datalink
    calllib('OnLineInterface','OnLineStatus',0,6,pstatus);
    [data, time, absTime, events,daqInfo] = daqread('datatrial.daq');
    delete datatrial.daq
    
end

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% save data
[handles.data,handles.time] = getdata(handles.ai);
Trial.Data = handles.data;
Trial.Time = handles.time;

Trial.Info{1,1} = 'Trial Description';
Trial.Info{2,1} = 'Sample Rate';
Trial.Info{3,1} = 'MVC Value';
Trial.Info{4,1} = 'Offset Value';
Trial.Info{5,1} = 'Target Force Level';
Trial.Info{6,1} = 'Hold Duration';

Trial.Info{1,2} = get(handles.TrialDescription,'String');
Trial.Info{2,2} = handles.samplerate;
Trial.Info{3,2} = str2double(get(handles.MVC_value,'String'));
Trial.Info{4,2} = str2double(get(handles.Offset_Value,'String'));
Trial.Info{5,2} = str2double(get(handles.TargetForceLevel,'String'));
Trial.Info{6,2} = str2double(get(handles.HoldDuration,'String'));

fileDir = [pwd '\' get(handles.subjectCodeEdit,'String') '\'];
fileName = [get(handles.subjectCodeEdit,'String') '_' num2str(get(handles.TrialNumberEdit,'String'),'%.3d')];

save([fileDir,fileName],'Trial');

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% update trialistbox
list = get(handles.prevTrialsListbox,'String');
list{end + 1} = [fileName]; %'.mat'];
set(handles.prevTrialsListbox, 'String', list);
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% update trial number
trialNumber = str2num(get(handles.TrialNumberEdit,'String')) + 1;
set(handles.TrialNumberEdit,'String',num2str(trialNumber));

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
guidata(hObject,handles);

function varargout = ForceTracking_OutputFcn(hObject, eventdata, handles)
varargout{1} = handles.output;

guidata(hObject,handles);

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% sample acquiring function
% this function updates figures during data collection
function sample_acq_fcn(one,two,three)

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% Aquire data
handles = guidata(three);
data = getsample(handles.ai);
temp = get(handles.LinePlotForce,'ydata');
temp2 = get(handles.CURSOR2,'ydata');

if handles.ChannelNumber == 10 %z-axis force
    Channel = 3;
elseif handles.ChannelNumber == 9 %y-axis force
    Channel = 2;
elseif handles.ChannelNumber == 8 %x-axis force
    Channel = 1;
else
    Channel = handles.ChannelNumber;
end

% index in data sample for the end of aquired data
handles.Index = handles.Index + handles.N;

EMG1_data = data(2);
EMG2_data = data(3);
Trigger_data = data(7);

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% Convert raw voltage into newton
forceJR3_rawVoltage = data(8:10);
forceJR3_Newton = handles.CalibrationMatrix*forceJR3_rawVoltage';
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% MVC trial
if strcmp(get(handles.MVC_value,'String'),'0')
    
    % Extract aquired force data from Index+1-handles to Index in sample
    % Remove offset
    Force_temp(handles.Index+1-handles.N:handles.Index) = (abs(forceJR3_Newton(Channel))- str2double(get(handles.Offset_Value,'String')));
    % display force feedback in GUIDE
    set(handles.LinePlotForce,'YData',Force_temp);
    xlabel('Force')
    ylabel('Time(sec)')
    
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% Force tracking trial
elseif strcmp(get(handles.MVC_value,'String'),'0') == 0
    %--------------------------------------------------------------------------
    % stationary target
    if Channel == 3
        
        % Extract aquired force data from Index+1-handles to Index in sample
        % Force [N]
        Force_temp(handles.Index+1-handles.N:handles.Index) = (abs(forceJR3_Newton(Channel))- str2double(get(handles.Offset_Value,'String')));
        % Force normalized to MVC [%MVC]
        Force_temp2 = (abs(forceJR3_Newton(Channel)) - str2double(get(handles.Offset_Value,'String')))/str2double(get(handles.MVC_value,'String'));
        % display raw force to the main axis
        set(handles.LinePlotForce,'YData',Force_temp);
        xlabel('Time (sec)')
        ylabel('Force (N)')
            
        %------------------------------------------------------------------
        % Test trial
        if get(handles.Baseline_Button,'Value') == 0         
            %--------------------------------------------------------------
            % Pursuit tracking: 
            %   feedback cursor moves from left to right 
            if handles.feedback_style == 1
                set(handles.CURSOR2,'xdata',(mod(handles.Index,length(handles.t)))/handles.samplerate,'YData',Force_temp2*100);
               
            %--------------------------------------------------------------
            % Static compensation: 
            %   feedback cursor moves up and down in the middle of the feedback figure (i.e., FORCEPLOT2LINE1) 
            elseif handles.feedback_style == 2
                %----------------------------------------------------------
                % Continuous feedback:
                %   where a subject can see the cursor all time
                if get(handles.Feedback_Continuous,'Value') == 1
                    %------------------------------------------------------
                    % Change the width of the acceptable range
                    % High gain condition
                    if get(handles.Feedback_HG,'Value') == 1
                        set(handles.FORCEPLOT2LINE1,'xdata',[0:length(handles.t)],'ydata',[ones(1,length(handles.t)).*handles.TargetData(1+mod(handles.Index,length(handles.t)))],'Color',[.7 .7 .7],'Linewidth',15)
                    % Low gain condition
                    elseif get(handles.Feedback_LG,'Value') == 1
                        set(handles.FORCEPLOT2LINE1,'xdata',[0:length(handles.t)],'ydata',[ones(1,length(handles.t)).*handles.TargetData(1+mod(handles.Index,length(handles.t)))],'Color',[.7 .7 .7],'Linewidth',40)
                    end                   
                %----------------------------------------------------------
                % Discrete feedback:
                %   where the cursor disappers when it is within the acceptable range
                elseif get(handles.Feedback_Discrete,'Value') == 1
                    %------------------------------------------------------
                    % Change the width of the acceptable range
                    % High gain condition
                    if get(handles.Feedback_HG,'Value') == 1
                        set(handles.FORCEPLOT2LINE1,'xdata',[0:length(handles.t)],'ydata',[ones(1,length(handles.t)).*handles.TargetData(1+mod(handles.Index,length(handles.t)))],'Color',[.7 .7 .7],'Linewidth',15)
                    % Low gain condition
                    elseif get(handles.Feedback_LG,'Value') == 1
                        set(handles.FORCEPLOT2LINE1,'xdata',[0:length(handles.t)],'ydata',[ones(1,length(handles.t)).*handles.TargetData(1+mod(handles.Index,length(handles.t)))],'Color',[.7 .7 .7],'Linewidth',40)
                    end
                end
                %----------------------------------------------------------
                % Plot the normalized force data in the middle
                set(handles.CURSOR2,'xdata',round(length(handles.t)/2)/handles.samplerate,'YData',Force_temp2*100);
            %--------------------------------------------------------------
            % Dynamic compensation: 
            %   feedback            
            elseif handles.feedback_style == 3
                set(handles.FORCEPLOT2LINE1,'xdata',0:length(handles.t),'ydata',zeros(1,length(handles.t)),'Color',[.7 .7 .7],'Linewidth',5)
                set(handles.CURSOR2,'xdata',round(length(handles.t)/2),'YData',Force_temp2*100-handles.TargetData(1+mod(handles.Index,length(handles.t))));
            end
            
        %------------------------------------------------------------------
        % Baseline trial
        %   Calculate baseline amplitude of force variability
        elseif get(handles.Baseline_Button,'Value') == 1         
            %--------------------------------------------------------------
            set(handles.FORCEPLOT2LINE1,'xdata',[1:length(handles.t)],'ydata',[ones(1,length(handles.t)).*handles.TargetData(1+mod(handles.Index,length(handles.t)))],'Color',[.7 .7 .7],'Linewidth',15)
            % Display force feedback for 5 sec and remove it for the rest
            if round(length(handles.t)/2)/handles.samplerate > 5
                set(handles.CURSOR2,'xdata',round(length(handles.t)/2)/handles.samplerate,'YData',Force_temp2*100,'Color',[.7 .7 .7]);
            else
                set(handles.CURSOR2,'xdata',round(length(handles.t)/2)/handles.samplerate,'YData',Force_temp2*100);
            end
        end
    elseif Channel == 2
        temp(handles.Index+1-handles.N:handles.Index) = (abs(forceJR3_Newton(Channel)- str2double(get(handles.Offset_Value,'String'))));
        temp2 = abs((forceJR3_Newton(Channel) - str2double(get(handles.Offset_Value,'String'))))/str2double(get(handles.MVC_value,'String'));
        %display force feedback in GUIDE
        set(handles.LinePlotForce,'YData',temp);
        xlabel('Force')
        ylabel('Time(sec)')
        
        if handles.feedback_style == 1
            set(handles.CURSOR2,'xdata',(mod(handles.Index,length(handles.t)))/handles.samplerate,'YData',temp2*100);
            %handles.HoldDuration*handles.samplerate
            if (((forceJR3_Newton(Channel)-handles.Threshold_Offset)/handles.Threshold_MVC) > (handles.LowerThreshold/100)) ...
                    && (((forceJR3_Newton(Channel)-handles.Threshold_Offset)/handles.Threshold_MVC) < (handles.UpperThreshold/100))
                set(handles.CURSOR2,'Parent',handles.FIG2,'MarkerFaceColor',[0 0 0],'MarkerEdgeColor',[0 0 0]);
            else
                set(handles.CURSOR2,'Parent',handles.FIG2,'MarkerFaceColor',[0.5 0.5 0.5],'MarkerEdgeColor',[0.5 0.5 0.5]);
            end
            %moving target
        elseif handles.feedback_style == 2
            set(handles.FORCEPLOT2LINE1,'xdata',[1:length(handles.t)],'ydata',[ones(1,length(handles.t)).*handles.TargetData(1+mod(handles.Index,length(handles.t)))],'Color',[.7 .7 .7],'Linewidth',5)
            set(handles.CURSOR2,'xdata',round(length(handles.t)/2)/handles.samplerate,'YData',temp2*100);
            if (((data(1)-handles.Threshold_Offset)/handles.Threshold_MVC) > (handles.LowerThreshold/100)) ...
                    && (((data(1)-handles.Threshold_Offset)/handles.Threshold_MVC) < (handles.UpperThreshold/100))
                set(handles.CURSOR2,'Parent',handles.FIG2,'MarkerFaceColor',[0 0 0],'MarkerEdgeColor',[0 0 0]);
            else
                set(handles.CURSOR2,'Parent',handles.FIG2,'MarkerFaceColor',[0.5 0.5 0.5],'MarkerEdgeColor',[0.5 0.5 0.5]);
            end
            %compensation
        elseif handles.feedback_style == 3
            set(handles.FORCEPLOT2LINE1,'xdata',1:length(handles.t),'ydata',zeros(1,length(handles.t)),'Color',[.7 .7 .7],'Linewidth',5)
            set(handles.CURSOR2,'xdata',round(length(handles.t)/2),'YData',temp2*100-handles.TargetData(1+mod(handles.Index,length(handles.t))));
        end
        %         Fs = handles.samplerate/handles.N;
        %         [b,a] = butter(4,200/(Fs/2),'high');
        %         dataFilt = zeros(1,30);
        %         if handles.Index > handles.N*5
        %             dataTemp(handles.Index+1-handles.N:handles.Index) = data(Channel);
        %             dataFilt(handles.Index+1-handles.N:handles.Index) = (b(5)*dataTemp(handles.Index-4*handles.N) + b(4)*dataTemp(handles.Index - handles.N*3) + b(3)*dataTemp(handles.Index-handles.N*2) ...
        %                 + b(2)*dataTemp(handles.Index-handles.N*1)+ b(1)*dataTemp(handles.Index) - a(5) * dataFilt(handles.Index - handles.N*4) ...
        %                 + a(4) * dataFilt(handles.Index - handles.N*3) + a(3) * dataFilt(handles.Index - handles.N*2) + a(2) * dataFilt(handles.Index - handles.N*1))/a(1);
        %         else
        %             dataTemp(handles.Index+1-handles.N:handles.Index) = 0;
        %             dataFilt(handles.Index+1-handles.N:handles.Index) = 0;
        %         end
        %         temp(handles.Index+1-handles.N:handles.Index) = (abs(data(Channel)- str2double(get(handles.Offset_Value,'String'))))/str2double(get(handles.MVC_value,'String'))*100;
        %
        %         set(handles.LinePlotForce,'YData',temp);
        %         xlabel('Force')
        %         ylabel('Time(sec)')
        %         dataTemp =  data(Channel);
        %         dataRect = abs(data(Channel) - str2double(get(handles.Offset_Value,'String')))/str2double(get(handles.MVC_value,'String'));
        %
        %         set(handles.CURSOR2,'xdata',(mod(handles.Index,length(handles.t)))/handles.samplerate,'YData',dataRect*100);
        %
    end
end

%% display EMG data
if get(handles.Raw,'Value') == 1
    % %% plot raw EMG data
    %
    %     set(handles.LinePlotEMG1,'xdata',(mod(handles.Index,handles.Duration*handles.samplerate))/handles.samplerate,'ydata',EMG1_data);
    %
    %     set(handles.LinePlotEMG2,'xdata',(mod(handles.Index,handles.Duration*handles.samplerate))/handles.samplerate,'ydata',EMG2_data);
    %
elseif get(handles.TendonReflex,'Value') == 1
    %% plot tendon forcetracking EMG data
    reflex_1_store = [];
    reflex_2_store = [];
    [pks,locs]= findpeaks(Trigger_data,'threshold',1);
    [t,reflex_1,t_tfr,reflex_tfr_1] = TendonReflex(locs(end),EMG1_data);
    [t,reflex_2,t_tfr,reflex_tfr_2] = TendonReflex(locs(end),EMG2_data);
    reflex_1_store = reflex_1_store + reflex_1;
    reflex_2_store = reflex_2_store + reflex_2;
    
    axes(handles.EMG1Plot)
    hold on
    set(handles.Plot2,'xdata',t,'ydata',reflex_1_store);
    hold off
    
    axes(handles.EMG2Plot)
    hold on
    set(handles.Plot3,'xdata',t,'ydata',reflex_2_store);
    hold off
    
elseif get(handles.Hreflex,'Value') == 1
    %% plot H-forcetracking EMG data
    % H-forcetracking analysis has two options, recruitment curve or sweep
    
    if get(handles.Recruitment,'Value') == 1
        % recruitment curve option looks for peak-to-peak amplitudes of M-wave and
        % H-forcetracking for corresponding stimulu intensities
        % Start low and increae intensity upto Mmax
        
    elseif get(handles.Sweep,'Value') == 1
        % sweep option calculates peak-to-peak amplitudes of M and H
        % it discards responses that didn't produce appropriate M-wave (+/-10% of targt Mwave(10%Mmax))
    end
    
    %%
end
%drawnow;

guidata(handles.LinePlotForce,handles);

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% List box for previous trials
function prevTrialsListbox_Callback(hObject, eventdata, handles)
function prevTrialsListbox_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function Analysis_Pushbutton_Callback(hObject, eventdata, handles)
Fs = handles.samplerate;

if get(handles.Baseline_Button,'Value') == 1
    %----------------------------------------------------------------------
    % Obtain trial information
    prompt = {'Muscle:','Contraction Level:','Feedback Gain:'};
    title = 'Trial Info';
    dims = [1 35];
    definput = {'fl','10','hg'};
    answer = inputdlg(prompt,title,dims,definput);
    file_name_temp = ['baseline_' answer{1} '_' answer{2} '_' answer 'hg'];    
    file_directory= [pwd '\' get(handles.subjectCodeEdit,'String') '\'];
    
    %----------------------------------------------------------------------
    % Calculate average baseline std from 5 baseline trials
    std_force = zeros(1,5);
    for i = 1:5
        load ([file_directory [file_name_temp '_' num2str(i)]],'Trial')
        forceJR3_rawVoltage = Trial.Data(:,8:10);
        forceJR3_Newton = handles.CalibrationMatrix*forceJR3_rawVoltage';
        force_data = abs(forceJR3_Newton(3,:)) - abs(str2double(get(handles.Offset_Value,'String')));
        force_norm = 100*force_data/str2double(get(handles.MVC_value,'String'));
        force_detrend = detrend(force_norm); % detrend data
        std_force(i) = force_detrend(end-5*Fs:end); % obtain data from final 5-s 
    end
    handles.baseline_std = mean(std_force);
end

guidata(hObject,handles);

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% function for 'plot data' push button
function PlotDataPushbutton_Callback(hObject, eventdata, handles)

%% look for selected data and load
index_selected = get(handles.prevTrialsListbox,'Value');
list = get(handles.prevTrialsListbox,'String');
trialFile = list{index_selected};
fileDir = [pwd '\' get(handles.subjectCodeEdit,'String') '\'];
load ([fileDir trialFile], 'Trial');

forceJR3_rawVoltage = Trial.Data(:,8:10);
forceJR3_Newton = handles.CalibrationMatrix*forceJR3_rawVoltage';

xdata = Trial.Time;
force_data = abs(forceJR3_Newton(3,:)) - abs(str2double(get(handles.Offset_Value,'String')));
force_plot = 100*force_data/str2double(get(handles.MVC_value,'String'));
EMG1_data = Trial.Data(:,3);
EMG2_data = Trial.Data(:,4);
EMG3_data = Trial.Data(:,5);
EMG4_data = Trial.Data(:,6);
Trigger_data = Trial.Data(:,7);
%% plot data
% calbrated force data in %MVC
set(handles.LinePlotForce,'xdata',xdata,'ydata',100*(force_data - str2double(get(handles.Offset_Value,'String')))/str2double(get(handles.MVC_value,'String')));
xlabel('Force')
ylabel('Time(sec)')
hold off

% plot data
if get(handles.Raw,'Value') == 1
    %plot
    Fs = handles.samplerate;
    time = [1:length(force_data)]/Fs;
    figure()
    plot(time,force_plot)
    xlabel('Time (sec)')
    ylabel('Force (%)')
    
    [time_chosen,force_chosen] = ginput(2);
    CoV_force = std(force_plot(time_chosen(1)*Fs:time_chosen(2)*Fs))/mean(force_plot(time_chosen(1)*Fs:time_chosen(2)*Fs));
    f = msgbox(num2str(CoV_force*100));
    
elseif get(handles.TendonReflex,'Value') == 1
    %plot tendon forcetracking EMG data
    reflex_1_store = [];
    reflex_2_store = [];
    
    fvec=4:1:30;
    Fs = 2000;
    reflex_tfr_start = 0.03*Fs+1;
    reflex_tfr_end = 0.4*Fs;
    time_reflex_tfr = reflex_tfr_start:1:reflex_tfr_end;
    reflex_1_tfr_store = zeros(length(fvec),length(time_reflex_tfr));
    reflex_2_tfr_store = zeros(length(fvec),length(time_reflex_tfr));
    
    [pks,locs]= findpeaks(Trigger_data,'threshold',1);
    for i = 1:length(locs)/2
        [t,reflex_1,t_tfr,reflex_tfr_1] = TendonReflex(locs(2*i),EMG1_data);
        [t,reflex_2,t_tfr,reflex_tfr_2] = TendonReflex(locs(2*i),EMG2_data);
    end
    
    reflex_1_store = reflex_1_store + reflex_1;
    reflex_2_store = reflex_2_store + reflex_2;
    
    reflex_1_mean = reflex_1_store./(length(locs)/2);
    reflex_2_mean = reflex_2_store./(length(locs)/2);
    
    reflex_1_tfr_store = reflex_1_tfr_store + reflex_1;
    reflex_2_tfr_store = reflex_2_tfr_store + reflex_2;
    
    reflex_1_tfr_mean = reflex_1_tfr_store./(length(locs)/2);
    reflex_2_tfr_mean = reflex_2_tfr_store./(length(locs)/2);
    
    
    axes(handles.EMG1Plot)
    hold on
    set(handles.Plot2,'xdata',t,'ydata',reflex_1_mean);
    hold off
    
    axes(handles.EMG2Plot)
    hold on
    set(handles.Plot3,'xdata',t,'ydata',reflex_2_mean);
    hold off
    
    figure()
    imagesc(t_tfr,fvec,reflex_1_tfr_mean)
    title('Muscle 1')
    xlabel('Time(ms)')
    ylabel('Frequency(Hz)')
    figure()
    imagesc(t_tfr,fvec,reflex_2_tfr_mean)
    title('Muscle 2')
    xlabel('time(ms)')
    ylabel('Frequency(Hz)')
    %% Plot H-Reflex data
elseif get(handles.Hreflex,'Value') == 1
    
    if get(handles.Single,'Value') == 1 % when single pulse is used
        Fs = handles.samplerate;
        t = -50:1:100;
        [pks,locs]= findpeaks(Trigger_data,'threshold',1);
        for i = 1:length(locs)
            figure(2)
            plot(t,abs(EMG1_data(locs(i)-0.05*Fs:locs(i)+0.1*Fs) - str2double(get(handles.Offset_Value,'String'))))
            title('EMG 1')
            hold on
            dataTemp(i,:) = abs(EMG1_data(locs(i)-0.05*Fs:locs(i)+0.1*Fs)  - str2double(get(handles.Offset_Value,'String')));
            
            figure(3)
            plot(t,EMG2_data(locs(i)-0.05*Fs:locs(i)+0.1*Fs))
            title('EMG 2')
            hold on
            dataTemp_2(i,:) = EMG2_data(locs(i)-0.05*Fs:locs(i)+0.1*Fs);
        end
        figure(4)
        plot(t,mean(dataTemp))
        title('EMG 1 Average')
        
        figure(5)
        plot(t,mean(dataTemp_2))
        title('EMG 2 Average')
    elseif get(handles.Double,'Value') == 1 % when double pulse is used
        Fs = handles.samplerate;
        t = -50:1:100;
        [pks,locs]= findpeaks(Trigger_data,'threshold',1);
        for i = 2:2:length(locs)
            figure(2)
            plot(t,abs(EMG1_data(locs(i)-0.05*Fs:locs(i)+0.1*Fs)))
            title('EMG 1')
            hold on
            dataTemp(i,:) = EMG1_data(locs(i)-0.05*Fs:locs(i)+0.1*Fs);
            
            figure(3)
            plot(t,EMG2_data(locs(i)-0.05*Fs:locs(i)+0.1*Fs))
            title('EMG 2')
            hold on
            dataTemp_2(i,:) = EMG2_data(locs(i)-0.05*Fs:locs(i)+0.1*Fs);
        end
        figure(4)
        plot(t,mean(abs(dataTemp)))
        title('EMG 1 Average')
        
        figure(5)
        plot(t,mean(dataTemp_2))
        title('EMG 2 Average')
    end
    
end


guidata(hObject,handles);


%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% Radio button to indicate baseline data collection
function Baseline_Button_Callback(hObject, eventdata, handles)

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% Axis for main pannel
function ForcePlot_CreateFcn(hObject, eventdata, handles)

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% Duration of trial
function duration_edit_Callback(hObject, eventdata, handles)
handle.Duration =  str2num(get(handles.duration_edit,'String'));
guidata(hObject, handles);
function duration_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%--------------------------------------------------------------------------
% Trial number
function TrialNumberEdit_Callback(hObject, eventdata, handles)
function TrialNumberEdit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%--------------------------------------------------------------------------
% Subject code
function subjectCodeEdit_Callback(~, eventdata, handles)
function subjectCodeEdit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%--------------------------------------------------------------------------
% Sampling rate
function sampleRateEdit_Callback(hObject, eventdata, handles)
function sampleRateEdit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% EMG analysis settings
function PulseInterval_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function PulseInterval_Callback(hObject, eventdata, handles)

function Hreflex_Options_SelectionChangeFcn(hObject, eventdata, handles)
switch get(eventdata.NewValue,'Tag')
    case 'Recruitment'
        set(handles.Recruitment,'Value',1);
        set(handles.Sweep,'Value',0);
    case 'Sweep'
        set(handles.Recruitment,'Value',0);
        set(handles.Sweep,'Value',1);
end
guidata(hObject,handles)

function PulseType_SelectionChangeFcn(hObject, eventdata, handles)
switch get(eventdata.NewValue,'Tag')
    case 'Single'
        set(handles.Single,'Value',1);
        set(handles.Double,'Value',0);
    case 'Double'
        set(handles.Single,'Value',0);
        set(handles.Double,'Value',1);
end
guidata(hObject,handles)

function EMG_Options_SelectionChangeFcn(hObject, eventdata, handles)

switch get(eventdata.NewValue,'Tag')
    case 'Raw'
        set(handles.Raw,'Value',1);
        set(handles.TendonReflex,'Value',0);
        set(handles.Hreflex,'Value',0);
    case 'Tendon Reflex'
        set(handles.Raw,'Value',0);
        set(handles.TendonReflex,'Value',1);
        set(handles.Hreflex,'Value',0);
    case 'H-reflex'
        set(handles.Raw,'Value',0);
        set(handles.TendonReflex,'Value',0);
        set(handles.Hreflex,'Value',1);
end
guidata(hObject,handles)

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% Force target settings
function MVC_value_Callback(hObject, eventdata, handles)
function MVC_value_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function MaxTag_Callback(hObject, eventdata, handles)
Max_Value = get(handles.MaxTag,'String');
set(handles.MVC_value,'String',num2str((str2double(Max_Value)-handles.mean_offset)));
function MaxTag_CreateFcn(hObject, eventdata, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function Offset_Value_CreateFcn(hObject, eventdata, handles)

function TargetForceLevel_Callback(hObject, eventdata, hand)
function TargetForceLevel_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function HoldDuration_Callback(hObject, eventdata, handles)
function HoldDuration_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%--------------------------------------------------------------------------
% Build_Target function creates a target based on inputs
function Build_Target_Callback(hObject, eventdata, handles)
set(handles.Build_Target,'Value',1);

%make the trapezoid or triangle [signal t] = generate_trap(SampRate_Hz,base_dur_s,ramp_dur_s,hold_dur_s,hold_level,modFreq,modAmp,modPhase)
[handles.TargetData handles.t] = generate_target2(handles.samplerate,0,...
    0,...
    str2double(get(handles.HoldDuration,'String')),...
    str2double(get(handles.TargetForceLevel,'String')),...
    0,...
    0,...
    0);

handles.FORCEPLOTDURATION=handles.t(end);
handles.FORCEPLOTDURATIONsamps=length(handles.t);

set(get(handles.FORCEPLOT2LINE1,'Parent'),'XLim',[0 length(handles.t)./handles.samplerate]);

if handles.feedback_style == 1
    set(handles.FORCEPLOT2LINE1,'XData',[0:1/handles.samplerate:(length(handles.t)-1)/handles.samplerate],'YData',[handles.TargetData],'Color',[.7 .7 .7],'Linewidth',5);
else
    set(handles.FORCEPLOT2LINE1,'XData',[1:length(handles.t)],'YData',[handles.TargetData],'Color',[.7 .7 .7],'Linewidth',5);
end
% newYLim = [-str2double(get(handles.ModulationAmplitude,'String'))+str2double(get(handles.TargetForceLevel,'String'))-10 ...
%         10+str2double(get(handles.ModulationAmplitude,'String'))+str2double(get(handles.TargetForceLevel,'String'))];
set(get(handles.LinePlotForce,'Parent'),'YLim',[-10 110]);
set(get(handles.FORCEPLOT2LINE1,'Parent'),'ylim',[-10 110]);


guidata(handles.figure1, handles);

%--------------------------------------------------------------------------
% Generate target based on inputs
function [signal t] = generate_target2(SampRate_Hz,base_dur_s,ramp_dur_s,hold_dur_s,hold_level,modFreq,modAmp,modPhase1);
%trapezoid (or triangle) signal.
% base_ramp_hold_ramp_base
%base and ramp lengths are symmetric
%if conversion from seconds to samples results in a non-integer
%then the specified sample number will be rounded down.
totaldur=(2*base_dur_s+2*ramp_dur_s+hold_dur_s);

t=linspace(0,totaldur,(floor(totaldur*SampRate_Hz)));
signal=zeros(1,length(t));
segments=floor([0,base_dur_s*SampRate_Hz,(base_dur_s+ramp_dur_s)*SampRate_Hz,(base_dur_s+ramp_dur_s+hold_dur_s)*SampRate_Hz,(base_dur_s+2*ramp_dur_s+hold_dur_s)*SampRate_Hz, totaldur*SampRate_Hz]);
%support 0 baseline and 0 ramp durations1
if base_dur_s==0
    segments(2)=1;
end
if base_dur_s==0 && ramp_dur_s==0
    segments(2)=1; segments(3)=1;
end

if ramp_dur_s>0%if there is a ramp
    signal(segments(2):segments(3))=t(1:length([segments(2):segments(3)])).*(hold_level/ramp_dur_s)+0;
    signal(segments(4):segments(5))=t(1:length([segments(4):segments(5)])).*-(hold_level/ramp_dur_s)+hold_level;
end
if hold_dur_s>0
    
    tempt=t(segments(3):segments(4))-t(segments(3));
    if length(modFreq)<2
        signal(segments(3):segments(4))=((hold_level.*ones(1,length(signal(segments(3):segments(4))))))+(modAmp(1).*sin(2*pi*tempt*modFreq(1)+modPhase1));
    end
    length(modFreq)
    if length(modFreq)>=2
        dummy=zeros(1,length(signal(segments(3):segments(4))));
        modPhase=rand(1,length(modFreq)).*(2*pi);
        for i=1:length(modFreq)
            dummy=dummy+(modAmp(i).*sin(2*pi*tempt*modFreq(i)+modPhase(i)));
        end
        signal(segments(3):segments(4))=dummy+(hold_level.*ones(1,length(signal(segments(3):segments(4)))));
    end
    
    
end

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% Load biometrics library
function LoadBiometricsLibrary_Callback(hObject, eventdata, handles)
if (get(hObject,'Value') == get(hObject,'Max'))
    addpath('C:\Program Files (x86)\Biometrics Ltd\DataLINK');
    loadlibrary('OnLineInterface.dll','OnLineInterface.h');
    obj = libstruct('tagSAFEARRAY');
end

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% asks for trial description
function TrialDescription_Callback(hObject, eventdata, handles)
function TrialDescription_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% Zero offset
function ZeroOffset_Callback(hObject, eventdata, handles)
handles.mean_offset = handles.mean_offset + ((handles.mvc_range*get(handles.CURSOR2,'ydata')))/100;
set(handles.Offset_Value,'String',num2str(handles.mean_offset));
guidata(hObject,handles)

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% Stimulation parameters
%--------------------------------------------------------------------------
% Stimulation setting
function Stimulation_Callback(hObject, eventdata, handles)
if get(handles.Single,'Value') == 1
    putdata(handles.ao,[0,4; 0 4]');%5/16/16 changed from [0,4]
    start(handles.ao);
elseif get(handles.Double,'Value') == 1
    putdata(handles.ao,[0,4,zeros(1,str2double(get(handles.PulseInterval,'String'))),4,0]');%.5 for trig 1ms, separated by 50ms
    start(handles.ao);
end
%--------------------------------------------------------------------------
% Switch to auto stimulation method
function AutoStimulation_Callback(hObject, eventdata, handles)

%--------------------------------------------------------------------------
% Determine stimulus interval for auto-stimulation
function StimulationInterval_Callback(hObject, eventdata, handles)

function StimulationInterval_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% Load a mat file for previous MVC and update MVC value and offset value for subsequent tracking trials
function PreviousMVC_Callback(hObject, eventdata, handles)

fileDir = [pwd '\' get(handles.subjectCodeEdit,'String') '\'];
[Filename,Pathname] = uigetfile([fileDir '*.mat'],'Pick a file');
load([Pathname Filename]);
MVC = cell2mat(Trial.Info(3,2));
Offset = cell2mat(Trial.Info(4,2));
set(handles.MVC_value,'string',num2str(MVC));
set(handles.Offset_Value,'string',num2str(Offset));
handles.mvc_range = MVC;

% handles.Threshold_MVC = MVC;
% handles.Threshold_Offset = Offset;
% handles.LowerThreshold = 25;
% handles.UpperThreshold = 75;

guidata(hObject,handles);

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% Load a mat file to update color feedback setting for the secondary tracking channel
function LoadThreshold_Callback(hObject, eventdata, handles)
% hObject    handle to LoadThreshold (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
fileDir = [pwd '\' get(handles.subjectCodeEdit,'String') '\'];
[Filename,Pathname] = uigetfile([fileDir '*.mat'],'Pick a file');
load([Pathname Filename]);
handles.Threshold_MVC = cell2mat(Trial.Info(3,2));
handles.Threshold_Offset = cell2mat(Trial.Info(4,2));
handles.LowerThreshold = 25;
handles.UpperThreshold = 75;

guidata(hObject,handles);

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% Feedback-related
%--------------------------------------------------------------------------
% Select the daq channel to be used for visual feedback
function TrackingChannel_Callback(hObject, eventdata, handles)

handles.ChannelNumber = str2double(get(handles.TrackingChannel,'String'));
guidata(hObject,handles);
function TrackingChannel_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%--------------------------------------------------------------------------
% reset yscale of feedback axis
function Yscale_Callback(hObject, eventdata, handles)
set(get(handles.FORCEPLOT2LINE1,'Parent'),'YLim',str2num(get(handles.Yscale,'String')));
guidata(handles.figure1,handles)

function Yscale_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%--------------------------------------------------------------------------
% Swithc tracking style (pursuit, static compentation, and dynamic compenstaion)
function tracking_style_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function tracking_style_Callback(hObject, eventdata, handles)
handles.feedback_style = get(hObject,'Value');
if handles.feedback_style == 1
    set(handles.Build_Target,'Value',0);
end
guidata(hObject,handles);

%--------------------------------------------------------------------------
% Swithc feedback gain
function FeedbackGain_Choice_CreateFcn(hObject, eventdata, handles)
function FeedbackGain_Choice_SelectionChangeFcn(hObject, eventdata, handles)

switch get(eventdata.NewValue,'Tag')
    case 'High Gain'
        set(handles.Feedback_HG,'Value',1);
        set(handles.Feedback_LG,'Value',0);
    case 'Low Gain'
        set(handles.Feedback_HG,'Value',0);
        set(handles.Feedback_LG,'Value',1);
        
end
guidata(hObject,handles)

%--------------------------------------------------------------------------
% Switch a type of feedback (visual vs. auditory)
function Feedback_SelectionChangeFcn(hObject, eventdata, handles)
switch get(eventdata.NewValue,'Tag')
    case 'Visual'
        set(handles.Feedback_Visual,'Value',1);
        set(handles.Feedback_Auditory,'Value',0);
    case 'Auditory'
        set(handles.Feedback_Visual,'Value',0);
        set(handles.Feedback_Auditory,'Value',1);
        
end
guidata(hObject,handles)

%--------------------------------------------------------------------------
% Switch a type of feedback (continuous vs. discrete)
function Feedback_Type_SelectionChangeFcn(hObject, eventdata, handles)
switch get(eventdata.NewValue,'Tag')
    case 'Continuous'
        set(handles.Feedback_Continuous,'Value',1);
        set(handles.Feedback_Discrete,'Value',0);
    case 'Discrete'
        set(handles.Feedback_Continuous,'Value',0);
        set(handles.Feedback_Discrete,'Value',1);
        
end
guidata(hObject,handles)


