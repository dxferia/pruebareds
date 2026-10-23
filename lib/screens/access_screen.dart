import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/navigation.dart';
import '../widgets/status_chip.dart';
import '../widgets/ui_helpers.dart';

class AccessScreen extends StatefulWidget {
  const AccessScreen({super.key, required this.state});
  final AppState state;

  @override
  State<AccessScreen> createState() => _AccessScreenState();
}

class _AccessScreenState extends State<AccessScreen> {
  CommunityAccess? selected;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Accesos veredales',
      role: 'Junta',
      junta: true,
      bottomIndex: 3,
      onBottomTap: (i) => juntaNav(context, i),
      body: AnimatedBuilder(
        animation: widget.state,
        builder: (context, _) {
          final pending = widget.state.accesses.where((a) => a.status == RequestStatus.pending).length;
          return ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          children: [
            Text('Cuentas de la comunidad', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            Text('$pending pendientes de validación'),
            const SizedBox(height: 24),
            ...widget.state.accesses.map((access) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Card(
                    child: InkWell(
                      onTap: () => setState(() => selected = access),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(color: identical(selected, access) ? AppColors.primary : Colors.transparent, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.background,
                              child: Text(access.name.isEmpty ? '?' : access.name.substring(0, 1), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(access.name, style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text('Habitante de Travesías', style: Theme.of(context).textTheme.bodySmall),
                              ]),
                            ),
                            StatusChip(status: access.status),
                          ],
                        ),
                      ),
                    ),
                  ),
                )),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Revisar seleccionada', onPressed: selected == null ? null : () => _review(context)),
            const SizedBox(height: 8),
            Text('El botón solo se habilita con una selección.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ],
          );
        },
      ),
    );
  }

  Future<void> _review(BuildContext context) async {
    if (selected == null) return;
    final result = await showModalBottomSheet<RequestStatus>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gestionar acceso de ${selected!.name}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              PrimaryButton(label: 'Aprobar acceso', onPressed: () => Navigator.pop(context, RequestStatus.approved)),
              const SizedBox(height: 10),
              SecondaryButton(label: 'Suspender acceso', danger: true, onPressed: () => Navigator.pop(context, RequestStatus.suspended)),
            ],
          ),
        ),
      ),
    );
    if (result != null) {
      try {
        await widget.state.updateAccess(selected!, result);
        if (!context.mounted) return;
        setState(() => selected = null);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}
