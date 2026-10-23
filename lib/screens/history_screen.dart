import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/navigation.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Historial',
      role: 'Junta',
      junta: true,
      showBack: true,
      bottomIndex: 0,
      onBottomTap: (i) => juntaNav(context, i),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
        children: [
          Text('Deshierbe de cultivo', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Registro de gestión'),
          const SizedBox(height: 30),
          ...List.generate(state.history.length, (index) {
            final e = state.history[index];
            final last = index == state.history.length - 1;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 24,
                    child: Column(
                      children: [
                        Container(width: 14, height: 14, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                        if (!last) Expanded(child: Container(width: 1, color: AppColors.border)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 36),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${e.date.day} sep · ${e.date.hour.toString().padLeft(2, '0')}:${e.date.minute.toString().padLeft(2, '0')}', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Text(e.title, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 5),
                        Text('Actor: ${e.actor}'),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
