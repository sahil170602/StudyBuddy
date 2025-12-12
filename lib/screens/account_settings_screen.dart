// lib/screens/account_settings_screen.dart
import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Account', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GlassCard(child: ListTile(leading: const Icon(Icons.person), title: const Text('Profile'))),
          const SizedBox(height: 10),
          GlassCard(child: ListTile(leading: const Icon(Icons.notifications), title: const Text('Notifications'))),
          const SizedBox(height: 10),
          GlassCard(child: ListTile(leading: const Icon(Icons.security), title: const Text('Privacy'))),
          const Spacer(),
          Center(child: ElevatedButton(onPressed: () {}, child: const Text('Sign Out'))),
        ]),
      ),
    );
  }
}
