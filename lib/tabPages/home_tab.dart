import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:utransfers_driver/splashScreen/splash_screen.dart';
import '../assistants/assistant_methods.dart';
import '../global/global.dart';

class HomeTabPage extends StatefulWidget {
  const HomeTabPage({Key? key}) : super(key: key);

  @override
  _HomeTabPageState createState() => _HomeTabPageState();
}

class _HomeTabPageState extends State<HomeTabPage>
{
  GoogleMapController? newGoogleMapController;
  final Completer<GoogleMapController> _controllerGoogleMap = Completer();

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );

  Position? driverCurrentPosition;
  var geoLocator = Geolocator();
  LocationPermission? _locationPermission;

  String statusText = "Offline";
  Color buttonColor = Colors.purpleAccent;
  bool isDriverActive = false;




  checkIfLocationPermissionAllowed() async
  {
    _locationPermission = await Geolocator.requestPermission();

    if(_locationPermission == LocationPermission.denied)
    {
      _locationPermission = await Geolocator.requestPermission();
    }
  }

  locateDriverPosition() async
  {
    Position cPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    driverCurrentPosition = cPosition;

    LatLng latLngPosition = LatLng(driverCurrentPosition!.latitude, driverCurrentPosition!.longitude);

    CameraPosition cameraPosition = CameraPosition(target: latLngPosition, zoom: 14);

    newGoogleMapController!.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));

    String humanReadableAddress = await AssistantMethods.searchAddressForGeographicCoOrdinated(driverCurrentPosition!,context);
    print("this is your address = " + humanReadableAddress);

  }

  @override
  void initState()
  {
    super.initState();

    checkIfLocationPermissionAllowed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(
          children: [
            GoogleMap(
              mapType: MapType.normal,
              myLocationEnabled: true,
              initialCameraPosition: _kGooglePlex,
              onMapCreated: (GoogleMapController controller)
              {
                _controllerGoogleMap.complete(controller);
                newGoogleMapController = controller;

                locateDriverPosition();
                updateDriversLocationAtRealTime();

              },
            ),
            //ui for online/offline driver button
            statusText != "Online"
                ? Container(
              height: MediaQuery.of(context).size.height,
              width: double.infinity,
              color: Colors.black87,
            )
                : Container(),

            //button for online/offline driver
            Positioned(
              top: statusText != "Online"
                  ? MediaQuery.of(context).size.height * 0.46
                  : 25,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: ()
                    {

                      if(isDriverActive != true) //offline
                        {
                        driverIsOnlineNow();
                        updateDriversLocationAtRealTime();

                        setState(() {
                          statusText = "Online";
                          isDriverActive = true;
                          buttonColor = Colors.transparent;
                        });
                        //display Toast
                        Fluttertoast.showToast(msg: "You are online now!");
                      }
                      else
                        {
                          driverIsOffLineNow();
                          setState(() {
                            statusText = "Offline";
                            isDriverActive = false;
                            buttonColor = Colors.grey;
                          });
                          //display Toast
                          Fluttertoast.showToast(msg: "You are offline now!");
                        }
                    },
                    style: ElevatedButton.styleFrom(
                      primary: buttonColor,
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)
                      )
                    ),
                    child: statusText != "Online"
                        ? Text(
                      statusText,
                      style: const TextStyle(
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(
                      Icons.phonelink_ring,
                      color: Colors.black,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
          ],
        )
    );
  }
  driverIsOnlineNow() async
  {
    Position pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    driverCurrentPosition = pos;

    Geofire.initialize("activeDrivers");
    Geofire.setLocation(
        currentFirebaseUser!.uid,
        driverCurrentPosition!.latitude,
        driverCurrentPosition!.longitude
    );

    DatabaseReference ref = FirebaseDatabase.instance.ref()
        .child("drivers")
        .child(currentFirebaseUser!.uid)
        .child("newRideStatus");

    ref.set("idle"); //searching for ride request
    ref.onValue.listen((event) { });
  }

  updateDriversLocationAtRealTime()
  {
    streamSubscriptionPosition = Geolocator.getPositionStream()
        .listen((Position position) 
    {
      driverCurrentPosition = position;
      
      if(isDriverActive == true)
        {
          Geofire.setLocation(
              currentFirebaseUser!.uid,
              driverCurrentPosition!.latitude,
              driverCurrentPosition!.longitude,
          );
        }

      LatLng latLng = LatLng(
          driverCurrentPosition!.latitude,
          driverCurrentPosition!.longitude,
      );
      
      newGoogleMapController!.animateCamera(CameraUpdate.newLatLng(latLng));
    });
  }
  
  driverIsOffLineNow()
  {
    Geofire.removeLocation(currentFirebaseUser!.uid);
    DatabaseReference? ref = FirebaseDatabase.instance.ref()
        .child("drivers")
        .child(currentFirebaseUser!.uid)
        .child("newRideStatus");
    ref.onDisconnect();
    ref.remove();
    ref = null;
    
    Future.delayed(const Duration(milliseconds: 2000), ()
        {
       // SystemChannels.platform.invokeMethod("SystemNavigator.pop");
          SystemNavigator.pop();
        //Navigator.push(context, MaterialPageRoute(builder: (c)=> MySplashScreen())); With this code the app does not fully restart and MAYBE i have some problems later(i have to debug to check)
    });
  }
}
