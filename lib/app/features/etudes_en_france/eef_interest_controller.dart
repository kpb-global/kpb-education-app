import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/models/eef.dart';
import '../../core/repositories/app_api_client.dart';
import '../../core/services/analytics_service.dart';

/// Où en est la déclaration d'intérêt, du point de vue de l'écran.
enum EefInterestPhase { initial, loading, ready, submitting, failed }

/// Pourquoi une déclaration a échoué — grossier, exprès.
///
/// Trois causes seulement, parce que l'écran n'a que trois choses différentes à
/// dire : « vérifie ta connexion », « reconnecte-toi », « réessaie plus tard ».
/// Un catalogue plus fin aurait produit des messages que personne ne sait
/// traduire en geste.
enum EefInterestFailure { network, unauthorized, server }

/// L'état de la vitrine, séparé de son rendu.
///
/// ## Pourquoi un contrôleur et pas du `setState` dans l'écran
///
/// Parce que la règle qui compte ici est testable sans peindre un pixel : **un
/// échec d'envoi ne doit JAMAIS produire un état de succès**. Le masquage
/// `documentUploadEnabled` existe parce qu'un écran cochait « fourni ✓ » avant
/// l'appel réseau puis avalait l'échec dans Crashlytics ; l'étudiant voyait un
/// document envoyé que le conseiller n'a jamais reçu.
///
/// Ici la transition est explicite : `submitting` va vers `ready` avec
/// `interest.declared == true` UNIQUEMENT quand le serveur a répondu, et vers
/// `failed` sinon. Il n'existe aucun chemin de code qui marque `declared` sans
/// réponse — et un test le vérifie plutôt que de faire confiance à la lecture.
class EefInterestController extends ChangeNotifier {
  EefInterestController(
      {required AppApiClient apiClient, AnalyticsService? analytics})
      : _apiClient = apiClient,
        _analytics = analytics ?? AnalyticsService.instance;

  final AppApiClient _apiClient;
  final AnalyticsService _analytics;

  EefInterestPhase _phase = EefInterestPhase.initial;
  EefInterest _interest = EefInterest.notDeclared;
  EefInterestFailure? _failure;

  EefInterestPhase get phase => _phase;
  EefInterest get interest => _interest;
  EefInterestFailure? get failure => _failure;

  bool get declared => _interest.declared;
  bool get busy =>
      _phase == EefInterestPhase.loading ||
      _phase == EefInterestPhase.submitting;

  /// Lit l'état existant, pour ne pas reposer la question à qui a déjà répondu.
  ///
  /// Un échec de LECTURE n'est pas un échec d'envoi : on retombe silencieusement
  /// sur « pas déclaré ». Au pire on repose la question à quelqu'un qui avait
  /// répondu — coût réel mais réparable, à comparer au cas inverse, qui serait
  /// de masquer le bouton et de perdre la déclaration.
  Future<void> load() async {
    if (_phase == EefInterestPhase.loading) return;
    _phase = EefInterestPhase.loading;
    notifyListeners();

    try {
      final raw = await _apiClient.getEefInterest();
      _interest = EefInterest.fromJson(raw);
    } catch (_) {
      _interest = EefInterest.notDeclared;
    }

    _failure = null;
    _phase = EefInterestPhase.ready;
    notifyListeners();
  }

  /// Déclare l'intérêt. Rend `true` seulement si le SERVEUR a confirmé.
  Future<bool> submit({
    String? currentLevel,
    String? targetLevel,
    List<String> fieldIds = const <String>[],
    bool wantsPremium = false,
  }) async {
    if (_phase == EefInterestPhase.submitting) return false;

    _phase = EefInterestPhase.submitting;
    _failure = null;
    notifyListeners();

    try {
      final raw = await _apiClient.declareEefInterest(
        currentLevel: currentLevel,
        targetLevel: targetLevel,
        fieldIds: fieldIds,
        wantsPremium: wantsPremium,
      );

      final saved = EefInterest.fromJson(raw);

      // Une réponse 2xx dont le corps ne dit PAS `declared: true` est traitée
      // comme un échec. C'est le cas limite qui a produit le défaut d'origine :
      // le transport a réussi, l'enregistrement non, et l'app a affiché un
      // succès. Un 200 n'est pas une preuve d'écriture — le corps l'est.
      if (!saved.declared) {
        _failure = EefInterestFailure.server;
        _phase = EefInterestPhase.failed;
        notifyListeners();
        _analytics.logEefInterestFailed(_failure!.name);
        return false;
      }

      _interest = saved;
      _phase = EefInterestPhase.ready;
      notifyListeners();

      _analytics.logEefInterestDeclared(
        wantsPremium: saved.wantsPremium,
        fieldCount: saved.fieldIds.length,
        currentLevel: saved.currentLevel,
      );
      return true;
    } catch (error) {
      _failure = classifyFailure(error);
      _phase = EefInterestPhase.failed;
      notifyListeners();
      _analytics.logEefInterestFailed(_failure!.name);
      return false;
    }
  }

  /// Range l'erreur dans l'une des trois cases que l'écran sait dire.
  @visibleForTesting
  static EefInterestFailure classifyFailure(Object error) {
    if (error is! DioException) return EefInterestFailure.server;

    final status = error.response?.statusCode;
    if (status == 401 || status == 403) return EefInterestFailure.unauthorized;
    if (status != null && status >= 400) return EefInterestFailure.server;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return EefInterestFailure.network;
      default:
        return EefInterestFailure.server;
    }
  }
}
