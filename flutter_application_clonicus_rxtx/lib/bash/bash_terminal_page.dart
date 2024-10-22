import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart'; // Подключаем Google Fonts
import 'bash_provider.dart';

class BashPage extends StatelessWidget {
  const BashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BashTerminal(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bash Terminal'),
        ),
        body: const TerminalScreen(),
      ),
    );
  }
}

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  TerminalScreenState createState() => TerminalScreenState();
}

class TerminalScreenState extends State<TerminalScreen> {
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus(); // Активируем фокус сразу при запуске
  }

  @override
  Widget build(BuildContext context) {
    final bash = Provider.of<BashTerminal>(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });

    return Column(
      children: [
        Expanded(
          child: Container(
            color: const Color.fromARGB(255, 44, 41, 41),
            child: ScrollbarTheme(
              data: ScrollbarThemeData(
                thumbColor: WidgetStateProperty.all<Color>(Colors.white), // Цвет скроллбара
                trackColor: WidgetStateProperty.all<Color>(Colors.grey.shade700), // Цвет трека
                radius: const Radius.circular(10), // Закругление для "большого пальца"
                thickness: WidgetStateProperty.all<double>(6.0), // Толщина скроллбара
              ),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: bash.output.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
                      child: RichText(
                        text: _buildColoredTextSpans(bash.output[index]),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        Container(
          color: Colors.black87,
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Text(
                "${bash.currentDirectory} \$ ",
                style: TextStyle(
                  color: Colors.green,
                  fontFamily: GoogleFonts.frankRuhlLibre().fontFamily,
                  fontSize: 14,
                ),
              ),
              Expanded(
                child: RawKeyboardListener(
                  focusNode: FocusNode(),
                  onKey: (RawKeyEvent event) {
                    if (event is RawKeyDownEvent) {
                      if (event.logicalKey == LogicalKeyboardKey.tab) {
                        _handleTabAutocomplete(bash);
                      }
                    }
                  },
                  child: TextField(
                    controller: _commandController,
                    focusNode: _focusNode, // Привязываем фокус к TextField
                    style: TextStyle(color: Colors.white, fontFamily: GoogleFonts.frankRuhlLibre().fontFamily),
                    cursorColor: Colors.white,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Введите команду...',
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                    onSubmitted: (command) {
                      if (command.isNotEmpty) {
                        bash.runCommand(command);
                        _commandController.clear();
                        _focusNode.requestFocus(); // Сохраняем фокус после отправки команды
                      }
                    },
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: () {
                  String command = _commandController.text.trim();
                  if (command.isNotEmpty) {
                    bash.runCommand(command);
                    _commandController.clear();
                    _focusNode.requestFocus(); // Сохраняем фокус после отправки команды
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleTabAutocomplete(BashTerminal bash) async {
    String command = _commandController.text;
    String newCommand = await bash.autoCompleteDirectory(command);
    setState(() {
      _commandController.text = newCommand;
      _commandController.selection = TextSelection.fromPosition(TextPosition(offset: newCommand.length));
    });

    // Восстанавливаем фокус после автодополнения
    _focusNode.requestFocus();
  }

  TextSpan _buildColoredTextSpans(String text) {
    List<TextSpan> spans = [];
    Color currentColor = Colors.white; // Цвет по умолчанию

    // Регулярное выражение для поиска преамбул
    final regex = RegExp(r'(drwxrwxr-x|drwxrwxrwt|srwx------|prwxrwxrwx|drwx------|-rw-------|-rw-rw-r--|-rw-r-----|drwxrwxrwx|drwxr--r--|drwxr-xr-x|lrwxrwxrwx)');
    final matches = regex.allMatches(text);

    int lastMatchEnd = 0;

    // Если находим преамбулу, используем её цвет до следующей
    for (var match in matches) {
      // Добавляем текст до преамбулы, с текущим цветом (если это первый блок, будет белым)
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: TextStyle(color: currentColor),
        ));
      }

      // Определяем текущую преамбулу
      String preamble = match.group(0) ?? '';
      currentColor = _getColorForPreamble(preamble); // Устанавливаем новый цвет

      // Добавляем преамбулу с её цветом
      spans.add(TextSpan(
        text: preamble,
        style: TextStyle(color: currentColor),
      ));

      lastMatchEnd = match.end; // Запоминаем конец текущего совпадения
    }

    // Добавляем остаток строки после последней преамбулы, с текущим цветом
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: TextStyle(color: currentColor), // Используем цвет последней найденной преамбулы
      ));
    }

    return TextSpan(children: spans);
  }

// Определение цвета для разных преамбул
  Color _getColorForPreamble(String preamble) {
    if (preamble.startsWith('drwxrwxr-x')) {
      return Colors.blue;
    } else if (preamble.startsWith('drwx------')) {
      return Colors.blue;
    } else if (preamble.startsWith('drwxr--r--')) {
      return Colors.blue;
    } else if (preamble.startsWith('drwxr-xr-x')) {
      return Colors.blue;
    } else if (preamble.startsWith('drwxrwxrwt')) {
      return Colors.green;
    } else if (preamble.startsWith('lrwxrwxrwx')) {
      return const Color.fromARGB(255, 53, 136, 56);
    } else if (preamble.startsWith('drwxrwxrwx')) {
      return Colors.green;
    } else if (preamble.startsWith('prwxrwxrwx')) {
      return Colors.orange;
    } else if (preamble.startsWith('srwx------')) {
      return Colors.purple;
    } else if (preamble.startsWith('-rw-------')) {
      return Colors.white;
    } else if (preamble.startsWith('-rw-rw-r--')) {
      return Colors.white;
    } else if (preamble.startsWith('-rw-r-----')) {
      return Colors.white;
    } else {
      return Colors.white; // По умолчанию
    }
  }
}
