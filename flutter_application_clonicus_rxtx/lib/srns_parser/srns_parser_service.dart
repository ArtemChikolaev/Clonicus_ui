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

  ValueNotifier<bool> get parsingCompleteNotifier => IsolateManager.parsingCompleteNotifier;

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
      _completeParsing();
      isParsingNotifier.value = false; // Обновляем флаг парсинга
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

  Future<int> startContinuousParsingTcp(bool parse) async {
    if (_isDisposed) return -1; // Если ресурс уже освобожден, возвращаем -1

    Timer? timeoutTimer;
    Uint8List accumulatedData = Uint8List(0);
    const int maxBufferSize = 7100;
    const int timeoutInSeconds = 5;

    // Если флаг parse = false, то останавливаем работу
    if (!parse) {
      print('Stopping continuous parsing...');
      isContinuousParsingNotifier.value = false; // Сброс флага
      await tcpStreamSubscription?.cancel(); // Отписываемся от потока данных
      print('Continuous parsing stopped');
      return -1; // Возвращаем -1, указывая на остановку
    }

    // Если парсер уже запущен
    if (isContinuousParsingNotifier.value) {
      return 1; // Возвращаем 1, если уже запущен
    }

    isContinuousParsingNotifier.value = true; // Устанавливаем флаг, что парсер запущен

    // Добавляем слушателя на завершение парсинга
    parsingCompleteNotifier.addListener(_onParsingComplete);

    Completer<int> completer = Completer<int>(); // Используем Completer для возврата значения при тайм-ауте

    // Перезапускаем таймер при получении новых данных
    void resetTimeoutTimer() {
      timeoutTimer?.cancel(); // Останавливаем предыдущий таймер
      timeoutTimer = Timer(const Duration(seconds: timeoutInSeconds), () async {
        print('Timeout: No data received within $timeoutInSeconds seconds');

        if (!_isDisposed) {
          isContinuousParsingNotifier.value = false; // Сбрасываем флаг парсера
        }

        await tcpStreamSubscription?.cancel(); // Отписываемся от потока данных
        timeoutTimer?.cancel(); // Останавливаем таймер

        print('Continuous parsing stopped due to timeout');

        if (!completer.isCompleted) {
          completer.complete(-1); // Возвращаем -1 при тайм-ауте
        }
      });
    }

// Подписываемся на поток данных от TCP-провайдера
    tcpStreamSubscription = _tcpProvider.dataStream.listen((Uint8List newData) async {
      resetTimeoutTimer(); // Перезапускаем таймер при получении данных

      accumulatedData = Uint8List.fromList(accumulatedData + newData);

      if (accumulatedData.length >= maxBufferSize) {
        Uint8List dataToSend = accumulatedData.sublist(0, maxBufferSize);
        accumulatedData = accumulatedData.sublist(maxBufferSize);

        // Передаем данные в изолятор для парсинга
        await isolateManagerInstance.parsingTcpPortInIsolate(dataToSend);
      }

      if (!completer.isCompleted) {
        completer.complete(1); // Возвращаем 1 при успешном получении данных
      }
    }, onError: (e) {
      print('Error receiving data: $e');
      timeoutTimer?.cancel();
      if (!_isDisposed) {
        isContinuousParsingNotifier.value = false; // Сбрасываем флаг при ошибке
      }
      tcpStreamSubscription?.cancel(); // Добавляем отмену подписки в случае ошибки
      if (!completer.isCompleted) {
        completer.complete(-1); // Возвращаем -1 в случае ошибки
      }
    }, onDone: () {
      timeoutTimer?.cancel(); // Останавливаем таймер при завершении потока
      if (!_isDisposed) {
        isContinuousParsingNotifier.value = false; // Сбрасываем флаг при завершении потока
      }
      tcpStreamSubscription?.cancel(); // Убеждаемся, что подписка отменена
    });

    tcpStreamSubscription?.onDone(() {
      timeoutTimer?.cancel(); // Останавливаем таймер
      if (!_isDisposed) {
        isContinuousParsingNotifier.value = false; // Сбрасываем флаг при завершении потока
      }
      tcpStreamSubscription?.cancel(); // Убеждаемся, что подписка отменена
      print('TCP Stream parsing completed');
    });

    tcpStreamSubscription?.onError((e) {
      print('Error receiving data: $e');
      timeoutTimer?.cancel();
      if (!_isDisposed) {
        isContinuousParsingNotifier.value = false; // Сбрасываем флаг при ошибке
      }
      tcpStreamSubscription?.cancel(); // Добавляем отмену подписки в случае ошибки
      if (!completer.isCompleted) {
        completer.complete(-1); // Возвращаем -1 в случае ошибки
      }
    });

    resetTimeoutTimer(); // Инициализируем таймер при запуске
    return completer.future; // Возвращаем результат через Completer
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
