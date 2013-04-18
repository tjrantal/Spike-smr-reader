clear all;
close all;
fclose all;
clc;
dataPath = 'C:\MyTemp\oma\Timon\tyo\Reflex2013\DATA\';
fileName = '01_Johanna_17_04\Running_on_spot.smr';
addpath('smrReader');
%Channel name  data(chan).hdr.title
%Channel type data(chan).hdr.channeltype ('Continuous Waveform')
%Scaling of a given channel is in data(chan).hdr.adc.Scale
%Sampling interval is in data(chan).hdr.adc.SampleInterval(1)
%Units data(chan).hdr.adc.Units
data =ImportSMR([dataPath fileName]);
for chan = 1:length(data)
    if isfield(data(chan).hdr,'title') && isfield(data(chan).hdr,'channeltype')
    [data(chan).hdr.title ' ' data(chan).hdr.channeltype]
    end
end