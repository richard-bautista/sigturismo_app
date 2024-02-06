import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MarkerDetails {
  final String nombre;
  final double latitud;
  final double longitud;
  final String? tipo;
  final String? lineaTransporte;
  final String? celular;
  final String? paginaWeb;
  final String? email;
  final String? horarioAtencion;
  final String? direccion;
  final String? urlImagenPortada;
  final String? circuitoId;

  MarkerDetails({
    required this.nombre,
    required this.latitud,
    required this.longitud,
    this.tipo,
    this.lineaTransporte,
    this.celular,
    this.paginaWeb,
    this.email,
    this.horarioAtencion,
    this.direccion,
    this.urlImagenPortada,
    this.circuitoId,
  });
}

Future<List<MarkerDetails>> fetchMarkers(
    String tipo, String selectedCircuit) async {
  final response = await http
      .get(Uri.parse('https://sigturismo.up.railway.app/api/v1/lugares'));

  if (response.statusCode == 200) {
    final List<dynamic> data = json.decode(response.body);

    // Obtener la lista de circuitos y sus IDs
    final circuitos =
        await fetchCircuits(); // Asumiendo que tienes una función fetchCircuits

    // Mapear el nombre del circuito al número de circuito_id
    final circuitIdMap =
        Map.fromEntries(circuitos.map((c) => MapEntry(c['nombre'], c['id'])));

    print(
        'selectedCircuit: $selectedCircuit'); // Imprimir el circuito seleccionado para depuración

    final filteredMarkers = data.where((pointData) {
      final circuitId = pointData['circuito_id']?.toString() ?? '';
      final circuitName = circuitIdMap[selectedCircuit]?.toString() ?? '';
      bool matchesType = tipo == 'all' || pointData['tipo'] == tipo;
      bool matchesCircuit =
          selectedCircuit == 'todos' || circuitId == circuitName;
      return matchesType && (tipo != 'ruta' || matchesCircuit);
    }).toList();

    print(
        'Marcadores filtrados: $filteredMarkers'); // Imprimir los marcadores filtrados

    if (filteredMarkers.isNotEmpty) {
      return filteredMarkers.map<MarkerDetails>((pointData) {
        double lat = double.parse(pointData['latitud'].toString());
        double lng = double.parse(pointData['longitud'].toString());
        return MarkerDetails(
          nombre: pointData['nombre'],
          latitud: lat,
          longitud: lng,
          tipo: pointData['tipo'],
          lineaTransporte: pointData['linea_transporte'],
          celular: pointData['celular'],
          paginaWeb: pointData['pagina_web'],
          email: pointData['email'],
          horarioAtencion: pointData['horario_atencion'],
          direccion: pointData['direccion'],
          urlImagenPortada: pointData['url_imagen_portada'],
          circuitoId: pointData['circuito_id'].toString(),
        );
      }).toList();
    }
  } else {
    print('Error en la solicitud: ${response.statusCode}');
  }
  return []; // Devolver una lista vacía si no hay marcadores encontrados
}

Future<List<Map<String, String>>> fetchCircuits() async {
  final response = await http
      .get(Uri.parse('https://sigturismo.up.railway.app/api/v1/circuitos'));

  if (response.statusCode == 200) {
    final List<dynamic> data = json.decode(response.body);
    List<Map<String, String>> circuits = [];
    for (var circuitData in data) {
      String nombre = circuitData['nombre'];
      String id = circuitData['id'].toString();
      circuits.add({'nombre': nombre, 'id': id});
    }
    return circuits;
  } else {
    throw Exception('Failed to load circuits');
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sigturismo',
      theme: ThemeData(
        primarySwatch: Colors.amber,
      ),
      debugShowCheckedModeBanner: false,
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  String selectedType = 'all';
  String selectedCircuit = 'todos';
  late Future<List<Map<String, String>>> circuits;
  Map<String, String?> circuitIdMap = {};
  List<MarkerDetails> markers = []; // La lista de marcadores sincrónica
  Polyline? polilineaActual;

  @override
  void initState() {
    super.initState();
    initData();
    polilineaActual = Polyline(
      points: [
        LatLng(-16.52112964, -68.16904217),
        LatLng(-16.51223485, -68.15371135)
      ],
      strokeWidth: 4.0,
      color: Colors.red,
    );
  }

    Future<void> initData() async {
    circuits = fetchCircuits();
    (await circuits).forEach((circuit) {
      // Asegurarse de que el valor asignado pueda ser nulo
      circuitIdMap[circuit['nombre'] as String] = circuit['id'] as String?;
    });
    await updateMarkers();
  }

 Future<void> updateMarkers() async {
    var marcadoresFiltrados = await fetchMarkers(selectedType, selectedCircuit);
    setState(() {
      markers = marcadoresFiltrados;

      if (selectedType == 'ruta' && selectedCircuit != 'todos') {
        String? circuitIdForSelectedCircuit = circuitIdMap[selectedCircuit];

        var puntosRuta = marcadoresFiltrados
            .where((marker) =>
                marker.tipo == 'ruta' && (circuitIdForSelectedCircuit == null || marker.circuitoId == circuitIdForSelectedCircuit))
            .map((marker) => LatLng(marker.latitud, marker.longitud))
            .toList();

      polilineaActual = puntosRuta.isNotEmpty
          ? Polyline(
              points: puntosRuta,
              strokeWidth: 4.0,
              color: Colors.blue,
            )
          : null;
    } else {
      polilineaActual = null;
    }
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'sigturismo',
          style: TextStyle(
            color: Color.fromARGB(255, 95, 39, 2),
          ),
        ),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedType,
              items: ['all', 'destino', 'ruta']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: Color.fromARGB(255, 94, 85,
                          11), // Cambia el color según tus preferencias
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedType = newValue;
                  });
                  updateMarkers();
                }
              },
            ),
          ),
          if (selectedType == 'ruta')
            FutureBuilder<List<Map<String, String>>>(
              future: circuits,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else {
                  final circuitNames = snapshot.data!
                      .map((circuit) => circuit['nombre'])
                      .toList();
                  return DropdownButton<String>(
                    value: selectedCircuit,
                    items: ['todos', ...circuitNames]
                        .map<DropdownMenuItem<String>>((String? value) {
                      return DropdownMenuItem<String>(
                        value: value ?? 'todos',
                        child: Text(
                          value ?? 'todos',
                          style: TextStyle(
                            color: Color.fromARGB(255, 94, 85, 11),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedCircuit = newValue;
                        });
                        updateMarkers();
                      }
                    },
                  );
                }
              },
            ),
        ],
      ),
      body: FutureBuilder<List<MarkerDetails>>(
        future: fetchMarkers(selectedType, selectedCircuit),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No se encontraron marcadores.'));
          } else {
            return FlutterMap(
              options: MapOptions(
                center: LatLng(
                  snapshot.data!.first.latitud,
                  snapshot.data!.first.longitud,
                ),
                zoom: 11.2,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: ['a', 'b', 'c'],
                  userAgentPackageName: 'dev.fleaflet.flutter_map.example',
                ),
                PopupMarkerLayer(
                  options: PopupMarkerLayerOptions(
                    markers: snapshot.data!.map((markerDetails) {
                      return Marker(
                        point: LatLng(
                          markerDetails.latitud,
                          markerDetails.longitud,
                        ),
                        child: Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 40.0,
                        ),
                        height: 40,
                        width: 40,
                      );
                    }).toList(),
                    popupController: PopupController(),
                    popupDisplayOptions: PopupDisplayOptions(
                      builder: (BuildContext context, Marker marker) {
                        final lugar = snapshot.data!.firstWhere(
                          (markerDetails) =>
                              markerDetails.latitud == marker.point.latitude &&
                              markerDetails.longitud == marker.point.longitude,
                        );

                        return Container(
                          width: 200,
                          child: Card(
                            margin: EdgeInsets.all(8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (lugar.urlImagenPortada != null)
                                  Image.network(
                                    lugar.urlImagenPortada!,
                                    height: 100,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ListTile(
                                  title: Text(
                                    lugar.nombre,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (lugar.latitud != null &&
                                          lugar.longitud != null)
                                        Text(
                                            'Latitud: ${lugar.latitud}\nLongitud: ${lugar.longitud}'),
                                      if (lugar.tipo != null)
                                        Text('Tipo: ${lugar.tipo}'),
                                      if (lugar.lineaTransporte != null)
                                        Text(
                                            'Línea de transporte: ${lugar.lineaTransporte}'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (polilineaActual != null)
                  PolylineLayer(
                    polylines: [polilineaActual!],
                  ),
              ],
            );
          }
        },
      ),
    );
  }

  void updatePolilinea(List<MarkerDetails> marcadoresFiltrados) {
    print(
        "Tipo seleccionado: $selectedType, Circuito seleccionado: $selectedCircuit");

    if (selectedType == 'ruta' && selectedCircuit != 'todos') {
      var puntosRuta = marcadoresFiltrados
          .where((marker) =>
              marker.tipo == 'ruta' && marker.circuitoId == selectedCircuit)
          .map((marker) => LatLng(marker.latitud, marker.longitud))
          .toList();

      print("Puntos de ruta: $puntosRuta");

      if (puntosRuta.isNotEmpty) {
        setState(() {
          polilineaActual = Polyline(
            points: puntosRuta,
            strokeWidth: 4.0,
            color: Colors.blue,
          );
        });
      } else {
        setState(() {
          polilineaActual = null;
        });
      }
    }
  }
}
