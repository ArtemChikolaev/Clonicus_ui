class Calendar {
  int year;
  int month;
  int day;
  int hour;
  int minute;
  int second;
  double frsec;

  Calendar({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.second,
    required this.frsec,
  });
}

class GTime {
  int time; // seconds since 1970 (TAI)
  double sec; // fractional seconds

  GTime({required this.time, required this.sec});
}

// Коррекция недели WN с учетом переполнения (каждые 1024 недели)
GTime convertTowToGTime(int wn, double tow) {
  const int secondsInWeek = 604800; // Количество секунд в неделе
  const int gpsEpochInUnix = 315964800; // Эпоха GPS в Unix-время (6 января 1980)
  const int weekFull = 1024;

  // Ожидаемая текущая неделя и секунда недели
  int currentUnixTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  int gpsWeeksSinceEpoch = (currentUnixTime - gpsEpochInUnix) ~/ secondsInWeek;

  // Коррекция для переполнения WN
  int correctedWn = wn-522; // учет того, что время идет на 10 лет позже;
  double correctedTow = tow - 86400*3; 
  if (gpsWeeksSinceEpoch - wn > weekFull) {
    correctedWn += 1024;
  } else if (wn - gpsWeeksSinceEpoch > weekFull) {
    correctedWn -= 1024;
  }

  // Перевод WN и TOW в Unix-время
  int totalSeconds = gpsEpochInUnix + correctedWn * secondsInWeek + correctedTow.toInt();
  double fractionalSeconds = correctedTow - correctedTow.toInt();

  return GTime(time: totalSeconds, sec: fractionalSeconds);
}

// Получение количества високосных секунд на основе времени
int getLeapSecondsTAI(GTime t) {
  List<List<int>> leaps = [
    // формат: [год, месяц, день, часы, минуты, секунды, количество високосных секунд, unix_time с учетом високосных секунд, unix_time без високосных секунд]
    [1970, 1, 1, 0, 0, 0,  0, 0         , 0         ],
    [1972, 1, 1, 0, 0, 0, 10, 63072010  , 63072000  ],
    [1972, 7, 1, 0, 0, 0, 11, 78796811  , 78796800  ],
    [1973, 1, 1, 0, 0, 0, 12, 94694412  , 94694400  ],
    [1974, 1, 1, 0, 0, 0, 13, 126230413 , 126230400 ],
    [1975, 1, 1, 0, 0, 0, 14, 157766414 , 157766400 ],
    [1976, 1, 1, 0, 0, 0, 15, 189302415 , 189302400 ],
    [1977, 1, 1, 0, 0, 0, 16, 220924816 , 220924800 ],
    [1978, 1, 1, 0, 0, 0, 17, 252460817 , 252460800 ],
    [1979, 1, 1, 0, 0, 0, 18, 283996818 , 283996800 ],
    [1980, 1, 1, 0, 0, 0, 19, 315532819 , 315532800 ],
    [1981, 7, 1, 0, 0, 0, 20, 362793620 , 362793600 ],
    [1982, 7, 1, 0, 0, 0, 21, 394329621 , 394329600 ],
    [1983, 7, 1, 0, 0, 0, 22, 425865622 , 425865600 ],
    [1985, 7, 1, 0, 0, 0, 23, 489024023 , 489024000 ],
    [1988, 1, 1, 0, 0, 0, 24, 567993624 , 567993600 ],
    [1990, 1, 1, 0, 0, 0, 25, 631152025 , 631152000 ],
    [1991, 1, 1, 0, 0, 0, 26, 662688026 , 662688000 ],
    [1992, 7, 1, 0, 0, 0, 27, 709948827 , 709948800 ],
    [1993, 7, 1, 0, 0, 0, 28, 741484828 , 741484800 ],
    [1994, 7, 1, 0, 0, 0, 29, 773020829 , 773020800 ],
    [1996, 1, 1, 0, 0, 0, 30, 820454430 , 820454400 ],
    [1997, 7, 1, 0, 0, 0, 31, 867715231 , 867715200 ],
    [1999, 1, 1, 0, 0, 0, 32, 915148832 , 915148800 ],
    [2006, 1, 1, 0, 0, 0, 33, 1136073633, 1136073600],
    [2009, 1, 1, 0, 0, 0, 34, 1230768034, 1230768000],
    [2012, 7, 1, 0, 0, 0, 35, 1341100835, 1341100800],
    [2015, 7, 1, 0, 0, 0, 36, 1435708836, 1435708800],
    [2017, 1, 1, 0, 0, 0, 37, 1483228837, 1483228800],
     // stub data:
    [2060, 1, 1, 0, 0, 0, 38, 2840140838, 2840140800],
    [2061, 1, 1, 0, 0, 0, 39, 2871763239, 2871763200],
    [2062, 1, 1, 0, 0, 0, 40, 2903299240, 2903299200],
    [2063, 1, 1, 0, 0, 0, 41, 2934835241, 2934835200],
    [2064, 1, 1, 0, 0, 0, 42, 2966371242, 2966371200],
    [2065, 1, 1, 0, 0, 0, 43, 2997993643, 2997993600],
  ];

  int ls = leaps[0][6]; // Начальное количество високосных секунд
  for (int i = 1; i < leaps.length; i++) {
    if (t.time > leaps[i][7]) {
      ls = leaps[i][6];
    } else {
      return ls;
    }
  }
  return ls;
}

// Конвертирование TAI в календарное время
void tai2calendar(GTime t, Calendar cal) {
  int leaps = getLeapSecondsTAI(t);
  t.time -= leaps; // Учитываем високосные секунды

  utc2calendar(t, cal); // Преобразуем в календарное время
}

// Исправленная функция utc2calendar для корректного расчета даты
void utc2calendar(GTime t, Calendar cal) {
  List<int> mday = [
    31,
    28,
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31
  ];

  // Высчитываем количество дней с 1 января 1970 года
  int days = (t.time ~/ 86400);
  int sec = (t.time - days * 86400).toInt();

  int year = 1970; // Начинаем с 1970 года
  int month = 1;
  int day = 1; // 1 января 1970 - начало GPS времени

  // Высчитываем год, начиная с 1970
  while (days >= 365) {
    bool isLeap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
    int daysInYear = isLeap ? 366 : 365;

    if (days >= daysInYear) {
      days -= daysInYear;
      year++;
    } else {
      break;
    }
  }

  // Корректируем февраль для високосного года
  if ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)) {
    mday[1] = 29;
  }

  // Высчитываем месяц и день
  for (int i = 0; i < 12; i++) {
    if (days >= mday[i]) {
      days -= mday[i];
      month++;
    } else {
      break;
    }
  }

  // Добавляем оставшиеся дни
  day += days;

  // Устанавливаем значения в календарь
  cal.year = year;
  cal.month = month;
  cal.day = day;
  cal.hour = sec ~/ 3600;
  cal.minute = (sec % 3600) ~/ 60;
  cal.second = sec % 60;
  cal.frsec = t.sec;
}

// Форматирование календарного времени в строку
String formatCalendarTime(Calendar cal) {
  return '${cal.year.toString().padLeft(4, '0')}-'
      '${cal.month.toString().padLeft(2, '0')}-'
      '${cal.day.toString().padLeft(2, '0')} '
      '${cal.hour.toString().padLeft(2, '0')}:'
      '${cal.minute.toString().padLeft(2, '0')}:'
      '${cal.second.toString().padLeft(2, '0')}.'
      '${(cal.frsec * 1000).toInt().toString().padLeft(3, '0')}';
}
