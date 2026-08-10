import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/blood_request_provider.dart';
import '../models/blood_request_model.dart';

class DonorTrackingScreen extends StatelessWidget {
  final String requestId;
  const DonorTrackingScreen({super.key, required this.requestId});

  Future<void> _callDonor(BuildContext context, String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber.replaceAll(RegExp(r'\s+'), ''),
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        throw Exception('Dialer not supported.');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open phone dialer: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloodProvider = Provider.of<BloodRequestProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Donor Tracking'),
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<BloodRequestModel?>(
        stream: bloodProvider.streamRequest(requestId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final request = snapshot.data;
          if (request == null) {
            return const Center(child: Text('Blood request details not found.'));
          }

          final hospitalLatLng = LatLng(request.geoPoint.latitude, request.geoPoint.longitude);
          LatLng? donorLatLng;
          if (request.donorLiveLocation != null) {
            donorLatLng = LatLng(
              request.donorLiveLocation!.latitude,
              request.donorLiveLocation!.longitude,
            );
          }

          // Compute map bounds/center
          final centerLatLng = donorLatLng ?? hospitalLatLng;
          final markers = <Marker>[
            Marker(
              point: hospitalLatLng,
              width: 50,
              height: 50,
              child: const Icon(Icons.local_hospital, color: Colors.red, size: 40),
            ),
          ];

          if (donorLatLng != null) {
            markers.add(
              Marker(
                point: donorLatLng,
                width: 50,
                height: 50,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(50),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.directions_run_rounded, color: Colors.blueAccent, size: 36),
                ),
              ),
            );
          }

          final polylines = <Polyline>[];
          if (donorLatLng != null) {
            polylines.add(
              Polyline(
                points: [donorLatLng, hospitalLatLng],
                color: Colors.blue[900]!,
                strokeWidth: 4.0,
                pattern: StrokePattern.dashed(segments: const [10, 5]),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Live status banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: donorLatLng == null ? Colors.orange[50] : Colors.green[50],
                child: Row(
                  children: [
                    Icon(
                      donorLatLng == null ? Icons.gps_off_rounded : Icons.gps_fixed_rounded,
                      color: donorLatLng == null ? Colors.orange[800] : Colors.green[800],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        donorLatLng == null
                            ? 'Waiting for donor\'s GPS signal to update...'
                            : 'Donor is active and en route!',
                        style: TextStyle(
                          color: donorLatLng == null ? Colors.orange[900] : Colors.green[900],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Map rendering area
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: centerLatLng,
                    initialZoom: 14.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.pulsepoint',
                    ),
                    if (polylines.isNotEmpty)
                      PolylineLayer(
                        polylines: polylines,
                      ),
                    MarkerLayer(
                      markers: markers,
                    ),
                  ],
                ),
              ),

              // Bottom card with Donor details
              Card(
                margin: const EdgeInsets.all(16),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Assigned Donor Details',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            child: Icon(Icons.person, color: Colors.blue[900]),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Voluntary Donor En Route',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Status: ${request.status.toUpperCase()}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (request.acceptedByDonorPhone != null &&
                              request.acceptedByDonorPhone!.isNotEmpty)
                            IconButton.filled(
                              icon: const Icon(Icons.call),
                              style: IconButton.styleFrom(backgroundColor: Colors.green),
                              onPressed: () => _callDonor(context, request.acceptedByDonorPhone!),
                            ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text(
                        'Patient: ${request.patientName}  •  Blood Needed: ${request.bloodGroupNeeded}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Destination: ${request.hospitalName}',
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
