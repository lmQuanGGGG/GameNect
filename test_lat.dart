void main() {
  Map<String, dynamic> map = {'lat1': 10, 'lat2': 10.5, 'lat3': "10.5"};
  print(map['lat1']?.toDouble());
  print(map['lat2']?.toDouble());
  try {
    print(map['lat3']?.toDouble());
  } catch (e) {
    print('Error for lat3: $e');
  }
}
