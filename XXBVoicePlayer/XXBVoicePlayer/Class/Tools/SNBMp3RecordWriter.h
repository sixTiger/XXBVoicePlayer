//
//  SNBMp3RecordWriter.h
//  XXBVoicePlayer
//
//  Created by xiaobing on 15/12/3.
//  Copyright © 2015年 xiaobing. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SNBRecordVoiceTools.h"

@interface SNBMp3RecordWriter : NSObject<FileWriterForSNBRecordVoiceTools>

@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, assign) unsigned long maxFileSize;
@property (nonatomic, assign) double maxSecondCount;

@end
