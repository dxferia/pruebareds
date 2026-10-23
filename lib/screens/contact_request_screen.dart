import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../widgets/app_shell.dart';
import '../widgets/navigation.dart';
import '../widgets/ui_helpers.dart';
import 'request_sent_screen.dart';

class ContactRequestScreen extends StatefulWidget {
  const ContactRequestScreen({super.key, required this.state, required this.job});
  final AppState state;
  final JobPost job;

  @override
  State<ContactRequestScreen> createState() => _ContactRequestScreenState();
}

class _ContactRequestScreenState extends State<ContactRequestScreen> {
  final reason = TextEditingController();
  final phone = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    reason.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Solicitar contacto',
      role: 'Habitante',
      showBack: true,
      bottomIndex: 2,
      onBottomTap: (i) => residentNav(context, i),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          children: [
            Text(widget.job.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(widget.job.location.replaceAll(', Vereda Travesías', '')),
            const SizedBox(height: 22),
            const InfoCard(child: Text('La solicitud quedará vinculada al anuncio.\nNo existe chat en tiempo real.')),
            const SizedBox(height: 20),
            const Text('Motivo breve'),
            const SizedBox(height: 8),
            TextFormField(controller: reason, validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe un motivo.' : null),
            const SizedBox(height: 14),
            const Text('Teléfono autorizado'),
            const SizedBox(height: 8),
            TextFormField(
              controller: phone,
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.replaceAll(' ', '').length < 7) ? 'Ingresa un teléfono válido.' : null,
            ),
            const SizedBox(height: 6),
            Text('Solo lo verán las partes autorizadas.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 70),
            PrimaryButton(label: 'Enviar solicitud', onPressed: _submit),
            const SizedBox(height: 10),
            SecondaryButton(label: 'Cancelar', onPressed: () => Navigator.of(context).maybePop()),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!formKey.currentState!.validate()) return;
    try {
      final request = await widget.state.createContactRequest(jobId: widget.job.id,reason:reason.text.trim(),phone:phone.text.trim());
      if(!mounted)return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => RequestSentScreen(state: widget.state,job:widget.job,request:request)));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
  }
}
