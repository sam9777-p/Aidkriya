import 'package:aidkriya_walker/model/Walker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapViewWidget extends StatefulWidget {
  final List<Walker> walkers;
  final ValueChanged<String> onMarkerTapped;
  final Position? initialPosition; // Add initial position

  const MapViewWidget({
    Key? key,
    required this.walkers,
    required this.onMarkerTapped,
    this.initialPosition, // Make it optional
  }) : super(key: key);

  @override
  State<MapViewWidget> createState() => _MapViewWidgetState();
}

class _MapViewWidgetState extends State<MapViewWidget> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  // Store the initial position locally
  late CameraPosition _initialCameraPosition;

  @override
  void initState() {
    super.initState();
    // Set initial camera position based on passed value or default
    _setInitialCameraPosition();
    // Create markers based on the initial list
    _createMarkers();
  }

  // Use didUpdateWidget to react to changes in the parent's state
  @override
  void didUpdateWidget(covariant MapViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if the walkers list has actually changed
    // Simple check: compare list references or lengths. For more complex scenarios,
    // you might need a deep comparison or use immutable lists.
    if (widget.walkers != oldWidget.walkers) {
      _createMarkers();
      // No need to call setState here if _createMarkers doesn't change other state
      // The build method will use the updated _markers set automatically.
      // However, if you want to animate the camera to fit markers, do it here or in onMapCreated.

      // Optionally, move the camera if markers change and controller is ready
      // _animateCameraToBounds();
    }
    // Update initial camera position if it changes (less likely but possible)
    if (widget.initialPosition != oldWidget.initialPosition) {
      _setInitialCameraPosition();
      // You might want to move the camera if the map is already created
      if (_mapController != null && widget.initialPosition != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(
              widget.initialPosition!.latitude,
              widget.initialPosition!.longitude,
            ),
          ),
        );
      }
    }
  }

  void _setInitialCameraPosition() {
    _initialCameraPosition = widget.initialPosition != null
        ? CameraPosition(
            target: LatLng(
              widget.initialPosition!.latitude,
              widget.initialPosition!.longitude,
            ),
            zoom: 14, // Zoom in a bit more
          )
        : const CameraPosition(
            // Default fallback (San Francisco) if no position provided
            target: LatLng(37.7749, -122.4194),
            zoom: 13,
          );
  }

  void _createMarkers() {
    print(
      "MapViewWidget/_createMarkers: Received ${widget.walkers.length} walkers.",
    ); // Log input count
    final newMarkers = <Marker>{}; // Start fresh

    for (var walker in widget.walkers) {
      // Log walker details *before* the filter
      print(
        "MapViewWidget/_createMarkers: Processing walker ID ${walker.id}, Lat: ${walker.latitude}, Lon: ${walker.longitude}, Name: ${walker.name}",
      );
      if (walker.latitude != 0.0 && walker.longitude != 0.0) {
        final marker = Marker(
          markerId: MarkerId(walker.id), // Use unique ID
          position: LatLng(walker.latitude, walker.longitude),
          infoWindow: InfoWindow(
            title: walker.name ?? 'Walker',
            snippet: '${walker.rating} ★ | ${walker.distance} km away',
          ),
          onTap: () => widget.onMarkerTapped(walker.id),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        );
        newMarkers.add(marker);
        print(
          "MapViewWidget/_createMarkers: Added marker for ${walker.id}",
        ); // Confirm addition
      } else {
        print(
          "MapViewWidget/_createMarkers: SKIPPED marker for ${walker.id} due to zero/invalid coordinates.",
        ); // Log skipped ones
      }
    }

    // Use setState to ensure the widget rebuilds with the new markers
    setState(() {
      _markers = newMarkers;
    });
    print(
      "MapViewWidget/_createMarkers: Finished. Final marker count: ${_markers.length}",
    ); // Log final count
  }

  // --- Optional: Animate camera to fit markers ---
  void _animateCameraToBounds() {
    if (_mapController == null || _markers.isEmpty) return;

    if (_markers.length == 1) {
      // If only one marker, center on it
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_markers.first.position, 15), // Zoom closer
      );
    } else {
      // Calculate bounds for multiple markers
      LatLngBounds bounds = _getBounds(_markers);
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50.0), // Add padding
      );
    }
  }

  LatLngBounds _getBounds(Set<Marker> markers) {
    // Simple bounds calculation
    double minLat = markers.first.position.latitude;
    double maxLat = markers.first.position.latitude;
    double minLng = markers.first.position.longitude;
    double maxLng = markers.first.position.longitude;

    for (var marker in markers) {
      if (marker.position.latitude < minLat) minLat = marker.position.latitude;
      if (marker.position.latitude > maxLat) maxLat = marker.position.latitude;
      if (marker.position.longitude < minLng)
        minLng = marker.position.longitude;
      if (marker.position.longitude > maxLng)
        maxLng = marker.position.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
  // --- End Optional ---

  @override
  Widget build(BuildContext context) {
    print(
      "MapViewWidget: Build called. Marker count: ${_markers.length}",
    ); // Debug print
    // Ensure initialCameraPosition is set before building GoogleMap
    if (_initialCameraPosition == null) {
      // This should ideally not happen if initState runs correctly
      _setInitialCameraPosition();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: GoogleMap(
        initialCameraPosition: _initialCameraPosition, // Use the state variable
        markers: _markers, // Use the state variable _markers
        onMapCreated: (controller) {
          _mapController = controller;
          // Optionally move camera once map is created
          // _animateCameraToBounds();
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: true, // Enable the button
        zoomControlsEnabled: false,
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
