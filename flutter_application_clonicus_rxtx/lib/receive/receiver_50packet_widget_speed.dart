import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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

  // Проверяем, есть ли данные для текущей системы
  bool _hasValidData(LatLng? location, double? height, Queue<double> queue) {
    return location != null && height != null && queue.isNotEmpty;
  }
}
