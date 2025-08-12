import 'env.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

Future<String?> loadAccessToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('accessToken'); // login_page.dart에서 저장한 키 그대로
}