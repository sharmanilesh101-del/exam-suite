import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' as xls;
import 'models.dart';

const _storageKey = 'exam_suite_state_v1';
const creditLine = 'Designed and Copyright by Nilesh V. Sharma (SNJBCOE | AI&DS)';

/// Parses DD.MM.YYYY into a comparable DateTime, or null if malformed.
DateTime? parseDMY(String s) {
  final p = s.split('.');
  if (p.length != 3) return null;
  final d = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final y = int.tryParse(p[2]);
  if (d == null || m == null || y == null) return null;
  return DateTime(y, m, d);
}

class AppState extends ChangeNotifier {
  String college = '';
  String dept = '';
  String examTitle = '';

  // Duty chart
  List<DcStaff> dcStaff = [];
  List<DcSlot> dcSlots = [];
  DcResult? dcResult;

  // Remuneration
  Rates rates = Rates();
  StaffDirectory directory = StaffDirectory();
  List<Examiner> examiners = [];
  List<SupportEntry> support = [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      college = j['college'] ?? '';
      dept = j['dept'] ?? '';
      examTitle = j['examTitle'] ?? '';
      dcStaff = (j['dcStaff'] as List? ?? []).map((e) => DcStaff.fromJson(e)).toList();
      dcSlots = (j['dcSlots'] as List? ?? []).map((e) => DcSlot.fromJson(e)).toList();
      dcResult = j['dcResult'] != null ? DcResult.fromJson(j['dcResult']) : null;
      rates = j['rates'] != null ? Rates.fromJson(j['rates']) : Rates();
      directory = j['directory'] != null ? StaffDirectory.fromJson(j['directory']) : StaffDirectory();
      examiners = (j['examiners'] as List? ?? []).map((e) => Examiner.fromJson(e)).toList();
      support = (j['support'] as List? ?? []).map((e) => SupportEntry.fromJson(e)).toList();
    } catch (_) {
      // ignore corrupt state, start fresh
    }
    notifyListeners();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final j = {
      'college': college, 'dept': dept, 'examTitle': examTitle,
      'dcStaff': dcStaff.map((e) => e.toJson()).toList(),
      'dcSlots': dcSlots.map((e) => e.toJson()).toList(),
      'dcResult': dcResult?.toJson(),
      'rates': rates.toJson(),
      'directory': directory.toJson(),
      'examiners': examiners.map((e) => e.toJson()).toList(),
      'support': support.map((e) => e.toJson()).toList(),
    };
    await prefs.setString(_storageKey, jsonEncode(j));
    notifyListeners();
  }

  // ---------------- DUTY CHART: allocation ----------------

  void runGeneration() {
    if (dcStaff.isEmpty || dcSlots.isEmpty) return;
    for (final s in dcStaff) {
      s.regular = 0;
    }
    final sorted = [...dcSlots]..sort((a, b) {
        final da = parseDMY(a.date), db = parseDMY(b.date);
        if (da == null || db == null) return 0;
        return da.compareTo(db);
      });

    final assignedOnDate = <String, Set<String>>{};
    final assignments = <String, Map<String, List<String>>>{};
    final unresolved = <Map<String, dynamic>>[];

    for (final slot in sorted) {
      assignments[slot.id] = {};
      assignedOnDate.putIfAbsent(slot.date, () => <String>{});
      for (final role in kRoles) {
        final required = slot.req[role.key] ?? 0;
        if (required == 0) {
          assignments[slot.id]![role.key] = [];
          continue;
        }
        var eligible = dcStaff
            .where((s) =>
                s.roles.contains(role.key) &&
                !s.unavailable.contains(slot.date) &&
                !assignedOnDate[slot.date]!.contains(s.id))
            .toList();
        eligible.sort((a, b) => (a.regular + a.backlog).compareTo(b.regular + b.backlog));
        final chosen = eligible.take(required).toList();
        for (final s in chosen) {
          s.regular++;
          assignedOnDate[slot.date]!.add(s.id);
        }
        assignments[slot.id]![role.key] = chosen.map((s) => s.id).toList();
        if (chosen.length < required) {
          unresolved.add({
            'cls': slot.cls, 'date': slot.date, 'subject': slot.name,
            'role': role.label, 'missing': required - chosen.length,
          });
        }
      }
    }
    dcResult = DcResult(assignments: assignments, unresolved: unresolved);
    save();
  }

  String staffName(String id) {
    final s = dcStaff.where((x) => x.id == id);
    return s.isEmpty ? '—' : s.first.name;
  }

  /// Push today's generated assignments into Remuneration entries.
  int sendToRemuneration() {
    if (dcResult == null) return 0;
    var count = 0;
    for (final slot in dcSlots) {
      final a = dcResult!.assignments[slot.id] ?? {};
      for (final sid in a['examiner'] ?? []) {
        final st = dcStaff.where((x) => x.id == sid);
        if (st.isEmpty) continue;
        examiners.add(Examiner(
          id: newId(), name: st.first.name, category: 'Internal', subject: slot.name,
          cls: slot.cls, head: slot.head, students: slot.students,
          dateFrom: slot.date, dateTo: slot.date, days: 1, ta: 0,
        ));
        if (!directory.internal.contains(st.first.name)) directory.internal.add(st.first.name);
        count++;
      }
      for (final sid in a['expert'] ?? []) {
        final st = dcStaff.where((x) => x.id == sid);
        if (st.isEmpty) continue;
        examiners.add(Examiner(
          id: newId(), name: st.first.name, category: 'External', subject: slot.name,
          cls: slot.cls, head: slot.head, students: slot.students,
          dateFrom: slot.date, dateTo: slot.date, days: 1, ta: rates.ta,
        ));
        if (!directory.external.contains(st.first.name)) directory.external.add(st.first.name);
        count++;
      }
      final techNames = (a['tech'] ?? []).map((id) => staffName(id)).where((n) => n != '—').toList();
      final peonNames = (a['peon'] ?? []).map((id) => staffName(id)).where((n) => n != '—').toList();
      if (techNames.isNotEmpty || peonNames.isNotEmpty) {
        final size = slot.head == 'OR' ? rates.batchOR : rates.batchPR;
        final batches = slot.students > 0 ? (slot.students / size).ceil() : 0;
        support.add(SupportEntry(
          id: newId(), subject: slot.name, cls: slot.cls, head: slot.head,
          students: slot.students, batches: batches,
          expertNames: [], labNames: techNames, peonNames: peonNames,
        ));
        count++;
      }
    }
    save();
    return count;
  }

  // ---------------- REMUNERATION: derived ----------------

  List<MapEntry<String, double>> buildStaffTotals() {
    final totals = <String, double>{};
    void add(String name, double amt) {
      if (name.isEmpty) return;
      totals[name] = (totals[name] ?? 0) + amt;
    }

    for (final e in examiners) {
      add(e.name, e.calc(rates)['grandTotal']!);
    }
    for (final s in support) {
      final c = s.calc(rates);
      void splitAdd(List<String> names, double total) {
        if (names.isEmpty) return;
        final share = total / names.length;
        for (final n in names) {
          add(n, share);
        }
      }

      splitAdd(s.expertNames, c['expertTotal']!);
      splitAdd(s.labNames, c['labTotal']!);
      splitAdd(s.peonNames, c['peonTotal']!);
    }
    final list = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  // ---------------- EXPORT ----------------

  Future<File> _writeToDownloads(String filename, List<int> bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> exportBackupJson() async {
    final j = {
      'college': college, 'dept': dept, 'examTitle': examTitle,
      'dcStaff': dcStaff.map((e) => e.toJson()).toList(),
      'dcSlots': dcSlots.map((e) => e.toJson()).toList(),
      'dcResult': dcResult?.toJson(),
      'rates': rates.toJson(),
      'directory': directory.toJson(),
      'examiners': examiners.map((e) => e.toJson()).toList(),
      'support': support.map((e) => e.toJson()).toList(),
    };
    final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(j));
    final file = await _writeToDownloads('${_safeName(examTitle, 'exam_suite')}_backup.json', bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Exam suite backup');
  }

  Future<void> restoreBackupJson(String content) async {
    final j = jsonDecode(content) as Map<String, dynamic>;
    college = j['college'] ?? college;
    dept = j['dept'] ?? dept;
    examTitle = j['examTitle'] ?? examTitle;
    dcStaff = (j['dcStaff'] as List? ?? []).map((e) => DcStaff.fromJson(e)).toList();
    dcSlots = (j['dcSlots'] as List? ?? []).map((e) => DcSlot.fromJson(e)).toList();
    dcResult = j['dcResult'] != null ? DcResult.fromJson(j['dcResult']) : null;
    rates = j['rates'] != null ? Rates.fromJson(j['rates']) : rates;
    directory = j['directory'] != null ? StaffDirectory.fromJson(j['directory']) : directory;
    examiners = (j['examiners'] as List? ?? []).map((e) => Examiner.fromJson(e)).toList();
    support = (j['support'] as List? ?? []).map((e) => SupportEntry.fromJson(e)).toList();
    await save();
  }

  String _safeName(String s, String fallback) {
    final v = s.trim().isEmpty ? fallback : s.trim();
    return v.replaceAll(RegExp(r'\s+'), '_');
  }

  /// Duty chart Word export (HTML written with a .doc extension — Word opens this natively).
  Future<void> exportDutyChartWord() async {
    if (dcResult == null) return;
    final classes = ['SE', 'TE', 'BE'].where((c) => dcSlots.any((s) => s.cls == c));
    String cell(String slotId, String roleKey) {
      final ids = dcResult!.assignments[slotId]?[roleKey] ?? [];
      if (ids.isEmpty) return '&mdash;';
      return ids.map(staffName).join('<br>');
    }

    final credit = '<p style="text-align:right;font-size:10px;color:#666;">$creditLine</p>';
    final buffer = StringBuffer('<html><head><meta charset="utf-8"></head><body style="font-family:Calibri,Arial,sans-serif;font-size:13px;">');
    for (final cls in classes) {
      final slots = dcSlots.where((s) => s.cls == cls).toList()
        ..sort((a, b) {
          final da = parseDMY(a.date), db = parseDMY(b.date);
          if (da == null || db == null) return 0;
          return da.compareTo(db);
        });
      buffer.write('<div style="page-break-after:always;">$credit');
      buffer.write('<p><b>$college</b></p><p><b>Department: $dept</b></p>');
      buffer.write('<p><b>$cls ${examTitle.isEmpty ? "PR OR Exam" : examTitle} Duty Chart for Staff</b></p>');
      buffer.write('<table border="1" cellspacing="0" cellpadding="4" style="border-collapse:collapse;width:100%;">');
      buffer.write('<tr style="background:#dfe7e2;"><th>Sr No</th><th>Confirmed Date</th><th>Class</th><th>Subject</th><th>Head</th>'
          '<th>Tentative No of Students</th><th>Internal Examiner</th><th>Expert</th><th>Technical Assistant</th><th>Peon</th></tr>');
      for (var i = 0; i < slots.length; i++) {
        final s = slots[i];
        buffer.write('<tr><td>${i + 1}</td><td>${s.date}</td><td>${s.cls}</td>'
            '<td>${s.code.isNotEmpty ? "${s.code}: " : ""}${s.name}</td><td>${s.head}</td><td>${s.students}</td>'
            '<td>${cell(s.id, "examiner")}</td><td>${cell(s.id, "expert")}</td>'
            '<td>${cell(s.id, "tech")}</td><td>${cell(s.id, "peon")}</td></tr>');
      }
      buffer.write('</table></div>');
    }
    // Staff summary
    buffer.write('<div style="page-break-after:always;">$credit<p><b>Staff Duty Summary</b></p>');
    buffer.write('<table border="1" cellspacing="0" cellpadding="4" style="border-collapse:collapse;width:100%;">');
    buffer.write('<tr style="background:#dfe7e2;"><th>Name of Staff</th><th>Regular Duties</th><th>Backlog Duties</th><th>Sign of Staff</th></tr>');
    for (final s in dcStaff) {
      buffer.write('<tr><td>${s.name}</td><td>${s.regular}</td><td>${s.backlog}</td><td></td></tr>');
    }
    buffer.write('</table></div>');
    // Signature sheet
    buffer.write('<div>$credit<p><b>Signature Sheet</b></p>');
    buffer.write('<table border="1" cellspacing="0" cellpadding="4" style="border-collapse:collapse;width:100%;">');
    buffer.write('<tr style="background:#dfe7e2;"><th>Sr No</th><th>Name of Staff</th><th>Sign with Date</th></tr>');
    for (var i = 0; i < dcStaff.length; i++) {
      buffer.write('<tr><td>${i + 1}</td><td>${dcStaff[i].name}</td><td></td></tr>');
    }
    buffer.write('</table><br/><p>PR OR Exam Coordinator &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; Head of Department</p></div>');
    buffer.write('</body></html>');

    final bytes = utf8.encode(buffer.toString());
    final file = await _writeToDownloads('${_safeName(examTitle, "duty_chart")}.doc', bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Duty chart');
  }

  Future<void> exportDutyChartExcel() async {
    if (dcResult == null) return;
    final wb = xls.Excel.createExcel();
    for (final cls in ['SE', 'TE', 'BE']) {
      final slots = dcSlots.where((s) => s.cls == cls).toList()
        ..sort((a, b) {
          final da = parseDMY(a.date), db = parseDMY(b.date);
          if (da == null || db == null) return 0;
          return da.compareTo(db);
        });
      if (slots.isEmpty) continue;
      final sheet = wb[cls];
      sheet.appendRow(['Sr No', 'Date', 'Class', 'Subject', 'Head', 'Students', 'Internal Examiner', 'Expert', 'Technical Assistant', 'Peon']
          .map((e) => xls.TextCellValue(e)).toList());
      for (var i = 0; i < slots.length; i++) {
        final s = slots[i];
        String names(String roleKey) {
          final ids = dcResult!.assignments[s.id]?[roleKey] ?? [];
          return ids.map(staffName).join('; ');
        }

        sheet.appendRow([
          xls.IntCellValue(i + 1), xls.TextCellValue(s.date), xls.TextCellValue(s.cls),
          xls.TextCellValue('${s.code.isNotEmpty ? "${s.code}: " : ""}${s.name}'),
          xls.TextCellValue(s.head), xls.IntCellValue(s.students),
          xls.TextCellValue(names('examiner')), xls.TextCellValue(names('expert')),
          xls.TextCellValue(names('tech')), xls.TextCellValue(names('peon')),
        ]);
      }
    }
    final summary = wb['Summary'];
    summary.appendRow(['Name', 'Regular Duties', 'Backlog Duties', 'Total'].map((e) => xls.TextCellValue(e)).toList());
    for (final s in dcStaff) {
      summary.appendRow([
        xls.TextCellValue(s.name), xls.IntCellValue(s.regular), xls.IntCellValue(s.backlog),
        xls.IntCellValue(s.regular + s.backlog),
      ]);
    }
    wb.delete('Sheet1');
    final bytes = wb.encode()!;
    final file = await _writeToDownloads('${_safeName(examTitle, "duty_chart")}.xlsx', bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Duty chart (Excel)');
  }

  Future<void> exportRemunerationWord() async {
    final credit = '<p style="text-align:right;font-size:10px;color:#666;">$creditLine</p>';
    final buffer = StringBuffer('<html><head><meta charset="utf-8"></head><body style="font-family:Calibri,Arial,sans-serif;font-size:12px;">');

    // TA-DA (external only)
    double grand1 = 0;
    final tadaRows = StringBuffer();
    final externals = examiners.where((e) => e.category == 'External').toList();
    for (var i = 0; i < externals.length; i++) {
      final e = externals[i];
      final c = e.calc(rates);
      grand1 += c['tadaTotal']!;
      tadaRows.write('<tr><td>${i + 1}</td><td>${e.name}</td><td>${e.subject}</td><td>${e.cls}</td><td>${e.head}</td>'
          '<td>${e.students}</td><td>${e.fromPlace}</td><td>${e.mode}</td><td>${e.dateFrom}</td><td>${e.dateTo}</td>'
          '<td>${e.days}</td><td>${c['ta']}</td><td>${c['auto']}</td><td>${c['da']}</td><td>${c['tadaTotal']}</td></tr>');
    }
    buffer.write('<div style="page-break-after:always;">$credit<p><b>$college</b></p>'
        '<p><b>Statement showing TA/DA for Practical/Oral External Examiner</b></p><p>Department: $dept — $examTitle</p>'
        '<table border="1" cellspacing="0" cellpadding="4" style="border-collapse:collapse;width:100%;font-size:11px;">'
        '<tr style="background:#dfe7e2;"><th>Sr</th><th>Name</th><th>Subject</th><th>Class</th><th>Head</th><th>Students</th>'
        '<th>From place</th><th>Mode</th><th>From</th><th>To</th><th>Days</th><th>TA</th><th>Auto</th><th>DA</th><th>Total</th></tr>'
        '$tadaRows<tr><td colspan="13"><b>Total</b></td><td><b>$grand1</b></td></tr></table></div>');

    // Remuneration statements
    for (final category in ['External', 'Internal']) {
      double grand = 0;
      final rows = StringBuffer();
      final list = examiners.where((e) => e.category == category).toList();
      for (var i = 0; i < list.length; i++) {
        final e = list[i];
        final c = e.calc(rates);
        grand += c['remuneration']!;
        rows.write('<tr><td>${i + 1}</td><td>${e.name}</td><td>${e.subject}</td><td>${e.cls}</td><td>${e.dateFrom}</td>'
            '<td>${e.head}</td><td>${e.students}</td><td>${rates.remRate(e.head)}</td><td>${c['remuneration']}</td></tr>');
      }
      buffer.write('<div style="page-break-after:always;">$credit<p><b>$college</b></p>'
          '<p><b>Statement showing Remuneration — $category Examiners</b></p><p>Department: $dept — $examTitle</p>'
          '<table border="1" cellspacing="0" cellpadding="4" style="border-collapse:collapse;width:100%;font-size:11px;">'
          '<tr style="background:#dfe7e2;"><th>Sr</th><th>Name</th><th>Subject</th><th>Class</th><th>Date</th><th>Head</th>'
          '<th>Students</th><th>Rate</th><th>Remuneration</th></tr>'
          '$rows<tr><td colspan="8"><b>Total</b></td><td><b>$grand</b></td></tr></table></div>');
    }

    // Supporting staff
    double grand3 = 0;
    final spRows = StringBuffer();
    for (var i = 0; i < support.length; i++) {
      final s = support[i];
      final c = s.calc(rates);
      grand3 += c['total']!;
      spRows.write('<tr><td>${i + 1}</td><td>${s.cls}</td><td>${s.subject}</td><td>${s.head}</td><td>${s.students}</td>'
          '<td>${s.batches}</td><td>${s.expertNames.join(", ")}</td><td>${c['expertTotal']}</td>'
          '<td>${s.labNames.join(", ")}</td><td>${c['labTotal']}</td><td>${s.peonNames.join(", ")}</td><td>${c['peonTotal']}</td>'
          '<td>${c['total']}</td></tr>');
    }
    buffer.write('<div style="page-break-after:always;">$credit<p><b>$college</b></p>'
        '<p><b>Statement showing Staff used for Practical/Oral/Term Work Exam</b></p><p>Department: $dept — $examTitle</p>'
        '<table border="1" cellspacing="0" cellpadding="4" style="border-collapse:collapse;width:100%;font-size:10.5px;">'
        '<tr style="background:#dfe7e2;"><th>Sr</th><th>Class</th><th>Subject</th><th>Head</th><th>Students</th><th>Batches</th>'
        '<th>Expert Asst.</th><th>Amt</th><th>Lab Asst.</th><th>Amt</th><th>Peon</th><th>Amt</th><th>Total</th></tr>'
        '$spRows<tr><td colspan="12"><b>Total</b></td><td><b>$grand3</b></td></tr></table></div>');

    // Staff-wise total
    final totals = buildStaffTotals();
    final summaryRows = StringBuffer();
    double grandAll = 0;
    for (var i = 0; i < totals.length; i++) {
      grandAll += totals[i].value;
      summaryRows.write('<tr><td>${i + 1}</td><td>${totals[i].key}</td><td>${totals[i].value}</td><td></td></tr>');
    }
    buffer.write('<div>$credit<p><b>$college</b></p><p><b>Staff-wise Total Remuneration &amp; Signature</b></p>'
        '<p>Department: $dept — $examTitle</p>'
        '<table border="1" cellspacing="0" cellpadding="4" style="border-collapse:collapse;width:100%;">'
        '<tr style="background:#dfe7e2;"><th>Sr</th><th>Name of Staff</th><th>Total (Rs.)</th><th>Signature</th></tr>'
        '$summaryRows<tr><td colspan="2"><b>Grand Total</b></td><td><b>$grandAll</b></td><td></td></tr></table><br/>'
        '<p>Prepared By &nbsp;&nbsp;&nbsp;&nbsp; Exam Coordinator &nbsp;&nbsp;&nbsp;&nbsp; HOD &nbsp;&nbsp;&nbsp;&nbsp; Principal</p></div>');

    buffer.write('</body></html>');
    final bytes = utf8.encode(buffer.toString());
    final file = await _writeToDownloads('${_safeName(examTitle, "remuneration_statement")}.doc', bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Remuneration statement');
  }

  Future<void> exportRemunerationExcel() async {
    final wb = xls.Excel.createExcel();

    final tada = wb['TADA'];
    tada.appendRow(['Sr', 'Name', 'Subject', 'Class', 'Head', 'Students', 'From Place', 'Mode', 'From', 'To', 'Days', 'TA', 'Auto', 'DA', 'Total']
        .map((e) => xls.TextCellValue(e)).toList());
    final externals = examiners.where((e) => e.category == 'External').toList();
    for (var i = 0; i < externals.length; i++) {
      final e = externals[i];
      final c = e.calc(rates);
      tada.appendRow([
        xls.IntCellValue(i + 1), xls.TextCellValue(e.name), xls.TextCellValue(e.subject), xls.TextCellValue(e.cls),
        xls.TextCellValue(e.head), xls.IntCellValue(e.students), xls.TextCellValue(e.fromPlace), xls.TextCellValue(e.mode),
        xls.TextCellValue(e.dateFrom), xls.TextCellValue(e.dateTo), xls.IntCellValue(e.days),
        xls.DoubleCellValue(c['ta']!), xls.DoubleCellValue(c['auto']!), xls.DoubleCellValue(c['da']!), xls.DoubleCellValue(c['tadaTotal']!),
      ]);
    }

    for (final category in ['External', 'Internal']) {
      final sheet = wb[category];
      sheet.appendRow(['Sr', 'Name', 'Subject', 'Class', 'Date', 'Head', 'Students', 'Rate', 'Remuneration']
          .map((e) => xls.TextCellValue(e)).toList());
      final list = examiners.where((e) => e.category == category).toList();
      for (var i = 0; i < list.length; i++) {
        final e = list[i];
        final c = e.calc(rates);
        sheet.appendRow([
          xls.IntCellValue(i + 1), xls.TextCellValue(e.name), xls.TextCellValue(e.subject), xls.TextCellValue(e.cls),
          xls.TextCellValue(e.dateFrom), xls.TextCellValue(e.head), xls.IntCellValue(e.students),
          xls.DoubleCellValue(rates.remRate(e.head)), xls.DoubleCellValue(c['remuneration']!),
        ]);
      }
    }

    final sp = wb['Supporting'];
    sp.appendRow(['Class', 'Subject', 'Head', 'Students', 'Batches', 'Expert Asst.', 'Expert Amt', 'Lab Asst.', 'Lab Amt', 'Peon', 'Peon Amt', 'Total']
        .map((e) => xls.TextCellValue(e)).toList());
    for (final s in support) {
      final c = s.calc(rates);
      sp.appendRow([
        xls.TextCellValue(s.cls), xls.TextCellValue(s.subject), xls.TextCellValue(s.head), xls.IntCellValue(s.students),
        xls.IntCellValue(s.batches), xls.TextCellValue(s.expertNames.join('; ')), xls.DoubleCellValue(c['expertTotal']!),
        xls.TextCellValue(s.labNames.join('; ')), xls.DoubleCellValue(c['labTotal']!),
        xls.TextCellValue(s.peonNames.join('; ')), xls.DoubleCellValue(c['peonTotal']!), xls.DoubleCellValue(c['total']!),
      ]);
    }

    final totalSheet = wb['Total'];
    totalSheet.appendRow(['Name', 'Total'].map((e) => xls.TextCellValue(e)).toList());
    for (final t in buildStaffTotals()) {
      totalSheet.appendRow([xls.TextCellValue(t.key), xls.DoubleCellValue(t.value)]);
    }

    wb.delete('Sheet1');
    final bytes = wb.encode()!;
    final file = await _writeToDownloads('${_safeName(examTitle, "remuneration_statement")}.xlsx', bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Remuneration statement (Excel)');
  }
}
