import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'receiver_notifier.dart';

class RemoveMarkerButton extends StatelessWidget {
  const RemoveMarkerButton({super.key});

  @override
  Widget build(BuildContext context) {
    final receiverNotifier = Provider.of<ReceiverNotifier>(context);

    return ElevatedButton(
      onPressed: () {
        // Удаляем маркер с карты
        receiverNotifier.removeMarker();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 252, 149, 142),
      ),
      child: const Text('Удалить маркер'),
    );
  }
}
