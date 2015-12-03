//
//  XXBVoicePlayerTools.m
//  XXBVoicePlayer
//
//  Created by xiaobing on 15/11/20.
//  Copyright © 2015年 xiaobing. All rights reserved.
//

#import "XXBVoicePlayerTools.h"
#import <AVFoundation/AVFoundation.h>

@interface XXBVoicePlayerTools ()<AVAudioPlayerDelegate>

@property(nonatomic , copy) NSString  *path;

@end

@implementation XXBVoicePlayerTools
XXBSingletonM(XXBVoicePlayerTools);
/**
 *  初始化
 */
+ (void)initialize
{
    // 设置音频会话类型
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategorySoloAmbient error:nil];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    [session setActive:YES error:nil];
}
- (void)playVoiceWithParth:(NSString *)path
{
    [self stopPlayVoice];
    _audioPlayer = nil;
    self.path = path;
    [self.audioPlayer play];
}

/**
 *  暂停播放声音
 */
- (void)stopPlayVoice
{
    [self.audioPlayer stop];
}

/**
 *  暂停播放声音
 */
- (void)pausePlayVoice
{
    [self.audioPlayer pause];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError * __nullable)error
{
    
}
- (void)setPath:(NSString *)path
{
    _path = [path copy];
}
- (AVAudioPlayer *)audioPlayer
{
    if (_audioPlayer == nil)
    {
        NSString *path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:self.path];
        NSURL *url = [NSURL fileURLWithPath:path];
        _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
        _audioPlayer.delegate = self;
        [_audioPlayer prepareToPlay];
        NSLog(@"%@",@(_audioPlayer.duration));
    }
    return _audioPlayer;
}
@end
