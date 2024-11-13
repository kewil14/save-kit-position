import 'dart:async';
import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;



import 'package:battery_plus/battery_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Map signal'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Timer? _timer;
  String _location = "Fetching location...";
  int _batteriePercent  = 100;
  String time = '';
  String equipmentId = '';
  String _id = '';
  final String userId = "USER_ID"; // Remplace par l'ID réel de l'utilisateur
  List<dynamic> _equipments = [];
  String? _customerId;

  final TextEditingController _subscriptionIdController = TextEditingController();
  Map<String, dynamic>? _subscriptionData;



  // Copier le code
  @override
  void initState() {
    super.initState();
    // _retrieveDeviceId(); // recuperer l'IMEI ou un id d un equipement
    // Demande la permission de localisation

  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Appel de la fonction pour récupérer l'ID après l'initialisation du contexte
    _retrieveDeviceId();
  }


  // Fonction pour récupérer l'IMEI ou un identifiant de l'appareil
  Future<void> _retrieveDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        // Pour Android, l'accès à l'IMEI est limité ; utilisez l'identifiant de l'appareil à la place
        setState(() {
          equipmentId = androidInfo.id ?? androidInfo.model ?? androidInfo.device ?? 'Unknown ID'; // Utilise l'ID Android
          print('equipmentId: $equipmentId');

        });
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        setState(() {
          equipmentId = iosInfo.identifierForVendor ?? ''; // Utilise l'identifiant iOS
        });
      }
    } catch (e) {
      print("Erreur lors de la récupération de l'IMEI ou de l'identifiant d'appareil : $e");
    }
  }

// Fonction pour démarrer le suivi de la position toutes les 5 secondes
  void _startLocationTracking() async {
    LocationPermission permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      setState(() {
        _location = "Location permission denied";
      });
      return;
    }

    // Configure le timer pour récupérer la position toutes les 5 secondes
    _timer = Timer.periodic(Duration(seconds: 30), (Timer timer) async {
      // Appel de la fonction pour obtenir la position actuelle
      Position position = await _getCurrentLocation();

      // Si la position est obtenue, mettre à jour l'UI et envoyer au backend
      if (position != null) {
        setState(() {
          _location = "Lat: ${position.latitude}, Lon: ${position.longitude}";


        });
        _sendLocationToServer(position.latitude, position.longitude);
      }
    });
  }

// Fonction pour obtenir la position actuelle de l'utilisateur
  Future<Position> _getCurrentLocation() async {
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

// Fonction pour envoyer la position au backend
  Future<void> _sendLocationToServer(double latitude, double longitude) async {

    final battery = Battery(); //create an instance pour acceder au niveau de la batterie

    try {
      // recupere le niveau de % de la batterie
      int batteryLevel = await battery.batteryLevel;
      _batteriePercent = batteryLevel;
      print('_id: $_id');
      time = DateTime.now().toIso8601String().split('.').first + 'Z';

      var response = await http.post(
        Uri.parse('http://95.111.225.198:5001/api/equipments/${_id}/positions'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'timestamp': time,
          'batterieLifeAtTime': batteryLevel, // % of the battery
        }),
      );

      if (response.statusCode == 200) {
        print("Location sent successfully");
        print(equipmentId);
      } else {
        print("Failed to send location: ${response.statusCode}");
      }
    } catch (err) {
      print("Error sending location: $err");
    }
  }


  // Fonction pour récupérer les données de la souscription
  Future<void> _fetchSubscriptionData() async {
    String subscriptionId = _subscriptionIdController.text.trim();
    if (subscriptionId.isEmpty) return;

    try {
      final response = await http.get(Uri.parse('http://95.111.225.198:5003/api/subscriptions/getById/$subscriptionId'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _subscriptionData = data['data'];

          _customerId = data['data']['customerId'];
        });
        print("Subscription data fetched successfully");


      //   une fois le customerId recupere on lance la requete des equipements
        _fetchEquipments();
      } else {
        print("Failed to fetch subscription data: ${response.statusCode}");
      }
    } catch (err) {
      print("Error fetching subscription data: $err");
    }
  }

  // Fonction pour récupérer la liste des équipements avec customerId
  Future<void> _fetchEquipments() async {
    if (_customerId == null) return;

    try {
      final response = await http.get(Uri.parse('http://95.111.225.198:5001/api/getAllEquipments?userId=$_customerId'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _equipments = data['data'];
        });
        print("Equipments fetched successfully");
      } else {
        print("Failed to fetch equipments: ${response.statusCode}");
      }
    } catch (err) {
      print("Error fetching equipments: $err");
    }
  }

  // Fonction pour activer un équipement spécifique
  Future<void> _activateEquipment(String equipmentId) async {
    try {

      _startLocationTracking();
      _id = equipmentId;

      final response = await http.post(
        Uri.parse('http://95.111.225.198:5001/api/activateEquip'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'equipmentId': equipmentId,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Successful activation of an equipment")));
      } else {
        print("Failed to activate equipment: ${response.statusCode}");
      }
    } catch (err) {
      print("Error activating equipment: $err");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Location Tracker"),
      ),
      body: Column(
        // child:


        children: [
          // parti subscription
          TextField(
            controller: _subscriptionIdController,
            decoration: InputDecoration(
              labelText: "Enter Subscription ID",
            ),
          ),
          ElevatedButton(
            onPressed: _fetchSubscriptionData,
            child: Text("Fetch Subscription Data"),
          ),


          if (_subscriptionData != null) ...[
            Text("Subscription ID: ${_subscriptionData!['subscriptionId']}"),
            Text("Customer ID: $_customerId"),
            Text("Service Option ID: ${_subscriptionData!['serviceOptionId']}"),
            Text("State: ${_subscriptionData!['state']}"),
            Text("Start Date: ${_subscriptionData!['startDate']}"),
            Text("End Date: ${_subscriptionData!['endDate']}"),
          ],
          if (_equipments.isNotEmpty) ...[
            Text("Equipments:"),
            ..._equipments.map((equipment) => Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.blue, // couleur du contour
                    width: 2.0, // largeur du contour
                  ),
                  borderRadius: BorderRadius.circular(8.0), // coins arrondis
                ),
                margin: EdgeInsets.symmetric(vertical: 4.0), // marge entre les items
                child: ListTile(
              title: Text(equipment['labelObjectTrack']),
              subtitle: Text("Battery Life: ${equipment['batterieLife']}%"),
              onTap: () => _activateEquipment(equipment['_id']),
            ))
            ),
          ],




          Text(
            equipmentId,
            style: TextStyle(fontSize: 22),
          ),
          Text(
            _id,
            style: TextStyle(fontSize: 22),
          ),
          // Text(
          //   time,
          //   style: TextStyle(fontSize: 22),
          // ),
          // Text(
          //   _batteriePercent.toString() ,
          //   style: TextStyle(fontSize: 18),
          // ),
          // Text(
          // _location,
          // style: TextStyle(fontSize: 18),
          // ),
        ],
      ),
    );
  }
}


