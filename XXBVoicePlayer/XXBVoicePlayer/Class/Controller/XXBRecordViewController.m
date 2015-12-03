//
//  XXBRecordViewController.m
//  XXBVoicePlayer
//
//  Created by xiaobing on 15/11/20.
//  Copyright © 2015年 xiaobing. All rights reserved.
//

#import "XXBRecordViewController.h"
#import "XXBRecordVoiceTools.h"
#import "XXBVoicePlayerTools.h"
#import <AVFoundation/AVFoundation.h>
#import <lame/lame.h>

@interface XXBRecordViewController ()<XXBRecordVoiceToolsDelegate,AVAudioPlayerDelegate>
@property (weak, nonatomic) IBOutlet UIButton *RecordButton;
@property (weak, nonatomic) IBOutlet UILabel *messageLabel;
@property (weak, nonatomic) IBOutlet UILabel *voiceLengthLabel;
- (IBAction)recordButtonClick:(id)sender;

@end

@implementation XXBRecordViewController

- (IBAction)recordButtonClick:(id)sender
{
    self.RecordButton.selected = !self.RecordButton.selected;
    
    [XXBRecordVoiceTools sharedXXBRecordVoiceTools].delegate = self;
    self.RecordButton.selected? [[XXBRecordVoiceTools sharedXXBRecordVoiceTools] startRecordVoiceWithName:@"test.caf"] : [[XXBRecordVoiceTools sharedXXBRecordVoiceTools] stopRecordVoice];
}
- (IBAction)pause:(id)sender {
    [[XXBRecordVoiceTools sharedXXBRecordVoiceTools] pauseRecordVoice];
}
- (IBAction)continue:(id)sender {
    [[XXBRecordVoiceTools sharedXXBRecordVoiceTools] continueRecordVoice];
}

- (void)recordVoiceTools:(XXBRecordVoiceTools *)recordVoiceTools voicePowerDidChange:(CGFloat)voicePower
{
    self.messageLabel.text = [NSString stringWithFormat:@"%@",@(voicePower)];
}
- (void)recordVoiceTools:(XXBRecordVoiceTools *)recordVoiceTools voiceLengthDidChange:(CGFloat)voiceLength
{
    self.voiceLengthLabel.text = [NSString stringWithFormat:@"%.2f",voiceLength];
}
- (void)recordVoiceToolsDidFailRecording:(XXBRecordVoiceTools *)recordVoiceTools error:(NSError *)error
{
    NSLog(@"+++++>>>>%@",error);
}
-(IBAction)playButtonAction:(id)sender
{
    [[XXBVoicePlayerTools sharedXXBVoicePlayerTools] playVoiceWithParth:@"test.caf"];
}

- (IBAction)encodToMP3:(id)sender
{
    [[XXBRecordVoiceTools sharedXXBRecordVoiceTools] toMP3WithFileName:@"test.caf"];
}

- (IBAction)playMP3:(id)sender {
    [[XXBVoicePlayerTools sharedXXBVoicePlayerTools] playVoiceWithParth:@"test.mp3"];
}
@end
