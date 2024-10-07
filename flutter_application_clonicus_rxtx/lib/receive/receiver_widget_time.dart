import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'receiver_50packet.dart';
import 'receiver_notifier.dart';

class Receiver50PacketTow extends StatelessWidget {
  const Receiver50PacketTow({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReceiverNotifier>(
      builder: (context, notifier, _) {
        final receiverNotifier = Provider.of<ReceiverNotifier>(context);
        final List<String> rawData = receiverNotifier.parsedDataList;

        return FutureBuilder<String?>(
          future: readLastTowFromFiftyPacket(rawData),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Ошибка: ${snapshot.error}');
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Text('Нет данных по времени');
            } else {
              return Text(
                'Последнее значение TOW: ${snapshot.data}',
                style: const TextStyle(fontSize: 12, color: Colors.black),
              );
            }
          },
        );
      },
    );
  }
}