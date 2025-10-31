// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Cat Alarm';

  @override
  String get soundLabel => '声音';

  @override
  String get usingSoundFile => '使用：soft.m4a';

  @override
  String get audioActiveBanner => '● 音频 激活 – 点击停止以结束';

  @override
  String get selectTone => '选择闹铃音';

  @override
  String get soft => '柔和';

  @override
  String get standard => '标准';

  @override
  String get power => '强力';

  @override
  String get am => '上午';

  @override
  String get pm => '下午';

  @override
  String get ampmToggle => 'AM/PM';

  @override
  String get currentTimePrefix => '当前时间：';

  @override
  String get setButton => '设置';

  @override
  String get alarmButton => '闹铃';

  @override
  String get stopButton => '停止';

  @override
  String get offButton => '关闭';

  @override
  String get testButton => '测试';

  @override
  String get audioTestTitle => '音频 测试';

  @override
  String get testSoundButton => '播放测试音';

  @override
  String get statusReady => '准备就绪';

  @override
  String get statusStarting => '正在启动音频播放器...';

  @override
  String get statusPlaying => '声音正在播放。';

  @override
  String get statusErrorPrefix => '错误：';

  @override
  String get statusPlayerStatePrefix => '播放器状态：';

  @override
  String get statusFinished => '声音完成。';

  @override
  String get statusPlayerErrorPrefix => '播放器错误：';
}

/// The translations for Chinese, as used in China (`zh_CN`).
class AppLocalizationsZhCn extends AppLocalizationsZh {
  AppLocalizationsZhCn() : super('zh_CN');

  @override
  String get appTitle => 'Cat Alarm';

  @override
  String get soundLabel => '声音';

  @override
  String get usingSoundFile => '使用：soft.m4a';

  @override
  String get audioActiveBanner => '● 音频 激活 – 点击停止以结束';

  @override
  String get selectTone => '选择闹铃音';

  @override
  String get soft => '柔和';

  @override
  String get standard => '标准';

  @override
  String get power => '强力';

  @override
  String get am => '上午';

  @override
  String get pm => '下午';

  @override
  String get ampmToggle => 'AM/PM';

  @override
  String get currentTimePrefix => '当前时间：';

  @override
  String get setButton => '设置';

  @override
  String get alarmButton => '闹铃';

  @override
  String get stopButton => '停止';

  @override
  String get offButton => '关闭';

  @override
  String get testButton => '测试';

  @override
  String get audioTestTitle => '音频 测试';

  @override
  String get testSoundButton => '播放测试音';

  @override
  String get statusReady => '准备就绪';

  @override
  String get statusStarting => '正在启动音频播放器...';

  @override
  String get statusPlaying => '声音正在播放。';

  @override
  String get statusErrorPrefix => '错误：';

  @override
  String get statusPlayerStatePrefix => '播放器状态：';

  @override
  String get statusFinished => '声音完成。';

  @override
  String get statusPlayerErrorPrefix => '播放器错误：';
}
