import 'package:flutter/material.dart';

class LocalGroupsNotice extends StatelessWidget {
  const LocalGroupsNotice({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: 20),
    child: Text(
      'Local preview · Changes last until the app restarts. Nothing is shared.',
    ),
  );
}
