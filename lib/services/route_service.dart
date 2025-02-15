import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteService {
  static Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    final url =
        'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List coordinates = data['routes'][0]['geometry']['coordinates'];
      return coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
    }
    return [];
  }
}
