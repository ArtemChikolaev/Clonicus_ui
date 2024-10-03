import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'receiver_55packet.dart';
import 'receiver_notifier.dart';

class Receiver55PacketData extends StatelessWidget {
  const Receiver55PacketData({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReceiverNotifier>(
      builder: (context, notifier, _) {
        final receiverNotifier = Provider.of<ReceiverNotifier>(context);
        final List<String> rawData = receiverNotifier.parsedDataList;

        return FutureBuilder<List<String>>(
          future: processFiftyFivePacketData(rawData),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Ошибка: ${snapshot.error}');
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Text('Нет данных');
            } else {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: snapshot.data!.map((data) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      data,
                      style: const TextStyle(fontSize: 10, color: Colors.black), // Общий стиль текста
                    ),
                  );
                }).toList(),
              );
            }
          },
        );
      },
    );
  }
}
