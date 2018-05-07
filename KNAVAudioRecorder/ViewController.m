//
//  ViewController.m
//  KNAVAudioRecorder：
//https://developer.apple.com/documentation/avfoundation/avaudiorecorder?language=objc
//  Created by devzkn on 07/05/2018.
//  Copyright © 2018 devzkn. All rights reserved.
//
#import <AVFoundation/AVFoundation.h>
#import "ViewController.h"

#define kRecordAudioFile @"myRecord.caf"// 录音文件名称
@interface ViewController () <AVAudioRecorderDelegate>
/** 录音机 */
@property (nonatomic, strong) AVAudioRecorder *audioRecorder;
/** 音频播放器,用于播放录音文件 */
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
/** 录音声波监控（注意这里暂时不对播放进行监控） */
@property (nonatomic,strong) NSTimer *timer;
@property (weak, nonatomic) IBOutlet UIButton *record;//开始录音
@property (weak, nonatomic) IBOutlet UIButton *pause;//暂停录音
@property (weak, nonatomic) IBOutlet UIButton *resume;//恢复录音
@property (weak, nonatomic) IBOutlet UIButton *stop;//停止录音
@property (weak, nonatomic) IBOutlet UIProgressView *audioPower;//音频波动
@property (weak, nonatomic) IBOutlet UILabel *powerLabel;
@end
@implementation ViewController
#pragma mark - View
- (void)viewDidLoad {
    [super viewDidLoad];
    [self setAudioSession];}
#pragma mark - 录音方法
/**
 *  设置音频会话
 */
-(void)setAudioSession{
    AVAudioSession *audioSession=[AVAudioSession sharedInstance];
    //设置为播放和录音状态，以便可以在录制完之后播放录音
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [audioSession setActive:YES error:nil];
}

/**
 *  取得录音文件保存路径
 *
 *  @return 录音文件路径
 */
-(NSURL *)getSavePath{
    NSString *urlStr=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    urlStr=[urlStr stringByAppendingPathComponent:kRecordAudioFile];
    NSLog(@"file path:%@",urlStr);
    NSURL *url=[NSURL fileURLWithPath:urlStr];
    return url;
}

/**
 *  取得录音文件设置
 *
 *  @return 录音设置
 */
- (NSDictionary *)getAudioSetting {
    
    NSMutableDictionary *dicM = [NSMutableDictionary dictionary];
    // 设置录音格式为lpcm
    [dicM setObject:@(kAudioFormatLinearPCM) forKey:AVFormatIDKey];
    // 设置录音采样率，8000是电话采样率，对于一般录音已经够了
    [dicM setObject:@(8000) forKey:AVSampleRateKey];
    // 声道
    [dicM setObject:@(2) forKey:AVNumberOfChannelsKey];
    // 每个采样点位数
    [dicM setObject:@(8) forKey:AVLinearPCMBitDepthKey];
    // 是否使用浮点数采样
    [dicM setObject:@(YES) forKey:AVLinearPCMIsFloatKey];
    // 录音品质
    [dicM setObject:@(AVAudioQualityHigh) forKey:AVSampleRateConverterAudioQualityKey];
    return dicM;
}

- (AVAudioRecorder *)audioRecorder {
    if (!_audioRecorder) {
        // 保存路径
        NSURL *url = [self getSavePath];
        // 录音设置
        NSDictionary *setting = [self getAudioSetting];
        // 创建录音机
        NSError *error = nil;
        _audioRecorder = [[AVAudioRecorder alloc] initWithURL:url settings:setting error:&error];
        _audioRecorder.delegate = self;
        _audioRecorder.meteringEnabled = YES;
        
        if (error) {
            NSLog(@"创建录音机对象发生错误，error：%@", error.localizedDescription);
            return nil;
        }
        
    }
    return _audioRecorder;
}

/**
 *  录音声波监控定制器
 *
 *  @return 定时器
 */
-(NSTimer *)timer {
    if (!_timer) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:0.1f target:self selector:@selector(audioPowerChange) userInfo:nil repeats:YES];
    }
    return _timer;
}

#pragma mark - ******** 录音声波状态设置
/**
 *  录音声波状态设置
 //  量程定为0~110dB,而Apple提供的测量值范围： -160 ~ 0dB，两者之间差了50dB，
 //  也就是说以麦克风的测量值的-160dB+50dB = -110dB作为起点，0dB作为Max值,恰好量程为0~110dB
 */
-(void)audioPowerChange{
//    https://developer.apple.com/documentation/avfoundation/avaudiorecorder/1387176-averagepowerforchannel?language=objc
//
    [self.audioRecorder updateMeters];//更新测量值
    float power = [self.audioRecorder averagePowerForChannel:0];//// 均值：
    float powerMax = [self.audioRecorder peakPowerForChannel:0];//峰值
    NSLog(@"power = %f, powerMax = %f",power, powerMax);
    CGFloat progress = (1.0 / 160.0) * (power + 160.0);
    power = power + 160  - 50;// 关键代码
    int dB = 0;
    if (power < 0.f) {
        dB = 0;
    } else if (power < 40.f) {
        dB = (int)(power * 0.875);
    } else if (power < 100.f) {
        dB = (int)(power - 15);
    } else if (power < 110.f) {
        dB = (int)(power * 2.5 - 165);
    } else {
        dB = 110;
    }
    self.powerLabel.text = [NSString stringWithFormat:@"%ddB", dB];
    [self.audioPower setProgress:progress];
}

#pragma mark - UI事件
/**
 *  点击录音按钮
 *
 *  @param sender 录音按钮
 */
- (IBAction)recordClick:(UIButton *)sender {
    if (![self.audioRecorder isRecording]) {
        [self.audioRecorder record];//首次使用应用时如果调用record方法会询问用户是否允许使用麦克风
        self.timer.fireDate=[NSDate distantPast];
    }
}

/**
 *  点击暂定按钮
 *
 *  @param sender 暂停按钮
 */
- (IBAction)pauseClick:(UIButton *)sender {
    if ([self.audioRecorder isRecording]) {
        [self.audioRecorder pause];
        self.timer.fireDate = [NSDate distantFuture];
    }
}

/**
 *  点击恢复按钮
 *  恢复录音只需要再次调用record，AVAudioSession会帮助你记录上次录音位置并追加录音
 *
 *  @param sender 恢复按钮
 */
- (IBAction)resumeClick:(UIButton *)sender {
    [self recordClick:sender];
}

/**
 *  点击停止按钮
 *
 *  @param sender 停止按钮
 */
- (IBAction)stopClick:(UIButton *)sender {
    [self.audioRecorder stop];
    self.timer.fireDate=[NSDate distantFuture];
    self.audioPower.progress=0.0;
}

#pragma mark - 录音机代理方法
/**
 *  录音完成，录音完成后播放录音
 *
 *  @param recorder 录音机对象
 *  @param flag     是否成功
 */
-(void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag{
    if (![self.audioPlayer isPlaying]) {
        [self.audioPlayer play];
    }
    NSLog(@"录音完成!");
}
@end
