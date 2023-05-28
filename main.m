clc;
clear;
close all;

%Getting the video
vid=VideoReader('Stephan.avi.mp4');

%Getting the number of frames in the vedio
Frames_num = vid.NumFrames;
frame_rate = vid.FrameRate;

% Create a VideoWriter object with a specified filename and codec
outputVideo = VideoWriter('output.avi', 'Uncompressed AVI');

%create error Ranges and probabilities array
errorsRange= 0.0001:0.001:0.2;
errorProbability=[];

%Creating decoded frames
decodedFrames={};

%Creating the trellis (change the numbers however u like :))
trellis = poly2trellis(7,[135 135 147 163]);

%deining if the channel uses channel coding or not
isChannelCoding=1;

for j=1:1:size(errorsRange,2)
counter=0;

%defining the probability of error (also change it however u like :))
pe=errorsRange(j);

%getting components for each color as binary
for i=1:Frames_num
    frame = read(vid, i);
   %getting  red components 
     redComponentframe = frame(:,:,1);
   %getting  green components
     greenComponentframe = frame(:,:,2);
   %getting  blue components
     blueComponentframe = frame(:,:,3);

redComponent=reshape(redComponentframe,1,[]); %we reshape to put the red as a stream of 1 row 
greenComponent=reshape(greenComponentframe,1,[]); %we reshape to put the green as a stream of 1 row 
blueComponent=reshape(blueComponentframe,1,[]); %we reshape to put the blue as a stream of 1 row 

redComponentdec=double(redComponent);%convert red map-8 to decimal
greenComponentdec=double(greenComponent);%convert green map-8 to decimal
blueComponentdec=double(blueComponent);%convert blue map-8 to decimal

Rbin=de2bi(redComponentdec,8);%convert red decimal to binary in 8 bits
Gbin=de2bi(greenComponentdec,8);%convert green decimal to binary in 8 bits
Bbin=de2bi(blueComponentdec,8);%convert blue decimal to binary in 8 bits

%with channel coding
if (isChannelCoding==1)
decodedRed  =transmit_channel_coding(Rbin,trellis,pe); %red
decodedGreen=transmit_channel_coding(Gbin,trellis,pe); %green
decodedBlue =transmit_channel_coding(Bbin,trellis,pe); %blue
end

%without channel coding
if (isChannelCoding==0)
decodedRed=introduceBitErrors(pe,Rbin); %red
decodedGreen=introduceBitErrors(pe,Gbin); %green
decodedBlue=introduceBitErrors(pe,Bbin); %blue
end

%getting the number of bits in error after decoding
counter=counter+sum(sum(xor(decodedRed,Rbin)))+sum(sum(xor(decodedGreen,Gbin)))+sum(sum(xor(decodedBlue,Bbin)));

decodedRedDec=bi2de(decodedRed);%convert decoded red binary to decimal
decodedGreenDec=bi2de(decodedGreen);%convert decoded green binary to decimal
decodedBlueDec=bi2de(decodedBlue);%convert decoded blue binary to decimal

decodedRedUint8=uint8(decodedRedDec);%convert decoded Red decimal into uint8 format
decodedGreenUint8=uint8(decodedGreenDec);%convert decoded green decimal into uint8 format
decodedBlueUint8=uint8(decodedBlueDec);%convert decoded blue decimal into uint8 format

Rframe=reshape(decodedRedUint8,size(frame,1),size(frame,2),[]); %we reshape to put the red in the original size
Gframe=reshape(decodedGreenUint8,size(frame,1),size(frame,2),[]);%we reshape to put the green in the original size
Bframe=reshape(decodedBlueUint8,size(frame,1),size(frame,2),[]);%we reshape to put the blue in the original size

%combine color components into a single frame
decodedFrame = cat(3, Rframe,Gframe, Bframe);

%store decoded frame in cell array
decodedFrames = cat(2,decodedFrames,decodedFrame);
 
end

%getting the probability of error
probability=counter/(Frames_num*(numel(Rbin)*3));
errorProbability=[errorProbability,probability];

%getting the rates of the codes (trellis number could be changed)
rate=numel(Rbin)/numel(toEncode(Rbin,trellis));

end

% open the video for writing
open(outputVideo);

%writing the frames in the outputVideo
for i=1:Frames_num
frame=decodedFrames{i};
writeVideo(outputVideo, frame);
end

%close the video
close(outputVideo);

% plot error probability vs. error range
figure;
plot(errorsRange, errorProbability);
xlabel('Error Range');
ylabel('Error Probability');
title('Error Probability vs. Error Range');


%Here starts the functions that encodes, decodes and puts the error
%1)Getting the Trellis with different rates and then encoding
function [encodedData] = toEncode(data2,trellis)
data= reshape(data2, [], 1);
encodedData=convenc(data,trellis);
encodedData=reshape(encodedData,size(data2,1),[]);
end

%2)Sending the bits in error/error_free
function [errorStream] = introduceBitErrors(probabilityOfError, correctStream)
    random = rand(size(correctStream)); % generate random matrix
    errorStream = correctStream; % initialize output matrix
    % compare random matrix with error probability matrix and flip bits
    errorStream(random < probabilityOfError) = 1 - errorStream(random < probabilityOfError);
end

%3)Decoding using a specific trellis
function [decodedData] = toDecode(data2,trellis)
%number_of_bits=numel(encodedData);
data= reshape(data2, [], 1);
decodedData =vitdec(data,trellis,50,'trunc','hard');
decodedData=reshape(decodedData,size(data2,1),[]);
end

%4)Function that encodes, decodes and puts error
function[decodedData]=transmit_channel_coding(data,trellis,error)
encodedData=toEncode(data,trellis);
errorData=introduceBitErrors(error,encodedData);
decodedData= toDecode(errorData,trellis);
end
