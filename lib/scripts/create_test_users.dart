import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:logger/logger.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

final Logger _logger = Logger();

class CreateTestUsers {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Danh sách tên Việt Nam ─────────────────────────────────────
  final List<String> _firstNames = [
    'Nguyễn',
    'Trần',
    'Lê',
    'Phạm',
    'Hoàng',
    'Huỳnh',
    'Phan',
    'Vũ',
    'Võ',
    'Đặng',
    'Bùi',
    'Đỗ',
    'Hồ',
    'Ngô',
    'Dương',
    'Lý',
    'Đinh',
    'Trịnh',
    'Tô',
    'La',
    'Mai',
    'Tạ',
    'Châu',
    'Tăng',
    'Lâm',
    'Chu',
    'Thái',
    'Tiêu',
    'Quách',
    'Hà',
  ];

  final List<String> _lastNames = [
    'Gia Huy',
    'Minh Khang',
    'Khánh An',
    'Bảo Ngọc',
    'Hải Đăng',
    'Nhật Minh',
    'Quỳnh Anh',
    'Phương Linh',
    'Yến Nhi',
    'Đức Thịnh',
    'Hoàng Nam',
    'Tuấn Kiệt',
    'Thanh Trúc',
    'Diễm My',
    'Ngọc Mai',
    'Kim Ngân',
    'Hà My',
    'Khôi Nguyên',
    'Minh Quân',
    'Tiến Đạt',
    'Vân Anh',
    'Thiên Ân',
    'Bảo Châu',
    'Quang Huy',
    'Mỹ Duyên',
    'Anh Thư',
    'Tường Vy',
    'Hữu Phước',
    'Gia Linh',
    'Đức Anh',
  ];

  // ─── Game list ───────────────────────────────────────────────────
  final List<String> _games = [
    'Liên Quân Mobile',
    'PUBG Mobile',
    'Free Fire',
    'Tốc Chiến',
    'Valorant',
    'League of Legends',
    'Đấu Trường Chân Lý',
    'CS2',
    'Genshin Impact',
    'Honkai: Star Rail',
    'Zenless Zone Zero',
    'Minecraft',
    'Roblox',
    'FC Online',
    'Naraka: Bladepoint',
    'Apex Legends',
    'Overwatch 2',
    'Warzone Mobile',
    'Marvel Rivals',
  ];

  // ─── Locations ───────────────────────────────────────────────────
  final List<Map<String, dynamic>> _locations = [
    {'city': 'Hà Nội', 'lat': 21.0278, 'lng': 105.8342},
    {'city': 'TP. Hồ Chí Minh', 'lat': 10.7769, 'lng': 106.7009},
    {'city': 'Đà Nẵng', 'lat': 16.0678, 'lng': 108.2208},
    {'city': 'Hải Phòng', 'lat': 20.8449, 'lng': 106.6881},
    {'city': 'Cần Thơ', 'lat': 10.0452, 'lng': 105.7469},
    {'city': 'Nha Trang', 'lat': 12.2388, 'lng': 109.1967},
    {'city': 'Huế', 'lat': 16.4637, 'lng': 107.5909},
    {'city': 'Đà Lạt', 'lat': 11.9404, 'lng': 108.4583},
    {'city': 'Quy Nhơn', 'lat': 13.7820, 'lng': 109.2197},
    {'city': 'Vũng Tàu', 'lat': 10.4114, 'lng': 107.1362},
    {'city': 'Buôn Ma Thuột', 'lat': 12.6667, 'lng': 108.0500},
    {'city': 'Thái Nguyên', 'lat': 21.5942, 'lng': 105.8482},
    {'city': 'Long Xuyên', 'lat': 10.3833, 'lng': 105.4333},
    {'city': 'Rạch Giá', 'lat': 10.0125, 'lng': 105.0808},
  ];

  // ─── Bios ────────────────────────────────────────────────────────
  final List<String> _bios = [
    'Tối online sau 8h, ưu tiên team nói chuyện vui vẻ.',
    'Main support nhưng sẵn sàng fill mọi vị trí khi cần.',
    'Thích leo rank nghiêm túc, không toxic, call rõ ràng.',
    'Chơi game để xả stress, thua cũng cười.',
    'Ưu tiên đồng đội kiên nhẫn, cùng nhau cải thiện.',
    'Fan game chiến thuật, thích đọc meta và thử bài dị.',
    'Cuối tuần cày dài, ngày thường chơi 1-2 trận.',
    'Thích duo ổn định, không ghost giữa trận.',
    'Mục tiêu mùa này: lên rank mới và giữ winrate đẹp.',
    'Vừa chơi vừa học, thích chia sẻ kinh nghiệm cho team.',
    'Không try-hard quá mức, tôn trọng đồng đội là chính.',
    'Nếu bạn thích teamwork thì bắt cặp luôn nhé.',
    'Mình chơi đều nhiều tựa, từ MOBA tới FPS.',
    'Tìm bạn nói chuyện hợp vibe và chơi lâu dài.',
    'Lên game đúng giờ, kỷ luật nhưng vẫn thoải mái.',
    'Sẵn sàng train cùng người mới, miễn là có tinh thần.',
    'Tập trung objective, hạn chế combat vô nghĩa.',
    'Duo buổi tối, cuối tuần có thể lập team 5 người.',
    'Ưu tiên giao tiếp lịch sự, cùng nhau win sạch đẹp.',
    'Mong gặp đồng đội tích cực để đi đường dài.',
  ];

  // ─── Options (khớp với UI app) ───────────────────────────────────
  final List<String> _ranks = [
    'Gà Mờ',
    'Tập Sự Truyền Thuyết',
    'Chiến Binh Phèn',
    'Thánh Né',
    'Quái vật cân team',
    'Trùm Cuối',
    'Thượng Đế AFK',
    'Đồng',
    'Bạc',
    'Vàng',
    'Bạch kim',
    'Kim cương',
    'Cao thủ',
    'Đại cao thủ',
    'Thách đấu',
  ];

  final List<String> _gameStyles = [
    'Casual',
    'Competitive',
    'Streamer',
    'Pro Player',
    'Vừa chơi vừa học',
  ];

  final List<String> _allInterests = [
    'Anime/Manga',
    'Thể thao',
    'Du lịch',
    'Âm nhạc',
    'Phim ảnh',
    'Nấu ăn',
    'Sách',
    'Công nghệ',
    'Thời trang',
    'Nhiếp ảnh',
  ];

  final List<String> _lookingForOptions = [
    'Bạn chơi game',
    'Hẹn hò',
    'Cả hai',
    'Người chỉ dạy',
    'Đồng đội lâu dài',
  ];

  final List<String> _genders = ['Nam', 'Nữ', 'Khác'];

  // ─── Avatars — Pixabay (ảnh thật, nét, không trùng lặp) ──
  final List<String> _maleAvatars = [
    'https://cdn.pixabay.com/photo/2012/04/14/16/14/kabuki-34464_1280.png',
    'https://cdn.pixabay.com/photo/2012/10/29/15/36/ball-63527_1280.jpg',
    'https://cdn.pixabay.com/photo/2013/07/12/16/27/face-150934_1280.png',
    'https://cdn.pixabay.com/photo/2013/07/12/17/50/chinese-152546_1280.png',
    'https://cdn.pixabay.com/photo/2013/07/12/19/21/player-154626_1280.png',
    'https://cdn.pixabay.com/photo/2013/07/13/14/06/chinese-162133_1280.png',
    'https://cdn.pixabay.com/photo/2013/07/26/09/51/photographer-167614_1280.jpg',
    'https://cdn.pixabay.com/photo/2013/11/14/13/11/front-view-210383_1280.jpg',
    'https://cdn.pixabay.com/photo/2014/01/04/13/21/toddler-238466_1280.jpg',
    'https://cdn.pixabay.com/photo/2014/01/11/06/07/designer-241987_1280.jpg',
    'https://cdn.pixabay.com/photo/2014/01/30/14/24/woman-254931_1280.jpg',
    'https://cdn.pixabay.com/photo/2014/03/13/04/06/boy-286418_1280.jpg',
    'https://cdn.pixabay.com/photo/2014/04/02/10/19/chinese-303488_1280.png',
    'https://cdn.pixabay.com/photo/2014/04/02/10/19/chinese-303489_1280.png',
    'https://cdn.pixabay.com/photo/2014/04/03/10/45/man-311326_1280.png',
    'https://cdn.pixabay.com/photo/2014/04/05/13/05/boy-317041_1280.jpg',
    'https://cdn.pixabay.com/photo/2014/04/16/11/56/boy-325546_1280.jpg',
    'https://cdn.pixabay.com/photo/2014/05/13/22/40/man-343674_1280.jpg',
    'https://cdn.pixabay.com/photo/2014/05/27/23/32/matrix-356024_1280.jpg',
    'https://cdn.pixabay.com/photo/2014/07/11/22/05/baby-390555_1280.jpg',
    'https://cdn.pixabay.com/photo/2014/08/01/12/54/boy-407592_1280.jpg',
    'https://cdn.pixabay.com/photo/2014/11/06/15/14/man-519246_1280.jpg',
    'https://cdn.pixabay.com/photo/2014/12/24/16/18/couple-579172_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/01/12/10/45/man-597178_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/01/25/21/38/matrix-612149_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/04/07/01/38/baby-710357_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/04/07/01/40/baby-710360_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/07/17/22/42/typing-849806_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/07/30/14/03/abe-shinzo-867817_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/08/13/01/00/keyboard-886462_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/09/04/09/30/baby-921806_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/09/09/17/36/people-932069_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/09/23/06/59/tourist-953017_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/10/10/10/15/vietnam-980546_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/10/27/04/55/children-1008318_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/10/27/04/55/children-1008323_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/11/19/09/49/watercolor-portrait-1050714_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/11/19/09/55/watercolor-portrait-1050721_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/11/19/09/55/watercolor-portrait-1050722_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/11/19/09/56/watercolor-portrait-1050724_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/11/29/11/14/myanmar-1068571_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/01/09/08/08/boy-1129926_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/01/24/12/59/indian-1158809_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/01/28/10/20/old-man-1166066_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/02/12/08/47/indian-1195642_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/03/15/03/39/childrens-1256840_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/03/31/18/27/coding-1294373_1280.png',
    'https://cdn.pixabay.com/photo/2016/04/01/11/10/boy-1300226_1280.png',
    'https://cdn.pixabay.com/photo/2016/04/13/19/29/binary-1327512_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/04/16/04/33/student-1332508_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/04/25/07/15/man-1351317_1280.png',
    'https://cdn.pixabay.com/photo/2016/04/25/12/06/man-1351761_1280.png',
    'https://cdn.pixabay.com/photo/2016/05/01/09/49/male-1364615_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/05/05/11/22/computer-1373684_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/05/14/21/11/sculpture-1392529_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/06/03/06/22/thailand-1432878_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/06/15/16/16/man-1459246_1280.png',
    'https://cdn.pixabay.com/photo/2016/06/17/07/31/watercolor-1462795_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/06/20/04/30/asian-man-1468032_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/07/01/12/16/vietnamese-people-1490969_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/07/01/12/16/vietnamese-people-1490975_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/07/01/12/56/vietnamese-people-1491025_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/07/01/12/56/vietnamese-people-1491026_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/07/01/13/38/vietnamese-people-1491063_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/07/13/15/43/india-1514771_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/08/05/12/38/hanoi-1572207_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/08/13/13/45/boy-1590771_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/08/22/18/51/japan-1612651_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/09/09/19/56/car-1657935_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/09/21/22/06/sport-1685853_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/09/21/22/10/sport-1685859_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/09/21/22/46/sport-1685896_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/09/21/22/47/sport-1685897_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/09/30/02/15/malay-1704225_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/10/05/17/26/indian-1717192_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/01/16/56/boy-1788912_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/11/04/13/sport-1815783_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/11/04/19/sport-1815798_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/14/03/02/woman-1822454_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/14/04/25/bride-1822587_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/14/04/27/children-1822590_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/19/00/10/gamepad-1837422_1280.png',
    'https://cdn.pixabay.com/photo/2016/11/19/13/08/business-1839191_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/19/14/16/man-1839500_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/21/12/42/beard-1845166_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/21/12/54/man-1845259_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/21/15/08/playstation-1845880_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/21/16/13/stylish-boy-1846201_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/21/16/16/stylish-boy-1846213_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/22/19/21/child-1850153_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/23/14/45/coding-1853305_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/24/19/15/video-game-1856991_1280.png',
    'https://cdn.pixabay.com/photo/2016/11/29/01/36/businessman-1866582_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/29/02/14/man-1866784_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/01/01/11/05/asian-boys-1944326_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/01/30/08/36/tattoo-2020311_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/02/15/01/10/young-2067414_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/02/20/04/00/baby-boy-2081553_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/02/21/18/09/little-boy-2086910_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/03/16/01/23/asian-2147968_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/03/20/22/54/man-2160602_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/04/28/21/34/stylish-boy-2269500_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/04/28/21/34/stylish-boy-2269501_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/05/08/08/23/family-2294760_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/05/09/13/33/laptop-2298286_1280.png',
    'https://cdn.pixabay.com/photo/2017/06/18/08/50/couple-2414892_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/06/26/02/47/man-2442565_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/07/17/09/56/carrier-2511853_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/07/27/18/08/man-2546206_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/08/01/00/38/man-2562325_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/08/02/19/54/stylish-boy-2573130_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/08/07/09/25/people-2601878_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/08/07/18/39/xbox-2606608_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/08/10/02/48/macbook-2617419_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/08/14/21/50/boy-2642117_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/08/23/20/40/stylish-boy-2674228_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/09/02/11/00/reading-newspapaer-2706960_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/09/07/11/54/street-2724849_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/09/28/01/13/kimono-2794020_1280.png',
    'https://cdn.pixabay.com/photo/2017/10/08/15/18/bhutan-2830240_1280.jpg',
  ];

  final List<String> _femaleAvatars = [
    'https://cdn.pixabay.com/photo/2012/04/14/14/16/girl-34082_1280.png',
    'https://cdn.pixabay.com/photo/2012/10/29/15/36/ball-63527_1280.jpg',
    'https://cdn.pixabay.com/photo/2013/07/13/13/56/chinese-161791_1280.png',
    'https://cdn.pixabay.com/photo/2015/02/02/11/09/office-620822_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/04/20/17/39/woman-731894_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/05/20/09/15/child-775029_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/05/28/05/03/portrait-787522_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/05/31/10/51/technology-791029_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/07/02/05/28/portrait-828395_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/07/17/22/43/student-849821_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/07/17/22/43/student-849824_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/07/17/22/44/student-849828_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/07/28/22/04/woman-865111_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/10/07/12/58/asia-976160_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/11/19/09/49/watercolor-portrait-1050712_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/01/26/00/47/thailand-1161812_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/01/26/00/47/thailand-1161813_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/03/14/04/52/japan-1254945_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/03/14/19/29/carnival-1256116_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/04/01/09/01/asian-1299111_1280.png',
    'https://cdn.pixabay.com/photo/2016/06/15/16/00/woman-1459220_1280.png',
    'https://cdn.pixabay.com/photo/2016/08/01/17/24/kid-1561583_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/08/09/15/42/girl-vietnam-1580951_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/08/11/17/46/vietnam-1586337_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/10/04/04/12/asian-1713562_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/10/29/10/22/street-shot-1780393_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/14/03/02/woman-1822454_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/14/03/11/geisha-1822467_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/14/04/06/grandmother-1822560_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/14/04/25/bride-1822587_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/14/04/25/umbrella-1822586_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/14/04/54/woman-1822646_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/14/04/57/woman-1822656_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/19/15/19/asian-1839802_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/21/15/08/playstation-1845880_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/23/00/32/woman-1851464_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/23/14/50/apple-1853337_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/11/29/06/17/computer-1867758_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/01/14/10/57/bed-1979270_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/03/10/08/30/girl-2132171_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/04/06/18/41/asian-2209044_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/06/07/20/39/model-2381573_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/06/09/07/37/notebook-2386034_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/06/25/08/03/tourist-2439935_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/07/31/11/44/laptop-2557571_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/08/01/00/44/laptop-2562361_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/08/02/01/49/people-2569690_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/08/05/13/06/girl-2583442_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/08/07/18/39/xbox-2606608_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/08/17/13/40/bridge-2651380_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/09/01/00/55/indian-2702771_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/09/01/12/52/girl-2704116_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/10/12/14/56/girl-2844802_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/11/18/21/26/vietnam-women-2961307_1280.jpg',
    'https://cdn.pixabay.com/photo/2017/12/13/09/15/vietnam-women-3016356_1280.jpg',
    'https://cdn.pixabay.com/photo/2018/01/17/07/06/laptop-3087585_1280.jpg',
    'https://cdn.pixabay.com/photo/2018/01/28/10/14/asian-girl-3113208_1280.jpg',
    'https://cdn.pixabay.com/photo/2018/03/30/17/33/vietnamese-girls-3275958_1280.jpg',
    'https://cdn.pixabay.com/photo/2018/04/07/16/33/people-3298899_1280.jpg',
    'https://cdn.pixabay.com/photo/2018/07/04/06/17/long-coat-3515443_1280.jpg',
    'https://cdn.pixabay.com/photo/2018/07/05/16/19/girl-3518622_1280.jpg',
    'https://cdn.pixabay.com/photo/2018/07/15/13/34/portrait-3539628_1280.jpg',
    'https://cdn.pixabay.com/photo/2018/08/12/12/15/portrait-3600667_1280.jpg',
    'https://cdn.pixabay.com/photo/2018/10/20/22/40/tuk-tuk-3761936_1280.jpg',
    'https://cdn.pixabay.com/photo/2018/11/01/16/46/girl-3788569_1280.jpg',
    'https://cdn.pixabay.com/photo/2018/11/17/07/28/girl-3820661_1280.jpg',
    'https://cdn.pixabay.com/photo/2018/11/23/16/10/indonesia-3834181_1280.jpg',
    'https://cdn.pixabay.com/photo/2018/12/08/16/02/asian-3863541_1280.jpg',
    'https://cdn.pixabay.com/photo/2018/12/11/11/00/girl-3868849_1280.jpg',
    'https://cdn.pixabay.com/photo/2018/12/28/12/51/asian-3899529_1280.jpg',
    'https://cdn.pixabay.com/photo/2019/01/09/06/39/asian-3922688_1280.jpg',
    'https://cdn.pixabay.com/photo/2019/01/23/16/40/girl-3950651_1280.jpg',
    'https://cdn.pixabay.com/photo/2019/01/23/16/46/asian-3950667_1280.jpg',
    'https://cdn.pixabay.com/photo/2019/01/24/02/53/woman-3951558_1280.jpg',
    'https://cdn.pixabay.com/photo/2019/02/12/13/45/chinese-3992277_1280.jpg',
    'https://cdn.pixabay.com/photo/2019/07/05/13/05/girl-4318539_1280.jpg',
    'https://cdn.pixabay.com/photo/2019/08/07/04/37/old-woman-4389774_1280.jpg',
    'https://cdn.pixabay.com/photo/2019/08/09/20/56/young-girl-4395876_1280.jpg',
    'https://cdn.pixabay.com/photo/2019/08/30/05/50/female-4440487_1280.jpg',
    'https://cdn.pixabay.com/photo/2019/09/09/15/41/cosplay-4463927_1280.jpg',
    'https://cdn.pixabay.com/photo/2019/09/09/15/41/cosplay-4463928_1280.jpg',
    'https://cdn.pixabay.com/photo/2019/09/28/23/53/girl-4512036_1280.jpg',
    'https://cdn.pixabay.com/photo/2019/10/05/19/45/girl-4528667_1280.jpg',
    'https://cdn.pixabay.com/photo/2019/10/16/06/43/cosplay-4553587_1280.jpg',
    'https://cdn.pixabay.com/photo/2019/10/27/16/18/vietnamese-4582190_1280.jpg',
    'https://cdn.pixabay.com/photo/2019/10/27/16/20/vietnamese-4582194_1280.jpg',
    'https://cdn.pixabay.com/photo/2019/10/27/16/23/vietnamese-4582200_1280.jpg',
    'https://cdn.pixabay.com/photo/2019/11/06/17/04/vietnam-girl-4606701_1280.jpg',
    'https://cdn.pixabay.com/photo/2019/11/06/17/49/model-4606802_1280.jpg',
    'https://cdn.pixabay.com/photo/2019/12/09/14/51/vietnamese-4683655_1280.jpg',
    'https://cdn.pixabay.com/photo/2019/12/09/14/55/vietnamese-4683671_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/01/18/10/55/child-4774967_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/01/18/11/18/child-4775023_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/01/21/18/51/woman-4783686_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/01/21/18/51/woman-4783687_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/01/21/18/51/woman-4783688_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/01/21/18/51/woman-4783689_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/01/21/18/51/woman-4783691_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/02/09/17/01/asian-woman-4833853_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/03/01/14/02/girl-4892957_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/03/06/01/25/cute-4905800_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/03/06/01/25/cute-4905802_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/03/06/01/26/cute-4905810_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/03/06/01/27/cute-4905815_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/03/06/01/27/cute-4905816_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/03/06/01/27/cute-4905817_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/03/06/01/27/cute-4905818_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/03/06/01/27/cute-4905819_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/03/06/01/27/cute-4905820_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/03/06/01/27/cute-4905821_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/03/06/11/15/woman-4906810_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/03/07/15/20/girl-4910058_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/03/07/15/20/girl-4910059_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/03/07/15/21/girl-4910064_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/03/07/15/21/girl-4910065_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/03/07/15/21/girl-4910066_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/03/07/15/21/girl-4910069_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/03/07/15/22/girl-4910076_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/03/07/15/24/girl-4910082_1280.jpg',
    'https://cdn.pixabay.com/photo/2020/03/07/15/26/girl-4910089_1280.jpg',
  ];

  final List<String> _otherAvatars = [
    'https://cdn.pixabay.com/photo/2010/12/22/10/49/advertisement-3926_1280.jpg',
    'https://cdn.pixabay.com/photo/2012/02/19/10/48/basketball-14861_1280.jpg',
    'https://cdn.pixabay.com/photo/2012/04/01/12/39/joystick-23234_1280.png',
    'https://cdn.pixabay.com/photo/2012/04/05/01/25/ball-25640_1280.png',
    'https://cdn.pixabay.com/photo/2012/04/11/11/32/audio-27582_1280.png',
    'https://cdn.pixabay.com/photo/2012/04/11/16/52/video-game-28884_1280.png',
    'https://cdn.pixabay.com/photo/2012/04/12/11/40/chessboard-29630_1280.png',
    'https://cdn.pixabay.com/photo/2012/04/13/11/41/joystick-32023_1280.png',
    'https://cdn.pixabay.com/photo/2012/04/18/23/22/joystick-38228_1280.png',
    'https://cdn.pixabay.com/photo/2012/12/19/03/27/open-70835_1280.jpg',
    'https://cdn.pixabay.com/photo/2013/02/01/10/55/lamps-77060_1280.jpg',
    'https://cdn.pixabay.com/photo/2013/02/16/17/36/las-vegas-82319_1280.jpg',
    'https://cdn.pixabay.com/photo/2013/03/02/01/25/joystick-89038_1280.jpg',
    'https://cdn.pixabay.com/photo/2013/07/12/12/18/headset-145520_1280.png',
    'https://cdn.pixabay.com/photo/2013/07/12/12/32/controller-145875_1280.png',
    'https://cdn.pixabay.com/photo/2013/07/12/13/26/video-game-controller-147039_1280.png',
    'https://cdn.pixabay.com/photo/2013/07/12/15/07/world-cup-149492_1280.png',
    'https://cdn.pixabay.com/photo/2013/07/12/16/34/goal-151148_1280.png',
    'https://cdn.pixabay.com/photo/2013/07/12/17/40/wii-152197_1280.png',
    'https://cdn.pixabay.com/photo/2013/07/12/18/02/video-game-controller-152852_1280.png',
    'https://cdn.pixabay.com/photo/2013/07/13/01/19/game-controller-155530_1280.png',
    'https://cdn.pixabay.com/photo/2013/07/13/12/21/chess-159693_1280.png',
    'https://cdn.pixabay.com/photo/2013/07/13/12/49/game-160398_1280.png',
    'https://cdn.pixabay.com/photo/2013/07/13/13/34/headset-161139_1280.png',
    'https://cdn.pixabay.com/photo/2013/07/13/13/48/controller-161579_1280.png',
    'https://cdn.pixabay.com/photo/2013/07/13/13/48/controller-161580_1280.png',
    'https://cdn.pixabay.com/photo/2013/11/14/18/04/las-vegas-210534_1280.jpg',
    'https://cdn.pixabay.com/photo/2013/11/14/18/06/las-vegas-210537_1280.jpg',
    'https://cdn.pixabay.com/photo/2013/12/16/18/41/open-229404_1280.jpg',
    'https://cdn.pixabay.com/photo/2014/01/05/01/19/dragon-238931_1280.jpg',
    'https://cdn.pixabay.com/photo/2014/01/30/00/37/gaming-console-254691_1280.jpg',
    'https://cdn.pixabay.com/photo/2014/02/18/17/56/neon-tube-269365_1280.jpg',
    'https://cdn.pixabay.com/photo/2014/03/24/17/17/video-controller-295295_1280.png',
    'https://cdn.pixabay.com/photo/2014/03/25/15/18/nintendo-296445_1280.png',
    'https://cdn.pixabay.com/photo/2014/04/03/10/01/console-309614_1280.png',
    'https://cdn.pixabay.com/photo/2014/04/03/10/06/american-football-309795_1280.png',
    'https://cdn.pixabay.com/photo/2014/04/03/10/34/joystick-310922_1280.png',
    'https://cdn.pixabay.com/photo/2014/04/11/02/24/knight-321443_1280.jpg',
    'https://cdn.pixabay.com/photo/2014/06/04/16/41/thank-you-362164_1280.jpg',
    'https://cdn.pixabay.com/photo/2014/08/27/05/23/pilot-428894_1280.jpg',
    'https://cdn.pixabay.com/photo/2014/10/08/23/24/chair-481002_1280.jpg',
    'https://cdn.pixabay.com/photo/2014/11/06/23/41/volleyball-520083_1280.jpg',
    'https://cdn.pixabay.com/photo/2014/12/21/23/49/bench-576129_1280.png',
    'https://cdn.pixabay.com/photo/2015/01/11/19/22/cowgirl-596574_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/02/19/04/40/slots-641738_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/04/05/14/30/headset-707889_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/05/01/10/27/casino-748170_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/05/31/13/10/girl-791686_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/06/24/15/59/workspace-820315_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/07/29/20/24/joystick-866522_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/08/18/01/54/video-games-893225_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/09/05/21/25/xbox-925407_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/09/10/19/36/tennis-934841_1280.jpg',
    'https://cdn.pixabay.com/photo/2015/09/14/23/35/sexy-940368_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/01/03/12/00/smartphone-1119314_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/01/04/12/35/support-1120755_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/01/12/16/38/video-games-1136046_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/01/22/08/18/neon-1155438_1280.jpg',
    'https://cdn.pixabay.com/photo/2016/03/31/18/02/controller-1294077_1280.png',
    'https://cdn.pixabay.com/photo/2016/03/31/18/22/game-1294305_1280.png',
  ];

  final Random _random = Random();

  final List<int> _locationWeights = [93, 85, 35, 21, 18, 15, 12, 10, 9, 11, 8, 7, 6, 6];

  List<String> _boysNamesFetched = [];
  List<String> _girlsNamesFetched = [];
  List<String> _gamesFetched = [];
  List<String> _ranksFetched = [];
  bool _isHybridDataInitialized = false;

  Future<void> _initializeHybridData() async {
    if (_isHybridDataInitialized) return;
    _logger.i('Bắt đầu khởi tạo dữ liệu Hybrid Real Data...');

    // 1. Tải tên thật từ GitHub
    try {
      final boyRes = await http.get(Uri.parse('https://raw.githubusercontent.com/duyet/vietnamese-namedb/master/boy.txt'));
      if (boyRes.statusCode == 200) {
        _boysNamesFetched = boyRes.body
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        _logger.i('✓ Đã tải ${_boysNamesFetched.length} tên con trai từ GitHub.');
      }
    } catch (e) {
      _logger.w('⚠️ Không thể tải boy.txt từ GitHub, sử dụng fallback: $e');
    }

    try {
      final girlRes = await http.get(Uri.parse('https://raw.githubusercontent.com/duyet/vietnamese-namedb/master/girl.txt'));
      if (girlRes.statusCode == 200) {
        _girlsNamesFetched = girlRes.body
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        _logger.i('✓ Đã tải ${_girlsNamesFetched.length} tên con gái từ GitHub.');
      }
    } catch (e) {
      _logger.w('⚠️ Không thể tải girl.txt từ GitHub, sử dụng fallback: $e');
    }

    // 2. Tải games từ RAWG API
    try {
      const apiKey = '754a38d2419a4aee8924fd13b8193b0f';
      const url = 'https://api.rawg.io/api/games?key=$apiKey&page_size=40&ordering=-added';
      final gamesRes = await http.get(Uri.parse(url));
      if (gamesRes.statusCode == 200) {
        final data = json.decode(gamesRes.body);
        final List results = data['results'] ?? [];
        _gamesFetched = results
            .map((item) => item['name'].toString())
            .where((name) => name.isNotEmpty)
            .toList();
        _logger.i('✓ Đã tải ${_gamesFetched.length} games hot từ RAWG API.');
      }
    } catch (e) {
      _logger.w('⚠️ Không thể tải games từ RAWG API, sử dụng fallback: $e');
    }

    // 3. Tải ranks từ Firestore Configurations
    try {
      final doc = await _firestore.collection('configurations').doc('rankOptions').get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['vi'] != null) {
          final List<dynamic> list = data['vi'];
          _ranksFetched = list.map((e) => e.toString()).toList();
          _logger.i('✓ Đã tải ${_ranksFetched.length} ranks từ Firestore Configurations.');
        }
      }
    } catch (e) {
      _logger.w('⚠️ Không thể tải ranks từ Firestore, sử dụng fallback: $e');
    }

    _isHybridDataInitialized = true;
  }

  Map<String, dynamic> _getRandomLocationWeighted() {
    final totalWeight = _locationWeights.reduce((a, b) => a + b);
    int r = _random.nextInt(totalWeight);
    for (int i = 0; i < _locations.length; i++) {
      r -= _locationWeights[i];
      if (r < 0) {
        return _locations[i];
      }
    }
    return _locations.first;
  }

  String _generateNaturalBio() {
    final greetings = [
      'Hi mọi người!',
      'Chào bạn nha,',
      'Hello, mình là game thủ hệ vui vẻ.',
      'Xin chào các chiến hữu!',
      'Tìm đồng đội hợp cạ đây.',
      'Hi, mong tìm được cạ cứng.',
      'Hello ace!',
      'Vào đây để giao lưu kết bạn.',
    ];

    final roles = [
      'Mình chuyên main support, gánh team bằng cả tấm lòng.',
      'Chuyên đi rừng gank dạo, cần tìm lane tốt.',
      'Main mid/adc thích chơi chủ động.',
      'Thích fill mọi vị trí, chơi gì cũng được.',
      'Thích chơi game bắn súng FPS, tay to gánh team.',
      'Học việc MOBA, mong được mọi người chỉ giáo.',
      'Chơi đủ thể loại từ chiến thuật đến nhập vai.',
      'Chuyên đi đường rồng gánh team.',
    ];

    final onlineTimes = [
      'Tối online sau 8h.',
      'Rảnh giờ nào chơi giờ đó, rủ là đi.',
      'Cuối tuần cày cật lực, ngày thường chơi tối.',
      'Chỉ online đêm muộn 22h - 2h sáng.',
      'Thời gian online linh hoạt.',
      'Chiều tối 18h - 21h hàng ngày.',
      'Thường rảnh cuối tuần.',
    ];

    final callToActions = [
      'Ai cùng chí hướng thì match cùng leo rank nhé!',
      'Không toxic, thua cùng chịu, thắng cùng vui. Match nha!',
      'Vui lòng match mình nếu muốn try hard.',
      'Chơi game xả stress, match nói chuyện vui vẻ.',
      'Ai rảnh inbox giao lưu nhé!',
      'Duo hoặc lập team 5 đều ok, match đi.',
      'Match đi chờ chi!',
      'Tìm cạ cứng leo rank nghiêm túc.',
    ];

    final greeting = greetings[_random.nextInt(greetings.length)];
    final role = roles[_random.nextInt(roles.length)];
    final time = onlineTimes[_random.nextInt(onlineTimes.length)];
    final cta = callToActions[_random.nextInt(callToActions.length)];

    return '$greeting $role $time $cta';
  }

  // ─── Helpers ─────────────────────────────────────────────────────

  DateTime _generateRandomBirthDate() {
    final now = DateTime.now();
    final age = 18 + _random.nextInt(18); // 18-35 tuổi
    return DateTime(
      now.year - age,
      1 + _random.nextInt(12),
      1 + _random.nextInt(28),
    );
  }

  String _getAvatarByGender(String gender) {
    if (gender == 'Nam')
      return _maleAvatars[_random.nextInt(_maleAvatars.length)];
    if (gender == 'Nữ')
      return _femaleAvatars[_random.nextInt(_femaleAvatars.length)];
    return _otherAvatars[_random.nextInt(_otherAvatars.length)];
  }

  String _removeVietnameseTones(String str) {
    const vietnamese =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const latin =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    String result = str;
    for (int i = 0; i < vietnamese.length; i++) {
      result = result.replaceAll(vietnamese[i], latin[i]);
    }
    return result;
  }

  // ════════════════════════════════════════════════════════════════
  // TẠO 1 USER
  // ════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> createRandomUser(int index) async {
    try {
      await _initializeHybridData();
      final gender = _genders[_random.nextInt(_genders.length)];
      final firstName = _firstNames[_random.nextInt(_firstNames.length)]; // Họ
      String lastName = ''; // Tên đệm + tên chính
      if (gender == 'Nam') {
        if (_boysNamesFetched.isNotEmpty) {
          lastName = _boysNamesFetched[_random.nextInt(_boysNamesFetched.length)];
        } else {
          lastName = _lastNames[_random.nextInt(_lastNames.length)];
        }
      } else if (gender == 'Nữ') {
        if (_girlsNamesFetched.isNotEmpty) {
          lastName = _girlsNamesFetched[_random.nextInt(_girlsNamesFetched.length)];
        } else {
          lastName = _lastNames[_random.nextInt(_lastNames.length)];
        }
      } else {
        final pool = _random.nextBool()
            ? (_boysNamesFetched.isNotEmpty ? _boysNamesFetched : _lastNames)
            : (_girlsNamesFetched.isNotEmpty ? _girlsNamesFetched : _lastNames);
        lastName = pool[_random.nextInt(pool.length)];
      }
      final displayName = '$firstName $lastName';
      final username =
          '${_removeVietnameseTones(firstName.toLowerCase())}'
          '${_removeVietnameseTones(lastName.toLowerCase())}'
          '${index.toString().padLeft(3, '0')}';
      final email = index < 100
          ? 'testuser${index.toString().padLeft(4, '0')}@gamenect.com'
          : '${username.replaceAll(' ', '')}@gmail.com';
      final password = 'Test@123';

      _logger.i('Đang tạo user [$index]: $email');

      User? user;
      try {
        final cred = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        user = cred.user;
        _logger.i('✓ Tạo mới Auth: $email');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          _logger.w('⚠️  Đã tồn tại, cập nhật: $email');
          try {
            final cred = await _auth.signInWithEmailAndPassword(
              email: email,
              password: password,
            );
            user = cred.user;
          } catch (_) {
            _logger.e('❌ Không đăng nhập được: $email');
            return null;
          }
        } else {
          rethrow;
        }
      }
      if (user == null) return null;

      await user.updateDisplayName(displayName);

      // ── Profile fields ─────────────────────────────────────────
      final birthDate = _generateRandomBirthDate();
      final age = DateTime.now().year - birthDate.year;
      final height = 150 + _random.nextInt(41);
      final location = _getRandomLocationWeighted();
      final bio = _generateNaturalBio();
      final rankPool = _ranksFetched.isNotEmpty ? _ranksFetched : _ranks;
      final rank = rankPool[_random.nextInt(rankPool.length)];
      final gameStyle = _gameStyles[_random.nextInt(_gameStyles.length)];
      final playTime = _random.nextInt(5001);
      final winRate = 30 + _random.nextInt(51);
      final isPremium = _random.nextInt(10) == 0;
      final isVerified = _random.nextInt(10) < 3;
      final isOnline = _random.nextInt(5) == 0;

      // Games (1-3)
      final gamesPool = _gamesFetched.isNotEmpty ? _gamesFetched : _games;
      final gamesCopy = List<String>.from(gamesPool);
      final numGames = 1 + _random.nextInt(3);
      final selectedGames = <String>[];
      for (int i = 0; i < numGames; i++) {
        selectedGames.add(
          gamesCopy.removeAt(_random.nextInt(gamesCopy.length)),
        );
      }

      // Interests (2-5)
      final intCopy = List<String>.from(_allInterests);
      final numInt = 2 + _random.nextInt(4);
      final interests = <String>[];
      for (int i = 0; i < numInt; i++) {
        interests.add(intCopy.removeAt(_random.nextInt(intCopy.length)));
      }

      // Photos phụ — Unsplash cuò thêm với face crop
      final additionalPhotos = <String>[];
      final numPhotos = 1 + _random.nextInt(4);
      final pool = gender == 'Nam' ? _maleAvatars : _femaleAvatars;
      final used = <String>{};
      for (int i = 0; i < numPhotos; i++) {
        if (i < 2) {
          // Nhặt ảnh khác từ pool (không trùng avatar chính)
          String pick;
          do {
            pick = pool[_random.nextInt(pool.length)];
          } while (used.contains(pick));
          used.add(pick);
          additionalPhotos.add(pick);
        } else {
          // Lifestyle shot — Unsplash cầnh phố/game cafe Việt Nam
          final lifestyleIds = [
            '1558618666-fcd25c85cd64', // cà phê Việt Nam
            '1506126613408-eca07ce68773', // cảnh phố
            '1574236170878-0e69a1609099', // gaming
            '1542751371-adc538436a54', // esports
            '1511512578047-dfb367046420', // gaming setup
            '1593305841991-05c297ba4575', // cà phê
            '1524592094714-0f0654e359e3', // bàn game
            '1600861194942-f883de0dfe96', // lạc phố Việt Nam
          ];
          final id = lifestyleIds[_random.nextInt(lifestyleIds.length)];
          additionalPhotos.add(
            'https://images.unsplash.com/photo-$id?w=600&h=800&fit=crop&q=80',
          );
        }
      }

      // ⭐ Preferences (QUAN TRỌNG cho ML model) ──────────────────
      final interestedInGender = _random.nextInt(3) == 0
          ? 'Tất cả'
          : (_random.nextBool() ? 'Nam' : 'Nữ');
      final minAge = 18 + _random.nextInt(5); // 18-22
      final maxAge = age + 5 + _random.nextInt(10); // age+5 → age+15
      final maxDistance = [10.0, 20.0, 30.0, 50.0, 100.0][_random.nextInt(5)];
      final lookingFor =
          _lookingForOptions[_random.nextInt(_lookingForOptions.length)];

      // ── Last seen: trong vòng 30 ngày qua ─────────────────────
      final lastSeenDaysAgo = _random.nextInt(30);
      final lastSeen = DateTime.now()
          .subtract(Duration(days: lastSeenDaysAgo, hours: _random.nextInt(24)))
          .toIso8601String();

      final profileData = {
        // Identity
        'uid': user.uid,
        'email': email,
        'username': username,
        'displayName': displayName,
        'photoURL': _getAvatarByGender(gender),
        'avatarUrl': _getAvatarByGender(gender),
        'bio': bio,

        // Personal
        'gender': gender,
        'birthDate': birthDate.toIso8601String(),
        'age': age,
        'height': height,

        // Game
        'favoriteGames': selectedGames,
        'rank': rank,
        'playTime': playTime,
        'winRate': winRate,
        'gameStyle': gameStyle,

        // Social
        'interests': interests,
        'lookingFor': lookingFor,

        // ⭐ Preferences (ML model dùng)
        'interestedInGender': interestedInGender,
        'minAge': minAge,
        'maxAge': maxAge,
        'maxDistance': maxDistance,

        // Location
        'location': {
          'city': location['city'],
          'latitude': location['lat'],
          'longitude': location['lng'],
          'updatedAt': DateTime.now().toIso8601String(),
        },

        // Media
        'additionalPhotos': additionalPhotos,

        // Status
        'isOnline': isOnline,
        'lastSeen': lastSeen,
        'isPremium': isPremium,
        'isVerified': isVerified,
        'showOnlineStatus': _random.nextBool(),
        'isTestAccount': true,

        // Timestamps
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),

        // ⭐ Social proof stats (ML model dùng)
        'likeCount': _random.nextInt(200),
        'matchCount': _random.nextInt(50),
        'friendCount': _random.nextInt(100),
        'superLikeCount': _random.nextInt(20),
        'profileViews': _random.nextInt(300),
        'totalMatches': _random.nextInt(50),
        'totalLikes': _random.nextInt(200),
        'totalSuperLikes': _random.nextInt(20),

        // Settings
        'showAge': _random.nextBool(),
        'showDistance': _random.nextBool(),

        // Account
        'subscriptionTier': 'free',
        'subscriptionEndDate': null,
        'incognitoMode': false,
        'blockedUserIds': <String>[],
        'reportedUserIds': <String>[],
      };

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(profileData, SetOptions(merge: true));

      _logger.i(
        '✓ $email | $displayName | ${location['city']} | '
        '$age tuổi | $gender | $rank | ${selectedGames.join(', ')}',
      );

      await _auth.signOut();

      return {
        'uid': user.uid,
        'email': email,
        'username': username,
        'password': password,
        'displayName': displayName,
        'city': location['city'],
        'lat': location['lat'],
        'lng': location['lng'],
        'age': age,
        'gender': gender,
        'games': selectedGames,
        'interests': interests,
        'rank': rank,
        'gameStyle': gameStyle,
        'lookingFor': lookingFor,
        'winRate': winRate,
        'playTime': playTime,
        'interestedInGender': interestedInGender,
        'minAge': minAge,
        'maxAge': maxAge,
        'maxDistance': maxDistance,
        'isVerified': isVerified,
        'isPremium': isPremium,
      };
    } catch (e) {
      _logger.e('✗ Lỗi tạo user $index: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════
  // ⭐ TẠO SWIPE DATA THỰC TẾ (QUAN TRỌNG NHẤT CHO ML MODEL)
  // Logic: dùng profile similarity để quyết định like/dislike
  // → Labels THỰC, không random hoàn toàn
  // ════════════════════════════════════════════════════════════════

  Future<void> createRealisticSwipeData(
    List<Map<String, dynamic>> users,
  ) async {
    _logger.i('\n=== TẠO SWIPE DATA (${users.length} users) ===\n');

    int totalSwipes = 0;
    int likeCount = 0;
    int dislikeCount = 0;

    // Mỗi user swipe ~15-25 users khác
    for (int i = 0; i < users.length; i++) {
      final swiper = users[i];
      final swiperId = swiper['uid'] as String;

      // Số lượng người được swipe (15-25)
      final numSwipes = 15 + _random.nextInt(11);
      final candidates = List<Map<String, dynamic>>.from(users)
        ..removeWhere((u) => u['uid'] == swiperId)
        ..shuffle(_random);
      final toSwipe = candidates.take(numSwipes).toList();

      for (final target in toSwipe) {
        final targetId = target['uid'] as String;

        // ── Tính compatibility score để quyết định like/dislike ──
        final score = _computeCompatibility(swiper, target);

        // Score cao → thích, thấp → không thích
        // Thêm randomness để realistic (không ai like 100% dựa theo rules)
        final randomFactor = (_random.nextDouble() - 0.5) * 0.3; // ±0.15
        final finalScore = (score + randomFactor).clamp(0.0, 1.0);
        final action = finalScore >= 0.5 ? 'like' : 'dislike';

        if (action == 'like')
          likeCount++;
        else
          dislikeCount++;
        totalSwipes++;

        // Lưu vào swipe_history
        final swipeDoc = _firestore.collection('swipe_history').doc();
        await swipeDoc.set({
          'id': swipeDoc.id,
          'userId': swiperId,
          'targetUserId': targetId,
          'action': action,
          'timestamp': DateTime.now()
              .subtract(
                Duration(
                  days: _random.nextInt(30),
                  hours: _random.nextInt(24),
                  minutes: _random.nextInt(60),
                ),
              )
              .toIso8601String(),
          // metadata cho debug
          '_compatScore': score,
          '_isTestData': true,
        });

        // Cũng lưu vào swipe_latest (snapshot mới nhất của cặp)
        final latestId = [swiperId, targetId]..sort();
        await _firestore
            .collection('swipe_latest')
            .doc('${latestId[0]}_${latestId[1]}')
            .set({
              'userId': swiperId,
              'targetUserId': targetId,
              'action': action,
              'timestamp': DateTime.now().toIso8601String(),
              '_isTestData': true,
            }, SetOptions(merge: true));
      }

      if ((i + 1) % 10 == 0) {
        _logger.i(
          'Swipe progress: ${i + 1}/${users.length} users | '
          'total=$totalSwipes like=$likeCount dislike=$dislikeCount',
        );
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }

    _logger.i('\n✅ Swipe data done:');
    _logger.i('  Total swipes : $totalSwipes');
    _logger.i(
      '  Like         : $likeCount (${(likeCount / totalSwipes * 100).toStringAsFixed(1)}%)',
    );
    _logger.i(
      '  Dislike      : $dislikeCount (${(dislikeCount / totalSwipes * 100).toStringAsFixed(1)}%)',
    );

    // Tạo matches từ mutual likes
    await _createMatchesFromMutualLikes(users);
  }

  // ════════════════════════════════════════════════════════════════
  // Tính compatibility score (0-1) giữa 2 users — giống ML model
  // ════════════════════════════════════════════════════════════════
  double _computeCompatibility(
    Map<String, dynamic> u1,
    Map<String, dynamic> u2,
  ) {
    double score = 0.0;
    int factors = 0;

    // 1. Gender preference match
    final pref1 = u1['interestedInGender'] as String? ?? 'Tất cả';
    final pref2 = u2['interestedInGender'] as String? ?? 'Tất cả';
    final g1 = u1['gender'] as String? ?? '';
    final g2 = u2['gender'] as String? ?? '';
    final m12 = pref1 == 'Tất cả' || pref1 == g2;
    final m21 = pref2 == 'Tất cả' || pref2 == g1;
    score += (m12 && m21)
        ? 1.0
        : (m12 || m21)
        ? 0.4
        : 0.0;
    factors++;

    // 2. Age preference
    final age1 = (u1['age'] as num?)?.toDouble() ?? 25;
    final age2 = (u2['age'] as num?)?.toDouble() ?? 25;
    final minAge1 = (u1['minAge'] as num?)?.toDouble() ?? 18;
    final maxAge1 = (u1['maxAge'] as num?)?.toDouble() ?? 60;
    final minAge2 = (u2['minAge'] as num?)?.toDouble() ?? 18;
    final maxAge2 = (u2['maxAge'] as num?)?.toDouble() ?? 60;
    final agePref =
        (minAge1 <= age2 && age2 <= maxAge1) &&
        (minAge2 <= age1 && age1 <= maxAge2);
    score += agePref ? 1.0 : 0.0;
    factors++;

    // 3. Age diff
    final ageDiff = (age1 - age2).abs();
    score += ageDiff <= 3
        ? 1.0
        : ageDiff <= 7
        ? 0.7
        : ageDiff <= 12
        ? 0.4
        : 0.1;
    factors++;

    // 4. Game style compatibility
    final s1 = u1['gameStyle'] as String? ?? '';
    final s2 = u2['gameStyle'] as String? ?? '';
    if (s1 == s2) {
      score += 1.0;
    } else if ((s1 == 'Competitive' && s2 == 'Pro Player') ||
        (s1 == 'Pro Player' && s2 == 'Competitive') ||
        (s1 == 'Casual' && s2 == 'Vừa chơi vừa học') ||
        (s1 == 'Vừa chơi vừa học' && s2 == 'Casual')) {
      score += 0.8;
    } else {
      score += 0.3;
    }
    factors++;

    // 5. Shared games (Jaccard)
    final g1s = Set<String>.from((u1['games'] as List?)?.cast<String>() ?? []);
    final g2s = Set<String>.from((u2['games'] as List?)?.cast<String>() ?? []);
    final union = g1s.union(g2s).length;
    final intersect = g1s.intersection(g2s).length;
    score += union > 0 ? intersect / union : 0.0;
    factors++;

    // 6. Shared interests (Jaccard)
    final i1s = Set<String>.from(
      (u1['interests'] as List?)?.cast<String>() ?? [],
    );
    final i2s = Set<String>.from(
      (u2['interests'] as List?)?.cast<String>() ?? [],
    );
    final uI = i1s.union(i2s).length;
    final iI = i1s.intersection(i2s).length;
    score += uI > 0 ? iI / uI : 0.0;
    factors++;

    // 7. Win rate diff (skill)
    final wr1 = (u1['winRate'] as num?)?.toDouble() ?? 50;
    final wr2 = (u2['winRate'] as num?)?.toDouble() ?? 50;
    final wrDiff = (wr1 - wr2).abs();
    score += wrDiff <= 10
        ? 1.0
        : wrDiff <= 25
        ? 0.6
        : wrDiff <= 40
        ? 0.3
        : 0.1;
    factors++;

    // 8. Same looking for
    final lf1 = u1['lookingFor'] as String? ?? '';
    final lf2 = u2['lookingFor'] as String? ?? '';
    score += lf1 == lf2 ? 1.0 : 0.3;
    factors++;

    // 9. Location — same city hoặc cùng vùng
    final lat1 = (u1['lat'] as num?)?.toDouble() ?? 0;
    final lng1 = (u1['lng'] as num?)?.toDouble() ?? 0;
    final lat2 = (u2['lat'] as num?)?.toDouble() ?? 0;
    final lng2 = (u2['lng'] as num?)?.toDouble() ?? 0;
    final approxDist =
        (((lat1 - lat2) * 111).abs() + ((lng1 - lng2) * 111).abs());
    score += approxDist < 5
        ? 1.0
        : approxDist < 30
        ? 0.7
        : approxDist < 100
        ? 0.4
        : 0.1;
    factors++;

    return factors > 0 ? score / factors : 0.5;
  }

  // ════════════════════════════════════════════════════════════════
  // TẠO MATCHES từ mutual likes
  // ════════════════════════════════════════════════════════════════
  Future<void> _createMatchesFromMutualLikes(
    List<Map<String, dynamic>> users,
  ) async {
    _logger.i('\n=== TẠO MATCHES TỪ MUTUAL LIKES ===');

    // Load tất cả swipe_latest để tìm mutual
    final swipeSnap = await _firestore.collection('swipe_latest').get();
    final swipeMap = <String, String>{}; // "u1_u2" → action

    for (final doc in swipeSnap.docs) {
      final data = doc.data();
      if (data['_isTestData'] == true) {
        final key = '${data['userId']}_${data['targetUserId']}';
        swipeMap[key] = data['action'] as String;
      }
    }

    int matchCount = 0;
    final processed = <String>{};

    for (final u1 in users) {
      for (final u2 in users) {
        final id1 = u1['uid'] as String;
        final id2 = u2['uid'] as String;
        if (id1 == id2) continue;

        final pairKey = [id1, id2]..sort();
        final pairStr = pairKey.join('_');
        if (processed.contains(pairStr)) continue;
        processed.add(pairStr);

        final k12 = '${id1}_$id2';
        final k21 = '${id2}_$id1';
        final a12 = swipeMap[k12];
        final a21 = swipeMap[k21];

        if (a12 == 'like' && a21 == 'like') {
          // Mutual like → tạo match
          final compatibility = _computeCompatibility(u1, u2);
          final status = compatibility >= 0.6 ? 'confirmed' : 'cancelled';

          await _firestore.collection('matches').add({
            'userIds': [id1, id2],
            'status': status,
            'isActive': status == 'confirmed',
            'game': (u1['games'] as List).isNotEmpty
                ? (u1['games'] as List).first
                : 'Liên Quân Mobile',
            'confirmations': {id1: true, id2: true},
            'createdAt': DateTime.now().toIso8601String(),
            'matchedAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
            'expiresAt': DateTime.now()
                .add(const Duration(days: 1))
                .toIso8601String(),
            'cancelledAt': status == 'cancelled'
                ? DateTime.now().toIso8601String()
                : null,
            '_compatScore': compatibility,
            '_isTestData': true,
          });

          matchCount++;
          _logger.i(
            '💕 Match: ${u1['displayName']} ↔ ${u2['displayName']} [$status]',
          );
        }
      }
    }

    _logger.i('\n✅ Created $matchCount matches');
  }

  // ════════════════════════════════════════════════════════════════
  // TẠO NHIỀU USERS + SWIPE DATA (gọi hàm này từ UI)
  // ════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> createMultipleUsers(int count) async {
    _logger.i('=== BẮT ĐẦU TẠO $count USERS + SWIPE DATA ===\n');

    final createdUsers = <Map<String, dynamic>>[];

    for (int i = 1; i <= count; i++) {
      final userData = await createRandomUser(i);
      if (userData != null) createdUsers.add(userData);

      await Future.delayed(const Duration(milliseconds: 500));

      if (i % 10 == 0) {
        _logger.i('--- Đã tạo $i/$count users ---');
      }
    }

    _logger.i('\n✅ Users: ${createdUsers.length}/$count');

    // ⭐ Tạo swipe data sau khi có đủ users
    if (createdUsers.length >= 2) {
      await createRealisticSwipeData(createdUsers);
    }

    _logger.i('\n=== HOÀN TẤT ===');
    _logger.i('Users    : ${createdUsers.length}');
    _logger.i(
      'Tổng cặp swipe có thể tạo: '
      '${createdUsers.length * (createdUsers.length - 1)} pairs',
    );
    _logger.i('→ Chạy collect_from_firebase.py để lấy data train model!');

    return createdUsers;
  }

  // ════════════════════════════════════════════════════════════════
  // EXPORT LOG
  // ════════════════════════════════════════════════════════════════

  void exportUsersList(List<Map<String, dynamic>> users) {
    _logger.i('\n=== DANH SÁCH USERS ===\n');
    for (int i = 0; i < users.length; i++) {
      final u = users[i];
      _logger.i(
        '${i + 1}. ${u['email']} | ${u['displayName']} | '
        '${u['age']}t ${u['gender']} | ${u['city']} | '
        '${u['rank']} | ${u['gameStyle']} | '
        'games: ${(u['games'] as List).join(', ')}',
      );
    }
  }

  // ════════════════════════════════════════════════════════════════
  // XÓA TEST DATA
  // ════════════════════════════════════════════════════════════════

  Future<void> deleteAllTestUsers() async {
    _logger.i('=== XÓA TEST USERS ===');

    // Xóa users
    final userSnap = await _firestore
        .collection('users')
        .where('isTestAccount', isEqualTo: true)
        .get();
    for (final doc in userSnap.docs) {
      await doc.reference.delete();
    }
    _logger.i('✓ Đã xóa ${userSnap.docs.length} users');

    // Xóa swipe_history test
    final swipeSnap = await _firestore
        .collection('swipe_history')
        .where('_isTestData', isEqualTo: true)
        .get();
    for (final doc in swipeSnap.docs) {
      await doc.reference.delete();
    }
    _logger.i('✓ Đã xóa ${swipeSnap.docs.length} swipe records');

    // Xóa swipe_latest test
    final latestSnap = await _firestore
        .collection('swipe_latest')
        .where('_isTestData', isEqualTo: true)
        .get();
    for (final doc in latestSnap.docs) {
      await doc.reference.delete();
    }
    _logger.i('✓ Đã xóa ${latestSnap.docs.length} swipe_latest records');

    // Xóa matches test
    final matchSnap = await _firestore
        .collection('matches')
        .where('_isTestData', isEqualTo: true)
        .get();
    for (final doc in matchSnap.docs) {
      await doc.reference.delete();
    }
    _logger.i('✓ Đã xóa ${matchSnap.docs.length} matches');

    _logger.w(
      '⚠️  Vào Firebase Auth Console để xóa thủ công các test accounts',
    );
  }
}
