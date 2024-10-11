import 'dart:async';
import 'package:flutter/foundation.dart';
import 'srns_isolate.manager.dart';
import 'package:flutter_application_clonicus_rxtx/tcp_client/tcp_provider.dart';

class ParsingService {
  final ValueNotifier<List<String>> parsedDataNotifier = ValueNotifier<List<String>>([]);
  final TCPProvider _tcpProvider;
  StreamSubscription? _subscription;
  final IsolateManager isolateManagerInstance = IsolateManager();

  bool _isDisposed = false;

  final ValueNotifier<bool> isParsingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isContinuousParsingNotifier = ValueNotifier<bool>(false);

  ParsingService(this._tcpProvider) {
    _initializeContinuousSubscription();
  }

  void _initializeContinuousSubscription() {
    _subscription?.cancel();
    _subscription = IsolateManager.stream.listen((message) {
      _addParsedData(message.map((data) => data.toString()).toList());
      // print('Parsed data received in srns_parser_service: $message');
    });
  }

  List<String> get parsedDataList => parsedDataNotifier.value;
  bool get isParsing => IsolateManager.isParsing;
  bool get isContinuousParsing => IsolateManager.isContinuousParsing;

  TCPProvider get tcpProvider => _tcpProvider;

  ValueNotifier<void> get parsingCompleteNotifier => IsolateManager.parsingCompleteNotifier;

  Future<void> startParsingFile(String filePath) async {
    if (isParsingNotifier.value || _isDisposed) return;

    isParsingNotifier.value = true;

    await IsolateManager.startParsingFile(filePath);

    // Добавляем слушателя на завершение парсинга
    parsingCompleteNotifier.addListener(_onParsingComplete);

    _addParsedData([
      'Parsing started'
    ]);
  }

  void _onParsingComplete() {
    if (!_isDisposed) {
      _completeParsing(); // Завершение парсинга
    }
  }

  Future<void> stopParsingFile() async {
    if (IsolateManager.isParsing && !_isDisposed) {
      await IsolateManager.stopParsingFile();
      isParsingNotifier.value = false;

      _addParsedData([
        'Parsing stopped'
      ]);
      _completeParsing();
    }
  }

  StreamSubscription<Uint8List>? tcpStreamSubscription;

  Future<void> startContinuousParsingTcp() async {
    if (isContinuousParsingNotifier.value || _isDisposed) return;

    isContinuousParsingNotifier.value = true; // Устанавливаем флаг здесь
    Uint8List accumulatedData = Uint8List(0);

    // Подписываемся на поток данных от TCP-провайдера
    tcpStreamSubscription = _tcpProvider.dataStream.listen((Uint8List newData) async {
      accumulatedData = Uint8List.fromList(accumulatedData + newData);
      // print('buffer: ${accumulatedData.length}');

      const int maxBufferSize = 5000;
      if (accumulatedData.length >= maxBufferSize) {
        Uint8List dataToSend = accumulatedData.sublist(0, maxBufferSize);
        accumulatedData = accumulatedData.sublist(maxBufferSize);

        // Передаем данные в изолятор для парсинга
        await isolateManagerInstance.sendDataToIsolate(dataToSend);
      }
    }, onError: (e) {
      print('Error receiving data: $e');
    });

    // Добавляем слушателя на завершение парсинга
    parsingCompleteNotifier.addListener(_onParsingComplete);

    print('Continuous parsing started');
  }

// Метод для остановки парсинга TCP
  Future<void> stopContinuousParsingTcp() async {
    if (isContinuousParsingNotifier.value) {
      // Проверяем, идет ли парсинг
      if (tcpStreamSubscription != null) {
        await tcpStreamSubscription?.cancel(); // Отменяем подписку
        tcpStreamSubscription = null; // Обнуляем подписку
        print('TCP stream subscription canceled.');
      }

      // Устанавливаем флаг, что парсинг завершен
      isContinuousParsingNotifier.value = false;

      // Удаляем слушателя завершения парсинга
      parsingCompleteNotifier.removeListener(_onParsingComplete);

      // Останавливаем прослушивание TCP
      await _tcpProvider.stopStream(); // Очищаем поток данных и закрываем сокет

      // Дополнительно очищаем изоляторы
      await IsolateManager.stopAllIsolates(); // Завершаем все активные изоляторы
      _addParsedData([
        'Continuous parsing stopped'
      ]);
    } else {
      print('Parsing was not active.');
    }
  }

  void _addParsedData(List<String> data) {
    if (_isDisposed) return;
    final updatedData = List<String>.from(parsedDataNotifier.value)..addAll(data);
    parsedDataNotifier.value = updatedData;
  }

  void _completeParsing() {
    if (_isDisposed) return;

    // Обновляем состояние парсинга
    isParsingNotifier.value = false;
    parsingCompleteNotifier.value = true;

    _addParsedData([
      'Parsing completed'
    ]);
    IsolateManager.cleanUpParsing();

    // Удаляем слушателя завершения
    parsingCompleteNotifier.removeListener(_onParsingComplete);
  }

  void dispose() {
    _subscription?.cancel();
    parsedDataNotifier.dispose();
    isParsingNotifier.dispose();
    isContinuousParsingNotifier.dispose();
    _isDisposed = true;
  }
}
