import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'note_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';  // File 객체 사용 (모바일에서만 필요)


Map<int, List<Stroke>> pageStrokes = {};  // 썸네일 테스트용
const String baseUrl = 'http://localhost:8000'; // 또는 실제 서버 주소
const cobaltBlue = Color(0xFF004377);

//pdf 업로드 기능 때문에 모바일로만 실행 가능.
/// 노트 모델 클래스
class NoteItem {
  final int id;
  final String title;
  final String? updatedAt; 

  NoteItem({required this.id, required this.title, this.updatedAt,});

  factory NoteItem.fromJson(Map<String, dynamic> json) {
    return NoteItem(id: json['pdf_id'], title: json['title'], updatedAt: json['updated_at'],);
  }
}

/// 특정 폴더의 노트 리스트 및 생성 화면
class NoteListPage extends StatefulWidget {
  final int folderId;
  final String folderName;

  const NoteListPage({
    super.key,
    required this.folderId,
    required this.folderName,
  });

  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  List<NoteItem> notes = [];
  String _sortOption = '최신순';
  


  @override
  void initState() {
    super.initState();
    fetchNotes();
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  /// 노트 리스트 불러오기
  Future<void> fetchNotes() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) return;

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/pdf/notes/${widget.folderId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          notes = data.map((n) => NoteItem.fromJson(n)).toList();
          _sortNotes(); // 정렬 함수 호출 추가
        });
      } else {
        debugPrint('노트 목록 불러오기 실패: ${response.body}');
        setState(() => notes = []);
      }
    } catch (e) {
      debugPrint('예외 발생: $e');
      setState(() => notes = []);
    }
  }

  /// 노트 생성 다이얼로그 및 API 호출
  Future<void> createNote() async {
    final controller = TextEditingController();

    final title = await showDialog<String>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('노트 제목 입력'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: '예: 2주차 정리노트'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('확인'),
              ),
            ],
          ),
    );

    if (title == null || title.isEmpty) return;

    final accessToken = await getAccessToken();
    if (accessToken == null) return;

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/pdf/notes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'title': title, 'folder_id': widget.folderId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchNotes();
      } else {
        debugPrint('노트 생성 실패: ${response.body}');
        _showErrorDialog('노트 생성 실패', response.body);
      }
    } catch (e) {
      debugPrint('예외 발생: $e');
      _showErrorDialog('예외 발생', e.toString());
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFFF5F5F5),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const DrawerHeader(
            child: Text(
              '메뉴',
              style: TextStyle(fontSize: 20, color: cobaltBlue),
            ),
          ),
          ListTile(
            title: const Text('PDF', style: TextStyle(color: cobaltBlue)),
            onTap: () => Navigator.pushNamed(context, '/folder'),
          ),
          ListTile(
            title: const Text('홈', style: TextStyle(color: cobaltBlue)),
            onTap: () => Navigator.pushNamed(context, '/home'),
          ),
          ListTile(
            title: const Text('AI 학습플래너', style: TextStyle(color: cobaltBlue)),
            onTap: () => Navigator.pushNamed(context, '/submain'),
          ),
          ListTile(
            title: const Text('스터디 타이머', style: TextStyle(color:cobaltBlue)),
            onTap: () => Navigator.pushNamed(context, '/timer'),
          ),
          ListTile(
            title: const Text('마이페이지', style: TextStyle(color: cobaltBlue)),
            onTap: () => Navigator.pushNamed(context, '/mypage'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), 
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // 이전 페이지(FolderHomePage)로 정상 복귀
          },
        ),
              
        title: Text('${widget.folderName}',
        style: const TextStyle(color: Colors.black87),
        ),
        backgroundColor: const Color(0xFFF5F5F5),  // 배경 맞춤
        elevation: 0,                              // 그림자 없애 부드럽게
        iconTheme: const IconThemeData(color: Colors.black87), // 햄버거/뒤로가기 등 아이콘도 맞춤
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _sortOption = value;
                _sortNotes();
              });
            },
            icon: const Icon(Icons.sort, color: Colors.black87),
            itemBuilder: (context) => [
              const PopupMenuItem(value: '최신순', child: Text('최신순')),
              const PopupMenuItem(value: '이름순', child: Text('이름순')),
            ],
          ),

          
        ],
      ),
      drawer: _buildDrawer(),
      body: notes.isEmpty
          ? const Center(child: Text('노트가 없습니다. 추가해보세요!'))
          : ListView.builder(
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return Dismissible(
                  key: ValueKey(note.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.redAccent,
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // 카드 margin 맞춤
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 28, // ← 아이콘 크기 살짝 키워서 존재감 더 줌
                    ),
                  ),

                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('노트 삭제'),
                        content: Text('「${note.title}」 노트를 삭제할까요?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('삭제', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) async {
                    await deleteNote(note.id); 
                    setState(() => notes.removeAt(index)); // 리스트에서 제거
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${note.title} 삭제됨')),
                    );
                  },
                  child: NoteItemCard(
                    key: ValueKey(note.id),
                    note: note,
                    onNoteMoved: () {
                      setState(() {
                        notes.removeAt(index);  // 이동한 노트는 즉시 리스트에서 제거됨
                      });
                    }
                  ),
                );

              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (_) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.note_add),
                  title: const Text('빈 노트 추가'),
                  onTap: () {
                    Navigator.pop(context);
                    createNote();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: const Text('PDF 업로드'),
                  onTap: () {
                    Navigator.pop(context);
                    uploadPdfFile();
                  },
                ),
              ],
            ),
          );
        },
        backgroundColor: cobaltBlue, 
        child: const Icon(Icons.add),
      ),
    );
  }


  Future<void> _showNoteOptionsDialog(BuildContext context, int pdfId, String title, int index) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('노트 옵션'),
        content: Text('"$title" 노트에 대해 어떤 작업을 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await deleteNote(pdfId);
              setState(() => notes.removeAt(index));
            },
            child: Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }





  Future<void> uploadPdfFile() async {
    final typeGroup = XTypeGroup(
      label: 'PDF',
      extensions: ['pdf'],
    );

    final XFile? pickedFile = await openFile(acceptedTypeGroups: [typeGroup]);

    if (pickedFile != null && pickedFile.path.isNotEmpty) {
      final filePath = pickedFile.path;
      final fileName = pickedFile.name;

      final accessToken = await getAccessToken();
      final uri = Uri.parse('http://localhost:8000/pdf/upload');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $accessToken'
        ..fields['title'] = fileName
        ..fields['folder_id'] = widget.folderId.toString()
        ..files.add(await http.MultipartFile.fromPath('file', filePath));

      final response = await request.send();
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchNotes(); // 리스트 갱신
        final body = await response.stream.bytesToString();
        final json = jsonDecode(body);
        final pdfId = json['pdf_id'];
        final title = json['title'];

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NotePage(pdfId: pdfId, noteTitle: title),
          ),
        );
      } else {
        debugPrint('업로드 실패: ${response.statusCode}');
      }
    }
  }

    Future<void> deleteNote(int pdfId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    final response = await http.delete(
      Uri.parse('$baseUrl/pdf/notes/$pdfId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      debugPrint("노트 삭제 성공");
      // 삭제 후 노트 목록 다시 로드하거나 리스트에서 제거
    } else {
      debugPrint("노트 삭제 실패: ${response.statusCode}");
    }
  }

  void _sortNotes() {
    if (_sortOption == '최신순') {
      notes.sort((a, b) => b.id.compareTo(a.id)); // ID가 클수록 최신
    } else if (_sortOption == '이름순') {
      notes.sort((a, b) => a.title.compareTo(b.title)); // 사전순 정렬
    }
  }




}







class NoteItemCard extends StatefulWidget {
  final NoteItem note;
  final VoidCallback? onNoteMoved; // 추가

  const NoteItemCard({super.key, required this.note,this.onNoteMoved,});

  @override
  State<NoteItemCard> createState() => _NoteItemCardState();
}

class _NoteItemCardState extends State<NoteItemCard> {
  String? thumbnailUrl;
  int? firstPageId;

  @override
  void initState() {
    super.initState();
    loadThumbnailOrPageId();
  }

  Future<void> loadThumbnailOrPageId() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');
    if (accessToken == null) return;

    try {
      // 썸네일 먼저 시도
      final response = await http.get(
        Uri.parse('http://localhost:8000/pdf/pages/${widget.note.id}'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> pages = jsonDecode(utf8.decode(response.bodyBytes));
        if (pages.isNotEmpty) {
          final firstPage = pages[0];
          final imageUrl = firstPage['image_preview_url'];
          setState(() {
            if (imageUrl != null) {
              thumbnailUrl = 'http://localhost:8000$imageUrl';
            } else {
              firstPageId = firstPage['page_id'];
            }
          });
        }
      }
    } catch (e) {
      debugPrint('페이지 또는 썸네일 로드 실패: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    final Widget leadingWidget = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: thumbnailUrl != null
          ? Image.network(
              '${thumbnailUrl!}?timestamp=${DateTime.now().millisecondsSinceEpoch}', // 캐시 방지
              width: 60,
              height: 80,
              fit: BoxFit.cover,
            )
          : Image.asset(
              'assets/note_placeholder.png',
              width: 60,
              height: 80,
              fit: BoxFit.cover,
            ),
    );

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16), 
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NotePage(
                pdfId: widget.note.id,
                noteTitle: widget.note.title,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: thumbnailUrl != null
                    ? Image.network(
                        '$thumbnailUrl?timestamp=${DateTime.now().millisecondsSinceEpoch}',
                        width: 60,
                        height: 80,
                        fit: BoxFit.cover,
                      )
                    : Image.asset(
                        'assets/note_placeholder.png',
                        width: 60,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.note.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '수정일: ${_formatDate(widget.note.updatedAt)}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'move') {
                    _showMoveDialog(widget.note.id);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'move', child: Text('다른 폴더로 이동')),
                ],
                icon: const Icon(Icons.more_vert),
              ),

            ],
          ),
        ),
      ),
    );


  }

  String _formatDate(String? datetimeString) {
    if (datetimeString == null) return '알 수 없음';
    final dateTime = DateTime.tryParse(datetimeString);
    if (dateTime == null) return '알 수 없음';
    return '${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')}';
  }

  @override
  void didUpdateWidget(NoteItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note.id != widget.note.id) {
      thumbnailUrl = null;
      firstPageId = null;
      loadThumbnailOrPageId();  // 새 노트용 데이터 다시 로딩
    }
  }

  Future<void> _showMoveDialog(int noteId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    final response = await http.get(
      Uri.parse('http://localhost:8000/pdf/folders'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      debugPrint("폴더 목록 불러오기 실패");
      return;
    }

    final List folders = jsonDecode(utf8.decode(response.bodyBytes));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('다른 폴더로 이동'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                return ListTile(
                  title: Text(folder['name']),
                  onTap: () async {
                    await _moveNoteToFolder(noteId, folder['folder_id']);
                    Navigator.of(context).pop();

                    // 콜백 실행 (노트 리스트에서 즉시 제거)
                    if (widget.onNoteMoved != null) {
                      widget.onNoteMoved!();
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('「${widget.note.title}」이(가) 이동되었습니다.')),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

    Future<void> _moveNoteToFolder(int noteId, int newFolderId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    final response = await http.patch(
      Uri.parse('http://localhost:8000/pdf/notes/$noteId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'folder_id': newFolderId}),
    );

    if (response.statusCode == 200) {
      debugPrint("노트 이동 성공");
    } else {
      debugPrint("노트 이동 실패: ${response.statusCode}");
    }
  }





}
