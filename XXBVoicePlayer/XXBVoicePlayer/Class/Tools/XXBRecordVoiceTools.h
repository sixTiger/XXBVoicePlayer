//
//  XXBRecordVoiceTools.h
//  XXBVoicePlayer
//
//  Created by xiaobing on 15/11/20.
//  Copyright © 2015年 xiaobing. All rights reserved.
//  录音 

#import <Foundation/Foundation.h>
#import <XXBLibs.h>
@class XXBRecordVoiceTools;

@protocol XXBRecordVoiceToolsDelegate <NSObject>
@optional
/**
 *  停止录音
 */
- (void)recordVoiceToolsDidStopRecord:(XXBRecordVoiceTools *)recordVoiceTools;

/**
 *  声音的分贝
 *
 *  @param voicePower       当前的声音的分贝
 */
- (void)recordVoiceTools:(XXBRecordVoiceTools *)recordVoiceTools voicePowerDidChange:(CGFloat)voicePower;

/**
 *  声音的长度开始变化
 *
 *  @param voicePower       当前的声音的长度
 */
- (void)recordVoiceTools:(XXBRecordVoiceTools *)recordVoiceTools voiceLengthDidChange:(CGFloat)voiceLength;


/**
 *  录音完成的回调
 *
 *  @param flag             录音是否成功
 */
- (void)recordVoiceToolsDidFinishRecording:(XXBRecordVoiceTools *)recordVoiceTools successfully:(BOOL)flag;
/**
 *  录音错误的会掉
 *
 *  @param error            错误的原因
 */
- (void)recordVoiceToolsDidFailRecording:(XXBRecordVoiceTools *)recordVoiceTools error:(NSError *)error;
@end


@interface XXBRecordVoiceTools : NSObject
XXBSingletonH(XXBRecordVoiceTools);

@property(nonatomic , weak) id<XXBRecordVoiceToolsDelegate>     delegate;

/**
 *  录音时长默认两分钟
 */
@property(nonatomic , assign) CGFloat                           defaultVoiceTime;

/**
 *  是否自动停止录音 默认是否
 */
@property(nonatomic , assign) BOOL                              autoStop;

/**
 *  默认的等待时间 3秒
 */
@property(nonatomic , assign) CGFloat                           defaultWaitTime;

/**
 *  开始录音
 *
 *  @param voiceName 录音文件的名字 
 *
 *  默认是在document目录下边的
 */
- (void)startRecordVoiceWithName:(NSString *)voiceName;

/**
 *  开始录音
 *
 *  @param voicePath 录音文件的路径
 */
- (void)startRecordVoiceWithPath:(NSString *)voicePath;

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

/**
 *  是否可以录音
 *
 *  @return 录音的状态
 */
- (BOOL)canRecordVoice;

/**
 *  把一个录音文件转成MP3格式
 *
 *  @param filePath 要转换格式的文件
 *
 *  @return 转换完格式的文件的路径
 */
- (NSString *)toMP3WithFilePath:(NSString *)filePath;

/**
 *  把一个录音文件转成MP3格式 默认在Document 路径下边
 *
 *  @param name 要转换的文件的名字
 *
 *  @return 转换玩的mp3文件的路径
 */
- (NSString *)toMP3WithFileName:(NSString *)name;
@end
