import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kindura_ai/res/app_url/app_url.dart';

class UserPreferences extends GetxController {
  // Local development token (auto-updated by setup_local.sh via code generation)
  // DO NOT manually edit - run ./setup_local.sh to regenerate
  static const String _localDevToken = '68-RKgafOFZEGYzuen2KK7o4chq93CyrUo14Yxn2TIw';

  Future<bool> setToken(String token) async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    sp.setString('token', token.toString());

    return true;
  }

  Future<String?> getToken() async {
    // Always use saved token from login
    SharedPreferences sp = await SharedPreferences.getInstance();
    String? savedToken = sp.getString('token');

    if (savedToken != null && savedToken.isNotEmpty) {
      print('✅ Using saved token from login: ${savedToken.substring(0, 10)}...');
      return savedToken;
    }

    print('⚠️ No token found - user needs to login');
    return null;
  }

  Future<bool> removeUser() async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    sp.clear();
    return true;
  }
}
