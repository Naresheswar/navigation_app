import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/map_widget.dart';
import '../services/location_service.dart';

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const HomeScreen({
    Key? key,
    required this.isDarkMode,
    required this.onToggleTheme,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LatLng? userLocation;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      final position = await LocationService.getUserLocation();
      setState(() {
        userLocation = LatLng(position.latitude, position.longitude);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = "Failed to get location. Ensure GPS is enabled.";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Navigation App'),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.dark_mode : Icons.light_mode),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Text(errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 16)))
              : MapWidget(
                  userLocation: userLocation!, isDarkMode: widget.isDarkMode),
    );
  }
}
