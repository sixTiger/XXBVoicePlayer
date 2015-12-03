//
//  XXBVoicePlayerTools.h
//  XXBVoicePlayer
//
//  Created by xiaobing on 15/11/20.
//  Copyright © 2015年 xiaobing. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <XXBLibs.h>

@interface XXBVoicePlayerTools : NSObject
XXBSingletonH(XXBVoicePlayerTools);
@property(nonatomic , strong) AVAudioPlayer     *audioPlayer;
@property(nonatomic , assign) CGFloat           voiceDurationTime;

/**
 *  开始播放声音
 *
 *  @param parth 声音文件的路径
 */
- (void)playVoiceWithParth:(NSString *)parth;

/**
 *  暂停播放声音
 */
- (void)stopPlayVoice;

/**
 *  暂停播放声音
 */
- (void)pausePlayVoice;
@end
