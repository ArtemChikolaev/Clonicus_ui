import 'dart:async';
import 'dart:convert';
import 'dart:io'; // работа с файлами
import 'dart:math';
import 'dart:collection';
import 'package:flutter/material.dart'; // основа
import 'package:flutter/services.dart'; // копирование в буфер обмена
import 'package:flutter_map/flutter_map.dart'; //opensteetmap
import 'package:latlong2/latlong.dart'; //openstreetmap
import 'package:syncfusion_flutter_gauges/gauges.dart'; //спидометр
import 'package:desktop_window/desktop_window.dart'; // фиксированный размер окна приложения

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Устанавливаем минимальные размеры окна
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Задаем минимальные размеры окна
    await DesktopWindow.setMinWindowSize(const Size(1728, 972));
  }

  runApp(const Clonicus());
}

class Clonicus extends StatelessWidget {
  const Clonicus({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: _CoordinatesScreen(),
    );
  }
}

class _CoordinatesScreen extends StatefulWidget {
  @override
  _CoordinatesScreenState createState() => _CoordinatesScreenState();
}

class YAxisLabels extends StatelessWidget {
  final bool hasSatellites;

  const YAxisLabels({super.key, required this.hasSatellites});

  @override
  Widget build(BuildContext context) {
    if (!hasSatellites) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(13, (index) {
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Text(
            '${(12 - index) * 5} дБ/Гц',
            style: const TextStyle(fontSize: 13),
          ),
        );
      }),
    );
  }
}

class GridPainter extends CustomPainter {
  final bool hasSatellites;

  GridPainter({required this.hasSatellites});

  @override
  void paint(Canvas canvas, Size size) {
    if (!hasSatellites) {
      return;
    }

    double step = size.height / 12; // шаг сетки по оси Y (разделить на 12 частей)
    Paint paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (double y = size.height; y >= 0; y -= step) {
      for (double x = 0; x < size.width; x += 10) {
        canvas.drawLine(Offset(x, y), Offset(x + 5, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class SkyPlot extends StatelessWidget {
  final List<Map<String, String>> data;
  final bool hasSolutionGPS;
  final bool hasSolutionGLN;
  final bool hasSolutionGAL;
  final bool hasSolutionBDS;

  const SkyPlot({
    super.key,
    required this.data,
    required this.hasSolutionGPS,
    required this.hasSolutionGLN,
    required this.hasSolutionGAL,
    required this.hasSolutionBDS,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: SkyPlotPainter(
            data: data,
            hasSolutionGPS: hasSolutionGPS,
            hasSolutionGLN: hasSolutionGLN,
            hasSolutionGAL: hasSolutionGAL,
            hasSolutionBDS: hasSolutionBDS,
          ),
        );
      },
    );
  }
}

class SkyPlotPainter extends CustomPainter {
  final List<Map<String, String>> data;
  final bool hasSolutionGPS;
  final bool hasSolutionGLN;
  final bool hasSolutionGAL;
  final bool hasSolutionBDS;

  SkyPlotPainter({
    required this.data,
    required this.hasSolutionGPS,
    required this.hasSolutionGLN,
    required this.hasSolutionGAL,
    required this.hasSolutionBDS,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double radius = (size.width < size.height ? size.width : size.height) / 2 * 0.8; // Динамический радиус
    Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;

    double centerX = size.width / 2;
    double centerY = size.height / 2;

    // Разметка полярных осей
    _drawPolarGrid(canvas, centerX, centerY, radius);

    for (var item in data) {
      double elevation = double.tryParse(item['Угол места'] ?? '0') ?? 0;
      double azimuth = double.tryParse(item['Азимут'] ?? '0') ?? 0;

      // Преобразование углов в радианы
      double radAzimuth = (azimuth - 90) * pi / 180;

      // Вычисление координат
      double r = radius * (1 - elevation / 90); // Преобразование угла места в радиус
      double x = centerX + r * cos(radAzimuth);
      double y = centerY + r * sin(radAzimuth);

      Color color;
      String prefix;
      switch (item['Система ГНСС']) {
        case 'GPS':
          color = hasSolutionGPS ? Colors.red : Colors.grey;
          prefix = 'G';
          break;
        case 'GLN':
          color = hasSolutionGLN ? Colors.blue : Colors.grey;
          prefix = 'R';
          break;
        case 'GAL':
          color = hasSolutionGAL ? Colors.orange : Colors.grey;
          prefix = 'E';
          break;
        case 'BDS':
          color = hasSolutionBDS ? Colors.green : Colors.grey;
          prefix = 'B';
          break;
        default:
          color = Colors.grey;
          prefix = '';
          break;
      }

      // Сдвигаем крайние значения внутрь графика
      x = x.clamp(20, size.width - 20);
      y = y.clamp(20, size.height - 20);

      paint.color = color;
      canvas.drawCircle(Offset(x, y), 15, paint);

      TextSpan span = TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 12),
        text: '$prefix${item['Номер НКА']}',
      );
      TextPainter textPainter = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
    }
  }

  void _drawPolarGrid(Canvas canvas, double centerX, double centerY, double radius) {
    Paint gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Разметка по углу места
    for (int i = 0; i <= 90; i += 15) {
      double r = radius * (i / 90); // Преобразование угла места
      canvas.drawCircle(Offset(centerX, centerY), r, gridPaint);

      // Добавляем числовую разметку для угла места, кроме 0 градусов
      if (i < 90) {
        TextSpan span = TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 12),
          text: '${90 - i}°', // Инвертируем значения угла места
        );
        TextPainter textPainter = TextPainter(
          text: span,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(centerX + r, centerY - textPainter.height / 2));
      }
    }

    // Разметка по азимуту
    for (int i = 0; i < 360; i += 30) {
      double rad = (i - 90) * pi / 180;
      double x = centerX + radius * cos(rad);
      double y = centerY + radius * sin(rad);
      canvas.drawLine(Offset(centerX, centerY), Offset(x, y), gridPaint);

      // Добавляем числовую разметку для азимута
      TextSpan span = TextSpan(
        style: const TextStyle(color: Colors.black, fontSize: 12),
        text: '$i°',
      );
      TextPainter textPainter = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      double labelX = centerX + (radius + 20) * cos(rad);
      double labelY = centerY + (radius + 20) * sin(rad);
      textPainter.paint(canvas, Offset(labelX - textPainter.width / 2, labelY - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class SkyPlotWidget extends StatefulWidget {
  final List<Map<String, String>> data;
  final bool hasSolutionGPS;
  final bool hasSolutionGLN;
  final bool hasSolutionGAL;
  final bool hasSolutionBDS;

  const SkyPlotWidget({
    super.key,
    required this.data,
    required this.hasSolutionGPS,
    required this.hasSolutionGLN,
    required this.hasSolutionGAL,
    required this.hasSolutionBDS,
  });

  @override
  SkyPlotWidgetState createState() => SkyPlotWidgetState();
}

class SkyPlotWidgetState extends State<SkyPlotWidget> {
  bool showGPS = true;
  bool showGLN = true;
  bool showGAL = true;
  bool showBDS = true;
  bool showSettings = false;

  @override
  Widget build(BuildContext context) {
    List<Map<String, String>> filteredData = widget.data.where((item) {
      switch (item['Система ГНСС']) {
        case 'GPS':
          return showGPS;
        case 'GLN':
          return showGLN;
        case 'GAL':
          return showGAL;
        case 'BDS':
          return showBDS;
        default:
          return false;
      }
    }).toList();

    return Column(
      children: [
        if (showSettings)
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color.fromARGB(255, 211, 186, 253)),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Настройки отображения навигационных систем на SkyPlot',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color.fromARGB(255, 252, 149, 142)),
                      onPressed: () {
                        setState(() {
                          showSettings = false;
                        });
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    Checkbox(
                      value: showGPS,
                      onChanged: (bool? value) {
                        setState(() {
                          showGPS = value!;
                        });
                      },
                    ),
                    const Text(
                      'GPS',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 211, 186, 253)),
                    ),
                    Checkbox(
                      value: showGLN,
                      onChanged: (bool? value) {
                        setState(() {
                          showGLN = value!;
                        });
                      },
                    ),
                    const Text(
                      'GLN',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 211, 186, 253)),
                    ),
                    Checkbox(
                      value: showGAL,
                      onChanged: (bool? value) {
                        setState(() {
                          showGAL = value!;
                        });
                      },
                    ),
                    const Text(
                      'GAL',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 211, 186, 253)),
                    ),
                    Checkbox(
                      value: showBDS,
                      onChanged: (bool? value) {
                        setState(() {
                          showBDS = value!;
                        });
                      },
                    ),
                    const Text(
                      'BDS',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 211, 186, 253)),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          Center(
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  showSettings = true;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 211, 186, 253),
              ),
              child: const Text('Настроить SkyPlot'),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: SkyPlotPainter(
                  data: filteredData,
                  hasSolutionGPS: widget.hasSolutionGPS,
                  hasSolutionGLN: widget.hasSolutionGLN,
                  hasSolutionGAL: widget.hasSolutionGAL,
                  hasSolutionBDS: widget.hasSolutionBDS,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class DynamicSpeedometer extends StatelessWidget {
  final double gpsSpeed;
  final double glnSpeed;
  final double galSpeed;
  final double bdsSpeed;
  final bool hasSolutionGPS;
  final bool hasSolutionGLN;
  final bool hasSolutionGAL;
  final bool hasSolutionBDS;

  const DynamicSpeedometer({
    super.key,
    required this.gpsSpeed,
    required this.glnSpeed,
    required this.galSpeed,
    required this.bdsSpeed,
    required this.hasSolutionGPS,
    required this.hasSolutionGLN,
    required this.hasSolutionGAL,
    required this.hasSolutionBDS,
  });

  @override
  Widget build(BuildContext context) {
    // Сохранение валидных скоростей
    List<double> validSpeeds = [];
    if (hasSolutionGPS && gpsSpeed > 0) validSpeeds.add(gpsSpeed);
    if (hasSolutionGLN && glnSpeed > 0) validSpeeds.add(glnSpeed);
    if (hasSolutionGAL && galSpeed > 0) validSpeeds.add(galSpeed);
    if (hasSolutionBDS && bdsSpeed > 0) validSpeeds.add(bdsSpeed);

    // Рассчет средней скорости
    double averageSpeed = validSpeeds.isNotEmpty ? validSpeeds.reduce((a, b) => a + b) / validSpeeds.length : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        double size = constraints.maxWidth < constraints.maxHeight ? constraints.maxWidth : constraints.maxHeight;
        return FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: size,
            height: size,
            child: SfRadialGauge(
              axes: <RadialAxis>[
                RadialAxis(
                  minimum: 0,
                  maximum: 100,
                  interval: 10,
                  ranges: <GaugeRange>[
                    GaugeRange(
                      startValue: 0,
                      endValue: 100,
                      color: Colors.blue,
                    ),
                  ],
                  pointers: <GaugePointer>[
                    NeedlePointer(
                      value: averageSpeed,
                      needleColor: Colors.red,
                      needleLength: 0.8,
                      needleEndWidth: 5,
                      enableAnimation: true,
                      animationType: AnimationType.ease,
                    ),
                  ],
                  annotations: <GaugeAnnotation>[
                    GaugeAnnotation(
                      widget: Text(
                        '${averageSpeed.toStringAsFixed(4)} м/с',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      angle: 90,
                      positionFactor: 0.75,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CoordinatesScreenState extends State<_CoordinatesScreen> {
  List<String> _coordinates = [];
  final Queue<String> _dataF5Queue = Queue<String>();
  final Queue<Map<String, String>> _data55Queue = Queue<Map<String, String>>();
  final Queue<Map<String, String>> _velocityQueue = Queue<Map<String, String>>();
  Timer? _timer;
  Timer? _followMarkerTimer;
  late File _file;
  late File _file2;
  late File _file3;
  bool _isReading = false;
  LatLng? _currentLocationGPS;
  LatLng? _currentLocationGLN;
  LatLng? _currentLocationGAL;
  LatLng? _currentLocationBDS;
  LatLng? _markerLocation;
  double? _markerHeight;
  List<String> _lastTenCoordinates = [];
  double? _currentSKOGPS;
  double? _currentSKOGLN;
  double? _currentSKOGAL;
  double? _currentSKOBDS;

  double? _currentHeightGPS;
  double? _currentHeightGLN;
  double? _currentHeightGAL;
  double? _currentHeightBDS;

  double? _distanceToMarkerGPS;
  double? _distanceToMarkerGLN;
  double? _distanceToMarkerGAL;
  double? _distanceToMarkerBDS;
  final MapController _mapController = MapController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _coordsController = TextEditingController();
  bool _isInputFieldVisible = false;
  bool _isFollowingMarker = false;
  bool _initialZoomSet = false; // Флаг для начального значения зума

  LatLng _currentCenter = const LatLng(55.751244, 37.618423); // Начальное положение
  double _currentZoom = 16.0;

  bool _showAllPoints = false;
  final List<LatLng> _allPointsGPS = [];
  final List<LatLng> _allPointsGLN = [];
  final List<LatLng> _allPointsGAL = [];
  final List<LatLng> _allPointsBDS = [];

  double _gpsSpeed = 0.0;
  double _glnSpeed = 0.0;
  double _galSpeed = 0.0;
  double _bdsSpeed = 0.0;

  File? recordingFile;
  bool isRecording = false;

  final TextEditingController commandController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startClock();
    _file = File('/tmp/srns_0x0050.txt');
    _file2 = File('/tmp/srns_0x00F5.txt');
    _file3 = File('/tmp/srns_0x0055.txt');
  }

  Future<void> _readLastCoordinates() async {
    try {
      final lines = await _file.readAsLines();
      if (lines.isNotEmpty) {
        final startIndex = lines.length > 20 ? lines.length - 20 : 0;
        final newLines = lines.sublist(startIndex);

        List<LatLng> recentLocationsGPS = [];
        List<LatLng> recentLocationsGLN = [];
        List<LatLng> recentLocationsGAL = [];
        List<LatLng> recentLocationsBDS = [];
        List<double> latitudesGPS = [];
        List<double> longitudesGPS = [];
        List<double> heightsGPS = [];
        double velocityGPS = 0.0;
        List<double> latitudesGLN = [];
        List<double> longitudesGLN = [];
        List<double> heightsGLN = [];
        double velocityGLN = 0.0;
        List<double> latitudesGAL = [];
        List<double> longitudesGAL = [];
        List<double> heightsGAL = [];
        double velocityGAL = 0.0;
        List<double> latitudesBDS = [];
        List<double> longitudesBDS = [];
        List<double> heightsBDS = [];
        double velocityBDS = 0.0;

        List<double> skoGPSnew = [];
        List<double> skoGLNnew = [];
        List<double> skoGALnew = [];
        List<double> skoBDSnew = [];

        List<double> pdopGPSnew = [];
        List<double> pdopGLNnew = [];
        List<double> pdopGALnew = [];
        List<double> pdopBDSnew = [];

        for (var line in newLines) {
          List<String> parts = line.split(',');
          if (parts.length > 10) {
            double latitude = double.parse(parts[4].trim().replaceAll('deg', '').trim());
            double longitude = double.parse(parts[5].trim().replaceAll('deg', '').trim());
            String height = '';
            for (String part in parts) {
              if (part.trim().startsWith('h=')) {
                height = part.trim().replaceAll('h=', '').replaceAll('m', '').trim();
                break;
              }
            }
            LatLng location = LatLng(latitude, longitude);
            double velocity = double.parse(parts[10].trim().replaceAll('|V|=', '').replaceAll('m/s', '').trim());
            double skoNew = double.parse(parts[11].trim().replaceAll('RMS=', '').replaceAll('m', '').trim());
            double pdopParse = double.parse(parts[12].trim().replaceAll('PDOP=', '').trim());

            switch (parts[2].trim()) {
              case 'GPS':
                recentLocationsGPS.add(location);
                latitudesGPS.add(latitude);
                longitudesGPS.add(longitude);
                if (height.isNotEmpty) {
                  heightsGPS.add(double.parse(height));
                }
                velocityGPS = velocity;
                skoGPSnew.add(skoNew);
                pdopGPSnew.add(pdopParse);
                break;
              case 'GLN':
                recentLocationsGLN.add(location);
                latitudesGLN.add(latitude);
                longitudesGLN.add(longitude);
                if (height.isNotEmpty) {
                  heightsGLN.add(double.parse(height));
                }
                velocityGLN = velocity;
                skoGLNnew.add(skoNew);
                pdopGLNnew.add(pdopParse);
                break;
              case 'GAL':
                recentLocationsGAL.add(location);
                latitudesGAL.add(latitude);
                longitudesGAL.add(longitude);
                if (height.isNotEmpty) {
                  heightsGAL.add(double.parse(height));
                }
                velocityGAL = velocity;
                skoGALnew.add(skoNew);
                pdopGALnew.add(pdopParse);
                break;
              case 'BDS':
                recentLocationsBDS.add(location);
                latitudesBDS.add(latitude);
                longitudesBDS.add(longitude);
                if (height.isNotEmpty) {
                  heightsBDS.add(double.parse(height));
                }
                velocityBDS = velocity;
                skoBDSnew.add(skoNew);
                pdopBDSnew.add(pdopParse);
                break;
              default:
                break;
            }
          }
        }

        // Список для хранения последних координат
        List<String> lastCoordinates = [];

        // Добавляем последние координаты для каждой активной системы
        if (recentLocationsGPS.isNotEmpty) {
          if (velocityGPS < 1.0) {
            LatLng averageLocationGPS = _calculateAverageLatLng(recentLocationsGPS);
            double averageLatitudeGPS = latitudesGPS.isNotEmpty ? _calculateAverage(latitudesGPS) : 0.0;
            double averageLongitudeGPS = longitudesGPS.isNotEmpty ? _calculateAverage(longitudesGPS) : 0.0;
            double averageHeightGPS = heightsGPS.isNotEmpty ? _calculateAverage(heightsGPS) : 0.0;
            double skoGPS = skoGPSnew.isNotEmpty ? _calculateAverage(skoGPSnew) : 0.0;
            double pdopGPS = pdopGPSnew.isNotEmpty ? _calculateAverage(pdopGPSnew) : 0.0;

            setState(() {
              _currentLocationGPS = averageLocationGPS;
              _currentHeightGPS = averageHeightGPS;
              _currentSKOGPS = skoGPS;
              if (_showAllPoints) _allPointsGPS.add(averageLocationGPS);
            });

            lastCoordinates.add('Широта\'(GPS): ${averageLatitudeGPS.toStringAsFixed(7)} °, Долгота\'(GPS): ${averageLongitudeGPS.toStringAsFixed(7)} °, Высота\'(GPS): ${averageHeightGPS.toStringAsFixed(4)} м, СКО\'(GPS): ${skoGPS.toStringAsFixed(2)} м, PDOP\'(GPS): ${pdopGPS.toStringAsFixed(2)}');
          } else {
            LatLng lastLocationGPS = recentLocationsGPS.last;
            double lastLatitudeGPS = latitudesGPS.last;
            double lastLongitudeGPS = longitudesGPS.last;
            double lastHeightGPS = heightsGPS.isNotEmpty ? heightsGPS.last : 0.0;
            double lastPDOPGPS = pdopGPSnew.last;
            double lastSKOGPS = skoGPSnew.last;

            setState(() {
              _currentLocationGPS = lastLocationGPS;
              _currentHeightGPS = lastHeightGPS;
              _currentSKOGPS = lastSKOGPS;
              if (_showAllPoints) _allPointsGPS.add(lastLocationGPS);
            });

            lastCoordinates.add('Широта(GPS): ${lastLatitudeGPS.toStringAsFixed(7)} °, Долгота(GPS): ${lastLongitudeGPS.toStringAsFixed(7)} °, Высота(GPS): ${lastHeightGPS.toStringAsFixed(4)} м, СКО(GPS): ${lastSKOGPS.toStringAsFixed(2)} м, PDOP(GPS): ${lastPDOPGPS.toStringAsFixed(2)}');
          }
        }

        if (recentLocationsGLN.isNotEmpty) {
          if (velocityGLN < 1.0) {
            LatLng averageLocationGLN = _calculateAverageLatLng(recentLocationsGLN);
            double averageLatitudeGLN = latitudesGLN.isNotEmpty ? _calculateAverage(latitudesGLN) : 0.0;
            double averageLongitudeGLN = longitudesGLN.isNotEmpty ? _calculateAverage(longitudesGLN) : 0.0;
            double averageHeightGLN = heightsGLN.isNotEmpty ? _calculateAverage(heightsGLN) : 0.0;
            double skoGLN = skoGLNnew.isNotEmpty ? _calculateAverage(skoGLNnew) : 0.0;
            double pdopGLN = pdopGLNnew.isNotEmpty ? _calculateAverage(pdopGLNnew) : 0.0;

            setState(() {
              _currentLocationGLN = averageLocationGLN;
              _currentHeightGLN = averageHeightGLN;
              _currentSKOGLN = skoGLN;
              if (_showAllPoints) _allPointsGLN.add(averageLocationGLN);
            });

            lastCoordinates.add('Широта\'(GLN): ${averageLatitudeGLN.toStringAsFixed(7)} °, Долгота\'(GLN): ${averageLongitudeGLN.toStringAsFixed(7)} °, Высота\'(GLN): ${averageHeightGLN.toStringAsFixed(4)} м, СКО\'(GLN): ${skoGLN.toStringAsFixed(2)} м, PDOP\'(GLN): ${pdopGLN.toStringAsFixed(2)}');
          } else {
            LatLng lastLocationGLN = recentLocationsGLN.last;
            double lastLatitudeGLN = latitudesGLN.last;
            double lastLongitudeGLN = longitudesGLN.last;
            double lastHeightGLN = heightsGLN.isNotEmpty ? heightsGLN.last : 0.0;
            double skoGLN = skoGLNnew.last;
            double lastSKOGLN = pdopGLNnew.last;

            setState(() {
              _currentLocationGLN = lastLocationGLN;
              _currentHeightGLN = lastHeightGLN;
              _currentSKOGLN = skoGLN;
              if (_showAllPoints) _allPointsGLN.add(lastLocationGLN);
            });

            lastCoordinates.add('Широта(GLN): ${lastLatitudeGLN.toStringAsFixed(7)} °, Долгота(GLN): ${lastLongitudeGLN.toStringAsFixed(7)} °, Высота(GLN): ${lastHeightGLN.toStringAsFixed(4)} м, СКО(GLN): ${skoGLN.toStringAsFixed(2)} м, PDOP(GLN): ${lastSKOGLN.toStringAsFixed(2)}');
          }
        }

        if (recentLocationsGAL.isNotEmpty) {
          if (velocityGAL < 1.0) {
            LatLng averageLocationGAL = _calculateAverageLatLng(recentLocationsGAL);
            double averageLatitudeGAL = latitudesGAL.isNotEmpty ? _calculateAverage(latitudesGAL) : 0.0;
            double averageLongitudeGAL = longitudesGAL.isNotEmpty ? _calculateAverage(longitudesGAL) : 0.0;
            double averageHeightGAL = heightsGAL.isNotEmpty ? _calculateAverage(heightsGAL) : 0.0;
            double skoGAL = skoGALnew.isNotEmpty ? _calculateAverage(skoGALnew) : 0.0;
            double pdopGAL = pdopGALnew.isNotEmpty ? _calculateAverage(pdopGALnew) : 0.0;

            setState(() {
              _currentLocationGAL = averageLocationGAL;
              _currentHeightGAL = averageHeightGAL;
              _currentSKOGAL = skoGAL;
              if (_showAllPoints) _allPointsGAL.add(averageLocationGAL);
            });

            lastCoordinates.add('Широта\'(GAL): ${averageLatitudeGAL.toStringAsFixed(7)} °, Долгота\'(GAL): ${averageLongitudeGAL.toStringAsFixed(7)} °, Высота\'(GAL): ${averageHeightGAL.toStringAsFixed(4)} м, СКО\'(GAL): ${skoGAL.toStringAsFixed(2)} м, PDOP\'(GAL): ${pdopGAL.toStringAsFixed(2)}');
          } else {
            LatLng lastLocationGAL = recentLocationsGAL.last;
            double lastLatitudeGAL = latitudesGAL.last;
            double lastLongitudeGAL = longitudesGAL.last;
            double lastHeightGAL = heightsGAL.isNotEmpty ? heightsGAL.last : 0.0;
            double skoGAL = skoGALnew.last;
            double lastPDOPGAL = pdopGALnew.last;

            setState(() {
              _currentLocationGAL = lastLocationGAL;
              _currentHeightGAL = lastHeightGAL;
              _currentSKOGAL = skoGAL;
              if (_showAllPoints) _allPointsGAL.add(lastLocationGAL);
            });

            lastCoordinates.add('Широта(GAL): ${lastLatitudeGAL.toStringAsFixed(7)} °, Долгота(GAL): ${lastLongitudeGAL.toStringAsFixed(7)} °, Высота(GAL): ${lastHeightGAL.toStringAsFixed(4)} м, СКО(GAL): ${skoGAL.toStringAsFixed(2)} м, PDOP(GAL): ${lastPDOPGAL.toStringAsFixed(2)}');
          }
        }

        if (recentLocationsBDS.isNotEmpty) {
          if (velocityBDS < 1.0) {
            LatLng averageLocationBDS = _calculateAverageLatLng(recentLocationsBDS);
            double averageLatitudeBDS = latitudesBDS.isNotEmpty ? _calculateAverage(latitudesBDS) : 0.0;
            double averageLongitudeBDS = longitudesBDS.isNotEmpty ? _calculateAverage(longitudesBDS) : 0.0;
            double averageHeightBDS = heightsBDS.isNotEmpty ? _calculateAverage(heightsBDS) : 0.0;
            double skoBDS = skoBDSnew.isNotEmpty ? _calculateAverage(skoBDSnew) : 0.0;
            double pdopBDS = pdopBDSnew.isNotEmpty ? _calculateAverage(pdopBDSnew) : 0.0;

            setState(() {
              _currentLocationBDS = averageLocationBDS;
              _currentHeightBDS = averageHeightBDS;
              _currentSKOBDS = skoBDS;
              if (_showAllPoints) _allPointsBDS.add(averageLocationBDS);
            });

            lastCoordinates.add('Широта\'(BDS): ${averageLatitudeBDS.toStringAsFixed(7)} °, Долгота\'(BDS): ${averageLongitudeBDS.toStringAsFixed(7)} °, Высота\'(BDS): ${averageHeightBDS.toStringAsFixed(4)} м, СКО\'(BDS): ${skoBDS.toStringAsFixed(2)} м, PDOP\'(BDS): ${pdopBDS.toStringAsFixed(2)}');
          } else {
            LatLng lastLocationBDS = recentLocationsBDS.last;
            double lastLatitudeBDS = latitudesBDS.last;
            double lastLongitudeBDS = longitudesBDS.last;
            double lastHeightBDS = heightsBDS.isNotEmpty ? heightsBDS.last : 0.0;
            double skoBDS = skoBDSnew.last;
            double lastPDOPBDS = pdopBDSnew.last;

            setState(() {
              _currentLocationBDS = lastLocationBDS;
              _currentHeightBDS = lastHeightBDS;
              _currentSKOBDS = skoBDS;
              if (_showAllPoints) _allPointsBDS.add(lastLocationBDS);
            });

            lastCoordinates.add('Широта(BDS): ${lastLatitudeBDS.toStringAsFixed(7)} °, Долгота(BDS): ${lastLongitudeBDS.toStringAsFixed(7)} °, Высота(BDS): ${lastHeightBDS.toStringAsFixed(4)} м, СКО(BDS): ${skoBDS.toStringAsFixed(2)} м, PDOP(BDS): ${lastPDOPBDS.toStringAsFixed(2)}');
          }
        }

        // Определяем количество последних координат для отображения
        int maxCoordinatesToShow = lastCoordinates.length;
        if (maxCoordinatesToShow > 4) {
          maxCoordinatesToShow = 4; // Показываем максимум 4 последние координаты
        }

        // Ограничиваем количество последних координат
        _lastTenCoordinates = lastCoordinates.sublist(0, maxCoordinatesToShow);

        setState(() {
          _coordinates = List.from(_lastTenCoordinates);
        });

        // Вычисляем расстояния до маркера для каждой активной системы
        _updateDistancesToMarker();
      } else {
        setState(() {
          _coordinates = [
            'Нет данных для расчета'
          ];
        });
      }
    } catch (e) {
      setState(() {
        _coordinates = [
          'Ошибка при чтении файла: файл srns_0x0050.txt не найден'
        ];
      });
    }
  }

  Future<void> _readF5Packet() async {
    try {
      List<String> lines = await _file2.readAsLines();

      // Создаем новую очередь для временного хранения данных
      Queue<String> newDataQueue = Queue<String>();

      // Переменная для хранения текущей секунды
      String currentTick = '';

      for (String line in lines) {
        List<String> parts = line.split(RegExp(r'\s+'));
        if (parts.length >= 7) {
          String navigationSystem = _getNavigationSystem(parts[2].trim()); // Получаем буквенное обозначение нав. сигнала
          String satelliteNumbers = parts[3];
          String signalToNoiseRatio = parts[5];
          String tickValue = parts[0];

          // Формируем новую строку данных
          String newDataItem = 'Навигационный сигнал: $navigationSystem, НКА: $satelliteNumbers, ОСШ: $signalToNoiseRatio';
          // String newDataItem = 'Навигационная система: $navigationSystem, Номера спутников: $satelliteNumbers, Сигнал/шум: $signalToNoiseRatio, Секунда: $tickValue';

          // Если текущая секунда изменилась, очищаем временную очередь и обновляем текущее время
          if (currentTick.isEmpty || tickValue != currentTick) {
            currentTick = tickValue;
            newDataQueue.clear();
          }

          // Добавляем новые данные в очередь
          newDataQueue.addLast(newDataItem);
        }
      }

      // Определяем максимальный размер очереди как количество элементов с текущим временем
      int maxQueueSize = newDataQueue.length;

      // Очищаем основную очередь и добавляем туда актуальные данные
      setState(() {
        _dataF5Queue.clear();
        for (var item in newDataQueue) {
          if (_dataF5Queue.length < maxQueueSize) {
            _dataF5Queue.addLast(item);
          }
        }
      });
    } catch (e) {
      // print('Ошибка при чтении файла: файл srns_0x00F5.txt не найден');
    }
  }

// Функция для получения буквенного обозначения навигационной системы по числовому коду
  String _getNavigationSystem(String code) {
    switch (code) {
      case '1':
        return 'GlnL1OF';
      case '33':
        return 'GlnL2OF';
      case '2':
        return 'GpsL1CA';
      case '34':
        return 'GpsL2CM';
      case '66':
        return 'GpsL5I';
      case '6':
        return 'GalE1B';
      case '38':
        return 'GalE5aI';
      case '55':
        return 'GalE5bI';
      case '8':
        return 'BdsB1I';
      case '40':
        return 'BdsB2I';
      default:
        return 'Unknown'; // Если код не соответствует ни одному известному нав. сигналу
    }
  }

  Map<String, int> _countSatellitesFromQueue(Queue<String> dataQueue) {
    int gpsCount = 0;
    int gpsL2Count = 0;
    int gpsL5Count = 0;
    int glnCount = 0;
    int glnL2Count = 0;
    int galCount = 0;
    int galL5aCount = 0;
    int galL5bCount = 0;
    int bdsCount = 0;
    int bdsL2Count = 0;

    for (String dataItem in dataQueue) {
      if (dataItem.contains('GpsL1CA')) {
        gpsCount++;
      } else if (dataItem.contains('GpsL2CM')) {
        gpsL2Count++;
      } else if (dataItem.contains('GpsL5I')) {
        gpsL5Count++;
      } else if (dataItem.contains('GlnL1OF')) {
        glnCount++;
      } else if (dataItem.contains('GlnL2OF')) {
        glnL2Count++;
      } else if (dataItem.contains('GalE1B')) {
        galCount++;
      } else if (dataItem.contains('GalE5aI')) {
        galL5aCount++;
      } else if (dataItem.contains('GalE5bI')) {
        galL5bCount++;
      } else if (dataItem.contains('BdsB1I')) {
        bdsCount++;
      } else if (dataItem.contains('BdsB2I')) {
        bdsL2Count++;
      }
    }

    int totalSatellites = gpsCount + gpsL2Count + gpsL5Count + glnCount + glnL2Count + galCount + galL5aCount + galL5bCount + bdsCount + bdsL2Count;

    return {
      'GPS': gpsCount,
      'GPSL2': gpsL2Count,
      'GPSL5': gpsL5Count,
      'GLN': glnCount,
      'GLNL2': glnL2Count,
      'GAL': galCount,
      'GALL5a': galL5aCount,
      'GALL5b': galL5bCount,
      'BDS': bdsCount,
      'BDSL2': bdsL2Count,
      'TOTAL': totalSatellites,
    };
  }

  Widget buildHistogram(double containerHeight) {
    Map<int, Map<String, List<int>>> histogramData = _computeHistogramData();

    List<String> signalTypesOrder = [
      'GpsL1CA',
      'GpsL2CM',
      'GpsL5I',
      'GlnL1OF',
      'GlnL2OF',
      'GalE1B',
      'GalE5aI',
      'GalE5bI',
      'BdsB1I',
      'BdsB2I'
    ];

    List<Widget> bars = [];
    Set<int> processedGlnL2OF = {}; // Для отслеживания уже обработанных сигналов GlnL2OF
    Set<int> processedBdsB2I = {}; // Для отслеживания уже обработанных сигналов BdsB2I
    Set<int> processedGpsL2CM = {}; // Для отслеживания уже обработанных сигналов GpsL2CM
    Set<int> processedGpsL5I = {}; // Для отслеживания уже обработанных сигналов GpsL5I
    Set<int> processedGalE5aI = {}; // Для отслеживания уже обработанных сигналов GalE5aI
    Set<int> processedGalE5bI = {}; // Для отслеживания уже обработанных сигналов GalE5bI

    for (String signalType in signalTypesOrder) {
      bool hasSolution;
      switch (signalType) {
        case 'GpsL1CA':
        case 'GpsL2CM':
        case 'GpsL5I':
          hasSolution = _currentLocationGPS != null && _currentLocationGPS!.latitude != 0.0 && _currentLocationGPS!.longitude != 0.0;
          break;
        case 'GlnL1OF':
        case 'GlnL2OF':
          hasSolution = _currentLocationGLN != null && _currentLocationGLN!.latitude != 0.0 && _currentLocationGLN!.longitude != 0.0;
          break;
        case 'GalE1B':
        case 'GalE5aI':
        case 'GalE5bI':
          hasSolution = _currentLocationGAL != null && _currentLocationGAL!.latitude != 0.0 && _currentLocationGAL!.longitude != 0.0;
          break;
        case 'BdsB1I':
        case 'BdsB2I':
          hasSolution = _currentLocationBDS != null && _currentLocationBDS!.latitude != 0.0 && _currentLocationBDS!.longitude != 0.0;
          break;
        default:
          hasSolution = false;
      }

      List<MapEntry<int, List<int>>> sortedSatellites = histogramData.entries.where((entry) => entry.value.containsKey(signalType)).map((entry) => MapEntry(entry.key, entry.value[signalType]!)).toList()..sort((a, b) => a.key.compareTo(b.key));

      for (var entry in sortedSatellites) {
        int satelliteNumber = entry.key;
        List<int> signalNoiseList = entry.value;
        double averageSignalToNoise = signalNoiseList.isNotEmpty ? signalNoiseList.reduce((a, b) => a + b) / signalNoiseList.length : 0.0;

        Color barColor;
        String prefix;
        switch (signalType) {
          case 'GpsL1CA':
            barColor = hasSolution ? Colors.red : Colors.grey;
            prefix = 'G';
            break;
          case 'GpsL2CM':
            barColor = hasSolution ? const Color.fromARGB(255, 122, 18, 10) : Colors.grey;
            prefix = 'G';
            break;
          case 'GpsL5I':
            barColor = hasSolution ? const Color.fromARGB(255, 53, 4, 1) : Colors.grey;
            prefix = 'G';
            break;
          case 'GlnL1OF':
            barColor = hasSolution ? Colors.blue : Colors.grey;
            prefix = 'R';
            break;
          case 'GlnL2OF':
            barColor = hasSolution ? const Color.fromARGB(255, 14, 80, 134) : Colors.grey;
            prefix = 'R';
            break;
          case 'GalE1B':
            barColor = hasSolution ? Colors.orange : Colors.grey;
            prefix = 'E';
            break;
          case 'GalE5aI':
            barColor = hasSolution ? const Color.fromARGB(255, 156, 97, 8) : Colors.grey;
            prefix = 'E';
            break;
          case 'GalE5bI':
            barColor = hasSolution ? const Color.fromARGB(255, 95, 59, 6) : Colors.grey;
            prefix = 'E';
            break;
          case 'BdsB1I':
            barColor = hasSolution ? const Color.fromARGB(255, 5, 131, 9) : Colors.grey;
            prefix = 'B';
            break;
          case 'BdsB2I':
            barColor = hasSolution ? const Color.fromARGB(255, 2, 77, 5) : Colors.grey;
            prefix = 'B';
            break;
          default:
            barColor = Colors.grey;
            prefix = '';
        }

        // Обработка GlnL2OF, если он уже был обработан как часть GlnL1OF
        if (signalType == 'GlnL2OF' && processedGlnL2OF.contains(satelliteNumber)) {
          continue;
        }

        // Обработка BdsB2I, если он уже был обработан как часть BdsB1I
        if (signalType == 'BdsB2I' && processedBdsB2I.contains(satelliteNumber)) {
          continue;
        }

        // Обработка GpsL2CM, если он уже был обработан как часть GpsL1CA
        if (signalType == 'GpsL2CM' && processedGpsL2CM.contains(satelliteNumber)) {
          continue;
        }
        // Обработка GpsL5I, если он уже был обработан как часть GpsL1CA и GpsL2CM
        if (signalType == 'GpsL5I' && processedGpsL5I.contains(satelliteNumber)) {
          continue;
        }

        // Обработка GalE5aI, если он уже был обработан как часть GalE1B
        if (signalType == 'GalE5aI' && processedGalE5aI.contains(satelliteNumber)) {
          continue;
        }

        // Обработка GalE5bI, если он уже был обработан как часть GalE1B и GalE5bI
        if (signalType == 'GalE5bI' && processedGalE5bI.contains(satelliteNumber)) {
          continue;
        }

        bars.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: _buildBar(averageSignalToNoise, '$prefix$satelliteNumber', barColor, containerHeight),
        ));

        // Обработка дополнительного столбика GlnL2OF рядом с GlnL1OF
        if (signalType == 'GlnL1OF' && histogramData[satelliteNumber]!.containsKey('GlnL2OF')) {
          List<int> glnL2OFList = histogramData[satelliteNumber]!['GlnL2OF']!;
          double averageSignalToNoiseGlnL2OF = glnL2OFList.isNotEmpty ? glnL2OFList.reduce((a, b) => a + b) / glnL2OFList.length : 0.0;
          Color glnL2OFColor = hasSolution ? const Color.fromARGB(255, 14, 80, 134) : Colors.grey;

          bars.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: _buildBar(averageSignalToNoiseGlnL2OF, '$prefix$satelliteNumber', glnL2OFColor, containerHeight),
          ));

          processedGlnL2OF.add(satelliteNumber); // Пометить как обработанный
        }

        // Обработка дополнительного столбика BdsB2I рядом с BdsB1I
        if (signalType == 'BdsB1I' && histogramData[satelliteNumber]!.containsKey('BdsB2I')) {
          List<int> bdsB2IList = histogramData[satelliteNumber]!['BdsB2I']!;
          double averageSignalToNoiseBdsB2I = bdsB2IList.isNotEmpty ? bdsB2IList.reduce((a, b) => a + b) / bdsB2IList.length : 0.0;
          Color bdsB2IColor = hasSolution ? const Color.fromARGB(255, 2, 77, 5) : Colors.grey;

          bars.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: _buildBar(averageSignalToNoiseBdsB2I, '$prefix$satelliteNumber', bdsB2IColor, containerHeight),
          ));

          processedBdsB2I.add(satelliteNumber); // Пометить как обработанный
        }

        // Обработка дополнительного столбика GpsL2CM рядом с GpsL1CA
        if (signalType == 'GpsL1CA' && histogramData[satelliteNumber]!.containsKey('GpsL2CM')) {
          List<int> gpsL2CMList = histogramData[satelliteNumber]!['GpsL2CM']!;
          double averageSignalToNoiseGpsL2CM = gpsL2CMList.isNotEmpty ? gpsL2CMList.reduce((a, b) => a + b) / gpsL2CMList.length : 0.0;
          Color gpsL2CMColor = hasSolution ? const Color.fromARGB(255, 122, 18, 10) : Colors.grey;

          bars.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: _buildBar(averageSignalToNoiseGpsL2CM, '$prefix$satelliteNumber', gpsL2CMColor, containerHeight),
          ));

          processedGpsL2CM.add(satelliteNumber); // Пометить как обработанный
        }

        // Обработка дополнительного столбика GpsL5I рядом с GpsL1CA или GpsL2CM
        if ((signalType == 'GpsL1CA' && signalType == 'GpsL2CM') || (signalType == 'GpsL1CA' || signalType == 'GpsL2CM') && histogramData[satelliteNumber]!.containsKey('GpsL5I')) {
          List<int> gpsL5IList = histogramData[satelliteNumber]!['GpsL5I']!;
          double averageSignalToNoiseGpsL5I = gpsL5IList.isNotEmpty ? gpsL5IList.reduce((a, b) => a + b) / gpsL5IList.length : 0.0;
          Color gpsL5IColor = hasSolution ? const Color.fromARGB(255, 71, 6, 2) : Colors.grey;

          bars.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: _buildBar(averageSignalToNoiseGpsL5I, '$prefix$satelliteNumber', gpsL5IColor, containerHeight),
          ));

          processedGpsL5I.add(satelliteNumber);
        }

        // Обработка дополнительного столбика GalE5aI рядом с GalE1B
        if (signalType == 'GalE1B' && histogramData[satelliteNumber]!.containsKey('GalE5aI')) {
          List<int> galE5aIList = histogramData[satelliteNumber]!['GalE5aI']!;
          double averageSignalToNoiseGalE5aI = galE5aIList.isNotEmpty ? galE5aIList.reduce((a, b) => a + b) / galE5aIList.length : 0.0;
          Color galE5aIColor = hasSolution ? const Color.fromARGB(255, 156, 97, 8) : Colors.grey;

          bars.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: _buildBar(averageSignalToNoiseGalE5aI, '$prefix$satelliteNumber', galE5aIColor, containerHeight),
          ));

          processedGalE5aI.add(satelliteNumber); // Пометить как обработанный
        }

        // Обработка дополнительного столбика GalE5bI рядом с GalE1B или GalE5aI
        if ((signalType == 'GalE1B' && signalType == 'GalE5aI') || (signalType == 'GalE1B' || signalType == 'GalE5aI') && histogramData[satelliteNumber]!.containsKey('GalE5bI')) {
          List<int> galE5bIList = histogramData[satelliteNumber]!['GalE5bI']!;
          double averageSignalToNoiseGalE5bI = galE5bIList.isNotEmpty ? galE5bIList.reduce((a, b) => a + b) / galE5bIList.length : 0.0;
          Color galE5bIColor = hasSolution ? const Color.fromARGB(255, 95, 59, 6) : Colors.grey;

          bars.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: _buildBar(averageSignalToNoiseGalE5bI, '$prefix$satelliteNumber', galE5bIColor, containerHeight),
          ));

          processedGalE5bI.add(satelliteNumber);
        }
      }
    }

    return Row(children: bars);
  }

  bool _hasSatellites() {
    Map<int, Map<String, List<int>>> histogramData = _computeHistogramData();
    return histogramData.isNotEmpty;
  }

  Map<int, Map<String, List<int>>> _computeHistogramData() {
    Map<int, Map<String, List<int>>> satelliteSignalNoise = {};

    for (String item in _dataF5Queue) {
      if (item.contains('НКА: ')) {
        int satelliteNumber = _extractSatelliteNumber(item);
        int signalToNoise = _extractSignalToNoise(item);
        String signalType = _extractSignalType(item);

        if (!satelliteSignalNoise.containsKey(satelliteNumber)) {
          satelliteSignalNoise[satelliteNumber] = {};
        }
        if (!satelliteSignalNoise[satelliteNumber]!.containsKey(signalType)) {
          satelliteSignalNoise[satelliteNumber]![signalType] = [];
        }
        satelliteSignalNoise[satelliteNumber]![signalType]!.add(signalToNoise);
      }
    }

    return satelliteSignalNoise;
  }

// Метод для извлечения номера спутника из строки данных
  int _extractSatelliteNumber(String dataItem) {
    // Регулярное выражение для извлечения номера спутника
    RegExp regex = RegExp(r'НКА: (\d+)');
    // Находим соответствие в строке и возвращаем значение
    Match? match = regex.firstMatch(dataItem);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return 0; // Возвращаем 0, если значение не найдено
  }

// Метод для извлечения значения сигнала/шума из строки данных
  int _extractSignalToNoise(String dataItem) {
    // Регулярное выражение для извлечения значения сигнала/шума
    RegExp regex = RegExp(r'ОСШ: (\d+)');
    // Находим соответствие в строке и возвращаем значение
    Match? match = regex.firstMatch(dataItem);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return 0; // Возвращаем 0, если значение не найдено
  }

// Метод для извлечения типа сигнала из строки данных
  String _extractSignalType(String dataItem) {
    if (dataItem.contains('GpsL1CA')) {
      return 'GpsL1CA';
    } else if (dataItem.contains('GpsL2CM')) {
      return 'GpsL2CM';
    } else if (dataItem.contains('GpsL5I')) {
      return 'GpsL5I';
    } else if (dataItem.contains('GlnL1OF')) {
      return 'GlnL1OF';
    } else if (dataItem.contains('GlnL2OF')) {
      return 'GlnL2OF';
    } else if (dataItem.contains('GalE1B')) {
      return 'GalE1B';
    } else if (dataItem.contains('GalE5aI')) {
      return 'GalE5aI';
    } else if (dataItem.contains('GalE5bI')) {
      return 'GalE5bI';
    } else if (dataItem.contains('BdsB1I')) {
      return 'BdsB1I';
    } else if (dataItem.contains('BdsB2I')) {
      return 'BdsB2I';
    }
    return 'Unknown';
  }

  Widget _buildBar(double value, String satelliteNumber, Color color, double containerHeight) {
    double maxSignalToNoise = 60.0;
    double barHeight = (value / maxSignalToNoise) * containerHeight;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 20.0,
          height: barHeight,
          color: color,
          child: Center(
            child: Text(
              satelliteNumber,
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _read55Packet() async {
    try {
      List<String> lines = await _file3.readAsLines();

      // Создаем временную очередь для хранения данных
      Queue<Map<String, String>> newDataQueue = Queue<Map<String, String>>();

      // Переменная для хранения текущей самой поздней секунды
      String latestTick = '';

      for (String line in lines) {
        List<String> parts = line.split(RegExp(r'\s+'));
        if (parts.length >= 21) {
          String tickValue = parts[0];
          String systemNumber = _getNavSystem55Packet(parts[3].trim());
          String satelliteNumber = parts[4];
          String elevation = parts[19];
          String azimuth = parts[20];

          // Формируем новую строку данных
          Map<String, String> newDataItem = {
            'Система ГНСС': systemNumber,
            'Номер НКА': satelliteNumber,
            'Угол места': elevation,
            'Азимут': azimuth
          };

          // Если это новый тик, обновляем latestTick и очищаем временную очередь
          if (tickValue != latestTick) {
            latestTick = tickValue;
            newDataQueue.clear();
          }

          // Добавляем новые данные в очередь
          newDataQueue.addLast(newDataItem);
        }
      }

      // Обновляем основную очередь данными из временной очереди
      setState(() {
        _data55Queue.clear();
        _data55Queue.addAll(newDataQueue);
      });
    } catch (e) {
      // print('Ошибка при чтении файла: файл srns_0x0055.txt не найден');
    }
  }

  // Функция для получения буквенного обозначения нав. системы по числовому коду
  String _getNavSystem55Packet(String code) {
    switch (code) {
      case '0':
        return 'GPS';
      case '1':
        return 'GLN';
      case '2':
        return 'GAL';
      case '3':
        return 'BDS';
      default:
        return 'Unknown'; // Если код не соответствует ни одной нав. системе
    }
  }

  Future<void> _readVelocityFrom50Packet() async {
    try {
      List<String> lines = await _file.readAsLines();

      // Переменные для хранения текущих скоростей
      Map<String, double> systemSpeeds = {
        'GPS': 0.0,
        'GLN': 0.0,
        'GAL': 0.0,
        'BDS': 0.0,
      };

      for (String line in lines) {
        List<String> parts = line.split(',');
        if (parts.length >= 12) {
          String systemName = parts[2].trim();
          String velocityStr = parts[10].trim().replaceAll('|V|=', '').replaceAll('m/s', '').trim();

          double velocity = double.tryParse(velocityStr) ?? 0.0;

          // Обновляем скорость для соответствующей системы
          if (velocity > 0) {
            systemSpeeds[systemName] = velocity;
          }
        }
      }

      // Обновляем основную очередь и состояния
      setState(() {
        _velocityQueue.clear();

        systemSpeeds.forEach((systemName, velocity) {
          if (velocity > 0) {
            _velocityQueue.addLast({
              'Система ГНСС': systemName,
              'Скорость НАП': velocity.toStringAsFixed(9),
            });
          }
        });

        // Обновляем скорости для отображения
        _gpsSpeed = systemSpeeds['GPS']!;
        _glnSpeed = systemSpeeds['GLN']!;
        _galSpeed = systemSpeeds['GAL']!;
        _bdsSpeed = systemSpeeds['BDS']!;
      });
    } catch (e) {
      // print('Ошибка при чтении файла: файл srns_0x0050.txt не найден');
    }
  }

  double _calculateAverage(List<double> values) {
    double sum = 0.0;
    for (var value in values) {
      sum += value;
    }
    return sum / values.length;
  }

  LatLng _calculateAverageLatLng(List<LatLng> locations) {
    double sumLat = 0.0;
    double sumLng = 0.0;
    for (var location in locations) {
      sumLat += location.latitude;
      sumLng += location.longitude;
    }
    double avgLat = sumLat / locations.length;
    double avgLng = sumLng / locations.length;
    return LatLng(avgLat, avgLng);
  }

  Future<void> _startTimer() async {
    try {
      if (_isReading) return;
      _isReading = true;
      _timer?.cancel();

      _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) async {
        await _readAllPackets();
        setState(() {
          _currentTime = DateTime.now().toString();
        });
      });

      setState(() {
        _coordinates = [
          'Считывание началось'
        ];
      });
    }
    // catch (e, stackTrace) {
    //   // print('Ошибка в методе _startTimer(): $e\n$stackTrace');
    // }

    catch (e) {
      // print('Ошибка в методе _startTimer(): $e\n$stackTrace');
    }
  }

  Future<void> _readAllPackets() async {
    try {
      await Future.wait([
        _readLastCoordinates(),
        _readF5Packet(),
        _read55Packet(),
        _readVelocityFrom50Packet()
      ]);

      if (isRecording && recordingFile != null) {
        Map<String, dynamic> recordedData = {
          'Координаты НАП': _coordinates,
          'ОСШ сигналов ГНСС': _dataF5Queue.toList(),
          'Созвездие НКА': _data55Queue.toList(),
          'Скорость НАП': _velocityQueue.toList(),
          'Время': DateTime.now().toIso8601String(),
        };

        String formattedJson = const JsonEncoder.withIndent('  ').convert(recordedData);

        // Записываем данные в файл без скобок
        recordingFile!.writeAsStringSync(
          '$formattedJson\n',
          mode: FileMode.append,
          flush: true,
        );
      }
    } catch (e) {
      // print('Ошибка при чтении пакетов: $e');
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _isReading = false;
    setState(() {
      _coordinates = [
        'Считывание остановлено'
      ];
    });
  }

  void _moveToCurrentLocation() {
    if (_currentLocationGPS != null && _currentLocationGPS!.latitude != 0 && _currentLocationGPS!.longitude != 0 && _currentSKOGPS! <= 150.0) {
      _mapController.move(_currentLocationGPS!, _initialZoomSet ? _currentZoom : 16.0);
      _currentCenter = _currentLocationGPS!;
    } else if (_currentLocationGLN != null && _currentLocationGLN!.latitude != 0 && _currentLocationGLN!.longitude != 0 && _currentSKOGLN! <= 150.0) {
      _mapController.move(_currentLocationGLN!, _initialZoomSet ? _currentZoom : 16.0);
      _currentCenter = _currentLocationGLN!;
    } else if (_currentLocationGAL != null && _currentLocationGAL!.latitude != 0 && _currentLocationGAL!.longitude != 0 && _currentSKOGAL! <= 150.0) {
      _mapController.move(_currentLocationGAL!, _initialZoomSet ? _currentZoom : 16.0);
      _currentCenter = _currentLocationGAL!;
    } else if (_currentLocationBDS != null && _currentLocationBDS!.latitude != 0 && _currentLocationBDS!.longitude != 0 && _currentSKOBDS! <= 150.0) {
      _mapController.move(_currentLocationBDS!, _initialZoomSet ? _currentZoom : 16.0);
      _currentCenter = _currentLocationBDS!;
    }
    _initialZoomSet = true; // Устанавливаем флаг после первого вызова
  }

  void _zoomIn() {
    setState(() {
      _currentZoom += 1;
      _mapController.move(_currentCenter, _currentZoom);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentZoom -= 1;
      _mapController.move(_currentCenter, _currentZoom);
    });
  }

  void _toggleFollowMarker() {
    setState(() {
      _isFollowingMarker = !_isFollowingMarker;
      if (_isFollowingMarker) {
        _followMarkerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          _moveToCurrentLocation();
        });
      } else {
        _followMarkerTimer?.cancel();
      }
    });
  }

  void _toggleShowAllPoints() {
    setState(() {
      _showAllPoints = !_showAllPoints;
      if (!_showAllPoints) {
        // Очищаем массивы точек при отключении отображения траектории
        _allPointsGPS.clear();
        _allPointsGLN.clear();
        _allPointsGAL.clear();
        _allPointsBDS.clear();
      } else {
        // Наполняем массивы новыми точками при включении отображения траектории
        _allPointsGPS.clear();
        _allPointsGLN.clear();
        _allPointsGAL.clear();
        _allPointsBDS.clear();
        _readLastCoordinates();
      }
    });
  }

  void _copyLastCoordinatesToClipboard() {
    if (_lastTenCoordinates.isNotEmpty) {
      final String gpsCoordinates = _lastTenCoordinates.firstWhere((coord) => coord.contains('GPS'), orElse: () => '');
      final String glnCoordinates = _lastTenCoordinates.firstWhere((coord) => coord.contains('GLN'), orElse: () => '');
      final String galCoordinates = _lastTenCoordinates.firstWhere((coord) => coord.contains('GAL'), orElse: () => '');
      final String bdsCoordinates = _lastTenCoordinates.firstWhere((coord) => coord.contains('BDS'), orElse: () => '');

      String copyText = '';
      if (gpsCoordinates.isNotEmpty && _currentLocationGPS!.latitude != 0.0 && _currentLocationGPS!.longitude != 0.0) {
        copyText += '$gpsCoordinates\n';
      }
      if (glnCoordinates.isNotEmpty && _currentLocationGLN!.latitude != 0.0 && _currentLocationGLN!.longitude != 0.0) {
        copyText += '$glnCoordinates\n';
      }
      if (galCoordinates.isNotEmpty && _currentLocationGAL!.latitude != 0.0 && _currentLocationGAL!.longitude != 0.0) {
        copyText += '$galCoordinates\n';
      }
      if (bdsCoordinates.isNotEmpty && _currentLocationBDS!.latitude != 0.0 && _currentLocationBDS!.longitude != 0.0) {
        copyText += '$bdsCoordinates\n';
      }

      if (copyText.isNotEmpty) {
        Clipboard.setData(ClipboardData(text: copyText));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Координаты скопированы в буфер обмена'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Нет доступных координат для копирования'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет доступных координат для копирования'),
          duration: Duration(seconds: 2),
        ),
      );
    }
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

  void _updateDistancesToMarker() {
    if (_markerLocation != null) {
      if (_currentLocationGPS != null) {
        if (_markerHeight != null && _currentHeightGPS != null) {
          _distanceToMarkerGPS = _calculateDistance3D(_currentLocationGPS!, _markerLocation!, _currentHeightGPS!, _markerHeight!);
        } else {
          _distanceToMarkerGPS = _calculateDistance2D(_currentLocationGPS!, _markerLocation!);
        }
      }
      if (_currentLocationGLN != null) {
        if (_markerHeight != null && _currentHeightGLN != null) {
          _distanceToMarkerGLN = _calculateDistance3D(_currentLocationGLN!, _markerLocation!, _currentHeightGLN!, _markerHeight!);
        } else {
          _distanceToMarkerGLN = _calculateDistance2D(_currentLocationGLN!, _markerLocation!);
        }
      }
      if (_currentLocationGAL != null) {
        if (_markerHeight != null && _currentHeightGAL != null) {
          _distanceToMarkerGAL = _calculateDistance3D(_currentLocationGAL!, _markerLocation!, _currentHeightGAL!, _markerHeight!);
        } else {
          _distanceToMarkerGAL = _calculateDistance2D(_currentLocationGAL!, _markerLocation!);
        }
      }
      if (_currentLocationBDS != null) {
        if (_markerHeight != null && _currentHeightBDS != null) {
          _distanceToMarkerBDS = _calculateDistance3D(_currentLocationBDS!, _markerLocation!, _currentHeightBDS!, _markerHeight!);
        } else {
          _distanceToMarkerBDS = _calculateDistance2D(_currentLocationBDS!, _markerLocation!);
        }
      }
    }
  }

  void _copyDistancesToMarker() {
    if (_markerLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет доступного маркера')),
      );
      return;
    }

    String copyText = '';

    if (_distanceToMarkerGPS != null && _currentLocationGPS!.latitude != 0.0 && _currentLocationGPS!.longitude != 0.0) {
      copyText += 'Расстояние до маркера (GPS): ${_distanceToMarkerGPS!.toStringAsFixed(6)} м\n';
    }
    if (_distanceToMarkerGLN != null && _currentLocationGLN!.latitude != 0.0 && _currentLocationGLN!.longitude != 0.0) {
      copyText += 'Расстояние до маркера (GLN): ${_distanceToMarkerGLN!.toStringAsFixed(6)} м\n';
    }
    if (_distanceToMarkerGAL != null && _currentLocationGAL!.latitude != 0.0 && _currentLocationGAL!.longitude != 0.0) {
      copyText += 'Расстояние до маркера (GAL): ${_distanceToMarkerGAL!.toStringAsFixed(6)} м\n';
    }
    if (_distanceToMarkerBDS != null && _currentLocationBDS!.latitude != 0.0 && _currentLocationBDS!.longitude != 0.0) {
      copyText += 'Расстояние до маркера (BDS): ${_distanceToMarkerBDS!.toStringAsFixed(6)} м\n';
    }

    if (copyText.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: copyText));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Расстояния до маркера скопированы в буфер обмена'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет доступных расстояний для копирования'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _checkFilesAndStartTimer(BuildContext context) {
    // Отдельные переменные для каждого файла
    String file1 = '/tmp/srns_0x00F5.txt';
    String file2 = '/tmp/srns_0x0055.txt';
    String file3 = '/tmp/srns_0x0050.txt';

    // Переменная для отслеживания наличия всех файлов
    bool allFilesExist = true;

    // Проверка первого файла
    if (!File(file1).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при чтении файла: файл $file1 не найден'),
          duration: const Duration(seconds: 2),
        ),
      );
      allFilesExist = false;
    }

    // Проверка второго файла
    if (!File(file2).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при чтении файла: файл $file2 не найден'),
          duration: const Duration(seconds: 2),
        ),
      );
      allFilesExist = false;
    }

    // Проверка третьего файла
    if (!File(file3).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при чтении файла: файл $file3 не найден'),
          duration: const Duration(seconds: 2),
        ),
      );
      allFilesExist = false;
    }

    // Если все файлы на месте, запускаем таймер
    if (allFilesExist) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Работа успешно началась'),
          duration: Duration(seconds: 2),
        ),
      );

      // Запускаем таймер
      _startTimer();
    }
  }

  void startRecording() {
    const String path = '/tmp/srns_txtparser.json';
    recordingFile = File(path);
    final Directory dir = recordingFile!.parent;

    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    if (recordingFile!.existsSync()) {
      recordingFile!.writeAsStringSync('', mode: FileMode.write);
      // print('Файл очищен: $path');
    } else {
      recordingFile!.createSync();
      // print('Файл создан: $path');
    }

    isRecording = true;
    // print('Запись начата');
  }

  void stopRecording() {
    if (isRecording && recordingFile != null) {
      if (recordingFile!.lengthSync() > 2) {
        recordingFile!.writeAsStringSync('\n', mode: FileMode.append, flush: true);
      } else {
        recordingFile!.deleteSync();
        // print('Файл был пуст и удален.');
      }
      // print('Запись завершена и файл закрыт.');
    }
    isRecording = false;
    recordingFile = null;
  }

  Process? recordingProcess;
  bool isRecordingVideo = false;
  bool isCommandFieldVisible = false;

  void startRecordingVideo(BuildContext context) async {
    String command = commandController.text;

    recordingProcess = await Process.start(
      'bash',
      [
        '-c',
        command
      ],
    );

    // recordingProcess?.stderr.transform(utf8.decoder).listen((data) {
    //   if (data.contains("File '/tmp/output.mp4' already exists. Overwrite ? [y/N]")) {
    //     recordingProcess?.stdin.writeln('y'); // Отправляем 'y', чтобы подтвердить перезапись
    //   }
    //   // print('stderr: $data');
    // });

    // recordingProcess?.stdout.transform(utf8.decoder).listen((data) {
    //   // print('stdout: $data');
    // });

    isRecordingVideo = true;
    (context as Element).markNeedsBuild();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Запись видео успешно начата'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void stopRecordingVideo(BuildContext context) {
    if (recordingProcess != null) {
      recordingProcess?.kill(ProcessSignal.sigint);
      recordingProcess = null;

      isRecordingVideo = false;
      (context as Element).markNeedsBuild();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Запись видео остановлена'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String _currentTime = '';

  void _startClock() {
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      setState(() {
        _currentTime = DateTime.now().toString();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
    _followMarkerTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    // Получаем количество спутников
    Map<String, int> satelliteCounts = _countSatellitesFromQueue(_dataF5Queue);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clonicus GNSS software'),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 211, 186, 253),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  FlutterMap(
                                    mapController: _mapController,
                                    options: MapOptions(
                                      initialCenter: _currentLocationGPS ?? _currentLocationGLN ?? _currentLocationGAL ?? _currentLocationBDS ?? const LatLng(55.751244, 37.618423),
                                      initialZoom: 10.0,
                                      onTap: (tapPosition, point) {
                                        setState(() {
                                          _markerLocation = point;
                                          _markerHeight = null; // Сбрасываем высоту маркера
                                          _updateDistancesToMarker(); // Обновляем расчеты расстояний
                                          if (_isInputFieldVisible) {
                                            _coordsController.text = '${point.latitude.toStringAsFixed(7)}, ${point.longitude.toStringAsFixed(7)}';
                                          }
                                        });
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
                                      if (_currentLocationGPS != null)
                                        CircleLayer(
                                          circles: [
                                            CircleMarker(
                                              point: _currentLocationGPS!,
                                              color: Colors.red.withOpacity(0.3),
                                              borderStrokeWidth: 1,
                                              useRadiusInMeter: true,
                                              radius: _currentSKOGPS ?? 0,
                                            ),
                                          ],
                                        ),
                                      if (_currentLocationGLN != null)
                                        CircleLayer(
                                          circles: [
                                            CircleMarker(
                                              point: _currentLocationGLN!,
                                              color: Colors.blue.withOpacity(0.3),
                                              borderStrokeWidth: 1,
                                              useRadiusInMeter: true,
                                              radius: _currentSKOGLN ?? 0,
                                            ),
                                          ],
                                        ),
                                      if (_currentLocationGAL != null)
                                        CircleLayer(
                                          circles: [
                                            CircleMarker(
                                              point: _currentLocationGAL!,
                                              color: Colors.orange.withOpacity(0.3),
                                              borderStrokeWidth: 1,
                                              useRadiusInMeter: true,
                                              radius: _currentSKOGAL ?? 0,
                                            ),
                                          ],
                                        ),
                                      if (_currentLocationBDS != null)
                                        CircleLayer(
                                          circles: [
                                            CircleMarker(
                                              point: _currentLocationBDS!,
                                              color: const Color.fromARGB(255, 5, 131, 9).withOpacity(0.3),
                                              borderStrokeWidth: 1,
                                              useRadiusInMeter: true,
                                              radius: _currentSKOBDS ?? 0,
                                            ),
                                          ],
                                        ),
                                      MarkerLayer(
                                        markers: [
                                          if (_currentLocationGPS != null)
                                            Marker(
                                              point: _currentLocationGPS!,
                                              width: 80.0,
                                              height: 80.0,
                                              child: const Icon(Icons.location_on, color: Colors.red, size: 40.0),
                                            ),
                                          if (_currentLocationGLN != null)
                                            Marker(
                                              point: _currentLocationGLN!,
                                              width: 80.0,
                                              height: 80.0,
                                              child: const Icon(Icons.location_on, color: Colors.blue, size: 40.0),
                                            ),
                                          if (_currentLocationGAL != null)
                                            Marker(
                                              point: _currentLocationGAL!,
                                              width: 80.0,
                                              height: 80.0,
                                              child: const Icon(Icons.location_on, color: Colors.orange, size: 40.0),
                                            ),
                                          if (_currentLocationBDS != null)
                                            Marker(
                                              point: _currentLocationBDS!,
                                              width: 80.0,
                                              height: 80.0,
                                              child: const Icon(Icons.location_on, color: Color.fromARGB(255, 5, 131, 9), size: 40.0),
                                            ),
                                          if (_markerLocation != null)
                                            Marker(
                                              point: _markerLocation!,
                                              width: 80.0,
                                              height: 80.0,
                                              child: const Icon(Icons.location_on, color: Colors.black, size: 40.0),
                                            ),
                                          if (_showAllPoints)
                                            ..._allPointsGPS.map((point) => Marker(
                                                  point: point,
                                                  width: 10.0,
                                                  height: 10.0,
                                                  child: const Icon(Icons.circle, color: Colors.red, size: 5.0),
                                                )),
                                          if (_showAllPoints)
                                            ..._allPointsGLN.map((point) => Marker(
                                                  point: point,
                                                  width: 10.0,
                                                  height: 10.0,
                                                  child: const Icon(Icons.circle, color: Colors.blue, size: 5.0),
                                                )),
                                          if (_showAllPoints)
                                            ..._allPointsGAL.map((point) => Marker(
                                                  point: point,
                                                  width: 10.0,
                                                  height: 10.0,
                                                  child: const Icon(Icons.circle, color: Colors.orange, size: 5.0),
                                                )),
                                          if (_showAllPoints)
                                            ..._allPointsBDS.map((point) => Marker(
                                                  point: point,
                                                  width: 10.0,
                                                  height: 10.0,
                                                  child: const Icon(Icons.circle, color: Color.fromARGB(255, 5, 131, 9), size: 5.0),
                                                )),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Positioned(
                                    bottom: 16.0,
                                    right: 16.0,
                                    child: Column(
                                      children: [
                                        FloatingActionButton(
                                          onPressed: _zoomIn,
                                          backgroundColor: const Color.fromARGB(255, 211, 186, 253),
                                          elevation: 10,
                                          mini: true,
                                          child: const Icon(Icons.add),
                                        ),
                                        const SizedBox(
                                          height: 2,
                                        ),
                                        FloatingActionButton(
                                          onPressed: _zoomOut,
                                          backgroundColor: const Color.fromARGB(255, 211, 186, 253),
                                          elevation: 10,
                                          mini: true,
                                          child: const Icon(Icons.remove),
                                        ),
                                        const SizedBox(height: 16.0), // Промежуток между кнопками
                                        FloatingActionButton(
                                          onPressed: _moveToCurrentLocation,
                                          backgroundColor: const Color.fromARGB(255, 211, 186, 253),
                                          elevation: 10,
                                          mini: true,
                                          child: const Icon(Icons.my_location),
                                        ),
                                        const SizedBox(height: 16.0), // Промежуток между кнопками
                                        FloatingActionButton(
                                          onPressed: _toggleFollowMarker,
                                          backgroundColor: _isFollowingMarker ? const Color.fromARGB(255, 252, 149, 142) : const Color.fromARGB(255, 211, 186, 253),
                                          elevation: 10,
                                          mini: true,
                                          child: const Icon(Icons.navigation),
                                        ),
                                        const SizedBox(height: 16.0), // Промежуток между кнопками
                                        FloatingActionButton(
                                          onPressed: _toggleShowAllPoints,
                                          backgroundColor: _showAllPoints ? const Color.fromARGB(255, 252, 149, 142) : const Color.fromARGB(255, 211, 186, 253),
                                          elevation: 10,
                                          mini: true,
                                          child: Icon(_showAllPoints ? Icons.visibility : Icons.visibility_off),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(),
                            const SizedBox(height: 2),
                            if (_markerLocation != null)
                              SelectableText(
                                'Координаты маркера: ${_markerLocation!.latitude.toStringAsFixed(7)}, ${_markerLocation!.longitude.toStringAsFixed(7)}${_markerHeight != null ? ', ${_markerHeight!.toStringAsFixed(2)} м' : ''}',
                                style: const TextStyle(fontSize: 12, color: Colors.black),
                              ),
                            if (_distanceToMarkerGPS != null && _currentLocationGPS!.latitude != 0.0 && _currentLocationGPS!.longitude != 0.0)
                              SelectableText(
                                'Расстояние до маркера (GPS): ${_distanceToMarkerGPS!.toStringAsFixed(4)} м',
                                style: const TextStyle(fontSize: 12, color: Colors.red),
                              ),
                            if (_distanceToMarkerGLN != null && _currentLocationGLN!.latitude != 0.0 && _currentLocationGLN!.longitude != 0.0)
                              SelectableText(
                                'Расстояние до маркера (GLN): ${_distanceToMarkerGLN!.toStringAsFixed(4)} м',
                                style: const TextStyle(fontSize: 12, color: Colors.blue),
                              ),
                            if (_distanceToMarkerGAL != null && _currentLocationGAL!.latitude != 0.0 && _currentLocationGAL!.longitude != 0.0)
                              SelectableText(
                                'Расстояние до маркера (GAL): ${_distanceToMarkerGAL!.toStringAsFixed(4)} м',
                                style: const TextStyle(fontSize: 12, color: Colors.orange),
                              ),
                            if (_distanceToMarkerBDS != null && _currentLocationBDS!.latitude != 0.0 && _currentLocationBDS!.longitude != 0.0)
                              SelectableText(
                                'Расстояние до маркера (BDS): ${_distanceToMarkerBDS!.toStringAsFixed(4)} м',
                                style: const TextStyle(fontSize: 12, color: Color.fromARGB(255, 5, 131, 9)),
                              ),
                            const Divider(),
                            const SizedBox(height: 1),
                            Column(
                              children: _coordinates
                                  .map((coord) {
                                    // Разбиваем координаты на части и фильтруем их с помощью метода _buildTextSpans
                                    List<TextSpan> spans = _buildTextSpans(coord);

                                    // Если spans содержит хотя бы один элемент, отображаем строку
                                    if (spans.isNotEmpty) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: RichText(
                                          text: TextSpan(
                                            style: const TextStyle(fontSize: 12, color: Colors.black),
                                            children: spans,
                                          ),
                                        ),
                                      );
                                    }
                                    // Если spans пуст, не добавляем ничего в Column
                                    return const SizedBox.shrink(); // Пустой виджет, занимающий 0 места
                                  })
                                  .where((widget) => widget is! SizedBox) // Фильтруем пустые виджеты
                                  .toList(),
                            ),
                            const SizedBox(height: 1),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(
                    thickness: 1.5,
                    indent: 0,
                    endIndent: 0,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        // Вставляем гистограмму с ограничением высоты
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onHorizontalDragUpdate: (details) {
                              const double scrollSpeedFactor = 90.0;
                              _scrollController.animateTo(
                                _scrollController.offset - details.delta.dx * scrollSpeedFactor,
                                duration: const Duration(milliseconds: 100),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                // Определяем наличие спутников
                                bool hasSatellites = _hasSatellites();
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  controller: _scrollController,
                                  child: Stack(
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          YAxisLabels(hasSatellites: hasSatellites),
                                          const SizedBox(width: 1), // Пространство между метками и гистограммой
                                          Container(
                                            constraints: BoxConstraints(maxHeight: constraints.maxHeight),
                                            child: buildHistogram(constraints.maxHeight),
                                          ),
                                        ],
                                      ),
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: GridPainter(hasSatellites: hasSatellites),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7.0, horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (satelliteCounts['GPS']! > 0)
                                SelectableText(
                                  'Количество спутников системы Global Positioning System (GPS) (L1-диапазон): ${satelliteCounts['GPS']}',
                                  style: const TextStyle(fontSize: 12, color: Colors.red),
                                ),
                              if (satelliteCounts['GPSL2']! > 0)
                                SelectableText(
                                  'Количество спутников системы Global Positioning System (GPS) (L2-диапазон): ${satelliteCounts['GPSL2']}',
                                  style: const TextStyle(fontSize: 12, color: Color.fromARGB(255, 122, 18, 10)),
                                ),
                              if (satelliteCounts['GPSL5']! > 0)
                                SelectableText(
                                  'Количество спутников системы Global Positioning System (GPS) (L5-диапазон): ${satelliteCounts['GPSL5']}',
                                  style: const TextStyle(fontSize: 12, color: Color.fromARGB(255, 53, 4, 1)),
                                ),
                              if (satelliteCounts['GLN']! > 0)
                                SelectableText(
                                  'Количество спутников системы ГЛОНАСС (GLN) (L1-диапазон): ${satelliteCounts['GLN']}',
                                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                                ),
                              if (satelliteCounts['GLNL2']! > 0)
                                SelectableText(
                                  'Количество спутников системы ГЛОНАСС (GLN) (L2-диапазон): ${satelliteCounts['GLNL2']}',
                                  style: const TextStyle(fontSize: 12, color: Color.fromARGB(255, 14, 80, 134)),
                                ),
                              if (satelliteCounts['GAL']! > 0)
                                SelectableText(
                                  'Количество спутников системы Galileo (GAL) (L1-диапазон): ${satelliteCounts['GAL']}',
                                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                                ),
                              if (satelliteCounts['GALL5a']! > 0)
                                SelectableText(
                                  'Количество спутников системы Galileo (GAL) (L5a-диапазон): ${satelliteCounts['GALL5a']}',
                                  style: const TextStyle(fontSize: 12, color: Color.fromARGB(255, 156, 97, 8)),
                                ),
                              if (satelliteCounts['GALL5b']! > 0)
                                SelectableText(
                                  'Количество спутников системы Galileo (GAL) (L5b-диапазон): ${satelliteCounts['GALL5b']}',
                                  style: const TextStyle(fontSize: 12, color: Color.fromARGB(255, 95, 59, 6)),
                                ),
                              if (satelliteCounts['BDS']! > 0)
                                SelectableText(
                                  'Количество спутников системы BeiDou (BDS) (L1-диапазон): ${satelliteCounts['BDS']}',
                                  style: const TextStyle(fontSize: 12, color: Color.fromARGB(255, 5, 131, 9)),
                                ),
                              if (satelliteCounts['BDSL2']! > 0)
                                SelectableText(
                                  'Количество спутников системы BeiDou (BDS) (L2-диапазон): ${satelliteCounts['BDSL2']}',
                                  style: const TextStyle(fontSize: 12, color: Color.fromARGB(255, 2, 77, 5)),
                                ),
                              if (satelliteCounts['TOTAL']! > 0)
                                SelectableText(
                                  'Суммарное количество спутников ГНСС: ${satelliteCounts['TOTAL']}',
                                  style: const TextStyle(fontSize: 12, color: Colors.black),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(
                    thickness: 1.5,
                    indent: 0,
                    endIndent: 0,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: SkyPlotWidget(
                            data: _data55Queue.toList(),
                            hasSolutionGPS: _currentLocationGPS != null && _currentLocationGPS!.latitude != 0.0 && _currentLocationGPS!.longitude != 0.0,
                            hasSolutionGLN: _currentLocationGLN != null && _currentLocationGLN!.latitude != 0.0 && _currentLocationGLN!.longitude != 0.0,
                            hasSolutionGAL: _currentLocationGAL != null && _currentLocationGAL!.latitude != 0.0 && _currentLocationGAL!.longitude != 0.0,
                            hasSolutionBDS: _currentLocationBDS != null && _currentLocationBDS!.latitude != 0.0 && _currentLocationBDS!.longitude != 0.0,
                          ),
                        ),
                        const Divider(),
                        Column(
                          children: [
                            // Спидометр
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 8.0),
                              child: AspectRatio(
                                aspectRatio: 4,
                                child: DynamicSpeedometer(
                                  gpsSpeed: _gpsSpeed,
                                  glnSpeed: _glnSpeed,
                                  galSpeed: _galSpeed,
                                  bdsSpeed: _bdsSpeed,
                                  hasSolutionGPS: _currentLocationGPS != null && _currentLocationGPS!.latitude != 0.0 && _currentLocationGPS!.longitude != 0.0,
                                  hasSolutionGLN: _currentLocationGLN != null && _currentLocationGLN!.latitude != 0.0 && _currentLocationGLN!.longitude != 0.0,
                                  hasSolutionGAL: _currentLocationGAL != null && _currentLocationGAL!.latitude != 0.0 && _currentLocationGAL!.longitude != 0.0,
                                  hasSolutionBDS: _currentLocationBDS != null && _currentLocationBDS!.latitude != 0.0 && _currentLocationBDS!.longitude != 0.0,
                                ),
                              ),
                            ),
                            const Divider(),
                            // Минимальный отступ
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ...[
                                    {
                                      'Система ГНСС': 'GPS',
                                      'color': Colors.red,
                                      'hasSolution': _currentLocationGPS != null && _currentLocationGPS!.latitude != 0.0 && _currentLocationGPS!.longitude != 0.0,
                                    },
                                    {
                                      'Система ГНСС': 'GLN',
                                      'color': Colors.blue,
                                      'hasSolution': _currentLocationGLN != null && _currentLocationGLN!.latitude != 0.0 && _currentLocationGLN!.longitude != 0.0,
                                    },
                                    {
                                      'Система ГНСС': 'GAL',
                                      'color': Colors.orange,
                                      'hasSolution': _currentLocationGAL != null && _currentLocationGAL!.latitude != 0.0 && _currentLocationGAL!.longitude != 0.0,
                                    },
                                    {
                                      'Система ГНСС': 'BDS',
                                      'color': const Color.fromARGB(255, 5, 131, 9),
                                      'hasSolution': _currentLocationBDS != null && _currentLocationBDS!.latitude != 0.0 && _currentLocationBDS!.longitude != 0.0,
                                    },
                                  ].map((system) {
                                    final systemName = system['Система ГНСС'] as String;
                                    final color = system['color'] as Color;
                                    final hasSolution = system['hasSolution'] as bool;

                                    // Фильтруем данные по текущей системе
                                    final dataList = _velocityQueue
                                        .where(
                                          (item) => item['Система ГНСС'] == systemName && item['Скорость НАП'] != '0.0 m/s',
                                        )
                                        .toList();

                                    // Если есть решение и данные для текущей системы есть, выводим их
                                    if (hasSolution && dataList.isNotEmpty) {
                                      final velocity = dataList.first['Скорость НАП'];
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 0.0),
                                        child: SelectableText(
                                          'Скорость ($systemName): $velocity м/с',
                                          style: TextStyle(fontSize: 12, color: color),
                                        ),
                                      );
                                    }

                                    return const SizedBox.shrink(); // Не отображаем ничего, если решения нет или скорость равна нулю
                                  }),
                                ],
                              ),
                            ),
                            const Divider(),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Дата и время: $_currentTime'),
                                // Остальные виджеты
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const Divider(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: _isReading ? null : () => _checkFilesAndStartTimer(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isReading ? Colors.grey : const Color.fromARGB(255, 211, 186, 253),
                      ),
                      child: Text(_isReading ? 'В процессе...' : 'Начать работу'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _stopTimer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 252, 149, 142),
                      ),
                      child: const Text('Остановить работу'),
                    ),
                  ],
                ),
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: _copyLastCoordinatesToClipboard,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 211, 186, 253),
                      ),
                      child: const Text('Скопировать последние координаты'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _copyDistancesToMarker,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 211, 186, 253),
                      ),
                      child: const Text('Скопировать расстояния до маркера'),
                    ),
                  ],
                ),
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          // Сбрасываем все переменные к их начальным значениям
                          _isInputFieldVisible = false;
                          _markerLocation = null;
                          _markerHeight = null;
                          _distanceToMarkerBDS = null;
                          _distanceToMarkerGAL = null;
                          _distanceToMarkerGLN = null;
                          _distanceToMarkerGPS = null;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 252, 149, 142),
                      ),
                      child: const Text('Убрать маркер'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          // Сбрасываем все переменные к их начальным значениям
                          _isInputFieldVisible = false;
                          _markerLocation = null;
                          _markerHeight = null;
                          _dataF5Queue.clear();
                          _currentLocationGPS = null;
                          _currentLocationGLN = null;
                          _currentLocationGAL = null;
                          _currentLocationBDS = null;
                          _distanceToMarkerBDS = null;
                          _distanceToMarkerGAL = null;
                          _distanceToMarkerGLN = null;
                          _distanceToMarkerGPS = null;
                          _coordsController.clear();
                          _data55Queue.clear();
                          _allPointsGPS.clear();
                          _allPointsGLN.clear();
                          _allPointsGAL.clear();
                          _allPointsBDS.clear();
                          _velocityQueue.clear();

                          // Сброс значений скоростей
                          _gpsSpeed = 0.0;
                          _glnSpeed = 0.0;
                          _galSpeed = 0.0;
                          _bdsSpeed = 0.0;
                          // Добавьте здесь сброс других переменных, если необходимо
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 252, 149, 142),
                      ),
                      child: const Text('Сбросить собранные данные'),
                    ),
                  ],
                ),
                Column(
                  children: [
                    // Добавление кнопок в нужное место интерфейса
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            if (!isRecording) {
                              startRecording();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Запись данных в текстовый файл начата'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            } else {
                              stopRecording();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Запись данных в текстовый файл завершена'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              // Удаляем переформатирование данных из этой части
                              // _reformatRecordingFile();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isRecording ? const Color.fromARGB(255, 252, 149, 142) : const Color.fromARGB(255, 211, 186, 253),
                          ),
                          child: Text(isRecording ? 'Остановить запись текстового файла' : 'Начать запись текстового файла'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            stopRecordingVideo(context);
                          },
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(
                              isRecordingVideo ? const Color.fromARGB(255, 252, 149, 142) : const Color.fromARGB(255, 211, 186, 253), // Цвет меняется в зависимости от состояния записи
                            ),
                          ),
                          child: const Text('Остановить запись видео'),
                        ),
                      ],
                    )
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isInputFieldVisible = !_isInputFieldVisible;
                    if (_isInputFieldVisible && _markerLocation != null) {
                      // Заполнение текстового поля текущими координатами и высотой, если она есть
                      _coordsController.text = '${_markerLocation!.latitude.toStringAsFixed(7)}, ${_markerLocation!.longitude.toStringAsFixed(7)}${_markerHeight != null ? ', ${_markerHeight!.toString()}' : ''}';
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isInputFieldVisible ? const Color.fromARGB(255, 252, 149, 142) : const Color.fromARGB(255, 211, 186, 253),
                ),
                child: Text(_isInputFieldVisible ? 'Закрыть окно' : 'Ввести координаты маркера'),
              ),
            ),
            if (_isInputFieldVisible) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _coordsController,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: 'Введите координаты маркера (latitude, longitude, height(опционально))',
                  helperText: 'Например: 55.149391, 37.942134, 212.22',
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color.fromARGB(255, 252, 149, 142),
                    ),
                    onPressed: () {
                      setState(() {
                        _coordsController.clear();
                      });
                    },
                  ),
                ),
                onSubmitted: (value) {
                  List<String> coords = value.split(',');
                  if (coords.length == 2 || coords.length == 3) {
                    double? lat = double.tryParse(coords[0]);
                    double? lon = double.tryParse(coords[1]);
                    double? height = coords.length == 3 ? double.tryParse(coords[2]) : null;
                    if (lat != null && lon != null) {
                      setState(() {
                        _markerLocation = LatLng(lat, lon);
                        _markerHeight = height;
                        _updateDistancesToMarker();
                      });
                    }
                  }
                },
              ),
            ],
            const SizedBox(height: 20),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        isCommandFieldVisible = !isCommandFieldVisible;
                        if (isCommandFieldVisible) {
                          // При открытии поля устанавливаем текст по умолчанию
                          commandController.text = 'ffmpeg -video_size 1920x1080 -framerate 30 -f x11grab -i :0.0 /tmp/output.mp4';
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCommandFieldVisible ? const Color.fromARGB(255, 252, 149, 142) : const Color.fromARGB(255, 211, 186, 253),
                    ),
                    child: Text(isCommandFieldVisible ? 'Закрыть окно' : 'Открыть окно для записи видео'),
                  ),
                  const SizedBox(height: 10),
                  if (isCommandFieldVisible)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: TextField(
                        controller: commandController,
                        onSubmitted: (value) {
                          startRecordingVideo(context);
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          helperText: 'Например, ffmpeg -video_size 1920x1080 -framerate 30 -f x11grab -i :0.0 /tmp/output.mp4 [-y (опционально для перезаписи файла)]',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TextSpan> _buildTextSpans(String coord) {
    List<TextSpan> spans = [];
    List<String> parts = coord.split(' ');

    bool hasValidData = false; // Флаг для проверки наличия действительных данных

    for (String part in parts) {
      if (part.startsWith('Широта(GPS):') || part.startsWith('Долгота(GPS):') || part.startsWith('Высота(GPS):') || part.startsWith('СКО(GPS):') || part.startsWith('PDOP(GPS):')) {
        if (_currentLocationGPS != null && _currentLocationGPS!.latitude != 0.0 && _currentLocationGPS!.longitude != 0.0) {
          spans.add(TextSpan(text: part, style: const TextStyle(color: Colors.red)));
          hasValidData = true;
        }
      } else if (part.startsWith('Широта(GLN):') || part.startsWith('Долгота(GLN):') || part.startsWith('Высота(GLN):') || part.startsWith('СКО(GLN):') || part.startsWith('PDOP(GLN):')) {
        if (_currentLocationGLN != null && _currentLocationGLN!.latitude != 0.0 && _currentLocationGLN!.longitude != 0.0) {
          spans.add(TextSpan(text: part, style: const TextStyle(color: Colors.blue)));
          hasValidData = true;
        }
      } else if (part.startsWith('Широта(GAL):') || part.startsWith('Долгота(GAL):') || part.startsWith('Высота(GAL):') || part.startsWith('СКО(GAL):') || part.startsWith('PDOP(GAL):')) {
        if (_currentLocationGAL != null && _currentLocationGAL!.latitude != 0.0 && _currentLocationGAL!.longitude != 0.0) {
          spans.add(TextSpan(text: part, style: const TextStyle(color: Colors.orange)));
          hasValidData = true;
        }
      } else if (part.startsWith('Широта(BDS):') || part.startsWith('Долгота(BDS):') || part.startsWith('Высота(BDS):') || part.startsWith('СКО(BDS):') || part.startsWith('PDOP(BDS):')) {
        if (_currentLocationBDS != null && _currentLocationBDS!.latitude != 0.0 && _currentLocationBDS!.longitude != 0.0) {
          spans.add(TextSpan(text: part, style: const TextStyle(color: Color.fromARGB(255, 5, 131, 9))));
          hasValidData = true;
        }
      } else if (part.startsWith('Широта\'(GPS):') || part.startsWith('Долгота\'(GPS):') || part.startsWith('Высота\'(GPS):') || part.startsWith('СКО\'(GPS):') || part.startsWith('PDOP\'(GPS):')) {
        if (_currentLocationGPS != null && _currentLocationGPS!.latitude != 0.0 && _currentLocationGPS!.longitude != 0.0) {
          spans.add(TextSpan(text: part, style: const TextStyle(color: Colors.red)));
          hasValidData = true;
        }
      } else if (part.startsWith('Широта\'(GLN):') || part.startsWith('Долгота\'(GLN):') || part.startsWith('Высота\'(GLN):') || part.startsWith('СКО\'(GLN):') || part.startsWith('PDOP\'(GLN):')) {
        if (_currentLocationGLN != null && _currentLocationGLN!.latitude != 0.0 && _currentLocationGLN!.longitude != 0.0) {
          spans.add(TextSpan(text: part, style: const TextStyle(color: Colors.blue)));
          hasValidData = true;
        }
      } else if (part.startsWith('Широта\'(GAL):') || part.startsWith('Долгота\'(GAL):') || part.startsWith('Высота\'(GAL):') || part.startsWith('СКО\'(GAL):') || part.startsWith('PDOP\'(GAL):')) {
        if (_currentLocationGAL != null && _currentLocationGAL!.latitude != 0.0 && _currentLocationGAL!.longitude != 0.0) {
          spans.add(TextSpan(text: part, style: const TextStyle(color: Colors.orange)));
          hasValidData = true;
        }
      } else if (part.startsWith('Широта\'(BDS):') || part.startsWith('Долгота\'(BDS):') || part.startsWith('Высота\'(BDS):') || part.startsWith('СКО\'(BDS):') || part.startsWith('PDOP\'(BDS):')) {
        if (_currentLocationBDS != null && _currentLocationBDS!.latitude != 0.0 && _currentLocationBDS!.longitude != 0.0) {
          spans.add(TextSpan(text: part, style: const TextStyle(color: Color.fromARGB(255, 5, 131, 9))));
          hasValidData = true;
        }
      } else {
        spans.add(TextSpan(text: part));
      }
      spans.add(const TextSpan(text: ' '));
    }

    return hasValidData ? spans : [];
  }
}
