//
//  SNBRecordViewController.m
//  XXBVoicePlayer
//
//  Created by xiaobing on 15/12/3.
//  Copyright © 2015年 xiaobing. All rights reserved.
//

#import "SNBRecordViewController.h"
#import "SNBRecordVoiceTools.h"
#import "SNBMp3RecordWriter.h"
#import <AVFoundation/AVFoundation.h>
#import "XXBVoicePlayerTools.h"

@interface SNBRecordViewController ()<SNBRecordVoiceToolsDelegate>
@property (nonatomic, strong) SNBMp3RecordWriter        *mp3Writer;
@property (nonatomic, copy) NSString                    *filePath;
@property (nonatomic, strong) SNBRecordVoiceTools       *recorder;
@property (weak, nonatomic) IBOutlet UILabel            *message1;
@property (weak, nonatomic) IBOutlet UILabel            *message2;
@property(nonatomic , assign) int                       count;
@end

@implementation SNBRecordViewController
- (IBAction)startRecord:(id)sender
{
    // Do any additional setup after loading the view, typically from a nib.
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    if (self.count <= 0)
    {
        self.count = 0;
    }
    self.count ++;
    NSString *fileName = [NSString stringWithFormat:@"%02d.mp3",self.count];
    self.filePath = [path stringByAppendingPathComponent:fileName];
    self.mp3Writer.filePath = self.filePath;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionDidChangeInterruptionType:) name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];
    
    [self.recorder startRecordVoice];
}

- (void)audioSessionDidChangeInterruptionType:(NSNotification *)notification
{
    AVAudioSessionInterruptionType interruptionType = [[[notification userInfo]
                                                        objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (AVAudioSessionInterruptionTypeBegan == interruptionType)
    {
        NSLog(@"begin");
    }
    else if (AVAudioSessionInterruptionTypeEnded == interruptionType)
    {
        NSLog(@"end");
    }
}
- (void)recordVoiceTools:(SNBRecordVoiceTools *)recordVoiceTools voiceLengthDidChange:(CGFloat)voiceLength
{
    self.message2.text = [NSString stringWithFormat:@"%@",@(voiceLength)];
}
- (void)recordVoiceTools:(SNBRecordVoiceTools *)recordVoiceTools voicePowerDidChange:(CGFloat)voicePower
{
    self.message1.text = [NSString stringWithFormat:@"%.2f",voicePower];
}
- (IBAction)stopRecord:(id)sender
{
    //取消录音
    [self.recorder stopRecordVoice];
}
- (IBAction)pause:(id)sender
{
    [self.recorder pauseRecordVoice];
}
- (IBAction)continue:(id)sender
{
    [self.recorder continueRecordVoice];
}
- (IBAction)playVoice:(id)sender
{
    [[XXBVoicePlayerTools sharedXXBVoicePlayerTools] playVoiceWithParth:self.filePath];
}
- (SNBRecordVoiceTools *)recorder
{
    if (_recorder == nil)
    {
        SNBRecordVoiceTools *recorder = [[SNBRecordVoiceTools alloc]init];
        recorder.delegate = self;
        recorder.fileWriterDelegate = self.mp3Writer;
        _recorder = recorder;
    }
    return _recorder;
}
- (SNBMp3RecordWriter *)mp3Writer
{
    if (_mp3Writer == nil)
    {
        SNBMp3RecordWriter *mp3Writer = [[SNBMp3RecordWriter alloc]init];
        mp3Writer.maxSecondCount = 60;
        /**
         *  录音文件的大小是 10M
         */
        mp3Writer.maxFileSize = 1024 * 1024 * 10;
        self.mp3Writer = mp3Writer;
        _mp3Writer = mp3Writer;
    }
    return _mp3Writer;
}
@end
