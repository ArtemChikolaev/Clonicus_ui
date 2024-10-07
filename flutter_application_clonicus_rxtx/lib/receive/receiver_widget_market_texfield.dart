import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'receiver_notifier.dart';

class ReceiverWidgetMarkerTextField extends StatefulWidget {
  const ReceiverWidgetMarkerTextField({super.key});

  @override
  ReceiverWidgetMarkerTextFieldState createState() => ReceiverWidgetMarkerTextFieldState();
}

class ReceiverWidgetMarkerTextFieldState extends State<ReceiverWidgetMarkerTextField> {
  final TextEditingController _coordsController = TextEditingController();
  bool _isInputFieldVisible = false;
  bool _isUserInput = false;
  double? _currentHeight;

  @override
  Widget build(BuildContext context) {
    final receiverNotifier = Provider.of<ReceiverNotifier>(context);
    LatLng? markerLocation = receiverNotifier.markerLocation;

    // Если маркер был перемещен и пользователь не вводил данные вручную
    if (markerLocation != null && !_isUserInput) {
      _coordsController.text = '${markerLocation.latitude.toStringAsFixed(7)}, ${markerLocation.longitude.toStringAsFixed(7)}${_currentHeight != null && _currentHeight! > 0 ? ', ${_currentHeight.toString()}' : ''}';
    }

    return Column(
      children: [
        Center(
          child: ElevatedButton(
            onPressed: () {
              // Переключаем видимость текстового поля
              setState(() {
                _isInputFieldVisible = !_isInputFieldVisible;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isInputFieldVisible
                  ? const Color.fromARGB(255, 252, 149, 142) // Цвет для состояния "Закрыть окно"
                  : const Color.fromARGB(255, 211, 186, 253), // Цвет для состояния "Ввести координаты маркера"
            ),
            child: Text(_isInputFieldVisible ? 'Закрыть окно' : 'Ввести координаты маркера'),
          ),
        ),
        const SizedBox(height: 20),
        if (_isInputFieldVisible)
          TextField(
            controller: _coordsController,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'Введите координаты маркера (latitude, longitude, height(опционально))',
              helperText: 'Например: 55.149391, 37.942134, 212.22',
              suffixIcon: IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color.fromARGB(255, 252, 149, 142),
                ),
                onPressed: () {
                  _coordsController.clear(); // Очищаем текстовое поле
                  _isUserInput = false; // Сбрасываем флаг, так как поле очищено
                  _currentHeight = null; // Сбрасываем высоту
                },
              ),
            ),
            onChanged: (value) {
              _isUserInput = true; // Пользователь вводит данные вручную
            },
            onSubmitted: (value) {
              List<String> coords = value.split(',');
              if (coords.length == 2 || coords.length == 3) {
                double? lat = double.tryParse(coords[0].trim());
                double? lon = double.tryParse(coords[1].trim());

                if (coords.length == 3) {
                  _currentHeight = double.tryParse(coords[2].trim());
                } else {
                  _currentHeight = null;
                }

                if (lat != null && lon != null) {
                  // Обновляем маркер
                  receiverNotifier.setMarkerLocation(LatLng(lat, lon), height: _currentHeight);
                  _isUserInput = false; // Ввод завершен
                }
              }
            },
          ),
      ],
    );
  }
}
