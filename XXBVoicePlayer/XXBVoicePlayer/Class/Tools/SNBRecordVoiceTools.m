//
//  SNBRecordVoiceTools.m
//  XXBVoicePlayer
//
//  Created by xiaobing on 15/12/3.
//  Copyright © 2015年 xiaobing. All rights reserved.
//

#import "SNBRecordVoiceTools.h"
#import <AVFoundation/AVFoundation.h>
/**
 *  缓存区的个数，3个一般不用改
 */
#define SNBNumberAudioQueueBuffers 3
/**
 *  每次的音频输入队列缓存区所保存的是多少秒的数据
 */
#define SNBDefaultBufferDurationSeconds 0.5
/**
 *  采样率，要转码为amr的话必须为8000
 */
#define SNBDefaultSampleRate 8000
#define SNBTime 0.1

#define SNBMLAudioRecorderErrorDomain @"SNBAudioRecorderErrorDomain"

#define IfAudioQueueErrorPostAndReturn(operation,error) \
if(operation!=noErr) { \
[self postAErrorWithErrorCode:SNBAudioRecorderErrorCodeAboutQueue andDescription:error]; \
return; \
}

@interface SNBRecordVoiceTools ()
{
    //音频输入缓冲区
    AudioQueueBufferRef         _audioBuffers[SNBNumberAudioQueueBuffers];
    
    AudioQueueLevelMeterState	*_levelMeterStates;
}

@property (nonatomic, strong) dispatch_queue_t      writeFileQueue;
/**
 *  一个信号量，用来保证队列中写文件错误事件处理只调用一次
 */
@property (nonatomic, strong) dispatch_semaphore_t  semError;
/**
 *  是否正在录音
 */
@property (nonatomic, assign) BOOL                  isRecording;
/**
 *  用于会掉的定时器
 */
@property(nonatomic , strong) NSTimer               *backTimer;
@property (nonatomic, assign) NSUInteger            channelCount;
@property(nonatomic , assign) CGFloat               voiceLength;
@end
@implementation SNBRecordVoiceTools
- (instancetype)init
{
    self = [super init];
    if (self) {
        //建立写入文件线程队列,串行，和一个信号量标识
        self.writeFileQueue = dispatch_queue_create("writeFileQueue", DISPATCH_QUEUE_SERIAL);
        self.sampleRate = SNBDefaultSampleRate;
        self.bufferDurationSeconds = SNBDefaultBufferDurationSeconds;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionInterruption:) name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];
    }
    return self;
}

- (void)dealloc
{
    //    NSAssert(!self.isRecording, @"SNBRecordVoiceTools dealloc之前必须停止录音");
    if (self.isRecording){
        [self stopRecordVoice];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)startRecordVoice
{
    NSAssert(!self.isRecording, @"录音必须先停止上一个才可开始新的");
    NSError *error = nil;
    //设置audio session的category
    BOOL ret = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if (!ret)
    {
        [self postAErrorWithErrorCode:SNBAudioRecorderErrorCodeAboutSession andDescription:@"为AVAudioSession设置Category失败"];
        return;
    }
    //启用audio session
    ret = [[AVAudioSession sharedInstance] setActive:YES error:&error];
    if (!ret)
    {
        [self postAErrorWithErrorCode:SNBAudioRecorderErrorCodeAboutSession andDescription:@"Active AVAudioSession失败"];
        return;
    }
    
    if(!self.fileWriterDelegate||![self.fileWriterDelegate respondsToSelector:@selector(createFileWithRecorder:)]||![self.fileWriterDelegate respondsToSelector:@selector(writeIntoFileWithData:withRecorder:inAQ:inStartTime:inNumPackets:inPacketDesc:)]||![self.fileWriterDelegate respondsToSelector:@selector(completeWriteWithRecorder:withIsError:)])
    {
        [self postAErrorWithErrorCode:SNBAudioRecorderErrorCodeAboutOther andDescription:@"fileWriterDelegate的代理未设置或其代理方法不完整"];
        return;
    }
    
    //设置录音的format数据
    if (self.fileWriterDelegate&&[self.fileWriterDelegate respondsToSelector:@selector(customAudioFormatBeforeCreateFile)])
    {
        dispatch_sync(self.writeFileQueue, ^{
            AudioStreamBasicDescription format = [self.fileWriterDelegate customAudioFormatBeforeCreateFile];
            memcpy(&_recordFormat, &format,sizeof(_recordFormat));
        });
    }
    else
    {
        [self setupAudioFormat:kAudioFormatLinearPCM SampleRate:self.sampleRate];
    }
    _recordFormat.mSampleRate = self.sampleRate;
    //建立文件,顺便同步下串行队列，防止意外前面有没处理的
    __block BOOL isContinue = YES;;
    dispatch_sync(self.writeFileQueue, ^{
        if(self.fileWriterDelegate&&![self.fileWriterDelegate createFileWithRecorder:self])
        {
            dispatch_async(dispatch_get_main_queue(),^{
                [self postAErrorWithErrorCode:SNBAudioRecorderErrorCodeAboutFile andDescription:@"为音频输入建立文件失败"];
            });
            isContinue = NO;
        }
    });
    if(!isContinue)
    {
        return;
    }
    self.semError = dispatch_semaphore_create(0);   //重新初始化信号量标识
    dispatch_semaphore_signal(self.semError);       //设置有一个信号
    //设置录音的回调函数
    IfAudioQueueErrorPostAndReturn(AudioQueueNewInput(&_recordFormat, inputBufferHandler, (__bridge void *)(self), NULL, NULL, 0, &_audioQueue),@"音频输入队列初始化失败");
    //计算估算的缓存区大小
    int frames = (int)ceil(self.bufferDurationSeconds * _recordFormat.mSampleRate);
    int bufferByteSize = frames * _recordFormat.mBytesPerFrame;
    //创建缓冲器
    for (int i = 0; i < SNBNumberAudioQueueBuffers; i++)
    {
        IfAudioQueueErrorPostAndReturn(AudioQueueAllocateBuffer(_audioQueue, bufferByteSize, &_audioBuffers[i]),@"为音频输入队列建立缓冲区失败");
        IfAudioQueueErrorPostAndReturn(AudioQueueEnqueueBuffer(_audioQueue, _audioBuffers[i], 0, NULL),@"为音频输入队列缓冲区做准备失败");
    }
    
    // 开始录音
    IfAudioQueueErrorPostAndReturn(AudioQueueStart(_audioQueue, NULL),@"开始音频输入队列失败");
    self.isRecording = YES;
    self.voiceLength = 0.0;
    [self p_startTimer];
}


/**
 *  暂停录音
 */
- (void)pauseRecordVoice
{
    AudioQueuePause(_audioQueue);
    [self p_stopTimer];
}

/**
 *  继续录音
 */
- (void)continueRecordVoice
{
    AudioQueueStart(_audioQueue, NULL);
    [self p_startTimer];
}

- (void)stopRecordVoice
{
    [self p_stopTimer];
    if (self.isRecording)
    {
        self.isRecording = NO;
        //停止录音队列和移除缓冲区,以及关闭session，这里无需考虑成功与否
        AudioQueueStop(_audioQueue, true);
        AudioQueueDispose(_audioQueue, true);
        [[AVAudioSession sharedInstance] setActive:NO error:nil];
        
        //这里直接做同步
        __block BOOL isFinish = YES;
        dispatch_sync(self.writeFileQueue, ^{
            if (self.fileWriterDelegate&&![self.fileWriterDelegate completeWriteWithRecorder:self withIsError:NO])
            {
                dispatch_async(dispatch_get_main_queue(),^{
                    [self postAErrorWithErrorCode:SNBAudioRecorderErrorCodeAboutFile andDescription:@"音频输入关闭文件失败"];
                });
                isFinish = NO;
            }
        });
        if ([self.delegate respondsToSelector:@selector(recordVoiceToolsDidFinishRecording:successfully:)])
        {
            [self.delegate recordVoiceToolsDidFinishRecording:self successfully:isFinish];
        }
    }
}

- (void)p_startTimer
{
    [[NSRunLoop currentRunLoop] addTimer:self.backTimer forMode:NSRunLoopCommonModes];
}
- (void)p_stopTimer
{
    [self.backTimer invalidate];
    self.backTimer = nil;
}
// 设置录音格式
- (void)setupAudioFormat:(UInt32) inFormatID SampleRate:(NSUInteger)sampeleRate
{
    //重置下
    memset(&_recordFormat, 0, sizeof(_recordFormat));
    //设置采样率，这里先获取系统默认的测试下 //TODO:
    //采样率的意思是每秒需要采集的帧数
    _recordFormat.mSampleRate = sampeleRate;//[[AVAudioSession sharedInstance] sampleRate];
    
    //设置通道数,这里先使用系统的测试下 //TODO:
    _recordFormat.mChannelsPerFrame = 1;//(UInt32)[[AVAudioSession sharedInstance] inputNumberOfChannels];
    //设置format，怎么称呼不知道。
    _recordFormat.mFormatID = inFormatID;
    
    if (inFormatID == kAudioFormatLinearPCM){
        //这个屌属性不知道干啥的。，
        _recordFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        //每个通道里，一帧采集的bit数目
        _recordFormat.mBitsPerChannel = 16;
        //结果分析: 8bit为1byte，即为1个通道里1帧需要采集2byte数据，再*通道数，即为所有通道采集的byte数目。
        //所以这里结果赋值给每帧需要采集的byte数目，然后这里的packet也等于一帧的数据。
        //至于为什么要这样。。。不知道。。。
        _recordFormat.mBytesPerPacket = _recordFormat.mBytesPerFrame = (_recordFormat.mBitsPerChannel / 8) * _recordFormat.mChannelsPerFrame;
        _recordFormat.mFramesPerPacket = 1;
    }
}

// 回调函数
void inputBufferHandler(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer, const AudioTimeStamp *inStartTime,UInt32 inNumPackets, const AudioStreamPacketDescription *inPacketDesc)
{
    SNBRecordVoiceTools *recorder = (__bridge SNBRecordVoiceTools*)inUserData;
    
    if (inNumPackets > 0) {
        NSData *pcmData = [[NSData alloc]initWithBytes:inBuffer->mAudioData length:inBuffer->mAudioDataByteSize];
        if (pcmData&&pcmData.length>0)
        {
            //在后台串行队列中去处理文件写入
            dispatch_async(recorder.writeFileQueue, ^{
                if(recorder.fileWriterDelegate&&![recorder.fileWriterDelegate writeIntoFileWithData:pcmData withRecorder:recorder inAQ:inAQ inStartTime:inStartTime inNumPackets:inNumPackets inPacketDesc:inPacketDesc]){
                    //保证只处理了一次
                    if (dispatch_semaphore_wait(recorder.semError,DISPATCH_TIME_NOW) == 0)
                    {
                        //回到主线程
                        dispatch_async(dispatch_get_main_queue(),^{
                            [recorder postAErrorWithErrorCode:SNBAudioRecorderErrorCodeAboutFile andDescription:@"写入文件失败"];
                        });
                    }
                }
            });
        }
    }
    
    if (recorder.isRecording)
    {
        if(AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL)!=noErr){
            recorder.isRecording = NO; //这里直接设置下，能防止队列中3个缓存，重复post error
            //回到主线程
            dispatch_async(dispatch_get_main_queue(),^{
                [recorder postAErrorWithErrorCode:SNBAudioRecorderErrorCodeAboutQueue andDescription:@"重准备音频输入缓存区失败"];
            });
        }
    }
}

- (NSTimer *)backTimer
{
    if(_backTimer == nil)
    {
        //检测这玩意是否支持光谱图
        UInt32 val = 1;
        if(AudioQueueSetProperty(_audioQueue, kAudioQueueProperty_EnableLevelMetering, &val, sizeof(UInt32)) != noErr)
        {
            [self postAErrorWithErrorCode:SNBAudioRecorderErrorCodeAboutQueue andDescription:@"couldn't enable metering"];
            return nil;
        }
        if (!val){
            NSLog(@"不支持光谱图"); //需要发送错误
            return nil;
        }
        
        // now check the number of channels in the new queue, we will need to reallocate if this has changed
        AudioStreamBasicDescription queueFormat;
        UInt32 data_sz = sizeof(queueFormat);
        if(AudioQueueGetProperty(_audioQueue, kAudioQueueProperty_StreamDescription, &queueFormat, &data_sz) != noErr)
        {
            [self postAErrorWithErrorCode:SNBAudioRecorderErrorCodeAboutQueue andDescription:@"couldn't get stream description"];
            return nil;
        }
        self.channelCount = queueFormat.mChannelsPerFrame;
        //重新初始化大小
        _levelMeterStates = (AudioQueueLevelMeterState*)realloc(_levelMeterStates, self.channelCount * sizeof(AudioQueueLevelMeterState));
        _backTimer =  [NSTimer scheduledTimerWithTimeInterval:SNBTime target:self selector:@selector(p_refreshCallBack) userInfo:nil repeats:YES];
    }
    return _backTimer;
}

- (void)p_refreshCallBack
{
    
    UInt32 data_sz = (UInt32)(sizeof(AudioQueueLevelMeterState) * self.channelCount);
    
    IfAudioQueueErrorPostAndReturn(AudioQueueGetProperty(_audioQueue, kAudioQueueProperty_CurrentLevelMeterDB, _levelMeterStates, &data_sz),@"获取meter数据失败");
    
    //转化成LevelMeterState数组传递到block
    NSMutableArray *meters = [NSMutableArray arrayWithCapacity:self.channelCount];
    
    for (int i=0; i<self.channelCount; i++)
    {
        [meters addObject:
         @{
           @"mAveragePower":@(_levelMeterStates[i].mAveragePower),
           @"mPeakPower":@( _levelMeterStates[i].mPeakPower)
           }];
    }
    Float32 averagePowerOfChannels = 0;
    for (int i=0; i<meters.count; i++)
    {
        averagePowerOfChannels += [meters[i][@"mAveragePower"] floatValue];
    }
    
    //获取音量百分比
    Float32 volume = pow(10, (0.05 * averagePowerOfChannels/meters.count));
    self.voiceLength += SNBTime;
    if([self.delegate respondsToSelector:@selector(recordVoiceTools:voiceLengthDidChange:)])
    {
        [self.delegate recordVoiceTools:self voiceLengthDidChange:self.voiceLength];
    }
    if ([self.delegate respondsToSelector:@selector(recordVoiceTools:voicePowerDidChange:)])
    {
        [self.delegate recordVoiceTools:self voicePowerDidChange:volume];
    }
}

/**
 *  错误的相关会掉
 *
 *  @param code        错误码
 *  @param description 错误的消息
 */
- (void)postAErrorWithErrorCode:(SNBAudioRecorderErrorCode)code andDescription:(NSString*)description
{
    //关闭可能还未关闭的东西,无需考虑结果
    self.isRecording = NO;
    AudioQueueStop(_audioQueue, true);
    AudioQueueDispose(_audioQueue, true);
    [[AVAudioSession sharedInstance] setActive:NO error:nil];
    
    if(self.fileWriterDelegate)
    {
        dispatch_sync(self.writeFileQueue, ^{
            [self.fileWriterDelegate completeWriteWithRecorder:self withIsError:YES];
        });
    }
    NSError *error = [NSError errorWithDomain:SNBMLAudioRecorderErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey:description}];
    if ([self.delegate respondsToSelector:@selector(recordVoiceToolsDidFailRecording:error:)])
    {
        [self.delegate recordVoiceToolsDidFailRecording:self error:error];
    }
}

#pragma mark - notification
- (void)sessionInterruption:(NSNotification *)notification
{
    AVAudioSessionInterruptionType interruptionType = [[[notification userInfo] objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (AVAudioSessionInterruptionTypeBegan == interruptionType)
    {
        NSLog(@"begin interruption");
        //直接停止录音
        [self stopRecordVoice];
    }
    else if (AVAudioSessionInterruptionTypeEnded == interruptionType)
    {
        NSLog(@"end interruption");
    }
}
@end
