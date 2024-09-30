import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'receiver_50packet.dart';
import 'receiver_notifier.dart';

class Receiver50PacketCoord extends StatelessWidget {
  const Receiver50PacketCoord({super.key});

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
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: snapshot.data!.entries.map((entry) {
                  return RichText(
                    text: TextSpan(
                      children: _buildTextSpans(entry.value),
                      style: const TextStyle(fontSize: 14, color: Colors.black), // Общий стиль текста
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

  List<TextSpan> _buildTextSpans(String coord) {
    List<TextSpan> spans = [];
    List<String> parts = coord.split(' ');

    for (String part in parts) {
      // Определяем стиль в зависимости от системы навигации
      if (part.contains('(GPS):')) {
        spans.add(TextSpan(text: part, style: const TextStyle(color: Colors.red)));
      } else if (part.contains('(GLN):')) {
        spans.add(TextSpan(text: part, style: const TextStyle(color: Colors.blue)));
      } else if (part.contains('(GAL):')) {
        spans.add(TextSpan(text: part, style: const TextStyle(color: Colors.orange)));
      } else if (part.contains('(BDS):')) {
        spans.add(TextSpan(text: part, style: const TextStyle(color: Color.fromARGB(255, 5, 131, 9))));
      } else {
        // Для остальных частей используем стандартный стиль
        spans.add(TextSpan(text: part));
      }
      spans.add(const TextSpan(text: ' ')); // Добавляем пробел после каждого элемента
    }

    return spans;
  }
}
