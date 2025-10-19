import 'package:flutter/material.dart';

class RideCheckoutPage extends StatelessWidget {
  const RideCheckoutPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: const Center(child: Text('Stripe payment here')),
    );
  }
}
