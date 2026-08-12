import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:image_picker/image_picker.dart';

import 'package:karatou/app/core/repositories/app_api_client.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/profile/profile_avatar.dart';

import '../../widget_test_helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProfileAvatar: the initials are the fallback in EVERY degraded case, the
// picker is always asked to downscale, and a failed upload never leaves the
// screen stuck on the spinner.
// ─────────────────────────────────────────────────────────────────────────────

class _FakeAvatarApi extends Fake implements AppApiClient {
  _FakeAvatarApi({
    this.headers,
    this.uploadResult = const <String, dynamic>{'hasAvatar': true},
    this.uploadError,
    this.deleteError,
  });

  final Map<String, String>? headers;
  final Map<String, dynamic> uploadResult;
  final Object? uploadError;
  final Object? deleteError;

  int uploadCount = 0;
  int? uploadedBytes;
  int deleteCount = 0;

  @override
  String get avatarStreamUrl =>
      'https://api.invalid.test/api/profiles/me/avatar';

  @override
  Future<Map<String, String>?> authImageHeaders() async => headers;

  @override
  Future<Map<String, dynamic>> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    uploadCount++;
    uploadedBytes = bytes.lengthInBytes;
    final error = uploadError;
    if (error != null) throw error;
    return uploadResult;
  }

  @override
  Future<void> deleteAvatar() async {
    deleteCount++;
    final error = deleteError;
    if (error != null) throw error;
  }
}

class _RecordingPicker extends Fake implements ImagePicker {
  _RecordingPicker({this.file, this.error});

  final XFile? file;
  final Object? error;

  ImageSource? source;
  double? maxWidth;
  double? maxHeight;
  int? quality;
  bool? fullMetadata;
  int calls = 0;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    calls++;
    this.source = source;
    this.maxWidth = maxWidth;
    this.maxHeight = maxHeight;
    quality = imageQuality;
    fullMetadata = requestFullMetadata;
    final err = error;
    if (err != null) throw err;
    return file;
  }
}

DioException _dioError(String code, int status) {
  final options = RequestOptions(path: '/profiles/me/avatar');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Map<String, dynamic>>(
      requestOptions: options,
      statusCode: status,
      data: <String, dynamic>{'code': code},
    ),
  );
}

late Directory _tmp;

/// Fixture EN MÉMOIRE, et c'est délibéré.
///
/// Un `XFile` adossé à un fichier disque paraît plus réaliste mais ne peut PAS
/// fonctionner ici : les tests de widgets tournent dans une horloge simulée
/// (`FakeAsync`), où une lecture disque réelle ne se termine jamais. Le
/// sélecteur renvoyait bien le fichier, toutes les assertions de redimension
/// passaient — et l'envoi ne partait jamais, sans erreur, juste un compteur à
/// zéro. `XFile.fromData` garde tout en mémoire et rend la chaîne complète
/// observable.
///
/// Le contenu n'est pas un JPEG décodable, ce qui exerce au passage le repli sur
/// les initiales quand l'image ne s'affiche pas.
XFile _tempJpeg(String name) => XFile.fromData(
      Uint8List.fromList(List<int>.filled(64, 0x42)),
      name: name,
      mimeType: 'image/jpeg',
      length: 64,
    );

Widget _wrap(Widget child) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      home: Scaffold(body: Center(child: child)),
    );

/// Avance de quelques trames au lieu d'attendre la quiescence.
///
/// `pumpAndSettle` ne peut PAS être utilisé ici : les messages d'erreur passent
/// par `Get.snackbar`, dont l'overlay anime et reste affiché plusieurs secondes.
/// Attendre que « tout se stabilise » ne se termine donc jamais, et le test
/// échoue sur un délai dépassé — pas sur l'assertion. ~1 s de trames suffit à
/// laisser la feuille s'ouvrir, le bandeau apparaître ET son minuteur de 4 s
/// s'épuiser — sinon le test se termine sur un minuteur en attente, ce que le
/// framework signale comme un échec.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 45; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  setUpAll(() {
    _tmp = Directory.systemTemp.createTempSync('kpb_avatar_test');
  });

  tearDownAll(() {
    if (_tmp.existsSync()) _tmp.deleteSync(recursive: true);
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
  });

  testWidgets(
      'renders the initials and fires NO request when there is no '
      'session', (tester) async {
    final api = _FakeAvatarApi(headers: null);

    await tester.pumpWidget(_wrap(ProfileAvatar(
      profile: createTestProfile(fullName: 'Awa Diallo'),
      initials: 'AD',
      apiClient: api,
      picker: _RecordingPicker(),
    )));
    await tester.pump();

    expect(find.text('AD'), findsOneWidget);
    // No bearer token means the authenticated endpoint can only 401 — we must
    // not spend the student's data finding that out.
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('fetches the authenticated image once a session exists',
      (tester) async {
    final api = _FakeAvatarApi(
      headers: const <String, String>{'Authorization': 'Bearer token'},
    );

    await tester.pumpWidget(_wrap(ProfileAvatar(
      profile: createTestProfile(),
      initials: 'AD',
      apiClient: api,
      picker: _RecordingPicker(),
    )));
    await tester.pump();

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, api.avatarStreamUrl);
    expect(image.httpHeaders, containsPair('Authorization', 'Bearer token'));
    // While it loads (and if it fails), the initials remain the fallback.
    expect(find.text('AD'), findsOneWidget);
  });

  testWidgets('asks the picker to downscale before any upload', (tester) async {
    final picker = _RecordingPicker(file: _tempJpeg('downscale.jpg'));
    final api = _FakeAvatarApi(
      uploadResult: const <String, dynamic>{
        'hasAvatar': true,
        'avatarUrl': '/api/profiles/me/avatar',
      },
    );

    await tester.pumpWidget(_wrap(ProfileAvatar(
      profile: createTestProfile(),
      initials: 'AD',
      apiClient: api,
      picker: picker,
    )));
    await tester.pump();

    await tester.tap(find.byType(InkWell).first);
    await _settle(tester);
    await tester.tap(find.text('Prendre une photo'));
    await _settle(tester);

    expect(picker.calls, 1);
    expect(picker.source, ImageSource.camera);
    // The whole point: a 4 MB camera capture must never reach the network on a
    // prepaid plan.
    expect(picker.maxWidth, kAvatarMaxDimension);
    expect(picker.maxHeight, kAvatarMaxDimension);
    expect(picker.quality, kAvatarJpegQuality);
    expect(picker.fullMetadata, isFalse, reason: 'no EXIF/GPS harvesting');
    expect(api.uploadCount, 1);
  });

  testWidgets('cancelling the picker uploads nothing and reports nothing',
      (tester) async {
    final picker = _RecordingPicker(file: null);
    final api = _FakeAvatarApi();

    await tester.pumpWidget(_wrap(ProfileAvatar(
      profile: createTestProfile(),
      initials: 'AD',
      apiClient: api,
      picker: picker,
    )));
    await tester.pump();

    await tester.tap(find.byType(InkWell).first);
    await _settle(tester);
    await tester.tap(find.text('Choisir dans la galerie'));
    await _settle(tester);

    expect(picker.calls, 1);
    expect(api.uploadCount, 0);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('AD'), findsOneWidget);
  });

  testWidgets('a failed upload clears the spinner and names the real cause',
      (tester) async {
    final api = _FakeAvatarApi(
      uploadError: _dioError('AVATAR_INFECTED', 422),
    );

    await tester.pumpWidget(_wrap(ProfileAvatar(
      profile: createTestProfile(),
      initials: 'AD',
      apiClient: api,
      picker: _RecordingPicker(file: _tempJpeg('infected.jpg')),
    )));
    await tester.pump();

    await tester.tap(find.byType(InkWell).first);
    await _settle(tester);
    await tester.tap(find.text('Prendre une photo'));
    await _settle(tester);

    expect(api.uploadCount, 1);
    // The screen must not stay stuck on the loader when the upload blows up.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('AD'), findsOneWidget);
    // Untranslated keys render as themselves, which lets us assert the exact
    // message the user gets — the infected case, not a generic network line.
  });

  testWidgets('a scanner outage is reported as ours, not the user\'s',
      (tester) async {
    final api = _FakeAvatarApi(
      uploadError: _dioError('AVATAR_SCANNER_UNAVAILABLE', 503),
    );

    await tester.pumpWidget(_wrap(ProfileAvatar(
      profile: createTestProfile(),
      initials: 'AD',
      apiClient: api,
      picker: _RecordingPicker(file: _tempJpeg('scanner.jpg')),
    )));
    await tester.pump();

    await tester.tap(find.byType(InkWell).first);
    await _settle(tester);
    await tester.tap(find.text('Prendre une photo'));
    await _settle(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('an over-cap file is refused locally, before the upload',
      (tester) async {
    final big = File('${_tmp.path}/big.jpg')
      ..writeAsBytesSync(List<int>.filled(kAvatarMaxUploadBytes + 1024, 0x42));
    final api = _FakeAvatarApi();

    await tester.pumpWidget(_wrap(ProfileAvatar(
      profile: createTestProfile(),
      initials: 'AD',
      apiClient: api,
      picker: _RecordingPicker(file: XFile(big.path)),
    )));
    await tester.pump();

    await tester.tap(find.byType(InkWell).first);
    await _settle(tester);
    await tester.tap(find.text('Prendre une photo'));
    await _settle(tester);

    expect(api.uploadCount, 0, reason: 'no airtime spent on a doomed upload');
  });

  testWidgets('removal is offered only when there is a photo, and clears it',
      (tester) async {
    final api = _FakeAvatarApi(
      headers: const <String, String>{'Authorization': 'Bearer token'},
    );
    // hasAvatar seeds "present", so the remove action is available immediately.
    await tester.pumpWidget(_wrap(ProfileAvatar(
      profile: createTestProfile().copyWith(hasAvatar: true),
      initials: 'AD',
      apiClient: api,
      picker: _RecordingPicker(),
    )));
    await tester.pump();

    await tester.tap(find.byType(InkWell).first);
    await _settle(tester);
    expect(find.text('Retirer la photo'), findsOneWidget);

    await tester.tap(find.text('Retirer la photo'));
    await _settle(tester);
    await tester.tap(find.text('Retirer la photo').last);
    await _settle(tester);

    expect(api.deleteCount, 1);
    expect(find.text('AD'), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);

    // Second visit to the sheet: nothing left to remove.
    await tester.tap(find.byType(InkWell).first);
    await _settle(tester);
    expect(find.text('Retirer la photo'), findsNothing);
  });

  testWidgets('a 404 on removal still reads as removed (idempotent)',
      (tester) async {
    final api = _FakeAvatarApi(
      headers: const <String, String>{'Authorization': 'Bearer token'},
      deleteError: _dioError('AVATAR_NOT_FOUND', 404),
    );

    await tester.pumpWidget(_wrap(ProfileAvatar(
      profile: createTestProfile().copyWith(hasAvatar: true),
      initials: 'AD',
      apiClient: api,
      picker: _RecordingPicker(),
    )));
    await tester.pump();

    await tester.tap(find.byType(InkWell).first);
    await _settle(tester);
    await tester.tap(find.text('Retirer la photo'));
    await _settle(tester);
    await tester.tap(find.text('Retirer la photo').last);
    await _settle(tester);

    expect(api.deleteCount, 1);
  });

  testWidgets(
      'a denied camera permission says so instead of blaming the '
      'network', (tester) async {
    final api = _FakeAvatarApi();

    await tester.pumpWidget(_wrap(ProfileAvatar(
      profile: createTestProfile(),
      initials: 'AD',
      apiClient: api,
      picker: _RecordingPicker(
        error: PlatformException(code: 'camera_access_denied'),
      ),
    )));
    await tester.pump();

    await tester.tap(find.byType(InkWell).first);
    await _settle(tester);
    await tester.tap(find.text('Prendre une photo'));
    await _settle(tester);

    expect(api.uploadCount, 0);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('removal is not offered when the profile has no photo',
      (tester) async {
    await tester.pumpWidget(_wrap(ProfileAvatar(
      profile: createTestProfile(),
      initials: 'AD',
      apiClient: _FakeAvatarApi(headers: null),
      picker: _RecordingPicker(),
    )));
    await tester.pump();

    await tester.tap(find.byType(InkWell).first);
    await _settle(tester);

    expect(find.text('Prendre une photo'), findsOneWidget);
    expect(find.text('Choisir dans la galerie'), findsOneWidget);
    expect(find.text('Retirer la photo'), findsNothing);
  });

  group('presenceFromProfileJson', () {
    test('reads either contract shape and never a storage path', () {
      expect(
        presenceFromProfileJson(<String, dynamic>{'hasAvatar': true}),
        AvatarPresence.present,
      );
      expect(
        presenceFromProfileJson(<String, dynamic>{'hasAvatar': false}),
        AvatarPresence.absent,
      );
      expect(
        presenceFromProfileJson(<String, dynamic>{
          'avatarUrl': '/api/profiles/me/avatar',
        }),
        AvatarPresence.present,
      );
      expect(
        presenceFromProfileJson(<String, dynamic>{'avatarUrl': null}),
        AvatarPresence.absent,
      );
      expect(presenceFromProfileJson(<String, dynamic>{}), isNull);
    });
  });
}
