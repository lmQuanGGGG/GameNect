/**
 * botDailyMentorApply — Scheduled Cloud Function (mỗi ngày lúc 10h sáng)
 *
 * Mỗi ngày chọn ngẫu nhiên 1-3 bot v5_perfect chưa là mentor (≤7 ngày tuổi):
 * - Tạo bio + achievements ngẫu nhiên, unique per bot (không trùng cụm 2 từ)
 * - Đăng ký mentor + auto approve
 * - Đăng 1 ảnh từ additionalPhotos của bot đó lên mentor_media
 * - Xóa ảnh đã đăng khỏi additionalPhotos để không bị lặp
 */

const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

const BOT_ACTIVE_DAYS = 14;
const MIN_APPLY = 1;
const MAX_APPLY = 3;

// ─── POOLS SINH BIO UNIQUE ───────────────────────────────────────────────────
// Mỗi slot có 40+ lựa chọn → kết hợp với username/game riêng = triệu tổ hợp
// Bot's username & game được embed vào text → đảm bảo không trùng cụm 2 từ
// giữa các bios khác nhau (vì username là unique)

const OPENERS = [
  (n, g) => `${n} đây, dân chơi ${g} lâu năm. Bây giờ muốn truyền lại chút kinh nghiệm tích lũy được.`,
  (n, g) => `Xin chào, mình là ${n}! Mình theo ${g} từ hồi server mới ra và chưa bỏ đến giờ.`,
  (n, g) => `Tên ${n}, gắn bó với ${g} khá lâu. Biết nhiều thứ hay ho trong game muốn chia sẻ.`,
  (n, g) => `Hey, ${n} nè. Không ngờ mình lại ngồi đây viết đăng ký mentor nhỉ, nhưng ${g} mình tự tin lắm.`,
  (n, g) => `Chào cả nhà, ${n} ở đây! ${g} là game mình dành nhiều thời gian nhất từ trước tới nay.`,
  (n, g) => `${n} đây mọi người ơi. Cũng mạnh dạn đăng ký mentor vì thấy mình hiểu ${g} khá sâu rồi.`,
  (n, g) => `Hi, mình là ${n}. Chơi ${g} từ thời beta, muốn giúp các bạn mới tiếp cận game dễ hơn.`,
  (n, g) => `Mình là ${n}, say mê ${g} ngay từ lần đầu thử. Giờ thấy mình đủ tự tin để chia sẻ rồi.`,
  (n, g) => `${n} xin phép tự giới thiệu nhé. Mình trải qua rất nhiều mùa rank với ${g} rồi.`,
  (n, g) => `Mọi người gọi mình là ${n}. ${g} với mình không chỉ là game, là cả một phần cuộc sống.`,
  (n, g) => `Cho phép ${n} tự ứng cử một chút. ${g} là thứ mình đổ không biết bao nhiêu giờ vào đó.`,
  (n, g) => `${n} đây nè, rón rén đăng ký mentor vì ${g} thật sự là thứ mình tâm đắc nhất.`,
  (n, g) => `Chào ace, ${n} muốn thử sức vai trò mentor! ${g} là game mình theo dõi từng bản cập nhật.`,
  (n, g) => `Tự giới thiệu nha, ${n} đây. Mình đến với ${g} từ rất sớm và chưa bao giờ hối hận.`,
  (n, g) => `${n} nói thiệt lòng: ${g} là game mình hiểu nhất, thích nhất, và sẵn sàng kèm nhất.`,
  (n, g) => `Xin giới thiệu, ${n} nè! Mình đã đi qua nhiều thăng trầm cùng ${g} và học được nhiều thứ.`,
  (n, g) => `Mình là ${n}, team ${g} từ đầu đến cuối. Kinh nghiệm tích lũy đủ để chia sẻ rồi.`,
  (n, g) => `Hú hú, ${n} đây nè. ${g} không phải game mình chơi giỏi nhất, nhưng chắc chắn hiểu sâu nhất.`,
  (n, g) => `${n} đăng ký mentor cho ${g} đây! Đã ngồi quan sát meta và gameplay khá lâu rồi.`,
  (n, g) => `Chào bạn, ${n} ở đây. Mình nhận thấy nhiều người mới vào ${g} còn lúng túng nên muốn giúp.`,
  (n, g) => `${n} xin chào! Chơi ${g} mãi thành quen, giờ muốn truyền kinh nghiệm lại cho người sau.`,
  (n, g) => `Mọi người, ${n} muốn đăng ký làm mentor nhé. Game ${g} mình bỏ không ít công sức vào đó.`,
  (n, g) => `Ký tên ${n} dưới đây nhé. ${g} là game tôi trung thành nhất từ trước đến nay.`,
  (n, g) => `Hola, ${n} đây nà. ${g} với mình như người bạn đồng hành, biết rõ từng ngóc ngách.`,
  (n, g) => `${n} muốn đóng góp thêm cho cộng đồng ${g}. Mình học nhiều từ người đi trước, nay tới lượt mình.`,
  (n, g) => `Xin tự giới thiệu, mình là ${n}. ${g} là nơi mình bỏ nhiều tâm huyết nhất trong giới gaming.`,
  (n, g) => `${n} đây, muốn thử vai trò mentor trong ${g}. Mình nghĩ kinh nghiệm của mình có thể giúp ích.`,
  (n, g) => `Chào mừng bạn ghé hồ sơ của ${n}! ${g} là đam mê lớn nhất và mình muốn lan tỏa nó.`,
  (n, g) => `${n} đây nè, hơi run nhưng vẫn tự tin đăng ký mentor ${g}. Mình biết mình có gì để dạy.`,
  (n, g) => `Mình là ${n}, và ${g} là game mình chưa bao giờ mệt mỏi dù chơi bao nhiêu giờ đi nữa.`,
  (n, g) => `Xin lỗi nếu ${n} hơi dài dòng nhé, nhưng mình muốn giải thích vì sao chọn mentor ${g}.`,
  (n, g) => `${n} tự tin đăng ký đây! ${g} là game mình dành nhiều công sức nghiên cứu hơn bất cứ thứ gì.`,
  (n, g) => `Gặp nhau là duyên, ${n} đây. Mình chọn ${g} vì đây là nơi mình thật sự trưởng thành trong gaming.`,
  (n, g) => `Á à, ${n} bạo dạn lên đây đăng ký mentor nè. ${g} là địa bàn quen thuộc nhất của mình.`,
  (n, g) => `${n} muốn thử đóng vai người dẫn dắt trong ${g}. Đã đủ trải nghiệm để nhìn lại và chia sẻ.`,
  (n, g) => `Xin giới thiệu qua về ${n} nha. Mình không phải cao thủ số một, nhưng ${g} mình hiểu rất rõ.`,
  (n, g) => `${n} đây mọi người. Mình đến với ${g} từ hồi game chưa hot và gắn bó cho tới bây giờ.`,
  (n, g) => `Chào ace, ${n} đây nè! ${g} là thứ mình hứa sẽ không bỏ dù meta có thay đổi thế nào.`,
  (n, g) => `Mình là ${n}, và lý do đăng ký mentor ${g} rất đơn giản: mình yêu game này và muốn giúp người khác.`,
  (n, g) => `${n} ở đây rồi nè. Theo ${g} khá lâu, đủ để thấy game này có chiều sâu hơn người ngoài nghĩ.`,
];

const MIDDLES = [
  (r) => `Rank hiện tại ${r}, nhưng mình coi trọng gameplay hơn con số rank.`,
  (r) => `Đang ở ${r}, từng leo từ dưới lên và biết rõ cảm giác cần người chỉ dẫn.`,
  (r) => `${r} là rank mình maintain, nhưng điều mình tự hào hơn là hiểu sâu về game.`,
  (r) => `Mình đạt ${r} sau nhiều mùa nỗ lực, cũng từng mắc nhiều lỗi trước khi tìm ra cách chơi đúng.`,
  (r) => `Con đường lên ${r} không trải hoa hồng, nhưng nhờ vậy mình tích lũy được nhiều kinh nghiệm thực chiến.`,
  (r) => `Rank ${r} hiện tại. Mình không chỉ chơi để win mà thực sự nghiên cứu từng chi tiết nhỏ.`,
  (r) => `Đạt ${r} rồi nhưng vẫn tiếp tục học mỗi ngày, vì mình tin không có giới hạn nào trong gaming.`,
  (r) => `Rank của mình là ${r}. Hành trình leo rank dạy mình nhiều hơn bất kỳ video hướng dẫn nào.`,
  (r) => `${r} là thành quả sau nhiều thất bại. Chính những trận thua đó giúp mình hiểu game hơn.`,
  (r) => `Hiện mình đang rank ${r}. Không phải ngày nào cũng smooth nhưng mình luôn rút ra được bài học.`,
  (r) => `Mình dừng lại ở ${r} một thời gian để phân tích kỹ lưỡng trước khi leo tiếp.`,
  (r) => `${r} là mốc mình tự hào vì biết mình đã bỏ bao nhiêu công để đạt được.`,
  (r) => `Từng kẹt mãi ở rank thấp, nhưng nhờ kiên trì và đổi cách tiếp cận, mình lên được ${r}.`,
  (r) => `${r} không tự nhiên mà có, đó là kết quả của hàng trăm giờ nghiêm túc với game.`,
  (r) => `Mình đang duy trì ${r} và thỉnh thoảng thử đẩy lên cao hơn để xem giới hạn bản thân.`,
  (r) => `Rank ${r} mình giữ khá ổn định, không leo nóng vội mà chú trọng hiểu sâu từng kỹ năng.`,
  (r) => `Đến ${r} mình mới thật sự thấy game depth như thế nào. Rank cao không có nghĩa là biết tất cả.`,
  (r) => `${r} là bước đệm để mình nhìn lại toàn bộ hành trình và muốn chia sẻ những gì đã học.`,
  (r) => `Từng thất bại rất nhiều trước khi chạm ${r}. Giờ mình muốn giúp người khác đỡ phải đi đường vòng.`,
  (r) => `Rank ${r} là điểm mình ổn định sau nhiều mùa, giờ muốn tập trung vào việc hướng dẫn hơn là leo.`,
  (r) => `Mình có ${r} trong tay. Không phải khoe, chỉ muốn nói mình đã trải qua đủ mọi tình huống game.`,
  (r) => `Con số ${r} chỉ là một phần, điều quan trọng hơn là mình biết vì sao mình thắng và thua mỗi trận.`,
  (r) => `Đạt được ${r} nhờ tập trung vào fundamentals. Đó là thứ mình muốn truyền đạt nhất.`,
  (r) => `${r} không phải đỉnh nhưng là nơi mình thấy mình đã hiểu đủ để dạy người khác.`,
  (r) => `Mình ở ${r} và vẫn tiếp tục cải thiện mỗi ngày. Game này không có điểm kết thúc để học.`,
  (r) => `Sau khi đạt ${r}, mình nhận ra điều mình muốn làm hơn là giúp người khác phát triển kỹ năng.`,
  (r) => `${r} là rank mình nghĩ đủ để chia sẻ kinh nghiệm có giá trị mà không bị lệch lạc bởi lý thuyết suông.`,
  (r) => `Mình duy trì ${r} trong nhiều mùa, đủ để biết đâu là quyết định quan trọng trong game.`,
  (r) => `Từ rank thấp leo lên ${r} mình học được rất nhiều điều mà không có video nào dạy đủ.`,
  (r) => `${r} là nơi mình dừng lại để nhìn xuống và suy nghĩ xem mình đã đi qua những gì.`,
];

const TEACHINGS = [
  () => `Mình thích giải thích theo kiểu thực tiễn, ít lý thuyết, nhiều ví dụ từ trận thật.`,
  () => `Phong cách của mình là kiên nhẫn, không rushh người học, cứ từ từ mà chắc.`,
  () => `Mình dạy theo kiểu phân tích từng quyết định, tại sao làm vậy chứ không chỉ làm thế nào.`,
  () => `Thích kèm những bạn chịu nghe feedback và không ngại sửa thói quen cũ.`,
  () => `Mình ưu tiên dạy mindset trước, kỹ năng sau. Đầu óc đúng thì tay theo được.`,
  () => `Cách của mình là cùng review replay, chỉ ra điểm có thể cải thiện một cách cụ thể.`,
  () => `Mình không judge kỹ năng người học, chỉ tìm điểm yếu cần fix và làm từng bước.`,
  () => `Giảng giải theo kiểu storytelling, biến lý thuyết khô khan thành những câu chuyện dễ nhớ.`,
  () => `Mình thích trao đổi hai chiều, không chỉ nói người học nghe mà cùng nhau phân tích.`,
  () => `Phong cách kèm của mình khá chill, không áp lực nhưng vẫn đảm bảo người học tiến bộ rõ ràng.`,
  () => `Mình tin vào việc lặp lại bài tập cơ bản thật thuần thục hơn là học nhiều thứ một lúc.`,
  () => `Thích encourage người học hơn là chỉ trích. Tiến bộ nhỏ cũng đáng được ghi nhận.`,
  () => `Mình quan sát gameplay của người học kỹ trước khi đưa ra nhận xét, không vội kết luận.`,
  () => `Phương pháp của mình là so sánh trước và sau để người học thấy sự khác biệt rõ ràng.`,
  () => `Mình thích customize cách dạy theo từng người, không dùng chung một công thức cho tất cả.`,
  () => `Giải thích bằng những thứ gần gũi trong cuộc sống, không chỉ dùng thuật ngữ game khó hiểu.`,
  () => `Mình tập trung vào những sai lầm phổ biến nhất mà người mới hay gặp, fix cái đó trước.`,
  () => `Cách dạy của mình dựa trên hỏi và đáp nhiều hơn là giảng một chiều.`,
  () => `Mình để người học tự thử trước rồi mới can thiệp, vì tự mình trải nghiệm mới thật sự hiểu.`,
  () => `Không có học trò nào giống học trò nào, mình luôn lắng nghe trước khi đưa ra hướng dẫn.`,
  () => `Mình muốn người học ra về không chỉ biết cách làm mà hiểu tại sao phải làm như vậy.`,
  () => `Phong cách của mình là vừa chỉ vừa giải thích, không bao giờ làm thay mà không nói rõ lý do.`,
  () => `Mình hay dùng hình thức thử thách nhỏ để kiểm tra và củng cố kiến thức người học.`,
  () => `Thích tạo môi trường thoải mái để người học dám hỏi bất kỳ câu hỏi nào, dù cơ bản đến đâu.`,
  () => `Cách dạy của mình luôn bắt đầu từ cái nền tảng, không nhảy vào nâng cao khi cơ bản chưa vững.`,
  () => `Mình dạy bằng cách đặt người học vào tình huống thực tế, không chỉ lý thuyết trên giấy.`,
  () => `Thích làm gương trực tiếp trong game hơn là chỉ mô tả bằng lời.`,
  () => `Mình rất cởi mở với feedback từ người học, muốn cải thiện cách dạy liên tục.`,
  () => `Kèm theo kiểu bạn bè chứ không phải thầy-trò cứng nhắc, cởi mở và thoải mái hơn.`,
  () => `Mình chú ý đến tiến độ của từng người học và điều chỉnh bài học cho phù hợp.`,
];

const CLOSINGS = [
  () => `Mong được gặp các bạn muốn nghiêm túc cải thiện game. Cùng nhau tiến bộ nào!`,
  () => `Nếu bạn muốn lên tay trong game này, mình sẵn sàng đồng hành.`,
  () => `Hẹn gặp ai muốn học nghiêm túc. Mình không từ chối ai có tinh thần cầu tiến.`,
  () => `Dù bạn đang ở level nào, mình tin mình có thể giúp bạn nhìn game theo cách mới.`,
  () => `Hy vọng sẽ có cơ hội chia sẻ những gì mình biết với cộng đồng.`,
  () => `Cứ nhắn tin nếu bạn cần, mình luôn sẵn sàng hỗ trợ.`,
  () => `Không ngại hỏi, mình ở đây để giúp chứ không phải để judge.`,
  () => `Mong được truyền lại những gì mình học được cho thế hệ sau trong game này.`,
  () => `Nếu bạn đang cần một người dẫn dắt trong game, mình nghĩ mình là lựa chọn không tệ.`,
  () => `Sẵn sàng hướng dẫn bất kỳ ai có tâm học hỏi, cấp độ không quan trọng.`,
  () => `Mình rất vui nếu được đồng hành cùng bạn trên hành trình cải thiện kỹ năng.`,
  () => `Cảm ơn đã đọc đến đây, hy vọng chúng ta sẽ có dịp chơi cùng và học cùng nhau.`,
  () => `Đây là lần đầu mình đăng ký mentor nhưng mình sẽ cố hết sức để không phụ lòng tin.`,
  () => `Mình sẽ làm hết sức để mỗi buổi kèm đều có giá trị thực sự với người học.`,
  () => `Đừng ngại thử, mình cam kết sẽ đưa ra nhận xét chân thực và có ích nhất có thể.`,
  () => `Hy vọng qua mentor này, mình đóng góp được chút gì cho cộng đồng game mình yêu thích.`,
  () => `Bất kỳ câu hỏi nào, dù nhỏ hay lớn, mình đều sẵn sàng trả lời hết mình.`,
  () => `Mình tin rằng ai cũng có thể giỏi hơn nếu được chỉ đúng cách. Hãy để mình giúp bạn.`,
  () => `Xin cảm ơn ban tổ chức và hy vọng được duyệt để mình có thể bắt đầu hành trình mentor.`,
  () => `Cùng nhau leo rank và chinh phục những thử thách phía trước nhé!`,
];

const ACHIEVE_OPENERS = [
  (r, g) => `Rank ${r} trong ${g} sau nhiều mùa nỗ lực.`,
  (r, g) => `Đạt ${r} ở ${g}, trải qua hàng trăm trận thực chiến.`,
  (r, g) => `${r} player ${g}, từng leo từ rank đáy lên.`,
  (r, g) => `Maintain ${r} trong ${g} nhiều mùa liên tiếp.`,
  (r, g) => `${g} rank ${r}, tập trung vào gameplay research.`,
  (r, g) => `Đạt mốc ${r} tại ${g} và tiếp tục cải thiện.`,
  (r, g) => `${r} rank chính thức trong ${g} season hiện tại.`,
  (r, g) => `Leo được ${r} ở ${g} nhờ chăm chỉ và phân tích kỹ.`,
  (r, g) => `${g} main với rank ${r}, đã trải nhiều meta khác nhau.`,
  (r, g) => `Đứng ${r} trong bảng xếp hạng ${g} của server.`,
  (r, g) => `Top ${r} player ${g} theo nhiều mùa giải.`,
  (r, g) => `${r} ở ${g}, con số đến từ nhiều tháng rèn luyện nghiêm túc.`,
  (r, g) => `${g} rank ${r} — thành tích mình tự hào nhất hiện tại.`,
  (r, g) => `Đạt ${r} ở ${g} sau khi thay đổi hoàn toàn cách tiếp cận game.`,
  (r, g) => `${r} là điểm dừng hiện tại trong ${g}, tiếp tục học để vươn xa hơn.`,
];

const ACHIEVE_EXTRAS = [
  () => `Từng tổ chức nhiều buổi chơi nhóm và hướng dẫn bạn bè mới.`,
  () => `Chuyên phân tích replay và rút kinh nghiệm sau mỗi trận thua.`,
  () => `Theo dõi và học hỏi từ các streamer và pro player hàng đầu.`,
  () => `Thành thạo nhiều vị trí và playstyle khác nhau trong game.`,
  () => `Đã tham gia nhiều giải đấu nội bộ và giải thân thiện.`,
  () => `Nghiên cứu kỹ meta của mỗi patch và adapt nhanh chóng.`,
  () => `Giúp không ít bạn bè leo rank thành công trong thời gian ngắn.`,
  () => `Có kinh nghiệm duo với nhiều kiểu chơi khác nhau.`,
  () => `Từng tự xây dựng spreadsheet theo dõi winrate theo từng champion/hero.`,
  () => `Kỹ năng shot-calling và game sense được đánh giá cao trong team.`,
  () => `Đã trải qua đủ mọi phase của game, từ early đến late game.`,
  () => `Hiểu rõ tầm quan trọng của vision control và objective trading.`,
  () => `Thành thạo wave management và các kỹ thuật farming nâng cao.`,
  () => `Có khả năng đọc map và dự đoán hành động đối thủ khá tốt.`,
  () => `Từng mentee nhiều bạn và thấy họ cải thiện rõ rệt sau vài buổi.`,
  () => `Giỏi adapt theo teammate và điều chỉnh chiến thuật linh hoạt.`,
  () => `Nắm vững lý thuyết về draft/pick và counter-pick.`,
  () => `Thường xuyên xem VOD review để cải thiện bản thân mỗi ngày.`,
  () => `Kinh nghiệm play với nhiều rank khác nhau giúp mình hiểu mọi level.`,
  () => `Biết cách xây dựng lộ trình học tập phù hợp với từng người.`,
];

const ACHIEVE_CLOSINGS = [
  () => `Sẵn sàng chia sẻ tất cả những gì mình biết với người học.`,
  () => `Mong đây là bước đầu để đóng góp cho cộng đồng game.`,
  () => `Hướng tới việc giúp người học tiến bộ thực sự chứ không chỉ lý thuyết.`,
  () => `Cam kết dành thời gian và tâm huyết cho từng người được kèm.`,
  () => `Luôn cập nhật kiến thức mới để đưa ra lời khuyên phù hợp nhất.`,
  () => `Tin rằng ai cũng có thể cải thiện nếu được hướng dẫn đúng cách.`,
  () => `Sẵn sàng đầu tư thời gian để giúp người học vượt qua điểm stuck.`,
  () => `Mong muốn tạo ra trải nghiệm học tốt và vui cho mọi người.`,
  () => `Đặt mục tiêu giúp ít nhất vài chục người leo rank thành công.`,
  () => `Kinh nghiệm thực chiến là thứ mình muốn truyền lại nhiều nhất.`,
  () => `Ưu tiên chất lượng buổi kèm hơn số lượng.`,
  () => `Luôn cởi mở học hỏi từ người học để mình cũng phát triển thêm.`,
  () => `Mục tiêu cuối cùng là giúp người học tự lực chứ không phụ thuộc mãi.`,
  () => `Sẵn sàng làm việc cùng bất kỳ ai có quyết tâm cải thiện.`,
  () => `Hy vọng sẽ tạo ra một cộng đồng nhỏ học game theo hướng lành mạnh.`,
];

function pickRandom(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function generateBioAndAchievements(bot) {
  const name = bot.username || "Mình";
  const games = bot.favoriteGames || [];
  const mainGame = games.length > 0 ? games[0] : "game yêu thích";
  const rank = bot.rank || "cao";

  // Mỗi bot pick random index khác nhau → unique vì username embed vào text
  const opener = pickRandom(OPENERS)(name, mainGame);
  const middle = pickRandom(MIDDLES)(rank);
  const teaching = pickRandom(TEACHINGS)();
  const closing = pickRandom(CLOSINGS)();

  const bio = `${opener}\n\n${middle} ${teaching}\n\n${closing}`;

  const achOpener = pickRandom(ACHIEVE_OPENERS)(rank, mainGame);
  const achExtra1 = pickRandom(ACHIEVE_EXTRAS)();
  const achExtra2 = pickRandom(ACHIEVE_EXTRAS.filter(f => f() !== achExtra1))();
  const achClosing = pickRandom(ACHIEVE_CLOSINGS)();

  const achievements = `${achOpener} ${achExtra1} ${achExtra2} ${achClosing}`;

  return { bio, achievements };
}

// ─── MAIN FUNCTION ────────────────────────────────────────────────────────────
exports.botDailyMentorApply = onSchedule(
  {
    schedule: "0 10 * * *",          // Mỗi ngày 10h sáng
    timeZone: "Asia/Ho_Chi_Minh",
    region: "asia-southeast1",
    memory: "256MiB",
    timeoutSeconds: 120,
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    // CHỈ CHẠY TRONG 14 NGÀY (từ 21/06/2026 đến 05/07/2026)
    const CUTOFF_DATE = new Date("2026-07-05T23:59:59+07:00").getTime();
    if (now.toMillis() > CUTOFF_DATE) {
      console.log("Đã hết thời hạn 7 ngày chạy auto mentor. Function sẽ không làm gì cả.");
      return;
    }

    // Lấy bot v5_perfect
    const eligibleSnap = await db.collection("users")
      .where("botVersion", "==", "v5_perfect")
      .get();

    const eligible = eligibleSnap.docs.filter(d => {
      const data = d.data();
      return data.isTestAccount === true && !data.isMentor && data.mentorStatus !== "approved";
    });

    if (eligible.length === 0) {
      console.log("Không có bot nào eligible để đăng ký mentor hôm nay.");
      return;
    }

    // Chọn ngẫu nhiên 1-3 bot
    const count = Math.floor(Math.random() * (MAX_APPLY - MIN_APPLY + 1)) + MIN_APPLY;
    const shuffled = [...eligible].sort(() => Math.random() - 0.5);
    const toApply = shuffled.slice(0, Math.min(count, eligible.length));

    console.log(`🎯 Hôm nay chọn ${toApply.length} bot để đăng ký mentor`);

    for (const botDoc of toApply) {
      const bot = botDoc.data();
      const botId = botDoc.id;

      try {
        const { bio, achievements } = generateBioAndAchievements(botData);
        const games = botData.favoriteGames || ["League of Legends"];

        // Tạo đánh giá và người theo dõi ảo
        const followerCount = Math.floor(Math.random() * (8 - 4 + 1)) + 4; // 4-8 followers
        const numRatings = Math.floor(Math.random() * (4 - 1 + 1)) + 1; // 1-4 ratings
        const stars = Array.from({length: numRatings}, () => Math.floor(Math.random() * (5 - 3 + 1)) + 3); // 3-5 stars
        const avgRating = stars.reduce((a, b) => a + b, 0) / stars.length;
        const roundedRating = Math.round(avgRating * 10) / 10;

        // 1. Tạo mentor_profiles với status approved
        await db.collection("mentor_profiles").doc(botId).set({
          userId: botId,
          username: botData.username || "",
          bio,
          games,
          achievements,
          status: "approved",
          appliedAt: now,
          approvedAt: now,
          followerCount: followerCount,
          rating: roundedRating,
          totalReviews: numRatings,
          totalStreams: 0,
          totalGiftsReceived: 0,
        });

        // Lấy 1 số bot để làm người thả tim/đánh giá
        const raterBots = bots.sort(() => Math.random() - 0.5);

        // Tạo fake followers trong mentor_followers
        const batch = db.batch();
        for (let i = 0; i < followerCount; i++) {
          const followerId = raterBots[i % raterBots.length].id;
          const docId = `${botId}_${followerId}`;
          const postDate = new Date(now.toMillis() - Math.floor(Math.random() * 24 * 60 * 60 * 1000));
          batch.set(db.collection('mentor_followers').doc(docId), {
            mentorId: botId,
            followerId: followerId,
            followedAt: admin.firestore.Timestamp.fromDate(postDate),
          });
        }

        // Tạo fake ratings
        for (let i = 0; i < numRatings; i++) {
          const raterId = raterBots[(i + followerCount) % raterBots.length].id;
          const postDate = new Date(now.toMillis() - Math.floor(Math.random() * 24 * 60 * 60 * 1000));
          batch.set(db.collection('mentor_ratings').doc(`${raterId}_${botId}`), {
            fromUserId: raterId,
            toMentorId: botId,
            rating: stars[i],
            comment: '',
            createdAt: admin.firestore.Timestamp.fromDate(postDate),
          });
        }
        await batch.commit();

        // 2. Update users doc
        await db.collection("users").doc(botId).update({
          isMentor: true,
          mentorStatus: "approved",
          isTestAccount: false,
        });

        // 3. Đăng 1 ảnh từ bot_photos_pool (ảnh đúng của người đó, từ JSONL đã import)
        const poolDoc = await db.collection("bot_photos_pool").doc(botId).get();
        const poolPhotos = poolDoc.exists ? (poolDoc.data().photos || []) : [];

        // Lấy ảnh đã đăng rồi để không lặp
        const postedSnap = await db.collection("mentor_media")
          .where("mentorId", "==", botId)
          .get();
        const postedUrls = new Set(postedSnap.docs.map(d => d.data().url));

        const availablePhotos = poolPhotos.filter(url => !postedUrls.has(url));

        if (availablePhotos.length > 0) {
          const photoUrl = availablePhotos[Math.floor(Math.random() * availablePhotos.length)];
          const postDate = new Date(now.toMillis() - Math.floor(Math.random() * 2 * 60 * 60 * 1000));

          await db.collection("mentor_media").add({
            mentorId: botId,
            type: "image",
            url: photoUrl,
            thumbnailUrl: null,
            caption: "",
            duration: null,
            month: `${postDate.getFullYear()}-${String(postDate.getMonth() + 1).padStart(2, "0")}`,
            createdAt: admin.firestore.Timestamp.fromDate(postDate),
            likes: [],
          });

          // Xóa ảnh đã dùng khỏi pool để không bị lặp lần sau
          await db.collection("bot_photos_pool").doc(botId).update({
            photos: admin.firestore.FieldValue.arrayRemove(photoUrl),
          });

          console.log(`   📸 Đăng ảnh mới cho mentor ${bot.username} (còn ${availablePhotos.length - 1} ảnh trong pool)`);
        } else {
          console.log(`   ⚠️ Bot ${bot.username} không còn ảnh trong pool`);
        }

        console.log(`✅ ${bot.username} (${botId}) → approved mentor!`);
      } catch (err) {
        console.error(`❌ Lỗi với bot ${bot.username}:`, err.message);
      }
    }

    console.log("botDailyMentorApply hoàn thành.");
  }
);
