import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL']!;
  static String get supabaseAnon => dotenv.env['SUPABASE_ANON_KEY']!;
  static String get stripePub => dotenv.env['STRIPE_PUBLISHABLE_KEY']!;
  static String get mapsKey => dotenv.env['MAPS_API_KEY']!;
  static String get fxBase => dotenv.env['FUNCTIONS_BASE']!;
}
