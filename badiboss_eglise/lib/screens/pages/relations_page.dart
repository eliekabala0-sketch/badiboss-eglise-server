import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/member.dart';
import '../../services/member_directory_service.dart';
import '../../auth/stores/session_store.dart';
import '../../core/config.dart';

class RelationsPage extends StatefulWidget {
  const RelationsPage({super.key});

  @override
  State<RelationsPage> createState() => _RelationsPageState();
}

class _RelationsPageState extends State<RelationsPage> {
  final List<_RelationItem> _items = [];
  bool _showClosed = true;
  String _relationFilter = 'all';
  List<Member> _members = <Member>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _members = await const MemberDirectoryService().loadMembersForActiveChurch();
      if (!mounted) return;
      final s = await const SessionStore().read();
      final token = (s?.token ?? '').trim();
      if (token.isEmpty) return;
      final uri = Uri.parse('${Config.baseUrl}/church/relations/list');
      final res = await http
          .get(
            uri,
            headers: {
              'accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(Duration(seconds: Config.timeoutSeconds));
      if (!mounted) return;

      Map<String, dynamic>? decoded;
      try {
        final raw = res.body.isEmpty ? '{}' : res.body;
        final d = jsonDecode(raw);
        if (d is Map) decoded = Map<String, dynamic>.from(d);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Réponse serveur invalide (liste relations).')),
          );
        }
        return;
      }
      if (decoded == null) return;

      if (res.statusCode < 200 || res.statusCode >= 300) {
        final detail = (decoded['detail'] ?? decoded['message'] ?? 'Erreur ${res.statusCode}').toString();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(detail)));
        }
        return;
      }

      final list = decoded['relations'];
      if (list is! List) return;
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(
            list
                .whereType<Map>()
                .map((e) => _RelationItem.fromMap(Map<String, dynamic>.from(e))),
          );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _pickRelationAppointment(
    BuildContext dialogCtx,
    TextEditingController appointment,
    void Function(void Function()) setLocal,
  ) async {
    final now = DateTime.now();
    final parsed = _parseFlexibleDate(appointment.text.trim());
    var init = parsed;
    if (init == null || init.isBefore(now)) {
      init = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    }
    final d = await showDatePicker(
      context: dialogCtx,
      initialDate: init,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 8)),
    );
    if (d == null) return;
    final t = await showTimePicker(
      context: dialogCtx,
      initialTime: TimeOfDay(hour: init.hour, minute: init.minute),
    );
    final h = t?.hour ?? 9;
    final mi = t?.minute ?? 0;
    final dt = DateTime(d.year, d.month, d.day, h, mi);
    final minNow = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    if (dt.isBefore(minNow)) {
      if (dialogCtx.mounted) {
        ScaffoldMessenger.of(dialogCtx).showSnackBar(
          const SnackBar(content: Text('Le rendez-vous ne peut pas être dans le passé.')),
        );
      }
      return;
    }
    final iso =
        '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}T'
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:00';
    setLocal(() => appointment.text = iso);
  }

  Future<void> _save() async {
    try {
      final s = await const SessionStore().read();
      final token = (s?.token ?? '').trim();
      if (token.isEmpty) throw StateError('token manquant');
      final uri = Uri.parse('${Config.baseUrl}/church/relations/sync');
      final res = await http
          .post(
            uri,
            headers: {
              'accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'relations': _items.map((e) => e.toMap()).toList(),
            }),
          )
          .timeout(Duration(seconds: Config.timeoutSeconds));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        String msg = res.body;
        try {
          final d = jsonDecode(res.body.isEmpty ? '{}' : res.body);
          if (d is Map) {
            msg = (d['detail'] ?? d['message'] ?? msg).toString();
          }
        } catch (_) {}
        throw StateError(msg);
      }
      if (mounted) await _load();
    } catch (e) {
      if (!mounted) return;
      final msg = e is StateError ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _addOrEdit({_RelationItem? existing}) async {
    final activeByMember = _activeOpenRelationByMember(excludeRelationId: existing?.id);
    final blockedReasons = <String, String>{};
    for (final m in _members) {
      if (m.maritalStatus == MaritalStatus.married) {
        blockedReasons[m.id] = '${m.fullName} est déjà marié(e).';
        continue;
      }
      final rel = activeByMember[m.id];
      if (rel != null) {
        final partner = rel.memberCodeA == m.id ? rel.personB : rel.personA;
        blockedReasons[m.id] = '${m.fullName} est déjà en relation active avec $partner.';
      }
    }
    String typeA = existing?.isMemberA == true ? 'member' : 'external';
    String typeB = existing?.isMemberB == true ? 'member' : 'external';
    Member? selectedA = _members.where((m) => m.id == existing?.memberCodeA).cast<Member?>().isEmpty
        ? null
        : _members.firstWhere((m) => m.id == existing?.memberCodeA);
    Member? selectedB = _members.where((m) => m.id == existing?.memberCodeB).cast<Member?>().isEmpty
        ? null
        : _members.firstWhere((m) => m.id == existing?.memberCodeB);
    final personA = TextEditingController(text: existing?.personA ?? '');
    final personB = TextEditingController(text: existing?.personB ?? '');
    final mentor = TextEditingController(text: existing?.mentor ?? '');
    final appointment = TextEditingController(text: existing?.nextAppointment ?? '');
    final parentsA = TextEditingController(text: existing?.parentsA ?? '');
    final parentsB = TextEditingController(text: existing?.parentsB ?? '');
    final ageA = TextEditingController(text: existing?.ageA ?? '');
    final ageB = TextEditingController(text: existing?.ageB ?? '');
    final addressA = TextEditingController(text: existing?.addressA ?? '');
    final addressB = TextEditingController(text: existing?.addressB ?? '');
    String step = existing?.step ?? 'decouverte';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
        title: Text(existing == null ? 'Dossier mariage / relation' : 'Modifier dossier'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: typeA,
                items: const [
                  DropdownMenuItem(value: 'member', child: Text('Homme: membre')),
                  DropdownMenuItem(value: 'external', child: Text('Homme: non membre')),
                ],
                onChanged: (v) => setLocal(() => typeA = v ?? 'member'),
              ),
              const SizedBox(height: 8),
              if (typeA == 'member')
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(selectedA == null ? 'Choisir un homme membre' : '${selectedA!.id} • ${selectedA!.fullName}'),
                  subtitle: const Text('Filtrer par nom, code membre ou téléphone'),
                  trailing: const Icon(Icons.search),
                  onTap: () async {
                    final picked = await _pickMemberFromList(
                      gender: Sex.male,
                      blockedReasons: blockedReasons,
                      currentMemberId: selectedA?.id,
                    );
                    if (picked == null) return;
                    setLocal(() {
                      selectedA = picked;
                      personA.text = picked.fullName;
                      addressA.text = [picked.commune, picked.quartier, picked.zone].where((e) => e.trim().isNotEmpty).join(', ');
                      if (picked.birthDateIso.isNotEmpty) {
                        final d = DateTime.tryParse(picked.birthDateIso);
                        if (d != null) {
                          final now = DateTime.now();
                          var age = now.year - d.year;
                          if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
                          ageA.text = age.toString();
                        }
                      }
                    });
                  },
                )
              else ...[
                TextField(controller: personA, decoration: const InputDecoration(labelText: 'Nom homme')),
                const SizedBox(height: 8),
                TextField(controller: ageA, decoration: const InputDecoration(labelText: 'Âge homme')),
                const SizedBox(height: 8),
                TextField(controller: addressA, decoration: const InputDecoration(labelText: 'Adresse homme')),
              ],
              const SizedBox(height: 8),
              TextField(controller: parentsA, decoration: const InputDecoration(labelText: 'Noms des parents (homme)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: typeB,
                items: const [
                  DropdownMenuItem(value: 'member', child: Text('Femme: membre')),
                  DropdownMenuItem(value: 'external', child: Text('Femme: non membre')),
                ],
                onChanged: (v) => setLocal(() => typeB = v ?? 'member'),
              ),
              const SizedBox(height: 8),
              if (typeB == 'member')
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(selectedB == null ? 'Choisir une femme membre' : '${selectedB!.id} • ${selectedB!.fullName}'),
                  subtitle: const Text('Filtrer par nom, code membre ou téléphone'),
                  trailing: const Icon(Icons.search),
                  onTap: () async {
                    final picked = await _pickMemberFromList(
                      gender: Sex.female,
                      blockedReasons: blockedReasons,
                      currentMemberId: selectedB?.id,
                    );
                    if (picked == null) return;
                    setLocal(() {
                      selectedB = picked;
                      personB.text = picked.fullName;
                      addressB.text = [picked.commune, picked.quartier, picked.zone].where((e) => e.trim().isNotEmpty).join(', ');
                      if (picked.birthDateIso.isNotEmpty) {
                        final d = DateTime.tryParse(picked.birthDateIso);
                        if (d != null) {
                          final now = DateTime.now();
                          var age = now.year - d.year;
                          if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
                          ageB.text = age.toString();
                        }
                      }
                    });
                  },
                )
              else ...[
                TextField(controller: personB, decoration: const InputDecoration(labelText: 'Nom femme')),
                const SizedBox(height: 8),
                TextField(controller: ageB, decoration: const InputDecoration(labelText: 'Âge femme')),
                const SizedBox(height: 8),
                TextField(controller: addressB, decoration: const InputDecoration(labelText: 'Adresse femme')),
              ],
              const SizedBox(height: 8),
              TextField(controller: parentsB, decoration: const InputDecoration(labelText: 'Noms des parents (femme)')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: step,
                items: const [
                  DropdownMenuItem(value: 'decouverte', child: Text('Découverte / fréquentation')),
                  DropdownMenuItem(value: 'accompagnement', child: Text('Accompagnement')),
                  DropdownMenuItem(value: 'fiancailles', child: Text('Fiançailles')),
                  DropdownMenuItem(value: 'mariage', child: Text('Mariage')),
                ],
                onChanged: (v) => step = v ?? 'decouverte',
                decoration: const InputDecoration(labelText: 'Étape'),
              ),
              const SizedBox(height: 8),
              TextField(controller: mentor, decoration: const InputDecoration(labelText: 'Parrain / marraine (facultatif)')),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  appointment.text.trim().isEmpty ? 'Choisir date / heure du rendez-vous' : appointment.text.trim(),
                  style: TextStyle(
                    fontWeight: appointment.text.trim().isEmpty ? FontWeight.w400 : FontWeight.w600,
                    color: appointment.text.trim().isEmpty ? Theme.of(ctx).hintColor : null,
                  ),
                ),
                subtitle: const Text('Prochain rendez-vous (calendrier)'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (appointment.text.trim().isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Effacer',
                        onPressed: () => setLocal(() => appointment.clear()),
                      ),
                    const Icon(Icons.event),
                  ],
                ),
                onTap: () => _pickRelationAppointment(ctx, appointment, setLocal),
              ),
            ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
        ],
      ),
      ),
    );
    if (ok != true) return;

    final a = personA.text.trim();
    final b = personB.text.trim();
    if (a.isEmpty || b.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Homme et Femme sont obligatoires avant enregistrement.')),
        );
      }
      return;
    }
    if (typeA == 'member' && selectedA == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sélection Homme membre obligatoire.')),
        );
      }
      return;
    }
    if (typeB == 'member' && selectedB == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sélection Femme membre obligatoire.')),
        );
      }
      return;
    }
    if (typeA == 'external' && (ageA.text.trim().isEmpty || addressA.text.trim().isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pour Homme non membre: âge et adresse sont obligatoires.')),
        );
      }
      return;
    }
    if (typeB == 'external' && (ageB.text.trim().isEmpty || addressB.text.trim().isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pour Femme non membre: âge et adresse sont obligatoires.')),
        );
      }
      return;
    }
    final rdv = appointment.text.trim();
    if (rdv.isNotEmpty) {
      final dt = _parseFlexibleDate(rdv);
      if (dt == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Date RDV invalide. Format attendu: YYYY-MM-DD ou YYYY-MM-DD HH:mm.')),
          );
        }
        return;
      }
      final now = DateTime.now();
      final nowNoSec = DateTime(now.year, now.month, now.day, now.hour, now.minute);
      if (dt.isBefore(nowNoSec)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Le rendez-vous ne peut pas être dans le passé.')),
          );
        }
        return;
      }
    }

    _RelationItem? conflict;
    for (final x in _items) {
      if (x.id == existing?.id || !x.isOpen) continue;
      final idA = selectedA?.id ?? '';
      final idB = selectedB?.id ?? '';
      final byMemberId =
          (idA.isNotEmpty && (x.memberCodeA == idA || x.memberCodeB == idA)) ||
          (idB.isNotEmpty && (x.memberCodeA == idB || x.memberCodeB == idB));
      final byName =
          x.personA.toLowerCase() == a.toLowerCase() ||
          x.personB.toLowerCase() == a.toLowerCase() ||
          x.personA.toLowerCase() == b.toLowerCase() ||
          x.personB.toLowerCase() == b.toLowerCase();
      if (byMemberId || byName) {
        conflict = x;
        break;
      }
    }
    if (conflict != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Conflit: relation active existante ${conflict.personA} + ${conflict.personB}. '
            'Finalisez/interrompez-la avant une nouvelle création.',
          ),
        ),
      );
      return;
    }

    setState(() {
      if (existing == null) {
        _items.insert(
          0,
          _RelationItem(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            personA: a,
            personB: b,
            isMemberA: typeA == 'member',
            isMemberB: typeB == 'member',
            memberCodeA: selectedA?.id ?? '',
            memberCodeB: selectedB?.id ?? '',
            parentsA: parentsA.text.trim(),
            parentsB: parentsB.text.trim(),
            ageA: ageA.text.trim(),
            ageB: ageB.text.trim(),
            addressA: addressA.text.trim(),
            addressB: addressB.text.trim(),
            step: step,
            mentor: mentor.text.trim(),
            nextAppointment: appointment.text.trim(),
            isOpen: true,
            history: ['Création ${DateTime.now().toIso8601String()}'],
          ),
        );
      } else {
        existing.personA = a;
        existing.personB = b;
        existing.isMemberA = typeA == 'member';
        existing.isMemberB = typeB == 'member';
        existing.memberCodeA = selectedA?.id ?? '';
        existing.memberCodeB = selectedB?.id ?? '';
        existing.parentsA = parentsA.text.trim();
        existing.parentsB = parentsB.text.trim();
        existing.ageA = ageA.text.trim();
        existing.ageB = ageB.text.trim();
        existing.addressA = addressA.text.trim();
        existing.addressB = addressB.text.trim();
        existing.step = step;
        existing.mentor = mentor.text.trim();
        existing.nextAppointment = appointment.text.trim();
        existing.history.add('Modification ${DateTime.now().toIso8601String()}');
      }
    });
    await _save();
  }

  Future<void> _close(_RelationItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmation de finalisation'),
        content: Text(
          'Vous allez finaliser/interrompre la relation:\n${item.personA} + ${item.personB}\n\n'
          'Cette action bloque toute suppression accidentelle en un clic.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmer')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      item.isOpen = false;
      item.history.add('Finalisée ${DateTime.now().toIso8601String()}');
    });
    await _save();
  }

  void _showHistory(_RelationItem item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${item.personA} + ${item.personB}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Étape actuelle: ${_stepLabel(item.step)}'),
            Text('État: ${item.isOpen ? "Ouverte" : "Finalisée"}'),
            const Divider(height: 24),
            const Text('Historique', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (item.history.isEmpty)
              const Text('Aucun événement.')
            else
              ...item.history.map((h) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.history_rounded, size: 18),
                    title: Text(h),
                  )),
          ],
        ),
      ),
    );
  }

  String _stepLabel(String step) {
    switch (step) {
      case 'decouverte':
        return 'Découverte / fréquentation';
      case 'accompagnement':
        return 'Accompagnement';
      case 'fiancailles':
        return 'Fiançailles';
      case 'mariage':
        return 'Mariage';
      default:
        return step;
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = _showClosed ? _items : _items.where((x) => x.isOpen).toList();
    final visible = base.where((x) {
      if (_relationFilter == 'all') return true;
      if (_relationFilter == 'en_cours') return x.isOpen;
      if (_relationFilter == 'finalisee') return !x.isOpen;
      return x.step == _relationFilter;
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Dossier mariage / relation amoureuse')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: visible.isEmpty
          ? const Center(child: Text('Aucune relation enregistrée.'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Afficher finalisées'),
                        selected: _showClosed,
                        onSelected: (v) => setState(() => _showClosed = v),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _relationFilter,
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Toutes')),
                          DropdownMenuItem(value: 'en_cours', child: Text('En cours')),
                          DropdownMenuItem(value: 'finalisee', child: Text('Finalisées')),
                          DropdownMenuItem(value: 'fiancailles', child: Text('Fiançailles')),
                          DropdownMenuItem(value: 'mariage', child: Text('Mariage')),
                          DropdownMenuItem(value: 'accompagnement', child: Text('Accompagnement')),
                          DropdownMenuItem(value: 'decouverte', child: Text('Découverte')),
                        ],
                        onChanged: (v) => setState(() => _relationFilter = v ?? 'all'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: visible.length,
              itemBuilder: (_, i) {
                final x = visible[i];
                return Card(
                  child: ListTile(
                    title: Text('${x.personA} + ${x.personB}'),
                    subtitle: Text(
                      'Étape: ${_stepLabel(x.step)} • Suivi: ${x.mentor.isEmpty ? "-" : x.mentor}\n'
                      'Type A/B: ${x.isMemberA ? "membre" : "non membre"} / ${x.isMemberB ? "membre" : "non membre"}\n'
                      'RDV: ${x.nextAppointment.isEmpty ? "-" : x.nextAppointment}\n'
                      'État: ${x.isOpen ? "Ouverte" : "Finalisée"}',
                    ),
                    isThreeLine: false,
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'edit') await _addOrEdit(existing: x);
                        if (v == 'close') await _close(x);
                        if (v == 'history') _showHistory(x);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                        if (x.isOpen) const PopupMenuItem(value: 'close', child: Text('Finaliser / dissocier')),
                        const PopupMenuItem(value: 'history', child: Text('Voir historique')),
                      ],
                    ),
                  ),
                );
              },
            ),
                ),
              ],
            ),
    );
  }
}

extension on _RelationsPageState {
  Future<Member?> _pickMemberFromList({
    required Sex gender,
    required Map<String, String> blockedReasons,
    String? currentMemberId,
  }) async {
    String q = '';
    final screenH = MediaQuery.of(context).size.height;
    final filteredBase = _members.where((m) => m.sex == gender).toList();
    return showDialog<Member>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final filtered = filteredBase.where((m) {
            final qq = q.trim().toLowerCase();
            if (qq.isEmpty) return true;
            return '${m.id} ${m.fullName} ${m.phone}'.toLowerCase().contains(qq);
          }).toList();
          return AlertDialog(
            title: Text(gender == Sex.male ? 'Choisir un homme membre' : 'Choisir une femme membre'),
            content: SizedBox(
              width: 480,
              height: screenH * 0.68,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Nom, code membre ou téléphone'),
                    onChanged: (v) => setLocal(() => q = v),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('Aucun membre trouvé.'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final m = filtered[i];
                              final blocked = blockedReasons[m.id];
                              final canUse = blocked == null || m.id == (currentMemberId ?? '');
                              return ListTile(
                                dense: true,
                                title: Text('${m.id} • ${m.fullName}'),
                                subtitle: Text(
                                  blocked == null ? m.phone : '$blocked • ${m.phone}',
                                ),
                                enabled: canUse,
                                onTap: canUse ? () => Navigator.pop(ctx, m) : null,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
            ],
          );
        },
      ),
    );
  }

  Map<String, _RelationItem> _activeOpenRelationByMember({String? excludeRelationId}) {
    final out = <String, _RelationItem>{};
    for (final x in _items) {
      if (!x.isOpen || x.id == excludeRelationId) continue;
      if (x.memberCodeA.trim().isNotEmpty) out[x.memberCodeA.trim()] = x;
      if (x.memberCodeB.trim().isNotEmpty) out[x.memberCodeB.trim()] = x;
    }
    return out;
  }

  DateTime? _parseFlexibleDate(String raw) {
    final v = raw.trim();
    final d = DateTime.tryParse(v);
    if (d != null) return DateTime(d.year, d.month, d.day, d.hour, d.minute);
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(v);
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final da = int.parse(m.group(3)!);
    final parsed = DateTime.tryParse('$y-${mo.toString().padLeft(2, '0')}-${da.toString().padLeft(2, '0')}T00:00:00');
    if (parsed == null) return null;
    if (parsed.year != y || parsed.month != mo || parsed.day != da) return null;
    return parsed;
  }
}

class _RelationItem {
  String id;
  String personA;
  String personB;
  bool isMemberA;
  bool isMemberB;
  String memberCodeA;
  String memberCodeB;
  String parentsA;
  String parentsB;
  String ageA;
  String ageB;
  String addressA;
  String addressB;
  String step;
  String mentor;
  String nextAppointment;
  bool isOpen;
  List<String> history;

  _RelationItem({
    required this.id,
    required this.personA,
    required this.personB,
    required this.isMemberA,
    required this.isMemberB,
    required this.memberCodeA,
    required this.memberCodeB,
    required this.parentsA,
    required this.parentsB,
    required this.ageA,
    required this.ageB,
    required this.addressA,
    required this.addressB,
    required this.step,
    required this.mentor,
    required this.nextAppointment,
    required this.isOpen,
    required this.history,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'personA': personA,
        'personB': personB,
        'isMemberA': isMemberA,
        'isMemberB': isMemberB,
        'memberCodeA': memberCodeA,
        'memberCodeB': memberCodeB,
        'parentsA': parentsA,
        'parentsB': parentsB,
        'ageA': ageA,
        'ageB': ageB,
        'addressA': addressA,
        'addressB': addressB,
        'step': step,
        'mentor': mentor,
        'nextAppointment': nextAppointment,
        'isOpen': isOpen,
        'history': history,
      };

  static _RelationItem fromMap(Map<String, dynamic> m) => _RelationItem(
        id: (m['id'] ?? '').toString(),
        personA: (m['personA'] ?? '').toString(),
        personB: (m['personB'] ?? '').toString(),
        isMemberA: (m['isMemberA'] ?? false) == true,
        isMemberB: (m['isMemberB'] ?? false) == true,
        memberCodeA: (m['memberCodeA'] ?? '').toString(),
        memberCodeB: (m['memberCodeB'] ?? '').toString(),
        parentsA: (m['parentsA'] ?? '').toString(),
        parentsB: (m['parentsB'] ?? '').toString(),
        ageA: (m['ageA'] ?? '').toString(),
        ageB: (m['ageB'] ?? '').toString(),
        addressA: (m['addressA'] ?? '').toString(),
        addressB: (m['addressB'] ?? '').toString(),
        step: (m['step'] ?? 'decouverte').toString(),
        mentor: (m['mentor'] ?? '').toString(),
        nextAppointment: (m['nextAppointment'] ?? '').toString(),
        isOpen: (m['isOpen'] ?? true) == true,
        history: (m['history'] is List) ? (m['history'] as List).map((e) => e.toString()).toList() : <String>[],
      );
}
