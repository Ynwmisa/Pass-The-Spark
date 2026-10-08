import 'package:flutter/material.dart';

class BackendSetupScreen extends StatelessWidget {
  const BackendSetupScreen({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pass the Spark')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          Text(
            'Connect your project',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(message),
          const SizedBox(height: 16),
          const Text(
            'Run the app with your local Supabase configuration. See the repository setup instructions.',
          ),
        ],
      ),
    ),
  );
}
