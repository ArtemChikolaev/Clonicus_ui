import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'receiver_notifier.dart';
import 'receiver_f5packet.dart';

class ReceiverF5PacketSatellites extends StatelessWidget {
  final SatelliteQueue satelliteQueue = SatelliteQueue();

  ReceiverF5PacketSatellites({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReceiverNotifier>(
      builder: (context, notifier, _) {
        // Обрабатываем данные
        List<String> rawData = notifier.parsedDataList;
        double time = extractTime(rawData); // Извлекаем время из пакета (t)
        List<SatelliteData> satelliteDataList = filterF5packetData(rawData);

        // Добавляем данные в очередь
        satelliteQueue.addData(time, satelliteDataList);

        // Получаем последние данные
        Map<String, List<SatelliteData>> latestData = satelliteQueue.getLatestData();
        Map<String, int> satelliteCounts = countSatellites(latestData);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.0, horizontal: 16.0),
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
        );
      },
    );
  }

  // Метод для извлечения времени из данных
  double extractTime(List<String> dataList) {
    RegExp timeRegExp = RegExp(r't: (\d+\.\d+)');
    for (String data in dataList) {
      Match? match = timeRegExp.firstMatch(data);
      if (match != null) {
        return double.parse(match.group(1)!);
      }
    }
    return 0.0; // Возвращаем 0.0, если время не найдено
  }
}
