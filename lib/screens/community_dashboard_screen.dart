import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/route_names.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/navigation.dart';
import '../widgets/ui_helpers.dart';
import 'manage_publication_screen.dart';

class CommunityDashboardScreen extends StatelessWidget {
  const CommunityDashboardScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Gestión comunitaria',
      role: 'Junta',
      junta: true,
      bottomIndex: 0,
      onBottomTap: (i) => juntaNav(context, i),
      body: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final active = state.jobs.where((j) => j.status == RequestStatus.active).length;
          final pendingAccess = state.accesses.where((a) => a.status == RequestStatus.pending).length;
          return ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          children: [
            Text('Junta de Acción Comunal', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Administración de publicaciones y accesos', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 26),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.9,
              children: [
                _Metric(value: '${state.accesses.length}', label: 'Cuentas\nregistradas'),
                _Metric(value: '$active', label: 'Publicaciones\nactivas'),
                _Metric(value: '${state.contactRequests.length}', label: 'Solicitudes\nde contacto'),
                _Metric(value: '$pendingAccess', label: 'Acciones\npor revisar'),
              ],
            ),
            const SizedBox(height: 24),
            Text('Publicaciones recientes', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...state.jobs.where((j) => j.status == RequestStatus.active).take(2).map((job) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      title: Text(job.title, style: Theme.of(context).textTheme.titleSmall),
                      subtitle: Text('${job.people} ${job.people == 1 ? 'persona' : 'personas'} · ${job.location.replaceAll(', Vereda Travesías', '')}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ManagePublicationScreen(state: state, job: job))),
                    ),
                  ),
                )),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, Routes.history),
              icon: const Icon(Icons.history),
              label: const Text('Ver historial de gestión'),
            ),
          ],
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Row(
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.primary)),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}
