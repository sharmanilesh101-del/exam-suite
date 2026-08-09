import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'duty_chart_screens.dart';
import 'remuneration_screens.dart';

void main() {
  runApp(const ExamSuiteApp());
}

class ExamSuiteApp extends StatefulWidget {
  const ExamSuiteApp({super.key});
  @override
  State<ExamSuiteApp> createState() => _ExamSuiteAppState();
}

class _ExamSuiteAppState extends State<ExamSuiteApp> {
  final AppState appState = AppState();
  bool loading = true;

  @override
  void initState() {
    super.initState();
    appState.load().then((_) => setState(() => loading = false));
  }

  @override
  Widget build(BuildContext context) {
    const ledgerGreen = Color(0xFF2F4A3C);
    const paper = Color(0xFFF6F3EC);
    return ChangeNotifierProvider.value(
      value: appState,
      child: MaterialApp(
        title: 'Exam Duty & Remuneration Suite',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: paper,
          colorScheme: ColorScheme.fromSeed(seedColor: ledgerGreen, primary: ledgerGreen),
          appBarTheme: const AppBarTheme(backgroundColor: ledgerGreen, foregroundColor: Colors.white),
          fontFamily: 'Georgia',
        ),
        home: loading ? const _Splash() : const RootShell(),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int module = 0; // 0 = duty chart, 1 = remuneration

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duty Chart & Remuneration'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Duty Chart'), icon: Icon(Icons.people_alt_outlined)),
                ButtonSegment(value: 1, label: Text('Remuneration'), icon: Icon(Icons.currency_rupee)),
              ],
              selected: {module},
              onSelectionChanged: (s) => setState(() => module = s.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected) ? Colors.white : Colors.white24,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _MetaHeader(appState: appState),
          const Divider(height: 1),
          Expanded(child: module == 0 ? const DutyChartHome() : const RemunerationHome()),
        ],
      ),
    );
  }
}

class _MetaHeader extends StatefulWidget {
  final AppState appState;
  const _MetaHeader({required this.appState});
  @override
  State<_MetaHeader> createState() => _MetaHeaderState();
}

class _MetaHeaderState extends State<_MetaHeader> {
  late final TextEditingController college = TextEditingController(text: widget.appState.college);
  late final TextEditingController dept = TextEditingController(text: widget.appState.dept);
  late final TextEditingController exam = TextEditingController(text: widget.appState.examTitle);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          SizedBox(
            width: 220,
            child: TextField(
              controller: college,
              decoration: const InputDecoration(labelText: 'College name', isDense: true, border: OutlineInputBorder()),
              onChanged: (v) { widget.appState.college = v; widget.appState.save(); },
            ),
          ),
          SizedBox(
            width: 220,
            child: TextField(
              controller: dept,
              decoration: const InputDecoration(labelText: 'Department', isDense: true, border: OutlineInputBorder()),
              onChanged: (v) { widget.appState.dept = v; widget.appState.save(); },
            ),
          ),
          SizedBox(
            width: 260,
            child: TextField(
              controller: exam,
              decoration: const InputDecoration(labelText: 'Exam title (e.g. Oct/Nov 2026 PR OR Exam)', isDense: true, border: OutlineInputBorder()),
              onChanged: (v) { widget.appState.examTitle = v; widget.appState.save(); },
            ),
          ),
        ],
      ),
    );
  }
}
