import 'package:flutter/material.dart';
import '../utils/route_names.dart';
import '../services/app_state.dart';
import '../widgets/app_shell.dart';
import '../widgets/navigation.dart';
import '../widgets/ui_helpers.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key, required this.state});
  final AppState state;

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  late String category;
  DateTime from = DateTime(2026, 9, 18);
  DateTime to = DateTime(2026, 9, 20);

  @override
  void initState() {
    super.initState();
    category = widget.state.selectedCategory == 'Todas' ? 'Labores agrícolas' : widget.state.selectedCategory;
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Filtrar resultados',
      role: 'Habitante',
      showBack: true,
      bottomIndex: 1,
      onBottomTap: (i) => residentNav(context, i),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
        children: [
          Text('Encuentra disponibilidad vigente', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          const Text('Categoría'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: category,
            items: ['Labores agrícolas', 'Carpintería', 'Reparaciones', 'Todas']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => category = v ?? 'Todas'),
          ),
          const SizedBox(height: 14),
          const Text('Disponible desde'),
          const SizedBox(height: 8),
          _DateField(date: from, onTap: () => _pickDate(true)),
          const SizedBox(height: 14),
          const Text('Disponible hasta'),
          const SizedBox(height: 8),
          _DateField(date: to, onTap: () => _pickDate(false)),
          const SizedBox(height: 14),
          const Text('Ámbito veredal'),
          const SizedBox(height: 8),
          const InfoCard(child: Text('Solo sectores y referencias\ndentro de la Vereda Travesías.')),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Aplicar filtros',
            onPressed: () {
              widget.state.setCategory(category);
              Navigator.of(context).pushNamedAndRemoveUntil(Routes.jobs, (r) => false);
            },
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Limpiar filtros',
            onPressed: () => setState(() {
              category = 'Todas';
              widget.state.setCategory('Todas');
              widget.state.setSearch('');
            }),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: () => Navigator.pushNamed(context, Routes.jobs), child: const Text('Volver al catálogo')),
        ],
      ),
    );
  }

  Future<void> _pickDate(bool start) async {
    final current = start ? from : to;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2026),
      lastDate: DateTime(2027),
    );
    if (picked != null) setState(() => start ? from = picked : to = picked);
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap});
  final DateTime date;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_today_outlined)),
        child: Text('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'),
      ),
    );
  }
}
