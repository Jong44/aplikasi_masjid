class JadwalModel {
  String? id;
  String? lokasi;
  String? daerah;
  Koordinat? koordinat;
  List<Jadwal>? jadwal;

  JadwalModel({this.id, this.lokasi, this.daerah, this.koordinat, this.jadwal});

  JadwalModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    lokasi = json['lokasi'];
    daerah = json['daerah'];
    koordinat = json['koordinat'] != null
        ? Koordinat.fromJson(json['koordinat'])
        : null;
    jadwal = (json['jadwal'] as List?) != null &&
        (json['jadwal'] as List).isNotEmpty
        ? (json['jadwal'] as List)
        .map((f) => Jadwal.fromJson(f))
        .toList()
        : [];
    // if (json['jadwal'] != null) {
    //   jadwal = <Jadwal>[];
    //   json['jadwal'].forEach((v) {
    //     jadwal!.add(new Jadwal.fromJson(v));
    //   });
    // }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['lokasi'] = lokasi;
    data['daerah'] = daerah;
    if (koordinat != null) {
      data['koordinat'] = koordinat!.toJson();
    }
    if (jadwal != null) {
      data['jadwal'] = jadwal!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Koordinat {
  double? lat;
  double? lon;
  String? lintang;
  String? bujur;

  Koordinat({this.lat, this.lon, this.lintang, this.bujur});

  Koordinat.fromJson(Map<String, dynamic> json) {
    lat = json['lat'];
    lon = json['lon'];
    lintang = json['lintang'];
    bujur = json['bujur'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['lat'] = lat;
    data['lon'] = lon;
    data['lintang'] = lintang;
    data['bujur'] = bujur;
    return data;
  }
}

class Jadwal {
  String? tanggal;
  String? imsak;
  String? subuh;
  String? terbit;
  String? dhuha;
  String? dzuhur;
  String? ashar;
  String? maghrib;
  String? isya;
  String? date;

  Jadwal(
      {this.tanggal,
        this.imsak,
        this.subuh,
        this.terbit,
        this.dhuha,
        this.dzuhur,
        this.ashar,
        this.maghrib,
        this.isya,
        this.date});

  Jadwal.fromJson(Map<String, dynamic> json) {
    tanggal = json['tanggal'];
    imsak = json['imsak'];
    subuh = json['subuh'];
    terbit = json['terbit'];
    dhuha = json['dhuha'];
    dzuhur = json['dzuhur'];
    ashar = json['ashar'];
    maghrib = json['maghrib'];
    isya = json['isya'];
    date = json['date'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['tanggal'] = tanggal;
    data['imsak'] = imsak;
    data['subuh'] = subuh;
    data['terbit'] = terbit;
    data['dhuha'] = dhuha;
    data['dzuhur'] = dzuhur;
    data['ashar'] = ashar;
    data['maghrib'] = maghrib;
    data['isya'] = isya;
    data['date'] = date;
    return data;
  }
}