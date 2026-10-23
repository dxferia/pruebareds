import 'package:flutter/material.dart';
import 'widgets/travesias_app.dart';
import 'services/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(TravesiasApp(state: AppState(autoLoad: true)));
}
