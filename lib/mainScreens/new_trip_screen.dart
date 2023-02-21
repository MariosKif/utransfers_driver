import 'dart:async';


import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:utransfers_driver/widgets/fare_amount_collection_dialog.dart';

import '../assistants/assistant_methods.dart';
import '../assistants/black_theme_google_map.dart';
import '../global/global.dart';
import '../infoHandler/app_info.dart';
import '../models/user_ride_request_information.dart';
import '../widgets/progress_dialog.dart';


class NewTripScreen extends StatefulWidget
{
  UserRideRequestInformation? userRideRequestDetails;

  NewTripScreen({
    this.userRideRequestDetails,
  });

  @override
  State<NewTripScreen> createState() => _NewTripScreenState();
}




class _NewTripScreenState extends State<NewTripScreen>
{
  GoogleMapController? newTripGoogleMapController;
  final Completer<GoogleMapController> _controllerGoogleMap = Completer();

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );

  String? buttonTitle = "Arrived";
  Color? buttonColor = Colors.green;


  Set<Marker> setOfMarkers = Set<Marker>();
  Set<Circle> setOfCircle = Set<Circle>();
  Set<Polyline> setOfPolyline = Set<Polyline>();
  List<LatLng> polyLinePositionCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints();

  double mapPadding = 0;
  BitmapDescriptor? iconAnimatedMarker;
  var geoLocator = Geolocator();
  Position? onlineDriverCurrentPosition;

  String rideRequestStatus = "accepted";
  String durationFromOriginToDestination = "";

  bool isRequestDirectionDetails = false;


  Future<void> drawPolyLineFromOriginToDestination(LatLng originLatLng, LatLng destinationLatLng) async
  {

    showDialog(
      context: context,
      builder: (BuildContext context) => ProgressDialog(message: "Please wait...",),
    );

    var directionDetailsInfo = await AssistantMethods.obtainOriginToDestinationDirectionDetails(originLatLng, destinationLatLng);


    Navigator.pop(context);

    print("These are points = ");
    print(directionDetailsInfo!.e_points);

    PolylinePoints pPoints = PolylinePoints();
    List<PointLatLng> decodedPolyLinePointsResultList = pPoints.decodePolyline(directionDetailsInfo!.e_points!);

    polyLinePositionCoordinates.clear();

    if(decodedPolyLinePointsResultList.isNotEmpty)
    {
      decodedPolyLinePointsResultList.forEach((PointLatLng pointLatLng)
      {
        polyLinePositionCoordinates.add(LatLng(pointLatLng.latitude, pointLatLng.longitude));
      });
    }

    setOfPolyline.clear();

    setState(() {
      Polyline polyline = Polyline(
        color: Colors.purpleAccent,
        polylineId: const PolylineId("PolylineID"),
        jointType: JointType.round,
        points: polyLinePositionCoordinates,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        geodesic: true,
      );

      setOfPolyline.add(polyline);
    });

    LatLngBounds boundsLatLng;
    if(originLatLng.latitude > destinationLatLng.latitude && originLatLng.longitude > destinationLatLng.longitude)
    {
      boundsLatLng = LatLngBounds(southwest: destinationLatLng, northeast: originLatLng);
    }
    else if(originLatLng.longitude > destinationLatLng.longitude)
    {
      boundsLatLng = LatLngBounds(
        southwest: LatLng(originLatLng.latitude, destinationLatLng.longitude),
        northeast: LatLng(destinationLatLng.latitude, originLatLng.longitude),
      );
    }
    else if(originLatLng.latitude > destinationLatLng.latitude)
    {
      boundsLatLng = LatLngBounds(
        southwest: LatLng(destinationLatLng.latitude, originLatLng.longitude),
        northeast: LatLng(originLatLng.latitude, destinationLatLng.longitude),
      );
    }
    else
    {
      boundsLatLng = LatLngBounds(southwest: originLatLng, northeast: destinationLatLng);
    }

    newTripGoogleMapController!.animateCamera(CameraUpdate.newLatLngBounds(boundsLatLng, 65));

    Marker originMarker = Marker(
      markerId: const MarkerId("originID"),
      position: originLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
    );

    Marker destinationMarker = Marker(
      markerId: const MarkerId("destinationID"),
      position: destinationLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
    );

    setState(() {
      setOfMarkers.add(originMarker);
      setOfMarkers.add(destinationMarker);
    });

    Circle originCircle = Circle(
      circleId: const CircleId("originID"),
      fillColor: Colors.green,
      radius: 12,
      strokeWidth: 3,
      strokeColor: Colors.white,
      center: originLatLng,
    );

    Circle destinationCircle = Circle(
      circleId: const CircleId("destinationID"),
      fillColor: Colors.red,
      radius: 12,
      strokeWidth: 3,
      strokeColor: Colors.white,
      center: destinationLatLng,
    );

    setState(() {
      setOfCircle.add(originCircle);
      setOfCircle.add(destinationCircle);
    });
  }

  @override
  void initState() {
    super.initState();

    saveAssignedDriverDetailsToUserRideRequest();
  }

  createDriverIconMarker()
  {
    if(iconAnimatedMarker == null)
    {
      ImageConfiguration imageConfiguration = createLocalImageConfiguration(context, size: const Size(2, 2));
      BitmapDescriptor.fromAssetImage(imageConfiguration, "images/car.png").then((value)
      {
        iconAnimatedMarker = value;
      });
    }
  }

  getDriversLocationUpdatesAtRealTime()
  {
    LatLng oldLatLng = LatLng(0, 0);

    streamSubscriptionDriverLivePosition = Geolocator.getPositionStream()
        .listen((Position position)
    {
      driverCurrentPosition = position;
      onlineDriverCurrentPosition = position;


      LatLng latLngLiveDriverPosition = LatLng(
        onlineDriverCurrentPosition!.latitude,
        onlineDriverCurrentPosition!.longitude,
      );

      Marker animatingMarker = Marker(
          markerId: const MarkerId("AnimatedMarker"),
        position: latLngLiveDriverPosition,
        icon: iconAnimatedMarker!,
        infoWindow: const InfoWindow(title: "This is your position."),
      );

      setState(() {
        CameraPosition cameraPosition = CameraPosition(target: latLngLiveDriverPosition,zoom: 16);
        newTripGoogleMapController!.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));

        setOfMarkers.removeWhere((element) => element.markerId.value == "AnimatedMarker");
        setOfMarkers.add(animatingMarker);
      });
      oldLatLng = latLngLiveDriverPosition;
      updateDurationTimeAtRealTime();

      Map driverLatLngDataMap =
      {
        "latitude": onlineDriverCurrentPosition!.latitude.toString(),
        "longitude": onlineDriverCurrentPosition!.longitude.toString(),
      };
      //Update driver location in database in real time
      FirebaseDatabase.instance.ref()
          .child("All Ride Requests")
          .child(widget.userRideRequestDetails!.rideRequestId!)
          .child("driverLocation")
          .set(driverLatLngDataMap);
    });
  }

  updateDurationTimeAtRealTime() async
  {
    if(isRequestDirectionDetails == false)
      {
        isRequestDirectionDetails = true;

        if(onlineDriverCurrentPosition == null)
          {
            return;
          }

        var originLatLng = LatLng(
            onlineDriverCurrentPosition!.latitude,
            onlineDriverCurrentPosition!.longitude
        ); //Driver current Position

        var destinationLatLng;

        if(rideRequestStatus == "accepted")
        {
          destinationLatLng = widget.userRideRequestDetails!.originLatLng; //User pick_up Location
        }
        else
        {
          destinationLatLng = widget.userRideRequestDetails!.destinationLatLng; //User Drop_off Location
        }

        var directionInformation = await AssistantMethods.obtainOriginToDestinationDirectionDetails(originLatLng, destinationLatLng);

        if(directionInformation != null)
        {
         setState(() {
           durationFromOriginToDestination = directionInformation.duration_text!;
         });
        }
        isRequestDirectionDetails = false;
      }
  }

  @override
  Widget build(BuildContext context)
  {
    createDriverIconMarker();

    return Scaffold(
      body: Stack(
        children: [

          //google map
          GoogleMap(
            padding: EdgeInsets.only(bottom: mapPadding),
            mapType: MapType.normal,
            myLocationEnabled: true,
            initialCameraPosition: _kGooglePlex,
            markers: setOfMarkers,
            circles: setOfCircle,
            polylines: setOfPolyline,
            onMapCreated: (GoogleMapController controller)
            {
              _controllerGoogleMap.complete(controller);
              newTripGoogleMapController = controller;

              setState(() {
                mapPadding = 350;
              });

              //black theme google map
              blackThemeGoogleMap(newTripGoogleMapController);

              var  driverCurrentLatLng = LatLng(
                  driverCurrentPosition!.latitude,
                  driverCurrentPosition!.longitude
               );

              var userPickUpLatLng = widget.userRideRequestDetails!.originLatLng;
              
              drawPolyLineFromOriginToDestination(driverCurrentLatLng, userPickUpLatLng!);

              getDriversLocationUpdatesAtRealTime();
            },
          ),

          //ui
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                ),
                boxShadow:
                [
                  BoxShadow(
                    color: Colors.white30,
                    blurRadius: 18,
                    spreadRadius: .5,
                    offset: Offset(0.6, 0.6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                child: Column(
                  children: [

                    //duration
                    Text(
                      durationFromOriginToDestination,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.lightGreenAccent,
                      ),
                    ),

                    const SizedBox(height: 18,),

                    const Divider(
                      thickness: 2,
                      height: 2,
                      color: Colors.grey,
                    ),

                    const SizedBox(height: 8,),

                    //user name - icon
                    Row(
                      children: [
                        Text(
                          widget.userRideRequestDetails!.userName!,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.lightGreenAccent,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(10.0),
                          child: Icon(
                            Icons.phone_android,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18,),

                    //user PickUp Address with icon
                    Row(
                      children: [
                        Image.asset(
                          "images/origin.png",
                          width: 30,
                          height: 30,
                        ),
                        const SizedBox(width: 14,),
                        Expanded(
                          child: Container(
                            child: Text(
                              widget.userRideRequestDetails!.originAddress!,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20.0),

                    //user DropOff Address with icon
                    Row(
                      children: [
                        Image.asset(
                          "images/destination.png",
                          width: 30,
                          height: 30,
                        ),
                        const SizedBox(width: 14,),
                        Expanded(
                          child: Container(
                            child: Text(
                              widget.userRideRequestDetails!.destinationAddress!,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24,),

                    const Divider(
                      thickness: 2,
                      height: 2,
                      color: Colors.grey,
                    ),

                    const SizedBox(height: 10.0),

                    ElevatedButton.icon(
                      onPressed: () async
                      {
                        //Driver has arrived at user PickUp Location
                        if(rideRequestStatus == "accepted")
                          {
                            rideRequestStatus = "arrived";
                            FirebaseDatabase.instance
                                .ref().child("All Ride Requests")
                                .child(widget.userRideRequestDetails!.rideRequestId!)
                                .child("status")
                                .set(rideRequestStatus);

                            setState(() {
                              buttonTitle = "Let's Go"; //Start the trip
                              buttonColor = Colors.lightGreen;
                            });

                            showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (BuildContext c) => ProgressDialog(
                                  message: "Loading ",
                                )
                            );

                            await drawPolyLineFromOriginToDestination(
                                widget.userRideRequestDetails!.originLatLng!,
                                widget.userRideRequestDetails!.destinationLatLng!
                            );
                            Navigator.pop(context);
                          }
                        //User has enter the car -> Start Trip now
                        else if(rideRequestStatus == "arrived")
                        {
                          rideRequestStatus = "ontrip";
                          FirebaseDatabase.instance
                              .ref().child("All Ride Requests")
                              .child(widget.userRideRequestDetails!.rideRequestId!)
                              .child("status")
                              .set(rideRequestStatus);

                          setState(() {
                            buttonTitle = "End Ride"; //Start the trip
                            buttonColor = Colors.red;
                          });
                        }

                        //User and driver has reach the destination -> End Trip now
                        else if(rideRequestStatus == "ontrip")
                        {
                          endTripNow();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        primary: buttonColor,
                      ),
                      icon: const Icon(
                        Icons.directions_car,
                        color: Colors.white,
                        size: 25,
                      ),
                      label: Text(
                        buttonTitle!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }

  endTripNow() async
  {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => ProgressDialog(message: "Please wait...",),
    );

    //Get the tripDirectionDetails = distance traveled
    var currentPositionLatLng = LatLng(
      onlineDriverCurrentPosition!.latitude,
      onlineDriverCurrentPosition!.longitude,
    );

    var tripDirectionDetails =  await AssistantMethods.obtainOriginToDestinationDirectionDetails(
        currentPositionLatLng,
        widget.userRideRequestDetails!.originLatLng!
    );

    //fare amount
    double totalFareAmount = AssistantMethods.calculateFareAmountFromOriginToDestination(tripDirectionDetails!);
    
    FirebaseDatabase.instance.ref()
        .child("All Ride Requests")
        .child(widget.userRideRequestDetails!.rideRequestId!)
        .child("fareAmount")
        .set(totalFareAmount.toString());

    FirebaseDatabase.instance.ref()
        .child("All Ride Requests")
        .child(widget.userRideRequestDetails!.rideRequestId!)
        .child("status")
        .set("ended");

    streamSubscriptionDriverLivePosition!.cancel();

    Navigator.pop(context);

    //display fare amount in dialog box
    showDialog(
        context: context,
        builder: (BuildContext c) => FareAmountCollectionDialog(
            totalFareAmount: totalFareAmount),
    );

    //Save total amount to driver total earnings
    saveFareAmountToDriverEarnings(totalFareAmount);

  }

  saveFareAmountToDriverEarnings(double totalFareAmount)
  {
    FirebaseDatabase.instance.ref()
    .child("drivers")
        .child(currentFirebaseUser!.uid)
        .child("earnings")
        .once()
        .then((snap)
    {
      //Earnings subchild exist
      if(snap.snapshot.value != null)
        {
          double oldEarnings = double.parse(snap.snapshot.value.toString());
          double driverTotalEarnings = totalFareAmount + oldEarnings;

          FirebaseDatabase.instance.ref()
              .child("drivers")
              .child(currentFirebaseUser!.uid)
              .child("earnings")
              .set(driverTotalEarnings.toString());
        }
      //Earnings subchild do not exist
      else
        {
          FirebaseDatabase.instance.ref()
              .child("drivers")
              .child(currentFirebaseUser!.uid)
              .child("earnings")
              .set(totalFareAmount.toString());
        }
    });
  }

  saveAssignedDriverDetailsToUserRideRequest()
  {
    DatabaseReference databaseReference = FirebaseDatabase.instance.ref()
                                            .child("All Ride Requests")
                                            .child(widget.userRideRequestDetails!.rideRequestId!);

    Map driverLocationDataMap =
    {
       "latitude": driverCurrentPosition!.latitude.toString(),
       "longitude": driverCurrentPosition!.longitude.toString(),

    };

    databaseReference.child("driverLocation").set(driverLocationDataMap);

    databaseReference.child("status").set("accepted");
    databaseReference.child("driverId").set(onlineDriverData.id);
    databaseReference.child("driverName").set(onlineDriverData.name);
    databaseReference.child("driverPhone").set(onlineDriverData.phone);
    databaseReference.child("car_details").set(onlineDriverData.car_color.toString()+ " " + onlineDriverData.car_model.toString()+ " " + onlineDriverData.car_number.toString());

    //saveRideRequestIdToDriverHistory();
  }

 /* saveRideRequestIdToDriverHistory()
  {
    DatabaseReference tripsHistoryRef = FirebaseDatabase.instance.ref()
                                          .child("drivers")
                                          .child(currentFirebaseUser!.uid )
                                          .child("tripsHistory");

    tripsHistoryRef.child(widget.userRideRequestDetails!.rideRequestId!).set(true);

  } */
}
