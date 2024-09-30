import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';

class MarkerDistanceDisplay extends StatelessWidget {
  final LatLng? markerLocation; // Координаты маркера
  final double? markerHeight; // Высота маркера

  final LatLng? currentLocationGPS; // Текущие координаты GPS
  final double? currentHeightGPS; // Текущая высота GPS
  final LatLng? currentLocationGLN; // Текущие координаты GLN
  final double? currentHeightGLN; // Текущая высота GLN
  final LatLng? currentLocationGAL; // Текущие координаты GAL
  final double? currentHeightGAL; // Текущая высота GAL
  final LatLng? currentLocationBDS; // Текущие координаты BDS
  final double? currentHeightBDS; // Текущая высота BDS

  const MarkerDistanceDisplay({
    Key? key,
    required this.markerLocation,
    required this.markerHeight,
    this.currentLocationGPS,
    this.currentHeightGPS,
    this.currentLocationGLN,
    this.currentHeightGLN,
    this.currentLocationGAL,
    this.currentHeightGAL,
    this.currentLocationBDS,
    this.currentHeightBDS,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Проверяем, есть ли координаты маркера
    if (markerLocation == null) {
      return const SizedBox.shrink(); // Не отображаем ничего, если маркер не установлен
    }

    // Вычисляем расстояния до маркера
    double? distanceToMarkerGPS = _calculateDistance(currentLocationGPS, currentHeightGPS);
    double? distanceToMarkerGLN = _calculateDistance(currentLocationGLN, currentHeightGLN);
    double? distanceToMarkerGAL = _calculateDistance(currentLocationGAL, currentHeightGAL);
    double? distanceToMarkerBDS = _calculateDistance(currentLocationBDS, currentHeightBDS);

    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 2),
        SelectableText(
          'Координаты маркера: ${markerLocation!.latitude.toStringAsFixed(7)}, ${markerLocation!.longitude.toStringAsFixed(7)}${markerHeight != null ? ', ${markerHeight!.toStringAsFixed(2)} м' : ''}',
          style: const TextStyle(fontSize: 12, color: Colors.black),
        ),
        if (distanceToMarkerGPS != null)
          SelectableText(
            'Расстояние до маркера (GPS): ${distanceToMarkerGPS.toStringAsFixed(4)} м',
            style: const TextStyle(fontSize: 12, color: Colors.red),
          ),
        if (distanceToMarkerGLN != null)
          SelectableText(
            'Расстояние до маркера (GLN): ${distanceToMarkerGLN.toStringAsFixed(4)} м',
            style: const TextStyle(fontSize: 12, color: Colors.blue),
          ),
        if (distanceToMarkerGAL != null)
          SelectableText(
            'Расстояние до маркера (GAL): ${distanceToMarkerGAL.toStringAsFixed(4)} м',
            style: const TextStyle(fontSize: 12, color: Colors.orange),
          ),
        if (distanceToMarkerBDS != null)
          SelectableText(
            'Расстояние до маркера (BDS): ${distanceToMarkerBDS.toStringAsFixed(4)} м',
            style: const TextStyle(fontSize: 12, color: Color.fromARGB(255, 5, 131, 9)),
          ),
      ],
    );
  }

  double? _calculateDistance(LatLng? currentLocation, double? currentHeight) {
    if (currentLocation != null && markerLocation != null) {
      if (currentHeight != null && markerHeight != null) {
        return _calculateDistance3D(currentLocation, markerLocation!, currentHeight, markerHeight!);
      } else {
        return _calculateDistance2D(currentLocation, markerLocation!);
      }
    }
    return null; // Если текущие координаты не установлены, возвращаем null
  }

  double _calculateDistance2D(LatLng point1, LatLng point2) {
    const double R = 6371000; // радиус Земли в метрах
    double dLat = (point2.latitude - point1.latitude) * pi / 180;
    double dLon = (point2.longitude - point1.longitude) * pi / 180;
    double a = sin(dLat / 2) * sin(dLat / 2) + cos(point1.latitude * pi / 180) * cos(point2.latitude * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _calculateDistance3D(LatLng point1, LatLng point2, double height1, double height2) {
    double distance2D = _calculateDistance2D(point1, point2);
    double heightDifference = height2 - height1;
    return sqrt(pow(distance2D, 2) + pow(heightDifference, 2));
  }
}
