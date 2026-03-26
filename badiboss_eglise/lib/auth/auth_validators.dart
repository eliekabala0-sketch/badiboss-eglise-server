import 'package:flutter/foundation.dart';

@immutable
final class AuthValidators {

  static final RegExp churchCodeStrict = RegExp(r'^[A-Z0-9]{6,12}$');

  static final RegExp phoneStrict = RegExp(r'^\d{9,15}$');

  static bool isValidPhone(String v) =>
      phoneStrict.hasMatch(v.trim());

  static bool isValidChurchCode(String v) =>
      churchCodeStrict.hasMatch(v.trim());

  static bool isValidPassword(String v) =>
      v.trim().length >= 6;

  static String normalizePhone(String v) =>
      v.trim();

  static String normalizeChurchCode(String v) =>
      v.trim().toUpperCase();
}
