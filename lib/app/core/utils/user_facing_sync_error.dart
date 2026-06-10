import 'package:dio/dio.dart';

/// Maps sync/API failures to short, locale-aware messages for UI display.
/// Technical details should be logged separately (Crashlytics / logging).
String userFacingSyncError(Object error, String localeCode) {
  final fr = localeCode.toLowerCase().startsWith('fr');
  String t(String frMsg, String enMsg) => fr ? frMsg : enMsg;

  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return t(
          'Impossible de joindre le serveur. Vérifiez votre connexion.',
          'Could not reach the server. Check your connection.',
        );
      case DioExceptionType.cancel:
        return t(
          'Synchronisation annulée.',
          'Sync was cancelled.',
        );
      default:
        break;
    }

    final code = error.response?.statusCode;
    if (code == 401 || code == 403) {
      return t(
        'Session expirée ou accès refusé. Reconnectez-vous.',
        'Session expired or access denied. Please sign in again.',
      );
    }
    if (code == 429) {
      return t(
        'Trop de requêtes serveur. Réessayez dans une minute.',
        'Too many server requests. Try again in a minute.',
      );
    }
    if (code != null && code >= 500) {
      return t(
        'Le serveur est temporairement indisponible. Réessayez plus tard.',
        'The server is temporarily unavailable. Try again later.',
      );
    }
  }

  return t(
    'La synchronisation a échoué. Réessayez.',
    'Sync failed. Please try again.',
  );
}
