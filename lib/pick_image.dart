import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:virtual_closet_son/video.dart';

import 'camera.dart';

class PickImage extends StatefulWidget {
  const PickImage({Key? key}) : super(key: key);

  @override
  _PickImageState createState() => _PickImageState();
}

class _PickImageState extends State<PickImage> {
  Uint8List? _image;
  File? selectedImage;
  String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        backgroundColor: Color.fromRGBO(244, 230, 230, 1),
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              height: 62, // Logonun yüksekliğini ayarlayın
            ),
            SizedBox(width: 8), // İkon ve metin arasına boşluk ekler
            Text(
              "Virtual Wardrobe",
              style: TextStyle(color: Colors.black),
            ),
          ],
        ),
      ),
      //backgroundColor: Colors.deepPurple[100],
      body: Center(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12), // Kenarları yumuşatmak için
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5), // Siyah rengi ve opaklığı
                spreadRadius: 2, // Gölgeyi yayma yarıçapı
                blurRadius: 4, // Gölgeyi bulanıklaştırma yarıçapı
                offset: Offset(0, 2), // Gölgenin konumu (x, y)
              ),
            ],
          ),

          child: Stack(
            children: [
              _image != null
                  ? Container(
                width: 300,
                height: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  image: DecorationImage(
                    image: MemoryImage(_image!),
                    fit: BoxFit.cover,
                  ),
                ),
              )
                  : Container(
                width: 300,
                height: 500,
                decoration: const BoxDecoration(
                  shape: BoxShape.rectangle,
                  image: DecorationImage(
                    image: AssetImage(
                      "assets/upload_the_outfit.png",
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.white, // Satırın arka plan rengini beyaz yapar
                  padding: EdgeInsets.all(8),
                  child: IconButton(
                    onPressed: () {
                      showImagePickerOption(context);
                    },
                    icon: Icon(
                      Icons.add_a_photo,
                      size: 52,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),



              if (message != null)
                Positioned(
                  bottom: 60,  // Move the message up to leave space for the button
                  left: 60,    // Adjust position to center it
                  child: Column(
                    children: [
                      Text(
                        message!,
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => NextPage()),
                          );
                        },
                        child: Text('Kabine Gidelim'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                          textStyle: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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

  void showImagePickerOption(BuildContext context) {
    showModalBottomSheet(
      backgroundColor: Color.fromRGBO(243,227,227,1),
      context: context,
      builder: (builder) {
        return Padding(
          padding: const EdgeInsets.all(18.0),
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height / 4.5,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      _pickImageFromGallery();
                    },
                    child: const SizedBox(
                      child: Column(
                        children: [
                          Icon(
                            Icons.image,
                            size: 70,
                          ),
                          Text("Gallery"),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      _pickImageFromCamera();
                    },
                    child: const SizedBox(
                      child: Column(
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size: 70,
                          ),
                          Text("Camera"),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImageFromGallery() async {
    final returnImage = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (returnImage == null) return;
    setState(() {
      selectedImage = File(returnImage.path);
      _image = File(returnImage.path).readAsBytesSync();
    });
    _uploadImage(selectedImage!);
    Navigator.of(context).pop(); // close the modal sheet
  }

  Future<void> _pickImageFromCamera() async {
    final returnImage = await ImagePicker().pickImage(source: ImageSource.camera);
    if (returnImage == null) return;
    setState(() {
      selectedImage = File(returnImage.path);
      _image = File(returnImage.path).readAsBytesSync();
    });
    _uploadImage(selectedImage!);
    Navigator.of(context).pop(); // close the modal sheet
  }

  Future<void> _uploadImage(File imageFile) async {
    final url = Uri.parse("https://5fa7-161-9-199-136.ngrok-free.app/upload");
    final request = http.MultipartRequest("POST", url);

    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
      ),
    );

    try {
      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      // Sunucudan gelen yanıt HTML hata sayfası ise
      if (responseData.startsWith('<!doctype html>')) {
        throw FormatException('Server returned HTML error page');
      }

      final decodedData = json.decode(responseData);

      setState(() {
        message = decodedData['message'];
      });
    } catch (error) {
      print("Error: $error");
      setState(() {
        message = 'An error occurred while uploading image.';
      });
    }
  }
}


