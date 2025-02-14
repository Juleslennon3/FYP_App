import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationPage extends StatefulWidget {
  final int childId;
  final String activityDate;

  LocationPage({required this.childId, required this.activityDate});

  @override
  _LocationPageState createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  List<LatLng> activityRoute = [];
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchLocationData();
  }

  // Fetch Location Data
  Future<void> fetchLocationData() async {
    final String apiUrl =
        'https://3efd-80-233-12-225.ngrok-free.app/location/${widget.childId}?date=${widget.activityDate}';
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final activities = data['activities'];

        if (activities.isNotEmpty) {
          final List<dynamic> coordinates = activities[0]['coordinates'];
          setState(() {
            activityRoute = coordinates
                .map((coord) => LatLng(coord['latitude'], coord['longitude']))
                .toList();
          });
        } else {
          setState(() {
            errorMessage = 'No location data available.';
          });
        }
      } else {
        setState(() {
          errorMessage = 'Failed to load location data.';
        });
      }
    } catch (e) {
      print('Error fetching location data: $e');
      setState(() {
        errorMessage = 'An error occurred. Please try again later.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Activity Location'),
        backgroundColor: Colors.blue,
      ),
      body: errorMessage.isNotEmpty
          ? Center(
              child: Text(
                errorMessage,
                style: TextStyle(color: Colors.red, fontSize: 18),
              ),
            )
          : activityRoute.isNotEmpty
              ? GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: activityRoute[0],
                    zoom: 15,
                  ),
                  markers: {
                    Marker(
                      markerId: MarkerId('start'),
                      position: activityRoute[0],
                      infoWindow: InfoWindow(title: 'Start Point'),
                    ),
                    Marker(
                      markerId: MarkerId('end'),
                      position: activityRoute.last,
                      infoWindow: InfoWindow(title: 'End Point'),
                    ),
                  },
                  polylines: {
                    Polyline(
                      polylineId: PolylineId('route'),
                      points: activityRoute,
                      color: Colors.blue,
                      width: 4,
                    ),
                  },
                )
              : Center(child: CircularProgressIndicator()),
    );
  }
}
