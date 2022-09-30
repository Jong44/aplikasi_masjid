import 'dart:convert';
import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MenuModal extends StatefulWidget {
  final String? url,keyData;
  final VoidCallback? onUpdate;
  final VoidCallback? onDelete;
  const MenuModal({this.url,this.keyData,this.onUpdate,this.onDelete});

  @override
  State<MenuModal> createState() => _MenuModalState();
}

class _MenuModalState extends State<MenuModal> {


  final fDatabase = FirebaseDatabase.instance;
  final fStorage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();


  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => true,
      child: Material(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 100,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(20)
                        ),
                      ),
                    ),
                    const SizedBox(height: 16,),
                    const Text(
                      'Menu',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 16,),
                    ListTile(
                      leading: Icon(
                        Icons.camera,
                        color: Colors.orange,
                      ),
                      onTap:widget.onUpdate,
                      title: const Text(
                        'Ganti Foto',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.delete_rounded,
                        color: Colors.red,
                      ),
                      onTap: widget.onDelete,
                      title: const Text(
                        'Hapus Foto',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
