import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_webservice/directions.dart' as gmaps_ws;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mainMapController;

  CameraPosition _cameraPosition = const CameraPosition(
    target: LatLng(-3.296894230550083, -60.62003334001973),
    zoom: 12,
  );

  LatLng? _selectedLocation;
  LatLng? _currentLocation;

  Set<Polyline> _polylines = {};

  final gmaps_ws.GoogleMapsDirections directions = gmaps_ws.GoogleMapsDirections(
    apiKey: 'AIzaSyAYS4r80fTUbfrIpI6AEnnADS-YNt828Ws', // substitua pela sua chave
  );

  // Estilo dark com todos os POIs ocultados (restaurantes, supermercados, hotéis, etc)
  static const String _darkMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [{"color": "#242f3e"}]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#746855"}]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#242f3e"}]
  },
  {
    "featureType": "administrative.locality",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#d59563"}]
  },

  // Ocultar todos os POIs
  {
    "featureType": "poi",
    "elementType": "all",
    "stylers": [
      { "visibility": "off" }
    ]
  },
  {
    "featureType": "poi",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "poi.business",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "poi.park",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "poi.place_of_worship",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "poi.school",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "poi.sports_complex",
    "stylers": [{"visibility": "off"}]
  },

  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{"color": "#38414e"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [{"color": "#212a37"}]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#9ca5b3"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [{"color": "#746855"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [{"color": "#1f2835"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#f3d19c"}]
  },

  // Ocultar estações de trânsito
  {
    "featureType": "transit",
    "stylers": [{"visibility": "off"}]
  },

  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#17263c"}]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#515c6d"}]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#17263c"}]
  }
]
''';

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    LocationPermission permission;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    Position position = await Geolocator.getCurrentPosition();

    LatLng currentLatLng = LatLng(position.latitude, position.longitude);

    setState(() {
      _currentLocation = currentLatLng;
      _cameraPosition = CameraPosition(target: currentLatLng, zoom: 16);
    });

    if (_mainMapController != null) {
      _mainMapController!.animateCamera(
        CameraUpdate.newLatLngZoom(currentLatLng, 16),
      );
    }
  }

  Future<void> _createRoute(LatLng destination) async {
    if (_currentLocation == null) return;

    final result = await directions.directionsWithLocation(
      gmaps_ws.Location(lat: _currentLocation!.latitude, lng: _currentLocation!.longitude),
      gmaps_ws.Location(lat: destination.latitude, lng: destination.longitude),
      travelMode: gmaps_ws.TravelMode.driving,
    );

    if (result.isOkay && result.routes.isNotEmpty) {
      final route = result.routes[0];
      final overviewPolyline = route.overviewPolyline.points;

      final points = _decodePolyline(overviewPolyline);

      setState(() {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: points,
            color: Colors.blueAccent,
            width: 5,
          ),
        );

        _selectedLocation = destination;
      });

      // Centralizar mapa para mostrar toda rota
      _mainMapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          _boundsFromLatLngList(points),
          150,
        ),
      );
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    assert(list.isNotEmpty);
    double x0 = list[0].latitude;
    double x1 = list[0].latitude;
    double y0 = list[0].longitude;
    double y1 = list[0].longitude;

    for (LatLng latLng in list) {
      if (latLng.latitude > x1) x1 = latLng.latitude;
      if (latLng.latitude < x0) x0 = latLng.latitude;
      if (latLng.longitude > y1) y1 = latLng.longitude;
      if (latLng.longitude < y0) y0 = latLng.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(x0, y0),
      northeast: LatLng(x1, y1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        initialCameraPosition: _cameraPosition,
        onMapCreated: (GoogleMapController controller) {
          _mainMapController = controller;
          _mainMapController!.setMapStyle(_darkMapStyle);
          if (_currentLocation != null) {
            _mainMapController!.animateCamera(
              CameraUpdate.newLatLngZoom(_currentLocation!, 16),
            );
          }
        },
        onCameraMove: (position) {
          setState(() {
            _cameraPosition = position;
          });
        },
        onLongPress: (LatLng pressedPoint) {
          _createRoute(pressedPoint);
        },
        markers: {
          if (_selectedLocation != null)
            Marker(
              markerId: const MarkerId('selected-location'),
              position: _selectedLocation!,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: const InfoWindow(title: 'Destino'),
            ),
        },
        polylines: _polylines,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.my_location, color: Colors.white),
        onPressed: () {
          if (_currentLocation != null && _mainMapController != null) {
            _mainMapController!.animateCamera(
              CameraUpdate.newLatLngZoom(_currentLocation!, 16),
            );
          }
        },
      ),
    );
  }
}