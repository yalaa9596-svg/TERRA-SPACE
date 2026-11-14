import 'dart:typed_data';

/// دالة فتح قفل الصوت للمنصات غير الويب (Android/iOS/Desktop/Tests).
void unlockBrowserSpeechAndAudio() {}

/// تشغيل رابط MP3 على الويب غير متاح على المننصات غير الويب (يستخدم FlutterTts مباشرة).
Future<bool> playAudioUrlOnWeb(
  String audioUrl, {
  required void Function() onStart,
  required void Function() onComplete,
}) async {
  return false;
}

/// تشغيل MP3 على الويب غير متاح على المنصات غير الويب (يستخدم FlutterTts مباشرة).
Future<bool> playAudioBytesOnWeb(
  Uint8List mp3Bytes, {
  required void Function() onStart,
  required void Function() onComplete,
}) async {
  return false;
}

/// إيقاف مشغل الصوت على الويب.
void stopWebAudio() {}
