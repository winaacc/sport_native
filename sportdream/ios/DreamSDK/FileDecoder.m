//
//  FileDecoder.m
//  sportdream
//
//  Created by lili on 2018/1/25.
//  Copyright © 2018年 Facebook. All rights reserved.
//

#import "FileDecoder.h"


@interface FileDecoder()
@property (nonatomic,strong) NSURL* url;
@property (nonatomic,strong) AVAsset* asset;
@property (nonatomic,strong) AVAssetReader* reader;
@end

@implementation FileDecoder
{
  BOOL audioEncodingIsFinished;
  BOOL videoEncodingIsFinished;
  BOOL keepLooping;
  CMTime previousFrameTime, processingFrameTime;
  CFAbsoluteTime previousActualFrameTime;
}
-(id)initWithURL:(NSURL*)url
{
  if (!(self = [super init]))
  {
    return nil;
  }
  self.url = url;
  self.shouldRepeat = NO;
  keepLooping = NO;
  self.playAtActualSpeed = YES;
  return self;
}

-(void)dealloc
{
  
}

-(void)startProcessing
{
  if(self.shouldRepeat)keepLooping=YES;
  previousFrameTime = kCMTimeZero;
  previousActualFrameTime = CFAbsoluteTimeGetCurrent();
  NSDictionary *inputOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
  self.asset = [[AVURLAsset alloc] initWithURL:self.url options:inputOptions];
  FileDecoder __weak *weakself = self;
  [self.asset loadValuesAsynchronouslyForKeys:[NSArray arrayWithObject:@"tracks"] completionHandler:^{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      NSError *error = nil;
      AVKeyValueStatus tracksStatus = [weakself.asset statusOfValueForKey:@"tracks" error:&error];
      if (tracksStatus != AVKeyValueStatusLoaded)
      {
        return;
      }
     
      [weakself processAsset];
      
    });
  }];
}
-(void)cancelProcessing
{
  if(self.reader){
    [self.reader cancelReading];
  }
  [self endProcessing];
}

-(void)endProcessing
{
  keepLooping = NO;
  if(self.delegate){
    [self.delegate didCompletePlayingMovie];
  }
}

-(AVAssetReader*)createAssetReader
{
  NSError* error = nil;
  AVAssetReader* assetReader = [AVAssetReader assetReaderWithAsset:self.asset error:&error];
  NSMutableDictionary *outputSettings = [NSMutableDictionary dictionary];
  [outputSettings setObject:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) forKey:(id)kCVPixelBufferPixelFormatTypeKey];
  AVAssetReaderTrackOutput* readerVideoTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:[[self.asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] outputSettings:outputSettings];
  readerVideoTrackOutput.alwaysCopiesSampleData = NO;
  [assetReader addOutput:readerVideoTrackOutput];
  
  NSArray* audioTracks = [self.asset tracksWithMediaType:AVMediaTypeAudio];
  //判断是否有音频数据
  BOOL shouldRecordAudioTrack = [audioTracks count] > 0;
  if(shouldRecordAudioTrack){
    AVAssetTrack* audioTrack = [audioTracks objectAtIndex:0];
    NSDictionary * audioOutputSettings = @{
                                           AVFormatIDKey:@(kAudioFormatLinearPCM),
                                           //AVLinearPCMIsBigEndianKey:@NO,
                                           //AVLinearPCMIsFloatKey:@NO,
                                           //AVLinearPCMBitDepthKey:@(16),
                                           //AVSampleRateKey:@(44100)
                                           };
    AVAssetReaderTrackOutput* readerAudioTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:audioOutputSettings];
    readerAudioTrackOutput.alwaysCopiesSampleData = NO;
    [assetReader addOutput:readerAudioTrackOutput];
  }
  return assetReader;
}

-(void)processAsset
{
  self.reader = [self createAssetReader];
  AVAssetReaderOutput *readerVideoTrackOutput = nil;
  AVAssetReaderOutput *readerAudioTrackOutput = nil;
  audioEncodingIsFinished = YES;
  for( AVAssetReaderOutput *output in self.reader.outputs ) {
    if( [output.mediaType isEqualToString:AVMediaTypeAudio] ) {
      audioEncodingIsFinished = NO;
      readerAudioTrackOutput = output;
    }
    else if( [output.mediaType isEqualToString:AVMediaTypeVideo] ) {
      readerVideoTrackOutput = output;
    }
  }
  
  if ([self.reader startReading] == NO)
  {
    NSLog(@"Error reading from file at URL: %@", self.url);
    return;
  }
  
  //begin read
  while(self.reader.status == AVAssetReaderStatusReading && (!self.shouldRepeat || keepLooping))
  {
    [self readNextVideoFrameFromOutput:readerVideoTrackOutput];
    if(readerAudioTrackOutput && !audioEncodingIsFinished){
      [self readNextAudioSampleFromOutput:readerAudioTrackOutput];
    }
  }
  
  if(self.reader.status ==  AVAssetReaderStatusCompleted){
    [self.reader cancelReading];
    if(keepLooping){
      self.reader = nil;
      dispatch_async(dispatch_get_main_queue(), ^{
        [self startProcessing];
      });
    }else{
      [self endProcessing];
    }
  }
  
}

- (void)readNextVideoFrameFromOutput:(AVAssetReaderOutput *)readerVideoTrackOutput
{
  if(self.reader.status == AVAssetReaderStatusReading && !videoEncodingIsFinished){
    CMSampleBufferRef sampleBufferRef = [readerVideoTrackOutput copyNextSampleBuffer];
    if(sampleBufferRef){
      if(self.playAtActualSpeed){
        CMTime currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBufferRef);
        CMTime differenceFromLastFrame = CMTimeSubtract(currentSampleTime, previousFrameTime);
        CFAbsoluteTime currentActualTime = CFAbsoluteTimeGetCurrent();
        
        CGFloat frameTimeDifference = CMTimeGetSeconds(differenceFromLastFrame);
        CGFloat actualTimeDifference = currentActualTime - previousActualFrameTime;
        
        if (frameTimeDifference > actualTimeDifference)
        {
          usleep(1000000.0 * (frameTimeDifference - actualTimeDifference));
        }
        
        previousFrameTime = currentSampleTime;
        previousActualFrameTime = CFAbsoluteTimeGetCurrent();
      }
      [self.delegate didVideoOutput:sampleBufferRef];
      CMSampleBufferInvalidate(sampleBufferRef);
      CFRelease(sampleBufferRef);
    }else{
      if (!keepLooping) {
        videoEncodingIsFinished = YES;
        if( videoEncodingIsFinished && audioEncodingIsFinished )
          [self endProcessing];
      }
    }
  }
}

- (void)readNextAudioSampleFromOutput:(AVAssetReaderOutput *)readerAudioTrackOutput
{
  if (self.reader.status == AVAssetReaderStatusReading && ! audioEncodingIsFinished){
    CMSampleBufferRef audioSampleBufferRef = [readerAudioTrackOutput copyNextSampleBuffer];
    if(audioSampleBufferRef){
      CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(audioSampleBufferRef);
      const AudioStreamBasicDescription* asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
      
      [self.delegate didAudioOutput:audioSampleBufferRef];
      CFRelease(audioSampleBufferRef);
    }else{
      if (!keepLooping) {
        audioEncodingIsFinished = YES;
        if( videoEncodingIsFinished && audioEncodingIsFinished )
          [self endProcessing];
      }
    }
  }
}

@end












































