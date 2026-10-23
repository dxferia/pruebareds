import 'package:flutter/material.dart';
import '../utils/route_names.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/navigation.dart';
import '../widgets/ui_helpers.dart';

class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Travesías Conecta',
      role: 'Habitante',
      bottomIndex: 0,
      onBottomTap: (i) => residentNav(context, i),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 80, 22, 28),
        children: [
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(color: AppColors.suspendedBg, shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off, size: 44, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 24),
          Text('No pudimos actualizar\nla información', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          const Text('Revisa tu conexión e intenta nuevamente.\nNo enviaremos solicitudes duplicadas.', textAlign: TextAlign.center),
          const SizedBox(height: 64),
          PrimaryButton(
            label: 'Reintentar',
            onPressed: () {
              state.toggleOffline(false);
              Navigator.of(context).pushNamedAndRemoveUntil(Routes.home, (r) => false);
            },
          ),
          const SizedBox(height: 10),
          SecondaryButton(label: 'Volver al inicio', onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(Routes.home, (r) => false)),
          const SizedBox(height: 12),
          TextButton(onPressed: () {}, child: const Text('Ayuda')),
          const SizedBox(height: 32),
          Text('Listas paginadas para funcionar mejor\ncon conectividad variable.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
