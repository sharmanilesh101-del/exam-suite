import 'package:uuid/uuid.dart';

const _uuid = Uuid();
String newId() => _uuid.v4().substring(0, 8);

/// Roles used by the Duty Chart module.
class RoleDef {
  final String key;
  final String label;
  final String category; // 'teaching' | 'technical'
  const RoleDef(this.key, this.label, this.category);
}

const List<RoleDef> kRoles = [
  RoleDef('examiner', 'Internal Examiner', 'teaching'),
  RoleDef('expert', 'Expert', 'teaching'),
  RoleDef('tech', 'Technical Assistant', 'technical'),
  RoleDef('peon', 'Peon', 'technical'),
];

// ---------------- DUTY CHART MODULE ----------------

class DcStaff {
  String id;
  String name;
  String category; // teaching | technical
  int backlog;
  List<String> unavailable; // DD.MM.YYYY strings
  List<String> roles; // role keys
  int regular;

  DcStaff({
    required this.id,
    required this.name,
    required this.category,
    this.backlog = 0,
    List<String>? unavailable,
    List<String>? roles,
    this.regular = 0,
  })  : unavailable = unavailable ?? [],
        roles = roles ?? [];

  factory DcStaff.fromJson(Map<String, dynamic> j) => DcStaff(
        id: j['id'],
        name: j['name'],
        category: j['category'],
        backlog: j['backlog'] ?? 0,
        unavailable: List<String>.from(j['unavailable'] ?? []),
        roles: List<String>.from(j['roles'] ?? []),
        regular: j['regular'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'backlog': backlog,
        'unavailable': unavailable,
        'roles': roles,
        'regular': regular,
      };
}

class DcSlot {
  String id;
  String cls; // SE/TE/BE
  String date; // DD.MM.YYYY
  String code;
  String name;
  String head; // PR/OR
  int students;
  Map<String, int> req; // roleKey -> count needed

  DcSlot({
    required this.id,
    required this.cls,
    required this.date,
    this.code = '',
    required this.name,
    required this.head,
    this.students = 0,
    Map<String, int>? req,
  }) : req = req ?? {'examiner': 1, 'expert': 1, 'tech': 1, 'peon': 1};

  factory DcSlot.fromJson(Map<String, dynamic> j) => DcSlot(
        id: j['id'],
        cls: j['cls'],
        date: j['date'],
        code: j['code'] ?? '',
        name: j['name'],
        head: j['head'],
        students: j['students'] ?? 0,
        req: Map<String, int>.from(j['req'] ?? {}),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'cls': cls,
        'date': date,
        'code': code,
        'name': name,
        'head': head,
        'students': students,
        'req': req,
      };
}

class DcResult {
  Map<String, Map<String, List<String>>> assignments; // slotId -> roleKey -> [staffId]
  List<Map<String, dynamic>> unresolved;

  DcResult({required this.assignments, required this.unresolved});

  factory DcResult.fromJson(Map<String, dynamic> j) {
    final assignments = <String, Map<String, List<String>>>{};
    (j['assignments'] as Map<String, dynamic>? ?? {}).forEach((slotId, roles) {
      final roleMap = <String, List<String>>{};
      (roles as Map<String, dynamic>).forEach((roleKey, ids) {
        roleMap[roleKey] = List<String>.from(ids);
      });
      assignments[slotId] = roleMap;
    });
    return DcResult(
      assignments: assignments,
      unresolved: List<Map<String, dynamic>>.from(j['unresolved'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'assignments': assignments.map((k, v) => MapEntry(k, v)),
        'unresolved': unresolved,
      };
}

// ---------------- REMUNERATION MODULE ----------------

class Rates {
  double ta, auto, da, pr, or, tw, expert, lab, peon;
  int batchPR, batchOR;
  Rates({
    this.ta = 210,
    this.auto = 150,
    this.da = 130,
    this.pr = 13,
    this.or = 11,
    this.tw = 11,
    this.expert = 440,
    this.lab = 140,
    this.peon = 103,
    this.batchPR = 12,
    this.batchOR = 20,
  });

  factory Rates.fromJson(Map<String, dynamic> j) => Rates(
        ta: (j['ta'] ?? 210).toDouble(),
        auto: (j['auto'] ?? 150).toDouble(),
        da: (j['da'] ?? 130).toDouble(),
        pr: (j['pr'] ?? 13).toDouble(),
        or: (j['or'] ?? 11).toDouble(),
        tw: (j['tw'] ?? 11).toDouble(),
        expert: (j['expert'] ?? 440).toDouble(),
        lab: (j['lab'] ?? 140).toDouble(),
        peon: (j['peon'] ?? 103).toDouble(),
        batchPR: j['batchPR'] ?? 12,
        batchOR: j['batchOR'] ?? 20,
      );

  Map<String, dynamic> toJson() => {
        'ta': ta, 'auto': auto, 'da': da, 'pr': pr, 'or': or, 'tw': tw,
        'expert': expert, 'lab': lab, 'peon': peon,
        'batchPR': batchPR, 'batchOR': batchOR,
      };

  double remRate(String head) {
    switch (head.toUpperCase()) {
      case 'PR': return pr;
      case 'OR': return or;
      default: return tw;
    }
  }
}

class Examiner {
  String id;
  String name;
  String category; // External | Internal
  String subject;
  String cls;
  String head; // PR/OR/TW
  int students;
  String dateFrom, dateTo;
  int days;
  String fromPlace, mode;
  double ta;

  Examiner({
    required this.id, required this.name, required this.category,
    required this.subject, required this.cls, required this.head,
    this.students = 0, this.dateFrom = '', this.dateTo = '', this.days = 1,
    this.fromPlace = '', this.mode = '', this.ta = 0,
  });

  factory Examiner.fromJson(Map<String, dynamic> j) => Examiner(
        id: j['id'], name: j['name'], category: j['category'], subject: j['subject'],
        cls: j['cls'], head: j['head'], students: j['students'] ?? 0,
        dateFrom: j['dateFrom'] ?? '', dateTo: j['dateTo'] ?? '', days: j['days'] ?? 1,
        fromPlace: j['fromPlace'] ?? '', mode: j['mode'] ?? '', ta: (j['ta'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'category': category, 'subject': subject, 'cls': cls,
        'head': head, 'students': students, 'dateFrom': dateFrom, 'dateTo': dateTo,
        'days': days, 'fromPlace': fromPlace, 'mode': mode, 'ta': ta,
      };

  /// Returns (ta, auto, da, tadaTotal, remuneration, grandTotal)
  Map<String, double> calc(Rates rates) {
    double rem = rates.remRate(head) * students;
    if (category == 'Internal' && rem < 280) rem = 280;
    final isExternal = category == 'External';
    final taAmt = isExternal ? ta : 0.0;
    final autoAmt = isExternal ? rates.auto : 0.0;
    final daAmt = isExternal ? rates.da * days : 0.0;
    final tadaTotal = taAmt + autoAmt + daAmt;
    final grandTotal = tadaTotal + rem;
    return {
      'ta': taAmt, 'auto': autoAmt, 'da': daAmt,
      'tadaTotal': tadaTotal, 'remuneration': rem, 'grandTotal': grandTotal,
    };
  }
}

class SupportEntry {
  String id;
  String subject, cls, head;
  int students, batches;
  List<String> expertNames, labNames, peonNames;

  SupportEntry({
    required this.id, required this.subject, required this.cls, required this.head,
    this.students = 0, this.batches = 0,
    List<String>? expertNames, List<String>? labNames, List<String>? peonNames,
  })  : expertNames = expertNames ?? [],
        labNames = labNames ?? [],
        peonNames = peonNames ?? [];

  factory SupportEntry.fromJson(Map<String, dynamic> j) => SupportEntry(
        id: j['id'], subject: j['subject'], cls: j['cls'], head: j['head'],
        students: j['students'] ?? 0, batches: j['batches'] ?? 0,
        expertNames: List<String>.from(j['expertNames'] ?? []),
        labNames: List<String>.from(j['labNames'] ?? []),
        peonNames: List<String>.from(j['peonNames'] ?? []),
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'subject': subject, 'cls': cls, 'head': head,
        'students': students, 'batches': batches,
        'expertNames': expertNames, 'labNames': labNames, 'peonNames': peonNames,
      };

  /// Returns (expertTotal, labTotal, peonTotal, total)
  Map<String, double> calc(Rates rates) {
    final expertTotal = head == 'OR' ? 0.0 : rates.expert * batches;
    final labTotal = rates.lab * batches;
    final peonTotal = rates.peon * batches;
    return {
      'expertTotal': expertTotal, 'labTotal': labTotal, 'peonTotal': peonTotal,
      'total': expertTotal + labTotal + peonTotal,
    };
  }
}

class StaffDirectory {
  List<String> internal;
  List<String> external;
  StaffDirectory({List<String>? internal, List<String>? external})
      : internal = internal ?? [],
        external = external ?? [];

  factory StaffDirectory.fromJson(Map<String, dynamic> j) => StaffDirectory(
        internal: List<String>.from(j['internal'] ?? []),
        external: List<String>.from(j['external'] ?? []),
      );

  Map<String, dynamic> toJson() => {'internal': internal, 'external': external};
}
