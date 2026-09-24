import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String supabaseUrl =
    'https://lybbdqwgfjekrqhhgdkf.supabase.co';

const String supabaseAnonKey =
    'sb_publishable_2J95CnOji4M7eU2BInHEXQ_wHw1kkhb';

late final SupabaseClient supabase;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  supabase = Supabase.instance.client;

  runApp(const ServiceBookingApp());
}

class ServiceBookingApp extends StatelessWidget {
  const ServiceBookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Service Booking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF101010),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFA45C),
          brightness: Brightness.dark,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1B1B1B),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1B1B1B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

/* ============================================================
   HELPERS
============================================================ */

String valueString(dynamic value) {
  return value?.toString() ?? '';
}

String timeString(dynamic value) {
  final text = valueString(value);

  if (text.length >= 5) {
    return text.substring(0, 5);
  }

  return text;
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return <String, dynamic>{};
}

/* ============================================================
   REPOSITORY
============================================================ */

class BookingRepository {
  Future<List<Map<String, dynamic>>> getServices() async {
    final response = await supabase
        .from('services')
        .select()
        .eq('active', true)
        .order('created_at');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> getService(String id) async {
    final response = await supabase
        .from('services')
        .select()
        .eq('id', id)
        .single();

    return Map<String, dynamic>.from(response);
  }

  Future<List<Map<String, dynamic>>> getLocations(
    String serviceId,
  ) async {
    final links = await supabase
        .from('service_locations')
        .select('location_id')
        .eq('service_id', serviceId);

    final ids = links
        .map<String>((item) => item['location_id'].toString())
        .toList();

    if (ids.isEmpty) {
      return [];
    }

    final response = await supabase
        .from('locations')
        .select()
        .inFilter('id', ids)
        .eq('active', true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getSlots({
    required String serviceId,
    required String locationId,
    required DateTime date,
  }) async {
    final day = date.toIso8601String().substring(0, 10);

    final response = await supabase
        .from('availability_slots')
        .select()
        .eq('service_id', serviceId)
        .eq('location_id', locationId)
        .eq('slot_date', day)
        .eq('status', 'available')
        .order('start_time');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> createBooking(
    String slotId,
  ) async {
    final response = await supabase.rpc(
      'create_booking',
      params: {
        'p_slot_id': slotId,
      },
    );

    return Map<String, dynamic>.from(response);
  }

  Future<List<Map<String, dynamic>>> getMyBookings() async {
    final response = await supabase
        .from('bookings')
        .select(
          '*, services(name), locations(name), '
          'availability_slots(slot_date,start_time,end_time)',
        )
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> cancelBooking(
    String bookingId,
  ) async {
    await supabase.rpc(
      'cancel_booking',
      params: {
        'p_booking_id': bookingId,
        'p_reason': 'Customer cancellation',
      },
    );
  }

  Future<void> confirmBooking(
    String bookingId,
  ) async {
    await supabase.rpc(
      'confirm_booking',
      params: {
        'p_booking_id': bookingId,
      },
    );
  }
}

final BookingRepository repository = BookingRepository();

/* ============================================================
   HOME
============================================================ */

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Map<String, dynamic>>> servicesFuture;

  @override
  void initState() {
    super.initState();

    servicesFuture = repository.getServices();
  }

  Future<void> refresh() async {
    setState(() {
      servicesFuture = repository.getServices();
    });

    await servicesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AppBottomNavigation(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 10),

              const Text(
                'Book your service',
                style: TextStyle(
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Choose a service, location, date and available time.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFB36D),
                      Color(0xFFE97F3F),
                    ],
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Simple. Fast. Confirmed.',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Real-time availability and secure bookings.',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Services',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 14),

              FutureBuilder<List<Map<String, dynamic>>>(
                future: servicesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return const ErrorCard(
                      message: 'Unable to load services.',
                    );
                  }

                  final services = snapshot.data ?? [];

                  if (services.isEmpty) {
                    return const EmptyCard(
                      title: 'No services yet',
                      message:
                          'There are currently no active services.',
                    );
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics:
                        const NeverScrollableScrollPhysics(),
                    itemCount: services.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: .85,
                    ),
                    itemBuilder: (context, index) {
                      return ServiceCard(
                        service: services[index],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ============================================================
   SERVICE CARD
============================================================ */

class ServiceCard extends StatelessWidget {
  final Map<String, dynamic> service;

  const ServiceCard({
    super.key,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final id = valueString(service['id']);
    final name = valueString(service['name']);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceScreen(
              serviceId: id,
            ),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: RemoteImage(
                url: valueString(service['image_url']),
                icon: Icons.medical_services_outlined,
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                name.isEmpty ? 'Service' : name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
   REMOTE IMAGE
============================================================ */

class RemoteImage extends StatelessWidget {
  final String url;
  final IconData icon;

  const RemoteImage({
    super.key,
    required this.url,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        width: double.infinity,
        color: const Color(0xFF292929),
        child: Center(
          child: Icon(
            icon,
            size: 48,
            color: const Color(0xFFFFA45C),
          ),
        ),
      );
    }

    return Image.network(
      url,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: const Color(0xFF292929),
          child: Center(
            child: Icon(
              icon,
              size: 48,
            ),
          ),
        );
      },
    );
  }
}

/* ============================================================
   SERVICE SCREEN
============================================================ */

class ServiceScreen extends StatefulWidget {
  final String serviceId;

  const ServiceScreen({
    super.key,
    required this.serviceId,
  });

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  Map<String, dynamic>? service;

  List<Map<String, dynamic>> locations = [];

  List<Map<String, dynamic>> slots = [];

  String? selectedLocation;

  String? selectedSlot;

  DateTime selectedDate = DateTime.now();

  bool loading = true;

  @override
  void initState() {
    super.initState();

    loadData();
  }

  Future<void> loadData() async {
    setState(() {
      loading = true;
    });

    try {
      service =
          await repository.getService(widget.serviceId);

      locations =
          await repository.getLocations(widget.serviceId);

      if (locations.isNotEmpty) {
        selectedLocation =
            valueString(locations.first['id']);

        await loadSlots();
      }
    } catch (error) {
      slots = [];
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> loadSlots() async {
    final location = selectedLocation;

    if (location == null) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      slots = await repository.getSlots(
        serviceId: widget.serviceId,
        locationId: location,
        date: selectedDate,
      );

      selectedSlot = null;
    } catch (error) {
      slots = [];
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate:
          DateTime.now().add(const Duration(days: 90)),
      initialDate: selectedDate,
    );

    if (picked == null) {
      return;
    }

    setState(() {
      selectedDate = picked;
    });

    await loadSlots();
  }

  Future<void> book() async {
    if (selectedSlot == null) {
      return;
    }

    if (supabase.auth.currentUser == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AuthScreen(),
        ),
      );

      return;
    }

    try {
      final booking =
          await repository.createBooking(selectedSlot!);

      if (!mounted) {
        return;
      }

      final status =
          valueString(booking['status']);

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
              status == 'confirmed'
                  ? 'Booking confirmed'
                  : 'Booking pending',
            ),
            content: Text(
              status == 'confirmed'
                  ? 'Your appointment has been confirmed.'
                  : 'Your booking is waiting for provider confirmation for up to 4 hours.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const BookingsScreen(),
                    ),
                  );
                },
                child: const Text('View bookings'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This time slot is no longer available.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final serviceData = service;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          valueString(serviceData?['name']).isEmpty
              ? 'Service'
              : valueString(serviceData?['name']),
        ),
      ),
      body: loading && serviceData == null
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (serviceData != null)
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(25),
                    child: SizedBox(
                      height: 190,
                      child: RemoteImage(
                        url: valueString(
                          serviceData['image_url'],
                        ),
                        icon: Icons
                            .medical_services_outlined,
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                Text(
                  valueString(serviceData?['name']),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  valueString(
                    serviceData?['description'],
                  ),
                  style: const TextStyle(
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: 25),

                const Text(
                  'Location',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 10),

                if (locations.isEmpty)
                  const EmptyCard(
                    title: 'No locations',
                    message:
                        'No locations are available for this service.',
                  )
                else
                  DropdownButtonFormField<String>(
                    value: selectedLocation,
                    decoration:
                        const InputDecoration(
                      labelText: 'Select location',
                    ),
                    items: locations.map((location) {
                      final id =
                          valueString(location['id']);

                      return DropdownMenuItem<String>(
                        value: id,
                        child: Text(
                          valueString(
                            location['name'],
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) async {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        selectedLocation = value;
                      });

                      await loadSlots();
                    },
                  ),

                const SizedBox(height: 22),

                const Text(
                  'Date',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 10),

                Card(
                  child: ListTile(
