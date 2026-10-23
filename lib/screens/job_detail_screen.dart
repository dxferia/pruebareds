import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../widgets/app_shell.dart';
import '../widgets/navigation.dart';
import '../widgets/status_chip.dart';
import '../widgets/ui_helpers.dart';
import 'contact_request_screen.dart';
import 'expired_publication_screen.dart';

class JobDetailScreen extends StatelessWidget {
  const JobDetailScreen({super.key, required this.state, required this.job});
  final AppState state;
  final JobPost job;

  @override
  Widget build(BuildContext context) {
    if (job.status == RequestStatus.expired) {
      return ExpiredPublicationScreen(state: state, job: job);
    }
    return AppShell(
      title: 'Detalle del anuncio',
      role: 'Habitante',
      showBack: true,
      bottomIndex: 1,
      onBottomTap: (i) => residentNav(context, i),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
        children: [
          const Align(alignment: Alignment.centerLeft, child: StatusChip(status: RequestStatus.active)),
          const SizedBox(height: 8),
          Text(job.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text('Servicio individual', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 26),
          _Field(label: 'Descripción', value: job.description),
          _Field(label: 'Ubicación', value: job.location),
          _Field(label: 'Disponibilidad', value: '${_short(job.startDate)} – ${_short(job.endDate)}'),
          const _Field(label: 'Responsable', value: 'Contacto visible solo mediante\nsolicitud autorizada.'),
          const SizedBox(height: 70),
          PrimaryButton(
            label: 'Solicitar contacto',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ContactRequestScreen(state: state, job: job))),
          ),
          const SizedBox(height: 10),
          SecondaryButton(label: 'Volver', onPressed: () => Navigator.of(context).maybePop()),
        ],
      ),
    );
  }

  String _short(DateTime d) => '${d.day} sep · ${d.hour == 0 ? '' : '${d.hour.toString().padLeft(2, '0')}:00'}';
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(value),
        ],
      ),
    );
  }
}
