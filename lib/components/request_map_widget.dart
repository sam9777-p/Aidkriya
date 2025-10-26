import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RequestMapWidget extends StatelessWidget {
  final String location;
  final double latitude;
  final double longitude;
  final Function(GoogleMapController) onMapCreated;

  const RequestMapWidget({
    Key? key,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.onMapCreated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(latitude, longitude),
        zoom: 13,
      ),
      markers: {
        Marker(
          markerId: MarkerId(location),
          position: LatLng(latitude, longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      },
      onMapCreated: onMapCreated,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
    );
  }
}
