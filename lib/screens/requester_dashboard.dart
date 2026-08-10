import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class RequesterDashboard extends StatelessWidget {
  const RequesterDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PulsePoint Requester'),
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await authProvider.logout();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Logout failed: ${e.toString()}')),
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_hospital_rounded,
                  size: 80,
                  color: Colors.red[800],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome, ${user?.name ?? 'Requester'}!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
              ),
              const SizedBox(height: 8),
              Chip(
                label: const Text(
                  'Hospital / Patient',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.blue[800],
              ),
              const SizedBox(height: 16),
              Icon(Icons.phone_android_rounded, color: Colors.grey[600]),
              const SizedBox(height: 4),
              Text(
                user?.phone ?? 'N/A',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              Card(
                elevation: 4,
                shadowColor: Colors.red[100],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        'Find Blood Donors',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[800],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This dashboard is configured for blood requesters. Future releases will allow you to find nearby compatible blood groups, view emergency lists, and request immediate assistance.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
