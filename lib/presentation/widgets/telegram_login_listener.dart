import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import '../../core/providers/phone_otp_auth_provider.dart';

class TelegramLoginListener extends StatefulWidget {
  const TelegramLoginListener({super.key, required this.child});
  final Widget child;

  @override
  State<TelegramLoginListener> createState() => _TelegramLoginListenerState();
}

class _TelegramLoginListenerState extends State<TelegramLoginListener> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _appLinks.uriLinkStream.listen(_onUri, onError: (_) {});
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _onUri(uri);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onUri(Uri uri) {
    if (uri.scheme != 'cofiz') return;
    if (uri.host != 'auth') return;
    if (uri.pathSegments.isEmpty) return;
    if (uri.pathSegments.first != 'telegram') return;
    if (uri.pathSegments.length > 1 && uri.pathSegments[1] == 'success') {
      final token = uri.queryParameters['customToken'];
      final uid = uri.queryParameters['uid'];
      if (token == null || token.isEmpty) return;
      if (!mounted) return;
      context.read<PhoneOtpAuthProvider>().completeWithCustomToken(customToken: token, uid: uid ?? '');
      return;
    }
    final fields = <String, String>{};
    uri.queryParameters.forEach((k, v) {
      fields[k] = v;
    });
    if (fields.isEmpty) return;
    if (!mounted) return;
    context.read<PhoneOtpAuthProvider>().completeTelegramLogin(fields: fields);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
