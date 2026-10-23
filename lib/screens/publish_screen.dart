import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
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
      title: 'Enviar para publicación',
      role: 'Habitante',
      showBack: true,
      bottomIndex: 2,
      onBottomTap: (i) => residentNav(context, i),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          children: [
            Text('Nueva solicitud de publicación', style: Theme.of(context).textTheme.titleLarge),
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
              child: Text('La Junta revisará antes de publicar.'),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: 'Enviar a revisión', onPressed: _submit),
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
    if (!formKey.currentState!.validate()) return;
    if(to.isBefore(from)){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('La fecha final debe ser posterior a la inicial.')));return;}
    try {
      await widget.state.createPublication(title:title.text.trim(),category:category,
        description:description.text.trim(),location:location.text.trim(),start:from,end:to,people:int.parse(quantity.text));
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Solicitud guardada en MySQL para revisión.')));
      Navigator.of(context).pop();
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
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
