import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/manager_theme_controller.dart';

/// Wrapper widget that adds the red light/dark mode FAB to manager screens
/// Uses the same design as the existing red switcher on the dashboard
class ManagerThemeFabWrapper extends StatelessWidget {
  const ManagerThemeFabWrapper({
    super.key,
    required this.child,
    this.showFab = true,
  });

  final Widget child;
  final bool showFab;

  @override
  Widget build(BuildContext context) {
    return Consumer<ManagerThemeController>(
      builder: (context, themeController, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: _createValueNotifier(themeController),
          builder: (context, light, _) {
            return Stack(
              children: [
                child,
                if (showFab)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      heroTag: 'global_manager_theme_toggle',
                      backgroundColor: ManagerChromeTheme.accentRed,
                      onPressed: () {
                        final ctrl = context.read<ManagerThemeController>();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          ctrl.toggle();
                        });
                      },
                      child: Icon(
                        themeController.isDark 
                            ? Icons.wb_sunny_rounded 
                            : Icons.dark_mode_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  ValueNotifier<bool> _createValueNotifier(ManagerThemeController controller) {
    final notifier = ValueNotifier(!controller.isDark);
    
    // Listen to controller changes and update notifier
    controller.addListener(() {
      notifier.value = !controller.isDark;
    });
    
    return notifier;
  }
}
