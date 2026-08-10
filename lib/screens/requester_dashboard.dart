import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/blood_request_provider.dart';
import '../models/blood_request_model.dart';
import '../widgets/custom_button.dart';
import 'donor_tracking_screen.dart';

class RequesterDashboard extends StatelessWidget {
  const RequesterDashboard({super.key});


  // Opens the modal bottom sheet containing the Request Form
  void _openRequestSheet(BuildContext context, String requesterId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: RequestFormSheet(requesterId: requesterId),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final bloodProvider = Provider.of<BloodRequestProvider>(context);
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRequestSheet(context, user!.uid),
        label: const Text('Request Blood'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Greeting & Profile Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.red[100],
                  radius: 30,
                  child: Icon(Icons.local_hospital_rounded, color: Colors.red[800], size: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, ${user?.name ?? 'Requester'}!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Role: Hospital / Patient  •  ${user?.phone ?? 'N/A'}',
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Request list header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              'Your Blood Requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Stream Builder of requester's own requests
          Expanded(
            child: StreamBuilder<List<BloodRequestModel>>(
              stream: bloodProvider.streamRequesterRequests(user?.uid ?? ''),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
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
                          Icon(Icons.bloodtype_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No active blood requests.',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap "Request Blood" to raise a donation call.',
                            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    return RequestCard(request: req);
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

// Request Form Widget inside Bottom Sheet
class RequestFormSheet extends StatefulWidget {
  final String requesterId;
  const RequestFormSheet({super.key, required this.requesterId});

  @override
  State<RequestFormSheet> createState() => _RequestFormSheetState();
}

class _RequestFormSheetState extends State<RequestFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _patientNameController = TextEditingController();
  final _unitsController = TextEditingController(text: '1');
  final _hospitalNameController = TextEditingController();

  String _selectedBloodGroup = 'A+';
  String _selectedUrgency = 'normal';
  bool _fetchingLocation = false;

  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> _urgencies = ['normal', 'high', 'critical'];

  @override
  void dispose() {
    _patientNameController.dispose();
    _unitsController.dispose();
    _hospitalNameController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _fetchingLocation = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bloodProvider = Provider.of<BloodRequestProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // 1. Fetch GPS location coordinates
      final position = await _determineGPSPosition();
      final requesterPhone = authProvider.currentUser?.phone ?? '';

      // 2. Post new blood request to Firestore
      await bloodProvider.createRequest(
        requesterId: widget.requesterId,
        requesterPhone: requesterPhone,
        patientName: _patientNameController.text.trim(),
        bloodGroupNeeded: _selectedBloodGroup,
        unitsNeeded: int.parse(_unitsController.text),
        hospitalName: _hospitalNameController.text.trim(),
        latitude: position.latitude,
        longitude: position.longitude,
        urgencyLevel: _selectedUrgency,
      );

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Blood request posted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      navigator.pop(); // Close sheet
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red[800],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _fetchingLocation = false;
        });
      }
    }
  }

  Future<Position> _determineGPSPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('GPS is disabled. Please enable location services.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission is denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is permanently denied.');
    }

    return await Geolocator.getCurrentPosition();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Emergency Request Form',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),

            // Patient Name field
            TextFormField(
              controller: _patientNameController,
              decoration: const InputDecoration(
                labelText: 'Patient Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter the patient name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Hospital Name field
            TextFormField(
              controller: _hospitalNameController,
              decoration: const InputDecoration(
                labelText: 'Hospital Name',
                prefixIcon: Icon(Icons.local_hospital_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter the hospital name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                // Blood group selection
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedBloodGroup,
                    decoration: const InputDecoration(
                      labelText: 'Blood Group',
                    ),
                    items: _bloodGroups.map((group) {
                      return DropdownMenuItem<String>(
                        value: group,
                        child: Text(group),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedBloodGroup = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Units Needed field
                Expanded(
                  child: TextFormField(
                    controller: _unitsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Units Required',
                      prefixIcon: Icon(Icons.opacity),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final units = int.tryParse(value);
                      if (units == null || units <= 0) {
                        return 'Enter a valid number';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Urgency Selection
            DropdownButtonFormField<String>(
              initialValue: _selectedUrgency,
              decoration: const InputDecoration(
                labelText: 'Urgency Level',
              ),
              items: _urgencies.map((urgency) {
                return DropdownMenuItem<String>(
                  value: urgency,
                  child: Text(urgency.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedUrgency = value;
                  });
                }
              },
            ),
            const SizedBox(height: 24),

            // Submit request
            CustomButton(
              text: _fetchingLocation ? 'Acquiring GPS Location...' : 'POST REQUEST',
              onPressed: _submit,
              isLoading: _fetchingLocation,
              backgroundColor: Colors.red[800],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// Request Card displaying status details
class RequestCard extends StatelessWidget {
  final BloodRequestModel request;
  const RequestCard({super.key, required this.request});

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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM dd, yyyy  •  hh:mm a').format(request.createdAt);

    return Card(
      elevation: 2,
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
                // Blood group badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Text(
                    request.bloodGroupNeeded,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
                // Urgency and Status Tags
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getUrgencyColor(request.urgencyLevel).withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(request.status).withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        request.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(request.status),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Patient details
            Row(
              children: [
                const Icon(Icons.person, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Patient: ${request.patientName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                Text(
                  '${request.unitsNeeded} Unit(s)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Hospital details
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request.hospitalName,
                    style: TextStyle(color: Colors.grey[800]),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Posted: $dateStr',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                if (request.status == 'accepted')
                  TextButton.icon(
                    icon: const Icon(Icons.map_rounded, size: 16),
                    label: const Text('TRACK DONOR'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DonorTrackingScreen(requestId: request.id),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red[800],
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
