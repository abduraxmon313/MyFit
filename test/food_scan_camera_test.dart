import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' as picker;
import 'package:myfit/models/food_nutrition.dart';
import 'package:myfit/screens/food_scan_page.dart';
import 'package:myfit/screens/meals_page.dart';
import 'package:myfit/widgets/meal_type_picker.dart';
import 'package:myfit/services/food_vision_service.dart';

const _back = CameraDescription(
  name: 'back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);

/// Minimal in-memory camera: one back camera, 1280x720 preview.
class FakeCameraPlatform extends CameraPlatform {
  FakeCameraPlatform({this.denied = false});

  final bool denied;
  final calls = <String>[];
  final _initialized = StreamController<CameraInitializedEvent>.broadcast();

  /// Open streams that never emit (like a healthy camera).
  final _errors = StreamController<CameraErrorEvent>.broadcast();
  final _closing = StreamController<CameraClosingEvent>.broadcast();

  @override
  Future<List<CameraDescription>> availableCameras() async => [_back];

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async {
    if (denied) throw CameraException('CameraAccessDenied', 'denied');
    calls.add('create:${cameraDescription.name}');
    return 1;
  }

  @override
  Future<int> createCamera(
    CameraDescription cameraDescription,
    ResolutionPreset? resolutionPreset, {
    bool enableAudio = false,
  }) => createCameraWithSettings(cameraDescription, const MediaSettings());

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    scheduleMicrotask(
      () => _initialized.add(
        CameraInitializedEvent(
          cameraId,
          1280,
          720,
          ExposureMode.auto,
          true,
          FocusMode.auto,
          true,
        ),
      ),
    );
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      _initialized.stream;

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => _errors.stream;

  @override
  Stream<CameraClosingEvent> onCameraClosing(int cameraId) => _closing.stream;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();

  @override
  Future<XFile> takePicture(int cameraId) async {
    calls.add('takePicture');
    return XFile.fromData(
      Uint8List.fromList(const [0xff, 0xd8, 0xff]),
      path: '/tmp/in-app-photo.jpg',
      name: 'in-app-photo.jpg',
    );
  }

  @override
  Widget buildPreview(int cameraId) =>
      const ColoredBox(key: Key('fake-camera-view'), color: Colors.black);

  @override
  Future<void> dispose(int cameraId) async => calls.add('dispose');

  @override
  Future<double> getMinZoomLevel(int cameraId) async => 1;
  @override
  Future<double> getMaxZoomLevel(int cameraId) async => 1;
  @override
  Future<double> getMinExposureOffset(int cameraId) async => 0;
  @override
  Future<double> getMaxExposureOffset(int cameraId) async => 0;
  @override
  Future<double> getExposureOffsetStepSize(int cameraId) async => 0;
  @override
  Future<void> lockCaptureOrientation(
    int cameraId,
    DeviceOrientation orientation,
  ) async {}
  @override
  Future<void> unlockCaptureOrientation(int cameraId) async {}
  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async {}
  @override
  Future<void> setExposureMode(int cameraId, ExposureMode mode) async {}
  @override
  Future<void> setFocusMode(int cameraId, FocusMode mode) async {}
  @override
  Future<void> pausePreview(int cameraId) async {}
  @override
  Future<void> resumePreview(int cameraId) async {}
}

class FakeVision extends FoodVisionService {
  final analyzed = <String>[];

  @override
  Future<FoodNutrition> analyzeFile(String imagePath) async {
    analyzed.add(imagePath);
    return const FoodNutrition(
      fdcId: 1,
      name: 'Tomato',
      localName: 'Pomidor',
      calories: 18,
      protein: 0.9,
      fat: 0.2,
      carbohydrates: 3.9,
      water: 95,
      confidence: .9,
    );
  }
}

Future<void> pumpScan(
  WidgetTester tester, {
  required FakeVision vision,
  Future<picker.XFile?> Function()? gallery,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 860);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: FoodScanPage(service: vision, pickFromGallery: gallery),
    ),
  );
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

void main() {
  late FakeCameraPlatform platform;

  setUp(() {
    platform = FakeCameraPlatform();
    CameraPlatform.instance = platform;
  });

  testWidgets('opens the camera inside the frame with all buttons', (
    tester,
  ) async {
    await pumpScan(tester, vision: FakeVision());
    // Live preview behind the frame; no external camera app was launched.
    expect(find.byKey(const Key('camera-preview')), findsOneWidget);
    expect(find.byKey(const Key('fake-camera-view')), findsOneWidget);
    expect(find.text('Ovqatni ramka ichiga joylashtiring'), findsOneWidget);
    expect(find.text('Galereya'), findsOneWidget);
    expect(find.text('Qayta olish'), findsOneWidget);
    expect(platform.calls, ['create:back']);
  });

  testWidgets('shutter takes the photo in-app and analyzes it', (tester) async {
    final vision = FakeVision();
    await pumpScan(tester, vision: vision);
    await tester.tap(find.bySemanticsLabel('Suratga olish'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(platform.calls, contains('takePicture'));
    expect(vision.analyzed, ['/tmp/in-app-photo.jpg']);
    expect(find.text('Tomato'), findsOneWidget);
    expect(find.text('Hisoblash va qo‘shish'), findsOneWidget);
  });

  testWidgets('gallery button picks a photo', (tester) async {
    final vision = FakeVision();
    await pumpScan(
      tester,
      vision: vision,
      gallery: () async => picker.XFile('/tmp/gallery.jpg'),
    );
    await tester.tap(find.text('Galereya'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(vision.analyzed, ['/tmp/gallery.jpg']);
    expect(platform.calls, isNot(contains('takePicture')));
  });

  testWidgets('without camera permission the gallery still works', (
    tester,
  ) async {
    CameraPlatform.instance = FakeCameraPlatform(denied: true);
    final vision = FakeVision();
    await pumpScan(
      tester,
      vision: vision,
      gallery: () async => picker.XFile('/tmp/gallery.jpg'),
    );
    expect(find.byKey(const Key('camera-error')), findsOneWidget);
    expect(find.textContaining('Kameraga ruxsat berilmagan'), findsOneWidget);
    expect(find.text('Galereya'), findsOneWidget);
    await tester.tap(find.text('Galereya'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(vision.analyzed, ['/tmp/gallery.jpg']);
  });

  test('suggested meal follows the time of day', () {
    expect(suggestedMealType(DateTime(2026, 1, 1, 8)), MealType.breakfast);
    expect(suggestedMealType(DateTime(2026, 1, 1, 13)), MealType.lunch);
    expect(suggestedMealType(DateTime(2026, 1, 1, 19)), MealType.dinner);
    expect(suggestedMealType(DateTime(2026, 1, 1, 23)), MealType.fifthSnack);
  });

  testWidgets('no "AI" wording; the chosen meal is returned', (tester) async {
    final vision = FakeVision();
    FoodNutrition? added;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  added = await Navigator.push<FoodNutrition>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FoodScanPage(
                        service: vision,
                        pickFromGallery: () async => picker.XFile('/tmp/g.jpg'),
                      ),
                    ),
                  ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Ovqat skaneri'), findsOneWidget);
    expect(find.textContaining('AI'), findsNothing);

    await tester.tap(find.text('Galereya'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.textContaining('AI'), findsNothing);
    expect(find.text('Aniqlandi · 90%'), findsOneWidget);
    expect(find.text('Qaysi ovqatlanishga qo‘shilsin?'), findsOneWidget);
    for (final meal in MealType.values) {
      expect(find.byKey(Key('meal-${meal.name}')), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('meal-lunch')));
    await tester.pump();
    await tester.tap(find.text('Hisoblash va qo‘shish'));
    await tester.pumpAndSettle();
    expect(added?.mealType, 'lunch');
    expect(added?.name, 'Tomato');
  });
}
