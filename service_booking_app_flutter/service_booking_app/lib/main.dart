import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://lybbdqwgfjekrqhhgdkf.supabase.co';
const supabasePublishableKey =
    'sb_publishable_2J95CnOji4M7eU2BInHEXQ_wHw1kkhb';

const appDeepLink = 'io.supabase.servicebooking://login-callback/';

final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabasePublishableKey,
  );

  runApp(
    const ProviderScope(
      child: BookingApp(),
    ),
  );
}

class BookingApp extends StatefulWidget {
  const BookingApp({super.key});

  @override
  State<BookingApp> createState() => _BookingAppState();
}

class _BookingAppState extends State<BookingApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(
      supabase.auth.onAuthStateChange,
    ),
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: '/service/:id',
        builder: (_, state) => ServiceScreen(
          serviceId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/bookings',
        builder: (_, __) => const BookingsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (_, __) => const AuthScreen(),
      ),
      GoRoute(
        path: '/provider',
        builder: (_, __) => const ProviderDashboard(),
      ),
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminDashboard(),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Service Booking',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: _router,
    );
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.listen((_) {
      notifyListeners();
    });
  }

  late final dynamic _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF101010),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFFA65C),
        brightness: Brightness.dark,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1A1A),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xFF141414),
      ),
    );
  }
}

class ServiceRepository {
  Future<List<Map<String, dynamic>>> services() async {
    final data = await supabase
        .from('services')
        .select()
        .eq('active', true)
        .order('created_at');

    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> service(String id) async {
    final data = await supabase
        .from('services')
        .select()
        .eq('id', id)
        .single();

    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> locations(
    String serviceId,
  ) async {
    final links = await supabase
        .from('service_locations')
        .select('location_id')
        .eq('service_id', serviceId);

    final ids = links
        .map<String>((e) => e['location_id'] as String)
        .toList();

    if (ids.isEmpty) {
      return [];
    }

    final data = await supabase
        .from('locations')
        .select()
        .inFilter('id', ids)
        .eq('active', true);

    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> slots({
    required String locationId,
    required String serviceId,
    required DateTime date,
  }) async {
    final d =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    final data = await supabase
        .from('availability_slots')
        .select()
        .eq('location_id', locationId)
        .eq('service_id', serviceId)
        .eq('slot_date', d)
        .eq('status', 'available')
        .order('start_time');

    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> createBooking(
    String slotId,
  ) async {
    final data = await supabase.rpc(
      'create_booking',
      params: {
        'p_slot_id': slotId,
      },
    );

    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> myBookings() async {
    final data = await supabase
        .from('bookings')
        .select(
          '*, services(name), locations(name), '
          'availability_slots(slot_date,start_time,end_time)',
        )
        .order(
          'created_at',
          ascending: false,
        );

    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> cancelBooking(
    String id,
    String reason,
  ) async {
    await supabase.rpc(
      'cancel_booking',
      params: {
        'p_booking_id': id,
        'p_reason': reason,
      },
    );
  }
}

final repo = ServiceRepository();

class Shell extends StatelessWidget {
  final Widget child;

  const Shell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: child,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index(context),
        onDestinationSelected: (index) {
          _go(context, index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  int _index(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;

    if (path == '/bookings') {
      return 1;
    }

    if (path == '/profile') {
      return 2;
    }

    return 0;
  }

  void _go(
    BuildContext context,
    int index,
  ) {
    if (index == 1) {
      context.go('/bookings');
    } else if (index == 2) {
      context.go('/profile');
    } else {
      context.go('/');
    }
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = repo.services();
  }

  @override
  Widget build(BuildContext context) {
    return Shell(
      child: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _future = repo.services();
          });
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            24,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Book your service',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Choose a service, location, date and time.',
                        style: TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    context.push('/profile');
                  },
                  icon: const Icon(
                    Icons.person_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              height: 150,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFB06D),
                    Color(0xFFEB7E3E),
                  ],
                ),
              ),
              child: const Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Simple. Fast. Confirmed.',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 8),
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
            const SizedBox(height: 26),
            Text(
              'Services',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return const ErrorCard(
                    message: 'Unable to load services.',
                  );
                }

                final data = snapshot.data ?? [];

                if (data.isEmpty) {
                  return const EmptyCard(
                    title: 'No services yet',
                    message:
                        'The administrator has not published any services.',
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  itemCount: data.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: .9,
                  ),
                  itemBuilder: (_, index) {
                    return ServiceCard(
                      service: data[index],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceCard extends StatelessWidget {
  final Map<String, dynamic> service;

  const ServiceCard({
    super.key,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        context.push(
          '/service/${service['id']}',
        );
      },
      borderRadius: BorderRadius.circular(22),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _RemoteImage(
                url: service['image_url'] as String?,
                icon: Icons.medical_services_outlined,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                14,
                12,
                14,
                14,
              ),
              child: Text(
                '${service['name'] ?? 'Service'}',
                maxLines: 2,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemoteImage extends StatelessWidget {
  final String? url;
  final IconData icon;

  const _RemoteImage({
    this.url,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        color: const Color(0xFF262626),
        child: Center(
          child: Icon(
            icon,
            size: 48,
            color: const Color(0xFFFFB06D),
          ),
        ),
      );
    }

    return Image.network(
      url!,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, __, ___) {
        return Container(
          color: const Color(0xFF262626),
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

class ServiceScreen extends StatefulWidget {
  final String serviceId;

  const ServiceScreen({
    super.key,
    required this.serviceId,
  });

  @override
  State<ServiceScreen> createState() =>
      _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  final _repo = repo;

  Map<String, dynamic>? service;
  List<Map<String, dynamic>> locations = [];

  String? selectedLocation;
  DateTime selectedDate = DateTime.now();

  List<Map<String, dynamic>> slots = [];
  String? selectedSlot;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
    });

    try {
      service = await _repo.service(
        widget.serviceId,
      );

      locations = await _repo.locations(
        widget.serviceId,
      );

      if (locations.isNotEmpty) {
        selectedLocation =
            locations.first['id'];

        await _loadSlots();
      }
    } catch (_) {
      // Error handled by the UI state.
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _loadSlots() async {
    if (selectedLocation == null) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      slots = await _repo.slots(
        locationId: selectedLocation!,
        serviceId: widget.serviceId,
        date: selectedDate,
      );

      selectedSlot = null;
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _book() async {
    if (selectedSlot == null) {
      return;
    }

    if (supabase.auth.currentUser == null) {
      if (mounted) {
        context.push('/auth');
      }
      return;
    }

    try {
      final booking = await _repo.createBooking(
        selectedSlot!,
      );

      if (!mounted) {
        return;
      }

      final confirmed =
          booking['status'] == 'confirmed';

      showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: Text(
              confirmed
                  ? 'Booking confirmed'
                  : 'Booking pending',
            ),
            content: Text(
              confirmed
                  ? 'Your appointment is confirmed.'
                  : 'Your booking is pending provider confirmation for up to 4 hours.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  context.go('/bookings');
                },
                child: const Text(
                  'View bookings',
                ),
              ),
            ],
          );
        },
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'This time slot is no longer available. Please choose another slot.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = service;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          s?['name'] ?? 'Service',
        ),
      ),
      body: loading && s == null
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (s != null)
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(26),
                    child: SizedBox(
                      height: 190,
                      child: _RemoteImage(
                        url: s['image_url'],
                        icon: Icons
                            .medical_services_outlined,
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                Text(
                  s?['name'] ?? 'Service',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  s?['description'] ??
                      'Choose a location and available time.',
                  style: const TextStyle(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ...locations.map(
                  (location) {
                    return RadioListTile<String>(
                      value: location['id'],
                      groupValue:
                          selectedLocation,
                      title: Text(
                        location['name'],
                      ),
                      subtitle: Text(
                        location['address'] ?? '',
                      ),
                      onChanged: (val
