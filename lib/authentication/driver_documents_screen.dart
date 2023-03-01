

import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:utransfers_driver/global/global.dart';

//Those are for testing purpose
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:utransfers_driver/splashScreen/splash_screen.dart';

class DriverDocumentsScreen extends StatefulWidget
{
  const DriverDocumentsScreen({Key? key}) : super(key: key);

  @override
  _DocumentsinfoScreenState createState() => _DocumentsinfoScreenState();
}

class _DocumentsinfoScreenState extends State<DriverDocumentsScreen> {
  TextEditingController driverLicenseEditingController = TextEditingController();

  TextEditingController ProfecionalDriverLicenseEditingController = TextEditingController();

  TextEditingController vehicleRegistrationLicenseEditingController = TextEditingController();

  TextEditingController UrbanClassUsePermitLicenseEditingController = TextEditingController();

  //final ImagePicker _picker = ImagePicker();
  //File? imageFile;


  DatabaseReference driversRef = FirebaseDatabase.instance.ref().child("drivers");
  firebase_storage.FirebaseStorage storage = firebase_storage.FirebaseStorage.instance;

  String? userId = onlineDriverData.id;
  var snapshot;

  //late File _image;
  final picker = ImagePicker();
  late bool DriverLicense =false;
  late bool ProfectionalLicense = false;
  late bool RegistrationLicense= false;
  late bool urbanClassPermit = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 22.0,),
              Image.asset("images/driverlogo.png", width: 300.0, height: 150.0,),
              Padding(
                padding: EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 30.0),
                child: Column(
                  children: [
                    SizedBox(height: 8.0,),
                    Text("Enter Car Details", style: TextStyle(
                        fontFamily: "Brand Bold", fontSize: 24.0),),

                    SizedBox(height: 12.0,),
                    ElevatedButton(

                        style: raisedButtonStyle,
                        child: Text('Driver License'),
                        onPressed: ()  {
                          getImage("Driver License");   //"Driver License"


                            DriverLicense = true;

                        }),

                    SizedBox(height: 15.0,),
                    ElevatedButton(
                      style: raisedButtonStyle,
                      child: Text('Profecional Driver License'),
                      onPressed: ()  {

                        getImage("Profecional Driver License");

                        ProfectionalLicense = true;
                      },

                    ),

                    SizedBox(height: 15.0,),
                    ElevatedButton(
                      style: raisedButtonStyle,
                      onPressed: ()  {

                        getImage("Vehicle Registration");

                        RegistrationLicense= true;
                      },
                      child: Text('Vehicle Registration'),
                    ),
                    SizedBox(height: 15.0,),
                    ElevatedButton(
                      style: raisedButtonStyle,
                      onPressed: () {

                        getImage("Urban class road use permit");

                        urbanClassPermit = true;
                      },
                      child: Text('Urban class road use permit'),
                    ),

                    const SizedBox(height: 26.0,),

                    const SizedBox(height: 42.0,),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: ElevatedButton(
                        onPressed: () {
                          //driverLicenseEditingController.hasListeners
                          if (DriverLicense = false)
                          {
                            Fluttertoast.showToast(msg: "Please Upload your Driver License.");

                          }
                          //ProfecionalDriverLicenseEditingController
                          //                               .hasListeners
                          else if (ProfectionalLicense == false)
                          {
                            Fluttertoast.showToast(msg:  "Please Upload your Profecional Driver License.");

                          }
                          //vehicleRegistrationLicenseEditingController
                          //                               .hasListeners
                          else if (RegistrationLicense == false)
                          {
                            Fluttertoast.showToast(msg:   "Please Upload your Vehicle Registration.");

                          }
                          // UrbanClassUsePermitLicenseEditingController
                          //                               .hasListeners
                          else if (urbanClassPermit == false)
                          {
                            Fluttertoast.showToast(msg:   "Please Upload your Urban Class Use Permit.");
                          }
                          else {
                            //saveDriverDocInfo(context);
                            Navigator.push(context, MaterialPageRoute(builder: (c)=> const MySplashScreen()));
                          }
                        },
                        // color: Colors.black54,
                        child: Padding(
                          padding: EdgeInsets.all(17.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text("NEXT", style: TextStyle(fontSize: 20.0,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),),
                              Icon(Icons.arrow_forward, color: Colors.white,
                                size: 26.0,),
                            ],
                          ),
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  final ButtonStyle raisedButtonStyle = ElevatedButton.styleFrom(
    onPrimary: Colors.black87,
    primary: Colors.grey[300],
    minimumSize: Size(88, 36),
    padding: EdgeInsets.symmetric(horizontal: 16),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(2)),

    ),
  );

  void saveDriverDocInfo(context) {
    String? userId = onlineDriverData.id;

    Map docInfoMap =
    {
      "vehicle_reg": vehicleRegistrationLicenseEditingController.hasListeners ==
          true,
      "pro_driver_license": ProfecionalDriverLicenseEditingController
          .hasListeners == true,
      "driver_license": driverLicenseEditingController.hasListeners == true,
      "urban_use_permit": UrbanClassUsePermitLicenseEditingController
          .hasListeners == true,
    };

    driversRef.child(userId!).child("doc_details").set(docInfoMap);


    Navigator.push(context, MaterialPageRoute(builder: (c)=> const MySplashScreen()));
  }

  Future getImage(String fileName) async
  {


    ImagePicker imagePicker = ImagePicker();
    XFile? file = await imagePicker.pickImage(source: ImageSource.gallery);
    //String? path = file!.path;
    print("${file?.path}");

    if(file == null) return;

    //Get reference to storage root
    Reference referenceRoot = FirebaseStorage.instance.ref();
    Reference referenceDirImage = referenceRoot.child(currentFirebaseUser!.uid);

    //Create a reference for the image to be stored
    Reference referenceImageToUpload = referenceDirImage.child(fileName);

    //Store the file
    referenceImageToUpload.putFile(File(file!.path));
  }





/*
  Future getImage(String type) async {
    final pickedFile =  await ImagePicker().getImage(source: ImageSource.gallery);
    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);

        String filename = basename(_image.path);
        Reference storageReference = FirebaseStorage.instance.ref().child("$userId/$type");
        final UploadTask uploadTask = storageReference.putFile(_image);



      } else {
        print('No image selected.');
      }

    });
  }





  Future<void> saveImageToFirebaseStorage(BuildContext context) async {

    final picker = ImagePicker();
    final pickedFile = await picker.getImage(source: ImageSource.gallery);
    final file = File(pickedFile.path);

    if (file != null) {
      // Upload the file to Firebase Storage
      final storage = FirebaseStorage.instance;
      final storageRef = storage.ref().child('images/${file.path.split('/').last}');
      final uploadTask = storageRef.putFile(file);

      // Wait for the upload to complete
      await uploadTask.whenComplete(() {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image uploaded successfully')));
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No image selected')));
    }
  }
*/
}




