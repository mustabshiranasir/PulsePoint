import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/blood_request_provider.dart';
import '../models/blood_request_model.dart';
import '../models/cached_request.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../widgets/custom_button.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class DonorDashboard extends StatefulWidget {
  const DonorDashboard({super.key});

  @override
  State<DonorDashboard> createState() => _DonorDashboardState();
}

class _DonorDashboardState extends State<DonorDashboard> {
  Position? _currentPosition;
  bool _fetchingLocation = false;
  String? _locationError;

  // Handles updates to donorLiveLocation in the background
  StreamSubscription<Position>? _liveLocationSubscription;
  String? _activeRequestId;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void dispose() {
    _stopLiveTracking();
    super.dispose();
  }

  // Starts streaming the donor's coordinates to Firestore
  void _startLiveTracking(String requestId) {
    if (_activeRequestId == requestId) return;
    _activeRequestId = requestId;
    _liveLocationSubscription?.cancel();

    final settings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    final bloodProvider = Provider.of<BloodRequestProvider>(context, listen: false);
    _liveLocationSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
      bloodProvider.updateDonorLocation(requestId, position.latitude, position.longitude);
    });
  }

  // Stops location streaming
  void _stopLiveTracking() {
    _liveLocationSubscription?.cancel();
    _liveLocationSubscription = null;
    _activeRequestId = null;
  }

  // Acquires the donor's current position
  Future<void> _fetchLocation() async {
    if (_fetchingLocation) return;
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
        _showPermissionDialog();
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

  // Explains what to do if permissions are permanently denied
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('GPS Permission Required'),
        content: const Text(
          'PulsePoint requires location access to find nearby blood requests. Please enable location permissions in your app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // Handles calling the hospital requester
  Future<void> _callRequester(BuildContext context, String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber.replaceAll(RegExp(r'\s+'), ''),
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        throw Exception('Call functionality is not supported on this device.');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open phone dialer: ${e.toString()}')),
        );
      }
    }
  }

  // Double-checks before accepting
  void _confirmAccept(BuildContext context, BloodRequestModel request, String donorId, String donorPhone) {
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
                _handleAccept(context, request.id, donorId, donorPhone);
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

  void _handleAccept(BuildContext context, String requestId, String donorId, String donorPhone) async {
    final bloodProvider = Provider.of<BloodRequestProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await bloodProvider.acceptRequest(
        requestId: requestId,
        donorId: donorId,
        donorPhone: donorPhone,
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Request accepted successfully! Navigate to the hospital.'),
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

  // Updates request status to completed
  void _markAsArrived(BuildContext context, String requestId) async {
    final bloodProvider = Provider.of<BloodRequestProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await bloodProvider.updateRequestStatus(requestId, 'completed');
      _stopLiveTracking();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Thank you! Blood donation request marked as completed.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red[800],
        ),
      );
    }
  }

  // Simple Haversine calculation to get distance
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371; // Earth's radius in km
    final double dLat = (lat2 - lat1) * math.pi / 180;
    final double dLon = (lon2 - lon1) * math.pi / 180;
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final bloodProvider = Provider.of<BloodRequestProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<List<BloodRequestModel>>(
      stream: bloodProvider.streamDonorActiveRequests(user.uid),
      builder: (context, activeSnapshot) {
        final activeRequests = activeSnapshot.data ?? [];

        if (activeRequests.isNotEmpty) {
          final activeReq = activeRequests.first;
          // Trigger post frame callback to start updating location safely
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startLiveTracking(activeReq.id);
          });
          return _buildNavigationDashboard(context, activeReq, user);
        } else {
          // If no accepted requests are present, stop updates
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _stopLiveTracking();
          });
          return _buildRequestListDashboard(context, user);
        }
      },
    );
  }

  // --- DASHBOARD LAYOUT 1: Navigation / Active Route screen ---
  Widget _buildNavigationDashboard(
      BuildContext context, BloodRequestModel request, var user) {
    final double donorLat = _currentPosition?.latitude ?? request.geoPoint.latitude;
    final double donorLng = _currentPosition?.longitude ?? request.geoPoint.longitude;

    final LatLng hospitalLatLng = LatLng(request.geoPoint.latitude, request.geoPoint.longitude);
    final LatLng donorLatLng = LatLng(donorLat, donorLng);

    // Calculate distance and time (Assuming 35km/h average city speed)
    final double distance = _calculateDistance(
      donorLat,
      donorLng,
      request.geoPoint.latitude,
      request.geoPoint.longitude,
    );
    final int estMinutes = math.max(1, ((distance / 35.0) * 60.0).round());

    return Scaffold(
      appBar: AppBar(
        title: const Text('En Route to Hospital'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.gps_fixed),
            onPressed: _fetchLocation,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Navigation Banner
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Row(
              children: [
                Icon(Icons.directions_car_rounded, color: Colors.blue[800], size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hospital: ${request.hospitalName}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Distance: ${distance.toStringAsFixed(1)} km  •  Est. Time: $estMinutes min',
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Live route Map
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: donorLatLng,
                initialZoom: 14.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.pulsepoint',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [donorLatLng, hospitalLatLng],
                      color: Colors.blue[800]!,
                      strokeWidth: 4.0,
                      pattern: StrokePattern.dashed(segments: const [10, 5]),
                    )
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: hospitalLatLng,
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.local_hospital, color: Colors.red, size: 40),
                    ),
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
                  ],
                ),
              ],
            ),
          ),

          // Control Actions Panel
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 10, spreadRadius: 2)],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Patient: ${request.patientName}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text('Blood Needed: ${request.bloodGroupNeeded} (${request.unitsNeeded} units)'),
                        ],
                      ),
                    ),
                    IconButton.filled(
                      icon: const Icon(Icons.call),
                      style: IconButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: () => _callRequester(context, request.requesterPhone),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                CustomButton(
                  text: 'MARK AS ARRIVED',
                  onPressed: () => _markAsArrived(context, request.id),
                  backgroundColor: Colors.green[800],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- DASHBOARD LAYOUT 2: Standard available requests screen ---
  Widget _buildRequestListDashboard(BuildContext context, var user) {
    final bloodProvider = Provider.of<BloodRequestProvider>(context);
    final bool isAvailable = user.isAvailable ?? false;

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
                await Provider.of<AuthProvider>(context, listen: false).logout();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Logout failed: ${e.toString()}')),
                );
              }
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue[900]),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.person, color: Colors.white, size: 50),
                  SizedBox(height: 10),
                  Text('PulsePoint Donor Menu', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Request History'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await Provider.of<AuthProvider>(context, listen: false).logout();
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Logout failed: ${e.toString()}')));
                }
              },
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Availability header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Row(
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
                      user.bloodGroup ?? 'N/A',
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
                        'Welcome, ${user.name}!',
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
                  onChanged: (bool val) async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await Provider.of<AuthProvider>(context, listen: false)
                          .updateAvailability(val);
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
          ),
          const SizedBox(height: 8),

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
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[900]),
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
                              bloodGroup: user.bloodGroup ?? '',
                              donorLat: _currentPosition!.latitude,
                              donorLng: _currentPosition!.longitude,
                              radiusInKm: 10.0,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              if (snapshot.hasError) {
                                try {
                                  final box = Hive.box<CachedRequest>('cached_requests');
                                  final cachedList = box.values
                                      .where((req) => req.bloodGroupNeeded == user.bloodGroup && req.status == 'pending')
                                      .toList();
                                  if (cachedList.isNotEmpty) {
                                    final lastUpdated = cachedList.first.cachedAt;
                                    return Column(
                                      children: [
                                        Container(
                                          color: Colors.amber[100],
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.cloud_off, color: Colors.orange),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  'Offline Mode. Showing cached requests.\nLast updated: ${DateFormat('MMM dd, yyyy - hh:mm a').format(lastUpdated)}',
                                                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: ListView.builder(
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            itemCount: cachedList.length,
                                            itemBuilder: (context, index) {
                                              final cachedReq = cachedList[index];
                                              final req = BloodRequestModel(
                                                id: cachedReq.id,
                                                requesterId: '',
                                                requesterPhone: '',
                                                patientName: cachedReq.patientName,
                                                bloodGroupNeeded: cachedReq.bloodGroupNeeded,
                                                unitsNeeded: 1,
                                                hospitalName: cachedReq.hospitalName,
                                                hospitalLocation: {},
                                                urgencyLevel: cachedReq.urgencyLevel,
                                                status: cachedReq.status,
                                                createdAt: cachedReq.createdAt,
                                              );
                                              return NearbyRequestCard(
                                                request: req,
                                                distance: 0.0,
                                                onAccept: () {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Cannot accept requests offline.')),
                                                  );
                                                },
                                                isAccepting: false,
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                } catch (_) {}
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
                                          style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue[900]),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'There are no emergency requests for blood group "${user.bloodGroup ?? ''}" within 10km.',
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

                                  final double distance = GeoFirePoint(GeoPoint(
                                    _currentPosition!.latitude,
                                    _currentPosition!.longitude,
                                  )).distanceBetweenInKm(geopoint: req.geoPoint);

                                  return NearbyRequestCard(
                                    request: req,
                                    distance: distance,
                                    onAccept: () => _confirmAccept(context, req, user.uid, user.phone),
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
