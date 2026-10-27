import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/navigation.dart';
import '../widgets/status_chip.dart';
import '../widgets/ui_helpers.dart';
import 'job_detail_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key, required this.state});
  final AppState state;

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  bool publications = true;
  @override void initState(){super.initState();widget.state.loadMine();}

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Mis solicitudes',
      role: 'Habitante',
      bottomIndex: 2,
      onBottomTap: (i) => residentNav(context, i),
      body: AnimatedBuilder(
        animation: widget.state,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
            children: [
              Container(
                height: 42,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: AppColors.suspendedBg, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(child: _TabButton(label: 'Publicaciones', selected: publications, onTap: () => setState(() => publications = true))),
                    Expanded(child: _TabButton(label: 'Contactos', selected: !publications, onTap: () => setState(() => publications = false))),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('Tus movimientos recientes', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (publications && widget.state.myPublications.isEmpty)
                const InfoCard(child: Text('Todavía no has publicado servicios.')),
              if (publications)
                ...widget.state.myPublications.map((p) => _SimpleTile(
                      title: p.title,
                      subtitle: 'Publicada · ${p.publishedAt == null ? '-' : '${p.publishedAt!.day}/${p.publishedAt!.month}'}',
                      status: p.status,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobDetailScreen(state: widget.state, job: p))),
                    ))
              else if (widget.state.contactRequests.isEmpty)
                const InfoCard(child: Text('Todavía no tienes solicitudes de contacto.'))
              else
                ...widget.state.contactRequests.map((c) {
                  final job = widget.state.jobs.where((j)=>j.id==c.jobId);
                  return _SimpleTile(title:job.isEmpty?'Publicación ${c.jobId}':job.first.title,subtitle:'Contacto · ${c.createdAt.day}/${c.createdAt.month}',status:c.status);
                }),
            ],
          );
        },
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(color: selected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(9)),
        child: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}

class _SimpleTile extends StatelessWidget {
  const _SimpleTile({required this.title, required this.subtitle, required this.status, this.onTap});
  final String title;
  final String subtitle;
  final RequestStatus status;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                StatusChip(status: status),
                if (onTap != null) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.chevron_right, color: AppColors.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
