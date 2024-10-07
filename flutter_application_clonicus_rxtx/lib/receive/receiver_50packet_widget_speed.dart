import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'receiver_50packet.dart';
import 'receiver_notifier.dart';

class Receiver50PacketAbsV extends StatelessWidget {
  const Receiver50PacketAbsV({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReceiverNotifier>(
      builder: (context, notifier, _) {
        final receiverNotifier = Provider.of<ReceiverNotifier>(context);
        final List<String> rawData = receiverNotifier.parsedDataList;

        // Первый FutureBuilder для загрузки данных скоростей
        return FutureBuilder<void>(
          future: velocityFiftyPacketData(rawData),
          builder: (context, velocitySnapshot) {
            if (velocitySnapshot.hasError) {
              return Text('Ошибка загрузки скоростей: ${velocitySnapshot.error}');
            } else {
              // Когда данные скоростей загружены, продолжаем с координатами
              return FutureBuilder<Map<String, String>>(
                future: readLastCoordinates(rawData),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Ошибка: ${snapshot.error}');
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('Нет данных');
                  } else {
                    final Map<String, String> coordinates = snapshot.data!;

                    // Проверяем наличие данных для каждой системы
                    final hasSolutionGPS = coordinates['GPS'] != null && coordinates['GPS']!.isNotEmpty && _isNonZeroLatitude(coordinates['GPS'], 'GPS');
                    final hasSolutionGLN = coordinates['GLN'] != null && coordinates['GLN']!.isNotEmpty && _isNonZeroLatitude(coordinates['GLN'], 'GLN');
                    final hasSolutionGAL = coordinates['GAL'] != null && coordinates['GAL']!.isNotEmpty && _isNonZeroLatitude(coordinates['GAL'], 'GAL');
                    final hasSolutionBDS = coordinates['BDS'] != null && coordinates['BDS']!.isNotEmpty && _isNonZeroLatitude(coordinates['BDS'], 'BDS');

                    // Проверяем, есть ли хотя бы одно решение
                    bool hasData = hasSolutionGPS || hasSolutionGLN || hasSolutionGAL || hasSolutionBDS;

                    // Если нет данных, возвращаем пустой виджет
                    if (!hasData) {
                      return const SizedBox.shrink();
                    }

                    // Сохраняем валидные скорости
                    List<double> validSpeeds = [];
                    if (hasSolutionGPS && absVGPSQueue.isNotEmpty) {
                      validSpeeds.add(absVGPSQueue.last);
                    }
                    if (hasSolutionGLN && absVGLNQueue.isNotEmpty) {
                      validSpeeds.add(absVGLNQueue.last);
                    }
                    if (hasSolutionGAL && absVGALQueue.isNotEmpty) {
                      validSpeeds.add(absVGALQueue.last);
                    }
                    if (hasSolutionBDS && absVBDSQueue.isNotEmpty) {
                      validSpeeds.add(absVBDSQueue.last);
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 8.0),
                          child: AspectRatio(
                            aspectRatio: 3,
                            // Спидометр с обновленными проверками на решение
                            child: DynamicSpeedometer(
                              gpsSpeed: _getLastValue(absVGPSQueue),
                              glnSpeed: _getLastValue(absVGLNQueue),
                              galSpeed: _getLastValue(absVGALQueue),
                              bdsSpeed: _getLastValue(absVBDSQueue),
                              hasSolutionGPS: hasSolutionGPS,
                              hasSolutionGLN: hasSolutionGLN,
                              hasSolutionGAL: hasSolutionGAL,
                              hasSolutionBDS: hasSolutionBDS,
                            ),
                          ),
                        ),
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Выводим скорости для каждой системы, если данные присутствуют
                              if (hasSolutionGPS)
                                _buildAbsVText(
                                  'GPS',
                                  absVGPSQueue,
                                  Colors.red,
                                ),
                              if (hasSolutionGLN)
                                _buildAbsVText(
                                  'GLN',
                                  absVGLNQueue,
                                  Colors.blue,
                                ),
                              if (hasSolutionGAL)
                                _buildAbsVText(
                                  'GAL',
                                  absVGALQueue,
                                  Colors.orange,
                                ),
                              if (hasSolutionBDS)
                                _buildAbsVText(
                                  'BDS',
                                  absVBDSQueue,
                                  const Color.fromARGB(255, 5, 131, 9),
                                ),
                            ],
                          ),
                        ),
                      ],
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

  // Проверяем, что широта не равна 0 для конкретной системы
  bool _isNonZeroLatitude(String? data, String systemName) {
    if (data == null || data.isEmpty) return false;

    final latitudePrefixWithApostrophe = "Широта'($systemName): ";
    final latitudePrefixWithoutApostrophe = "Широта($systemName): ";

    final startIndexWithApostrophe = data.indexOf(latitudePrefixWithApostrophe);
    final startIndexWithoutApostrophe = data.indexOf(latitudePrefixWithoutApostrophe);

    int startIndex = startIndexWithApostrophe != -1 ? startIndexWithApostrophe : startIndexWithoutApostrophe;

    if (startIndex == -1) return false;

    final latitudeString = data.substring(startIndex + (startIndexWithApostrophe != -1 ? latitudePrefixWithApostrophe.length : latitudePrefixWithoutApostrophe.length)).split(' ')[0];

    final latitude = double.tryParse(latitudeString);

    return latitude != null && latitude != 0.0;
  }

  // Метод для создания текста с последним значением скорости для конкретной системы
  Widget _buildAbsVText(
    String systemName,
    Queue<double> queue,
    Color color,
  ) {
    String absVValue = queue.isNotEmpty ? queue.last.toStringAsFixed(9) : 'Нет данных';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Text(
        'Скорость НАП по системе $systemName: $absVValue м/с',
        style: TextStyle(fontSize: 12, color: color),
      ),
    );
  }

  // Получаем последнее значение из очереди
  double _getLastValue(Queue<double> queue) {
    return queue.isNotEmpty ? queue.last : 0.0;
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
