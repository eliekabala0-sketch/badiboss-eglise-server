import '../auth/stores/session_store.dart';
import '../services/church_service.dart';

/// Code église pour appels API : d’abord la session (pasteur/membre/…),
/// sinon le scope mémoire super admin (`ChurchService` après « Entrer dans l’église »).
Future<String> resolveActiveChurchCode() async {
  final s = await const SessionStore().read();
  final fromSession = (s?.churchCode ?? '').trim();
  if (fromSession.isNotEmpty) return fromSession;
  return ChurchService.getChurchCode().trim();
}
