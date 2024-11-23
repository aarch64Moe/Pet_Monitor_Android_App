import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pet Monitoring System',
      theme: ThemeData(
        fontFamily: 'Poppins',
        primaryColor: const Color(0xFF171F24),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E282C),
        colorScheme: ColorScheme.dark().copyWith(
          primary: const Color(0xFF171F24),
          secondary: const Color(0xFF4BB2F9),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
      ),
      home: const HomePage(),
    );
  }
}



///////////////////////Dynamic Ip ////////////////////////////


/////////////////////////////
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  double temperature = 0.0;
  double humidity = 0.0;
  double heartRate = 0.0;
  String movement = 'Unknown';
  String classification = 'None';
  bool isRunning = false;
  bool isConnected = false;
  String ipAddress = '192.168.1.209'; // Initial IP address

  Timer? _timer;

  final List<Map<String, dynamic>> dataQueue = [];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) => fetchData());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  ////////////////// Update IP Address page  ///////////////////////////////////////
  void updateIpAddress(String newIp) {
    setState(() {
      ipAddress = newIp;
    });
  }

  Future<void> _showIpDialog(BuildContext context) async {
    String newIp = '';
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter IP Address'),
          content: TextField(
            onChanged: (value) {
              newIp = value;
            },
            decoration: InputDecoration(hintText: "Enter new IP address"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('OK'),
              onPressed: () {
                if (newIp.isNotEmpty) {
                  updateIpAddress(newIp);
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  ////////////////// Monitor Update and save report section ///////////////////////////////////////
  int reportCounter = 0; // Counter for total data points processed

  Future<void> fetchData() async {
    try {
      final response = await http.get(Uri.parse('http://$ipAddress:5000/status'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (mounted) {
          setState(() {
            temperature = data['temperature'] ?? 0.0;
            humidity = data['humidity'] ?? 0.0;
            heartRate = data['heart_rate'] ?? 0.0;
            movement = data['movement'] ?? 'Unknown';
            classification = data['classification'] ?? 'None';
            isRunning = data['is_running'] ?? false;
            isConnected = true;

            // Add all data points to the queue
            final newEntry = {
              'temperature': temperature,
              'humidity': humidity,
              'heartRate': heartRate,
              'movement': movement,
              'classification': classification,
              'isRunning': isRunning,
              'timestamp': DateTime.now().toIso8601String(),
            };

            dataQueue.add(newEntry);

            // Maintain queue size
            if (dataQueue.length > 1000) {
              dataQueue.removeAt(0);
            }

            // Increment report counter
            reportCounter++;

            // Generate report every 1000 data points
            if (reportCounter >= 1000) {
              final report = calculateReport();
              saveLogToServer(report);
              reportCounter = 0; // Reset counter after saving
            }
          });
        }
      } else {
        setDisconnected();
      }
    } catch (e) {
      setDisconnected();
      print("Error fetching data: $e");
    }
  }


  void setDisconnected() {
    if (mounted) {
      setState(() {
        isConnected = false;
        temperature = 0.0;
        humidity = 0.0;
        heartRate = 0.0;
        movement = 'Disconnected';
        classification = 'N/A';
        isRunning = false;
      });
    }
  }

  ////////////////// Monitor Logic report section ///////////////////////////////////////
  Map<String, dynamic> calculateReport() {
    double totalTemperature = 0.0;
    double totalHumidity = 0.0;
    double totalHeartRate = 0.0;
    int validHeartRateCount = 0;
    Map<String, int> movementCount = {};
    Map<String, int> classificationCount = {};
    int isRunningTrueCount = 0;

    //for (var entry in dataQueue) {
     // movementCount[entry['movement']] = (movementCount[entry['movement']] ?? 0) + 1;
     // classificationCount[entry['classification']] = (classificationCount[entry['classification']] ?? 0) + 1;
    //}
    for (var entry in dataQueue) {
      // Ensure values are not null
      double temperature = entry['temperature'] ?? 0.0;
      double humidity = entry['humidity'] ?? 0.0;
      double heartRate = entry['heartRate'] ?? 0.0;
      String movement = entry['movement'] ?? 'Unknown';
      String classification = entry['classification'] ?? 'None';
      bool isRunning = entry['isRunning'] ?? false;

      totalTemperature += temperature;
      totalHumidity += humidity;

      if (heartRate > 0) {
        totalHeartRate += heartRate;
        validHeartRateCount++;
      }

      movementCount[movement] = (movementCount[movement] ?? 0) + 1;
      classificationCount[classification] = (classificationCount[classification] ?? 0) + 1;

      if (isRunning) {
        isRunningTrueCount++;
      }
    }

    int dataPoints = dataQueue.length;

    // Safeguard against division by zero
    double avgTemperature = dataPoints > 0 ? totalTemperature / dataPoints : 0.0;
    double avgHumidity = dataPoints > 0 ? totalHumidity / dataPoints : 0.0;
    double avgHeartRate = validHeartRateCount > 0 ? totalHeartRate / validHeartRateCount : 0.0;
    double isRunningPercentage = dataPoints > 0 ? (isRunningTrueCount / dataPoints) * 100 : 0.0;

    String mostCommonMovement = movementCount.isNotEmpty
        ? movementCount.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : 'Unknown';
    String mostCommonClassification = classificationCount.isNotEmpty
        ? classificationCount.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : 'None';

    return {
      'averageTemperature': avgTemperature.toStringAsFixed(2),
      'averageHumidity': avgHumidity.toStringAsFixed(2),
      'averageHeartRate': avgHeartRate.toStringAsFixed(2),
      'mostCommonMovement': mostCommonMovement,
      'mostCommonClassification': mostCommonClassification,
      'isRunningPercentage': isRunningPercentage.toStringAsFixed(2),
      'movementCount': movementCount[mostCommonMovement] ?? 0,
      'classificationCount': classificationCount[mostCommonClassification] ?? 0,
      'dataPoints': dataPoints,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<void> saveLogToServer(Map<String, dynamic> report) async {
    final url = "http://$ipAddress:5000/save_report"; // Flask endpoint
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(report),
      );
      if (response.statusCode == 200) {
        print("Log saved successfully");
        dataQueue.clear(); // Clear queue after successful saving
      } else {
        print("Failed to save log: ${response.statusCode}");
      }
    } catch (e) {
      print("Error saving log: $e");
    }
  }



  ////////////////// Main Page layout ///////////////////////////////////////

  //// pops up menu ////
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pet Monitoring System', style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'Reboot') {
                rebootDevice();
              }
              else if (value == 'Change IP') {
                _showIpDialog(context);
              }
            },

            itemBuilder: (BuildContext context) {
              return {'Reboot', 'Change IP'}.map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
            icon: const Icon(Icons.more_vert, color: Colors.white),

          ),
        ],
      ),

      ////////////////// main page body ///////////////////////////////////////

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isConnected ? 'Device Connected' : 'Device Disconnected',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isConnected ? Colors.green : Colors.red,
              ),
            ),


            ////////////////// Sensors Row  ///////////////////////////////////////
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildInfoCard('Temperature', '${temperature.toStringAsFixed(1)}°C', Icons.thermostat, Colors.orange),
                _buildInfoCard('Humidity', '${humidity.toStringAsFixed(1)}%', Icons.water_drop, Colors.blue),
                _buildInfoCard('Heart Rate', '$heartRate BPM', Icons.favorite, Colors.red),
              ],
            ),

            ////////////////// Live Status  ///////////////////////////////////////
            Column(
              children: [
                RotatingIcon(isRunning: isRunning),
                const SizedBox(height: 10),
                Text(
                  isRunning ? 'AI Live Status: Running' : 'AI Live Status: Not Running',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isRunning ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),

            ////////////////// Movement/Classification Row ////////////////////////
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildInfoCard('Movement', movement, Icons.directions_walk, Colors.indigo),
                _buildInfoCard('Classification', classification, Icons.category, Theme.of(context).colorScheme.secondary),
              ],
            ),

            ////////////////// Options  Row  ///////////////////////////////////////
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                //// Camera  widget /////
                _buildActionButton(
                  'Camera',
                  Icons.camera_alt,
                  onPressed: () {
                    print("Camera button pressed");
                    //String streamUrl = "http://$ipAddress:5000/camera_stream";
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CameraStreamPage(ipAddress: ipAddress),
                      ),
                    );
                  },
                ),
                //// Track GPS widget ////
                _buildActionButton(
                  'Track GPS',
                  Icons.gps_fixed,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GpsMapPage(ipAddress: ipAddress),
                      ),
                    );
                  },
                ),

                //// Monitor widget ////
                ElevatedButton.icon(
                  onPressed: () {
                    final report = calculateReport();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MonitorReportScreen(report: report),
                      ),
                    );
                  },
                  icon: const Icon(Icons.analytics),
                  label: const Text('Monitor'),
                  style: ElevatedButton.styleFrom(
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      inherit: true,
                    ),
                    backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  } // Finish Main Page layout
//////////////////////////////////////////////////////////////////////////////////////////////

//creates a styled information card. The card contains
// an icon, a title, and some data, all styled and laid out consistently.
  Widget _buildInfoCard(String title, String data, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      //BoxDecoration
      //Sets the background color of the card using theme,
      //Rounds the corners with borderRadius
      //Adds a subtle shadow using the BoxShadow
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            data,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
//////////////////////////////////////////////////////////////////////////////////////////////

  Widget _buildActionButton(String label, IconData icon, {required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          inherit: true,
        ),
        backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.9),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> rebootDevice() async {
    // Reboot logic
  }
}

////////////////// arrow rotating class  ///////////////////////////////////////
class RotatingIcon extends StatefulWidget {
  final bool isRunning;

  const RotatingIcon({Key? key, required this.isRunning}) : super(key: key);

  @override
  _RotatingIconState createState() => _RotatingIconState();
}

class _RotatingIconState extends State<RotatingIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    if (widget.isRunning) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(RotatingIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(Icons.refresh, size: 40, color: widget.isRunning ? Colors.green : Colors.red),
    );
  }
}

/////////////////////////////////////////////////////////////////////////////////
class MonitorReportScreen extends StatelessWidget {
  final Map<String, dynamic> report;

  const MonitorReportScreen({Key? key, required this.report}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitor Report'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Most Common Movement: ${report['mostCommonMovement']}"),
            Text("Most Common Classification: ${report['mostCommonClassification']}"),
            Text("Movement Count: ${report['movementCount']}"),
            Text("Classification Count: ${report['classificationCount']}"),
            Text("Data Points: ${report['dataPoints']}"),
          ],
        ),

      ),
    );
  }
}

//////////////////////////widget to display a web page within a Flutter app using WebView////////////////////////////////////////
class CameraStreamPage extends StatelessWidget {
  final String ipAddress;
  const CameraStreamPage({Key? key, required this.ipAddress}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Camera Stream'),
      ),
      body: WebView(
        initialUrl: 'http://$ipAddress:5000/camera_stream',

        javascriptMode: JavascriptMode.unrestricted,
      ),
    );
  }
}
//////////////////////////GPS////////////////////////////////////


class GpsMapPage extends StatefulWidget {
  final String ipAddress;

  const GpsMapPage({Key? key, required this.ipAddress}) : super(key: key);

  @override
  _GpsMapPageState createState() => _GpsMapPageState();
}

class _GpsMapPageState extends State<GpsMapPage> {
  late GoogleMapController mapController;
  LatLng currentLocation = LatLng(37.7749, -122.4194); // Default location (San Francisco)
  Timer? timer;
  Set<Marker> markers = {}; // To dynamically update markers

  @override
  void initState() {
    super.initState();
    setGpsNavigating(true); // Enable GPS navigation
    fetchAndUpdateLocation();
    timer = Timer.periodic(Duration(seconds: 3), (_) => fetchAndUpdateLocation());
  }

  @override
  void dispose() {
    timer?.cancel(); // Stop the periodic update timer
    setGpsNavigating(false); // Disable GPS navigation
    super.dispose();
  }

  // control the gps active flag in main.py
  Future<void> setGpsNavigating(bool status) async {
    final url = "http://${widget.ipAddress}:5000/set_gps_navigating"; // Replace with your Flask server's IP
    try {
      await http.post(
        Uri.parse(url),
        body: json.encode({"Gps_navigating": status}),
        headers: {"Content-Type": "application/json"},
      );
    } catch (e) {
      print("Error setting GPS navigating status: $e");
    }
  }

  Future<void> fetchAndUpdateLocation() async {
    final url = "http://${widget.ipAddress}:5000/gps_coordinates"; // Replace with your Flask server's IP
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['latitude'] != null && data['longitude'] != null) {
          LatLng newLocation = LatLng(data['latitude'], data['longitude']);
          setState(() {
            currentLocation = newLocation;
            markers = {
              Marker(
                markerId: MarkerId("current_location"),
                position: currentLocation,
                infoWindow: InfoWindow(title: "Current Location"),
              ),
            };
          });
          mapController.animateCamera(CameraUpdate.newLatLng(newLocation)); // Update the map position
        }
      } else {
        print("Failed to fetch GPS data: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching GPS data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Perform cleanup and return true to allow back navigation
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Real-Time GPS Map"),
        ),
        body: GoogleMap(
          onMapCreated: (GoogleMapController controller) {
            mapController = controller;
          },
          initialCameraPosition: CameraPosition(
            target: currentLocation,
            zoom: 15.0,
          ),
          markers: markers, // Use dynamic markers
        ),
      ),
    );
  }
}