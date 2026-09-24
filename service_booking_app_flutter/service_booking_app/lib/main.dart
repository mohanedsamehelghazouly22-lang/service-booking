import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://lybbdqwgfjekrqhhgdkf.supabase.co';
const supabasePublishableKey = 'sb_publishable_2J95CnOji4M7eU2BInHEXQ_wHw1kkhb';
const appDeepLink = 'io.supabase.servicebooking://login-callback/';

final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabasePublishableKey);
  runApp(const ProviderScope(child: BookingApp()));
}

class BookingApp extends StatefulWidget {
  const BookingApp({super.key});
  @override
  State<BookingApp> createState() => _BookingAppState();
}

class _BookingAppState extends State<BookingApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(supabase.auth.onAuthStateChange),
    routes: [
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/service/:id', builder: (_, s) => ServiceScreen(serviceId: s.pathParameters['id']!)),
      GoRoute(path: '/bookings', builder: (_, __) => const BookingsScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
      GoRoute(path: '/provider', builder: (_, __) => const ProviderDashboard()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminDashboard()),
    ],
  );

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Service Booking',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        routerConfig: _router,
      );
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final dynamic _sub;
  @override
  void dispose() { _sub.cancel(); super.dispose(); }
}

class AppTheme {
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101010),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFA65C), brightness: Brightness.dark),
        cardTheme: CardThemeData(
          color: const Color(0xFF1A1A1A),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
        navigationBarTheme: const NavigationBarThemeData(backgroundColor: Color(0xFF141414)),
      );
}

class ServiceRepository {
  Future<List<Map<String, dynamic>>> services() async =>
      List<Map<String, dynamic>>.from(await supabase.from('services').select().eq('active', true).order('created_at'));

  Future<Map<String, dynamic>> service(String id) async =>
      Map<String, dynamic>.from(await supabase.from('services').select().eq('id', id).single());

  Future<List<Map<String, dynamic>>> locations(String serviceId) async {
    final links = await supabase.from('service_locations').select('location_id').eq('service_id', serviceId);
    final ids = links.map<String>((e) => e['location_id'] as String).toList();
    if (ids.isEmpty) return [];
    return List<Map<String, dynamic>>.from(await supabase.from('locations').select().inFilter('id', ids).eq('active', true));
  }

  Future<List<Map<String, dynamic>>> slots({required String locationId, required String serviceId, required DateTime date}) async {
    final d = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return List<Map<String, dynamic>>.from(await supabase.from('availability_slots').select().eq('location_id', locationId).eq('service_id', serviceId).eq('slot_date', d).eq('status', 'available').order('start_time'));
  }

  Future<Map<String, dynamic>> createBooking(String slotId) async =>
      Map<String, dynamic>.from(await supabase.rpc('create_booking', params: {'p_slot_id': slotId}));

  Future<List<Map<String, dynamic>>> myBookings() async => List<Map<String, dynamic>>.from(await supabase.from('bookings').select('*, services(name), locations(name), availability_slots(slot_date,start_time,end_time)').order('created_at', ascending: false));

  Future<void> cancelBooking(String id, String reason) async => await supabase.rpc('cancel_booking', params: {'p_booking_id': id, 'p_reason': reason});
}

final repo = ServiceRepository();

class Shell extends StatelessWidget {
  final Widget child;
  const Shell({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: child),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index(context),
          onDestinationSelected: (i) => _go(context, i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Bookings'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      );
  int _index(BuildContext context) => GoRouterState.of(context).uri.path == '/bookings' ? 1 : GoRouterState.of(context).uri.path == '/profile' ? 2 : 0;
  void _go(BuildContext context, int i) => context.go(i == 1 ? '/bookings' : i == 2 ? '/profile' : '/');
}

class HomeScreen extends StatefulWidget { const HomeScreen({super.key}); @override State<HomeScreen> createState() => _HomeScreenState(); }
class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  @override void initState() { super.initState(); _future = repo.services(); }
  @override Widget build(BuildContext context) => Shell(child: RefreshIndicator(onRefresh: () async => setState(() => _future = repo.services()), child: ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 24), children: [
    Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Book your service', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text('Choose a service, location, date and time.', style: TextStyle(color: Colors.white.withOpacity(.65)))])),
      IconButton(onPressed: () => context.push('/profile'), icon: const Icon(Icons.person_outline))
    ]),
    const SizedBox(height: 22),
    Container(height: 150, padding: const EdgeInsets.all(22), decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: const LinearGradient(colors: [Color(0xFFFFB06D), Color(0xFFEB7E3E)])), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Simple. Fast. Confirmed.', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: Colors.black)), SizedBox(height: 8), Text('Real-time availability and secure bookings.', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))])),
    const SizedBox(height: 26),
    Text('Services', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 12),
    FutureBuilder(future: _future, builder: (context, snap) { if (snap.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())); if (snap.hasError) return ErrorCard(message: 'Unable to load services.'); final data = snap.data ?? []; if (data.isEmpty) return const EmptyCard(title: 'No services yet', message: 'The administrator has not published any services.'); return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: data.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .9), itemBuilder: (_, i) => ServiceCard(service: data[i])); })
  ])));
}

class ServiceCard extends StatelessWidget { final Map<String,dynamic> service; const ServiceCard({super.key, required this.service}); @override Widget build(BuildContext context) => InkWell(onTap: () => context.push('/service/${service['id']}'), borderRadius: BorderRadius.circular(22), child: Card(clipBehavior: Clip.antiAlias, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _RemoteImage(url: service['image_url'] as String?, icon: Icons.medical_services_outlined)), Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 14), child: Text('${service['name'] ?? 'Service'}', maxLines: 2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)))])); }

class _RemoteImage extends StatelessWidget { final String? url; final IconData icon; const _RemoteImage({this.url, required this.icon}); @override Widget build(BuildContext context) => url == null || url!.isEmpty ? Container(color: const Color(0xFF262626), child: Center(child: Icon(icon, size: 48, color: const Color(0xFFFFB06D)))) : Image.network(url!, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => Container(color: const Color(0xFF262626), child: Center(child: Icon(icon, size: 48)))); }

class ServiceScreen extends StatefulWidget { final String serviceId; const ServiceScreen({super.key, required this.serviceId}); @override State<ServiceScreen> createState()=>_ServiceScreenState(); }
class _ServiceScreenState extends State<ServiceScreen> {
  final _repo=repo; Map<String,dynamic>? service; List<Map<String,dynamic>> locations=[]; String? selectedLocation; DateTime selectedDate=DateTime.now(); List<Map<String,dynamic>> slots=[]; String? selectedSlot; bool loading=true;
  @override void initState(){super.initState(); _load();}
  Future<void> _load() async { setState(()=>loading=true); try { service=await _repo.service(widget.serviceId); locations=await _repo.locations(widget.serviceId); if(locations.isNotEmpty){selectedLocation=locations.first['id']; await _loadSlots();}} catch(e){} finally{if(mounted)setState(()=>loading=false);} }
  Future<void> _loadSlots() async { if(selectedLocation==null)return; setState(()=>loading=true); try{slots=await _repo.slots(locationId:selectedLocation!,serviceId:widget.serviceId,date:selectedDate);selectedSlot=null;}finally{if(mounted)setState(()=>loading=false);}}
  Future<void> _book() async { if(selectedSlot==null)return; if(supabase.auth.currentUser==null){ if(mounted) context.push('/auth'); return; } try{final b=await _repo.createBooking(selectedSlot!); if(mounted) { showDialog(context:context,builder:(_)=>AlertDialog(title:Text(b['status']=='confirmed'?'Booking confirmed':'Booking pending'),content:Text(b['status']=='confirmed'?'Your appointment is confirmed.':'Your booking is pending provider confirmation for up to 4 hours.'),actions:[TextButton(onPressed:()=>context.go('/bookings'),child:const Text('View bookings'))])); }}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('This time slot is no longer available. Please choose another slot.')));}}
  @override Widget build(BuildContext context){final s=service;return Scaffold(appBar:AppBar(title:Text(s?['name']??'Service')),body:loading&&s==null?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(20),children:[if(s!=null)ClipRRect(borderRadius:BorderRadius.circular(26),child:SizedBox(height:190,child:_RemoteImage(url:s['image_url'],icon:Icons.medical_services_outlined))),const SizedBox(height:18),Text(s?['name']??'Service',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),const SizedBox(height:8),Text(s?['description']??'Choose a location and available time.',style:TextStyle(color:Colors.white.withOpacity(.68))),const SizedBox(height:24),const Text('Location',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),const SizedBox(height:10),...locations.map((l)=>RadioListTile<String>(value:l['id'],groupValue:selectedLocation,title:Text(l['name']),subtitle:Text(l['address']??''),onChanged:(v){selectedLocation=v;_loadSlots();setState((){});})),const SizedBox(height:12),ListTile(contentPadding:EdgeInsets.zero,title:const Text('Date',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),trailing:FilledButton.tonal(onPressed:()async{final d=await showDatePicker(context:context,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:90)),initialDate:selectedDate);if(d!=null){selectedDate=d;await _loadSlots();}},child:const Text('Choose')),),const SizedBox(height:12),const Text('Available times',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),const SizedBox(height:10),if(slots.isEmpty)const EmptyCard(title:'No available slots',message:'Try another date or location.') else Wrap(spacing:10,runSpacing:10,children:slots.map((slot){final selected=selectedSlot==slot['id'];return ChoiceChip(label:Text(_time(slot['start_time'])),selected:selected,onSelected:(_){setState(()=>selectedSlot=slot['id']);});}).toList()),const SizedBox(height:28),FilledButton(onPressed:selectedSlot==null?null:_book,child:const Padding(padding:EdgeInsets.all(4),child:Text('Continue to confirmation',style:TextStyle(fontWeight:FontWeight.w800))))]));}
}

String _time(dynamic t){final parts=t.toString().split(':');if(parts.length<2)return t.toString();final h=int.parse(parts[0]);final m=parts[1];final ap=h>=12?'PM':'AM';final hh=h%12==0?12:h%12;return '$hh:$m $ap';}

class AuthScreen extends StatefulWidget{const AuthScreen({super.key});@override State<AuthScreen> createState()=>_AuthScreenState();}
class _AuthScreenState extends State<AuthScreen>{final phone=TextEditingController();final otp=TextEditingController();bool sent=false;bool busy=false;Future<void> _google()async{try{await supabase.auth.signInWithOAuth(OAuthProvider.google,redirectTo:appDeepLink);}catch(e){_error('Google sign-in could not start.');}}Future<void> _send()async{setState(()=>busy=true);try{await supabase.auth.signInWithOtp(phone:phone.text.trim());setState(()=>sent=true);}catch(e){_error('Could not send the verification code.')}finally{setState(()=>busy=false);}}Future<void> _verify()async{setState(()=>busy=true);try{await supabase.auth.verifyOTP(type:OtpType.sms,phone:phone.text.trim(),token:otp.text.trim());if(mounted)context.pop();}catch(e){_error('Invalid or expired code.')}finally{setState(()=>busy=false);}}void _error(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(),body:ListView(padding:const EdgeInsets.all(24),children:[const SizedBox(height:30),const Text('Welcome back',style:TextStyle(fontSize:34,fontWeight:FontWeight.w900)),const SizedBox(height:8),Text('Sign in to complete your booking.',style:TextStyle(color:Colors.white70)),const SizedBox(height:30),FilledButton.icon(onPressed:busy?null:_google,icon:const Icon(Icons.login),label:const Text('Continue with Google')),const SizedBox(height:22),const Divider(),const SizedBox(height:22),TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Phone number',prefixText:'+')),if(sent)...[const SizedBox(height:14),TextField(controller:otp,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'6-digit verification code'))],const SizedBox(height:18),FilledButton(onPressed:busy?null:(sent?_verify:_send),child:Text(sent?'Verify code':'Send code')),const SizedBox(height:18),const Text('By continuing, you agree to the platform Terms & Conditions.',textAlign:TextAlign.center,style:TextStyle(color:Colors.white54))]));}

class BookingsScreen extends StatefulWidget{const BookingsScreen({super.key});@override State<BookingsScreen> createState()=>_BookingsScreenState();}
class _BookingsScreenState extends State<BookingsScreen>{late Future<List<Map<String,dynamic>>> future;@override void initState(){super.initState();future=repo.myBookings();}@override Widget build(BuildContext context){if(supabase.auth.currentUser==null)return Shell(child:const Center(child:Padding(padding:EdgeInsets.all(24),child:Text('Sign in to view your bookings.'))));return Shell(child:RefreshIndicator(onRefresh:()async=>setState(()=>future=repo.myBookings()),child:ListView(padding:const EdgeInsets.all(20),children:[Text('My bookings',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w900)),const SizedBox(height:18),FutureBuilder(future:future,builder:(c,s){if(s.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());if(s.hasError)return const ErrorCard(message:'Could not load bookings.');final list=s.data??[];if(list.isEmpty)return const EmptyCard(title:'No bookings yet',message:'Your confirmed and pending appointments will appear here.');return Column(children:list.map((b)=>BookingCard(booking:b,onRefresh:()=>setState(()=>future=repo.myBookings()))).toList());})]));}}

class BookingCard extends StatelessWidget{final Map<String,dynamic> booking;final VoidCallback onRefresh;const BookingCard({super.key,required this.booking,required this.onRefresh});@override Widget build(BuildContext context){final slot=booking['availability_slots'] as Map?;final service=booking['services'] as Map?;final loc=booking['locations'] as Map?;final status=(booking['status']??'').toString();final appointment=slot==null?'': '${slot['slot_date']} • ${_time(slot['start_time'])}';return Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(service?['name']??'Service',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17))),StatusPill(status:status)]),const SizedBox(height:8),Text(loc?['name']??'Location',style:const TextStyle(color:Colors.white70)),Text(appointment,style:const TextStyle(color:Colors.white70)),if(status=='pending')... [const SizedBox(height:10),Text('Awaiting provider confirmation (up to 4 hours).',style:TextStyle(color:Colors.orange.shade200))],if(status=='confirmed')... [const SizedBox(height:10),Text('Confirmed',style:TextStyle(color:Colors.greenAccent))],if(status=='pending'||status=='confirmed')const SizedBox(height:12),if(status=='pending'||status=='confirmed')OutlinedButton(onPressed:()async{try{await repo.cancelBooking(booking['id'], 'Customer cancellation');onRefresh();}catch(e){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Cancellation is only allowed more than 3 hours before the appointment.')));}},child:const Text('Cancel booking'))])));}}

class StatusPill extends StatelessWidget{final String status;const StatusPill({super.key,required this.status});@override Widget build(BuildContext context){return Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:status=='confirmed'?Colors.green.withOpacity(.18):status=='pending'?Colors.orange.withOpacity(.18):Colors.white.withOpacity(.08),borderRadius:BorderRadius.circular(20)),child:Text(status.toUpperCase(),style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800)));}}

class ProfileScreen extends StatefulWidget{const ProfileScreen({super.key});@override State<ProfileScreen> createState()=>_ProfileScreenState();}
class _ProfileScreenState extends State<ProfileScreen>{Map<String,dynamic>? p;final name=TextEditingController();final city=TextEditingController();final gov=TextEditingController();@override void initState(){super.initState();_load();}Future<void>_load()async{final u=supabase.auth.currentUser;if(u==null)return;try{p=Map<String,dynamic>.from(await supabase.from('profiles').select().eq('id',u.id).single());name.text=p?['full_name']??'';city.text=p?['city']??'';gov.text=p?['governorate']??'';setState((){});}catch(_){}}Future<void>_save()async{final u=supabase.auth.currentUser;if(u==null)return;await supabase.from('profiles').update({'full_name':name.text.trim(),'city':city.text.trim(),'governorate':gov.text.trim(),'email':u.email}).eq('id',u.id);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Profile updated.')));}Future<void>_signOut()async{await supabase.auth.signOut();if(mounted)context.go('/');}@override Widget build(BuildContext context)=>Shell(child:ListView(padding:const EdgeInsets.all(20),children:[Text('Profile',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w900)),const SizedBox(height:22),if(supabase.auth.currentUser==null) ...[const Text('You are browsing as a guest.'),const SizedBox(height:16),FilledButton(onPressed:()=>context.push('/auth'),child:const Text('Sign in'))] else ...[Text(supabase.auth.currentUser?.email??supabase.auth.currentUser?.phone??'',style:const TextStyle(color:Colors.white70)),const SizedBox(height:18),TextField(controller:name,decoration:const InputDecoration(labelText:'Full name')),const SizedBox(height:12),TextField(controller:gov,decoration:const InputDecoration(labelText:'Governorate')),const SizedBox(height:12),TextField(controller:city,decoration:const InputDecoration(labelText:'City')),const SizedBox(height:18),FilledButton(onPressed:_save,child:const Text('Save profile')),const SizedBox(height:10),OutlinedButton(onPressed:_signOut,child:const Text('Sign out')),if(p?['role']=='provider')... [const SizedBox(height:18),FilledButton.tonalIcon(onPressed:()=>context.push('/provider'),icon:const Icon(Icons.dashboard_outlined),label:const Text('Provider dashboard'))],if(p?['role']=='super_user')... [const SizedBox(height:10),FilledButton.tonalIcon(onPressed:()=>context.push('/admin'),icon:const Icon(Icons.admin_panel_settings_outlined),label:const Text('Admin dashboard'))]]));}}

class ProviderDashboard extends StatefulWidget{const ProviderDashboard({super.key});@override State<ProviderDashboard> createState()=>_ProviderDashboardState();}
class _ProviderDashboardState extends State<ProviderDashboard>{DateTime date=DateTime.now();late Future<List<Map<String,dynamic>>> future;@override void initState(){super.initState();future=_load();}Future<List<Map<String,dynamic>>>_load()async{final d='${date.year.toString().padLeft(4,'0')}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';return List<Map<String,dynamic>>.from(await supabase.from('bookings').select('*, profiles!bookings_customer_id_fkey(full_name,phone), services(name), locations(name), availability_slots(slot_date,start_time)').eq('provider_id',supabase.auth.currentUser!.id).eq('availability_slots.slot_date',d).order('created_at'));}Future<void>_confirm(String id)async{try{await supabase.rpc('confirm_booking',params:{'p_booking_id':id});setState(()=>future=_load());}catch(e){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('This booking has expired or is no longer pending.')));}}Future<void>_cancel(String id)async{final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('Cancel booking?'),content:const Text('Please communicate with the customer before cancelling. You accept full responsibility for this cancellation under the Terms & Conditions.'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Keep')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('I accept responsibility'))]));if(ok==true){try{await repo.cancelBooking(id,'Provider cancellation after customer contact');setState(()=>future=_load());}catch(_){}}}@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Provider dashboard')),body:ListView(padding:const EdgeInsets.all(20),children:[Text('Today\'s operations',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),const SizedBox(height:12),Card(child:Padding(padding:const EdgeInsets.all(20),child:Row(children:[const Icon(Icons.event_available,size:32,color:Color(0xFFFFB06D)),const SizedBox(width:14),FutureBuilder(future:future,builder:(_,s)=>Text('${s.data?.length??0}',style:const TextStyle(fontSize:34,fontWeight:FontWeight.w900)))]))),const SizedBox(height:14),ListTile(title:const Text('Date'),subtitle:Text('${date.day}/${date.month}/${date.year}'),trailing:IconButton(onPressed:()async{final d=await showDatePicker(context:context,firstDate:DateTime.now().subtract(const Duration(days:365)),lastDate:DateTime.now().add(const Duration(days:365)),initialDate:date);if(d!=null){setState(()=>date=d);future=_load();}},icon:const Icon(Icons.calendar_month))),const SizedBox(height:10),FutureBuilder(future:future,builder:(_,s){if(s.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());final list=s.data??[];if(list.isEmpty)return const EmptyCard(title:'No bookings',message:'There are no operations for this date.');return Column(children:list.map((b)=>Card(child:ListTile(title:Text((b['profiles'] as Map?)?['full_name']??'Customer'),subtitle:Text('${(b['services'] as Map?)?['name']??'Service'} • ${(b['locations'] as Map?)?['name']??''}\n${_time(((b['availability_slots'] as Map?)?['start_time']))}'),isThreeLine:true,trailing:b['status']=='pending'?Column(mainAxisSize:MainAxisSize.min,children:[TextButton(onPressed:()=>_confirm(b['id']),child:const Text('Confirm')),TextButton(onPressed:()=>_cancel(b['id']),child:const Text('Cancel'))]):StatusPill(status:b['status'])))).toList());})]));}}

class AdminDashboard extends StatefulWidget{const AdminDashboard({super.key});@override State<AdminDashboard> createState()=>_AdminDashboardState();}
class _AdminDashboardState extends State<AdminDashboard>{late Future<List<Map<String,dynamic>>> services;final name=TextEditingController();final desc=TextEditingController();@override void initState(){super.initState();services=_services();}Future<List<Map<String,dynamic>>> _services() async => List<Map<String,dynamic>>.from(await supabase.from('services').select().order('created_at',ascending:false));Future<void>_add()async{if(name.text.trim().isEmpty)return;await supabase.from('services').insert({'name':name.text.trim(),'description':desc.text.trim(),'active':true});name.clear();desc.clear();setState(()=>services=_services());}@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Super User dashboard')),body:ListView(padding:const EdgeInsets.all(20),children:[Text('Services',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),const SizedBox(height:12),TextField(controller:name,decoration:const InputDecoration(labelText:'Service name')),const SizedBox(height:10),TextField(controller:desc,decoration:const InputDecoration(labelText:'Description')),const SizedBox(height:10),FilledButton(onPressed:_add,child:const Text('Add service')),const SizedBox(height:22),FutureBuilder(future:services,builder:(_,s){if(!s.hasData)return const CircularProgressIndicator();return Column(children:s.data!.map((x)=>ListTile(title:Text(x['name']),subtitle:Text(x['active']==true?'Active':'Disabled'),trailing:Switch(value:x['active']==true,onChanged:(v)async{await supabase.from('services').update({'active':v}).eq('id',x['id']);setState(()=>services=_services());}))).toList());})]));}

class EmptyCard extends StatelessWidget{final String title,message;const EmptyCard({super.key,required this.title,required this.message});@override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(22),child:Column(children:[Icon(Icons.inbox_outlined,size:42,color:Colors.white38),const SizedBox(height:10),Text(title,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:17)),const SizedBox(height:5),Text(message,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white60))])));}
class ErrorCard extends StatelessWidget{final String message;const ErrorCard({super.key,required this.message});@override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(20),child:Text(message,style:const TextStyle(color:Colors.redAccent))));}
