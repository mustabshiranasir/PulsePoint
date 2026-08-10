import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class DonorDashboard extends StatefulWidget {
  const DonorDashboard({super.key});

  @override
  State<DonorDashboard> createState() => _DonorDashboardState();
}

class _DonorDashboardState extends State<DonorDashboard> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final bool isAvailable = user?.isAvailable ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PulsePoint Donor'),
        backgroundColor: Colors.blue[900],
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
              // Blood group badge design
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.shade100, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withAlpha(26),
                      blurRadius: 16,
                      spreadRadius: 4,
                    )
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        user?.bloodGroup ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const Text(
                        'BLOOD GROUP',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome, ${user?.name ?? 'Donor'}!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
              ),
              const SizedBox(height: 8),
              Chip(
                label: const Text(
                  'Voluntary Blood Donor',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.red[800],
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

              // Availability toggle section
              Card(
                elevation: 4,
                shadowColor: Colors.blue[100],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Available to Donate',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isAvailable
                                    ? 'Active: Requesters can see you'
                                    : 'Inactive: Hidden from search',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isAvailable ? Colors.green[700] : Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Switch.adaptive(
                            value: isAvailable,
                            activeThumbColor: Colors.red,
                            activeTrackColor: Colors.red.shade100,
                            onChanged: authProvider.isLoading
                                ? null
                                : (bool value) async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    try {
                                      await authProvider.updateAvailability(value);
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            value
                                                ? 'Status updated to available!'
                                                : 'Status updated to unavailable.',
                                          ),
                                          backgroundColor: value ? Colors.green : Colors.grey[800],
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    } catch (e) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to update: ${e.toString()}'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                          ),
                        ],
                      ),
                      if (authProvider.isLoading) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(),
                      ]
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Explanatory placeholder card
              Card(
                color: Colors.grey[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'As a donor, when you toggle your availability to active, hospitals and patients in immediate need of blood matching your type can locate and contact you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      height: 1.4,
                    ),
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
