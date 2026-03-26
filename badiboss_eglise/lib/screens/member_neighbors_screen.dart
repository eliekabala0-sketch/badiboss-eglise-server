import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/member.dart';
import '../services/local_members_store.dart';

class MemberNeighborsScreen extends StatefulWidget {
  const MemberNeighborsScreen({super.key});

  @override
  State<MemberNeighborsScreen> createState() => _MemberNeighborsScreenState();
}

class _MemberNeighborsScreenState extends State<MemberNeighborsScreen> {
  bool _loading = true;
  String _error = '';
  Member? _me;
  List<Member> _neighbors = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final myPhone = (prefs.getString('auth_phone') ?? '').trim();
      final churchCode = (prefs.getString('auth_church_code') ?? '').trim();

      if (myPhone.isEmpty || churchCode.isEmpty) {
        setState(() {
          _loading = false;
          _error = "Session invalide: phone/churchCode manquant.";
        });
        return;
      }

      final all = await LocalMembersStore.loadByChurch(churchCode);
      final me = all.where((m) => m.phone == myPhone).isNotEmpty
          ? all.firstWhere((m) => m.phone == myPhone)
          : null;

      if (me == null) {
        setState(() {
          _loading = false;
          _error = "Ton profil membre n'est pas trouvé localement.";
        });
        return;
      }

      // ✅ règle verrouillée: voisins seulement si membre validé
      if (me.status != MemberStatus.active) {
        setState(() {
          _loading = false;
          _error = "Accès refusé: ton compte n'est pas encore validé (statut: ${me.status.name}).";
        });
        return;
      }

      final neigh = await LocalMembersStore.neighborsOf(me);

      setState(() {
        _me = me;
        _neighbors = neigh;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = "Erreur: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;

    return Scaffold(
      appBar: AppBar(title: const Text('Mes voisins')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error))
              : Column(
                  children: [
                    if (me != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Card(
                          child: ListTile(
                            title: Text(me.fullName),
                            subtitle: Text(
                              "Quartier: ${me.quartier} • Zone: ${me.zone}\nCommune: ${me.commune}",
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: _neighbors.isEmpty
                          ? const Center(child: Text("Aucun voisin trouvé (même zone/quartier)."))
                          : ListView.separated(
                              itemCount: _neighbors.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final m = _neighbors[i];
                                return ListTile(
                                  title: Text(m.fullName),
                                  subtitle: Text("${m.phone}\n${m.quartier} • ${m.zone}"),
                                  isThreeLine: true,
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _init,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
