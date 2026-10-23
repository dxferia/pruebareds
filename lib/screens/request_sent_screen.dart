import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/route_names.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/navigation.dart';
import '../widgets/status_chip.dart';
import '../widgets/ui_helpers.dart';

class RequestSentScreen extends StatelessWidget {
  const RequestSentScreen({super.key, required this.state, required this.job, required this.request});
  final AppState state;
  final JobPost job;
  final ContactRequest request;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Solicitud enviada',
      role: 'Habitante',
      showBack: true,
      bottomIndex: 2,
      onBottomTap: (i) => residentNav(context, i),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 38, 22, 28),
        children: [
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(color: AppColors.approvedBg, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: AppColors.approvedFg, size: 46),
            ),
          ),
          const SizedBox(height: 20),
          Text('Solicitud registrada', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('La persona responsable podrá consultar tu solicitud.\nRevisa el estado desde “Solicitudes”.', textAlign: TextAlign.center),
          const SizedBox(height: 34),
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Enviada · ${request.createdAt.day} sep ${request.createdAt.year}', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                const StatusChip(status: RequestStatus.pending),
              ],
            ),
          ),
          const SizedBox(height: 44),
          PrimaryButton(
            label: 'Ver mis solicitudes',
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(Routes.myRequests, (r) => false),
          ),
        ],
      ),
    );
  }
}
