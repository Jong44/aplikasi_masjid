import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ffi';
import 'dart:io';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_svg/parser.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:marquee/marquee.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'commons.dart';
import 'info_state_model.dart';
import 'jadwal_model.dart';

void main() async{
  runApp(MyApp());
}
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        },
        child: MaterialApp(
            title: 'Flutter Android TV',
            theme: ThemeData(
              primarySwatch: Colors.blue,
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
            debugShowCheckedModeBanner: false,
            home: const MyHomePage()));
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key,}) : super(key: key);


  @override
  State<MyHomePage> createState() => _MyHomePageState();

}

class _MyHomePageState extends State<MyHomePage>  with TickerProviderStateMixin{

  String? _timeString;
  String? _mDateString;
  String? _hDateString;
  String? jadwal;
  var hijriyah = HijriCalendar.now();
  final GlobalKey _listKey = GlobalKey();
  var adzan = Jadwal();
  final fDatabase = FirebaseDatabase.instance;
  var state = InfoStateModel(
    namaMasjid: 'Masjid Al Aqsho',
    alamat: 'Banguntapan, Yogyakarta',
    phone: '081234567890',
    idKota: '1501',
  );
  bool showTime = false;
  bool iqomah = false;
  Timer? iqomahCountDown;
  Timer? adzCountDown;
  String? adzanNow;
  String? titleAdzanNow;
  IconData? iconData;
  String? titleAdzanNowMini;
  Duration endCountDown = const Duration(minutes: 10);
  Duration adzanCountDown = const Duration(minutes: 10);

  @override
  void initState(){
    super.initState();


    initializeDateFormatting('id_ID');
    init();
    _timeString = _formatDateTime(DateTime.now());
    _mDateString = _formatMDate(DateTime.now());
    _hDateString = _formatHDate(hijriyah);
    getData();
    Timer.periodic(const Duration(seconds: 1), (Timer t) => _getTime());
  }




  void init()async{
    await Firebase.initializeApp();
  }


  Future<void> getData()async{
    await Future.wait([
      setCityId(),
      getJadwalAdzan(),
      if (jadwal != null)getJadwal( ),
    ]);
  }

  Future<void> setCityId() async {
    var pref = await SharedPreferences.getInstance();
    var city = await fDatabase.reference().child('setting').child('cityId').once();
    await pref.setString('cityId', city.value);
  }

  Future<void> getJadwalAdzan() async {
    var pref = await SharedPreferences.getInstance();
    var city = await fDatabase.reference().child('setting').child('cityId').once();
    print('https://api.myquran.com/v1/sholat/jadwal/${city.value ?? '1501'}/${DateTime.now().year}/${DateTime.now().month}');
    var url = Uri.parse('https://api.myquran.com/v1/sholat/jadwal/${city.value ?? '1501'}/${DateTime.now().year}/${DateTime.now().month}');
    var response = await http.get(url,);
    if (response.statusCode == 200){
      print(response.body);
      await pref.setString('jadwal', jsonEncode(jsonDecode(response.body)['data']));
      getJadwal();
    }else{
      throw Exception('Failed to load movie');
    }
  }

  Future<void> getJadwal()async{
    var pref = await SharedPreferences.getInstance();
    jadwal = pref.getString('jadwal');
    JadwalModel time = JadwalModel.fromJson(jsonDecode(jadwal!));
    var data = time.jadwal?.where((element) => element.date! == DateFormat('yyyy-MM-dd').format(DateTime.now())).toList();
    setState(() {
      adzan = data![0];
    });
  }


  void _getTime()async {
    var pref = await SharedPreferences.getInstance();
    final DateTime now = DateTime.now();
    final String formattedDateTime = _formatDateTime(now);
    final String formattedMDate = _formatMDate(now);
    final String formattedHDate = _formatHDate(hijriyah);
    int lastday = DateTime(now.year, now.month + 1, 0).day;
    String? cityId = pref.getString('cityId');
    var city = await fDatabase.reference().child('setting').child('cityId').once();
    if (city.value != cityId){
      getJadwalAdzan();
      setCityId();
    }
    if (DateFormat('HH:mm').format(now) == '23:59:59'){
      getJadwal();
    }
    if (now.day == lastday){
      getJadwalAdzan();
    }
    adzanTime();
    changeTitle();
    setState(() {
      _timeString = formattedDateTime;
      _mDateString = formattedMDate;
      _hDateString = formattedHDate;
    });
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  String _formatMDate(DateTime dateTime) {
    return DateFormat('EEEE, dd MMMM yyyy','id_ID').format(dateTime);
  }

  String _formatHDate(HijriCalendar dateTime) {
    return dateTime.toFormat('dd MMMM yyyy H');
  }

  List<String> lists = [];
  List<String> information = [];


  void startIqomah(){
    setState(() {
      iqomah = true;
      endCountDown = const Duration(minutes: 10);
    });
    Future.delayed(const Duration(seconds: 1)).then((value) {
      iqomahCountDown = Timer.periodic(const Duration(seconds: 1), (timer)async {
        setState(() {
          endCountDown -= const Duration(seconds: 1);
        });
        if (endCountDown.inMinutes % 60 == 0 && endCountDown.inSeconds % 60 == 0){
          Future.delayed(const Duration(seconds: 1)).then((value) {
            setState(() {
              iqomah = false;
              iqomahCountDown!.cancel();
              endCountDown = const Duration(seconds: 0,minutes: 0);
              AssetsAudioPlayer.newPlayer().dispose();
            });
          });
        }
        if (endCountDown.inMinutes % 60 == 0 && endCountDown.inSeconds % 60 == 0){
          AssetsAudioPlayer.newPlayer().open(
            Audio("assets/beep-3.mp3"),
            autoStart: true,
            showNotification: true,
          );
        }
        if (endCountDown.inMinutes % 60 == 0 && endCountDown.inSeconds % 60 == 0){
          AssetsAudioPlayer.newPlayer().open(
            Audio("assets/last-beep.wav"),
            autoStart: true,
            showNotification: true,
          );
          Future.delayed(const Duration(minutes: 15)).then((value){
            setState(() {
              showTime = false;
            });
          });
        }
      });
    });
  }

  String doubleDigitParse(int digit){
    if (digit < 10){
      return '0$digit';
    }else{
      return '$digit';
    }
  }

  String? waktu;
  void adzanTime(){
    final DateTime now = DateTime.now();
    if (DateFormat('HH:mm').format(now) == '${doubleDigitParse(DateFormat('HH:mm').parse(adzan.subuh!).hour)}:${DateFormat('HH:mm').parse(adzan.subuh!).minute - 10}'){
      setState(() {
        showTime = true;
        adzanNow = adzan.subuh;
        titleAdzanNowMini = 'Shubuh';
        titleAdzanNow = 'Memasuki Waktu Sholat';
        iconData = CupertinoIcons.sunrise_fill;
        if (now.second == 0){
          hideTime();
        }
      });
    }else if (DateFormat('HH:mm').format(now) == '${DateFormat('HH:mm').parse(adzan.ashar!).hour}:${DateFormat('HH:mm').parse(adzan.ashar!).minute - 10}'){
      setState(() {
        showTime = true;
        adzanNow = adzan.dzuhur;
        titleAdzanNowMini = 'Dhuhur';
        titleAdzanNow = 'Memasuki Waktu Dhuhur';
        iconData = Icons.sunny;
        if (now.second == 0){
          hideTime();
        }
      });
    }else if (DateFormat('HH:mm').format(now) == '${DateFormat('HH:mm').parse(adzan.ashar!).hour}:${DateFormat('HH:mm').parse(adzan.ashar!).minute - 10}'){
      setState(() {
        showTime = true;
        adzanNow = adzan.ashar;
        titleAdzanNowMini = 'Ashar';
        titleAdzanNow = 'Memasuki Waktu Ashar';
        iconData = CupertinoIcons.sunset_fill;
        if (now.second == 0){
          hideTime();
        }
      });
    }else {
      if (DateFormat('HH:mm').format(now) == '${DateFormat('HH:mm').parse(adzan.maghrib!).hour}:${DateFormat('HH:mm').parse(adzan.maghrib!).minute - 10}'){
      setState(() {
        showTime = true;
        adzanNow = adzan.maghrib;
        titleAdzanNowMini = 'Maghrib';
        titleAdzanNow = 'Memasuki Waktu Maghrib';
        iconData = CupertinoIcons.moon_fill;
        if (now.second == 0){
          hideTime();
        }
      });
    }else if (DateFormat('HH:mm').format(now) == '${DateFormat('HH:mm').parse(adzan.isya!).hour}:${DateFormat('HH:mm').parse(adzan.isya!).minute - 10}'){
      setState(() {
        showTime = true;
        adzanNow = adzan.isya;
        titleAdzanNowMini = 'Isya';
        titleAdzanNow = 'Memasuki Waktu Isya';
        iconData = CupertinoIcons.moon_stars_fill;
        if (now.second == 0){
          hideTime();
        }
      });
    }
    }
  }

  void changeTitle(){
    final DateTime now = DateTime.now();
    if (DateFormat('HH:mm').format(now) == '${doubleDigitParse(DateFormat('HH:mm').parse(adzan.subuh!).hour)}:${doubleDigitParse(DateFormat('HH:mm').parse(adzan.subuh!).minute)}'){
      setState(() {
        titleAdzanNow = 'Sedang Waktu Sholat';
      });
    }else if (DateFormat('HH:mm').format(now) == '${doubleDigitParse(DateFormat('HH:mm').parse(adzan.dzuhur!).hour)}:${doubleDigitParse(DateFormat('HH:mm').parse(adzan.dzuhur!).minute)}'){
      setState(() {
        titleAdzanNow = 'Sedang Waktu Sholat';
      });
    }else if (DateFormat('HH:mm').format(now) == '${doubleDigitParse(DateFormat('HH:mm').parse(adzan.ashar!).hour)}:${doubleDigitParse(DateFormat('HH:mm').parse(adzan.ashar!).minute)}'){
      setState(() {
        titleAdzanNow = 'Sedang Waktu Sholat';
      });
    }else if (DateFormat('HH:mm').format(now) == '${doubleDigitParse(DateFormat('HH:mm').parse(adzan.maghrib!).hour)}:${doubleDigitParse(DateFormat('HH:mm').parse(adzan.maghrib!).minute)}'){
      setState(() {
        titleAdzanNow = 'Sedang Waktu Sholat';
      });
    }else if (DateFormat('HH:mm').format(now) == '${doubleDigitParse(DateFormat('HH:mm').parse(adzan.isya!).hour)}:${doubleDigitParse(DateFormat('HH:mm').parse(adzan.isya!).minute)}'){
      setState(() {
        titleAdzanNow = 'Sedang Waktu Sholat';
      });
    }
  }

  void hideTime(){
    Future.delayed(const Duration(minutes: 10)).then((value){
      startIqomah();
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xfff8f1e5),
      body: true?SafeArea(
        child: Stack(
          children: [
            Stack(
              children: [
                // CarouselSlider(items: [
                //
                // ],
                //     options: CarouselOptions(
                //       autoPlay: true,
                //       autoPlayInterval: const Duration(minutes: 1),
                //       autoPlayAnimationDuration: Duration(seconds: 10),
                //       enableInfiniteScroll: true,
                //     )),
                // FutureBuilder(
                //     future: fDatabase.reference().child('setting').child('background').once(),
                //     builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
                //       if (snapshot.hasError)return const Text('Empty');
                //       if (snapshot.hasData) {
                //         if (snapshot.data!.value != null){
                //           String? bg = snapshot.data!.value;
                //           return bg != null?Image.asset('assets/bg-1.jpg',fit: BoxFit.cover,width: MediaQuery.of(context).size.width,):Image.asset('assets/bg-1.jpg',fit: BoxFit.cover,width: MediaQuery.of(context).size.width,);
                //         }
                //       }
                //       return const SizedBox();
                //     }),
                Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                ),
              ],
            ),
            Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.only(right: 5, top: 20, bottom: 15 ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            margin: EdgeInsets.only(right: 30, left: 20),
                            decoration: BoxDecoration(
                                color: Color.fromRGBO(217, 217, 217, 1),
                                borderRadius: BorderRadius.circular(25),
                                boxShadow:[
                                  BoxShadow(
                                    color: Color.fromRGBO(36, 35, 35, 100),
                                    spreadRadius: 2,
                                    blurRadius: 7,
                                    offset: Offset(0,0),
                                  )]
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 14),
                            child: Row(
                              children: [
                                 Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FutureBuilder(
                                        future: fDatabase.reference().child('setting').child('name').once(),
                                        builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
                                          if (snapshot.hasError)return const Text('Empty');
                                          if (snapshot.hasData) {
                                            if (snapshot.data!.value != null){
                                              String? nama = snapshot.data!.value;
                                              return Text(
                                                nama ?? '-',
                                                maxLines: 1,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 23,
                                                    fontWeight: FontWeight.bold
                                                ),
                                              );
                                            }
                                          }
                                          return const SizedBox();
                                        }),
                                    // FutureBuilder(
                                    //     future: fDatabase.reference().child('setting').child('address').once(),
                                    //     builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
                                    //       if (snapshot.hasError)return const Text('Empty');
                                    //       if (snapshot.hasData) {
                                    //         if (snapshot.data!.value != null){
                                    //           String? address = snapshot.data!.value;
                                    //           return SizedBox(
                                    //             width: MediaQuery.of(context).size.width * .35,
                                    //             child: Text(
                                    //               address ?? '-',
                                    //               maxLines: 2,
                                    //               style: const TextStyle(
                                    //                   color: Colors.black,
                                    //                   fontSize: 12,
                                    //                   fontWeight: FontWeight.w400
                                    //               ),
                                    //             ),
                                    //           );
                                    //         }
                                    //       }
                                    //       return const SizedBox();
                                    //     }),
                                  ],
                                ),

                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: EdgeInsets.only(right: 30),
                                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 14),
                                decoration: BoxDecoration(
                                    color: Color.fromRGBO(217, 217, 217, 1),
                                    borderRadius: BorderRadius.circular(25),
                                    boxShadow:[
                                      BoxShadow(
                                        color: Color.fromRGBO(36, 35, 35, 100),
                                        spreadRadius: 2,
                                        blurRadius: 7,
                                        offset: Offset(0,0),
                                      )
                                    ]
                                ),
                                child: Text(
                                  _mDateString! ,
                                  style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 23,
                                      fontWeight: FontWeight.w700
                                  ),
                                ),
                              )
                            ],
                          ),


                          Column(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                                decoration: BoxDecoration(
                                    color: Color.fromRGBO(217, 217, 217, 1),
                                    borderRadius: BorderRadius.circular(25),
                                    boxShadow:[
                                      BoxShadow(
                                        color: Color.fromRGBO(36, 35, 35, 100),
                                        spreadRadius: 2,
                                        blurRadius: 7,
                                        offset: Offset(0,0),
                                      )
                                    ]
                                ),
                                child:
                                Text(
                                  _timeString! + " WIB",
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 23,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                    FutureBuilder(
                        future: fDatabase.reference().child('image').once(),
                        builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
                          if (snapshot.hasError)return const Text('error');
                          if (snapshot.hasData) {
                            lists.clear();
                            if (snapshot.data!.value != null){
                              Map<dynamic, dynamic> values = snapshot.data!.value;
                              values.forEach((key, values) {
                                lists.add(values);
                              });
                              return

                                Container(
                                    height: 400,
                                    decoration: BoxDecoration(
                                        color: Colors.transparent
                                    ),
                                    child: Row(
                                      children: [
                                        Column(

                                          children: [
                                            Container(
                                                alignment: Alignment.centerLeft,
                                                width: 380,
                                                padding: EdgeInsets.symmetric(horizontal: 20),
                                                decoration: BoxDecoration(
                                                    color: Colors.transparent
                                                ),
                                                child: Column(
                                                    children: [

                                                      showTime? iqomah? Container(
                                                          width:350,
                                                          height: 150,
                                                          padding: EdgeInsets.symmetric(horizontal: 20),
                                                          decoration: BoxDecoration(
                                                            color: Color(0xff704d37),
                                                            borderRadius: BorderRadius.circular(20),
                                                          ),
                                                          child: Row(
                                                            children:
                                                            [
                                                              Image.asset('assets/logo.png',scale: 45,),
                                                              Container(
                                                                margin: EdgeInsets.only(left: 20),
                                                                child: Column(
                                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    Row(
                                                                      children: [
                                                                        Icon(iconData!, size: 30,color: Colors.white, ),
                                                                        Container(
                                                                            margin: EdgeInsets.only(left: 15),
                                                                            child:
                                                                            Text(
                                                                              '${doubleDigitParse(endCountDown.inMinutes % 60)}:${doubleDigitParse(endCountDown.inSeconds % 60)}'.substring(1,5),
                                                                              style: TextStyle(
                                                                                  color: Colors.white,
                                                                                  fontSize: 30,
                                                                                  fontWeight: FontWeight.bold
                                                                              ),
                                                                            )
                                                                        )
                                                                      ],
                                                                    ),
                                                                    Container(
                                                                      margin: EdgeInsets.only(top: 5, bottom: 5),
                                                                      child: const Text(
                                                                        'Menuju Waktu Iqomah',
                                                                        maxLines: 2,
                                                                        style: TextStyle(
                                                                            color: Colors.white,
                                                                            fontWeight: FontWeight.w400,
                                                                            fontSize: 18),
                                                                      ),
                                                                    ),

                                                                    Text(
                                                                      titleAdzanNowMini!,
                                                                      style: TextStyle(
                                                                          color: Colors.white,
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 18
                                                                      ),
                                                                    )
                                                                  ],
                                                                ),
                                                              )
                                                            ],
                                                          )
                                                      )
                                                          :AnimatedContainer(
                                                          width:350,
                                                          height: 150,
                                                          padding: EdgeInsets.symmetric(horizontal: 20),
                                                          decoration: BoxDecoration(
                                                            color: Color.fromRGBO(163,130,108, 40),
                                                            borderRadius: BorderRadius.circular(20),
                                                          ),
                                                          duration: Duration(seconds: 2),
                                                          curve: Curves.fastOutSlowIn,
                                                          child: Row(
                                                            children: [
                                                              Image.asset('assets/logo.png',scale: 45,),
                                                              Container(
                                                                margin: EdgeInsets.only(left: 20),
                                                                child: Column(
                                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    Row(
                                                                      crossAxisAlignment: CrossAxisAlignment.center,
                                                                      children: [
                                                                        Icon(iconData!, size: 30,  color: Colors.white,),
                                                                        Container(
                                                                            margin: EdgeInsets.only(left: 15),
                                                                            child:
                                                                            Text(
                                                                              adzanNow!,
                                                                              style: TextStyle(
                                                                                  color: Colors.white,
                                                                                  fontSize: 30,
                                                                                  fontWeight: FontWeight.bold
                                                                              ),
                                                                            )
                                                                        )
                                                                      ],
                                                                    ),
                                                                    Container(
                                                                      margin: EdgeInsets.only(top: 5, bottom: 5),
                                                                      child: Text(
                                                                        titleAdzanNow ?? '-',
                                                                        style: const TextStyle(
                                                                            color: Colors.white,
                                                                            fontWeight: FontWeight.w400,
                                                                            fontSize: 18),
                                                                      ),
                                                                    ),

                                                                    Text(
                                                                      titleAdzanNowMini!,
                                                                      style: TextStyle(
                                                                          color: Colors.white,
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 18
                                                                      ),
                                                                    )
                                                                  ],
                                                                ),
                                                              )
                                                            ],
                                                          )
                                                      ) : Column(
                                                        children: [
                                                          Container(
                                                            width: 350,
                                                            padding: EdgeInsets.symmetric(vertical: 5),
                                                            decoration: BoxDecoration(
                                                                color: Color.fromRGBO(163,130,108, 40),
                                                                borderRadius: BorderRadius.circular(20)
                                                            ),
                                                            child: Text(
                                                              "Jadwal Sholat",
                                                              style: TextStyle(
                                                                  fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold
                                                              ),
                                                              textAlign: TextAlign.center,
                                                            ),
                                                          ),
                                                          Row(
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              children:[
                                                                Container(
                                                                  margin: EdgeInsets.only(top: 17, right: 10, bottom: 17),
                                                                  width: 88,
                                                                  decoration: BoxDecoration(
                                                                      border: Border(
                                                                          top: BorderSide(
                                                                              color: Color(0xff979797),
                                                                              width: 1
                                                                          )

                                                                      )
                                                                  ),
                                                                ),
                                                                Container(
                                                                  margin: EdgeInsets.only(top: 15, bottom: 12),
                                                                  child: Text(
                                                                    _hDateString != null?'$_hDateString':'',
                                                                    textAlign: TextAlign.end,
                                                                    style: const TextStyle(
                                                                      color: Color(0xff8B5D5D),
                                                                      fontSize: 15,
                                                                      fontWeight: FontWeight.w700,
                                                                    ),
                                                                  ),
                                                                ),
                                                                Container(
                                                                  margin: EdgeInsets.only(top: 17, left: 10, bottom: 17),
                                                                  width: 88,
                                                                  decoration: BoxDecoration(
                                                                      border: Border(
                                                                          top: BorderSide(
                                                                              color: Color(0xff979797),
                                                                              width: 1
                                                                          )

                                                                      )
                                                                  ),
                                                                ),
                                                              ]
                                                          ),

                                                        ],
                                                      ),
                                                      if (showTime && titleAdzanNowMini == "Shubuh" )  Column(
                                                          children: [
                                                            Container(
                                                              width: 350,
                                                              margin: EdgeInsets.only(top: 15),
                                                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                              decoration: BoxDecoration(
                                                                  color: Color.fromRGBO(189,158,138, 100),
                                                                  borderRadius: BorderRadius.circular(20)
                                                              ),
                                                              child: Row(
                                                                children: [
                                                                  Container(
                                                                    child: Icon(
                                                                      Icons.sunny,color: Color(0xff8B5D5D),
                                                                    ),
                                                                  ),
                                                                  Container(
                                                                    margin: EdgeInsets.only(left: 10, right: 109),
                                                                    child: const Text(
                                                                      'Dhuhur',
                                                                      style: TextStyle(
                                                                          color: Color(0xff8B5D5D),
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 20),
                                                                    ),
                                                                  ),
                                                                  Container(
                                                                    child: Text(
                                                                      adzan.dzuhur ?? '-',
                                                                      style: const TextStyle(
                                                                          color: Color(0xff8B5D5D),
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 20),
                                                                    ),
                                                                  )
                                                                ],
                                                              ),
                                                            ),

                                                            Container(
                                                              width: 350,
                                                              margin: EdgeInsets.only(top: 15),
                                                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                              decoration: BoxDecoration(
                                                                  color: Color.fromRGBO(189,158,138, 100),
                                                                  borderRadius: BorderRadius.circular(20)
                                                              ),
                                                              child: Row(
                                                                children: [
                                                                  Container(
                                                                    child: Icon(
                                                                      CupertinoIcons.sunset_fill,color: Color(0xff8B5D5D),
                                                                    ),
                                                                  ),
                                                                  Container(
                                                                    margin: EdgeInsets.only(left: 10, right: 121),
                                                                    child: const Text(
                                                                      'Ashar',
                                                                      style: TextStyle(
                                                                          color: Color(0xff8B5D5D),
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 20),
                                                                    ),
                                                                  ),
                                                                  Container(
                                                                    child: Text(
                                                                      adzan.ashar ?? '-',
                                                                      style: const TextStyle(
                                                                          color: Color(0xff8B5D5D),
                                                                          fontWeight: FontWeight.w700,
                                                                          fontSize: 20),
                                                                    ),
                                                                  )
                                                                ],
                                                              ),
                                                            ),

                                                            Container(
                                                              width: 350,
                                                              margin: EdgeInsets.only(top: 15),
                                                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                              decoration: BoxDecoration(
                                                                  color: Color.fromRGBO(189,158,138, 100),
                                                                  borderRadius: BorderRadius.circular(20)
                                                              ),
                                                              child: Row(
                                                                  children: [
                                                                    Container(
                                                                      child: Icon(
                                                                        CupertinoIcons.moon_fill,color: Color(0xff8B5D5D),
                                                                      ),
                                                                    ),
                                                                    Container(
                                                                      margin: EdgeInsets.only(left: 10, right: 100),
                                                                      child: const Text(
                                                                        'Maghrib',
                                                                        style: TextStyle(
                                                                            color: Color(0xff8B5D5D),
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 20),
                                                                      ),
                                                                    ),
                                                                    Container(
                                                                      child: Text(
                                                                        adzan.maghrib ?? '-',
                                                                        style: const TextStyle(
                                                                            color: Color(0xff8B5D5D),
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 20),
                                                                      ),
                                                                    ),
                                                                  ]
                                                              ),
                                                            ),

                                                            Container(
                                                              width: 350,
                                                              margin: EdgeInsets.only(top: 15),
                                                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                              decoration: BoxDecoration(
                                                                  color: Color.fromRGBO(189,158,138, 100),
                                                                  borderRadius: BorderRadius.circular(20)
                                                              ),
                                                              child: Row(
                                                                children: [
                                                                  Container(
                                                                    child: Icon(
                                                                      CupertinoIcons.moon_stars_fill,color: Color(0xff8B5D5D),
                                                                    ),
                                                                  ),
                                                                  Container(
                                                                    margin: EdgeInsets.only(left: 10, right: 140),
                                                                    child: const Text(
                                                                      'Isya',
                                                                      style: TextStyle(
                                                                          color: Color(0xff8B5D5D),
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 20),
                                                                    ),
                                                                  ),
                                                                  Container(
                                                                    child: Text(
                                                                      adzan.isya ?? '-',
                                                                      style: const TextStyle(
                                                                          color: Color(0xff8B5D5D),
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 20),
                                                                    ),
                                                                  ),

                                                                ],
                                                              ),
                                                            ),
                                                          ]
                                                      ) else if(showTime && titleAdzanNowMini == "Dhuhur" ) Column(
                                                          children: [
                                                            Container(
                                                              width: 350,
                                                              margin: EdgeInsets.only(top: 15),
                                                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                              decoration: BoxDecoration(
                                                                  color: Color.fromRGBO(189,158,138, 100),
                                                                  borderRadius: BorderRadius.circular(20)
                                                              ),
                                                              child: Row(
                                                                children: [
                                                                  Container(
                                                                    child: Icon(
                                                                      CupertinoIcons.sunset_fill,color: Color(0xff8B5D5D),
                                                                    ),
                                                                  ),
                                                                  Container(
                                                                    margin: EdgeInsets.only(left: 10, right: 121),
                                                                    child: const Text(
                                                                      'Ashar',
                                                                      style: TextStyle(
                                                                          color: Color(0xff8B5D5D),
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 20),
                                                                    ),
                                                                  ),
                                                                  Container(
                                                                    child: Text(
                                                                      adzan.ashar ?? '-',
                                                                      style: const TextStyle(
                                                                          color: Color(0xff8B5D5D),
                                                                          fontWeight: FontWeight.w700,
                                                                          fontSize: 20),
                                                                    ),
                                                                  )
                                                                ],
                                                              ),
                                                            ),

                                                            Container(
                                                              width: 350,
                                                              margin: EdgeInsets.only(top: 15),
                                                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                              decoration: BoxDecoration(
                                                                  color: Color.fromRGBO(189,158,138, 100),
                                                                  borderRadius: BorderRadius.circular(20)
                                                              ),
                                                              child: Row(
                                                                children: [
                                                                  Container(
                                                                    child: Icon(
                                                                      CupertinoIcons.moon_fill,color: Color(0xff8B5D5D),
                                                                    ),
                                                                  ),
                                                                  Container(
                                                                    margin: EdgeInsets.only(left: 10, right: 100),
                                                                    child: const Text(
                                                                      'Maghrib',
                                                                      style: TextStyle(
                                                                          color: Color(0xff8B5D5D),
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 20),
                                                                    ),
                                                                  ),
                                                                  Container(
                                                                    child: Text(
                                                                      adzan.maghrib ?? '-',
                                                                      style: const TextStyle(
                                                                          color: Color(0xff8B5D5D),
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 20),
                                                                    ),
                                                                  ),

                                                                ],
                                                              ),
                                                            ),

                                                            Container(
                                                              width: 350,
                                                              margin: EdgeInsets.only(top: 15),
                                                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                              decoration: BoxDecoration(
                                                                  color: Color.fromRGBO(189,158,138, 100),
                                                                  borderRadius: BorderRadius.circular(20)
                                                              ),
                                                              child: Row(
                                                                children: [
                                                                  Container(
                                                                    child: Icon(
                                                                      CupertinoIcons.moon_stars_fill,color: Color(0xff8B5D5D),
                                                                    ),
                                                                  ),
                                                                  Container(
                                                                    margin: EdgeInsets.only(left: 10, right: 140),
                                                                    child: const Text(
                                                                      'Isya',
                                                                      style: TextStyle(
                                                                          color: Color(0xff8B5D5D),
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 20),
                                                                    ),
                                                                  ),
                                                                  Container(
                                                                    child: Text(
                                                                      adzan.isya ?? '-',
                                                                      style: const TextStyle(
                                                                          color: Color(0xff8B5D5D),
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 20),
                                                                    ),
                                                                  ),

                                                                ],
                                                              ),
                                                            ),

                                                            Container(
                                                              width: 350,
                                                              margin: EdgeInsets.only(top: 15),
                                                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                              decoration: BoxDecoration(
                                                                  color: Color.fromRGBO(189,158,138, 100),
                                                                  borderRadius: BorderRadius.circular(20)
                                                              ),
                                                              child: Row(
                                                                children: [
                                                                  Container(
                                                                    child: Icon(
                                                                      Icons.sunny_snowing,color: Color(0xff8B5D5D),
                                                                    ),
                                                                  ),
                                                                  Container(
                                                                    margin: EdgeInsets.only(left: 10, right: 105),
                                                                    child: const Text(
                                                                      'Shubuh',
                                                                      style: TextStyle(
                                                                          color: Color(0xff8B5D5D),
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 20),
                                                                    ),
                                                                  ),
                                                                  Container(
                                                                    child: Text(
                                                                      adzan.subuh ?? '-',
                                                                      style: const TextStyle(
                                                                          color: Color(0xff8B5D5D),
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 20),
                                                                    ),
                                                                  )
                                                                ],
                                                              ),
                                                            ),
                                                          ]
                                                      )
                                                      else if(showTime && titleAdzanNowMini == "Ashar" ) Column(
                                                            children: [
                                                              Container(
                                                                width: 350,
                                                                margin: EdgeInsets.only(top: 15),
                                                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                                decoration: BoxDecoration(
                                                                    color: Color.fromRGBO(189,158,138, 100),
                                                                    borderRadius: BorderRadius.circular(20)
                                                                ),
                                                                child: Row(
                                                                  children: [
                                                                    Container(
                                                                      child: Icon(
                                                                        CupertinoIcons.moon_fill,color: Color(0xff8B5D5D),
                                                                      ),
                                                                    ),
                                                                    Container(
                                                                      margin: EdgeInsets.only(left: 10, right: 100),
                                                                      child: const Text(
                                                                        'Maghrib',
                                                                        style: TextStyle(
                                                                            color: Color(0xff8B5D5D),
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 20),
                                                                      ),
                                                                    ),
                                                                    Container(
                                                                      child: Text(
                                                                        adzan.maghrib ?? '-',
                                                                        style: const TextStyle(
                                                                            color: Color(0xff8B5D5D),
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 20),
                                                                      ),
                                                                    ),

                                                                  ],
                                                                ),
                                                              ),

                                                              Container(
                                                                width: 350,
                                                                margin: EdgeInsets.only(top: 15),
                                                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                                decoration: BoxDecoration(
                                                                    color: Color.fromRGBO(189,158,138, 100),
                                                                    borderRadius: BorderRadius.circular(20)
                                                                ),
                                                                child: Row(
                                                                  children: [
                                                                    Container(
                                                                      child: Icon(
                                                                        CupertinoIcons.moon_stars_fill,color: Color(0xff8B5D5D),
                                                                      ),
                                                                    ),
                                                                    Container(
                                                                      margin: EdgeInsets.only(left: 10, right: 140),
                                                                      child: const Text(
                                                                        'Isya',
                                                                        style: TextStyle(
                                                                            color: Color(0xff8B5D5D),
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 20),
                                                                      ),
                                                                    ),
                                                                    Container(
                                                                      child: Text(
                                                                        adzan.isya ?? '-',
                                                                        style: const TextStyle(
                                                                            color: Color(0xff8B5D5D),
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 20),
                                                                      ),
                                                                    ),

                                                                  ],
                                                                ),
                                                              ),

                                                              Container(
                                                                width: 350,
                                                                margin: EdgeInsets.only(top: 15),
                                                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                                decoration: BoxDecoration(
                                                                    color: Color.fromRGBO(189,158,138, 100),
                                                                    borderRadius: BorderRadius.circular(20)
                                                                ),
                                                                child: Row(
                                                                  children: [
                                                                    Container(
                                                                      child: Icon(
                                                                        Icons.sunny_snowing,color: Color(0xff8B5D5D),
                                                                      ),
                                                                    ),
                                                                    Container(
                                                                      margin: EdgeInsets.only(left: 10, right: 105),
                                                                      child: const Text(
                                                                        'Shubuh',
                                                                        style: TextStyle(
                                                                            color: Color(0xff8B5D5D),
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 20),
                                                                      ),
                                                                    ),
                                                                    Container(
                                                                      child: Text(
                                                                        adzan.subuh ?? '-',
                                                                        style: const TextStyle(
                                                                            color: Color(0xff8B5D5D),
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 20),
                                                                      ),
                                                                    )
                                                                  ],
                                                                ),
                                                              ),

                                                              Container(
                                                                width: 350,
                                                                margin: EdgeInsets.only(top: 15),
                                                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                                decoration: BoxDecoration(
                                                                    color: Color.fromRGBO(189,158,138, 100),
                                                                    borderRadius: BorderRadius.circular(20)
                                                                ),
                                                                child: Row(
                                                                  children: [
                                                                    Container(
                                                                      child: Icon(
                                                                        Icons.sunny,color: Color(0xff8B5D5D),
                                                                      ),
                                                                    ),
                                                                    Container(
                                                                      margin: EdgeInsets.only(left: 10, right: 109),
                                                                      child: const Text(
                                                                        'Dzuhur',
                                                                        style: TextStyle(
                                                                            color: Color(0xff8B5D5D),
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 20),
                                                                      ),
                                                                    ),
                                                                    Container(
                                                                      child: Text(
                                                                        adzan.dzuhur ?? '-',
                                                                        style: const TextStyle(
                                                                            color: Color(0xff8B5D5D),
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 20),
                                                                      ),
                                                                    )
                                                                  ],
                                                                ),
                                                              ),
                                                            ]
                                                        )
                                                        else if(showTime && titleAdzanNowMini == "Maghrib" ) Column(
                                                              children: [
                                                                Container(
                                                                  width: 350,
                                                                  margin: EdgeInsets.only(top: 15),
                                                                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                                  decoration: BoxDecoration(
                                                                      color: Color.fromRGBO(189,158,138, 100),
                                                                      borderRadius: BorderRadius.circular(20)
                                                                  ),
                                                                  child: Row(
                                                                    children: [
                                                                      Container(
                                                                        child: Icon(
                                                                          CupertinoIcons.moon_stars_fill,color: Color(0xff8B5D5D),
                                                                        ),
                                                                      ),
                                                                      Container(
                                                                        margin: EdgeInsets.only(left: 10, right: 140),
                                                                        child: const Text(
                                                                          'Isya',
                                                                          style: TextStyle(
                                                                              color: Color(0xff8B5D5D),
                                                                              fontWeight: FontWeight.bold,
                                                                              fontSize: 20),
                                                                        ),
                                                                      ),
                                                                      Container(
                                                                        child: Text(
                                                                          adzan.isya ?? '-',
                                                                          style: const TextStyle(
                                                                              color: Color(0xff8B5D5D),
                                                                              fontWeight: FontWeight.bold,
                                                                              fontSize: 20),
                                                                        ),
                                                                      ),

                                                                    ],
                                                                  ),
                                                                ),

                                                                Container(
                                                                  width: 350,
                                                                  margin: EdgeInsets.only(top: 15),
                                                                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                                  decoration: BoxDecoration(
                                                                      color: Color.fromRGBO(189,158,138, 100),
                                                                      borderRadius: BorderRadius.circular(20)
                                                                  ),
                                                                  child: Row(
                                                                    children: [
                                                                      Container(
                                                                        child: Icon(
                                                                          Icons.sunny_snowing,color: Color(0xff8B5D5D),
                                                                        ),
                                                                      ),
                                                                      Container(
                                                                        margin: EdgeInsets.only(left: 10, right: 105),
                                                                        child: const Text(
                                                                          'Shubuh',
                                                                          style: TextStyle(
                                                                              color: Color(0xff8B5D5D),
                                                                              fontWeight: FontWeight.bold,
                                                                              fontSize: 20),
                                                                        ),
                                                                      ),
                                                                      Container(
                                                                        child: Text(
                                                                          adzan.subuh ?? '-',
                                                                          style: const TextStyle(
                                                                              color: Color(0xff8B5D5D),
                                                                              fontWeight: FontWeight.bold,
                                                                              fontSize: 20),
                                                                        ),
                                                                      )
                                                                    ],
                                                                  ),
                                                                ),

                                                                Container(
                                                                  width: 350,
                                                                  margin: EdgeInsets.only(top: 15),
                                                                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                                  decoration: BoxDecoration(
                                                                      color: Color.fromRGBO(189,158,138, 100),
                                                                      borderRadius: BorderRadius.circular(20)
                                                                  ),
                                                                  child: Row(
                                                                    children: [
                                                                      Container(
                                                                        child: Icon(
                                                                          Icons.sunny,color: Color(0xff8B5D5D),
                                                                        ),
                                                                      ),
                                                                      Container(
                                                                        margin: EdgeInsets.only(left: 10, right: 109),
                                                                        child: const Text(
                                                                          'Dzuhur',
                                                                          style: TextStyle(
                                                                              color: Color(0xff8B5D5D),
                                                                              fontWeight: FontWeight.bold,
                                                                              fontSize: 20),
                                                                        ),
                                                                      ),
                                                                      Container(
                                                                        child: Text(
                                                                          adzan.dzuhur ?? '-',
                                                                          style: const TextStyle(
                                                                              color: Color(0xff8B5D5D),
                                                                              fontWeight: FontWeight.bold,
                                                                              fontSize: 20),
                                                                        ),
                                                                      )
                                                                    ],
                                                                  ),
                                                                ),

                                                                Container(
                                                                  width: 350,
                                                                  margin: EdgeInsets.only(top: 15),
                                                                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                                  decoration: BoxDecoration(
                                                                      color: Color.fromRGBO(189,158,138, 100),
                                                                      borderRadius: BorderRadius.circular(20)
                                                                  ),
                                                                  child: Row(
                                                                    children: [
                                                                      Container(
                                                                        child: Icon(
                                                                          CupertinoIcons.sunset_fill,color: Color(0xff8B5D5D),
                                                                        ),
                                                                      ),
                                                                      Container(
                                                                        margin: EdgeInsets.only(left: 10, right: 121),
                                                                        child: const Text(
                                                                          'Ashar',
                                                                          style: TextStyle(
                                                                              color: Color(0xff8B5D5D),
                                                                              fontWeight: FontWeight.bold,
                                                                              fontSize: 20),
                                                                        ),
                                                                      ),
                                                                      Container(
                                                                        child: Text(
                                                                          adzan.ashar ?? '-',
                                                                          style: const TextStyle(
                                                                              color: Color(0xff8B5D5D),
                                                                              fontWeight: FontWeight.w700,
                                                                              fontSize: 20),
                                                                        ),
                                                                      )
                                                                    ],
                                                                  ),
                                                                ),
                                                              ]
                                                          )
                                                          else if(showTime && titleAdzanNowMini == "Isya" ) Column(
                                                                children: [
                                                                  Container(
                                                                    width: 350,
                                                                    margin: EdgeInsets.only(top: 15),
                                                                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                                    decoration: BoxDecoration(
                                                                        color: Color.fromRGBO(189,158,138, 100),
                                                                        borderRadius: BorderRadius.circular(20)
                                                                    ),
                                                                    child: Row(
                                                                      children: [
                                                                        Container(
                                                                          child: Icon(
                                                                            Icons.sunny_snowing,color: Color(0xff8B5D5D),
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          margin: EdgeInsets.only(left: 10, right: 105),
                                                                          child: const Text(
                                                                            'Shubuh',
                                                                            style: TextStyle(
                                                                                color: Color(0xff8B5D5D),
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 20),
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          child: Text(
                                                                            adzan.subuh ?? '-',
                                                                            style: const TextStyle(
                                                                                color: Color(0xff8B5D5D),
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 20),
                                                                          ),
                                                                        )
                                                                      ],
                                                                    ),
                                                                  ),

                                                                  Container(
                                                                    width: 350,
                                                                    margin: EdgeInsets.only(top: 15),
                                                                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                                    decoration: BoxDecoration(
                                                                        color: Color.fromRGBO(189,158,138, 100),
                                                                        borderRadius: BorderRadius.circular(20)
                                                                    ),
                                                                    child: Row(
                                                                      children: [
                                                                        Container(
                                                                          child: Icon(
                                                                            Icons.sunny,color: Color(0xff8B5D5D),
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          margin: EdgeInsets.only(left: 10, right: 109),
                                                                          child: const Text(
                                                                            'Dzuhur',
                                                                            style: TextStyle(
                                                                                color: Color(0xff8B5D5D),
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 20),
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          child: Text(
                                                                            adzan.dzuhur ?? '-',
                                                                            style: const TextStyle(
                                                                                color: Color(0xff8B5D5D),
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 20),
                                                                          ),
                                                                        )
                                                                      ],
                                                                    ),
                                                                  ),

                                                                  Container(
                                                                    width: 350,
                                                                    margin: EdgeInsets.only(top: 15),
                                                                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                                    decoration: BoxDecoration(
                                                                        color: Color.fromRGBO(189,158,138, 100),
                                                                        borderRadius: BorderRadius.circular(20)
                                                                    ),
                                                                    child: Row(
                                                                      children: [
                                                                        Container(
                                                                          child: Icon(
                                                                            CupertinoIcons.sunset_fill,color: Color(0xff8B5D5D),
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          margin: EdgeInsets.only(left: 10, right: 121),
                                                                          child: const Text(
                                                                            'Ashar',
                                                                            style: TextStyle(
                                                                                color: Color(0xff8B5D5D),
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 20),
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          child: Text(
                                                                            adzan.ashar ?? '-',
                                                                            style: const TextStyle(
                                                                                color: Color(0xff8B5D5D),
                                                                                fontWeight: FontWeight.w700,
                                                                                fontSize: 20),
                                                                          ),
                                                                        )
                                                                      ],
                                                                    ),
                                                                  ),

                                                                  Container(
                                                                    width: 350,
                                                                    margin: EdgeInsets.only(top: 15),
                                                                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                                    decoration: BoxDecoration(
                                                                        color: Color.fromRGBO(189,158,138, 100),
                                                                        borderRadius: BorderRadius.circular(20)
                                                                    ),
                                                                    child: Row(
                                                                      children: [
                                                                        Container(
                                                                          child: Icon(
                                                                            CupertinoIcons.moon_fill,color: Color(0xff8B5D5D),
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          margin: EdgeInsets.only(left: 10, right: 100),
                                                                          child: const Text(
                                                                            'Maghrib',
                                                                            style: TextStyle(
                                                                                color: Color(0xff8B5D5D),
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 20),
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          child: Text(
                                                                            adzan.maghrib ?? '-',
                                                                            style: const TextStyle(
                                                                                color: Color(0xff8B5D5D),
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 20),
                                                                          ),
                                                                        ),

                                                                      ],
                                                                    ),
                                                                  ),
                                                                ]
                                                            )










                                                            else Column(
                                                                children: [
                                                                  Container(
                                                                    width: 350,
                                                                    margin: EdgeInsets.only(top: 8),
                                                                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                                    decoration: BoxDecoration(
                                                                        color: Color.fromRGBO(189,158,138, 100),
                                                                        borderRadius: BorderRadius.circular(20)
                                                                    ),
                                                                    child: Row(
                                                                      children: [
                                                                        Container(
                                                                          child: Icon(
                                                                            Icons.sunny_snowing,color: Color(0xff8B5D5D),
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          margin: EdgeInsets.only(left: 10, right: 105),
                                                                          child: const Text(
                                                                            'Shubuh',
                                                                            style: TextStyle(
                                                                                color: Color(0xff8B5D5D),
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 20),
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          child: Text(
                                                                            adzan.subuh ?? '-',
                                                                            style: const TextStyle(
                                                                                color: Color(0xff8B5D5D),
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 20),
                                                                          ),
                                                                        )
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  Container(
                                                                    width: 350,
                                                                    margin: EdgeInsets.only(top: 15),
                                                                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                                    decoration: BoxDecoration(
                                                                        color: Color.fromRGBO(189,158,138, 100),
                                                                        borderRadius: BorderRadius.circular(20)
                                                                    ),
                                                                    child: Row(
                                                                      children: [
                                                                        Container(
                                                                          child: Icon(
                                                                            CupertinoIcons.sunrise_fill,color: Color(0xff8B5D5D),
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          margin: EdgeInsets.only(left: 10, right: 110),
                                                                          child: const Text(
                                                                            'Syuruq',
                                                                            style: TextStyle(
                                                                                color: Color(0xff8B5D5D),
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 20),
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          child: Text(
                                                                            adzan.terbit ?? '-',
                                                                            style: const TextStyle(
                                                                                color: Color(0xff8B5D5D),
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 20),
                                                                          ),
                                                                        )
                                                                      ],
                                                                    ),
                                                                  ),

                                                                  Container(
                                                                    width: 350,
                                                                    margin: EdgeInsets.only(top: 15),
                                                                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                                    decoration: BoxDecoration(
                                                                        color: Color.fromRGBO(189,158,138, 100),
                                                                        borderRadius: BorderRadius.circular(20)
                                                                    ),
                                                                    child: Row(
                                                                      children: [
                                                                        Container(
                                                                          child: Icon(
                                                                            Icons.sunny,color: Color(0xff8B5D5D),
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          margin: EdgeInsets.only(left: 10, right: 109),
                                                                          child: const Text(
                                                                            'Dzuhur',
                                                                            style: TextStyle(
                                                                                color: Color(0xff8B5D5D),
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 20),
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          child: Text(
                                                                            adzan.dzuhur ?? '-',
                                                                            style: const TextStyle(
                                                                                color: Color(0xff8B5D5D),
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 20),
                                                                          ),
                                                                        )
                                                                      ],
                                                                    ),
                                                                  ),

                                                                  Container(
                                                                    width: 350,
                                                                    margin: EdgeInsets.only(top: 15),
                                                                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                                    decoration: BoxDecoration(
                                                                        color: Color.fromRGBO(189,158,138, 100),
                                                                        borderRadius: BorderRadius.circular(20)
                                                                    ),
                                                                    child: Row(
                                                                      children: [
                                                                        Container(
                                                                          child: Icon(
                                                                            CupertinoIcons.sunset_fill,color: Color(0xff8B5D5D),
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          margin: EdgeInsets.only(left: 10, right: 121),
                                                                          child: const Text(
                                                                            'Ashar',
                                                                            style: TextStyle(
                                                                                color: Color(0xff8B5D5D),
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 20),
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          child: Text(
                                                                            adzan.ashar ?? '-',
                                                                            style: const TextStyle(
                                                                                color: Color(0xff8B5D5D),
                                                                                fontWeight: FontWeight.w700,
                                                                                fontSize: 20),
                                                                          ),
                                                                        )
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  Container(
                                                                    width: 350,
                                                                    margin: EdgeInsets.only(top: 15),
                                                                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                                    decoration: BoxDecoration(
                                                                        color: Color.fromRGBO(189,158,138, 100),
                                                                        borderRadius: BorderRadius.circular(20)
                                                                    ),
                                                                    child: Row(
                                                                      children: [
                                                                        Container(
                                                                          child: Icon(
                                                                            CupertinoIcons.moon_fill,color: Color(0xff8B5D5D),
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          margin: EdgeInsets.only(left: 10, right: 100),
                                                                          child: const Text(
                                                                            'Maghrib',
                                                                            style: TextStyle(
                                                                                color: Color(0xff8B5D5D),
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 20),
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          child: Text(
                                                                            adzan.maghrib ?? '-',
                                                                            style: const TextStyle(
                                                                                color: Color(0xff8B5D5D),
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 20),
                                                                          ),
                                                                        ),

                                                                      ],
                                                                    ),
                                                                  ),
                                                                  Container(
                                                                    width: 350,
                                                                    margin: EdgeInsets.only(top: 15),
                                                                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                                                    decoration: BoxDecoration(
                                                                        color: Color.fromRGBO(189,158,138, 100),
                                                                        borderRadius: BorderRadius.circular(20)
                                                                    ),
                                                                    child: Row(
                                                                      children: [
                                                                        Container(
                                                                          child: Icon(
                                                                            CupertinoIcons.moon_stars_fill,color: Color(0xff8B5D5D),
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          margin: EdgeInsets.only(left: 10, right: 140),
                                                                          child: const Text(
                                                                            'Isya',
                                                                            style: TextStyle(
                                                                                color: Color(0xff8B5D5D),
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 20),
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          child: Text(
                                                                            adzan.isya ?? '-',
                                                                            style: const TextStyle(
                                                                                color: Color(0xff8B5D5D),
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 20),
                                                                          ),
                                                                        ),

                                                                      ],
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                    ]
                                                )
                                            ),
                                          ],
                                        ),



                                        Column(
                                          children: [
                                            Container(
                                                height: 390,
                                                width: 560,
                                                padding: EdgeInsets.all(20),
                                                decoration: BoxDecoration(
                                                    color: Color.fromRGBO(163,130,108, 40),
                                                    borderRadius: BorderRadius.circular(20)
                                                ),
                                                child: Column(
                                                    children:[
                                                      Container(
                                                          alignment: Alignment.centerLeft,
                                                          child: Column(
                                                            children: [
                                                              Container(
                                                                  margin: EdgeInsets.only(top: 10),
                                                                  padding: EdgeInsets.symmetric(horizontal:20),
                                                                  child: Container(
                                                                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                                                                    decoration: BoxDecoration(
                                                                        color: Color(0x55ffd6a7),
                                                                        borderRadius: BorderRadius.circular(25)
                                                                    ),
                                                                    child: Row(
                                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                      children: [
                                                                        Icon(Icons.mosque,color: Colors.white,),
                                                                        // FutureBuilder(
                                                                        //     future: fDatabase.reference().child('setting').child('logo').once(),
                                                                        //     builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
                                                                        //       if (snapshot.hasError)return const Text('Empty');
                                                                        //       if (snapshot.hasData) {
                                                                        //         if (snapshot.data!.value != null){
                                                                        //           String? nama = snapshot.data!.value;
                                                                        //           return Image.network(nama ?? '',height: 40,);
                                                                        //         }
                                                                        //       }
                                                                        //       return const SizedBox();
                                                                        //     }),
                                                                        // const SizedBox(width: 15,),
                                                                        Text(
                                                                          "INFORMASI DARI TAKMIR MASJID",
                                                                          maxLines: 2,
                                                                          style: TextStyle(
                                                                            color: Color(0xff704d37),
                                                                            fontSize: 21,
                                                                            fontWeight: FontWeight.bold,
                                                                          ),
                                                                        ),
                                                                        Icon(Icons.mosque, color: Colors.white)
                                                                        // FutureBuilder(
                                                                        //     future: fDatabase.reference().child('setting').child('logo').once(),
                                                                        //     builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
                                                                        //       if (snapshot.hasError)return const Text('Empty');
                                                                        //       if (snapshot.hasData) {
                                                                        //         if (snapshot.data!.value != null){
                                                                        //           String? nama = snapshot.data!.value;
                                                                        //           return Image.network(nama ?? '',height: 40,);
                                                                        //         }
                                                                        //       }
                                                                        //       return const SizedBox();
                                                                        //     }),
                                                                        // const SizedBox(width: 20,),
                                                                      ],

                                                                    ),
                                                                  )
                                                              )
                                                            ],
                                                          )
                                                      ),
                                                      CarouselSlider(
                                                        options: CarouselOptions(
                                                            viewportFraction: 1 ,
                                                            height: MediaQuery.of(context).size.height * .5,
                                                            autoPlay: true,
                                                            aspectRatio: 1,
                                                            autoPlayInterval: const Duration(minutes: 1),
                                                            autoPlayAnimationDuration: const Duration(seconds: 10)
                                                        ),
                                                        items: lists.map((i) {
                                                          return Builder(
                                                            builder: (BuildContext context) {
                                                              return Container(
                                                                  width: MediaQuery.of(context).size.width,
                                                                  margin: EdgeInsets.only(top: 30),
                                                                  child: i.contains('http')?ClipRRect(
                                                                      borderRadius: BorderRadius.circular(10),
                                                                      child: Image.network(i,fit: BoxFit.cover,)):Column(
                                                                    children: [


                                                                      Container(
                                                                          padding: const EdgeInsets.symmetric(horizontal: 10,vertical: 16),
                                                                          height: MediaQuery.of(context).size.height * .36,
                                                                          child: Center(
                                                                            child :AutoSizeText(
                                                                              i,
                                                                              maxFontSize: 36,
                                                                              minFontSize: 24,
                                                                              textAlign:TextAlign.center,
                                                                              style: const TextStyle(
                                                                                color: Colors.white,
                                                                                fontSize: 25,
                                                                                fontFamily: 'RobotoMono',
                                                                                fontWeight: FontWeight.w600,
                                                                              ),
                                                                            ),)
                                                                      ),
                                                                    ],
                                                                  )
                                                              );
                                                            },
                                                          );
                                                        }).toList(),
                                                      ),
                                                    ]
                                                )

                                            )

                                          ],
                                        )
                                      ],
                                    )
                                );


                            }
                          }
                          return const SizedBox();
                        }),
                  ],
                )
                // Positioned(
                //   right: 16,
                //   left: 16,
                //   bottom: 55,
                //   child: Row(
                //     children: [
                //       Expanded(
                //         child: SizedBox(
                //           height:80,
                //           child: Column(
                //             crossAxisAlignment: CrossAxisAlignment.center,
                //             mainAxisAlignment: MainAxisAlignment.center,
                //
                //             children: [
                //               Text(
                //                 adzan.subuh ?? '-',
                //                 style: const TextStyle(
                //                     color: Colors.white,
                //                     fontWeight: FontWeight.w700,
                //                     fontSize: 40),
                //               ),
                //               const Text(
                //                 'Shubuh',
                //                 style: TextStyle(
                //                     color: Colors.white,
                //                     fontWeight: FontWeight.w500,
                //                     fontSize: 28),
                //               ),
                //             ],
                //           ),
                //         ),
                //       ),
                //       const SizedBox(width: 16,),
                //       Expanded(
                //         child: SizedBox(
                //           height:80,
                //           child: Column(
                //             crossAxisAlignment: CrossAxisAlignment.center,
                //             mainAxisAlignment: MainAxisAlignment.center,
                //             children: [
                //               Text(
                //                 adzan.terbit ?? '-',
                //                 style: const TextStyle(
                //                     color: Colors.white,
                //                     fontWeight: FontWeight.w700,
                //                     fontSize: 40),
                //               ),
                //               const Text(
                //                 'Syuruq',
                //                 style: TextStyle(
                //                     color: Colors.white,
                //                     fontWeight: FontWeight.w500,
                //                     fontSize: 28),
                //               ),
                //             ],
                //           ),
                //         ),
                //       ),
                //       const SizedBox(width: 16,),
                //       Expanded(
                //         child: SizedBox(
                //           height:80,
                //           child: Column(
                //             crossAxisAlignment: CrossAxisAlignment.center,
                //             mainAxisAlignment: MainAxisAlignment.center,
                //             children: [
                //               Text(
                //                 adzan.dzuhur ?? '-',
                //                 style: const TextStyle(
                //                     color: Colors.white,
                //                     fontWeight: FontWeight.w700,
                //                     fontSize: 40),
                //               ),
                //               const Text(
                //                 'Dhuhur',
                //                 style: TextStyle(
                //                     color: Colors.white,
                //                     fontWeight: FontWeight.w500,
                //                     fontSize: 28),
                //               ),
                //             ],
                //           ),
                //         ),
                //       ),
                //       const SizedBox(width: 16,),
                //       Expanded(
                //         child: SizedBox(
                //           height:80,
                //           child: Column(
                //             crossAxisAlignment: CrossAxisAlignment.center,
                //             mainAxisAlignment: MainAxisAlignment.center,
                //             children: [
                //               Text(
                //                 adzan.ashar ?? '-',
                //                 style: const TextStyle(
                //                     color: Colors.white,
                //                     fontWeight: FontWeight.w700,
                //                     fontSize: 40),
                //               ),
                //               const Text(
                //                 'Ashar',
                //                 style: TextStyle(
                //                     color: Colors.white,
                //                     fontWeight: FontWeight.w500,
                //                     fontSize: 28),
                //               ),
                //             ],
                //           ),
                //         ),
                //       ),
                //       const SizedBox(width: 16,),
                //       Expanded(
                //         child: SizedBox(
                //           height:80,
                //           child: Column(
                //             crossAxisAlignment: CrossAxisAlignment.center,
                //             mainAxisAlignment: MainAxisAlignment.center,
                //             children: [
                //               Text(
                //                 adzan.maghrib ?? '-',
                //                 style: const TextStyle(
                //                     color: Colors.white,
                //                     fontWeight: FontWeight.w700,
                //                     fontSize: 40),
                //               ),
                //               const Text(
                //                 'Maghrib',
                //                 style: TextStyle(
                //                     color: Colors.white,
                //                     fontWeight: FontWeight.w500,
                //                     fontSize: 28),
                //               ),
                //             ],
                //           ),
                //         ),
                //       ),
                //       const SizedBox(width: 16,),
                //       Expanded(
                //         child: SizedBox(
                //           height:80,
                //           child: Column(
                //             crossAxisAlignment: CrossAxisAlignment.center,
                //             crossAxisAlignment: CrossAxisAlignment.center,
                //             mainAxisAlignment: MainAxisAlignment.center,
                //             children: [
                //               Text(
                //                 adzan.isya ?? '-',
                //                 style: const TextStyle(
                //                     color: Colors.white,
                //                     fontWeight: FontWeight.w700,
                //                     fontSize: 40),
                //               ),
                //               const Text(
                //                 'Isya',
                //                 style: TextStyle(
                //                     color: Colors.white,
                //                     fontWeight: FontWeight.w500,
                //                     fontSize: 28),
                //               ),
                //             ],
                //           ),
                //         ),
                //       ),
                //     ],
                //   ),
                // )
              ],
            ),


          ],
        ),
      ):SafeArea(
          child: Stack(
            children: [
              Image.asset('assets/bg.jpeg',fit: BoxFit.cover,width: MediaQuery.of(context).size.width,),
              Stack(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: primaryColor
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FutureBuilder(
                                      future: fDatabase.reference().child('setting').child('logo').once(),
                                      builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
                                        if (snapshot.hasError)return const Text('Empty');
                                        if (snapshot.hasData) {
                                          if (snapshot.data!.value != null){
                                            String? nama = snapshot.data!.value;
                                            return Image.network(nama ?? '',height: 60,);
                                          }
                                        }
                                        return const SizedBox();
                                      }),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  FutureBuilder(
                                      future: fDatabase.reference().child('setting').child('name').once(),
                                      builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
                                        if (snapshot.hasError)return const Text('Empty');
                                        if (snapshot.hasData) {
                                          if (snapshot.data!.value != null){
                                            String? nama = snapshot.data!.value;
                                            return Text(
                                              nama ?? '-',
                                              style: GoogleFonts.lobster(
                                                textStyle: const TextStyle(
                                                    color: primaryTextColor,
                                                    fontSize: 30,
                                                    fontWeight: FontWeight.w400
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                        return const SizedBox();
                                      }),
                                  const SizedBox(height: 5,),
                                  FutureBuilder(
                                      future: fDatabase.reference().child('setting').child('address').once(),
                                      builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
                                        if (snapshot.hasError)return const Text('Empty');
                                        if (snapshot.hasData) {
                                          if (snapshot.data!.value != null){
                                            String? address = snapshot.data!.value;
                                            return Text(
                                              address ?? '-',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w400
                                              ),
                                            );
                                          }
                                        }
                                        return const SizedBox();
                                      }),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _timeString!,
                                    style: const TextStyle(
                                      color: primaryTextColor,
                                        fontSize: 30,
                                        fontWeight: FontWeight.w700
                                    ),
                                  ),
                                  const SizedBox(height: 5,),
                                  Text(
                                    '${_mDateString! }${_hDateString != null?' | $_hDateString':''}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w400
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      FutureBuilder(
                          future: fDatabase.reference().child('image').once(),
                          builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
                            if (snapshot.hasError)return const Text('error');
                            if (snapshot.hasData) {
                              lists.clear();
                              if (snapshot.data!.value != null){
                                Map<dynamic, dynamic> values = snapshot.data!.value;
                                values.forEach((key, values) {
                                  lists.add(values);
                                });
                                return CarouselSlider(
                                  options: CarouselOptions(
                                    viewportFraction: 1,
                                    height: MediaQuery.of(context).size.height * .63,
                                    autoPlay: true,
                                    aspectRatio: 1,
                                    autoPlayInterval: const Duration(minutes: 1),
                                    autoPlayAnimationDuration: const Duration(seconds: 10)
                                  ),
                                  items: lists.map((i) {
                                    return Builder(
                                      builder: (BuildContext context) {
                                        return SizedBox(
                                            width: MediaQuery.of(context).size.width,
                                            child: i.contains('http')?Image.network(i,fit: BoxFit.cover,):Container(
                                              decoration: BoxDecoration(
                                                color: secondaryColor.withOpacity(.5)
                                              ),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 40),
                                                  child: Center(child: Text(
                                                      i,
                                                    style: const TextStyle(
                                                      fontSize: 36,
                                                      color: Colors.white
                                                    ),
                                                  )),
                                                )
                                            )
                                        );
                                      },
                                    );
                                  }).toList(),
                                );
                              }
                            }
                            return const SizedBox();
                          }),
                      Expanded(
                        child: Container(
                          color:primaryColor,
                        ),
                      )
                    ],
                  ),
                  Positioned(
                    right: 16,
                    left: 16,
                    bottom: 55,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height:80,
                            decoration: BoxDecoration(
                              color: secondaryColor,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4)
                                )
                              ],
                              borderRadius: const BorderRadius.all(Radius.circular(20)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  adzan.subuh ?? '-',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 30),
                                ),
                                const Text(
                                  'Shubuh',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 20),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16,),
                        Expanded(
                          child: Container(
                            height:80,
                            decoration: BoxDecoration(
                              color: secondaryColor,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4)
                                )
                              ],
                              borderRadius: const BorderRadius.all(Radius.circular(20)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  adzan.dhuha ?? '-',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 30),
                                ),
                                const Text(
                                  'Syuruq',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 20),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16,),
                        Expanded(
                          child: Container(
                            height:80,
                            decoration: BoxDecoration(
                              color: secondaryColor,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4)
                                )
                              ],
                              borderRadius: const BorderRadius.all(Radius.circular(20)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  adzan.dzuhur ?? '-',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 30),
                                ),
                                const Text(
                                  'Dhuhur',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 20),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16,),
                        Expanded(
                          child: Container(
                            height:80,
                            decoration: BoxDecoration(
                              color: secondaryColor,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4)
                                )
                              ],
                              borderRadius: const BorderRadius.all(Radius.circular(20)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  adzan.ashar ?? '-',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 30),
                                ),
                                const Text(
                                  'Ashar',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 20),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16,),
                        Expanded(
                          child: Container(
                            height:80,
                            decoration: BoxDecoration(
                              color: secondaryColor,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4)
                                )
                              ],
                              borderRadius: const BorderRadius.all(Radius.circular(20)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  adzan.maghrib ?? '-',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 30),
                                ),
                                const Text(
                                  'Maghrib',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 20),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16,),
                        Expanded(
                          child: Container(
                            height:80,
                            decoration: BoxDecoration(
                              color: secondaryColor,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4)
                                )
                              ],
                              borderRadius: const BorderRadius.all(Radius.circular(20)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  adzan.isya ?? '-',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 30),
                                ),
                                const Text(
                                  'Isya',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 20),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              if (showTime)Container(
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
                color: primaryColor,
                child: Stack(
                  children: [
                    Positioned(
                        right:0,
                        bottom: 0,
                        child: SvgPicture.asset(
                          'assets/pattern-mandala.svg',
                          height: MediaQuery.of(context).size.height * .8,
                        )),
                    if (iqomah)Positioned(
                      right: 50,
                      bottom: 50,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              titleAdzanNowMini ?? '-',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24),
                            ),
                            Text(
                              adzanNow ?? '-',
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 34),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      decoration: const BoxDecoration(

                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          iqomah?const Text(
                            'Sebentar Lagi Akan Memasuki Jadwal Iqomah',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 30),
                          ):Text(
                            titleAdzanNow ?? '-',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 30),
                          ),
                          const SizedBox(height: 16,),
                          if (iqomah)Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15)
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 15),
                                child: Text(
                                  '${doubleDigitParse(endCountDown.inMinutes % 60)}:${doubleDigitParse(endCountDown.inSeconds % 60)}'.substring(0,1),
                                  style: const TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 80),
                                ),
                              ),
                              const SizedBox(width: 16,),
                              Container(
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15)
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 15),
                                child: Text(
                                  '${doubleDigitParse(endCountDown.inMinutes % 60)}:${doubleDigitParse(endCountDown.inSeconds % 60)}'.substring(1,2),
                                  style: const TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 80),
                                ),
                              ),
                              const SizedBox(width: 6,),
                              const Text(
                                ':',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 80),
                              ),
                              const SizedBox(width: 6,),
                              Container(
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15)
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 15),
                                child: Text(
                                  '${doubleDigitParse(endCountDown.inMinutes % 60)}:${doubleDigitParse(endCountDown.inSeconds % 60)}'.substring(3,4),
                                  style: const TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 80),
                                ),
                              ),
                              const SizedBox(width: 16,),
                              Container(
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15)
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 15),
                                child: Text(
                                  '${doubleDigitParse(endCountDown.inMinutes % 60)}:${doubleDigitParse(endCountDown.inSeconds % 60)}'.substring(4,5),
                                  style: const TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 80),
                                ),
                              ),
                            ],
                          )else Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15)
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 15),
                                child: Text(
                                  adzanNow?.substring(0,1) ?? '-',
                                  style: const TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 80),
                                ),
                              ),
                              const SizedBox(width: 16,),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15)
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 15),
                                child: Text(
                                  adzanNow?.substring(1,2) ?? '-',
                                  style: const TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 80),
                                ),
                              ),
                              const SizedBox(width: 6,),
                              const Text(
                                ':',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 80),
                              ),
                              const SizedBox(width: 6,),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15)
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 15),
                                child: Text(
                                  adzanNow?.substring(3,4) ?? '-',
                                  style: const TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 80),
                                ),
                              ),
                              const SizedBox(width: 16,),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15)
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 15),
                                child: Text(
                                  adzanNow?.substring(4,5) ?? '-',
                                  style: const TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 80),
                                ),
                              ),
                            ],
                          ),

                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ]
          ),
        ),

      // floatingActionButton: FloatingActionButton(
      //   child: Icon(
      //     Icons.add
      //   ),
      //   onPressed: (){
      //     startIqomah();
      //   },
      // ),
      bottomSheet: Container(
        padding: EdgeInsets.only(right: 19, left: 19, bottom: 10),
        decoration: BoxDecoration(
          color: Color(0xfff8f1e5),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10),
          height: 40,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Color.fromRGBO(217, 217, 217, 1)
          ),
          child: FutureBuilder(
                    future: fDatabase.reference().child('information').once(),
                    builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
                      if (snapshot.hasError)return const Text('error');
                      if (snapshot.hasData) {
                        information.clear();
                        if (snapshot.data!.value != null){
                          Map<dynamic, dynamic> values = snapshot.data!.value;
                          values.forEach((key, values) {
                            information.add(values);
                          });
                          return Marquee(
                            text: information.length == 1?information[0] :'🕌      ${information[0]}     🕌      ${information[1]}',
                            blankSpace: 35,
                            style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                                fontSize: 20
                            ),

                          );
                        }
                      }
                      return const SizedBox();
                    }),

              // Expanded(
              //   child: FutureBuilder(
              //       future: fDatabase.reference().child('information').once(),
              //       builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
              //         if (snapshot.hasError)return Text('Empty');
              //         if (snapshot.hasData) {
              //           if (snapshot.data!.value != null){
              //             Map<dynamic, dynamic> values = snapshot.data!.value;
              //             print(values);
              //             String? info;
              //             values.forEach((key, values) {
              //               info = values;
              //             });
              //             return Marquee(
              //               text: info ?? '',
              //               blankSpace: 50,
              //               style: TextStyle(
              //                   color:Colors.black,
              //                   fontWeight: FontWeight.w600,
              //                   fontSize: 30
              //               ),
              //             );
              //           }
              //         }
              //         }
              //         return SizedBox();
              //       }),
              // ),
        )
      ),
    );
  }
}
