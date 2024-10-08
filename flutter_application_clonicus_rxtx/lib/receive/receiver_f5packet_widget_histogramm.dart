import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'receiver_50packet.dart';
import 'receiver_f5packet.dart';
import 'receiver_notifier.dart';

class ReceiverF5PacketData extends StatelessWidget {
  ReceiverF5PacketData({super.key});

  final ScrollController _scrollController = ScrollController();

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
              final Map<String, String> coordinates = snapshot.data!;

              final hasSolutionGPS = coordinates['GPS'] != null && coordinates['GPS']!.isNotEmpty && isNonZeroLatitude(coordinates['GPS'], 'GPS');
              final hasSolutionGLN = coordinates['GLN'] != null && coordinates['GLN']!.isNotEmpty && isNonZeroLatitude(coordinates['GLN'], 'GLN');
              final hasSolutionGAL = coordinates['GAL'] != null && coordinates['GAL']!.isNotEmpty && isNonZeroLatitude(coordinates['GAL'], 'GAL');
              final hasSolutionBDS = coordinates['BDS'] != null && coordinates['BDS']!.isNotEmpty && isNonZeroLatitude(coordinates['BDS'], 'BDS');

              return FutureBuilder<List<Map<String, String>>>(
                future: processF5PacketData(rawData),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Ошибка: ${snapshot.error}');
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('Нет данных');
                  } else {
                    // Оставляем одну гистограмму, которая обновляется при изменении данных
                    return Flexible(
                      flex: 2,
                      fit: FlexFit.loose,
                      child: GestureDetector(
                        onHorizontalDragUpdate: (details) {
                          const double scrollSpeedFactor = 120.0;
                          _scrollController.animateTo(
                            _scrollController.offset - details.delta.dx * scrollSpeedFactor,
                            duration: const Duration(milliseconds: 100),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            bool hasSatellites = _hasSatellites(snapshot.data!);
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              controller: _scrollController,
                              child: Stack(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      YAxisLabels(hasSatellites: hasSatellites),
                                      const SizedBox(width: 1),
                                      Container(
                                        constraints: BoxConstraints(
                                          maxHeight: constraints.maxHeight.isFinite ? constraints.maxHeight : 200.0,
                                        ),
                                        // Построение одной гистограммы
                                        child: buildHistogram(
                                          constraints.maxHeight.isFinite ? constraints.maxHeight : 200.0,
                                          hasSolutionGPS,
                                          hasSolutionGLN,
                                          hasSolutionGAL,
                                          hasSolutionBDS,
                                          snapshot.data!,
                                        ),
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
                    );
                  }
                },
              );
            }
          },
        );
      },
    );
  }

// Метод для построения гистограммы с передачей данных
  Widget buildHistogram(double containerHeight, bool hasSolutionGPS, bool hasSolutionGLN, bool hasSolutionGAL, bool hasSolutionBDS, List<Map<String, String>> data // Добавляем data как аргумент
      ) {
    // Передаем data в _computeHistogramData
    Map<int, Map<String, List<int>>> histogramData = _computeHistogramData(data);

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
          hasSolution = hasSolutionGPS;
          break;
        case 'GlnL1OF':
        case 'GlnL2OF':
          hasSolution = hasSolutionGLN;
          break;
        case 'GalE1B':
        case 'GalE5aI':
        case 'GalE5bI':
          hasSolution = hasSolutionGAL;
          break;
        case 'BdsB1I':
        case 'BdsB2I':
          hasSolution = hasSolutionBDS;
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

  bool _hasSatellites(List<Map<String, String>> data) {
    Map<int, Map<String, List<int>>> histogramData = _computeHistogramData(data);

    // Проверяем, есть ли данные по хотя бы одному спутнику
    for (var satelliteData in histogramData.values) {
      if (satelliteData.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Map<int, Map<String, List<int>>> _computeHistogramData(List<Map<String, String>> data) {
    Map<int, Map<String, List<int>>> satelliteSignalNoise = {};

    for (var map in data) {
      // Получаем тип сигнала, номер НКА и ОСШ напрямую из Map
      String signalType = map['Навигационный сигнал']!;
      int satelliteNumber = int.parse(map['Номер НКА']!);
      int signalToNoise = int.parse(map['ОСШ']!);

      // Добавляем данные в структуру satelliteSignalNoise
      if (!satelliteSignalNoise.containsKey(satelliteNumber)) {
        satelliteSignalNoise[satelliteNumber] = {};
      }
      if (!satelliteSignalNoise[satelliteNumber]!.containsKey(signalType)) {
        satelliteSignalNoise[satelliteNumber]![signalType] = [];
      }
      satelliteSignalNoise[satelliteNumber]![signalType]!.add(signalToNoise);
    }

    // print('Данные гистограммы: $satelliteSignalNoise');
    return satelliteSignalNoise;
  }
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

// Функция для извлечения и проверки широты
bool isNonZeroLatitude(String? data, String systemName) {
  if (data == null || data.isEmpty) return false;

  // Ищем строку с широтой с апострофом или без
  final latitudePrefixWithApostrophe = "Широта'($systemName): ";
  final latitudePrefixWithoutApostrophe = "Широта($systemName): ";

  // Определяем, какой вариант строки широты используется
  final startIndexWithApostrophe = data.indexOf(latitudePrefixWithApostrophe);
  final startIndexWithoutApostrophe = data.indexOf(latitudePrefixWithoutApostrophe);

  // Используем найденный индекс для извлечения широты
  int startIndex = startIndexWithApostrophe != -1 ? startIndexWithApostrophe : startIndexWithoutApostrophe;

  // Если широта не найдена, возвращаем false
  if (startIndex == -1) return false;

  // Извлекаем строку с числом широты
  final latitudeString = data.substring(startIndex + (startIndexWithApostrophe != -1 ? latitudePrefixWithApostrophe.length : latitudePrefixWithoutApostrophe.length)).split(' ')[0];

  final latitude = double.tryParse(latitudeString);

  // Проверяем, что широта корректная и не равна 0.0
  return latitude != null && latitude != 0.0;
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
