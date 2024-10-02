import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
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

        return FutureBuilder<void>(
          future: velocityFiftyPacketData(rawData),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Ошибка: ${snapshot.error}');
            } else {
              // Проверяем, есть ли данные хотя бы для одной системы
              bool hasData = _hasValidData(
                    notifier.gpsLocation,
                    notifier.gpsHeight,
                    absVGPSQueue,
                  ) ||
                  _hasValidData(
                    notifier.glnLocation,
                    notifier.glnHeight,
                    absVGLNQueue,
                  ) ||
                  _hasValidData(
                    notifier.galLocation,
                    notifier.galHeight,
                    absVGALQueue,
                  ) ||
                  _hasValidData(
                    notifier.bdsLocation,
                    notifier.bdsHeight,
                    absVBDSQueue,
                  );

              // Если нет данных ни для одной системы, возвращаем пустой виджет
              if (!hasData) {
                return const SizedBox.shrink();
              }

              // Сохранение валидных скоростей
              List<double> validSpeeds = [];
              if (_hasValidData(notifier.gpsLocation, notifier.gpsHeight, absVGPSQueue)) {
                validSpeeds.add(absVGPSQueue.last);
              }
              if (_hasValidData(notifier.glnLocation, notifier.glnHeight, absVGLNQueue)) {
                validSpeeds.add(absVGLNQueue.last);
              }
              if (_hasValidData(notifier.galLocation, notifier.galHeight, absVGALQueue)) {
                validSpeeds.add(absVGALQueue.last);
              }
              if (_hasValidData(notifier.bdsLocation, notifier.bdsHeight, absVBDSQueue)) {
                validSpeeds.add(absVBDSQueue.last);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 8.0),
                    child: AspectRatio(
                      aspectRatio: 11,
                      // Добавляем спидометр над выводом скоростей
                      child: DynamicSpeedometer(
                        gpsSpeed: _getLastValue(absVGPSQueue),
                        glnSpeed: _getLastValue(absVGLNQueue),
                        galSpeed: _getLastValue(absVGALQueue),
                        bdsSpeed: _getLastValue(absVBDSQueue),
                        hasSolutionGPS: _hasValidData(notifier.gpsLocation, notifier.gpsHeight, absVGPSQueue),
                        hasSolutionGLN: _hasValidData(notifier.glnLocation, notifier.glnHeight, absVGLNQueue),
                        hasSolutionGAL: _hasValidData(notifier.galLocation, notifier.galHeight, absVGALQueue),
                        hasSolutionBDS: _hasValidData(notifier.bdsLocation, notifier.bdsHeight, absVBDSQueue),
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
                        if (_hasValidData(notifier.gpsLocation, notifier.gpsHeight, absVGPSQueue))
                          _buildAbsVText(
                            'GPS',
                            absVGPSQueue,
                            Colors.red,
                          ),
                        if (_hasValidData(notifier.glnLocation, notifier.glnHeight, absVGLNQueue))
                          _buildAbsVText(
                            'GLN',
                            absVGLNQueue,
                            Colors.blue,
                          ),
                        if (_hasValidData(notifier.galLocation, notifier.galHeight, absVGALQueue))
                          _buildAbsVText(
                            'GAL',
                            absVGALQueue,
                            Colors.orange,
                          ),
                        if (_hasValidData(notifier.bdsLocation, notifier.bdsHeight, absVBDSQueue))
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
      },
    );
  }

  // Метод для создания текста с последним значением скорости для конкретной системы
  Widget _buildAbsVText(
    String systemName,
    Queue<double> queue,
    Color color,
  ) {
    String absVValue = queue.isNotEmpty
        ? queue.last.toStringAsFixed(9) // Берем последнее значение в очереди
        : 'Нет данных'; // Если нет данных, выводим соответствующее сообщение

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

  // Проверяем, есть ли данные для текущей системы
  bool _hasValidData(LatLng? location, double? height, Queue<double> queue) {
    return location != null && height != null && queue.isNotEmpty;
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
