import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../widgets/app_shell.dart';
import '../widgets/navigation.dart';
import '../widgets/status_chip.dart';
import '../widgets/ui_helpers.dart';

class ReviewRequestScreen extends StatelessWidget {
  const ReviewRequestScreen({super.key, required this.state, required this.request});
  final AppState state;
  final PublicationRequest request;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Revisar solicitud',
      role: 'Junta',
      junta: true,
      showBack: true,
      bottomIndex: 1,
      onBottomTap: (i) => juntaNav(context, i),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
        children: [
          Align(alignment: Alignment.centerLeft, child: StatusChip(status: request.status)),
          const SizedBox(height: 8),
          Text(request.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 22),
          _Line(label: 'Categoría', value: request.category),
          _Line(label: 'Descripción', value: request.description),
          _Line(label: 'Ubicación', value: '${request.location}, Vereda Travesías'),
          _Line(label: 'Disponibilidad', value: '${request.startDate.day}–${request.endDate.day} septiembre 2026'),
          const _Line(label: 'Contacto autorizado', value: 'Visible para gestión de la Junta'),
          const SizedBox(height: 58),
          PrimaryButton(
            label: 'Aprobar y publicar',
            onPressed: () async {
              final tipo = await showDialog<String>(
                context: context,
                builder: (dialogContext) => SimpleDialog(
                  title: const Text('Tipo de publicación'),
                  children: [
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(dialogContext, 'LABOR'),
                      child: const Text('Labor'),
                    ),
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(dialogContext, 'SERVICIO'),
                      child: const Text('Servicio'),
                    ),
                  ],
                ),
              );
              if(tipo==null || !context.mounted)return;
              try {await state.updatePublicationStatus(request.id,RequestStatus.approved,tipo:tipo);
                if(!context.mounted)return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Publicación aprobada en MySQL.')));
                Navigator.of(context).pop();
              }catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
            },
          ),
          const SizedBox(height: 10),
          SecondaryButton(label: 'Rechazar', danger: true, onPressed: () => _reject(context)),
          const SizedBox(height: 8),
          Text('Al rechazar se solicitará un motivo.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Future<void> _reject(BuildContext context) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Motivo del rechazo'),
        content: TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(hintText: 'Describe qué debe corregirse...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Rechazar')),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    try {await state.updatePublicationStatus(request.id,RequestStatus.rejected,reason:reason);
      if(context.mounted)Navigator.of(context).pop();
    }catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 5),
        Text(value),
      ]),
    );
  }
}
