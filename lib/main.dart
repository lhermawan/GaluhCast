import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rtmp_streaming/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'widgets/galuh_cast_logo.dart';

const _serverBaseUrl = 'rtmp://ams.ciamiskab.go.id/live';
const _defaultStreamId = 'Live_5';
const _antMediaBroadcastsApiUrl =
    'https://ams.ciamiskab.go.id:5443/live/rest/v2/broadcasts/list/0/50';
const _antMediaApiTimeout = Duration(seconds: 5);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const GaluhCastApp());
}

class GaluhCastApp extends StatelessWidget {
  const GaluhCastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GaluhCast',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF18A999),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101416),
        useMaterial3: true,
      ),
      home: const BroadcastPage(),
    );
  }
}

class GaluhCastLogo extends StatelessWidget {
  const GaluhCastLogo({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo GaluhCast',
      child: CustomPaint(
        size: Size.square(size),
        painter: const _GaluhCastLogoPainter(),
      ),
    );
  }
}

class _GaluhCastLogoPainter extends CustomPainter {
  const _GaluhCastLogoPainter();

  static const _teal = Color(0xFF18A999);
  static const _deep = Color(0xFF101416);
  static const _gold = Color(0xFFFFC857);
  static const _red = Color(0xFFE84A5F);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = size.width * 0.24;
    final badge = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_teal, Color(0xFF0E6F68), _deep],
        stops: [0, 0.56, 1],
      ).createShader(rect);
    canvas.drawRRect(badge, background);

    final highlight = Paint()..color = Colors.white.withValues(alpha: 0.12);
    final highlightPath = Path()
      ..moveTo(size.width * 0.12, 0)
      ..lineTo(size.width * 0.72, 0)
      ..lineTo(size.width * 0.36, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(highlightPath, highlight);

    final cameraPaint = Paint()..color = Colors.white;
    final cameraBody = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.24,
        size.height * 0.33,
        size.width * 0.44,
        size.height * 0.34,
      ),
      Radius.circular(size.width * 0.08),
    );
    canvas.drawRRect(cameraBody, cameraPaint);

    final cameraNose = Path()
      ..moveTo(size.width * 0.66, size.height * 0.42)
      ..lineTo(size.width * 0.82, size.height * 0.34)
      ..lineTo(size.width * 0.82, size.height * 0.66)
      ..lineTo(size.width * 0.66, size.height * 0.58)
      ..close();
    canvas.drawPath(cameraNose, cameraPaint);

    final lensPaint = Paint()..color = _deep.withValues(alpha: 0.88);
    canvas.drawCircle(
      Offset(size.width * 0.46, size.height * 0.50),
      size.width * 0.105,
      lensPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.46, size.height * 0.50),
      size.width * 0.042,
      Paint()..color = _teal,
    );

    final liveDot = Paint()..color = _red;
    canvas.drawCircle(
      Offset(size.width * 0.62, size.height * 0.39),
      size.width * 0.042,
      liveDot,
    );

    final wavePaint = Paint()
      ..color = _gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round;
    final waveCenter = Offset(size.width * 0.50, size.height * 0.50);
    for (final scale in [0.72, 0.93]) {
      canvas.drawArc(
        Rect.fromCircle(center: waveCenter, radius: size.width * scale),
        -0.76,
        1.52,
        false,
        wavePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BroadcastProfile {
  const BroadcastProfile({
    required this.name,
    required this.preset,
    required this.width,
    required this.height,
    required this.defaultBitrateKbps,
  });

  final String name;
  final ResolutionPreset preset;
  final int width;
  final int height;
  final int defaultBitrateKbps;
}

const _profiles = <BroadcastProfile>[
  BroadcastProfile(
    name: 'Auto kamera',
    preset: ResolutionPreset.max,
    width: 1920,
    height: 1080,
    defaultBitrateKbps: 4500,
  ),
  BroadcastProfile(
    name: '1080p',
    preset: ResolutionPreset.veryHigh,
    width: 1920,
    height: 1080,
    defaultBitrateKbps: 4500,
  ),
  BroadcastProfile(
    name: '720p',
    preset: ResolutionPreset.high,
    width: 1280,
    height: 720,
    defaultBitrateKbps: 2500,
  ),
  BroadcastProfile(
    name: '480p',
    preset: ResolutionPreset.medium,
    width: 640,
    height: 480,
    defaultBitrateKbps: 1200,
  ),
  BroadcastProfile(
    name: '360p hemat',
    preset: ResolutionPreset.low,
    width: 352,
    height: 288,
    defaultBitrateKbps: 700,
  ),
];

enum AntMediaConnectionStatus {
  idle,
  connecting,
  connected,
  disconnected,
  error,
}

class AntMediaServerStatus {
  const AntMediaServerStatus({
    required this.status,
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
    this.checkedAt,
  });

  final AntMediaConnectionStatus status;
  final String title;
  final String detail;
  final IconData icon;
  final Color color;
  final DateTime? checkedAt;

  bool get isConnected => status == AntMediaConnectionStatus.connected;
}

class AntMediaBroadcast {
  const AntMediaBroadcast({
    required this.streamId,
    required this.status,
    required this.bitrate,
    required this.width,
    required this.height,
    required this.receivedBytes,
  });

  factory AntMediaBroadcast.fromJson(Map<dynamic, dynamic> json) {
    return AntMediaBroadcast(
      streamId: json['streamId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unknown',
      bitrate: (json['bitrate'] as num?)?.round() ?? 0,
      width: (json['width'] as num?)?.round() ?? 0,
      height: (json['height'] as num?)?.round() ?? 0,
      receivedBytes: (json['receivedBytes'] as num?)?.round() ?? 0,
    );
  }

  final String streamId;
  final String status;
  final int bitrate;
  final int width;
  final int height;
  final int receivedBytes;

  bool get isBroadcasting => status.toLowerCase() == 'broadcasting';

  String get resolution => width > 0 && height > 0 ? '${width}x$height' : '-';
}

class AntMediaBroadcastLookup {
  const AntMediaBroadcastLookup({this.broadcast, this.error});

  final AntMediaBroadcast? broadcast;
  final String? error;
}

class BroadcastPage extends StatefulWidget {
  const BroadcastPage({super.key});

  @override
  State<BroadcastPage> createState() => _BroadcastPageState();
}

class _BroadcastPageState extends State<BroadcastPage>
    with WidgetsBindingObserver {
  final _streamIdController = TextEditingController(text: _defaultStreamId);
  late CameraController _cameraController;

  List<CameraDescription> _cameras = const [];
  CameraDescription? _selectedCamera;
  BroadcastProfile _profile = _profiles[2];
  StreamStatistics? _stats;
  AntMediaServerStatus _serverStatus = const AntMediaServerStatus(
    status: AntMediaConnectionStatus.idle,
    title: 'Belum live',
    detail: 'Tekan Mulai Live untuk mengirim stream ke Ant Media Server.',
    icon: Icons.cloud_queue,
    color: Colors.white54,
  );
  Timer? _statsTimer;
  Timer? _amsStatusTimer;
  Timer? _clockTimer;
  DateTime? _startedAt;

  bool _isBusy = false;
  bool _audioEnabled = true;
  bool _flashEnabled = false;
  bool _rtmpPingEnabled = true;
  bool _ignoreNextRtmpStopEvent = false;
  int _bitrateKbps = _profiles[2].defaultBitrateKbps;
  int _fps = 30;
  String? _statusMessage;

  bool get _isInitialized => _cameraController.value.isInitialized == true;
  bool get _isStreaming => _cameraController.value.isStreamingVideoRtmp == true;

  String get _rtmpUrl {
    final streamId = _streamIdController.text.trim();
    return '$_serverBaseUrl/${streamId.isEmpty ? _defaultStreamId : streamId}';
  }

  Duration get _duration {
    final start = _startedAt;
    if (start == null) return Duration.zero;
    return DateTime.now().difference(start);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraController = _buildController(_profile);
    _loadSettings();
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statsTimer?.cancel();
    _amsStatusTimer?.cancel();
    _clockTimer?.cancel();
    _streamIdController.dispose();
    WakelockPlus.disable();
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (!_isInitialized) return;
    if (state == AppLifecycleState.paused && !_isStreaming) {
      await _cameraController.dispose();
    }
    if (state == AppLifecycleState.resumed && !_isStreaming) {
      await _recreateController();
    }
  }

  CameraController _buildController(BroadcastProfile profile) {
    final controller = CameraController(
      profile.preset,
      enableAudio: true,
      androidUseOpenGL: true,
    );
    controller.addListener(_onCameraChanged);
    return controller;
  }

  void _onCameraChanged() {
    if (!mounted) return;
    final event = _cameraController.value.event;
    if (event is Map) {
      final eventType = event['eventType']?.toString().toLowerCase() ?? '';
      if (eventType.contains('rtmp_stopped') ||
          eventType.contains('disconnect') ||
          eventType.contains('closed')) {
        _stopTimers();
        if (_ignoreNextRtmpStopEvent) {
          _ignoreNextRtmpStopEvent = false;
        } else {
          _setServerStatus(
            AntMediaConnectionStatus.disconnected,
            title: 'Terputus dari Ant Media Server',
            detail:
                'Koneksi RTMP berhenti. Cek jaringan, stream ID, dan server.',
            icon: Icons.cloud_off,
            color: const Color(0xFFFFC857),
          );
        }
      }
    }
    setState(() {});
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final streamId = prefs.getString('streamId');
    final profileName = prefs.getString('profile');
    if (!mounted) return;
    setState(() {
      if (streamId != null && streamId.isNotEmpty) {
        _streamIdController.text = streamId;
      }
      _fps = prefs.getInt('fps') ?? _fps;
      _bitrateKbps = prefs.getInt('bitrateKbps') ?? _bitrateKbps;
      _audioEnabled = prefs.getBool('audioEnabled') ?? _audioEnabled;
      _rtmpPingEnabled = prefs.getBool('rtmpPingEnabled') ?? _rtmpPingEnabled;
      _profile = _profiles.firstWhere(
        (profile) => profile.name == profileName,
        orElse: () => _profile,
      );
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('streamId', _streamIdController.text.trim());
    await prefs.setString('profile', _profile.name);
    await prefs.setInt('fps', _fps);
    await prefs.setInt('bitrateKbps', _bitrateKbps);
    await prefs.setBool('audioEnabled', _audioEnabled);
    await prefs.setBool('rtmpPingEnabled', _rtmpPingEnabled);
  }

  Future<void> _initializeCamera() async {
    setState(() => _isBusy = true);
    try {
      await _requestPermissions();
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _setStatus('Kamera tidak ditemukan.');
        return;
      }
      _selectedCamera ??= _preferredCamera(_cameras);
      await _cameraController.initialize(_selectedCamera!);
      _setStatus('Kamera siap untuk live.');
    } on CameraException catch (e) {
      _setStatus('Camera error: ${e.description ?? e.code}');
    } on PlatformException catch (e) {
      _setStatus('Platform error: ${e.message ?? e.code}');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _requestPermissions() async {
    final statuses = await [Permission.camera, Permission.microphone].request();
    if (statuses.values.any(
      (status) => status.isDenied || status.isPermanentlyDenied,
    )) {
      throw PlatformException(
        code: 'permission_denied',
        message: 'Izin kamera dan mikrofon diperlukan untuk live streaming.',
      );
    }
  }

  CameraDescription _preferredCamera(List<CameraDescription> cameras) {
    return cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
  }

  Future<void> _recreateController({BroadcastProfile? profile}) async {
    final wasStreaming = _isStreaming;
    if (wasStreaming) {
      _setStatus('Stop live dulu sebelum mengganti kualitas.');
      return;
    }
    setState(() => _isBusy = true);
    final old = _cameraController;
    old.removeListener(_onCameraChanged);
    await old.dispose();
    _cameraController = _buildController(profile ?? _profile);
    try {
      if (_selectedCamera != null) {
        await _cameraController.initialize(_selectedCamera!);
      }
    } on CameraException catch (e) {
      _setStatus('Camera error: ${e.description ?? e.code}');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isBusy) return;
    final currentIndex = _cameras.indexOf(_selectedCamera ?? _cameras.first);
    final next = _cameras[(currentIndex + 1) % _cameras.length];
    try {
      if (_isInitialized) {
        await _cameraController.switchCamera(next.name!);
      }
      setState(() {
        _selectedCamera = next;
        _flashEnabled = false;
      });
    } on CameraException catch (e) {
      _setStatus('Gagal ganti kamera: ${e.description ?? e.code}');
    }
  }

  Future<void> _toggleFlash() async {
    if (!_isStreaming ||
        _selectedCamera?.lensDirection != CameraLensDirection.back) {
      _setStatus('Flash bisa diaktifkan saat live dengan kamera belakang.');
      return;
    }
    try {
      await _cameraController.switchFlashLight(!_flashEnabled);
      setState(() => _flashEnabled = !_flashEnabled);
    } on CameraException catch (e) {
      _setStatus('Gagal mengubah flash: ${e.description ?? e.code}');
    }
  }

  Future<void> _toggleAudio(bool enabled) async {
    setState(() => _audioEnabled = enabled);
    if (_isStreaming) {
      try {
        await _cameraController.switchAudio(enabled);
      } on CameraException catch (e) {
        _setStatus('Gagal mengubah audio: ${e.description ?? e.code}');
      }
    }
    await _saveSettings();
  }

  Future<AntMediaBroadcastLookup> _fetchAntMediaBroadcast() async {
    final streamId = _streamIdController.text.trim();
    final client = HttpClient()..connectionTimeout = _antMediaApiTimeout;

    try {
      final request = await client
          .getUrl(Uri.parse(_antMediaBroadcastsApiUrl))
          .timeout(_antMediaApiTimeout);
      final response = await request.close().timeout(_antMediaApiTimeout);
      final body = await response.transform(utf8.decoder).join().timeout(
        _antMediaApiTimeout,
      );

      if (response.statusCode != HttpStatus.ok) {
        return AntMediaBroadcastLookup(
          error: 'API AMS gagal (${response.statusCode}): $body',
        );
      }

      final decoded = jsonDecode(body);
      if (decoded is! List) {
        return const AntMediaBroadcastLookup(
          error: 'Response API AMS tidak sesuai format list broadcast.',
        );
      }

      for (final item in decoded) {
        if (item is Map && item['streamId']?.toString() == streamId) {
          return AntMediaBroadcastLookup(
            broadcast: AntMediaBroadcast.fromJson(item),
          );
        }
      }

      return AntMediaBroadcastLookup(
        error: 'Stream ID $streamId tidak ditemukan di API AMS.',
      );
    } on TimeoutException {
      return AntMediaBroadcastLookup(
        error:
            'API AMS tidak merespons dalam ${_antMediaApiTimeout.inSeconds} detik.',
      );
    } on SocketException catch (e) {
      return AntMediaBroadcastLookup(
        error: 'API AMS tidak bisa dihubungi: ${e.message}',
      );
    } on FormatException catch (e) {
      return AntMediaBroadcastLookup(
        error: 'Response API AMS bukan JSON valid: ${e.message}',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _refreshAntMediaStatus() async {
    if (!_isStreaming) return;
    final lookup = await _fetchAntMediaBroadcast();
    if (!mounted || !_isStreaming) return;

    final error = lookup.error;
    if (error != null) {
      _setServerStatus(
        AntMediaConnectionStatus.error,
        title: 'Tidak masuk Ant Media Server',
        detail: error,
        icon: Icons.error_outline,
        color: const Color(0xFFE84A5F),
      );
      return;
    }

    final broadcast = lookup.broadcast;
    if (broadcast == null) return;

    if (broadcast.isBroadcasting) {
      _setServerStatus(
        AntMediaConnectionStatus.connected,
        title: 'Masuk Ant Media Server',
        detail: 'API AMS status broadcasting untuk ${broadcast.streamId} '
            '(${broadcast.resolution}, ${broadcast.bitrate} bps, '
            '${broadcast.receivedBytes} bytes diterima).',
        icon: Icons.cloud_done,
        color: const Color(0xFF18A999),
      );
    } else {
      _setServerStatus(
        AntMediaConnectionStatus.connecting,
        title: 'Belum masuk Ant Media Server',
        detail: 'API AMS menemukan ${broadcast.streamId}, tetapi status masih '
            '${broadcast.status}. Menunggu status broadcasting.',
        icon: Icons.cloud_sync,
        color: const Color(0xFFFFC857),
      );
    }
  }

  Future<void> _startStreaming() async {
    if (!_isInitialized || _isBusy) return;
    final streamId = _streamIdController.text.trim();
    if (streamId.isEmpty) {
      _setStatus('Isi stream ID dulu.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isBusy = true);
    _setServerStatus(
      AntMediaConnectionStatus.connecting,
      title: 'Menghubungkan ke Ant Media Server',
      detail: 'Mencoba masuk ke $_rtmpUrl ...',
      icon: Icons.cloud_sync,
      color: const Color(0xFFFFC857),
    );
    try {
      final apiLookup = await _fetchAntMediaBroadcast();
      if (apiLookup.error != null) {
        _setServerStatus(
          AntMediaConnectionStatus.error,
          title: 'Tidak masuk Ant Media Server',
          detail: apiLookup.error!,
          icon: Icons.error_outline,
          color: const Color(0xFFE84A5F),
        );
        _setStatus(apiLookup.error!);
        return;
      }

      if (Platform.isAndroid) {
        await _cameraController.setForceBt709Color(true);
        await _cameraController.setRtmpShouldSendPings(_rtmpPingEnabled);
      }
      if (Platform.isIOS) {
        await _cameraController.setSessionPreset(_iosSessionPreset(_profile));
        await _cameraController.setFrameRate(_fps);
        await _cameraController.setVideoSettings(
          bitrate: _bitrateKbps * 1000,
          width: _profile.width,
          height: _profile.height,
          expectedFrameRate: _fps.toDouble(),
          bitRateMode: 'average',
        );
      }
      await _cameraController.startVideoStreaming(
        _rtmpUrl,
        bitrate: _bitrateKbps * 1000,
        androidUseOpenGL: true,
      );
      if (!_audioEnabled) {
        await _cameraController.switchAudio(false);
      }
      await _saveSettings();
      await WakelockPlus.enable();
      _startedAt = DateTime.now();
      _startTimers();
      _setServerStatus(
        AntMediaConnectionStatus.connecting,
        title: 'Menunggu konfirmasi API AMS',
        detail: 'RTMP mulai dikirim ke $_rtmpUrl. Menunggu status broadcasting '
            'dari API Ant Media Server.',
        icon: Icons.cloud_sync,
        color: const Color(0xFFFFC857),
      );
      unawaited(_refreshAntMediaStatus());
      _setStatus('Live dimulai, menunggu konfirmasi API AMS.');
    } on CameraException catch (e) {
      _setServerStatus(
        AntMediaConnectionStatus.error,
        title: 'Tidak masuk Ant Media Server',
        detail: 'Gagal mulai live: ${e.description ?? e.code}',
        icon: Icons.error_outline,
        color: const Color(0xFFE84A5F),
      );
      _setStatus('Gagal mulai live: ${e.description ?? e.code}');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _stopStreaming() async {
    if (!_isStreaming || _isBusy) return;
    setState(() => _isBusy = true);
    try {
      _ignoreNextRtmpStopEvent = true;
      await _cameraController.stopVideoStreaming();
      _stopTimers();
      await WakelockPlus.disable();
      _setServerStatus(
        AntMediaConnectionStatus.idle,
        title: 'Belum live',
        detail: 'Stream dihentikan dari aplikasi.',
        icon: Icons.cloud_queue,
        color: Colors.white54,
      );
      _setStatus('Live dihentikan.');
    } on CameraException catch (e) {
      _ignoreNextRtmpStopEvent = false;
      _setStatus('Gagal stop live: ${e.description ?? e.code}');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String _iosSessionPreset(BroadcastProfile profile) {
    if (profile.preset == ResolutionPreset.veryHigh ||
        profile.preset == ResolutionPreset.max) {
      return 'hd1920x1080';
    }
    if (profile.preset == ResolutionPreset.high) return 'hd1280x720';
    if (profile.preset == ResolutionPreset.medium) return 'vga640x480';
    return 'cif352x288';
  }

  void _startTimers() {
    _statsTimer?.cancel();
    _amsStatusTimer?.cancel();
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _statsTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!_isStreaming) return;
      try {
        final stats = await _cameraController.getStreamStatistics();
        if (!_isStreaming) return;
        if (mounted) {
          setState(() => _stats = stats);
        }
      } catch (_) {
        // Stats availability differs by platform and encoder state.
      }
    });
    _amsStatusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_refreshAntMediaStatus());
    });
  }

  void _stopTimers() {
    _statsTimer?.cancel();
    _amsStatusTimer?.cancel();
    _clockTimer?.cancel();
    _statsTimer = null;
    _amsStatusTimer = null;
    _clockTimer = null;
    _startedAt = null;
    _stats = null;
  }

  void _setStatus(String message) {
    if (!mounted) return;
    setState(() => _statusMessage = message);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _setServerStatus(
    AntMediaConnectionStatus status, {
    required String title,
    required String detail,
    required IconData icon,
    required Color color,
  }) {
    if (!mounted) return;
    setState(() {
      _serverStatus = AntMediaServerStatus(
        status: status,
        title: title,
        detail: detail,
        icon: icon,
        color: color,
        checkedAt: DateTime.now(),
      );
    });
  }


  Future<void> _selectProfile(BroadcastProfile profile) async {
    if (_isStreaming) {
      _setStatus('Stop live dulu untuk mengganti resolusi.');
      return;
    }
    setState(() {
      _profile = profile;
      _bitrateKbps = profile.defaultBitrateKbps;
    });
    await _saveSettings();
    await _recreateController(profile: profile);
  }

  Future<void> _setOrientation(List<DeviceOrientation> orientations) async {
    await SystemChrome.setPreferredOrientations(orientations);
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      body: SafeArea(
        child: isLandscape ? _landscapeLayout() : _portraitLayout(),
      ),
    );
  }

  Widget _portraitLayout() {
    return Column(
      children: [
        _topBar(),
        Expanded(child: _preview()),
        _controlPanel(),
      ],
    );
  }

  Widget _landscapeLayout() {
    return Row(
      children: [
        Expanded(flex: 7, child: _preview()),
        SizedBox(width: 390, child: _controlPanel(compact: true)),
      ],
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/logo.png',
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GaluhCast',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Broadcasting Platform Diskominfo Ciamis',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          _liveBadge(),
        ],
      ),
    );
  }

  Widget _cameraPreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewAspectRatio = _cameraController.value.aspectRatio;
        if (previewAspectRatio <= 0 ||
            constraints.maxWidth <= 0 ||
            constraints.maxHeight <= 0) {
          return CameraPreview(_cameraController);
        }

        final containerAspectRatio =
            constraints.maxWidth / constraints.maxHeight;
        final scale = containerAspectRatio > previewAspectRatio
            ? containerAspectRatio / previewAspectRatio
            : previewAspectRatio / containerAspectRatio;

        return ClipRect(
          child: Transform.scale(
            scale: scale,
            child: Center(
              child: AspectRatio(
                aspectRatio: previewAspectRatio,
                child: CameraPreview(_cameraController),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _preview() {
    return Container(
      margin: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isStreaming ? const Color(0xFFE84A5F) : Colors.white12,
          width: _isStreaming ? 2 : 1,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_isInitialized)
            _cameraPreview()
          else
            const Center(child: CircularProgressIndicator()),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metricChip(Icons.timer_outlined, _formatDuration(_duration)),
                _metricChip(
                  Icons.network_check,
                  '${_stats?.bitrate ?? _bitrateKbps} kbps',
                ),
                _metricChip(Icons.speed, '${_stats?.fps ?? _fps} fps'),
                _metricChip(
                  _serverStatus.icon,
                  _serverStatus.isConnected
                      ? 'AMS masuk'
                      : _serverStatus.title,
                  color: _serverStatus.color,
                ),
                _metricChip(
                  Icons.crop_16_9,
                  _stats?.width != null && _stats?.height != null
                      ? '${_stats!.width}x${_stats!.height}'
                      : _profile.name,
                ),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Row(
              children: [
                _roundButton(
                  icon: Icons.cameraswitch,
                  onPressed: _isBusy ? null : _switchCamera,
                  tooltip: 'Ganti kamera',
                ),
                const SizedBox(width: 8),
                _roundButton(
                  icon: _audioEnabled ? Icons.mic : Icons.mic_off,
                  onPressed: () => _toggleAudio(!_audioEnabled),
                  tooltip: 'Audio',
                  active: _audioEnabled,
                ),
                const SizedBox(width: 8),
                _roundButton(
                  icon: _flashEnabled ? Icons.flash_on : Icons.flash_off,
                  onPressed: _toggleFlash,
                  tooltip: 'Flash',
                  active: _flashEnabled,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlPanel({bool compact = false}) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, compact ? 12 : 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compact) _topBar(),
          TextField(
            controller: _streamIdController,
            enabled: !_isStreaming,
            decoration: InputDecoration(
              labelText: 'Stream ID',
              prefixIcon: const Icon(Icons.key),
              suffixText: '/live',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (_) => _saveSettings(),
          ),
          const SizedBox(height: 8),
          SelectableText(
            _rtmpUrl,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _antMediaStatusCard(),
          const SizedBox(height: 16),
          _sectionTitle('Kualitas'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _profiles.map((profile) {
              final selected = profile == _profile;
              return ChoiceChip(
                label: Text(profile.name),
                selected: selected,
                onSelected: (_) => _selectProfile(profile),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _slider(
            label: 'Bitrate',
            value: _bitrateKbps.toDouble(),
            min: 500,
            max: 8000,
            divisions: 75,
            display: '$_bitrateKbps kbps',
            onChanged: _isStreaming
                ? null
                : (value) {
                    setState(() => _bitrateKbps = value.round());
                    _saveSettings();
                  },
          ),
          _slider(
            label: 'FPS',
            value: _fps.toDouble(),
            min: 15,
            max: 60,
            divisions: 9,
            display: '$_fps fps',
            onChanged: _isStreaming
                ? null
                : (value) {
                    setState(() => _fps = value.round());
                    _saveSettings();
                  },
          ),
          SwitchListTile(
            value: _rtmpPingEnabled,
            onChanged: _isStreaming
                ? null
                : (value) {
                    setState(() => _rtmpPingEnabled = value);
                    _saveSettings();
                  },
            title: const Text('RTMP ping / RTT'),
            secondary: const Icon(Icons.online_prediction),
          ),
          const SizedBox(height: 8),
          _sectionTitle('Orientasi'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'portrait',
                icon: Icon(Icons.stay_current_portrait),
                label: Text('Portrait'),
              ),
              ButtonSegment(
                value: 'landscape',
                icon: Icon(Icons.stay_current_landscape),
                label: Text('Landscape'),
              ),
              ButtonSegment(
                value: 'free',
                icon: Icon(Icons.screen_rotation),
                label: Text('Auto'),
              ),
            ],
            selected: const {'free'},
            onSelectionChanged: (selection) {
              final value = selection.first;
              if (value == 'portrait') {
                _setOrientation([DeviceOrientation.portraitUp]);
              } else if (value == 'landscape') {
                _setOrientation([
                  DeviceOrientation.landscapeLeft,
                  DeviceOrientation.landscapeRight,
                ]);
              } else {
                _setOrientation([
                  DeviceOrientation.portraitUp,
                  DeviceOrientation.landscapeLeft,
                  DeviceOrientation.landscapeRight,
                ]);
              }
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isBusy
                ? null
                : _isStreaming
                ? _stopStreaming
                : _startStreaming,
            icon: Icon(_isStreaming ? Icons.stop : Icons.broadcast_on_personal),
            label: Text(_isStreaming ? 'Stop Live' : 'Mulai Live'),
            style: FilledButton.styleFrom(
              backgroundColor: _isStreaming
                  ? const Color(0xFFE84A5F)
                  : const Color(0xFF18A999),
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _statusMessage!,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _liveBadge() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _isStreaming ? const Color(0xFFE84A5F) : Colors.white10,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _isStreaming ? 'LIVE' : 'READY',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }

  Widget _metricChip(IconData icon, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color ?? Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color ?? Colors.white70),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _antMediaStatusCard() {
    final checkedAt = _serverStatus.checkedAt;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _serverStatus.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _serverStatus.color.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_serverStatus.icon, color: _serverStatus.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _serverStatus.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  _serverStatus.detail,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if (checkedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Update ${_formatClock(checkedAt)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton.filledTonal(
        onPressed: onPressed,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: active
              ? const Color(0xFF18A999)
              : Colors.black.withValues(alpha: 0.55),
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double>? onChanged,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(display, style: const TextStyle(color: Colors.white70)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          label: display,
          onChanged: onChanged,
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  String _formatClock(DateTime time) {
    final hours = time.hour.toString().padLeft(2, '0');
    final minutes = time.minute.toString().padLeft(2, '0');
    final seconds = time.second.toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}
