import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../utils/route_names.dart';
import '../widgets/app_shell.dart';
import '../widgets/navigation.dart';
import '../widgets/ui_helpers.dart';

class PublishScreen extends StatefulWidget {
  const PublishScreen({super.key, required this.state});
  final AppState state;

  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends State<PublishScreen> {
  final formKey = GlobalKey<FormState>();
  String category = 'Labores agrícolas';
  String kind = 'LABOR';
  bool sending = false;
  String? submissionKey; // se conserva entre reintentos: el servidor no duplica la publicación
  final title = TextEditingController();
  final description = TextEditingController();
  final quantity = TextEditingController();
  final location = TextEditingController();
  DateTime from = DateTime.now();
  DateTime to = DateTime.now().add(const Duration(days: 7));

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    quantity.dispose();
    location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Publicar servicio',
      role: 'Habitante',
      showBack: true,
      bottomIndex: 2,
      onBottomTap: (i) => residentNav(context, i),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          children: [
            Text('Nueva publicación', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            _label('Título'),
            TextFormField(controller: title, validator: _required),
            const SizedBox(height: 12),
            _label('Categoría'),
            DropdownButtonFormField<String>(
              initialValue: category,
              items: ['Labores agrícolas', 'Carpintería', 'Reparaciones', 'Otros oficios']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => category = v ?? category),
            ),
            const SizedBox(height: 12),
            _label('Tipo'),
            DropdownButtonFormField<String>(
              initialValue: kind,
              items: const [
                DropdownMenuItem(value: 'LABOR', child: Text('Labor')),
                DropdownMenuItem(value: 'SERVICIO', child: Text('Servicio')),
              ],
              onChanged: (v) => setState(() => kind = v ?? kind),
            ),
            const SizedBox(height: 12),
            _label('Descripción'),
            TextFormField(controller: description, validator: _required, maxLines: 2),
            const SizedBox(height: 12),
            _label('Cantidad'),
            TextFormField(
              controller: quantity,
              keyboardType: TextInputType.number,
              validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'Ingresa una cantidad válida.' : null,
            ),
            const SizedBox(height: 12),
            _label('Ubicación de referencia'),
            TextFormField(controller: location, validator: _required),
            const SizedBox(height: 12),
            _label('Fechas de disponibilidad'),
            Row(
              children: [
                Expanded(child: _DateBox(date: from, onTap: () => _pick(true))),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('–')),
                Expanded(child: _DateBox(date: to, onTap: () => _pick(false))),
              ],
            ),
            const SizedBox(height: 72),
            const InfoCard(
              background: AppColors.background,
              child: Text('Tu publicación aparecerá de inmediato, en primer lugar, en Oficios disponibles.'),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: sending ? 'Publicando...' : 'Publicar', loading: sending, onPressed: _submit),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(text),
      );

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Campo obligatorio.' : null;

  Future<void> _pick(bool isFrom) async {
    final value = isFrom ? from : to;
    final picked = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(2026),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => isFrom ? from = picked : to = picked);
  }

  Future<void> _submit() async {
    if (sending || !formKey.currentState!.validate()) return;
    if(to.isBefore(from)){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('La fecha final debe ser posterior a la inicial.')));return;}
    setState(() => sending = true);
    try {
      await widget.state.createPublication(title:title.text.trim(),category:category,kind:kind,
        description:description.text.trim(),location:location.text.trim(),start:from,end:to,people:int.parse(quantity.text),
        claveEnvio: submissionKey ??= ApiService.claveEnvio());
      if(!mounted)return;
      // Solo tras la confirmación del backend: el catálogo ya la muestra en primer lugar.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('¡Publicado! Tu servicio ya aparece primero en el catálogo.')));
      Navigator.of(context).pushNamedAndRemoveUntil(Routes.jobs, (r) => false);
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));
    }finally{
      if(mounted)setState(() => sending = false);
    }
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({required this.date, required this.onTap});
  final DateTime date;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 13)),
        child: Text('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}', style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}
