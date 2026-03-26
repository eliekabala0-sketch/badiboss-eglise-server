import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/member_model.dart';

class MemberService {
  static const String baseUrl = 'http://31.97.158.229:8000';

  static Future<List<Member>> fetchMembers(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/membre'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((e) => Member.fromJson(e)).toList();
    } else {
      throw Exception('Erreur chargement membres');
    }
  }
}