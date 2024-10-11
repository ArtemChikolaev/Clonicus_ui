import 'package:flutter/material.dart';

class BashTerminalPage extends StatelessWidget {
  const BashTerminalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bash terminal'),
        centerTitle: true,
      ),
      body: const Center(child: Text('Bash terminal Page')),
    );
  }
}