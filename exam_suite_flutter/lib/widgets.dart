import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final String? hint;
  final List<Widget> children;
  const SectionCard({super.key, required this.title, this.hint, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1C2F26))),
            if (hint != null) Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 10),
              child: Text(hint!, style: const TextStyle(fontSize: 11.5, color: Color(0xFF4A5750))),
            ) else const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class EmptyNote extends StatelessWidget {
  final String text;
  const EmptyNote(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(text, style: const TextStyle(color: Color(0xFF4A5750), fontStyle: FontStyle.italic)),
  );
}
