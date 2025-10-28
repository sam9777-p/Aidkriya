import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RequestMapWidget extends StatefulWidget {
  final double requestLatitude;
  final double requestLongitude;
  final double? walkerLatitude;
  final double? walkerLongitude;
  final String? senderName;
  final ValueChanged<GoogleMapController>? onMapCreated;

  const RequestMapWidget({
    Key? key,
    required this.requestLatitude,
    required this.requestLongitude,
    this.walkerLatitude,
    this.walkerLongitude,
    this.senderName,
    this.onMapCreated,
  }) : super(key: key);

  @override
  State<RequestMapWidget> createState() => _RequestMapWidgetState();
}

class _RequestMapWidgetState extends State<RequestMapWidget> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _createMarkers();
  }

  @override
  void didUpdateWidget(covariant RequestMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Recreate markers if locations change
    if (widget.requestLatitude != oldWidget.requestLatitude ||
        widget.requestLongitude != oldWidget.requestLongitude ||
        widget.walkerLatitude != oldWidget.walkerLatitude ||
        widget.walkerLongitude != oldWidget.walkerLongitude) {
      _createMarkers();
    }
  }

  void _createMarkers() {
    final newMarkers = <Marker>{};
    final newPolylines = <Polyline>{};

    // ✅ Add marker for the request location (where walk will happen)
    newMarkers.add(
      Marker(
        markerId: const MarkerId('request_location'),
        position: LatLng(widget.requestLatitude, widget.requestLongitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Walk Location',
          snippet: widget.senderName != null
              ? 'Requested by ${widget.senderName}'
              : 'Walk request location',
        ),
      ),
    );

    // ✅ Add marker for walker's current location (if available)
    if (widget.walkerLatitude != null && widget.walkerLongitude != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('walker_location'),
          position: LatLng(widget.walkerLatitude!, widget.walkerLongitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Current position',
          ),
        ),
      );

      // ✅ Draw a line connecting the two locations
      newPolylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: [
            LatLng(widget.walkerLatitude!, widget.walkerLongitude!),
            LatLng(widget.requestLatitude, widget.requestLongitude),
          ],
          color: const Color(0xFF6BCBA6),
          width: 3,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
    }

    setState(() {
      _markers = newMarkers;
      _polylines = newPolylines;
    });

    // Move camera to show both markers
    if (_mapController != null) {
      _moveCameraToShowBothLocations();
    }

    debugPrint(
      'RequestMapWidget: Created ${_markers.length} markers and ${_polylines.length} polylines',
    );
  }

  void _moveCameraToShowBothLocations() {
    if (_mapController == null) return;

    if (widget.walkerLatitude != null && widget.walkerLongitude != null) {
      // If we have both locations, zoom to show both
      final bounds = _calculateBounds(
        LatLng(widget.walkerLatitude!, widget.walkerLongitude!),
        LatLng(widget.requestLatitude, widget.requestLongitude),
      );

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100), // 100px padding
      );
    } else {
      // If only request location, center on it
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(widget.requestLatitude, widget.requestLongitude),
          15,
        ),
      );
    }
  }

  LatLngBounds _calculateBounds(LatLng point1, LatLng point2) {
    final southwest = LatLng(
      math.min(point1.latitude, point2.latitude),
      math.min(point1.longitude, point2.longitude),
    );
    final northeast = LatLng(
      math.max(point1.latitude, point2.latitude),
      math.max(point1.longitude, point2.longitude),
    );
    return LatLngBounds(southwest: southwest, northeast: northeast);
  }

  @override
  Widget build(BuildContext context) {
    // Determine initial camera position
    final initialPosition =
        widget.walkerLatitude != null && widget.walkerLongitude != null
        ? LatLng(widget.walkerLatitude!, widget.walkerLongitude!)
        : LatLng(widget.requestLatitude, widget.requestLongitude);

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: initialPosition, zoom: 14),
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (controller) {
        _mapController = controller;
        widget.onMapCreated?.call(controller);
        // Move camera after map is created
        Future.delayed(const Duration(milliseconds: 500), () {
          _moveCameraToShowBothLocations();
        });
      },
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
