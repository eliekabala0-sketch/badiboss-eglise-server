import 'package:flutter/material.dart';

import '../../auth/models/session.dart';
import '../../auth/permissions.dart';
import '../../auth/stores/session_store.dart';
import '../../auth/ui/permission_gate.dart';
import '../../services/export_file_service.dart';
import '../../services/church_service.dart';

final class ReportsExportPage extends StatefulWidget {
  const ReportsExportPage({super.key});

  static const String routeName = '/reports/export';

  @override
  State<ReportsExportPage> createState() => _ReportsExportPageState();
}

final class _ReportsExportPageState extends State<ReportsExportPage> {
  AppSession? _session;
  String _status = '';
  bool _loading = false;

  final _superAdminChurchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await const SessionStore().read();
      if (!mounted) return;
      setState(() => _session = s);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _session = null;
        _status = 'Session introuvable.';
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

  @override
  void dispose() {
    _superAdminChurchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;

    return Scaffold(
      appBar: AppBar(title: const Text('Exporter rapports')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: (s == null)
            ? const Center(child: CircularProgressIndicator())
            : PermissionGate(
                permission: Permissions.exportReports,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Session: ${s.phone} | role=${s.role.toJson()} | church=${s.churchCode ?? "-"}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),

                    if (s.churchCode == null) ...[
                      TextField(
                        controller: _superAdminChurchCtrl,
                        decoration: const InputDecoration(
                          labelText: 'churchCode (SUPER ADMIN)',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (_effectiveChurchCode() == null)
                      const Text(
                        'churchCode requis (SUPER ADMIN: saisir).',
                        style: TextStyle(color: Colors.red),
                      ),

                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _loading ? null : _exportGlobalCsv,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Télécharger rapport global (CSV)'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _exportTemplateCsv,
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Télécharger modèle import membres (CSV)'),
                    ),
                    const SizedBox(height: 8),
                    if (_loading) const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    const Text(
                      'Exports réels: génération de fichiers CSV puis partage/téléchargement.',
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),

                    if (_status.trim().isNotEmpty)
                      Text(
                        _status,
                        style: const TextStyle(color: Colors.red),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _exportGlobalCsv() async {
    final cc = _effectiveChurchCode();
    if (cc == null) {
      setState(() => _status = 'churchCode requis.');
      return;
    }
    setState(() {
      _loading = true;
      _status = '';
    });
    final now = DateTime.now();
    final csv = [
      'report_type,church_code,generated_at,generated_by',
      'global,${_q(cc)},${_q(now.toIso8601String())},${_q(_session?.phone ?? "")}',
      'section,key,value',
      'overview,total_members,NA',
      'overview,total_presence,NA',
      'overview,total_finance_in,NA',
      'overview,total_finance_out,NA',
    ].join('\n');
    final ts = now.toIso8601String().replaceAll(':', '-');
    final result = await ExportFileService.saveTextFile(
      fileName: 'rapport_global_${cc}_$ts.csv',
      content: csv,
      openShareSheet: true,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _status = 'Rapport exporté: ${result.path}';
    });
  }

  Future<void> _exportTemplateCsv() async {
    final now = DateTime.now();
    setState(() {
      _loading = true;
      _status = '';
    });
    final csv = [
      'full_name,phone,sex,marital_status,commune,quarter,zone,address_line,neighborhood,region,province',
      'Exemple Nom,+243990000001,male,single,Gombe,Volga,Zone A,Avenue 1,Q1,Kinshasa,Kinshasa',
    ].join('\n');
    final ts = now.toIso8601String().replaceAll(':', '-');
    final result = await ExportFileService.saveTextFile(
      fileName: 'template_import_membres_$ts.csv',
      content: csv,
      openShareSheet: true,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _status = 'Modèle exporté: ${result.path}';
    });
  }

  String _q(String v) => '"${v.replaceAll('"', '""')}"';
}
