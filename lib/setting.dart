import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv_application/info_state_model.dart';
import 'package:http/http.dart' as http;
import 'package:tv_application/kota_model.dart';
import 'commons.dart';

class SettingInfoPage extends StatefulWidget {
  final InfoStateModel? data;
  const SettingInfoPage({Key? key,this.data}) : super(key: key);

  @override
  State<SettingInfoPage> createState() => _SettingInfoPageState();
}

class _SettingInfoPageState extends State<SettingInfoPage> {
  var namaController = TextEditingController(),phoneController = TextEditingController(),alamatController = TextEditingController();
  List<KotaModel> kota = [];
  KotaModel? selectedKota;
  var state = InfoStateModel();
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    namaController.text = widget.data?.namaMasjid ?? '';
    phoneController.text = widget.data?.phone ?? '';
    alamatController.text = widget.data?.alamat ?? '';
    getKota();
  }

  Future<void> getKota() async {
    var pref = await SharedPreferences.getInstance();
    var url = Uri.parse('https://api.myquran.com/v1/sholat/kota/semua');
    var response = await http.get(url,);
    if (response.statusCode == 200){
      print(response.body);
      await pref.setString('kota', jsonEncode(jsonDecode(response.body)));
      getSavedKota();
    }else{
      throw Exception('Failed to load movie');
    }
  }

  Future<void> getSavedKota()async{
    var pref = await SharedPreferences.getInstance();
    var response = pref.getString('kota');
    setState(() {
      kota  = (jsonDecode(response!) as List?) != null &&
          (jsonDecode(response) as List).isNotEmpty
          ? (jsonDecode(response) as List)
          .map((f) => KotaModel.fromJson(f))
          .toList()
          : [];
      selectedKota = kota
          .where((element) =>
      element.id == widget.data!.idKota)
          .toList()[0];
    });
  }

  void save(){
    state = InfoStateModel(
      namaMasjid: namaController.text,
      alamat: alamatController.text,
      phone: phoneController.text,
      idKota:selectedKota?.id
    );
    Navigator.pop(context,state);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text(
          'Setting',
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nama Masjid',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  const SizedBox(height: 5,),
                  TextFormField(
                    controller: namaController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      hintText: "Nama Masjid",
                      hintStyle: TextStyle(color: Colors.grey.shade300),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 15,),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nomor Handphone',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  const SizedBox(height: 5,),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      hintText: "081234567890",
                      hintStyle: TextStyle(color: Colors.grey.shade300),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 15,),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alamat',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold
                    ),
                  ),
                  const SizedBox(height: 5,),
                  TextFormField(
                    controller: alamatController,
                    keyboardType: TextInputType.streetAddress,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      hintText: "Alamat Masjid",
                      hintStyle: TextStyle(color: Colors.grey.shade300),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 15,),
              Container(
                margin: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height * 0.01),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Provinsi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    DropdownButtonFormField<KotaModel>(
                      value: selectedKota,
                      decoration: InputDecoration(
                        fillColor: kota.isEmpty
                            ? Colors.grey.shade400
                            : Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: selectedKota != null
                                ? primaryColor
                                : Colors.grey[200]!,
                          ),
                        ),
                      ),
                      hint: const Text(
                        "Pilih kota anda",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      items: kota.map((value) {
                        return DropdownMenuItem<KotaModel>(
                          value: value,
                          child: Row(
                            children: <Widget>[
                              Text(
                                value.lokasi!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              )
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        selectedKota = value as KotaModel;
                        FocusScope.of(context).unfocus();
                        // _getCity(selectedProvince!.id!);
                        // selectedCity = null;
                        // selectedDistrict = null;
                      },
                    )
                  ],
                ),
              ),
              const SizedBox(height: 10,),
              SizedBox(
                width: MediaQuery.of(context).size.width,
                child: ElevatedButton(
                  onPressed: (){
                    save();
                  },
                  style: ElevatedButton.styleFrom(
                    primary: primaryColor
                  ),
                  child: const Text(
                    'Simpan'
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
