import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_application_clonicus_rxtx/srns_parser/srns_parser_navsystype.dart';
import 'package:flutter_application_clonicus_rxtx/srns_parser/srns_parser_structure.dart';

List<Map<String, dynamic>> packetParserF5(Uint8List data) {
  // Преобразуем Uint8List в ByteData
  ByteData byteData = ByteData.sublistView(data);

  // Парсим данные через наш Srns0xF5 класс
  Srns0xF5 packet = Srns0xF5.fromByteData(byteData);

  // Подготовим список для хранения данных
  List<Map<String, dynamic>> parsedPacketData = [];

  // Добавляем данные заголовка
  parsedPacketData.add({
    't': packet.header.t,
    // 'WN': packet.header.WN,
    // 'dGPSUTC': packet.header.dGPSUTC,
    // 'dGLNUTC': packet.header.dGLNUTC,
    // 'TimeScaleCorrection': packet.header.timeScaleCorrection,
  });

  // Добавляем данные по каждому спутнику
  for (var sig in packet.signals) {
    // Определяем тип сигнала
    SignalType signalType = getSignalType(sig.type);

    parsedPacketData.add({
      'type': signalTypeToString(signalType), // Получаем строковое представление типа сигнала
      'sgnID': sig.sgnID,
      'lit': sig.lit,
      'q': sig.q,
      // 'phase': sig.phase,
      // 'range': sig.range / 1e3 * LightC, // пересчитываем range
      // 'doppler': sig.doppler,
      // 'flags': sig.flags,
      // 'reserved': sig.reserved,
    });
  }
  // print('$parsedPacketData');
  return parsedPacketData;
}

List<Map<String, dynamic>> packetParser55(Uint8List data) {
  // Получаем ByteData для работы с байтовыми данными
  final ByteData byteData = ByteData.sublistView(data);

  // Парсим данные из байтов в объект Srns0x55
  Srns0x55 packet = Srns0x55.fromByteData(byteData);

  // Парсим информацию о спутнике
  SatDescr satDescr = SatDescr.fromByteData(byteData, 0); // offset = 0, т.к. первый элемент

  // Создаём карту с результатами для дальнейшего вывода
  Map<String, dynamic> parsedData = {
    'Type': satDescr.type.toString().split('.').last, // Тип системы (NavSysType)
    'SatID': satDescr.satID, // Номер спутника
    'El': (packet.El / pi * 180).toStringAsFixed(3), // Угол места
    'Az': (packet.Az / pi * 180).toStringAsFixed(3), // Азимут
    // 'PVel': packet.pvel.toStringAsFixed(3), // Скорость
  };

  // Возвращаем список с единственной записью (один пакет данных)
  return [
    parsedData
  ];
}

// Модифицированный парсинг данных
List<Map<String, dynamic>> packetParser50(Uint8List data) {
  ByteData byteData = ByteData.sublistView(data);
  List<Map<String, dynamic>> parsedPackets = [];

  for (int i = 0; i < data.lengthInBytes; i += 104) {
    Srns0x50 packet = Srns0x50.fromByteData(byteData.buffer.asByteData(i, 104));

    double absV = packet.getAbsVelocity();

    // Получаем тип навигационной системы
    NavSysType navSysType = navSysFromInt(packet.statAndSys & 0xFFFF);
    String navSys = navSysToString(navSysType);

    // Добавляем пакет в список
    parsedPackets.add({
      'WN': packet.WN,
      'TOW': packet.TOW,
      'NavSys': navSys,
      'Status': (packet.statAndSys >> 16) & 0xFF,
      'Latitude': packet.lat,
      'Longitude': packet.lon,
      'Height': packet.height.toStringAsFixed(3),
      'Vx': packet.vLat,
      'Vy': packet.vLon,
      'Vz': packet.vH,
      'AbsV': absV,
      'RMS': packet.posRMS.toStringAsFixed(2),
      'PDOP': packet.PDOP.toStringAsFixed(1)
    });
  }

  return parsedPackets;
}
