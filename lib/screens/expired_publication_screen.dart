import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/route_names.dart';
import '../services/app_state.dart';
import '../widgets/app_shell.dart';
import '../widgets/navigation.dart';
import '../widgets/status_chip.dart';
import '../widgets/ui_helpers.dart';

class ExpiredPublicationScreen extends StatelessWidget {
  const ExpiredPublicationScreen({super.key, required this.state, this.job});
  final AppState state;
  final JobPost? job;

  @override
  Widget build(BuildContext context) {
    final current = job ?? _expiredExample();
    return AppShell(
      title: 'Detalle del anuncio',
      role: 'Habitante',
      showBack: true,
      bottomIndex: 1,
      onBottomTap: (i) => residentNav(context, i),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
        children: [
          const Align(alignment: Alignment.centerLeft, child: StatusChip(status: RequestStatus.expired)),
          const SizedBox(height: 8),
          Text(current.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          Text('Este anuncio ya no está disponible', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          const InfoCard(child: Text('La fecha final ya transcurrió. El anuncio se conserva en el historial, pero no admite nuevas solicitudes.')),
          const SizedBox(height: 30),
          Text('Última disponibilidad', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text('${current.startDate.day}–${current.endDate.day} septiembre 2026'),
          const SizedBox(height: 28),
          Text('Ubicación de referencia', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(current.location),
          const SizedBox(height: 90),
          PrimaryButton(label: 'Ver otros oficios', onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(Routes.jobs, (r) => false)),
          const SizedBox(height: 10),
          SecondaryButton(label: 'Volver', onPressed: () => Navigator.of(context).maybePop()),
        ],
      ),
    );
  }

  JobPost _expiredExample() => JobPost(
        id: 'expired-demo',
        title: 'Deshierbe de cultivo',
        category: 'Labores agrícolas',
        location: 'Sector La Escuela, Vereda Travesías',
        description: 'Se requieren dos personas para deshierbe.',
        startDate: DateTime(2026, 9, 18),
        endDate: DateTime(2026, 9, 20),
        people: 2,
        status: RequestStatus.expired,
      );
}
