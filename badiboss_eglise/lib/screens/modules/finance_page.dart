import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../auth/access_control.dart';
import '../../auth/models/session.dart';
import '../../auth/permissions.dart';
import '../../auth/stores/session_store.dart';
import '../../core/config.dart';
import '../../services/export_file_service.dart';
import '../../services/church_service.dart';
import '../../models/member.dart';
import '../../widgets/member_picker_dialog.dart';
import '../../widgets/scroll_edge_fabs.dart';

final class _FinanceCategory {
  final int id;
  final String name;
  final String direction; // 'in' | 'out'

  const _FinanceCategory({
    required this.id,
    required this.name,
    required this.direction,
  });
}

final class _CategoryReportPage extends StatefulWidget {
  final String title;
  final List<_FinanceTransaction> rows;
  final String Function(int) toIso;
  final Map<String, String> Function(_FinanceTransaction) parseMeta;
  final Future<void> Function() onExport;

  const _CategoryReportPage({
    required this.title,
    required this.rows,
    required this.toIso,
    required this.parseMeta,
    required this.onExport,
  });

  @override
  State<_CategoryReportPage> createState() => _CategoryReportPageState();
}

final class _CategoryReportPageState extends State<_CategoryReportPage> {
  String _filter = '';
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _filter.trim().toLowerCase();
    final filtered = widget.rows.where((t) {
      if (q.isEmpty) return true;
      final m = widget.parseMeta(t);
      final blob =
          '${widget.toIso(t.createdAt)} ${t.amount} ${t.currency} ${m['source']} ${m['destination']} ${m['activity']} ${m['author']} ${m['circumstance']} ${t.memberNumber ?? ''} ${m['donor_label'] ?? ''} ${m['note']}'
              .toLowerCase();
      return blob.contains(q);
    }).toList();

    final byCur = <String, double>{};
    var inSum = 0.0;
    var outSum = 0.0;
    for (final t in filtered) {
      byCur[t.currency] = (byCur[t.currency] ?? 0) + t.amount;
      if (t.direction == 'out') {
        outSum += t.amount;
      } else {
        inSum += t.amount;
      }
    }
    final curKeys = byCur.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text('Rubrique: ${widget.title}'),
        actions: [
          IconButton(
            tooltip: 'Exporter rapport rubrique',
            onPressed: () => widget.onExport(),
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
      floatingActionButton: scrollEdgeFabs(_scroll),
      body: widget.rows.isEmpty
          ? const Center(child: Text('Aucune opération pour cette rubrique.'))
          : Scrollbar(
              controller: _scroll,
              thumbVisibility: true,
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Filtrer (date, montant, membre, note…)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.filter_alt_outlined),
                    ),
                    onChanged: (v) => setState(() => _filter = v),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Résumé', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text(
                            'Lignes affichées: ${filtered.length} / ${widget.rows.length} • Entrées (direction in): ${inSum.toStringAsFixed(2)} • Sorties: ${outSum.toStringAsFixed(2)}',
                            style: const TextStyle(height: 1.25),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: curKeys
                                .map((c) => Chip(label: Text('Total $c: ${(byCur[c] ?? 0).toStringAsFixed(2)}')))
                                .toList(),
                          ),
                          const SizedBox(height: 10),
                          const Text('Points clés', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            '- Totaux par devise (USD / CDF) — pas de mélange.\n'
                            '- Utilisez le filtre pour isoler un membre, une période ou un mot-clé.',
                            style: TextStyle(color: Colors.grey.shade800, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Montant')),
                            DataColumn(label: Text('Devise')),
                            DataColumn(label: Text('Source')),
                            DataColumn(label: Text('Destination')),
                            DataColumn(label: Text('Activité')),
                            DataColumn(label: Text('Auteur')),
                            DataColumn(label: Text('Circonstance')),
                            DataColumn(label: Text('Personne / membre')),
                            DataColumn(label: Text('Note')),
                          ],
                          rows: filtered.map((t) {
                            final m = widget.parseMeta(t);
                            return DataRow(
                              cells: [
                                DataCell(Text(widget.toIso(t.createdAt).substring(0, 19))),
                                DataCell(Text(t.amount.toStringAsFixed(2))),
                                DataCell(Text(t.currency)),
                                DataCell(Text(m['source'] ?? '-')),
                                DataCell(Text(m['destination'] ?? '-')),
                                DataCell(Text(m['activity'] ?? '-')),
                                DataCell(Text(m['author'] ?? '-')),
                                DataCell(Text(m['circumstance'] ?? '-')),
                                DataCell(Text(m['donor_label'] ?? '-')),
                                DataCell(Text(m['note'] ?? '-')),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

final class _FinanceTransaction {
  final int id;
  final int categoryId;
  final String categoryName;
  final String direction;
  final String? memberNumber;
  final double amount;
  final String currency;
  final String note;
  final int createdAt; // epoch seconds

  const _FinanceTransaction({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.direction,
    required this.memberNumber,
    required this.amount,
    required this.currency,
    required this.note,
    required this.createdAt,
  });
}

final class _FinanceSummary {
  final double inTotal;
  final double outTotal;
  final double netTotal;
  final List<Map<String, dynamic>> byCategory;

  const _FinanceSummary({
    required this.inTotal,
    required this.outTotal,
    required this.netTotal,
    required this.byCategory,
  });
}

final class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  static const String routeName = '/finance';

  @override
  State<FinancePage> createState() => _FinancePageState();
}

final class _FinancePageState extends State<FinancePage> {
  AppSession? _session;
  bool _loading = true;
  String _status = '';

  bool _canView = false;
  bool _canManage = false;
  bool _canExport = false;

  final _superAdminChurchCtrl = TextEditingController();

  List<_FinanceCategory> _categories = <_FinanceCategory>[];
  int? _selectedCategoryId;

  double _inTotal = 0;
  double _outTotal = 0;
  double _netTotal = 0;
  List<Map<String, dynamic>> _byCategory = <Map<String, dynamic>>[];

  List<_FinanceTransaction> _transactions = <_FinanceTransaction>[];
  int? _focusCategoryId;

  // Create form
  final _amountCtrl = TextEditingController();
  final _beneficiaryCtrl = TextEditingController();
  final _activityCtrl = TextEditingController();
  final _circumstanceCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _externalNameCtrl = TextEditingController();
  final _externalPhoneCtrl = TextEditingController();
  final _listScrollCtrl = ScrollController();

  List<Member> _members = <Member>[];
  Member? _pickedMember;
  /// false = membre choisi dans la liste ; true = donateur externe (non-membre)
  bool _externalDonor = false;

  String _currency = 'USD';
  String _sourceType = 'person';

  // Category create (manage)
  final _catNameCtrl = TextEditingController();
  String _catDirection = 'in'; // 'in' | 'out'

  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      setState(() {
        _loading = true;
        _status = '';
      });
      final s = await const SessionStore().read();
      if (!mounted) return;
      setState(() => _session = s);

      if (s == null) {
        setState(() {
          _loading = false;
          _status = 'Session introuvable.';
        });
        return;
      }

      final canView = await AccessControl.has(s, Permissions.viewFinance);
      final canManage = await AccessControl.has(s, Permissions.manageFinance);
      final canExport = await AccessControl.has(s, Permissions.exportFinance);

      if (!mounted) return;
      setState(() {
        _canView = canView;
        _canManage = canManage;
        _canExport = canExport;
      });

      if (!canView) {
        setState(() {
          _loading = false;
          _status = 'Accès refusé.';
        });
        return;
      }

      await _reload();
      _poll = Timer.periodic(const Duration(seconds: 20), (_) => _reload(silent: true));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = 'Erreur init finance: $e';
      });
    }
  }

  String? _effectiveChurchCode() {
    final s = _session;
    if (s == null) return null;
    if (s.churchCode != null && s.churchCode!.trim().isNotEmpty) return s.churchCode!.trim();
    final cc = _superAdminChurchCtrl.text.trim();
    if (cc.isNotEmpty) return cc;
    final scoped = ChurchService.getChurchCode().trim();
    if (scoped.isNotEmpty) return scoped;
    return null;
  }

  Future<void> _reload({bool silent = false}) async {
    final s = _session;
    final cc = _effectiveChurchCode();
    if (s == null || cc == null) {
      if (!silent && mounted) {
        setState(() {
          _loading = false;
          _status = 'churchCode requis (SUPER ADMIN).';
        });
      }
      return;
    }

    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _status = '';
      });
    }

    try {
      final token = s.token.trim();
      final superAdmin = s.churchCode == null;
      final categories = await _fetchCategories(token: token, churchCode: cc, superAdmin: superAdmin);
      final summary = await _fetchSummary(token: token, churchCode: cc, superAdmin: superAdmin);
      final txs = await _fetchTransactions(token: token, churchCode: cc, superAdmin: superAdmin);

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _selectedCategoryId ??= categories.isNotEmpty ? categories.first.id : null;

        _inTotal = summary.inTotal;
        _outTotal = summary.outTotal;
        _netTotal = summary.netTotal;
        _byCategory = summary.byCategory;

        _transactions = txs;
        _loading = false;
      });
      await _loadMembers(cc: cc, token: token, superAdmin: superAdmin);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = e.toString();
      });
    }
  }

  Future<List<_FinanceCategory>> _fetchCategories({
    required String token,
    required String churchCode,
    required bool superAdmin,
  }) async {
    final uri = Uri.parse('${Config.baseUrl}/church/finance/categories/list').replace(
      queryParameters: superAdmin ? {'church_code': churchCode} : null,
    );
    final res = await http
        .get(
          uri,
          headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'},
        )
        .timeout(Duration(seconds: Config.timeoutSeconds));

    final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError((decoded['detail'] ?? decoded['message'] ?? 'Erreur API').toString());
    }

    final list = decoded['categories'];
    if (list is! List) return <_FinanceCategory>[];
    return list
        .whereType<Map>()
        .where((e) {
          final name = (e['name'] ?? '').toString();
          return name != 'Entrées' && name != 'Sorties';
        })
        .map((e) => _FinanceCategory(
              id: int.parse((e['id'] ?? 0).toString()),
              name: (e['name'] ?? '').toString(),
              direction: (e['direction'] ?? 'in').toString(),
            ))
        .toList();
  }

  Future<_FinanceSummary> _fetchSummary({
    required String token,
    required String churchCode,
    required bool superAdmin,
  }) async {
    final uri = Uri.parse('${Config.baseUrl}/church/finance/summary').replace(
      queryParameters: superAdmin ? {'church_code': churchCode} : null,
    );
    final res = await http
        .get(
          uri,
          headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'},
        )
        .timeout(Duration(seconds: Config.timeoutSeconds));

    final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError((decoded['detail'] ?? decoded['message'] ?? 'Erreur API').toString());
    }

    final by = decoded['by_category'];
    final byList = by is List
        ? by.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList()
        : <Map<String, dynamic>>[];
    return _FinanceSummary(
      inTotal: (decoded['in_total'] ?? 0).toDouble(),
      outTotal: (decoded['out_total'] ?? 0).toDouble(),
      netTotal: (decoded['net_total'] ?? 0).toDouble(),
      byCategory: byList,
    );
  }

  Future<List<_FinanceTransaction>> _fetchTransactions({
    required String token,
    required String churchCode,
    required bool superAdmin,
  }) async {
    final uri = Uri.parse('${Config.baseUrl}/church/finance/transactions/list').replace(
      queryParameters: <String, String>{
        'limit': '5000',
        'offset': '0',
        if (superAdmin) 'church_code': churchCode,
      },
    );

    final res = await http
        .get(
          uri,
          headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'},
        )
        .timeout(Duration(seconds: Config.timeoutSeconds));

    final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError((decoded['detail'] ?? decoded['message'] ?? 'Erreur API').toString());
    }

    final list = decoded['transactions'];
    if (list is! List) return <_FinanceTransaction>[];
    return list
        .whereType<Map>()
        .map((e) => _FinanceTransaction(
              id: int.parse((e['id'] ?? 0).toString()),
              categoryId: int.parse((e['category_id'] ?? 0).toString()),
              categoryName: (e['category_name'] ?? '').toString(),
              direction: (e['direction'] ?? 'in').toString(),
              memberNumber: (e['member_number'] ?? '').toString().isEmpty
                  ? null
                  : (e['member_number'] ?? '').toString(),
              amount: (e['amount'] ?? 0).toDouble(),
              currency: (e['currency'] ?? 'CDF').toString(),
              note: (e['note'] ?? '').toString(),
              createdAt: int.parse((e['created_at'] ?? 0).toString()),
            ))
        .toList();
  }

  Future<void> _loadMembers({
    required String cc,
    required String token,
    required bool superAdmin,
  }) async {
    try {
      final list = await _fetchMembersFromApi(token: token, churchCode: cc, superAdmin: superAdmin);
      if (!mounted) return;
      setState(() => _members = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _members = <Member>[]);
    }
  }

  Future<List<Member>> _fetchMembersFromApi({
    required String token,
    required String churchCode,
    required bool superAdmin,
  }) async {
    if (token.trim().isEmpty) return <Member>[];
    final uri = Uri.parse('${Config.baseUrl}/church/members/list').replace(
      queryParameters: <String, String>{
        if (superAdmin) 'church_code': churchCode,
      },
    );
    final res = await http
        .get(
          uri,
          headers: {
            'accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(Duration(seconds: Config.timeoutSeconds));
    final text = res.body.isEmpty ? '{}' : res.body;
    final decoded = jsonDecode(text);
    if (decoded is! Map) return <Member>[];
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return <Member>[];
    }
    final membersRaw = decoded['members'];
    if (membersRaw is! List) return <Member>[];
    return membersRaw
        .whereType<Map>()
        .map((m) => _memberFromApiMap(Map<String, dynamic>.from(m), churchCode: churchCode))
        .toList();
  }

  Member _memberFromApiMap(Map<String, dynamic> m, {required String churchCode}) {
    final isValidated = (m['is_validated'] ?? 0) == 1;
    final createdAtTs = int.tryParse((m['created_at'] ?? '').toString()) ?? 0;
    final statusRaw = (m['status'] ?? '').toString().trim().toLowerCase();
    final status = statusRaw == 'active'
        ? MemberStatus.active
        : statusRaw == 'suspended'
            ? MemberStatus.suspended
            : statusRaw == 'banned'
                ? MemberStatus.banned
                : (isValidated ? MemberStatus.active : MemberStatus.pending);

    return Member(
      id: (m['member_number'] ?? m['id'] ?? '').toString(),
      phone: (m['phone'] ?? '').toString(),
      fullName: (m['full_name'] ?? '').toString(),
      sex: sexFromString(m['sex']?.toString()),
      maritalStatus: maritalFromString(m['marital_status']?.toString()),
      birthDateIso: (m['birth_date'] ?? m['date_of_birth'] ?? '').toString(),
      commune: (m['commune'] ?? '').toString(),
      quartier: (m['quarter'] ?? '').toString(),
      zone: (m['zone'] ?? '').toString(),
      addressLine: (m['address_line'] ?? '').toString(),
      neighborhood: (m['neighborhood'] ?? '').toString(),
      region: (m['region'] ?? '').toString(),
      province: (m['province'] ?? '').toString(),
      churchCode: churchCode,
      role: 'membre',
      status: status,
      createdBy: '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtTs * 1000),
    );
  }

  String _dirLabel(String d) => d == 'out' ? 'Sortie' : 'Entrée';

  String _normalizeCategoryLabel(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == 'dame' || v == 'dime' || v == 'di me') return 'Dîme';
    if (v == 'offrande' || v == 'offrandes') return 'Offrande';
    if (v == 'action de grace') return 'Action de grâce';
    if (v == 'don special' || v == 'don spécial') return 'Don spécial';
    if (v == 'depense' || v == 'dépense' || v == 'depenses' || v == 'dépenses') return 'Dépenses';
    if (v == 'salaire' || v == 'salaires') return 'Salaires';
    return raw;
  }

  String _isoFromEpochSec(int sec) {
    final dt = DateTime.fromMillisecondsSinceEpoch(sec * 1000);
    return dt.toIso8601String();
  }

  String _escapeCsv(String s) {
    final v = s.replaceAll('"', '""');
    return '"$v"';
  }

  String _extractAuthor(String note) {
    final m = RegExp(r'author\s*=\s*([^|]+)').firstMatch(note);
    if (m == null) return 'Auteur: -';
    return 'Auteur: ${m.group(1)!.trim()}';
  }

  Map<String, String> _parseNoteMeta(String note) {
    final out = <String, String>{
      'source': '-',
      'destination': '-',
      'activity': '-',
      'author': '-',
      'circumstance': '-',
      'note': note,
      'donor_kind': '-',
      'external_name': '-',
      'external_phone': '-',
    };
    final parts = note.split('||');
    if (parts.isNotEmpty) {
      out['note'] = parts.first.trim().isEmpty ? '-' : parts.first.trim();
    }
    final metaBlock = parts.length > 1 ? parts.sublist(1).join('||') : note;
    for (final seg in metaBlock.split('|')) {
      final pair = seg.trim();
      if (pair.isEmpty) continue;
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;
      final k = pair.substring(0, eq).trim();
      final v = pair.substring(eq + 1).trim();
      if (v.isEmpty) continue;
      if (k == 'source_type') out['source'] = v == 'person' ? 'Personne' : 'Activité';
      if (k == 'beneficiary') out['destination'] = v;
      if (k == 'activity') out['activity'] = v;
      if (k == 'author') out['author'] = v;
      if (k == 'circumstance') out['circumstance'] = v;
      if (k == 'donor_kind') out['donor_kind'] = v;
      if (k == 'external_name') out['external_name'] = v;
      if (k == 'external_phone') out['external_phone'] = v;
    }
    if (out['author'] == '-') {
      final a = _extractAuthor(note);
      out['author'] = a.replaceFirst('Auteur: ', '').trim();
      if (out['author'] == '-') out['author'] = '-';
    }
    return out;
  }

  String _donorLabel(_FinanceTransaction t, Map<String, String> m) {
    final kind = (m['donor_kind'] ?? '').trim();
    if (kind == 'external') {
      final name = (m['external_name'] ?? '').trim();
      final ph = (m['external_phone'] ?? '').trim();
      if (name.isEmpty) return 'Donateur externe';
      if (ph.isNotEmpty && ph != '-') return '$name (externe) • $ph';
      return '$name (externe)';
    }
    if (t.memberNumber != null && t.memberNumber!.trim().isNotEmpty) {
      return 'Membre ${t.memberNumber!.trim()}';
    }
    if (kind == 'none') return '—';
    return '-';
  }

  Map<String, String> _transactionMeta(_FinanceTransaction t) {
    final m = _parseNoteMeta(t.note);
    m['donor_label'] = _donorLabel(t, m);
    return m;
  }

  bool _isEditableWithin24h(_FinanceTransaction t) {
    final dt = DateTime.fromMillisecondsSinceEpoch(t.createdAt * 1000);
    return DateTime.now().difference(dt).inHours < 24;
  }

  Future<void> _editLocalNote(_FinanceTransaction t) async {
    if (!_canManage) return;
    if (!_isEditableWithin24h(t)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modification refusée: délai 24h dépassé (lecture seule).')),
      );
      return;
    }
    final c = TextEditingController(text: t.note);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier la note'),
        content: TextField(controller: c, maxLines: 3, decoration: const InputDecoration(labelText: 'Note')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok != true) return;
    final s = _session;
    final cc = _effectiveChurchCode();
    if (s == null || cc == null) return;
    try {
      final uri = Uri.parse('${Config.baseUrl}/church/finance/transactions/update_note').replace(
        queryParameters: s.churchCode == null ? {'church_code': cc} : null,
      );
      final res = await http
          .post(
            uri,
            headers: {
              'accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${s.token}',
            },
            body: jsonEncode({
              'transaction_id': t.id,
              'note': c.text.trim(),
            }),
          )
          .timeout(Duration(seconds: Config.timeoutSeconds));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError(res.body);
      }
    } catch (_) {
      // fallback local in case endpoint unavailable; 24h rule already enforced locally
      setState(() {
        final idx = _transactions.indexWhere((x) => x.id == t.id);
        if (idx >= 0) {
          _transactions[idx] = _FinanceTransaction(
            id: t.id,
            categoryId: t.categoryId,
            categoryName: t.categoryName,
            direction: t.direction,
            memberNumber: t.memberNumber,
            amount: t.amount,
            currency: t.currency,
            note: c.text.trim(),
            createdAt: t.createdAt,
          );
        }
      });
    }
  }

  Future<void> _deleteTransaction(_FinanceTransaction t) async {
    if (!_canManage) return;
    if (!_isEditableWithin24h(t)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Suppression refusée: délai 24h dépassé (lecture seule).')),
      );
      return;
    }
    final s = _session;
    final cc = _effectiveChurchCode();
    if (s == null || cc == null) return;
    try {
      final uri = Uri.parse('${Config.baseUrl}/church/finance/transactions/delete').replace(
        queryParameters: s.churchCode == null ? {'church_code': cc} : null,
      );
      final res = await http
          .post(
            uri,
            headers: {
              'accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${s.token}',
            },
            body: jsonEncode({'transaction_id': t.id}),
          )
          .timeout(Duration(seconds: Config.timeoutSeconds));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError(res.body);
      }
      await _reload();
    } catch (_) {
      setState(() => _transactions.removeWhere((x) => x.id == t.id));
    }
  }

  Future<void> _createTransaction() async {
    if (!_canManage) return;
    final s = _session;
    final cc = _effectiveChurchCode();
    if (s == null || cc == null) return;
    final catId = _selectedCategoryId;
    if (catId == null) {
      setState(() => _status = 'Choisir une catégorie.');
      return;
    }

    final amountRaw = _amountCtrl.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(amountRaw);
    if (amount == null || amount <= 0) {
      setState(() => _status = 'Montant invalide.');
      return;
    }

    String donorKind = 'none';
    String? memberNumber;

    if (_sourceType == 'person') {
      if (_externalDonor) {
        if (_externalNameCtrl.text.trim().isEmpty) {
          setState(() => _status = 'Donateur externe : le nom est obligatoire.');
          return;
        }
        donorKind = 'external';
        memberNumber = null;
      } else {
        if (_pickedMember == null) {
          setState(
            () => _status =
                'Sélectionnez un membre dans la liste, ou basculez sur « Donateur externe » pour un non-membre.',
          );
          return;
        }
        donorKind = 'member';
        memberNumber = _pickedMember!.id.trim();
      }
    } else {
      if (_externalDonor) {
        if (_externalNameCtrl.text.trim().isEmpty) {
          setState(() => _status = 'Si vous indiquez un donateur externe, le nom est obligatoire.');
          return;
        }
        donorKind = 'external';
        memberNumber = null;
      } else if (_pickedMember != null) {
        donorKind = 'member';
        memberNumber = _pickedMember!.id.trim();
      } else {
        donorKind = 'none';
        memberNumber = null;
      }
    }

    setState(() {
      _loading = true;
      _status = '';
    });

    try {
      final token = s.token.trim();
      final uri = Uri.parse('${Config.baseUrl}/church/finance/transactions/create').replace(
        queryParameters: s.churchCode == null ? {'church_code': cc} : null,
      );
      final donorParts = <String>[
        'donor_kind=$donorKind',
        if (donorKind == 'external') 'external_name=${_externalNameCtrl.text.trim()}',
        if (donorKind == 'external' && _externalPhoneCtrl.text.trim().isNotEmpty)
          'external_phone=${_externalPhoneCtrl.text.trim()}',
      ];
      final structuredMeta = [
        'author=${s.phone}',
        'source_type=$_sourceType',
        'activity=${_activityCtrl.text.trim()}',
        'circumstance=${_circumstanceCtrl.text.trim()}',
        'beneficiary=${_beneficiaryCtrl.text.trim()}',
        ...donorParts,
      ].join(' | ');
      final rawNote = _noteCtrl.text.trim();
      final note = rawNote.isEmpty ? structuredMeta : '$rawNote || $structuredMeta';

      final res = await http.post(
        uri,
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'category_id': catId,
          'member_number': memberNumber,
          'amount': amount,
          'currency': _currency,
          'note': note,
        }),
      ).timeout(Duration(seconds: Config.timeoutSeconds));

      final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError((decoded['detail'] ?? decoded['message'] ?? 'Erreur API').toString());
      }

      _amountCtrl.clear();
      _beneficiaryCtrl.clear();
      _activityCtrl.clear();
      _circumstanceCtrl.clear();
      _noteCtrl.clear();
      _externalNameCtrl.clear();
      _externalPhoneCtrl.clear();
      setState(() {
        _pickedMember = null;
        _externalDonor = false;
      });
      _focusCategoryId = catId;
      await _reload();
    } catch (e) {
      setState(() {
        _loading = false;
        _status = e.toString();
      });
    }
  }

  Future<void> _createCategory() async {
    if (!_canManage) return;
    final s = _session;
    final cc = _effectiveChurchCode();
    if (s == null || cc == null) return;

    final name = _catNameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _status = 'Nom catégorie requis.');
      return;
    }

    setState(() {
      _loading = true;
      _status = '';
    });

    try {
      final token = s.token.trim();
      final uri = Uri.parse('${Config.baseUrl}/church/finance/categories/create').replace(
        queryParameters: s.churchCode == null ? {'church_code': cc} : null,
      );

      final res = await http.post(
        uri,
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'direction': _catDirection,
        }),
      ).timeout(Duration(seconds: Config.timeoutSeconds));

      final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError((decoded['detail'] ?? decoded['message'] ?? 'Erreur API').toString());
      }

      _catNameCtrl.clear();
      await _reload();
    } catch (e) {
      setState(() {
        _loading = false;
        _status = e.toString();
      });
    }
  }

  Future<void> _exportCsv() async {
    if (!_canExport) return;
    final lines = <String>[];
    lines.add('# Rapport financier global (Badiboss Église)');
    lines.add('# total_in=${_inTotal.toStringAsFixed(2)} total_out=${_outTotal.toStringAsFixed(2)} net=${_netTotal.toStringAsFixed(2)}');
    final byCur = <String, double>{};
    for (final t in _transactions) {
      byCur[t.currency] = (byCur[t.currency] ?? 0) + t.amount;
    }
    for (final e in byCur.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
      lines.add('# total_volume_${e.key}=${e.value.toStringAsFixed(2)}');
    }
    lines.add(
      'date,direction,rubrique,montant,devise,personne_donateur,source,destination,activite,auteur,circonstance,membre_code,note_brute',
    );

    for (final t in _transactions) {
      final m = _transactionMeta(t);
      lines.add([
        _escapeCsv(_isoFromEpochSec(t.createdAt)),
        _escapeCsv(t.direction),
        _escapeCsv(_normalizeCategoryLabel(t.categoryName)),
        t.amount.toStringAsFixed(2),
        _escapeCsv(t.currency),
        _escapeCsv(m['donor_label'] ?? '-'),
        _escapeCsv(m['source'] ?? '-'),
        _escapeCsv(m['destination'] ?? '-'),
        _escapeCsv(m['activity'] ?? '-'),
        _escapeCsv(m['author'] ?? '-'),
        _escapeCsv(m['circumstance'] ?? '-'),
        _escapeCsv(t.memberNumber ?? '-'),
        _escapeCsv(t.note),
      ].join(','));
    }

    final csv = lines.join('\n');
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final cc = _effectiveChurchCode() ?? 'church';
    final result = await ExportFileService.saveTextFile(
      fileName: 'finance_${cc}_$ts.csv',
      content: csv,
      openShareSheet: true,
    );
    if (!mounted) return;
    setState(() => _status = 'Export finance généré: ${result.path}');
  }

  Future<void> _exportCategoryCsv(_FinanceCategory cat) async {
    final rows = _transactions.where((t) => t.categoryId == cat.id).toList();
    final lines = <String>[
      'date,montant,devise,personne_donateur,source,destination,activite,auteur,circonstance,membre_code,note',
    ];
    for (final t in rows) {
      final m = _transactionMeta(t);
      lines.add([
        _escapeCsv(_isoFromEpochSec(t.createdAt)),
        t.amount.toStringAsFixed(2),
        _escapeCsv(t.currency),
        _escapeCsv(m['donor_label'] ?? '-'),
        _escapeCsv(m['source'] ?? '-'),
        _escapeCsv(m['destination'] ?? '-'),
        _escapeCsv(m['activity'] ?? '-'),
        _escapeCsv(m['author'] ?? '-'),
        _escapeCsv(m['circumstance'] ?? '-'),
        _escapeCsv(t.memberNumber ?? '-'),
        _escapeCsv(m['note'] ?? '-'),
      ].join(','));
    }
    final result = await ExportFileService.saveTextFile(
      fileName: 'finance_${_normalizeCategoryLabel(cat.name)}_${DateTime.now().millisecondsSinceEpoch}.csv',
      content: lines.join('\n'),
      openShareSheet: true,
    );
    if (!mounted) return;
    setState(() => _status = 'Rapport rubrique généré: ${result.path}');
  }

  void _openCategoryDetail(_FinanceCategory cat) {
    final rows = _transactions.where((t) => t.categoryId == cat.id).toList();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CategoryReportPage(
          title: _normalizeCategoryLabel(cat.name),
          rows: rows,
          toIso: _isoFromEpochSec,
          parseMeta: _transactionMeta,
          onExport: () => _exportCategoryCsv(cat),
        ),
      ),
    );
  }

  void _accumulateBucket(Map<String, Map<String, double>> target, _FinanceTransaction t) {
    target.putIfAbsent(t.currency, () => {'in': 0, 'out': 0});
    final b = target[t.currency]!;
    if (t.direction == 'out') {
      b['out'] = (b['out'] ?? 0) + t.amount;
    } else {
      b['in'] = (b['in'] ?? 0) + t.amount;
    }
  }

  String _pctChange(double prev, double cur) {
    if (prev == 0) return cur == 0 ? '0 %' : '—';
    final p = ((cur - prev) / prev.abs()) * 100;
    return '${p >= 0 ? '+' : ''}${p.toStringAsFixed(1)} %';
  }

  Widget _buildMonthlyPilotageCard() {
    if (_transactions.isEmpty) {
      return const SizedBox.shrink();
    }
    final now = DateTime.now();
    final curY = now.year;
    final curM = now.month;
    final prevM = curM == 1 ? 12 : curM - 1;
    final prevY = curM == 1 ? curY - 1 : curY;

    final curBuckets = <String, Map<String, double>>{};
    final prevBuckets = <String, Map<String, double>>{};
    final rubricVol = <String, double>{};

    for (final t in _transactions) {
      final dt = DateTime.fromMillisecondsSinceEpoch(t.createdAt * 1000);
      if (dt.year == curY && dt.month == curM) {
        _accumulateBucket(curBuckets, t);
        final name = _normalizeCategoryLabel(t.categoryName);
        rubricVol[name] = (rubricVol[name] ?? 0) + t.amount;
      } else if (dt.year == prevY && dt.month == prevM) {
        _accumulateBucket(prevBuckets, t);
      }
    }

    final allCurrencies = {...curBuckets.keys, ...prevBuckets.keys}.toList()..sort();
    final topRubrics = rubricVol.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = topRubrics.take(5).toList();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pilotage mensuel (mois en cours vs mois précédent)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 6),
            Text(
              'Période courante : ${now.year}-${curM.toString().padLeft(2, '0')} • '
              'Mois précédent : $prevY-${prevM.toString().padLeft(2, '0')}',
              style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Text('Par devise (totaux séparés)', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade900)),
            const SizedBox(height: 6),
            ...allCurrencies.map((c) {
              final cb = curBuckets[c] ?? {'in': 0, 'out': 0};
              final pb = prevBuckets[c] ?? {'in': 0, 'out': 0};
              final ci = cb['in'] ?? 0;
              final co = cb['out'] ?? 0;
              final pi = pb['in'] ?? 0;
              final po = pb['out'] ?? 0;
              final cNet = ci - co;
              final pNet = pi - po;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Devise $c', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      'Mois en cours — entrées: ${ci.toStringAsFixed(2)} • sorties: ${co.toStringAsFixed(2)} • solde: ${cNet.toStringAsFixed(2)}',
                      style: const TextStyle(height: 1.25),
                    ),
                    Text(
                      'Mois précédent — entrées: ${pi.toStringAsFixed(2)} • sorties: ${po.toStringAsFixed(2)} • solde: ${pNet.toStringAsFixed(2)}',
                      style: const TextStyle(height: 1.25),
                    ),
                    Text(
                      'Variation du solde: ${_pctChange(pNet, cNet)} (vs mois précédent)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cNet >= pNet ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (top5.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Volume par rubrique (mois en cours)', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              ...top5.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${e.key}: ${e.value.toStringAsFixed(2)}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _superAdminChurchCtrl.dispose();
    _amountCtrl.dispose();
    _externalNameCtrl.dispose();
    _externalPhoneCtrl.dispose();
    _listScrollCtrl.dispose();
    _beneficiaryCtrl.dispose();
    _activityCtrl.dispose();
    _circumstanceCtrl.dispose();
    _noteCtrl.dispose();
    _catNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    final totalsByCurrency = <String, double>{};
    for (final t in _transactions) {
      totalsByCurrency[t.currency] = (totalsByCurrency[t.currency] ?? 0) + t.amount;
    }
    final visibleTx = _focusCategoryId == null
        ? _transactions
        : _transactions.where((t) => t.categoryId == _focusCategoryId).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance / Trésorerie'),
        actions: [
          if (_canExport)
            IconButton(
              tooltip: 'Exporter CSV',
              onPressed: _exportCsv,
              icon: const Icon(Icons.download),
            ),
        ],
      ),
      floatingActionButton: _canView ? scrollEdgeFabs(_listScrollCtrl) : null,
      body: _loading && s == null
          ? const Center(child: CircularProgressIndicator())
          : (s == null)
              ? const Center(child: Text('Session introuvable.'))
              : (!_canView)
                  ? Center(child: Text(_status.trim().isEmpty ? 'Accès refusé.' : _status))
                  : RefreshIndicator(
                      onRefresh: () => _reload(),
                      child: ListView(
                        controller: _listScrollCtrl,
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (s.churchCode == null) ...[
                            TextField(
                              controller: _superAdminChurchCtrl,
                              decoration: const InputDecoration(labelText: 'churchCode (SUPER ADMIN)'),
                              onChanged: (_) => _reload(),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_status.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                _status,
                                style: TextStyle(
                                  color: _status.toLowerCase().contains('erreur') ? Colors.red : Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                          Card(
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text('Entrées: ${_inTotal.toStringAsFixed(2)}',
                                            style: const TextStyle(fontWeight: FontWeight.w700)),
                                      ),
                                      Expanded(
                                        child: Text('Sorties: ${_outTotal.toStringAsFixed(2)}',
                                            style: const TextStyle(fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Net: ${_netTotal.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: _netTotal >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                                    ),
                                  ),
                                  if (totalsByCurrency.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: totalsByCurrency.entries
                                          .map((e) => Chip(label: Text('Total ${e.key}: ${e.value.toStringAsFixed(2)}')))
                                          .toList(),
                                    ),
                                  ],
                                  if (_byCategory.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Détail par catégorie (top):',
                                      style: TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 6,
                                      children: _byCategory
                                          .take(8)
                                          .map((c) {
                                            final name = (c['name'] ?? '').toString();
                                            final dir = (c['direction'] ?? '').toString();
                                            final total = (c['total'] ?? 0).toDouble();
                                            final d = dir == 'out' ? 'S' : 'E';
                                            final catId = int.tryParse((c['id'] ?? '').toString());
                                            return ChoiceChip(
                                              label: Text('${_normalizeCategoryLabel(name)} [$d] ${total.toStringAsFixed(2)}'),
                                              selected: _focusCategoryId != null && _focusCategoryId == catId,
                                              onSelected: (_) {
                                                setState(() => _focusCategoryId = catId);
                                                if (catId != null) {
                                                  final cat = _categories.firstWhere(
                                                    (x) => x.id == catId,
                                                    orElse: () => _FinanceCategory(id: catId, name: name, direction: dir),
                                                  );
                                                  _openCategoryDetail(cat);
                                                }
                                              },
                                            );
                                          })
                                          .toList(),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: OutlinedButton(
                                        onPressed: () => setState(() => _focusCategoryId = null),
                                        child: const Text('Voir toutes rubriques'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          _buildMonthlyPilotageCard(),

                          const SizedBox(height: 12),

                          if (_canManage) ...[
                            Card(
                              elevation: 0,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Text('Nouvelle opération', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<int>(
                                      value: _selectedCategoryId,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Catégorie (rubrique)',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: _categories
                                          .map((c) => DropdownMenuItem<int>(
                                                value: c.id,
                                                child: Text('${_normalizeCategoryLabel(c.name)} • ${_dirLabel(c.direction)}'),
                                              ))
                                          .toList(),
                                      onChanged: (v) => setState(() => _selectedCategoryId = v),
                                    ),
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _amountCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Montant', border: OutlineInputBorder()),
                                    ),
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String>(
                                      value: _currency,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Devise',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'USD', child: Text('USD')),
                                        DropdownMenuItem(value: 'CDF', child: Text('CDF')),
                                      ],
                                      onChanged: (v) => setState(() => _currency = v ?? 'USD'),
                                    ),
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String>(
                                      value: _sourceType,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Source principale',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'person', child: Text('Personne (dîme, don nominatif)')),
                                        DropdownMenuItem(value: 'activity', child: Text('Culte / activité / circonstance')),
                                      ],
                                      onChanged: (v) => setState(() => _sourceType = v ?? 'person'),
                                    ),
                                    const SizedBox(height: 12),
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text('Donateur / membre lié', style: TextStyle(fontWeight: FontWeight.w800)),
                                    ),
                                    const SizedBox(height: 6),
                                    SegmentedButton<bool>(
                                      segments: const [
                                        ButtonSegment<bool>(
                                          value: false,
                                          label: Text('Membre'),
                                          icon: Icon(Icons.group_outlined),
                                        ),
                                        ButtonSegment<bool>(
                                          value: true,
                                          label: Text('Externe'),
                                          icon: Icon(Icons.person_outline),
                                        ),
                                      ],
                                      selected: <bool>{_externalDonor},
                                      onSelectionChanged: (Set<bool> ns) {
                                        final v = ns.first;
                                        setState(() {
                                          _externalDonor = v;
                                          if (_externalDonor) {
                                            _pickedMember = null;
                                          } else {
                                            _externalNameCtrl.clear();
                                            _externalPhoneCtrl.clear();
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    if (!_externalDonor)
                                      ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        shape: RoundedRectangleBorder(
                                          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        title: Text(
                                          _pickedMember == null
                                              ? 'Choisir un membre'
                                              : '${_pickedMember!.id} • ${_pickedMember!.fullName}',
                                        ),
                                        subtitle: Text(
                                          _pickedMember == null
                                              ? 'Recherche par nom, code membre ou téléphone'
                                              : _pickedMember!.phone,
                                        ),
                                        trailing: const Icon(Icons.search),
                                        onTap: () async {
                                          final m = await showMemberPickerDialog(context, members: _members);
                                          if (m != null) setState(() => _pickedMember = m);
                                        },
                                      ),
                                    if (_externalDonor) ...[
                                      TextFormField(
                                        controller: _externalNameCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Nom complet (donateur externe)',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: _externalPhoneCtrl,
                                        keyboardType: TextInputType.phone,
                                        decoration: const InputDecoration(
                                          labelText: 'Téléphone (optionnel)',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _activityCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Activité concernée (optionnel)',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _circumstanceCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Circonstance (optionnel)',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _beneficiaryCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Bénéficiaire / destination (optionnel)',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _noteCtrl,
                                      maxLines: 2,
                                      decoration: const InputDecoration(
                                        labelText: 'Note (optionnel)',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 44,
                                      child: ElevatedButton.icon(
                                        onPressed: _loading ? null : _createTransaction,
                                        icon: const Icon(Icons.check_circle_outline),
                                        label: const Text('Enregistrer opération'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            Card(
                              elevation: 0,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Text('Créer une rubrique (catégorie)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String>(
                                      value: _catDirection,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Direction',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'in', child: Text('Entrée')),
                                        DropdownMenuItem(value: 'out', child: Text('Sortie')),
                                      ],
                                      onChanged: (v) => setState(() => _catDirection = v ?? 'in'),
                                    ),
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _catNameCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Nom de la rubrique',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 44,
                                      child: FilledButton.icon(
                                        onPressed: _loading ? null : _createCategory,
                                        icon: const Icon(Icons.add),
                                        label: const Text('Ajouter rubrique'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),
                          ],

                          Card(
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    _focusCategoryId == null ? 'Historique' : 'Détail rubrique',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('Règle: après 24h, les opérations restent consultables en lecture seule.'),
                                  const SizedBox(height: 10),
                                  if (visibleTx.isEmpty)
                                    const Text('Aucune opération enregistrée.')
                                  else
                                    ListView.builder(
                                      itemCount: visibleTx.length,
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemBuilder: (context, i) {
                                        final t = visibleTx[i];
                                        final meta = _transactionMeta(t);
                                        return Card(
                                          elevation: 0,
                                          margin: const EdgeInsets.only(bottom: 10),
                                          child: ListTile(
                                            dense: true,
                                            leading: CircleAvatar(
                                              radius: 20,
                                              backgroundColor: t.direction == 'out' ? Colors.red.shade600 : Colors.green.shade600,
                                              child: Text(
                                                t.direction == 'out' ? 'S' : 'E',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                                              ),
                                            ),
                                            title: InkWell(
                                              onTap: () {
                                                setState(() => _focusCategoryId = t.categoryId);
                                                final cat = _categories.firstWhere(
                                                  (x) => x.id == t.categoryId,
                                                  orElse: () => _FinanceCategory(id: t.categoryId, name: t.categoryName, direction: t.direction),
                                                );
                                                _openCategoryDetail(cat);
                                              },
                                              child: Text(_normalizeCategoryLabel(t.categoryName)),
                                            ),
                                            subtitle: Text(
                                              '${_isoFromEpochSec(t.createdAt).substring(0, 19)} • ${t.currency} • ${meta['donor_label'] ?? '-'}\n${_extractAuthor(t.note)}',
                                              maxLines: 4,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            trailing: PopupMenuButton<String>(
                                              onSelected: (v) {
                                                if (v == 'edit') _editLocalNote(t);
                                                if (v == 'delete') _deleteTransaction(t);
                                              },
                                              itemBuilder: (_) => [
                                                PopupMenuItem(
                                                  value: 'edit',
                                                  enabled: _isEditableWithin24h(t),
                                                  child: const Text('Modifier (24h max)'),
                                                ),
                                                PopupMenuItem(
                                                  value: 'delete',
                                                  enabled: _isEditableWithin24h(t),
                                                  child: const Text('Supprimer (24h max)'),
                                                ),
                                              ],
                                              child: Text(
                                                '${t.amount.toStringAsFixed(2)} ${t.currency}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  color: t.direction == 'out' ? Colors.red.shade700 : Colors.green.shade700,
                                                ),
                                              ),
                                            ),
                                            onTap: () => setState(() => _focusCategoryId = t.categoryId),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
