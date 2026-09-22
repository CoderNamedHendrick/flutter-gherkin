import 'package:flutter/material.dart';

Widget createApp() => const FixtureApp();

class FixtureApp extends StatefulWidget {
  const FixtureApp({super.key});
  @override
  State<FixtureApp> createState() => _FixtureAppState();
}

class _FixtureAppState extends State<FixtureApp> {
  bool submitted = false;
  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('Gherkin fixture')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const TextField(
              key: ValueKey<String>('name_field'),
              decoration: InputDecoration(labelText: 'Name'),
            ),
            const TextField(
              key: ValueKey<String>('password_field'),
              obscureText: true,
              decoration: InputDecoration(labelText: 'Password'),
            ),
            ElevatedButton(
              key: const ValueKey<String>('submit'),
              onPressed: () => setState(() => submitted = true),
              child: const Text('Submit'),
            ),
            if (submitted)
              const Text('Complete', key: ValueKey<String>('result')),
          ],
        ),
      ),
    ),
  );
}
