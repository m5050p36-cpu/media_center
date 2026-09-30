import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import 'strings.dart';

class I18n {
  static S of(BuildContext context) {
    final lang = context.watch<LanguageProvider>().locale.languageCode;
    return S(lang);
  }
}
