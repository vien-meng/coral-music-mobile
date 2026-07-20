import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppBackScope extends StatelessWidget {
  const AppBackScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
        canPop: context.canPop(),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.go('/more');
        },
        child: child,
      );
}

class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: '返回',
        onPressed: () => context.canPop() ? context.pop() : context.go('/more'),
        icon: const Icon(Icons.arrow_back),
      );
}
