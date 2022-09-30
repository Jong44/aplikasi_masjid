class KotaModel {
  String? id;
  String? lokasi;

  KotaModel({this.id, this.lokasi});

  KotaModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    lokasi = json['lokasi'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['lokasi'] = lokasi;
    return data;
  }
}
