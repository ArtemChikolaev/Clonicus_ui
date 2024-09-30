// ignore_for_file: unused_local_variable, non_constant_identifier_names

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_application_clonicus_rxtx/srns_parser/srns_parser_navsystype.dart';

class PacketData {
  int preamble;
  int sender;
  int size;
  int getSize;
  int id;
  int counter;
  int crcCalc;
  int crcPos;
  Uint8List data;

  PacketData({
    required this.preamble,
    required this.sender,
    required this.size,
    required this.getSize,
    required this.id,
    required this.counter,
    required this.crcCalc,
    required this.crcPos,
    required this.data,
  });
}

// Константа для скорости света
const double lightC = 299792458.0;

// Структура Srns0xF5SatData
class Srns0xF5SatData {
  final int type;
  final int sgnID;
  final int lit;
  final int q;
  final double phase;
  final double range;
  final double doppler;
  final int flags;
  final int reserved;

  Srns0xF5SatData({
    required this.type,
    required this.sgnID,
    required this.lit,
    required this.q,
    required this.phase,
    required this.range,
    required this.doppler,
    required this.flags,
    required this.reserved,
  });

  // Парсинг данных из ByteData
  factory Srns0xF5SatData.fromByteData(ByteData data, int offset) {
    return Srns0xF5SatData(
      type: data.getInt8(offset),
      sgnID: data.getInt8(offset + 1),
      lit: data.getInt8(offset + 2),
      q: data.getInt8(offset + 3),
      phase: data.getFloat64(offset + 4, Endian.little),
      range: data.getFloat64(offset + 12, Endian.little),
      doppler: data.getFloat64(offset + 20, Endian.little),
      flags: data.getInt8(offset + 28),
      reserved: data.getUint8(offset + 29),
    );
  }
}

// Структура заголовка Srns0xF5Header
class Srns0xF5Header {
  final double t;
  final int WN;
  final double dGPSUTC;
  final double dGLNUTC;
  final int timeScaleCorrection;

  Srns0xF5Header({
    required this.t,
    required this.WN,
    required this.dGPSUTC,
    required this.dGLNUTC,
    required this.timeScaleCorrection,
  });

  // Парсинг заголовка из ByteData
  factory Srns0xF5Header.fromByteData(ByteData data) {
    return Srns0xF5Header(
      t: data.getFloat64(0, Endian.little),
      WN: data.getInt16(8, Endian.little),
      dGPSUTC: data.getFloat64(10, Endian.little),
      dGLNUTC: data.getFloat64(18, Endian.little),
      timeScaleCorrection: data.getInt8(26),
    );
  }
}

// Конечная структура Srns0xF5
class Srns0xF5 {
  final Srns0xF5Header header;
  final List<Srns0xF5SatData> signals;

  Srns0xF5({
    required this.header,
    required this.signals,
  });

  // Парсинг всей структуры
  factory Srns0xF5.fromByteData(ByteData data) {
    // Заголовок
    Srns0xF5Header header = Srns0xF5Header.fromByteData(data);

    // Размеры данных для сигнатур
    const int satDataSize = 30; // 30 байт на одну сигнатуру
    int headerSize = 27; // Размер заголовка (в байтах)
    int remainingDataSize = data.lengthInBytes - headerSize;
    int numberOfSatData = remainingDataSize ~/ satDataSize;

    // Чтение всех данных для спутников
    List<Srns0xF5SatData> signals = [];
    for (int i = 0; i < numberOfSatData; i++) {
      int offset = headerSize + i * satDataSize;
      signals.add(Srns0xF5SatData.fromByteData(data, offset));
    }

    return Srns0xF5(header: header, signals: signals);
  }
}

// Класс для описания SatDescr
class SatDescr {
  final NavSysType type; // тип системы (NavSysType, 8 бит)
  final int satID; // идентификатор спутника (8 бит)
  final int point; // номер точки (3 бит)

  SatDescr({required this.type, required this.satID, required this.point});

  // Преобразование целого числа в NavSysType
  static NavSysType _intToNavSysType(int value) {
    if (value < NavSysType.values.length) {
      return NavSysType.values[value];
    }
    return NavSysType.UNKNOWN_SYS; // значение по умолчанию
  }

  // Фабричный метод для создания объекта SatDescr из ByteData
  factory SatDescr.fromByteData(ByteData data, int offset) {
    final int packedData = data.getUint32(offset, Endian.little);

    // Распаковываем данные
    final int typeValue = (packedData & 0xFF); // первые 8 бит
    final int satID = ((packedData >> 8) & 0xFF) + 1; // следующие 8 бит
    final int point = ((packedData >> 16) & 0x07); // 3 бита для point

    return SatDescr(
      type: _intToNavSysType(typeValue), // конвертируем в NavSysType
      satID: satID,
      point: point,
    );
  }
}

// Основной класс для пакета 55
class Srns0x55 {
  final SatDescr sat; // структура SatDescr
  final int sgn; // для SgnDescr (4 байта)
  final int pos; // для TPV (112 байт)
  final int tbcst; // для gtime_t (16 байт)
  final double El; // угол места (float, 4 байта)
  final double Az; // азимут (float, 4 байта)
  final double pvel; // скорость (double, 8 байт)

  Srns0x55({
    required this.sat,
    required this.sgn,
    required this.pos,
    required this.tbcst,
    required this.El,
    required this.Az,
    required this.pvel,
  });

  // Фабричный метод для создания объекта из ByteData
  factory Srns0x55.fromByteData(ByteData data) {
    return Srns0x55(
      // SatDescr занимает первые 4 байта
      sat: SatDescr.fromByteData(data, 0),

      // SgnDescr находится на смещении 4 байта (4 байта данных)
      sgn: data.getInt32(4, Endian.little),

      // TPV занимает 112 байт, начиная с 8 байта
      pos: data.getInt32(8, Endian.little),

      // gtime_t занимает 16 байт, начиная с 120 байта
      tbcst: data.getInt64(120, Endian.little),

      // Угол места (El), начиная с 136 байта, 4 байта данных (float)
      El: data.getFloat32(136, Endian.little),

      // Азимут (Az), начиная с 140 байта, 4 байта данных (float)
      Az: data.getFloat32(140, Endian.little),

      // Скорость (pvel), начиная с 144 байта, 8 байт данных (double)
      pvel: data.getFloat64(144, Endian.little),
    );
  }
}

// Структура пакета Srns0x50
class Srns0x50 {
  final int WN; // Week Number
  final double TOW; // Time of Week (TAI, мс)
  final double lat; // Latitude (градусы)
  final double lon; // Longitude (градусы)
  final double height; // Geodetic height (м)
  final double posRMS; // Position RMS (м)
  final double heightRMS; // Reserved (м)
  final double PDOP; // Position Dilution of Precision
  final double shift; // Reserved
  final int dTAIUTC; // Leap Seconds TAI-UTC
  final int statAndSys; // Status and Navigation System flags
  final double vLat; // Velocity in Latitude direction (м/с)
  final double vLon; // Velocity in Longitude direction (м/с)
  final double vH; // Vertical Velocity (м/с)
  final double vRMS; // Velocity RMS (м/с)
  final double vPDOP; // Velocity PDOP

  Srns0x50({
    required this.WN,
    required this.TOW,
    required this.lat,
    required this.lon,
    required this.height,
    required this.posRMS,
    required this.heightRMS,
    required this.PDOP,
    required this.shift,
    required this.dTAIUTC,
    required this.statAndSys,
    required this.vLat,
    required this.vLon,
    required this.vH,
    required this.vRMS,
    required this.vPDOP,
  });

  // Парсинг данных из ByteData
  factory Srns0x50.fromByteData(ByteData data) {
    return Srns0x50(
      WN: data.getInt32(0, Endian.little), // Week Number (int32)
      TOW: data.getFloat64(8, Endian.little), // Time of Week (double)
      lat: data.getFloat64(16, Endian.little), // Latitude (double)
      lon: data.getFloat64(24, Endian.little), // Longitude (double)
      height: data.getFloat64(32, Endian.little), // Height (double)
      posRMS: data.getFloat32(40, Endian.little), // Position RMS (float)
      heightRMS: data.getFloat32(44, Endian.little), // Reserved (float)
      PDOP: data.getFloat32(48, Endian.little), // PDOP (float)
      shift: data.getFloat64(52, Endian.little), // Reserved (double)
      dTAIUTC: data.getInt32(60, Endian.little), // TAI-UTC (int32)
      statAndSys: data.getInt32(68, Endian.little), // Status and System (int32)
      vLat: data.getFloat64(72, Endian.little), // Velocity Latitude (double)
      vLon: data.getFloat64(80, Endian.little), // Velocity Longitude (double)
      vH: data.getFloat64(88, Endian.little), // Vertical Velocity (double)
      vRMS: data.getFloat32(92, Endian.little), // Velocity RMS (float)
      vPDOP: data.getFloat32(96, Endian.little), // Velocity PDOP (float)
    );
  }

  // Метод для вычисления абсолютной скорости
  double getAbsVelocity() {
    return sqrt(vLat * vLat + vLon * vLon + vH * vH);
  }
}
