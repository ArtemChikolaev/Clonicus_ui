import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BashTerminal with ChangeNotifier {
  List<String> _output = [];
  List<String> _commandHistory = [];
  String _currentDirectory = "/";
  SharedPreferences? _prefs;

  List<String> get output => _output;
  String get currentDirectory => _currentDirectory;

  BashTerminal() {
    _initializeShell();
  }

  Future<void> _initializeShell() async {
    _prefs = await SharedPreferences.getInstance();
    _currentDirectory = _prefs?.getString('current_directory') ?? Directory.current.path;
    _loadHistory();
    notifyListeners();
  }

  Future<void> _loadHistory() async {
    List<String>? savedOutput = _prefs?.getStringList('bash_output');
    List<String>? savedCommands = _prefs?.getStringList('bash_command_history');
    if (savedOutput != null) {
      _output = savedOutput;
    }
    if (savedCommands != null) {
      _commandHistory = savedCommands;
    }
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    await _prefs?.setStringList('bash_output', _output);
    await _prefs?.setStringList('bash_command_history', _commandHistory);
  }

  Future<void> _saveCurrentDirectory() async {
    await _prefs?.setString('current_directory', _currentDirectory);
  }

  Future<void> runCommand(String command) async {
    if (command == "clear") {
      clearOutput();
      return;
    }

    if (command == "prevcommand" || command == "prevcmd" || command == "prvcmd") {
      showPreviousCommand();
      return;
    }

    if (command == "clearcmd") {
      clearCommandHistory();
      return;
    }

    if (command.startsWith('cd')) {
      command = await autoCompleteDirectory(command);
    }

    if (command.startsWith('cat')) {
      command = await autoCompleteFile(command);
    }

    try {
      ProcessResult result = await Process.run(
        'bash',
        [
          '-c',
          command
        ],
        workingDirectory: _currentDirectory,
      );
      _output.add(">\$ $command");
      _commandHistory.add(command); // Сохраняем команду в историю

      if (result.stdout.isNotEmpty) {
        _output.add(result.stdout.toString().trim());
      }
      if (result.stderr.isNotEmpty) {
        _output.add(result.stderr.toString().trim());
      }

      if (command.startsWith('cd')) {
        _changeDirectory(command);
      }

      // Ограничиваем количество строк в выводе
      const int lineLimit = 100; // Максимальное количество строк (можно изменить по необходимости)

      while (_output.length > lineLimit) {
        _output.removeAt(0); // Удаляем старые строки, если превышено количество строк
      }

      notifyListeners();
      _saveHistory();
    } catch (e) {
      _output.add("Error executing command: $e");
      notifyListeners();
    }
  }

  void showPreviousCommand() {
    // Отображаем историю предыдущих команд красным цветом
    _output.addAll(_commandHistory.map((cmd) => "previous command: $cmd")); // Добавляем команды в вывод
    notifyListeners();
  }

  void clearCommandHistory() {
    // Очищаем историю команд
    _commandHistory.clear();
    _output.add("Command history cleared.");
    _prefs?.remove('bash_command_history'); // Удаляем сохраненные данные из SharedPreferences
    notifyListeners();
  }

  void _changeDirectory(String command) {
    List<String> parts = command.split(' ');
    if (parts.length > 1) {
      String path = parts[1].trim();
      Directory newDir;

      if (path.startsWith('/')) {
        newDir = Directory(path);
      } else {
        newDir = Directory("$_currentDirectory/$path");
      }

      if (newDir.existsSync()) {
        _currentDirectory = newDir.resolveSymbolicLinksSync();
        _saveCurrentDirectory();
      } else {
        _output.add("bash: cd: $path: No such file or directory");
      }
    }
  }

  Future<String> autoCompleteDirectory(String command) async {
    List<String> parts = command.split(' ');
    if (parts.length > 1) {
      String pathPart = parts.last.trim();

      // Определяем, является ли путь абсолютным или относительным
      Directory searchDir;
      if (pathPart.startsWith('/')) {
        // Абсолютный путь, нормализуем путь для удаления лишних слешей
        pathPart = pathPart.replaceAll(RegExp(r'/+'), '/');
        searchDir = Directory('/');
      } else {
        // Относительный путь от текущей директории
        searchDir = Directory(_currentDirectory);
      }

      // Получаем компоненты пути
      List<String> pathComponents = pathPart.split('/');
      String incompletePart = pathComponents.last; // Последняя часть пути для автодополнения
      String basePath = pathComponents.sublist(0, pathComponents.length - 1).join('/');

      // Если basePath непустой, ищем в конкретной директории
      if (basePath.isNotEmpty) {
        searchDir = Directory(pathPart.startsWith('/') ? '/$basePath' : '$_currentDirectory/$basePath');
      }

      if (await searchDir.exists()) {
        List<FileSystemEntity> entities = searchDir.listSync();

        // Ищем совпадения по неполному имени
        List<String> possibleMatches = entities.where((entity) => entity is Directory && entity.path.split('/').last.startsWith(incompletePart)).map((dir) => dir.path.split('/').last).toList();

        if (possibleMatches.length == 1) {
          // Строим полный путь, добавляя найденную директорию
          String completedPath = possibleMatches.first;
          String finalPath = basePath.isNotEmpty ? '$basePath/$completedPath' : completedPath;

          // Если путь абсолютный, добавляем "/", если относительный — нет
          String normalizedPath = (pathPart.startsWith('/') ? '/$finalPath' : '$finalPath').replaceAll(RegExp(r'/+'), '/'); // Нормализуем путь
          return 'cd $normalizedPath';
        }
      }
    }

    return command; // Возвращаем исходную команду, если не найдено совпадений
  }

  Future<String> autoCompleteFile(String command) async {
    return command;
  }

  void clearOutput() {
    _output.clear();
    _saveHistory();
    notifyListeners();
  }
}
