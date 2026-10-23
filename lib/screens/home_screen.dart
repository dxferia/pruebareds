import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/route_names.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/navigation.dart';
import '../widgets/status_chip.dart';
import '../widgets/ui_helpers.dart';
import 'job_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final featured = state.jobs.isEmpty ? null : state.jobs.first;
    return AnimatedBuilder(animation:state,builder:(context,_)=>AppShell(
      title: 'Travesías Conecta',
      role: 'Habitante',
      bottomIndex: 0,
      onBottomTap: (i) => residentNav(context, i),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        children: [
          Text('Oficios y trabajadores', style: Theme.of(context).textTheme.headlineMedium),
          Text('de la Vereda Travesías', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            'Consulta servicios y disponibilidad\ncon información validada por la comunidad.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),
          InkWell(
            onTap: () => Navigator.pushNamed(context, Routes.jobs),
            borderRadius: BorderRadius.circular(10),
            child: const IgnorePointer(
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: '¿Qué oficio necesitas?',
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SectionTitle('Categorías'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 2.9,
            children: [
              _CategoryTile(label: 'Labores agrícolas', onTap: () => _goCategory(context, 'Labores agrícolas')),
              _CategoryTile(label: 'Carpintería', onTap: () => _goCategory(context, 'Carpintería')),
              _CategoryTile(label: 'Reparaciones', onTap: () => _goCategory(context, 'Reparaciones')),
              _CategoryTile(label: 'Otros oficios', onTap: () => _goCategory(context, 'Todas')),
            ],
          ),
          const SizedBox(height: 20),
          SectionTitle(
            'Disponibles hoy',
            trailing: TextButton(
              onPressed: () => Navigator.pushNamed(context, Routes.jobs),
              child: const Text('Ver todos'),
            ),
          ),
          const SizedBox(height: 8),
          if (featured == null) InfoCard(child: Text(state.loading ? 'Cargando publicaciones desde MySQL...' : state.error ?? 'No hay publicaciones vigentes en este momento.')),
          if (featured != null) Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobDetailScreen(state: state, job: featured))),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const StatusChip(status: RequestStatus.active),
                    const SizedBox(height: 8),
                    Text(featured.title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(featured.location, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 130,
                        child: PrimaryButton(
                          label: 'Ver detalle',
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobDetailScreen(state: state, job: featured))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const InfoCard(
            background: Color(0xFFF3F6F4),
            child: Text('Identidad integrada: Universidad · Sistemas · Red Comunitaria', textAlign: TextAlign.center),
          ),
        ],
      ),
    ));
  }

  void _goCategory(BuildContext context, String category) {
    state.setCategory(category);
    Navigator.pushNamed(context, Routes.jobs);
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.work_outline, color: AppColors.primary, size: 21),
              const SizedBox(width: 10),
              Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }
}
