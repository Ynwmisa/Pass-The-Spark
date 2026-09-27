import 'package:flutter/material.dart';

void main() {
  runApp(const PassTheSparkApp());
}

class PassTheSparkApp extends StatelessWidget {
  const PassTheSparkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pass the Spark',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Pass the Spark'),
        ),
        body: const Center(
          child: Text('Project setup in progress'),
        ),
      ),
    );
  }
}
