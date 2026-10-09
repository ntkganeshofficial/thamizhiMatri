import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';

/// Translates member-written text (names, occupation, about...) into the active app language.
/// Unknown text is shown as written until the translation arrives, then the UI refreshes.
class TranslationController extends ChangeNotifier {
  final LanguageController _lang;
  final _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
  final Map<String, String> _cache = {};
  final Set<String> _pending = {};
  final Set<String> _failed = {};
  Timer? _timer;

  static final _tamil = RegExp(r'[\u0B80-\u0BFF]');
  static final _latin = RegExp(r'[A-Za-z]');
  static const _maxLength = 1500;

  TranslationController(this._lang) {
    _lang.addListener(notifyListeners);
  }

  String get _target => _lang.isTamil ? 'ta' : 'en';

  String translate(String text) {
    final t = text.trim();
    if (t.isEmpty || t.length > _maxLength) return text;
    // Only text that is not already in the active script needs translating.
    final needs = _lang.isTamil ? _latin.hasMatch(t) : _tamil.hasMatch(t);
    if (!needs) return text;

    final key = '$_target|$t';
    final cached = _cache[key];
    if (cached != null) return cached;
    if (!_failed.contains(key) && _pending.add(key)) {
      _timer ??= Timer(const Duration(milliseconds: 80), _flush);
    }
    return text;
  }

  Future<void> _flush() async {
    _timer = null;
    final batch = _pending.take(25).toList();
    _pending.removeAll(batch);
    if (batch.isEmpty) return;

    // Keys are "<target>|<text>"; group by target (normally just one).
    final byTarget = <String, List<String>>{};
    for (final key in batch) {
      final i = key.indexOf('|');
      byTarget
          .putIfAbsent(key.substring(0, i), () => [])
          .add(key.substring(i + 1));
    }

    var changed = false;
    for (final entry in byTarget.entries) {
      try {
        final result = await _functions
            .httpsCallable('translateTexts')
            .call<Map<Object?, Object?>>({
              'texts': entry.value,
              'target': entry.key,
            });
        final out = (result.data['translations'] as List).cast<String>();
        for (var i = 0; i < entry.value.length; i++) {
          _cache['${entry.key}|${entry.value[i]}'] = out[i];
        }
        changed = true;
      } catch (e) {
        debugPrint('translateTexts failed: $e');
        for (final text in entry.value) {
          _failed.add('${entry.key}|$text');
        }
      }
    }
    if (changed) notifyListeners();
    if (_pending.isNotEmpty) {
      _timer ??= Timer(const Duration(milliseconds: 80), _flush);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lang.removeListener(notifyListeners);
    super.dispose();
  }
}

extension TranslateText on BuildContext {
  /// Member-written text in the active language; rebuilds when its translation arrives.
  String tx(String text) => watch<TranslationController>().translate(text);
}
