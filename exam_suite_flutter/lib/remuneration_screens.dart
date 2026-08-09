import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'models.dart';
import 'widgets.dart';

class RemunerationHome extends StatefulWidget {
  const RemunerationHome({super.key});
  @override
  State<RemunerationHome> createState() => _RemunerationHomeState();
}

class _RemunerationHomeState extends State<RemunerationHome> with SingleTickerProviderStateMixin {
  late final TabController tab = TabController(length: 5, vsync: this);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: tab,
          isScrollable: true,
          labelColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'Rate Setup'), Tab(text: 'Directory'), Tab(text: 'Examiners'), Tab(text: 'Supporting Staff'), Tab(text: 'Summary & Export'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: tab,
            children: const [_RatesTab(), _DirectoryTab(), _ExaminersTab(), _SupportTab(), _SummaryTab()],
          ),
        ),
      ],
    );
  }
}

// ---------------- RATES TAB ----------------

class _RatesTab extends StatefulWidget {
  const _RatesTab();
  @override
  State<_RatesTab> createState() => _RatesTabState();
}

class _RatesTabState extends State<_RatesTab> {
  final Map<String, TextEditingController> ctrl = {};

  @override
  void initState() {
    super.initState();
    final r = context.read<AppState>().rates;
    ctrl['ta'] = TextEditingController(text: r.ta.toStringAsFixed(0));
    ctrl['auto'] = TextEditingController(text: r.auto.toStringAsFixed(0));
    ctrl['da'] = TextEditingController(text: r.da.toStringAsFixed(0));
    ctrl['pr'] = TextEditingController(text: r.pr.toStringAsFixed(0));
    ctrl['or'] = TextEditingController(text: r.or.toStringAsFixed(0));
    ctrl['tw'] = TextEditingController(text: r.tw.toStringAsFixed(0));
    ctrl['expert'] = TextEditingController(text: r.expert.toStringAsFixed(0));
    ctrl['lab'] = TextEditingController(text: r.lab.toStringAsFixed(0));
    ctrl['peon'] = TextEditingController(text: r.peon.toStringAsFixed(0));
    ctrl['batchPR'] = TextEditingController(text: '${r.batchPR}');
    ctrl['batchOR'] = TextEditingController(text: '${r.batchOR}');
  }

  Widget _field(String key, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: ctrl[key],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionCard(
          title: 'Rates (per current SPPU / college circular)',
          hint: 'Internal examiner remuneration is floored at Rs. 280. Batch size: 12 students/batch for PR, 20 for OR. Expert Assistant is not applicable for OR (auto-zeroed).',
          children: [
            _field('ta', 'Default TA (prefills new entries)'),
            _field('auto', 'Auto charges (flat)'),
            _field('da', 'DA per day'),
            _field('pr', 'Remuneration / student — PR'),
            _field('or', 'Remuneration / student — OR'),
            _field('tw', 'Remuneration / student — TW'),
            _field('expert', 'Expert Asst. / batch'),
            _field('lab', 'Lab/Tech Asst. / batch'),
            _field('peon', 'Peon / batch'),
            _field('batchPR', 'Batch size — PR (students/batch)'),
            _field('batchOR', 'Batch size — OR (students/batch)'),
            FilledButton(
              onPressed: () {
                app.rates = Rates(
                  ta: double.tryParse(ctrl['ta']!.text) ?? 210,
                  auto: double.tryParse(ctrl['auto']!.text) ?? 150,
                  da: double.tryParse(ctrl['da']!.text) ?? 130,
                  pr: double.tryParse(ctrl['pr']!.text) ?? 13,
                  or: double.tryParse(ctrl['or']!.text) ?? 11,
                  tw: double.tryParse(ctrl['tw']!.text) ?? 11,
                  expert: double.tryParse(ctrl['expert']!.text) ?? 440,
                  lab: double.tryParse(ctrl['lab']!.text) ?? 140,
                  peon: double.tryParse(ctrl['peon']!.text) ?? 103,
                  batchPR: int.tryParse(ctrl['batchPR']!.text) ?? 12,
                  batchOR: int.tryParse(ctrl['batchOR']!.text) ?? 20,
                );
                app.save();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rates saved.')));
              },
              child: const Text('Save rates'),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------- DIRECTORY TAB ----------------

class _DirectoryTab extends StatefulWidget {
  const _DirectoryTab();
  @override
  State<_DirectoryTab> createState() => _DirectoryTabState();
}

class _DirectoryTabState extends State<_DirectoryTab> {
  final internalName = TextEditingController();
  final externalName = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionCard(
          title: 'Internal examiners',
          hint: 'Populates the dropdown on Examiner Entries when Category is Internal.',
          children: [
            Row(children: [
              Expanded(child: TextField(controller: internalName, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  final n = internalName.text.trim();
                  if (n.isEmpty) return;
                  if (!app.directory.internal.contains(n)) app.directory.internal.add(n);
                  internalName.clear();
                  app.save();
                },
                child: const Text('Add'),
              ),
            ]),
            const SizedBox(height: 8),
            for (final n in app.directory.internal)
              ListTile(
                dense: true, title: Text(n),
                trailing: IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () { app.directory.internal.remove(n); app.save(); }),
              ),
            if (app.directory.internal.isEmpty) const EmptyNote('No names added yet.'),
          ],
        ),
        SectionCard(
          title: 'External examiners',
          hint: 'Populates the dropdown on Examiner Entries when Category is External.',
          children: [
            Row(children: [
              Expanded(child: TextField(controller: externalName, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  final n = externalName.text.trim();
                  if (n.isEmpty) return;
                  if (!app.directory.external.contains(n)) app.directory.external.add(n);
                  externalName.clear();
                  app.save();
                },
                child: const Text('Add'),
              ),
            ]),
            const SizedBox(height: 8),
            for (final n in app.directory.external)
              ListTile(
                dense: true, title: Text(n),
                trailing: IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () { app.directory.external.remove(n); app.save(); }),
              ),
            if (app.directory.external.isEmpty) const EmptyNote('No names added yet.'),
          ],
        ),
      ],
    );
  }
}

// ---------------- EXAMINERS TAB ----------------

class _ExaminersTab extends StatefulWidget {
  const _ExaminersTab();
  @override
  State<_ExaminersTab> createState() => _ExaminersTabState();
}

class _ExaminersTabState extends State<_ExaminersTab> {
  String category = 'External';
  String? name;
  final subject = TextEditingController();
  String cls = 'SE';
  String head = 'PR';
  final studentsC = TextEditingController(text: '0');
  final dateFrom = TextEditingController();
  final dateTo = TextEditingController();
  final days = TextEditingController(text: '1');
  final fromPlace = TextEditingController();
  final mode = TextEditingController();
  final ta = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final names = category == 'Internal' ? app.directory.internal : app.directory.external;
    if (name != null && !names.contains(name)) name = null;

    double grand = 0;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionCard(
          title: 'Add examiner entry',
          hint: 'TA varies per examiner (distance travelled) — enter it directly. Remuneration applies to both External and Internal.',
          children: [
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                value: category, decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: const [DropdownMenuItem(value: 'External', child: Text('External')), DropdownMenuItem(value: 'Internal', child: Text('Internal'))],
                onChanged: (v) => setState(() { category = v!; name = null; }),
              )),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<String>(
                value: name, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                items: names.map((n) => DropdownMenuItem(value: n, child: Text(n, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() => name = v),
                hint: names.isEmpty ? const Text('Add names in Directory') : const Text('Select'),
              )),
            ]),
            const SizedBox(height: 8),
            TextField(controller: subject, decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                value: cls, decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
                items: const [DropdownMenuItem(value: 'SE', child: Text('SE')), DropdownMenuItem(value: 'TE', child: Text('TE')), DropdownMenuItem(value: 'BE', child: Text('BE'))],
                onChanged: (v) => setState(() => cls = v!),
              )),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<String>(
                value: head, decoration: const InputDecoration(labelText: 'Head', border: OutlineInputBorder()),
                items: const [DropdownMenuItem(value: 'PR', child: Text('PR')), DropdownMenuItem(value: 'OR', child: Text('OR')), DropdownMenuItem(value: 'TW', child: Text('TW'))],
                onChanged: (v) => setState(() => head = v!),
              )),
            ]),
            const SizedBox(height: 8),
            TextField(controller: studentsC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'No. of students', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: dateFrom, decoration: const InputDecoration(labelText: 'Date from', border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: dateTo, decoration: const InputDecoration(labelText: 'Date to', border: OutlineInputBorder()))),
            ]),
            const SizedBox(height: 8),
            TextField(controller: days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Days', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: fromPlace, decoration: const InputDecoration(labelText: 'From place (external)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: mode, decoration: const InputDecoration(labelText: 'Mode of journey', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: ta, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'TA amount (default ${app.rates.ta.toStringAsFixed(0)})', border: const OutlineInputBorder())),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () {
                if (name == null) return;
                app.examiners.add(Examiner(
                  id: newId(), name: name!, category: category, subject: subject.text.trim(), cls: cls, head: head,
                  students: int.tryParse(studentsC.text) ?? 0, dateFrom: dateFrom.text.trim(), dateTo: dateTo.text.trim(),
                  days: int.tryParse(days.text) ?? 1, fromPlace: fromPlace.text.trim(), mode: mode.text.trim(),
                  ta: ta.text.trim().isEmpty ? app.rates.ta : (double.tryParse(ta.text) ?? app.rates.ta),
                ));
                subject.clear(); studentsC.text = '0'; dateFrom.clear(); dateTo.clear(); fromPlace.clear(); ta.clear();
                app.save();
              },
              child: const Text('Add entry'),
            ),
          ],
        ),
        SectionCard(
          title: 'Examiner entries (${app.examiners.length})',
          children: [
            for (final e in app.examiners)
              Builder(builder: (_) {
                final c = e.calc(app.rates);
                grand += c['grandTotal']!;
                return Card(
                  child: ListTile(
                    title: Text('${e.name} · ${e.category}'),
                    subtitle: Text('${e.cls} · ${e.subject} · ${e.head} · ${e.students} students\n'
                        'TA ₹${c["ta"]!.toStringAsFixed(0)} + Auto ₹${c["auto"]!.toStringAsFixed(0)} + DA ₹${c["da"]!.toStringAsFixed(0)} + Rem ₹${c["remuneration"]!.toStringAsFixed(0)} = ₹${c["grandTotal"]!.toStringAsFixed(0)}'),
                    isThreeLine: true,
                    trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () { app.examiners.removeWhere((x) => x.id == e.id); app.save(); }),
                  ),
                );
              }),
            if (app.examiners.isEmpty) const EmptyNote('No examiner entries yet.'),
            if (app.examiners.isNotEmpty) Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Grand total: ₹${grand.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------- SUPPORT TAB ----------------

class _SupportTab extends StatefulWidget {
  const _SupportTab();
  @override
  State<_SupportTab> createState() => _SupportTabState();
}

class _SupportTabState extends State<_SupportTab> {
  final subject = TextEditingController();
  String cls = 'SE';
  String head = 'PR';
  final studentsC = TextEditingController(text: '0');
  final batchesC = TextEditingController(text: '1');
  final expertNames = TextEditingController();
  final labNames = TextEditingController();
  final peonNames = TextEditingController();

  void _recomputeBatches(AppState app) {
    final students = int.tryParse(studentsC.text) ?? 0;
    final size = head == 'OR' ? app.rates.batchOR : app.rates.batchPR;
    batchesC.text = students > 0 ? (students / size).ceil().toString() : '0';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final orSelected = head == 'OR';
    double grand = 0;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionCard(
          title: 'Add supporting-staff entry',
          hint: 'Batches auto-suggest from students/head (12/batch PR, 20/batch OR) — still editable. Expert Assistant is disabled for OR.',
          children: [
            TextField(controller: subject, decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                value: cls, decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
                items: const [DropdownMenuItem(value: 'SE', child: Text('SE')), DropdownMenuItem(value: 'TE', child: Text('TE')), DropdownMenuItem(value: 'BE', child: Text('BE'))],
                onChanged: (v) => setState(() => cls = v!),
              )),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<String>(
                value: head, decoration: const InputDecoration(labelText: 'Head', border: OutlineInputBorder()),
                items: const [DropdownMenuItem(value: 'PR', child: Text('PR')), DropdownMenuItem(value: 'OR', child: Text('OR')), DropdownMenuItem(value: 'TW', child: Text('TW'))],
                onChanged: (v) => setState(() { head = v!; _recomputeBatches(app); if (orSelected) expertNames.clear(); }),
              )),
            ]),
            const SizedBox(height: 8),
            TextField(controller: studentsC, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'No. of students', border: OutlineInputBorder()),
                onChanged: (_) => setState(() => _recomputeBatches(app))),
            const SizedBox(height: 8),
            TextField(controller: batchesC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'No. of batches', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
              controller: expertNames, enabled: !orSelected,
              decoration: InputDecoration(labelText: 'Expert Assistant name(s)', hintText: orSelected ? 'Not applicable for OR' : 'Prof. A, Prof. B', border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(controller: labNames, decoration: const InputDecoration(labelText: 'Lab/Tech Assistant name(s)', hintText: 'Mr. C, Ms. D', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: peonNames, decoration: const InputDecoration(labelText: 'Peon name(s)', hintText: 'Mr. E', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () {
                if (subject.text.trim().isEmpty) return;
                List<String> split(String s) => s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                app.support.add(SupportEntry(
                  id: newId(), subject: subject.text.trim(), cls: cls, head: head,
                  students: int.tryParse(studentsC.text) ?? 0, batches: int.tryParse(batchesC.text) ?? 0,
                  expertNames: orSelected ? [] : split(expertNames.text),
                  labNames: split(labNames.text), peonNames: split(peonNames.text),
                ));
                subject.clear(); studentsC.text = '0'; batchesC.text = '1'; expertNames.clear(); labNames.clear(); peonNames.clear();
                app.save();
              },
              child: const Text('Add entry'),
            ),
          ],
        ),
        SectionCard(
          title: 'Supporting-staff entries (${app.support.length})',
          children: [
            for (final s in app.support)
              Builder(builder: (_) {
                final c = s.calc(app.rates);
                grand += c['total']!;
                return Card(
                  child: ListTile(
                    title: Text('${s.cls} · ${s.subject} · ${s.head} · ${s.batches} batches'),
                    subtitle: Text('Expert: ${s.expertNames.join(", ")} (₹${c["expertTotal"]!.toStringAsFixed(0)})\n'
                        'Lab: ${s.labNames.join(", ")} (₹${c["labTotal"]!.toStringAsFixed(0)})\n'
                        'Peon: ${s.peonNames.join(", ")} (₹${c["peonTotal"]!.toStringAsFixed(0)}) · Total ₹${c["total"]!.toStringAsFixed(0)}'),
                    isThreeLine: true,
                    trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () { app.support.removeWhere((x) => x.id == s.id); app.save(); }),
                  ),
                );
              }),
            if (app.support.isEmpty) const EmptyNote('No supporting-staff entries yet.'),
            if (app.support.isNotEmpty) Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Grand total: ₹${grand.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------- SUMMARY TAB ----------------

class _SummaryTab extends StatelessWidget {
  const _SummaryTab();
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final totals = app.buildStaffTotals();
    final grand = totals.fold(0.0, (s, t) => s + t.value);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionCard(
          title: 'Staff-wise total',
          hint: 'Adds up every examiner and supporting-staff amount per named person.',
          children: [
            for (final t in totals)
              ListTile(dense: true, title: Text(t.key), trailing: Text('₹${t.value.toStringAsFixed(0)}')),
            if (totals.isEmpty) const EmptyNote('No entries yet.'),
            if (totals.isNotEmpty) Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Grand total: ₹${grand.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        SectionCard(
          title: 'Local backup',
          hint: 'Everything (both modules) saves automatically. Use this to also keep a copy on your device, or move data between phones.',
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(onPressed: () => app.exportBackupJson(), child: const Text('Share backup (.json)')),
              OutlinedButton(
                onPressed: () async {
                  final controller = TextEditingController();
                  final content = await showDialog<String>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Restore from backup'),
                      content: TextField(controller: controller, maxLines: 6, decoration: const InputDecoration(hintText: 'Paste backup JSON here')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Restore')),
                      ],
                    ),
                  );
                  if (content != null && content.trim().isNotEmpty) {
                    try {
                      jsonDecode(content); // validate
                      await app.restoreBackupJson(content);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup restored.')));
                    } catch (_) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That did not look like valid backup JSON.')));
                    }
                  }
                },
                child: const Text('Restore from pasted JSON'),
              ),
            ]),
          ],
        ),
        SectionCard(
          title: 'Export',
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton(onPressed: () => app.exportRemunerationWord(), child: const Text('Export Word (.doc)')),
              OutlinedButton(onPressed: () => app.exportRemunerationExcel(), child: const Text('Export Excel (.xlsx)')),
            ]),
          ],
        ),
      ],
    );
  }
}
