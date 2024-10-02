import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Для работы с буфером обмена
import 'package:provider/provider.dart';
import 'receiver_notifier.dart';
import 'receiver_50packet.dart';

class CopyCoordinatesButton extends StatelessWidget {
  const CopyCoordinatesButton({super.key});

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
              return const Text('Ошибка загрузки координат');
            } else {
              return ElevatedButton(
                onPressed: () {
                  _copyCoordinatesToClipboard(snapshot.data!, context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 211, 186, 253),
                ),
                child: const Text('Скопировать координаты'),
              );
            }
          },
        );
      },
    );
  }

  void _copyCoordinatesToClipboard(Map<String, String> lastCoordinates, BuildContext context) {
    String copyText = '';

    // Проверяем и добавляем данные для каждой системы
    if (lastCoordinates['GPS']!.isNotEmpty) {
      copyText += 'GPS: ${lastCoordinates['GPS']}\n';
    }
    if (lastCoordinates['GLN']!.isNotEmpty) {
      copyText += 'GLN: ${lastCoordinates['GLN']}\n';
    }
    if (lastCoordinates['GAL']!.isNotEmpty) {
      copyText += 'GAL: ${lastCoordinates['GAL']}\n';
    }
    if (lastCoordinates['BDS']!.isNotEmpty) {
      copyText += 'BDS: ${lastCoordinates['BDS']}\n';
    }

    // Копируем данные, если есть что копировать
    if (copyText.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: copyText));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Координаты скопированы в буфер обмена'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      // Сообщение, если нет данных для копирования
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет доступных координат для копирования'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
