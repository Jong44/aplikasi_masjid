import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'commons.dart';

class TextModal extends StatefulWidget {
  final String? id;
  final String? text;
  final bool isUpdate;
  final VoidCallback? onDelete;
  const TextModal({Key? key,this.id,this.text,this.isUpdate = true,this.onDelete}) : super(key: key);

  @override
  State<TextModal> createState() => _TextModalState();
}

class _TextModalState extends State<TextModal> {

  var textController = TextEditingController();
  final fDatabase = FirebaseDatabase.instance;

  @override
  void initState(){
    super.initState();
    if (widget.text != null){
      textController.text = widget.text!;
    }
  }

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
                      'Text',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 16,),
                    TextFormField(
                      controller: textController,
                      textInputAction: TextInputAction.newline,
                      maxLines: 5,
                      decoration: InputDecoration(
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        hintText: "Masukkan Text",
                        hintStyle: TextStyle(color: Colors.grey.shade300),
                      ),
                    ),
                    SizedBox(height: 10,),
                    Row(
                      children: [
                        if (widget.isUpdate)Expanded(
                          child: ElevatedButton(
                            onPressed: widget.onDelete,
                            style: ElevatedButton.styleFrom(
                                primary: Colors.red
                            ),
                            child: Text(
                                'Hapus'
                            ),
                          ),
                        ),
                        if (widget.isUpdate)SizedBox(width: 10,),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSubmit()?(){
                              Navigator.pop(context,textController.text);
                            }:null,
                            style: ElevatedButton.styleFrom(
                                primary: primaryColor
                            ),
                            child: Text(
                                'Simpan'
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool isSubmit(){
    if (textController.text.isEmpty)return false;
    else return true;
  }
}
