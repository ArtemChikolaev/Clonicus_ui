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

    if (!parse) {
      print('Stopping continuous parsing...');
      isContinuousParsingNotifier.value = false;
      await tcpStreamSubscription?.cancel();
      print('Continuous parsing stopped');
      return -1;
    }

    if (isContinuousParsingNotifier.value) {
      return 1;
    }

    isContinuousParsingNotifier.value = true;

    Completer<int> completer = Completer<int>();

    void resetTimeoutTimer() {
      timeoutTimer?.cancel();
      timeoutTimer = Timer(const Duration(seconds: timeoutInSeconds), () async {
        print('Timeout: No data received within $timeoutInSeconds seconds');

        // Останавливаем парсер из-за таймаута
        isContinuousParsingNotifier.value = false;
        parsingCompleteNotifier.value = true;

        await tcpStreamSubscription?.cancel();
        timeoutTimer?.cancel();

        print('Continuous parsing stopped due to timeout');

        // Завершаем операцию с результатом -1
        if (!completer.isCompleted) {
          completer.complete(-1);
        }
      });
    }

    // Обработчик получения данных
    tcpStreamSubscription = _tcpProvider.dataStream.listen((Uint8List newData) async {
      resetTimeoutTimer(); // Сбрасываем таймер при каждом новом получении данных
      accumulatedData = Uint8List.fromList(accumulatedData + newData);

      if (accumulatedData.length >= maxBufferSize) {
        Uint8List dataToSend = accumulatedData.sublist(0, maxBufferSize);
        accumulatedData = accumulatedData.sublist(maxBufferSize);

        await isolateManagerInstance.parsingTcpPortInIsolate(dataToSend);
      }

      if (!completer.isCompleted) {
        completer.complete(1);
      }
    }, onError: (e) {
      timeoutTimer?.cancel();
      isContinuousParsingNotifier.value = false;
      tcpStreamSubscription?.cancel();
      if (!completer.isCompleted) {
        completer.complete(-1);
      }
    }, onDone: () {
      timeoutTimer?.cancel();
      isContinuousParsingNotifier.value = false;
      tcpStreamSubscription?.cancel();
    });

    resetTimeoutTimer();
    return completer.future;
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
