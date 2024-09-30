// ignore_for_file: constant_identifier_names

enum NavSysType {
  GPS,
  GLN,
  GAL,
  BDS,
  LCT,
  LOC,
  SBS,
  TST,
  NavSysTypeLast,
  UNKNOWN_SYS,
  AnyNavSys,
  NavSysTypeEnd
}

const List<String> navSysTypeStr = [
  "GPS",
  "GLN",
  "GAL",
  "BDS",
  "LCT",
  "LOC",
  "SBS",
  "TST",
  "NavSysTypeLast",
  "UNKNOWN_SYS",
  "AnyNavSys",
  "NavSysTypeEnd",
];

// Функция для преобразования int значения в NavSysType
NavSysType navSysFromInt(int value) {
  if (value >= 0 && value < NavSysType.NavSysTypeLast.index) {
    return NavSysType.values[value];
  }
  return NavSysType.UNKNOWN_SYS;
}

// Функция для получения строкового представления NavSysType
String navSysToString(NavSysType type) {
  if (type.index < navSysTypeStr.length) {
    return navSysTypeStr[type.index];
  }
  return "Unknown";
}

// Определяем перечисление для типов сигналов
enum SignalType {
  GlnL1OF,
  GlnL2OF,
  GpsL1CA,
  GpsL2CM,
  GPSL5I,
  GalE1B,
  GalE5aI,
  GalE5bI,
  BdsB1I,
  BdsB2I,
  Unknown, // На случай, если тип сигнала неизвестен
}

// Функция для получения типа сигнала по значению
SignalType getSignalType(int type) {
  switch (type) {
    case 1:
      return SignalType.GlnL1OF;
    case 33:
      return SignalType.GlnL2OF;
    case 2:
      return SignalType.GpsL1CA;
    case 34:
      return SignalType.GpsL2CM;
    case 66:
      return SignalType.GPSL5I;
    case 6:
      return SignalType.GalE1B;
    case 38:
      return SignalType.GalE5aI;
    case 55:
      return SignalType.GalE5bI;
    case 8:
      return SignalType.BdsB1I;
    case 40:
      return SignalType.BdsB2I;
    default:
      return SignalType.Unknown; // Если тип неизвестен
  }
}

// Функция для получения строки сигнала по типу
String signalTypeToString(SignalType signalType) {
  switch (signalType) {
    case SignalType.GlnL1OF:
      return "GlnL1OF";
    case SignalType.GlnL2OF:
      return "GlnL2OF";
    case SignalType.GpsL1CA:
      return "GpsL1CA";
    case SignalType.GpsL2CM:
      return "GpsL2CM";
    case SignalType.GPSL5I:
      return "GpsL5I";
    case SignalType.GalE1B:
      return "GalE1B";
    case SignalType.GalE5aI:
      return "GalE5aI";
    case SignalType.GalE5bI:
      return "GalE5bI";
    case SignalType.BdsB1I:
      return "BdsB1I";
    case SignalType.BdsB2I:
      return "BdsB2I";
    default:
      return "Unknown"; // Если тип неизвестен
  }
}
