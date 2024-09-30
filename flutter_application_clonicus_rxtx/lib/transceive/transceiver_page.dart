import 'package:flutter/material.dart';

class TransceivePage extends StatelessWidget {
  const TransceivePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transceive'),
        centerTitle: true,
      ),
      body: const Center(child: Text('Transceive Page')),
    );
  }
}
