// lib/utils/auth.dart
import 'package:shared_preferences/shared_preferences.dart';

Future<String?> getAccessToken() async {
  final sp = await SharedPreferences.getInstance();
  return sp.getString('accessToken');
}
