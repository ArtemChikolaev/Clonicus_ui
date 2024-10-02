import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'receiver_50packet.dart';
import 'receiver_notifier.dart';

class Receiver50PacketMap extends StatefulWidget {
  const Receiver50PacketMap({super.key});

  @override
  State<Receiver50PacketMap> createState() => _Receiver50PacketMapState();
}

class _Receiver50PacketMapState extends State<Receiver50PacketMap> {
  final MapController _mapController = MapController();
  double _mapZoom = 10; // Начальное значение зума
  // LatLng _currentCenter = const LatLng(55.751244, 37.618423); // Начальное положение
  LatLng _currentCenter = const LatLng(48.15, 11.58); // Начальное положение
  // ignore: unused_field
  bool _initialZoomSet = false; // Флаг для определения, был ли уже установлен начальный зум
  // ignore: unused_field
  bool _isUserInput = true;

  final TextEditingController _coordsController = TextEditingController();
  LatLng? _markerLocation;
  double? _markerHeight;
  // ignore: unused_field
  final bool _isInputFieldVisible = false;

  LatLng? get markerLocation => _markerLocation;
  double? get markerHeight => _markerHeight;
  // Добавляем переменные для управления режимом следования
  bool _isFollowingMarker = false;
  Timer? _followMarkerTimer;

  bool _isDrawingEnabled = false; // Флаг для управления отрисовкой
  final List<CircleMarker> _allCircleMarkers = [];

  @override
  void dispose() {
    _followMarkerTimer?.cancel(); // Остановить таймер, если он запущен
    super.dispose(); // Вызов метода родителя
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReceiverNotifier>(
      builder: (context, notifier, _) {
        final receiverNotifier = Provider.of<ReceiverNotifier>(context);
        final List<String> rawData = receiverNotifier.parsedDataList;

        return FutureBuilder<Map<String, String>>(
          future: readLastCoordinates(rawData),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Ошибка: ${snapshot.error}');
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Text('Нет данных');
            } else {
              // Здесь добавляем координаты всех систем в ReceiverNotifier
              _updateNotifierWithCoordinates(context, snapshot.data!);
              return Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _currentCenter,
                        initialZoom: _mapZoom,
                        onTap: (tapPosition, point) {
                          receiverNotifier.setMarkerLocation(point);
                          _coordsController.text = '${point.latitude.toStringAsFixed(7)}, ${point.longitude.toStringAsFixed(7)}';
                          _isUserInput = false; // Сбрасываем флаг ввода вручную
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const [
                            'a',
                            'b',
                            'c'
                          ],
                        ),
                        if (receiverNotifier.markerLocation != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: receiverNotifier.markerLocation!,
                                width: 80.0,
                                height: 80.0,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.black,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: _buildMarkers(snapshot.data!),
                        ),
                        CircleLayer(
                          circles: _buildCircles(snapshot.data!),
                        ),
                        CircleLayer(
                          circles: _buildCircleMarkers(snapshot.data!),
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: 16.0,
                      right: 16.0,
                      child: Column(
                        children: [
                          FloatingActionButton(
                            heroTag: 'zoomInButton',
                            onPressed: () {
                              if (!mounted) return;
                              setState(() {
                                _zoomIn(); // Увеличиваем зум
                              });
                            },
                            backgroundColor: const Color.fromARGB(255, 211, 186, 253),
                            elevation: 10,
                            mini: true,
                            child: const Icon(Icons.add),
                          ),
                          const SizedBox(height: 2),
                          FloatingActionButton(
                            heroTag: 'zoomOutButton',
                            onPressed: () {
                              if (!mounted) return;
                              setState(() {
                                _zoomOut(); // Уменьшаем зум
                              });
                            },
                            backgroundColor: const Color.fromARGB(255, 211, 186, 253),
                            elevation: 10,
                            mini: true,
                            child: const Icon(Icons.remove),
                          ),
                          const SizedBox(height: 16.0),
                          FloatingActionButton(
                            heroTag: 'moveToCurrentLocation',
                            onPressed: () {
                              if (!mounted) return;
                              setState(() {
                                _moveToCurrentLocation(snapshot.data!); // Перемещаем к текущей локации
                              });
                            },
                            backgroundColor: const Color.fromARGB(255, 211, 186, 253),
                            elevation: 10,
                            mini: true,
                            child: const Icon(Icons.my_location),
                          ),
                          const SizedBox(height: 16.0), // Промежуток между кнопками
                          FloatingActionButton(
                            heroTag: 'toggleFollowMarker',
                            onPressed: () {
                              if (!mounted) return;
                              _toggleFollowMarker(snapshot.data!); // Включаем или выключаем режим следования
                            },
                            backgroundColor: _isFollowingMarker ? const Color.fromARGB(255, 252, 149, 142) : const Color.fromARGB(255, 211, 186, 253),
                            elevation: 10,
                            mini: true,
                            child: const Icon(Icons.navigation),
                          ),
                          const SizedBox(height: 16.0), // Промежуток между кнопками
                          FloatingActionButton(
                            heroTag: 'toggleDrawing',
                            onPressed: _toggleDrawing,
                            backgroundColor: _isDrawingEnabled ? const Color.fromARGB(255, 252, 149, 142) : const Color.fromARGB(255, 211, 186, 253),
                            elevation: 10,
                            mini: true,
                            child: Icon(_isDrawingEnabled ? Icons.visibility : Icons.visibility_off), // Иконка меняется в зависимости от состояния
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
          },
        );
      },
    );
  }

  // Метод для обновления ReceiverNotifier с координатами всех систем
  void _updateNotifierWithCoordinates(BuildContext context, Map<String, String> coordinatesData) {
    final receiverNotifier = Provider.of<ReceiverNotifier>(context, listen: false);

    coordinatesData.forEach((systemName, coord) {
      final parsedData = _parseCoordinatesFull(coord);
      if (parsedData != null) {
        LatLng location = parsedData['location'];
        double height = parsedData['height'];

        // Проверяем, что широта и долгота не равны нулю
        if (location.latitude != 0 && location.longitude != 0) {
          switch (systemName) {
            case 'GPS':
              receiverNotifier.setGPSLocation(location, height);
              break;
            case 'GLN':
              receiverNotifier.setGLNLocation(location, height);
              break;
            case 'GAL':
              receiverNotifier.setGALLocation(location, height);
              break;
            case 'BDS':
              receiverNotifier.setBDSLocation(location, height);
              break;
          }
        }
      }
    });
  }

  // Метод для увеличения зума
  void _zoomIn() {
    setState(() {
      _mapZoom += 1.0;
      _mapController.move(_currentCenter, _mapZoom);
    });
  }

  // Метод для уменьшения зума
  void _zoomOut() {
    setState(() {
      _mapZoom = (_mapZoom > 1.0) ? _mapZoom - 1.0 : _mapZoom;
      _mapController.move(_currentCenter, _mapZoom);
    });
  }

  // Метод для перемещения к текущему местоположению с сохранением зума
  void _moveToCurrentLocation(Map<String, String> coordinatesData) {
    LatLng? location;
    // ignore: unused_local_variable
    double? sko;

    if ((location = _getLocationIfValid(coordinatesData['GPS'])) != null && (sko = _getSKOIfValid(coordinatesData['GPS'])) != null) {
      _setMapCenter(location!);
    } else if ((location = _getLocationIfValid(coordinatesData['GLN'])) != null && (sko = _getSKOIfValid(coordinatesData['GLN'])) != null) {
      _setMapCenter(location!);
    } else if ((location = _getLocationIfValid(coordinatesData['GAL'])) != null && (sko = _getSKOIfValid(coordinatesData['GAL'])) != null) {
      _setMapCenter(location!);
    } else if ((location = _getLocationIfValid(coordinatesData['BDS'])) != null && (sko = _getSKOIfValid(coordinatesData['BDS'])) != null) {
      _setMapCenter(location!);
    }

    _initialZoomSet = true;
  }

  // Метод для управления режимом следования
  void _toggleFollowMarker(Map<String, String> coordinatesData) {
    setState(() {
      _isFollowingMarker = !_isFollowingMarker;
    });

    if (_isFollowingMarker) {
      // Если включили следование, запускаем таймер
      _followMarkerTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
        _moveToCurrentLocation(coordinatesData); // Каждую секунду обновляем положение
      });
    } else {
      // Если выключили следование, останавливаем таймер
      _followMarkerTimer?.cancel();
    }
  }

  // Устанавливаем центр карты с сохранённым зумом
  void _setMapCenter(LatLng location) {
    setState(() {
      _currentCenter = location;
      _mapController.move(location, _mapZoom);
    });
  }

  // Проверка валидности координат
  LatLng? _getLocationIfValid(String? coord) {
    LatLng? location = _parseCoordinates(coord ?? '');
    return (location != null && location.latitude != 0 && location.longitude != 0) ? location : null;
  }

  // Проверка валидности СКО
  double? _getSKOIfValid(String? coord) {
    double? sko = _parseRadius(coord ?? '');
    return (sko != null && sko > 0) ? sko : null;
  }

  List<Marker> _buildMarkers(Map<String, String> coordinatesData) {
    List<Marker> markers = [];

    coordinatesData.forEach((systemName, coord) {
      LatLng? location = _parseCoordinates(coord);
      if (location != null) {
        markers.add(Marker(
          width: 80.0,
          height: 80.0,
          point: location,
          child: Column(
            children: [
              Icon(
                Icons.location_on,
                color: _getColorByNavSys(systemName),
                size: 40,
              ),
              Text(
                systemName,
                style: TextStyle(
                  color: _getColorByNavSys(systemName),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ));
      }
    });

    return markers;
  }

  List<CircleMarker> _buildCircles(Map<String, String> coordinatesData) {
    List<CircleMarker> circles = [];

    coordinatesData.forEach((systemName, coord) {
      LatLng? location = _parseCoordinates(coord); // Получаем координаты
      double? radius = _parseRadius(coord); // Получаем радиус (СКО)
      if (location != null && radius != null && radius > 0) {
        circles.add(CircleMarker(
          point: location,
          color: _getColorByNavSys(systemName).withOpacity(0.3),
          borderStrokeWidth: 1,
          useRadiusInMeter: true,
          radius: radius,
        ));
      }
    });

    return circles;
  }

  LatLng? _parseCoordinates(String coordString) {
    // Извлекаем широту и долготу из строки
    RegExp coordPattern = RegExp(r'Широта.*?:\s([\d.]+).*Долгота.*?:\s([\d.]+)');
    final match = coordPattern.firstMatch(coordString);
    if (match != null) {
      double latitude = double.tryParse(match.group(1)!) ?? 0.0;
      double longitude = double.tryParse(match.group(2)!) ?? 0.0;
      return LatLng(latitude, longitude);
    }
    return null;
  }

  // Метод для парсинга координат и высоты
  Map<String, dynamic>? _parseCoordinatesFull(String coordString) {
    // Регулярное выражение для извлечения широты, долготы и высоты
    RegExp coordPattern = RegExp(r'Широта.*?:\s([\d.]+).*Долгота.*?:\s([\d.]+).*Высота.*?:\s([\d.]+)');
    final match = coordPattern.firstMatch(coordString);
    if (match != null) {
      double latitude = double.tryParse(match.group(1)!) ?? 0.0;
      double longitude = double.tryParse(match.group(2)!) ?? 0.0;
      double height = double.tryParse(match.group(3)!) ?? 0.0;

      // Возвращаем карту с данными
      return {
        'location': LatLng(latitude, longitude),
        'height': height,
      };
    }
    return null; // Возвращаем null, если парсинг не удался
  }

  double? _parseRadius(String coordString) {
    // Извлекаем СКО из строки для использования в качестве радиуса круга
    RegExp skoPattern = RegExp(r'СКО.*?:\s([\d.]+)');
    final match = skoPattern.firstMatch(coordString);
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }
    return null;
  }

  Color _getColorByNavSys(String navSys) {
    switch (navSys) {
      case 'GPS':
        return Colors.red;
      case 'GLN':
        return Colors.blue;
      case 'GAL':
        return Colors.orange;
      case 'BDS':
        return const Color.fromARGB(255, 5, 131, 9);
      default:
        return Colors.grey;
    }
  }

  // Метод для построения точек на карте
  List<CircleMarker> _buildCircleMarkers(Map<String, String> coordinatesData) {
    if (_isDrawingEnabled) {
      coordinatesData.forEach((systemName, coord) {
        LatLng? location = _parseCoordinates(coord);

        if (location != null) {
          // Проверяем, есть ли уже такая точка
          bool pointExists = _allCircleMarkers.any((circle) => circle.point == location);

          // Если такой точки нет, добавляем её
          if (!pointExists) {
            _allCircleMarkers.add(CircleMarker(
              point: location,
              color: _getColorByNavSys(systemName).withOpacity(1), // Цвет точки с прозрачностью
              radius: 4.0, // Размер точки
            ));
          }
        }
      });
    }

    return _allCircleMarkers;
  }

  // Метод для переключения отрисовки точек
  void _toggleDrawing() {
    setState(() {
      _isDrawingEnabled = !_isDrawingEnabled; // Переключаем состояние

      if (!_isDrawingEnabled) {
        // Если отрисовка отключена, очищаем массив точек
        _allCircleMarkers.clear();
      }
    });
  }
}
