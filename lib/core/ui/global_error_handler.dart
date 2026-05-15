import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class GlobalErrorService {
  final _controller = StreamController<String?>.broadcast();
  void show(String message) => _controller.add(message);
  Stream<String?> get stream => _controller.stream;
  void dispose() => _controller.close();
}

final globalErrorServiceProvider = Provider<GlobalErrorService>((ref) {
  final s = GlobalErrorService();
  ref.onDispose(() => s.dispose());
  return s;
});

class GlobalErrorListener extends ConsumerWidget {
  final Widget child;

  const GlobalErrorListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(globalErrorServiceProvider);

    return StreamBuilder<String?>(
      stream: service.stream,
      builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final msg = snapshot.data!;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              // Announce for accessibility
              try {
                SemanticsService.announce(msg, TextDirection.ltr);
              } catch (e) {
                // ignore: avoid_print
                print('Semantics announce failed: $e');
              }
            });
        }
        return child;
      },
    );
  }
}
