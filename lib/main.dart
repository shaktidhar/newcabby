import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/env.dart';
import 'app/app.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnon);

  // Initialize Stripe ONLY on mobile right now
  if (!kIsWeb) {
    // however you load your key (dotenv, etc.)
    // e.g., final pk = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
    final pk = const String.fromEnvironment('STRIPE_PUBLISHABLE_KEY', defaultValue: '');
    if (pk.isNotEmpty) {
      stripe.Stripe.publishableKey = pk;
      await stripe.Stripe.instance.applySettings();
    }
  }

  runApp(const NewCabbyApp());
}
