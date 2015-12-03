//
//  XXBRecordVoiceTools.m
//  XXBVoicePlayer
//
//  Created by xiaobing on 15/11/20.
//  Copyright © 2015年 xiaobing. All rights reserved.
//

#import "XXBRecordVoiceTools.h"
#import <AVFoundation/AVFoundation.h>
#import <lame/lame.h>

@interface XXBRecordVoiceTools ()<AVAudioRecorderDelegate>
@property(nonatomic , strong) CADisplayLink         *link;
@property(nonatomic , strong) AVAudioRecorder       *recorder;

/**
 *  当前的静止时间
 */
@property(nonatomic , assign) CGFloat               slientDuration;
/**
 *  录音格式的控制
 */
@property(nonatomic , strong) NSMutableDictionary   *settingDict;
@end
@implementation XXBRecordVoiceTools
XXBSingletonM(XXBRecordVoiceTools);
- (instancetype)init
{
    if (self = [super init])
    {
        self.defaultWaitTime = 3;
        self.defaultVoiceTime = 120;
    }
    return self;
}

- (CADisplayLink *)link
{
    if (!_link)
    {
        self.link = [CADisplayLink displayLinkWithTarget:self selector:@selector(update)];
    }
    return _link;
}

- (void)update
{
    [self.recorder updateMeters];
    float power = [self.recorder averagePowerForChannel:0.1];
    if (self.autoStop)
    {
        if (power < - 20)
        {
            self.slientDuration += self.link.duration;
            if (self.slientDuration >= self.defaultWaitTime)
            {
                [self stopRecordVoice];
            }
        }
        else
        {
            self.slientDuration = 0;
            if ([self.delegate respondsToSelector:@selector(recordVoiceTools:voicePowerDidChange:)])
            {
                [self.delegate recordVoiceTools:self voicePowerDidChange:power];
            }
            if ([self.delegate respondsToSelector:@selector(recordVoiceTools:voiceLengthDidChange:)])
            {
                [self.delegate recordVoiceTools:self voiceLengthDidChange:self.recorder.currentTime];
            }
        }
    }
    else
    {
        self.slientDuration = 0;
        if ([self.delegate respondsToSelector:@selector(recordVoiceTools:voicePowerDidChange:)])
        {
            [self.delegate recordVoiceTools:self voicePowerDidChange:power];
        }
        
        if ([self.delegate respondsToSelector:@selector(recordVoiceTools:voiceLengthDidChange:)])
        {
            [self.delegate recordVoiceTools:self voiceLengthDidChange:self.recorder.currentTime];
        }
    }
}

/**
 *  开始录音
 */
- (void)startRecordVoiceWithName:(NSString *)voiceName;
{
    
    NSString *path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:voiceName];
    [self startRecordVoiceWithPath:path];
}

- (void)startRecordVoiceWithPath:(NSString *)voicePath
{
    if ([self canRecordVoice])
    {
        [self p_startRecordVoiceWithPath:voicePath];
    }
    else
    {
        if ([self.delegate respondsToSelector:@selector(recordVoiceToolsDidFailRecording:error:)])
        {
            NSError *error = [[NSError alloc] initWithDomain:@"不允许访问麦克风" code:-1 userInfo:@{@"message":@"用户不允许访问麦克风"}];
            [self.delegate recordVoiceToolsDidFailRecording:self error:error];
        }
    }
}

/**
 *  暂停录音
 */
- (void)pauseRecordVoice
{
    [self.recorder pause];
    [self p_stopTimer];
}

/**
 *  继续录音
 */
- (void)continueRecordVoice
{
    if ([self.recorder record])
    {
        [self p_startTimer];
        NSLog(@"继续录音成功");
    }
    else
    {
        NSLog(@"继续录音失败");
    }
    
}

- (void)stopRecordVoice
{
    if ([self.recorder isRecording])
    {
        [self.recorder stop];
    }
    [self p_stopTimer];
}

- (BOOL)canRecordVoice
{
    __block BOOL canRecordVoice = NO;
    if ([[AVAudioSession sharedInstance] respondsToSelector:@selector(requestRecordPermission:)])
    {
        [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
            canRecordVoice = granted;
        }];
    }
    return canRecordVoice;
}

- (NSString *)toMP3WithFilePath:(NSString *)filePath
{
    NSString *fileName = [self p_getFileNameWithFilePath:filePath];
    fileName = [NSString stringWithFormat:@"%@.mp3",fileName];
    NSDate *startDate = [NSDate date];
    NSString *mp3FilePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:fileName];//存储mp3文件的路径
    NSFileManager* fileManager=[NSFileManager defaultManager];
    if([fileManager removeItemAtPath:mp3FilePath error:nil])
    {
        NSLog(@"文件已存在，删除了文件");
    }
    @try {
        int read, write;
        FILE *pcm = fopen([filePath cStringUsingEncoding:1], "rb");  //source
        fseek(pcm, 4*1024, SEEK_CUR);                                   //skip file header
        FILE *mp3 = fopen([mp3FilePath cStringUsingEncoding:1], "wb");  //output
        
        const int PCM_SIZE = 640;
        const int MP3_SIZE = 8192;
        short int pcm_buffer[PCM_SIZE*2];
        unsigned char mp3_buffer[MP3_SIZE];
        
        lame_t lame = lame_init();
        lame_set_in_samplerate(lame, 8000);
        lame_set_VBR(lame, vbr_default);
        lame_init_params(lame);
        do
        {
            read = (int)fread(pcm_buffer, 2*sizeof(short int), PCM_SIZE, pcm);
            if (read == 0)
                write = lame_encode_flush(lame, mp3_buffer, MP3_SIZE);
            else
                write = lame_encode_buffer_interleaved(lame, pcm_buffer, read, mp3_buffer, MP3_SIZE);
            
            fwrite(mp3_buffer, write, 1, mp3);
            
        } while (read != 0);
        
        lame_close(lame);
        fclose(mp3);
        fclose(pcm);
    }
    @catch (NSException *exception) {
        NSLog(@"%@",[exception description]);
    }
    @finally {
        
        NSInteger fileSize =  [self p_getFileSize:mp3FilePath];
        NSString *message = [NSString stringWithFormat:@"%@ kb", @(fileSize/1024)];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Time %fs", [[NSDate date] timeIntervalSinceDate:startDate]] message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:@"ok", nil];
        [alert show];
    }
    return mp3FilePath;
}

/**
 *  把一个录音文件转成MP3格式
 *
 *  @param name 要转换的文件的名字
 *
 *  @return 转换玩的mp3文件的路径
 */
- (NSString *)toMP3WithFileName:(NSString *)name
{
    if (name == nil) return nil;
    NSString *filePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:name];
    return  [self toMP3WithFilePath:filePath];
}

- (void)p_startRecordVoiceWithPath:(NSString *)voicePath
{
    if (voicePath == nil)
    {
        return;
    }
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *setCategoryError = nil;
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&setCategoryError];
    if(setCategoryError)
    {
        if ([self.delegate respondsToSelector:@selector(recordVoiceToolsDidFailRecording:error:)])
        {
            [self.delegate recordVoiceToolsDidFailRecording:self error:setCategoryError];
        }
        return;
    }
    setCategoryError = nil;
    [session setActive:YES error:&setCategoryError];
    if (setCategoryError)
    {
        if ([self.delegate respondsToSelector:@selector(recordVoiceToolsDidFailRecording:error:)])
        {
            [self.delegate recordVoiceToolsDidFailRecording:self error:setCategoryError];
        }
    }
    NSURL *url = [NSURL fileURLWithPath:voicePath];
    setCategoryError = nil;
    AVAudioRecorder *recorder = [[AVAudioRecorder alloc] initWithURL:url settings:self.settingDict error:&setCategoryError];
    if (setCategoryError)
    {
        if ([self.delegate respondsToSelector:@selector(recordVoiceToolsDidFailRecording:error:)])
        {
            /**
             *  不支持当前的setting设置的录音音频
             */
            [self.delegate recordVoiceToolsDidFailRecording:self error:setCategoryError];
        }
    }
    recorder.delegate = self;
    recorder.meteringEnabled = YES;
    [recorder prepareToRecord];
    [recorder recordForDuration:self.defaultVoiceTime];
    if (self.recorder)
    {
        self.recorder = nil;
    }
    self.recorder = recorder;
    self.slientDuration = 0;
    [self p_startTimer];
    
}
- (void)p_startTimer
{
    [self.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
}
- (void)p_stopTimer
{
    [self.link invalidate];
    self.link = nil;
    if ([self.delegate respondsToSelector:@selector(recordVoiceToolsDidStopRecord:)])
    {
        [self.delegate recordVoiceToolsDidStopRecord:self];
    }
}


- (NSInteger) p_getFileSize:(NSString*) path
{
    NSFileManager * filemanager = [[NSFileManager alloc]init];
    if([filemanager fileExistsAtPath:path])
    {
        NSDictionary * attributes = [filemanager attributesOfItemAtPath:path error:nil];
        NSNumber *theFileSize;
        if ( (theFileSize = [attributes objectForKey:NSFileSize]) )
            return  [theFileSize intValue];
        else
            return -1;
    }
    else
    {
        return -1;
    }
}

/**
 *  根据文件路径获取文件名
 *
 *  @param filePath 文件路径
 *
 *  @return 文件名
 */
- (NSString *)p_getFileNameWithFilePath:(NSString *)filePath
{
    NSRange range = [filePath rangeOfString:@"/" options:NSBackwardsSearch];
    NSString *fileName = filePath;
    if (range.location != NSNotFound)
    {
        fileName = [filePath substringFromIndex:range.location + 1];
    }
    range = [fileName rangeOfString:@"." options:NSBackwardsSearch];
    if (range.location != NSNotFound)
    {
        fileName = [fileName substringToIndex:range.location];
    }
    return fileName;
}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag
{
    [self p_stopTimer];
    if ([self.delegate respondsToSelector:@selector(recordVoiceToolsDidFinishRecording:successfully:)])
    {
        [self.delegate recordVoiceToolsDidFinishRecording:self successfully:flag];
    }
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError * __nullable)error
{
    [self p_stopTimer];
}

- (NSMutableDictionary *)settingDict
{
    if (_settingDict == nil)
    {
        // 格式为 .caf
        NSMutableDictionary *setting = [NSMutableDictionary dictionary];
        setting[AVFormatIDKey] = @(kAudioFormatLinearPCM);
        setting[AVSampleRateKey] = @(8000);
        setting[AVNumberOfChannelsKey] = @(2);
        setting[@"AVEncoderAudioQualityKey"] = @(AVAudioQualityLow);
        _settingDict = setting;
    }
    return _settingDict;
}
@end
