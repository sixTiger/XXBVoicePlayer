//
//  SNBRecordVoiceTools.h
//  XXBVoicePlayer
//
//  Created by xiaobing on 15/12/3.
//  Copyright © 2015年 xiaobing. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <UIKit/UIKit.h>


/**
 *  错误标识
 */
typedef NS_OPTIONS(NSUInteger, SNBAudioRecorderErrorCode) {
    SNBAudioRecorderErrorCodeAboutFile = 0,     //关于文件操作的错误
    SNBAudioRecorderErrorCodeAboutQueue,        //关于音频输入队列的错误
    SNBAudioRecorderErrorCodeAboutSession,      //关于audio session的错误
    SNBAudioRecorderErrorCodeAboutOther,        //关于其他的错误
};

@class SNBRecordVoiceTools;

/**
 *  处理写文件操作的，实际是转码的操作在其中进行。算作可扩展自定义的转码器
 *  当然如果是实时语音的需求的话，就可以在此处理编码后发送语音数据到对方
 *  PS:这里的三个方法是在后台线程中处理的
 */
@protocol FileWriterForSNBRecordVoiceTools <NSObject>

@optional
- (AudioStreamBasicDescription)customAudioFormatBeforeCreateFile;

@required
/**
 *  在录音开始时候建立文件和写入文件头信息等操作
 *
 */
- (BOOL)createFileWithRecorder:(SNBRecordVoiceTools*)recoder;

/**
 *  写入音频输入数据，内部处理转码等其他逻辑
 *  能传递过来的都传递了。以方便多能扩展使用
 */
- (BOOL)writeIntoFileWithData:(NSData*)data withRecorder:(SNBRecordVoiceTools*)recoder inAQ:(AudioQueueRef)inAQ inStartTime:(const AudioTimeStamp *)inStartTime inNumPackets:(UInt32)inNumPackets inPacketDesc:(const AudioStreamPacketDescription*)inPacketDesc;

/**
 *  文件写入完成之后的操作，例如文件句柄关闭等,isError表示是否是因为错误才调用的
 *
 */
- (BOOL)completeWriteWithRecorder:(SNBRecordVoiceTools*)recoder withIsError:(BOOL)isError;

@end


/**
 *  录音结果的相关回调
 */
@protocol SNBRecordVoiceToolsDelegate <NSObject>
@optional
/**
 *  声音的分贝
 *
 *  @param voicePower       当前的声音的分贝
 */
- (void)recordVoiceTools:(SNBRecordVoiceTools *)recordVoiceTools voicePowerDidChange:(CGFloat)voicePower;

/**
 *  声音的长度开始变化
 *
 *  @param voicePower       当前的声音的长度
 */
- (void)recordVoiceTools:(SNBRecordVoiceTools *)recordVoiceTools voiceLengthDidChange:(CGFloat)voiceLength;

/**
 *  录音完成的回调
 *
 *  @param flag             录音是否成功
 */
- (void)recordVoiceToolsDidFinishRecording:(SNBRecordVoiceTools *)recordVoiceTools successfully:(BOOL)flag;


/**
 *  录音错误的回调
 *
 *  @param error            错误的原因
 */
- (void)recordVoiceToolsDidFailRecording:(SNBRecordVoiceTools *)recordVoiceTools error:(NSError *)error;
@end

@interface SNBRecordVoiceTools : NSObject
{
    //音频输入队列
    AudioQueueRef				_audioQueue;
    //音频输入数据format
    AudioStreamBasicDescription	_recordFormat;
}
/**
 *  是否正在录音
 */
@property (atomic, assign,readonly) BOOL                            isRecording;

/**
 *  这俩是当前的采样率和缓冲区采集秒数，根据情况可以设置(对其设置必须在startRecording之前才有效)，随意设置可能有意外发生。
 *  这俩属性被标识为原子性的，读取写入是线程安全的。
 */
@property (atomic, assign) NSUInteger                               sampleRate;
@property (atomic, assign) double                                   bufferDurationSeconds;
/**
 *  处理写文件操作的，实际是转码的操作在其中进行。算作可扩展自定义的转码器
 */
@property (nonatomic, weak) id<FileWriterForSNBRecordVoiceTools>    fileWriterDelegate;

@property(nonatomic , weak) id<SNBRecordVoiceToolsDelegate>         delegate;

/**
 *  开始录音
 *
 *  @param voicePath 录音文件的路径
 */
- (void)startRecordVoice;

/**
 *  暂停录音
 */
- (void)pauseRecordVoice;

/**
 *  继续录音
 */
- (void)continueRecordVoice;

/**
 *  停止录音
 */
- (void)stopRecordVoice;
@end
