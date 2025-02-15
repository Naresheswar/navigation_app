import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class SearchScreen extends StatefulWidget {
  final Function(LatLng) onLocationSelected;

  const SearchScreen({super.key, required this.onLocationSelected});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;
  bool _isLoading = false;

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    setState(() => _isLoading = true);

    final url = Uri.parse(
        "https://nominatim.openstreetmap.org/search?format=json&q=$query&limit=5");

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        setState(() {
          _suggestions = data
              .map((item) => {
                    "display_name": item["display_name"] ?? "Unknown Place",
                    "lat": double.tryParse(item["lat"] ?? "0.0") ?? 0.0,
                    "lon": double.tryParse(item["lon"] ?? "0.0") ?? 0.0
                  })
              .toList();
        });
      } else {
        print("Error: API request failed with status ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching suggestions: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchSuggestions(query);
    });
  }

  void _selectLocation(Map<String, dynamic> location) {
    LatLng selectedLocation = LatLng(location["lat"], location["lon"]);
    widget.onLocationSelected(selectedLocation);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Search Location")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: "Enter location",
                border: OutlineInputBorder(),
                suffixIcon: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _suggestions = []);
                        },
                      ),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  return ListTile(
                    title: Text(suggestion["display_name"]),
                    onTap: () => _selectLocation(suggestion),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
