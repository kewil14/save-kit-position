import 'dart:async';
import 'dart:convert';

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
  String equipmentId = '672c8146b794168403980ebc';
  final String userId = "USER_ID"; // Remplace par l'ID réel de l'utilisateur



  // Copier le code
  @override
  void initState() {
    super.initState();

    // Demande la permission de localisation
    _startLocationTracking();
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
      time = DateTime.now().toIso8601String().split('.').first + 'Z';

      var response = await http.post(
        Uri.parse('http://95.111.225.198:5001/api/equipments/${equipmentId}/positions'),
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
      } else {
        print("Failed to send location: ${response.statusCode}");
      }
    } catch (err) {
      print("Error sending location: $err");
    }
  }





  // @override
  // Widget build(BuildContext context) {
  //   // This method is rerun every time setState is called, for instance as done
  //   // by the _incrementCounter method above.
  //   //
  //   // The Flutter framework has been optimized to make rerunning build methods
  //   // fast, so that you can just rebuild anything that needs updating rather
  //   // than having to individually change instances of widgets.
  //   return Scaffold(
  //     appBar: AppBar(
  //       // TRY THIS: Try changing the color here to a specific color (to
  //       // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
  //       // change color while the other colors stay the same.
  //       backgroundColor: Theme.of(context).colorScheme.inversePrimary,
  //       // Here we take the value from the MyHomePage object that was created by
  //       // the App.build method, and use it to set our appbar title.
  //       title: Text(widget.title),
  //     ),
  //     body: Center(
  //       // Center is a layout widget. It takes a single child and positions it
  //       // in the middle of the parent.
  //       child: Column(
  //
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         children: <Widget>[
  //           const Text(
  //             'Suivi GPS en temps réel',
  //           ),
  //           Text(
  //             '$_counter',
  //             style: Theme.of(context).textTheme.headlineMedium,
  //           ),
  //
  //           Text(
  //             '$_counter',
  //             style: Theme.of(context).textTheme.headlineMedium,
  //           ),
  //         ],
  //       ),
  //     ),
  //     floatingActionButton: FloatingActionButton(
  //       onPressed: _incrementCounter,
  //       tooltip: 'Increment',
  //       child: const Icon(Icons.add),
  //     ), // This trailing comma makes auto-formatting nicer for build methods.
  //   );
  // }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Location Tracker"),
      ),
      body: Column(
        // child:


        children: [
          Text(
            equipmentId,
            style: TextStyle(fontSize: 22),
          ),
          Text(
            time,
            style: TextStyle(fontSize: 22),
          ),
          Text(
            _batteriePercent.toString() ,
            style: TextStyle(fontSize: 18),
          ),
          Text(
          _location,
          style: TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }
}


