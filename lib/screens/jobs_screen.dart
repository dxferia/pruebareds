import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/route_names.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/navigation.dart';
import 'job_detail_screen.dart';

class JobsScreen extends StatelessWidget {
  const JobsScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Oficios disponibles',
      role: 'Habitante',
      bottomIndex: 1,
      onBottomTap: (i) => residentNav(context, i),
      body: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final jobs = state.filteredJobs.where((j) => j.status != RequestStatus.expired).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            children: [
              TextFormField(
                initialValue: state.search,
                onChanged: state.setSearch,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Buscar oficio o labor...',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.filter_list),
                    tooltip: 'Filtrar',
                    onPressed: () => Navigator.pushNamed(context, Routes.filters),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Todas', 'Labores agrícolas', 'Carpintería', 'Reparaciones'].map((c) {
                    final selected = state.selectedCategory == c;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c == 'Labores agrícolas' ? 'Agrícola' : c),
                        selected: selected,
                        onSelected: (_) => state.setCategory(c),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Text('${jobs.length} anuncios vigentes', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 18),
              if (jobs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: Text('No hay resultados con estos filtros.')),
                ),
              ...jobs.map((job) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _JobCard(
                      job: job,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobDetailScreen(state: state, job: job))),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.onTap});
  final JobPost job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(999)),
                      child: Text(job.kind, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 7),
                    Text(job.title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(job.location.replaceAll(', Vereda Travesías', ''), style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(job.people == 1 ? '1 persona' : '${job.people} personas', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
