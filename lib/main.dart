import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/env.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  // TEMP: verify keys are loading
  // print('MAPS KEY = ${Env.mapsKey.substring(0, 7)}***');

  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnon);
  runApp(const NewCabbyApp());
}
