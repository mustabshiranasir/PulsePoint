import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../providers/blood_request_provider.dart';
import '../models/blood_request_model.dart';
import '../widgets/custom_button.dart';

class DonorDashboard extends StatefulWidget {
  const DonorDashboard({super.key});

  @override
  State<DonorDashboard> createState() => _DonorDashboardState();
}

class _DonorDashboardState extends State<DonorDashboard> {
  Position? _currentPosition;
  bool _fetchingLocation = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  // Resolves the current GPS coordinates of the donor
  Future<void> _fetchLocation() async {
    setState(() {
      _fetchingLocation = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable GPS.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      final Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _fetchingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = e.toString().replaceAll('Exception: ', '');
          _fetchingLocation = false;
        });
      }
    }
  }

  // Opens a confirmation dialog before accepting the blood request
  void _confirmAccept(BuildContext context, BloodRequestModel request, String donorId) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Confirm Request Acceptance'),
          content: Text(
            'Are you sure you want to accept the request for ${request.patientName} at ${request.hospitalName}? This will notify the hospital that you are arriving to donate.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _handleAccept(context, request.id, donorId);
              },
              child: Text(
                'Accept',
                style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleAccept(BuildContext context, String requestId, String donorId) async {
    final bloodProvider = Provider.of<BloodRequestProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await bloodProvider.acceptRequest(requestId: requestId, donorId: donorId);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Request accepted successfully! Please proceed to the hospital.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red[800],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final bloodProvider = Provider.of<BloodRequestProvider>(context);
    final user = authProvider.currentUser;
    final bool isAvailable = user?.isAvailable ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PulsePoint Donor'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchingLocation ? null : _fetchLocation,
          ),
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Donor Details Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.red.shade100, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          user?.bloodGroup ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${user?.name ?? 'Donor'}!',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Available to Donate: ${isAvailable ? "Active" : "Inactive"}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isAvailable ? Colors.green[700] : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: isAvailable,
                      activeThumbColor: Colors.red,
                      activeTrackColor: Colors.red.shade100,
                      onChanged: authProvider.isLoading
                          ? null
                          : (bool val) async {
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await authProvider.updateAvailability(val);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      val ? 'Availability set to Active!' : 'Availability set to Inactive.',
                                    ),
                                    backgroundColor: val ? Colors.green : Colors.grey[850],
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Failed: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Informative Warning Banner if donor is unavailable
          if (!isAvailable)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange[800]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You are currently marked as Unavailable. Toggle the switch above to let requesters search for you.',
                      style: TextStyle(fontSize: 12, color: Colors.orange[900]),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Text(
              'Nearby Blood Requests (Within 10km)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
          ),

          // Central content depending on GPS state
          Expanded(
            child: _fetchingLocation
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Fetching your GPS coordinates...'),
                      ],
                    ),
                  )
                : _locationError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.location_off, size: 64, color: Colors.red[800]),
                              const SizedBox(height: 16),
                              Text(
                                'GPS Location Error',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _locationError!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _fetchLocation,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Try Again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _currentPosition == null
                        ? Center(
                            child: TextButton(
                              onPressed: _fetchLocation,
                              child: const Text('Click to acquire GPS Location'),
                            ),
                          )
                        : StreamBuilder<List<BloodRequestModel>>(
                            stream: bloodProvider.streamNearbyPendingRequests(
                              bloodGroup: user?.bloodGroup ?? '',
                              donorLat: _currentPosition!.latitude,
                              donorLng: _currentPosition!.longitude,
                              radiusInKm: 10.0,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              if (snapshot.hasError) {
                                return Center(
                                  child: Text('Error loading requests: ${snapshot.error}'),
                                );
                              }

                              final requests = snapshot.data ?? [];

                              if (requests.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.done_all_rounded, size: 64, color: Colors.green[400]),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No pending requests found',
                                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'There are no emergency requests for blood group "${user?.bloodGroup ?? ''}" within 10km.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: requests.length,
                                itemBuilder: (context, index) {
                                  final req = requests[index];

                                  // Calculate distance using GeoFirePoint distance helper
                                  final double distance = GeoFirePoint(GeoPoint(
                                    _currentPosition!.latitude,
                                    _currentPosition!.longitude,
                                  )).distanceBetweenInKm(geopoint: req.geoPoint);

                                  return NearbyRequestCard(
                                    request: req,
                                    distance: distance,
                                    onAccept: () => _confirmAccept(context, req, user!.uid),
                                    isAccepting: bloodProvider.isLoading,
                                  );
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class NearbyRequestCard extends StatelessWidget {
  final BloodRequestModel request;
  final double distance;
  final VoidCallback onAccept;
  final bool isAccepting;

  const NearbyRequestCard({
    super.key,
    required this.request,
    required this.distance,
    required this.onAccept,
    required this.isAccepting,
  });

  Color _getUrgencyColor(String urgency) {
    switch (urgency) {
      case 'critical':
        return Colors.red.shade900;
      case 'high':
        return Colors.orange.shade800;
      default:
        return Colors.blue.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Blood type required
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    request.bloodGroupNeeded,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Urgency level tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getUrgencyColor(request.urgencyLevel).withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    request.urgencyLevel.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getUrgencyColor(request.urgencyLevel),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Patient and Units details
            Text(
              'Patient: ${request.patientName}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Requested Units: ${request.unitsNeeded} unit(s)',
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            const SizedBox(height: 8),
            // Hospital details
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.red),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.hospitalName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Distance indicator
            Row(
              children: [
                const Icon(Icons.navigation, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text(
                  '${distance.toStringAsFixed(1)} km away',
                  style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const Divider(height: 24),
            // Accept Request Button
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'ACCEPT REQUEST',
                onPressed: isAccepting ? null : onAccept,
                isLoading: isAccepting,
                backgroundColor: Colors.blue[900],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
