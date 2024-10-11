import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class TCPProvider extends ChangeNotifier {
  Socket? _socket;
  String _output = '';
  bool _isConnected = false;
  bool _isListening = false;
  bool _isRecording = false;
  File outputFile = File('/tmp/srns_parser.bin');
  bool _isFirstRun = true;
  ScrollController scrollController = ScrollController();

  final StreamController<Uint8List> _dataController = StreamController<Uint8List>.broadcast();
  StreamSubscription? _subscription; // Добавляем переменную для подписки
  Socket? get socket => _socket;

  String get output => _output;
  bool get isConnected => _isConnected;
  bool get isRecording => _isRecording;
  Stream<Uint8List> get dataStream => _dataController.stream;

  String _ipSuffix = '';
  int _port = 3490;

  String get ipSuffix => _ipSuffix;
  int get port => _port;

  TCPProvider() {
    if (_isFirstRun) {
      clearOutput();
      _isFirstRun = false;
    }
  }

  void setIpSuffix(String value) {
    _ipSuffix = value;
  }

  void setPort(int value) {
    _port = value;
  }

  Future<void> connect(String ip, int port) async {
    try {
      final socket = await Socket.connect(ip, port).timeout(const Duration(seconds: 5));
      _socket = socket;
      _isConnected = true;
      _output += 'Connected to $ip on port $port\n';
      _startListening();

      Future.delayed(const Duration(seconds: 5), () {
        if (_isConnected && _output.endsWith('Connected to $ip on port $port\n')) {
          _output += '\nNo data received after connection...\n';
        }
      });
    } catch (e) {
      _isConnected = false;
      _output += '\nFailed to connect to $ip on port $port: $e\n';
    } finally {
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _stopListening();
    await _socket?.close();
    _isConnected = false;
    _output += '\nDisconnected\n';
    notifyListeners();
  }

  void _startListening() {
    if (_socket != null && !_isListening) {
      _isListening = true;
      _subscription = _socket!.listen(
        // Сохраняем подписку
        (data) {
          _dataController.add(data); // Передача данных в StreamController
          if (_isRecording) {
            _writeToFile(data); // Запись бинарных данных
          }
          _appendOutput(String.fromCharCodes(data)); // Добавление данных в вывод
          notifyListeners();
        },
        onDone: () {
          _appendOutput('\nConnection closed.\n');
          _isConnected = false;
          _isListening = false;
          notifyListeners();
        },
        onError: (error) {
          _appendOutput('\nError: $error\n');
          _isListening = false;
          notifyListeners();
        },
        cancelOnError: true,
      );
    }
  }

  void _stopListening() {
    _isListening = false;
    _subscription?.cancel(); // Используем подписку для отмены
    _socket?.destroy();
  }

  void clearOutput() {
    _output = '';
    notifyListeners();
  }

  void startRecording() async {
    try {
      await outputFile.writeAsBytes([]); // Очистка файла перед записью
      _isRecording = true;
      notifyListeners();
    } catch (e) {
      _output += '\nError starting recording: $e\n';
      notifyListeners();
    }
  }

  void stopRecording() {
    _isRecording = false;
    notifyListeners();
  }

  void _writeToFile(Uint8List data) async {
    try {
      await outputFile.writeAsBytes(data, mode: FileMode.append);
    } catch (e) {
      _output += '\nError writing to file: $e\n';
      notifyListeners();
    }
  }

  void _appendOutput(String data) {
    _output += data;
    if (_output.length > 3000) {
      _output = _output.substring(_output.length - 3000); // Обрезаем до 3000 символов
    }
  }

  Future<void> stopStream() async {
    if (_subscription != null) {
      await _subscription!.cancel();
      _isListening = false; // Обновляем флаг, что прослушивание остановлено
      _socket?.destroy(); // Уничтожаем соединение сокета
      notifyListeners();
    }
  }
}
