import 'package:http/http.dart' as http;
import 'dart:convert';

class SearchService {
  static Future<List<Map<String, dynamic>>> getLocationSuggestions(
      String query) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    return [];
  }
}
