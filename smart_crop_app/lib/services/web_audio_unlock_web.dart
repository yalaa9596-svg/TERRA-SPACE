import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

bool _browserAudioUnlocked = false;
JSObject? _sharedAudioEl;
Completer<bool>? _activePlayCompleter;

const String _silentWavDataUri =
    'data:audio/wav;base64,UklGRigAAABXQVZFZm10IBIAAAABAAEARKwAAIhYAQACABAAAABkYXRhAgAAAAEA';

JSObject? _ensureAudioElement() {
  if (_sharedAudioEl != null) return _sharedAudioEl;
  final ctor = globalContext['Audio'];
  if (ctor != null && ctor.typeofEquals('function')) {
    _sharedAudioEl = (ctor as JSFunction).callAsConstructor<JSObject>();
  }
  return _sharedAudioEl;
}

/// يفتح قفل AudioContext وSpeechSynthesis وعنصر HTMLAudioElement لحظياً أثناء ضغطة المستخدم في Chrome
/// حتى يسمح المتصفح بالتشغيل التلقائي للصوت فور وصول الرد من الخادم.
void unlockBrowserSpeechAndAudio() {
  try {
    final audioEl = _ensureAudioElement();
    if (audioEl != null && !_browserAudioUnlocked) {
      try {
        audioEl['muted'] = true.toJS;
        audioEl['src'] = _silentWavDataUri.toJS;
        final res = audioEl.callMethod<JSAny?>('play'.toJS);
        if (res != null && res.typeofEquals('object')) {
          (res as JSObject).callMethod<JSAny?>(
            'catch'.toJS,
            ((JSAny? _) {}).toJS,
          );
        }
      } catch (_) {}
    }

    final speechSynth = globalContext['speechSynthesis'];
    if (speechSynth != null && speechSynth.typeofEquals('object')) {
      final synthObj = speechSynth as JSObject;
      try {
        synthObj.callMethod<JSAny?>('resume'.toJS);
      } catch (_) {}

      if (!_browserAudioUnlocked) {
        final ctor = globalContext['SpeechSynthesisUtterance'];
        if (ctor != null && ctor.typeofEquals('function')) {
          final utterance = (ctor as JSFunction).callAsConstructor<JSObject>(' '.toJS);
          utterance['volume'] = 0.0.toJS;
          utterance['rate'] = 0.85.toJS;
          utterance['lang'] = 'ar-EG'.toJS;
          synthObj.callMethod<JSAny?>('speak'.toJS, utterance);
        }
      }
    }

    final audioCtxCtor = globalContext['AudioContext'] ?? globalContext['webkitAudioContext'];
    if (audioCtxCtor != null && audioCtxCtor.typeofEquals('function')) {
      final ctx = (audioCtxCtor as JSFunction).callAsConstructor<JSObject>();
      ctx.callMethod<JSAny?>('resume'.toJS);
    }

    _browserAudioUnlocked = true;
  } catch (_) {}
}

Future<bool> _playSrcOnWeb(
  String src, {
  required void Function() onStart,
  required void Function() onComplete,
}) async {
  try {
    final audioEl = _ensureAudioElement();
    if (audioEl == null) return false;

    stopWebAudio();

    final completer = Completer<bool>();
    _activePlayCompleter = completer;

    void finish(bool ok) {
      if (!completer.isCompleted) {
        completer.complete(ok);
      }
      if (identical(_activePlayCompleter, completer)) {
        _activePlayCompleter = null;
      }
      onComplete();
    }

    audioEl['onended'] = ((JSAny? _) => finish(true)).toJS;
    audioEl['onerror'] = ((JSAny? _) => finish(false)).toJS;

    audioEl['muted'] = false.toJS;
    audioEl['volume'] = 1.0.toJS;
    audioEl['playbackRate'] = 1.0.toJS;
    audioEl['src'] = src.toJS;

    onStart();
    final playPromise = audioEl.callMethod<JSAny?>('play'.toJS);
    if (playPromise != null && playPromise.typeofEquals('object')) {
      (playPromise as JSObject).callMethod<JSAny?>(
        'catch'.toJS,
        ((JSAny? _) => finish(false)).toJS,
      );
    }

    return await completer.future;
  } catch (_) {
    onComplete();
    return false;
  }
}

/// يشغّل رابط MP3 مباشر (مثل http://localhost:8000/audio/tts_xxx.mp3) على Chrome Web.
Future<bool> playAudioUrlOnWeb(
  String audioUrl, {
  required void Function() onStart,
  required void Function() onComplete,
}) {
  return _playSrcOnWeb(audioUrl, onStart: onStart, onComplete: onComplete);
}

/// يشغّل بايتات MP3 على متصفح الويب باستخدام عنصر الصوت المفكوك قفله مسبقاً.
Future<bool> playAudioBytesOnWeb(
  Uint8List mp3Bytes, {
  required void Function() onStart,
  required void Function() onComplete,
}) {
  return _playSrcOnWeb(
    'data:audio/mpeg;base64,${base64Encode(mp3Bytes)}',
    onStart: onStart,
    onComplete: onComplete,
  );
}

/// يوقف عنصر الصوت النشط وأي نطق عبر speechSynthesis على الويب فوراً لمنع تداخل صوتين معاً.
void stopWebAudio() {
  try {
    final audioEl = _sharedAudioEl;
    if (audioEl != null) {
      audioEl['onended'] = null;
      audioEl['onerror'] = null;
      audioEl.callMethod<JSAny?>('pause'.toJS);
      audioEl['currentTime'] = 0.0.toJS;
    }

    final speechSynth = globalContext['speechSynthesis'];
    if (speechSynth != null && speechSynth.typeofEquals('object')) {
      (speechSynth as JSObject).callMethod<JSAny?>('cancel'.toJS);
    }
  } catch (_) {}

  final pending = _activePlayCompleter;
  _activePlayCompleter = null;
  if (pending != null && !pending.isCompleted) {
    pending.complete(false);
  }
}
