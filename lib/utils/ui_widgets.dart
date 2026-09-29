import 'dart:ui';
import 'package:flutter/material.dart';
import 'colors.dart';

class AppLoadingIndicator extends StatelessWidget {
  final String message;

  const AppLoadingIndicator({super.key, this.message = 'Loading...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.dark),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: AppColors.fontBody,
              color: AppColors.textGray,
            ),
          ),
        ],
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppColors.fontBody,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppColors.fontCaption,
                color: AppColors.textGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppErrorState({
    super.key,
    this.message = 'Something went wrong. Please try again.',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 64, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppColors.fontBody,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppColors.fontCaption,
                color: AppColors.textGray,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Try Again',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dark,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String friendlyErrorMessage(Object? error) {
  if (error == null) return 'Something went wrong. Please try again.';
  final text = error.toString().toLowerCase();

  if (text.contains('network') || text.contains('unavailable')) {
    return 'No internet connection. Please check your connection and try again.';
  }
  if (text.contains('permission-denied')) {
    return 'You don\'t have permission to do that. Please log in again.';
  }
  if (text.contains('not-found')) {
    return 'We couldn\'t find that record.';
  }
  if (text.contains('timeout') || text.contains('deadline')) {
    return 'This is taking longer than usual. Please try again.';
  }
  // Default: generic, hindi nakakatakot na message.
  return 'Something went wrong. Please try again.';
}

/// Isang pare-parehong "modal shell" para sa LAHAT ng dialogs sa app —
/// blurred backdrop, naka-gitna talaga ang card (hindi naka-anchor sa
/// taas), malambot na rounded corners, at consistent button row.
/// Gamitin ito sa halip na showDialog + AlertDialog nang direkta, para
/// magkapareho ang itsura ng bawat confirmation/dialog sa buong app.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  required List<AppDialogAction> actions,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: title,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
    transitionBuilder: (context, anim1, anim2, child) {
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 6 * anim1.value,
          sigmaY: 6 * anim1.value,
        ),
        child: FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: AppColors.fontTitle,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        content,
                        const SizedBox(height: 20),
                        _AppDialogActionRow(actions: actions),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}


class AppDialogAction {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isDestructive;
  final bool isLoading;

  const AppDialogAction({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.isDestructive = false,
    this.isLoading = false,
  });
}

class _AppDialogActionRow extends StatelessWidget {
  final List<AppDialogAction> actions;
  const _AppDialogActionRow({required this.actions});

  @override
  Widget build(BuildContext context) {
    if (actions.length == 1) {
      return SizedBox(
        width: double.infinity,
        child: _buildButton(actions.first),
      );
    }

    return Row(
      children: [
        for (int i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _buildButton(actions[i])),
        ],
      ],
    );
  }

  Widget _buildButton(AppDialogAction action) {
    if (action.isPrimary) {
      return ElevatedButton(
        onPressed: action.isLoading ? null : action.onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              action.isDestructive ? AppColors.danger : AppColors.dark,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: action.isLoading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(action.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppColors.fontLabel,
                    fontWeight: FontWeight.w600)),
      );
    }
    return OutlinedButton(
      onPressed: action.isLoading ? null : action.onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: Color(0xFFD1D5DB)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(action.label,
          style: const TextStyle(
              color: AppColors.textGray,
              fontSize: AppColors.fontLabel,
              fontWeight: FontWeight.w600)),
    );
  }
}
