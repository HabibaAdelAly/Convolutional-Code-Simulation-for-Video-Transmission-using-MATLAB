clc;
clear;
close all;

%Getting the video
vid=VideoReader('Stephan.avi');

%Getting the number of frames in the vedio
Frames_num = vid.NumFrames;
frame_rate = vid.FrameRate;

%Creating decoded frames
decodedFrames={};

%Creating the trellis (change the numbers however u like :))
K=7;
trellis=poly2trellis(K, [133 177]);

%defining the probability of error (also change it however u like :))
pe=0.1;

%deining if the channel uses channel coding or not
isChannelCoding=true;

%getting components for each color as binary
for i=1:Frames_num
    frame = read(vid, i);
     %getting  red components 
    redComponent = frame(:,:,1);
     %getting  green components
    greenComponent = frame(:,:,2);
     %getting  blue components
    blueComponent = frame(:,:,3);

redComponent=reshape(redComponent,1,[]); %we reshape to put the red as a stream of 1 row 
greenComponent=reshape(greenComponent,1,[]); %we reshape to put the green as a stream of 1 row 
blueComponent=reshape(blueComponent,1,[]); %we reshape to put the blue as a stream of 1 row 

redComponentdec=double(redComponent);%convert red map-8 to decimal
greenComponentdec=double(greenComponent);%convert green map-8 to decimal
blueComponentdec=double(blueComponent);%convert blue map-8 to decimal

Rbin=dec2bin(redComponentdec,8); %convert red decimal to binary in 8 bits
Gbin=dec2bin(greenComponentdec,8); %convert green decimal to binary in 8 bits
Bbin=dec2bin(blueComponentdec,8); %convert blue decimal to binary in 8 bits


%double converts the input string to a numeric array of ASCII codes. The
%ASCII of zero is 48 so we subtract by 48
Rbin_stream=double(reshape(Rbin,[1,101376*8]))-48;%convert the char into an array Red component
Gbin_stream=double(reshape(Rbin,[1,101376*8]))-48;%convert the char into an array green component
Bbin_stream=double(reshape(Rbin,[1,101376*8]))-48;%convert the char into an array blue component

if isChannelCoding==true
%Red 
decodedRed = transmit_channel_coding(Rbin_stream,trellis,pe,K);

%Green
decodedGreen = transmit_channel_coding(Gbin_stream,trellis,pe,K);

%Blue
decodedBlue = transmit_channel_coding(Bbin_stream,trellis,pe,K);

else

%Red 
decodedRed = transmit(Rbin_stream,pe);

%Green
decodedGreen = transmit(Gbin_stream,pe);

%Blue
decodedBlue = transmit(Bbin_stream,pe);
end

%combine color components into a single frame
decodedFrame = cat(3, decodedRed, decodedGreen, decodedBlue);

%store decoded frame in cell array
decodedFrames=cat(2,decodedFrames,decodedFrame) ;

end

% create a VideoWriter object with a specified filename and frame rate
outputVideo = VideoWriter('output.avi','Motion JPEG 2000');

% open the video for writing
open(outputVideo);

% write each frame to the video
for i = 1:Frames_num
   writeVideo(outputVideo, decodedFrames{i});
end

close(outputVideo);

%Here starts the functions that encodes, decodes and puts the error

%1)Getting the Trellis with different rates and then encoding
function [encodedData] = toEncode(data,trellis)
encodedData=convenc(data(1,:),trellis);
encodedData=reshape(encodedData,[(length(encodedData)/8),8]);
end

%2)Sending the bits in error/error_free
function [errorStream]= getErrorStream(probabilityOfError,correctStream)
errorStream=correctStream;
for i=1:length(correctStream)
    random=rand;
    if(random<=probabilityOfError)
        if(correctStream(i)==0)
            errorStream(i)=1;
        else
            errorStream(i)=0;
        end
    end
end
end

%3)Decoding using a specific trellis
function [decodedData] = toDecode(data,K,encodedData,trellis)
number_of_bits=numel(encodedData);
encodedData=reshape(encodedData,[1,number_of_bits]);
tbDepth=round((K-1)/(1-(length(data)/length(encodedData))));
decodedData =vitdec(encodedData(1,:),trellis,tbDepth,'trunc','hard');
decodedData=reshape(decodedData,[(length(decodedData)/8),8]);
end

%4)Function that encodes, decodes and puts error
function[decodedData]=transmit_channel_coding(data,trellis,error,K)
encodedData=toEncode(data,trellis);
errorData=getErrorStream(error,encodedData);
decodedData= toDecode(data,K,errorData,trellis);
end

%5)Function that transmits without channel coding (only error)
function[sentData]=transmit(data,error)
sentData=getErrorStream(error,data);
end