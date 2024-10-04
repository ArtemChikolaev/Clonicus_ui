import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'srns_parser_main.dart';

class IsolateManager {
  static Isolate? _parsingIsolate;
  static ReceivePort? _receivePort;
  static bool isContinuousParsing = false;
  static bool isParsing = false;
  static bool isListening = false; // Флаг для отслеживания состояния слушателя
  static bool shouldContinue = true; // Флаг для продолжения работы

  static StreamController<List<Map<String, dynamic>>>? _streamController;
  static final ValueNotifier<bool> isParsingNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> parsingCompleteNotifier = ValueNotifier<bool>(false);

  // Метод для получения данных из парсинга
  static Stream<List<Map<String, dynamic>>> get stream {
    if (_streamController == null || _streamController!.isClosed) {
      _streamController = StreamController<List<Map<String, dynamic>>>.broadcast();
    }
    return _streamController!.stream;
  }

  static ReceivePort? get receivePort => _receivePort;

// Запуск парсинга файла
  static Future<void> startParsingFile(String filePath) async {
    if (isParsing) return;

    isParsing = true;
    isParsingNotifier.value = true; // Устанавливаем состояние парсинга в true
    _receivePort = ReceivePort(); // Создаем новый ReceivePort

    _parsingIsolate = await Isolate.spawn(
      _startParsingFromFile,
      {
        'filePath': filePath,
        'sendPort': _receivePort!.sendPort, // Передаем SendPort
      },
    );

    _receivePort!.listen((message) {
      if (message == 'done') {
        isParsing = false; // Завершаем процесс парсинга
        isParsingNotifier.value = false; // Обновляем состояние парсинга
        parsingCompleteNotifier.value = true; // Уведомляем об окончании парсинга
        cleanUpParsing();
      } else if (message is List<Map<String, dynamic>>) {
        _streamController?.add(message); // Передаем данные через StreamController
      }
    });
  }

  // Остановка парсинга файла
  static Future<void> stopParsingFile() async {
    if (isParsing) {
      isParsing = false;

      // Отправляем сигнал на остановку парсинга
      _receivePort?.sendPort.send('stop');

      // Очищаем ресурсы
      cleanUpParsing();
    }
  }

  // Запуск постоянного парсинга
  static Future<void> startContinuousParsingFile(String filePath) async {
    if (isContinuousParsing) return;

    isContinuousParsing = true;
    _receivePort = ReceivePort();

    _parsingIsolate = await Isolate.spawn(
      _startContinuousParsingFromFile,
      {
        'filePath': filePath,
        'sendPort': _receivePort!.sendPort
      },
    );

    // Подписываемся на сообщения от изолятора
    _receivePort!.listen((message) {
      if (message is List<Map<String, dynamic>>) {
        // Передаем данные через StreamController
        if (_streamController == null || _streamController!.isClosed) {
          _streamController = StreamController<List<Map<String, dynamic>>>.broadcast();
        }
        _streamController!.add(message);
      } else if (message == 'done') {
        isContinuousParsing = false;
        // Удаляем старый контроллер, если он существует
        _streamController?.close();
        _streamController = null;
        cleanUpParsing();
      }
    });
  }

  // Остановка постоянного парсинга
  static Future<void> stopContinuousParsingFile() async {
    if (isContinuousParsing) {
      isContinuousParsing = false;

      // Отправляем сигнал на остановку парсинга
      _receivePort?.sendPort.send('stop');

      // Очищаем ресурсы
      cleanUpParsing();
    }
  }

  static Future<void> _startParsingFromFile(Map<String, dynamic> params) async {
    String filePath = params['filePath'];
    SendPort sendPort = params['sendPort']; // Получаем SendPort

    final srnsParser = SRNSParser(filePath);

    // Запуск процесса парсинга
    await srnsParser.readAndParse();

    // Подписываемся на поток данных из парсера
    srnsParser.stream.listen((data) {
      if (data.isNotEmpty) {
        sendPort.send(data); // Отправляем данные в главный изолят
      }
    }, onDone: () {
      sendPort.send('done'); // Отправляем сообщение о завершении
      isParsing = false; // Завершаем процесс парсинга
      isParsingNotifier.value = false; // Обновляем состояние парсинга
      parsingCompleteNotifier.value = true; // Уведомляем об окончании парсинга
      cleanUpParsing();
    }, onError: (error) {
      sendPort.send({
        'error': error.toString()
      });
    });
  }

  static Future<void> _startContinuousParsingFromFile(Map<String, dynamic> params) async {
    String filePath = params['filePath'];
    SendPort sendPort = params['sendPort'];

    final srnsParser = SRNSParserContinious(filePath);

    // Подписываемся на поток данных из парсера
    srnsParser.stream.listen((data) {
      if (data.isNotEmpty) {
        // Отправляем данные в главный изолят
        sendPort.send(data);
      }
    });

    // Запускаем процесс парсинга
    await srnsParser.start();
    sendPort.send('done'); // Отправляем сообщение о завершении парсинга
  }

  static void cleanUpParsing() {
    _receivePort?.close();
    _receivePort = null;
    // Устанавливаем значение в false, если парсинг завершен
    _parsingIsolate?.kill(priority: Isolate.immediate);
    _parsingIsolate = null;
    _streamController?.close();
    _streamController = null; // Очищаем контроллер, чтобы он мог быть пересоздан
  }

  // Метод для продолжения парсера при возвращении на страницу
  static Future<void> resumeParsingIfNeeded(String filePath) async {
    if (isContinuousParsing) {
      // Если парсер уже запущен, просто перезапускаем
      await stopContinuousParsingFile();
      await startContinuousParsingFile(filePath);
    }
  }
}
