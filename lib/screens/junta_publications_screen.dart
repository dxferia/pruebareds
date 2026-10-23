import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../widgets/app_shell.dart';
import '../widgets/navigation.dart';
import '../widgets/status_chip.dart';
import 'manage_publication_screen.dart';

class JuntaPublicationsScreen extends StatelessWidget {
  const JuntaPublicationsScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Publicaciones',
      role: 'Junta',
      junta: true,
      bottomIndex: 2,
      onBottomTap: (i) => juntaNav(context, i),
      body: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final active = state.jobs.where((j) => j.status == RequestStatus.active).toList();
          return ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          children: [
            Text('Publicaciones activas', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...active.map((job) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Card(
                    child: ListTile(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ManagePublicationScreen(state: state, job: job))),
                      title: Text(job.title, style: Theme.of(context).textTheme.titleSmall),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('${job.people} ${job.people == 1 ? 'persona' : 'personas'} · ${job.location.replaceAll(', Vereda Travesías', '')}'),
                      ),
                      trailing: const StatusChip(status: RequestStatus.active),
                    ),
                  ),
                )),
          ],
          );
        },
      ),
    );
  }
}
