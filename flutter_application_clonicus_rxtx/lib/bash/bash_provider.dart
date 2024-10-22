import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Для сохранения данных

class BashTerminal with ChangeNotifier {
  List<String> _output = [];
  String _currentDirectory = "/";
  final List<String> _commandHistory = [];
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
    if (savedOutput != null) {
      _output = savedOutput;
    }
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    await _prefs?.setStringList('bash_output', _output);
  }

  Future<void> _saveCurrentDirectory() async {
    await _prefs?.setString('current_directory', _currentDirectory);
  }

  Future<void> runCommand(String command) async {
    if (command == "clear") {
      clearOutput();
      return;
    }

    // Добавляем команду в историю
    _commandHistory.add(command);

    if (command.startsWith('cd')) {
      command = await autoCompleteDirectory(command);
    }

    try {
      ProcessResult result = await Process.run(
          'bash',
          [
            '-c',
            command
          ],
          workingDirectory: _currentDirectory);
      _output.add(">\$ $command");

      if (result.stdout.isNotEmpty) {
        _output.add(result.stdout.toString().trim());
      }
      if (result.stderr.isNotEmpty) {
        _output.add(result.stderr.toString().trim());
      }

      if (command.startsWith('cd')) {
        _changeDirectory(command);
      }

      notifyListeners();
      _saveHistory();
    } catch (e) {
      _output.add("Error executing command: $e");
      notifyListeners();
    }
  }

  // Обработка автодополнения директории
  Future<String> autoCompleteDirectory(String command) async {
    List<String> parts = command.split(' ');
    if (parts.length > 1) {
      String pathPart = parts[1].trim();
      Directory currentDir = Directory(_currentDirectory);
      List<FileSystemEntity> entities = currentDir.listSync();

      List<String> possibleMatches = entities.where((entity) => entity is Directory && entity.path.split('/').last.startsWith(pathPart)).map((dir) => dir.path.split('/').last).toList();

      if (possibleMatches.length == 1) {
        String completedPath = possibleMatches.first;
        return 'cd $completedPath';
      }
    }

    return command;
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

  void clearOutput() {
    _output.clear();
    _saveHistory();
    notifyListeners();
  }
}
