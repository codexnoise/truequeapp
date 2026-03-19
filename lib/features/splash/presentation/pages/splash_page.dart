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
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            const _TruequeAppLogo(),
            const SizedBox(height: 32),
            const _AppTitle(),
            const SizedBox(height: 12),
            Text(
              'I N T E R C A M B I O S   Y\nD O N A C I O N E S',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurface,
                letterSpacing: 2,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Lo que tú ya no usas, alguien más lo necesita.',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: colors.onSurfaceVariant,
              ),
            ),
            const Spacer(flex: 4),
            const _BottomIcons(),
            const SizedBox(height: 8),
            Text(
              'V E R S I O N  $_version',
              style: TextStyle(
                fontSize: 11,
                color: colors.onSurfaceVariant,
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
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'TRUEQUE',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: onSurface,
            letterSpacing: 1,
          ),
        ),
        const Text(
          'APP',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: Color(0xFFC75B12),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      isDark ? 'assets/logo/logo_truequeapp_dark.png' : 'assets/logo/logo_truequeapp_light.png',
      height: 120,
    );
  }
}

class _BottomIcons extends StatelessWidget {
  const _BottomIcons();

  @override
  Widget build(BuildContext context) {
    final variantColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inventory_2_outlined, size: 22, color: variantColor),
        const SizedBox(width: 24),
        Icon(Icons.volunteer_activism_outlined, size: 22, color: variantColor),
        const SizedBox(width: 24),
        Icon(Icons.groups_outlined, size: 22, color: variantColor),
      ],
    );
  }
}
