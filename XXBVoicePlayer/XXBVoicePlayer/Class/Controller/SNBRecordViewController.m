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

@interface SNBRecordViewController ()
@property (nonatomic, strong) SNBMp3RecordWriter *mp3Writer;
@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, strong) SNBRecordVoiceTools *recorder;
@end

@implementation SNBRecordViewController
- (IBAction)startRecord:(id)sender
{
    // Do any additional setup after loading the view, typically from a nib.
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    SNBMp3RecordWriter *mp3Writer = [[SNBMp3RecordWriter alloc]init];
    mp3Writer.filePath = [path stringByAppendingPathComponent:@"record.mp3"];
    mp3Writer.maxSecondCount = 60;
    mp3Writer.maxFileSize = 1024*256;
    self.mp3Writer = mp3Writer;
    SNBRecordVoiceTools *recorder = [[SNBRecordVoiceTools alloc]init];

    recorder.fileWriterDelegate = mp3Writer;
    self.filePath = mp3Writer.filePath;
    self.recorder = recorder;
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
    [[XXBVoicePlayerTools sharedXXBVoicePlayerTools] playVoiceWithParth:@"record.mp3"];
}

@end
