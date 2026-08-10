import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../models/blood_request_model.dart';
import '../models/cached_request.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<dynamic>> _fetchHistory(String uid, String role) async {
    try {
      final query = _firestore.collection('blood_requests')
          .where(role == 'donor' ? 'acceptedByDonorId' : 'requesterId', isEqualTo: uid)
          .where('status', whereIn: ['completed', 'cancelled'])
          .orderBy('createdAt', descending: true);
          
      final snapshot = await query.get();
      return snapshot.docs.map((doc) => BloodRequestModel.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      // Offline fallback
      final box = Hive.box<CachedRequest>('cached_requests');
      // For fallback we just return all cached items matching criteria (naive approach)
      return box.values.where((req) => 
        req.status == 'completed' || req.status == 'cancelled'
      ).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) return const Scaffold();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request History'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _fetchHistory(user.uid, user.role),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
             return Center(child: Text('Error loading history: ${snapshot.error}'));
          }

          final history = snapshot.data ?? [];

          if (history.isEmpty) {
            return const Center(
              child: Text(
                'No past requests found.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              final bool isModel = item is BloodRequestModel;
              
              final status = isModel ? item.status : item.status;
              final hospitalName = isModel ? item.hospitalName : item.hospitalName;
              final patientName = isModel ? item.patientName : item.patientName;
              final createdAt = isModel ? item.createdAt : item.createdAt;
              final bloodGroup = isModel ? item.bloodGroupNeeded : item.bloodGroupNeeded;

              final Color statusColor = status == 'completed' ? Colors.green : Colors.red;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    hospitalName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text('Patient: $patientName'),
                      Text('Blood Needed: $bloodGroup'),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('MMM dd, yyyy - hh:mm a').format(createdAt),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
