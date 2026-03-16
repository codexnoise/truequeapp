import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:go_router/go_router.dart';

const String _appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '');

Future<String> _readVersionFromPubspec() async {
  if (_appVersion.isNotEmpty) return _appVersion;
  try {
    final pubspec = await rootBundle.loadString('pubspec.yaml');
    final versionLine = pubspec.split('\n').firstWhere(
      (line) => line.startsWith('version:'),
      orElse: () => 'version: 0.0.0',
    );
    return versionLine.split(':').last.trim().split('+').first;
  } catch (_) {
    return '0.0.0';
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _readVersionFromPubspec().then((v) {
      if (mounted) setState(() => _version = v);
    });
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            const _TruequeAppLogo(),
            const SizedBox(height: 32),
            const _AppTitle(),
            const SizedBox(height: 12),
            const Text(
              'I N T E R C A M B I O S   Y\nD O N A C I O N E S',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF2D3142),
                letterSpacing: 2,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Lo que tú ya no usas, alguien más lo necesita.',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Color(0xFF757575),
              ),
            ),
            const Spacer(flex: 4),
            const _BottomIcons(),
            const SizedBox(height: 8),
            Text(
              'V E R S I O N  $_version',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9E9E9E),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _AppTitle extends StatelessWidget {
  const _AppTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'TRUEQUE',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF2D3142),
            letterSpacing: 1,
          ),
        ),
        Text(
          'APP',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFC75B12),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _TruequeAppLogo extends StatelessWidget {
  const _TruequeAppLogo();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(
          Icons.swap_horizontal_circle,
          size: 80,
          color: Color(0xFF2D3142),
        ),
        Positioned(
          top: -2,
          right: -4,
          child: Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: Color(0xFFC75B12),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomIcons extends StatelessWidget {
  const _BottomIcons();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inventory_2_outlined, size: 22, color: Color(0xFF9E9E9E)),
        SizedBox(width: 24),
        Icon(Icons.volunteer_activism_outlined,
            size: 22, color: Color(0xFF9E9E9E)),
        SizedBox(width: 24),
        Icon(Icons.groups_outlined, size: 22, color: Color(0xFF9E9E9E)),
      ],
    );
  }
}
