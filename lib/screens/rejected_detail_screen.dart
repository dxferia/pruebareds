import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../widgets/app_shell.dart';
import '../widgets/navigation.dart';
import '../widgets/status_chip.dart';
import '../widgets/ui_helpers.dart';
import 'publish_screen.dart';

class RejectedDetailScreen extends StatelessWidget {
  const RejectedDetailScreen({super.key, required this.state, required this.request});
  final AppState state;
  final PublicationRequest request;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Detalle de solicitud',
      role: 'Habitante',
      showBack: true,
      bottomIndex: 2,
      onBottomTap: (i) => residentNav(context, i),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
        children: [
          const Align(alignment: Alignment.centerLeft, child: StatusChip(status: RequestStatus.rejected)),
          const SizedBox(height: 8),
          Text(request.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 3),
          const Text('Solicitud de publicación'),
          const SizedBox(height: 30),
          Text('Motivo de la Junta', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          InfoCard(child: Text(request.rejectionReason ?? 'La solicitud requiere ajustes antes de volver a enviarse.')),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: _DateColumn(label: 'Enviada', value: '${request.createdAt.day} sep 2026')),
              Expanded(child: _DateColumn(label: 'Revisada', value: '${request.createdAt.day + 1} sep 2026')),
            ],
          ),
          const SizedBox(height: 76),
          PrimaryButton(
            label: 'Corregir y reenviar',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PublishScreen(state: state))),
          ),
          const SizedBox(height: 10),
          SecondaryButton(label: 'Volver', onPressed: () => Navigator.of(context).maybePop()),
        ],
      ),
    );
  }
}

class _DateColumn extends StatelessWidget {
  const _DateColumn({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(label, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 4), Text(value)],
      );
}
