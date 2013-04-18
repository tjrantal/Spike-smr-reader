%Modified by Timo Rantalainen 2013
% function matfilename=ImportSMR(filename, targetpath)
function dataInMemory=ImportSMR(filename)
% ImportSMR imports Cambridge Electronic Design Spike2 files to
% sigTOOL. The file created has the 'kcl' extension but is a version 6
% MATLAB MAT-file
%
% Example:
% OUTPUTFILE=ImportSMR(FILENAME)
% OUTPUTFILE=ImportSMR(FILENAME, TARGETPATH)
%
% FILENAME is the path and name of the Spike2 file to import.
%
% The kcl file generated will be placed in TARGETPATH if supplied. If not,
% the file will be created in the directory taken from FILENAME.
%
% ImportSMR requires the MATLAB SON library version 2.4 or higher.
%
%
% Toolboxes required: None
%
% -------------------------------------------------------------------------
% Author: Malcolm Lidierth 07/06
% Copyright © The Author & King's College London 2006-2007
% -------------------------------------------------------------------------
%
% Acknowledgements:
% Revisions:


if (SONVersion('nodisplay')<2.31)
    errordlg('ImportSMR: An old version of the SON library is on the MATLAB path.\nDelete this and use the version in sigTOOL');
    matfilename='';
    which('SONVersion');
    return;
end
dataInMemory = struct([]);
[pathname filename2 extension]=fileparts(filename);
if strcmpi(extension,'.smr')==1
    % Spike2 for Windows source file so little-endian
    fid=fopen(filename,'r','l');
elseif strcmpi(extension,'.son')==1
    % Spike2 for Mac file
    fid=fopen(filename,'r','b');
else
    warning('%s is not a Spike2 file\n', filename);
    matfilename='';
    return
end
    
if fid<0
    matfilename='';
    return
end

% Removed by Timo
% % Set up MAT-file giving a 'kcl' extension
% matfilename=scCreateKCLFile(filename, targetpath);
% if isempty(matfilename)
%     return
% end

% get list of valid channels
F=SONFileHeader(fid);
c=SONChanList(fid);

% Removed by Timo
% progbar=scProgressBar(0,'','Name', 'Import File' );

% Import the data.
for i=1:length(c)
%     keyboard
    chan=c(i).number;
    msg=[];
    
%     Removed by Timo
%     scProgressBar(i/length(c), progbar, ...
%         sprintf('Importing data on Channel %d', chan));
    % For each channel, call the SON library function then save the data
    % in Mode 0. If this fails, it is likely to be because of an
    % out-of-memory error so use the SON library's inbuilt 'mat' option
    % to save the adc data in Mode 1. If that fails then skip to next
    % channel.
    try
        % Normal write - kcl Mode 0
%         keyboard;
        [data,header]=SONGetChannel(fid, chan,'progress','ticks');
        Mode=0;
%         keyboard;
        if isempty(data)
            % Empty channel
            continue
        end
    catch
        % Too large?: if so try Mode 1
        % SONGetADCChannel & SONGetRealWaveChannel have builtin writing.
        % This will fail again if we are trying to load a different channel
        % type.
%         keyboard;
        try
            keyboard;
            [data,header]=SONGetChannel(fid, chan,'progress','ticks',...
                'mat',matfilename);
            % SON library uses chan1, chan2 etc. Convert to adc1, adc2...
            VarRename(matfilename,['chan' num2str(chan)],...
                ['adc' num2str(chan)]);
            Mode=1;
        catch
            % Failed again
            % Go to next channel
            continue;
        end
    end
%     keyboard;
    hdr.channel=chan;
    hdr.source=dir(header.FileName);
    hdr.source.name=header.FileName;
    hdr.title=header.title;
    hdr.comment=header.comment;
    if strcmpi(hdr.title,'Keyboard')
        hdr.markerclass='char';
    else
        hdr.markerclass='uint8';
    end
%     keyboard
    switch header.kind
        case {1,9}% Waveform int16 or single in SMR file

            imp.tim(:,1)=int32(header.start);
            imp.tim(:,2)=int32(header.stop);
            imp.adc=data;
            imp.mrk=zeros(size(imp.tim,1),4,'uint8');

            if size(imp.adc,2)==1
                hdr.channeltype='Continuous Waveform';
                hdr.channeltypeFcn='';
                hdr.adc.Labels={'Time'};
            else
                hdr.channeltype='Episodic Waveform';
                hdr.adc.Labels={'Time' 'Epoch'};
            end

            hdr.adc.TargetClass='adcarray';
            hdr.adc.SampleInterval=[header.sampleinterval 1e-6];
            if header.kind==1
                hdr.adc.Scale=header.scale/6553.6;
                hdr.adc.DC=header.offset;
            else
                hdr.adc.Scale=1;
                hdr.adc.DC=0;
            end
            hdr.adc.Func=[];
            hdr.adc.Units=header.units;
            hdr.adc.Multiplex=header.interleave;
            hdr.adc.MultiInterval=[0 0];%not known from SMR format
            hdr.adc.Npoints=header.npoints;
            if Mode==0
                hdr.adc.YLim=[double(min(data(:)))*...
                hdr.adc.Scale+hdr.adc.DC...
                double(max(data(:)))*hdr.adc.Scale+hdr.adc.DC];
            else
                hdr.adc.YLim=[header.min header.max]*...
                    hdr.adc.Scale+hdr.adc.DC;
            end

            hdr.tim.Class='tstamp';
            % NB avoid IEEE rounding error
            hdr.tim.Scale=F.usPerTime;
            hdr.tim.Shift=0;
            hdr.tim.Func=[];
            hdr.tim.Units=F.dTimeBase;

        case {2,3}% Event+ or Event- in SMR file
            imp.tim(:,1)=data;
            imp.adc=[];
            imp.mrk=zeros(size(imp.tim,1),4,'uint8');
            if header.kind==2
                hdr.channeltype='Falling Edge';
            else
                hdr.channeltype='Rising Edge';
            end
            hdr.channeltypeFcn='';
            hdr.adc=[];

            hdr.tim.Class='tstamp';
            hdr.tim.Scale=F.usPerTime;
            hdr.tim.Shift=0;
            hdr.tim.Func=[];
            hdr.tim.Units=F.dTimeBase;

        case {4}% EventBoth in SMR file
            if header.initLow==0 % insert a rising edge...
                data=vertcat(-1, data);   % ...if initial state is high
            end
            imp.tim(:,1)=data(1:2:end-1);% rising edges
            imp.tim(:,2)=data(2:2:end);% falling edges
            imp.adc=[];
            imp.mrk=zeros(size(imp.tim,1),4,'uint8');

            hdr.channeltype='Pulse';
            hdr.channeltypeFcn='';
            hdr.adc=[];

            hdr.tim.Class='tstamp';
            hdr.tim.Scale=F.usPerTime;
            hdr.tim.Shift=0;
            hdr.tim.Func=[];
            hdr.tim.Units=F.dTimeBase;

        case {5}% Marker channel in SMR file
            imp.tim(:,1)=data.timings;
            imp.adc=[];
            imp.mrk=data.markers;

            hdr.channeltype='Edge';
            hdr.channeltypeFcn='';
            hdr.adc=[];

            hdr.tim.Class='tstamp';
            hdr.tim.Scale=F.usPerTime;
            hdr.tim.Shift=0;
            hdr.tim.Func=[];
            hdr.tim.Units=F.dTimeBase;

        case {6}% int16 ADC Marker in SMR file
            imp.tim(:,1)=data.timings;
            % 24.02.08 remove -1 and include interleave factor
            imp.tim(:,2)=data.timings...
                +(SONGetSampleTicks(fid,chan)*(header.preTrig));
            imp.tim(:,3)=data.timings...
                +(SONGetSampleTicks(fid,chan)*(header.values/header.interleave-1));

            imp.adc=data.adc;
            imp.mrk=data.markers;

            hdr.channeltype='Framed Waveform (Spike)';
            hdr.channeltypeFcn='';

            hdr.adc.Labels={'Time' 'Spike'};
            hdr.adc.TargetClass='adcarray';
            hdr.adc.SampleInterval=[header.sampleinterval 1e-6];
            hdr.adc.Scale=header.scale/6553.6;
            hdr.adc.DC=header.offset;
            hdr.adc.YLim=[double(min(data.adc(:)))*hdr.adc.Scale+hdr.adc.DC...
                double(max(data.adc(:)))*hdr.adc.Scale+hdr.adc.DC];
            hdr.adc.Func=[];
            hdr.adc.Units=header.units;
            hdr.adc.Npoints(1:size(imp.adc,2))=header.values;
            hdr.adc.Multiplex=header.interleave;
            hdr.adc.MultiInterval=[0 0];%not known from SMR format

            hdr.tim.TargetClass='tstamp';
            hdr.tim.Scale=F.usPerTime;
            hdr.tim.Shift=0;
            hdr.tim.Func=[];
            hdr.tim.Units=F.dTimeBase;

        case {7,8}% Real marker or text marker in SMR file
            imp.tim(:,1)=data.timings;
            switch header.kind
                case 7
                    imp.adc=data.real;
                    hdr.channeltype='Edge';
                    hdr.adc.TargetClass='single';
                    hdr.channeltypeFcn='';
                    hdr.adc.Labels={'Single'};
                case 8
                    imp.adc=data.text;
                    hdr.channeltype='Edge';
                    hdr.adc.TargetClass='char';
                    hdr.channeltypeFcn='SONMarkerDisplay';
                    hdr.adc.Labels={'Text'};
            end
            imp.mrk=data.markers;            
            hdr.adc.SampleInterval=NaN;
            hdr.adc.Func=[];
            hdr.adc.Scale=1;
            hdr.adc.DC=0;
            hdr.adc.Units='';
            hdr.adc.Multiplex=NaN;
            hdr.adc.MultiInterval=[0 0];%not known from SMR format
            hdr.adc.Npoints(1:size(imp.adc,2))=header.values;

            hdr.tim.TargetClass='tstamp';
            hdr.tim.Scale=F.usPerTime;
            hdr.tim.Shift=0;
            hdr.tim.Func=[];
            hdr.tim.Units=F.dTimeBase;

        otherwise
            continue
    end
%     scProgressBar(i/length(c), progbar, ...
%             sprintf('Saving data on Channel %d', chan));
    %Modified by Timo
    dataInMemory(i).hdr = hdr;
    dataInMemory(i).imp = imp;
    dataInMemory(i).Mode = Mode;
    dataInMemory(i).numer = chan;
%     scSaveImportedChannel(matfilename, chan, imp, hdr, Mode);
    clear('imp','hdr','data','header');
end
%Modified by Timo
% sigTOOLVersion=scVersion('nodisplay');
% save(matfilename,'sigTOOLVersion','-v6','-append');
fclose(fid);
% delete(progbar);
if ishandle(msg)
    delete(msg);
end
end