import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapWidget extends StatefulWidget {
  final LatLng userLocation;
  final bool isDarkMode;

  const MapWidget(
      {super.key, required this.userLocation, required this.isDarkMode});

  @override
  _MapWidgetState createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  late MapController _mapController;
  LatLng? searchedLocation;
  List<LatLng> routeCoordinates = [];
  String? distance;
  String? eta;
  TextEditingController _searchController = TextEditingController();
  List<dynamic> _suggestions = [];
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("OK"))
        ],
      ),
    );
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    final url =
        'https://nominatim.openstreetmap.org/search?format=json&q=$query';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data.isNotEmpty) {
        double lat = double.parse(data[0]['lat']);
        double lon = double.parse(data[0]['lon']);

        setState(() {
          searchedLocation = LatLng(lat, lon);
          _mapController.move(searchedLocation!, 15.0);
          _fetchRoute(widget.userLocation, searchedLocation!);
          _suggestions.clear();
          _removeOverlay();
        });
      } else {
        _showError("Location not found. Try a different place.");
      }
    } else {
      _showError("Failed to fetch location. Check your connection.");
    }
  }

  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    final url =
        'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson&overview=full';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      List<dynamic> coordinates = data['routes'][0]['geometry']['coordinates'];
      double dist = data['routes'][0]['distance'] / 1000;
      double duration = data['routes'][0]['duration'] / 60;

      setState(() {
        routeCoordinates =
            coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
        distance = "${dist.toStringAsFixed(2)} km";
        eta = "${duration.toStringAsFixed(1)} min";
      });
    } else {
      _showError("Failed to fetch route. Try again.");
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) {
      _removeOverlay();
      return;
    }

    final url =
        'https://nominatim.openstreetmap.org/search?format=json&q=$query&limit=5';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _suggestions = data;
      });

      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? Size.zero;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width - 30,
        child: CompositedTransformFollower(
          link: _layerLink,
          offset: const Offset(0.0, 50.0),
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(10),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  title: Text(suggestion['display_name']),
                  onTap: () {
                    _searchController.text = suggestion['display_name'];
                    _searchLocation(suggestion['display_name']);
                    _removeOverlay();
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.userLocation,
            initialZoom: 13.0,
          ),
          children: [
            TileLayer(
              urlTemplate: widget.isDarkMode
                  ? "https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
                  : "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
              subdomains: ['a', 'b', 'c'],
            ),
            if (routeCoordinates.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routeCoordinates,
                    color: Colors.blue,
                    strokeWidth: 4.0,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  width: 40.0,
                  height: 40.0,
                  point: widget.userLocation,
                  child: const Icon(Icons.my_location,
                      color: Colors.blue, size: 40),
                ),
                if (searchedLocation != null)
                  Marker(
                    width: 40.0,
                    height: 40.0,
                    point: searchedLocation!,
                    child: const Icon(Icons.location_pin,
                        color: Colors.red, size: 40),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 40.0,
          left: 15.0,
          right: 15.0,
          child: CompositedTransformTarget(
            link: _layerLink,
            child: Card(
              elevation: 5.0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search location...",
                  prefixIcon: const Icon(Icons.search, color: Colors.black54),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(15),
                ),
                onChanged: (value) => _fetchSuggestions(value),
                onSubmitted: (value) => _searchLocation(value),
              ),
            ),
          ),
        ),
        if (distance != null && eta != null)
          Positioned(
            bottom: 30.0,
            left: 20.0,
            right: 20.0,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                "Distance: $distance | ETA: $eta",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
