import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'models.dart';
import 'widgets.dart';

class DutyChartHome extends StatefulWidget {
  const DutyChartHome({super.key});
  @override
  State<DutyChartHome> createState() => _DutyChartHomeState();
}

class _DutyChartHomeState extends State<DutyChartHome> with SingleTickerProviderStateMixin {
  late final TabController tab = TabController(length: 4, vsync: this);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: tab,
          labelColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'Staff'), Tab(text: 'Exam Slots'), Tab(text: 'Generate'), Tab(text: 'Summary & Export'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: tab,
            children: const [_StaffTab(), _SlotsTab(), _GenerateTab(), _ExportTab()],
          ),
        ),
      ],
    );
  }
}

// ---------------- STAFF TAB ----------------

class _StaffTab extends StatefulWidget {
  const _StaffTab();
  @override
  State<_StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<_StaffTab> {
  final name = TextEditingController();
  final backlog = TextEditingController(text: '0');
  final unavailable = TextEditingController();
  String category = 'teaching';
  Set<String> roles = {'examiner', 'expert'};

  void _syncDefaultRoles(String cat) {
    setState(() {
      category = cat;
      roles = kRoles.where((r) => r.category == cat).map((r) => r.key).toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionCard(
          title: 'Add staff',
          hint: 'Teaching staff can hold Internal Examiner / Expert duties. Technical & support staff hold Technical Assistant / Peon duties.',
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'teaching', child: Text('Teaching staff')),
                DropdownMenuItem(value: 'technical', child: Text('Technical / support staff')),
              ],
              onChanged: (v) => _syncDefaultRoles(v!),
            ),
            const SizedBox(height: 8),
            TextField(controller: backlog, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Backlog duties (carried over)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: unavailable,
                decoration: const InputDecoration(labelText: 'Unavailable dates (comma-separated, DD.MM.YYYY)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: kRoles.map((r) => FilterChip(
                label: Text(r.label),
                selected: roles.contains(r.key),
                onSelected: (sel) => setState(() => sel ? roles.add(r.key) : roles.remove(r.key)),
              )).toList(),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                app.dcStaff.add(DcStaff(
                  id: newId(), name: name.text.trim(), category: category,
                  backlog: int.tryParse(backlog.text) ?? 0,
                  unavailable: unavailable.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                  roles: roles.toList(),
                ));
                name.clear(); backlog.text = '0'; unavailable.clear();
                app.save();
              },
              child: const Text('Add staff member'),
            ),
          ],
        ),
        SectionCard(
          title: 'Staff list (${app.dcStaff.length})',
          children: [
            for (final s in app.dcStaff)
              Card(
                child: ListTile(
                  title: Text(s.name),
                  subtitle: Text('${s.category} · roles: ${s.roles.map((k) => kRoles.firstWhere((r) => r.key == k).label).join(", ")}\n'
                      'backlog: ${s.backlog} · unavailable: ${s.unavailable.isEmpty ? "—" : s.unavailable.join(", ")}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () { app.dcStaff.removeWhere((x) => x.id == s.id); app.save(); },
                  ),
                ),
              ),
            if (app.dcStaff.isEmpty) const EmptyNote('No staff added yet.'),
          ],
        ),
      ],
    );
  }
}

// ---------------- SLOTS TAB ----------------

class _SlotsTab extends StatefulWidget {
  const _SlotsTab();
  @override
  State<_SlotsTab> createState() => _SlotsTabState();
}

class _SlotsTabState extends State<_SlotsTab> {
  String cls = 'SE';
  final date = TextEditingController();
  final code = TextEditingController();
  final subjectName = TextEditingController();
  String head = 'PR';
  final students = TextEditingController();
  final reqExaminer = TextEditingController(text: '1');
  final reqExpert = TextEditingController(text: '1');
  final reqTech = TextEditingController(text: '1');
  final reqPeon = TextEditingController(text: '1');

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionCard(
          title: 'Add exam slot',
          hint: 'One slot = one row of the final chart.',
          children: [
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                value: cls, decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
                items: const [DropdownMenuItem(value: 'SE', child: Text('SE')), DropdownMenuItem(value: 'TE', child: Text('TE')), DropdownMenuItem(value: 'BE', child: Text('BE'))],
                onChanged: (v) => setState(() => cls = v!),
              )),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<String>(
                value: head, decoration: const InputDecoration(labelText: 'Head', border: OutlineInputBorder()),
                items: const [DropdownMenuItem(value: 'PR', child: Text('PR')), DropdownMenuItem(value: 'OR', child: Text('OR'))],
                onChanged: (v) => setState(() => head = v!),
              )),
            ]),
            const SizedBox(height: 8),
            TextField(controller: date, decoration: const InputDecoration(labelText: 'Confirmed date (DD.MM.YYYY)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: code, decoration: const InputDecoration(labelText: 'Subject code', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: subjectName, decoration: const InputDecoration(labelText: 'Subject name', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: students, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Tentative students', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            const Text('How many people each role needs for this slot:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: TextField(controller: reqExaminer, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Internal Examiners', border: OutlineInputBorder()))),
              const SizedBox(width: 6),
              Expanded(child: TextField(controller: reqExpert, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Experts', border: OutlineInputBorder()))),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: TextField(controller: reqTech, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Technical Assts.', border: OutlineInputBorder()))),
              const SizedBox(width: 6),
              Expanded(child: TextField(controller: reqPeon, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Peons', border: OutlineInputBorder()))),
            ]),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () {
                if (date.text.trim().isEmpty || subjectName.text.trim().isEmpty) return;
                app.dcSlots.add(DcSlot(
                  id: newId(), cls: cls, date: date.text.trim(), code: code.text.trim(),
                  name: subjectName.text.trim(), head: head, students: int.tryParse(students.text) ?? 0,
                  req: {
                    'examiner': int.tryParse(reqExaminer.text) ?? 0,
                    'expert': int.tryParse(reqExpert.text) ?? 0,
                    'tech': int.tryParse(reqTech.text) ?? 0,
                    'peon': int.tryParse(reqPeon.text) ?? 0,
                  },
                ));
                date.clear(); code.clear(); subjectName.clear(); students.clear();
                app.save();
              },
              child: const Text('Add slot'),
            ),
          ],
        ),
        SectionCard(
          title: 'Exam slots (${app.dcSlots.length})',
          children: [
            for (final s in app.dcSlots)
              Card(
                child: ListTile(
                  title: Text('${s.cls} · ${s.date} · ${s.code.isNotEmpty ? "${s.code}: " : ""}${s.name}'),
                  subtitle: Text('${s.head} · ${s.students} students · IE ${s.req["examiner"]} / EX ${s.req["expert"]} / TA ${s.req["tech"]} / PE ${s.req["peon"]}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () { app.dcSlots.removeWhere((x) => x.id == s.id); app.save(); },
                  ),
                ),
              ),
            if (app.dcSlots.isEmpty) const EmptyNote('No exam slots added yet.'),
          ],
        ),
      ],
    );
  }
}

// ---------------- GENERATE TAB ----------------

class _GenerateTab extends StatelessWidget {
  const _GenerateTab();
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final result = app.dcResult;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionCard(
          title: 'Generate duty chart',
          hint: 'Assigns the least-loaded eligible staff to each role, skips anyone unavailable that date, and never double-books a person on the same date.',
          children: [
            FilledButton(
              onPressed: (app.dcStaff.isEmpty || app.dcSlots.isEmpty) ? null : () => app.runGeneration(),
              child: const Text('Generate chart'),
            ),
          ],
        ),
        if (result != null && result.unresolved.isNotEmpty)
          Card(
            color: const Color(0xFFFBEEEB),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '${result.unresolved.length} slot-role(s) short-staffed:\n' +
                    result.unresolved.map((u) => '${u["cls"]} · ${u["date"]} · ${u["subject"]} — needs ${u["missing"]} more ${u["role"]}').join('\n'),
                style: const TextStyle(color: Color(0xFF9C3B2E)),
              ),
            ),
          ),
        if (result != null)
          for (final cls in ['SE', 'TE', 'BE'].where((c) => app.dcSlots.any((s) => s.cls == c)))
            _ClassChartCard(cls: cls, app: app),
      ],
    );
  }
}

class _ClassChartCard extends StatelessWidget {
  final String cls;
  final AppState app;
  const _ClassChartCard({required this.cls, required this.app});

  @override
  Widget build(BuildContext context) {
    final slots = app.dcSlots.where((s) => s.cls == cls).toList()
      ..sort((a, b) {
        final da = parseDMY(a.date), db = parseDMY(b.date);
        if (da == null || db == null) return 0;
        return da.compareTo(db);
      });
    String cell(String slotId, String roleKey) {
      final ids = app.dcResult!.assignments[slotId]?[roleKey] ?? [];
      return ids.isEmpty ? '—' : ids.map(app.staffName).join(', ');
    }

    return SectionCard(
      title: '$cls — ${app.examTitle.isEmpty ? "PR OR Exam" : app.examTitle} Duty Chart',
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Date')), DataColumn(label: Text('Subject')), DataColumn(label: Text('Head')),
              DataColumn(label: Text('Students')), DataColumn(label: Text('Int. Examiner')), DataColumn(label: Text('Expert')),
              DataColumn(label: Text('Tech. Asst.')), DataColumn(label: Text('Peon')),
            ],
            rows: [
              for (final s in slots)
                DataRow(cells: [
                  DataCell(Text(s.date)), DataCell(Text(s.name)), DataCell(Text(s.head)), DataCell(Text('${s.students}')),
                  DataCell(Text(cell(s.id, 'examiner'))), DataCell(Text(cell(s.id, 'expert'))),
                  DataCell(Text(cell(s.id, 'tech'))), DataCell(Text(cell(s.id, 'peon'))),
                ]),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------- EXPORT TAB ----------------

class _ExportTab extends StatelessWidget {
  const _ExportTab();
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionCard(
          title: 'Duty tally',
          children: [
            for (final s in [...app.dcStaff]..sort((a, b) => (b.regular + b.backlog).compareTo(a.regular + a.backlog)))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(width: 140, child: Text(s.name, overflow: TextOverflow.ellipsis)),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (s.regular + s.backlog) == 0 ? 0 : (s.regular + s.backlog) / (app.dcStaff.map((x) => x.regular + x.backlog).fold(1, (a, b) => a > b ? a : b)),
                      color: s.category == 'technical' ? const Color(0xFFA9822F) : const Color(0xFF2F4A3C),
                      backgroundColor: const Color(0xFFEEE7D8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${s.regular}+${s.backlog}=${s.regular + s.backlog}'),
                ]),
              ),
            if (app.dcStaff.isEmpty) const EmptyNote('No staff to show.'),
          ],
        ),
        SectionCard(
          title: 'Send to Remuneration',
          hint: 'Turns generated assignments into Remuneration entries: Internal Examiner → Internal examiner entries, Expert → External examiner entries, Technical Assistant + Peon → Supporting Staff entries.',
          children: [
            OutlinedButton(
              onPressed: app.dcResult == null ? null : () {
                final count = app.sendToRemuneration();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sent $count entries to Remuneration. Switch tabs above to review.')),
                );
              },
              child: const Text('Send assignments to Remuneration →'),
            ),
          ],
        ),
        SectionCard(
          title: 'Export',
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton(onPressed: app.dcResult == null ? null : () => app.exportDutyChartWord(), child: const Text('Export Word (.doc)')),
              OutlinedButton(onPressed: app.dcResult == null ? null : () => app.exportDutyChartExcel(), child: const Text('Export Excel (.xlsx)')),
            ]),
          ],
        ),
      ],
    );
  }
}
