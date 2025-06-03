// 📄 folder_home_page.dart - AccessToken 적용 & 리팩토링 버전
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'note_list_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FolderHomePage extends StatefulWidget {
  const FolderHomePage({super.key});

  static const background = Color(0xFFFFFFFF);
  static const cobaltBlue = Color(0xFF004377);

  @override
  State<FolderHomePage> createState() => _FolderHomePageState();
}

class _FolderHomePageState extends State<FolderHomePage> {
  List<Map<String, dynamic>> folders = [];
  List<bool> isEditing = [];
  List<TextEditingController> controllers = [];

  @override
  void initState() {
    super.initState();
    _fetchFolders();
  }

  @override
  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  Future<void> _fetchFolders() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) return;

    try {
      final response = await http.get(
        Uri.parse('http://172.16.11.249:8000/pdf/folders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          folders =
              data
                  .map((f) => {'id': f['folder_id'], 'name': f['name']})
                  .toList();
          controllers = List.generate(
            folders.length,
            (i) => TextEditingController(text: folders[i]['name']),
          );
          isEditing = List.filled(folders.length, false);
        });
      } else {
        debugPrint('❌ 폴더 목록 요청 실패: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ 폴더 목록 요청 예외: $e');
    }
  }

  Future<void> _createFolder() async {
    final folderName = _generateUniqueFolderName();
    final accessToken = await getAccessToken();
    if (accessToken == null) return;

    try {
      final response = await http.post(
        Uri.parse('http://172.16.11.249:8000/pdf/folders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'name': folderName}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _fetchFolders();
        Future.delayed(const Duration(milliseconds: 50), () {
          setState(() {
            isEditing[folders.length - 1] = true;
          });
        });
      } else {
        debugPrint('❌ 폴더 생성 실패: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ 폴더 생성 예외: $e');
    }
  }

  Future<void> _renameFolder(int folderId, String newName) async {
    final accessToken = await getAccessToken();
    if (accessToken == null) return;

    try {
      final response = await http.patch(
        Uri.parse('http://172.16.11.249:8000/pdf/folders/$folderId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'name': newName}),
      );

      if (response.statusCode == 200) {
        await _fetchFolders();
      } else {
        debugPrint('❌ 이름 변경 실패: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ 이름 변경 예외: $e');
    }
  }

  Future<void> _deleteFolder(int folderId) async {
    final accessToken = await getAccessToken();
    if (accessToken == null) return;

    try {
      final response = await http.delete(
        Uri.parse('http://172.16.11.249:8000/pdf/folders/$folderId'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        await _fetchFolders();
      } else {
        debugPrint('❌ 삭제 실패: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ 삭제 예외: $e');
    }
  }

  String _generateUniqueFolderName() {
    String baseName = '새 폴더';
    String newName = baseName;
    int counter = 1;
    while (folders.any((f) => f['name'] == newName)) {
      newName = '$baseName ($counter)';
      counter++;
    }
    return newName;
  }

  void _enterFolder(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => NoteListPage(
              folderId: folders[index]['id'],
              folderName: folders[index]['name'],
            ),
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.create_new_folder,
                  color: FolderHomePage.cobaltBlue,
                ),
                title: const Text('폴더'),
                onTap: () {
                  Navigator.pop(context);
                  _createFolder();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.upload_file,
                  color: FolderHomePage.cobaltBlue,
                ),
                title: const Text('불러오기'),
                onTap: () {
                  Navigator.pop(context);
                  debugPrint('📂 파일 불러오기 기능은 아직 구현되지 않았습니다.');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('폴더 삭제'),
            content: const Text('정말로 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteFolder(folders[index]['id']);
                },
                child: const Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  void _showFolderOptions(int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('이름 변경'),
              onTap: () {
                Navigator.pop(context);
                setState(() => isEditing[index] = true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('삭제'),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(index);
              },
            ),
          ],
        );
      },
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      backgroundColor: FolderHomePage.background,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const DrawerHeader(
            child: Text(
              '메뉴',
              style: TextStyle(fontSize: 20, color: FolderHomePage.cobaltBlue),
            ),
          ),
          ExpansionTile(
            title: const Text(
              'PDF',
              style: TextStyle(color: FolderHomePage.cobaltBlue),
            ),
            children: const [
              ListTile(title: Text('- A과목')),
              ListTile(title: Text('- B과목')),
              ListTile(title: Text('- PDF')),
            ],
          ),
          ListTile(
            title: const Text(
              'AI 학습플래너',
              style: TextStyle(color: FolderHomePage.cobaltBlue),
            ),
            onTap: () => Navigator.pushNamed(context, '/home'),
          ),
          const ListTile(
            title: Text(
              '스터디 타이머',
              style: TextStyle(color: FolderHomePage.cobaltBlue),
            ),
          ),
          const ListTile(
            title: Text(
              '마이페이지',
              style: TextStyle(color: FolderHomePage.cobaltBlue),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FolderHomePage.background,
      appBar: AppBar(
        title: const Text(
          'iPlanner',
          style: TextStyle(color: FolderHomePage.cobaltBlue),
        ),
        backgroundColor: FolderHomePage.background,
        iconTheme: const IconThemeData(color: FolderHomePage.cobaltBlue),
        elevation: 0,
      ),
      drawer: _buildDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 16,
          childAspectRatio: 1,
          children: List.generate(
            folders.length,
            (index) => _buildFolder(index),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: FolderHomePage.cobaltBlue,
        onPressed: () => _showAddOptions(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFolder(int index) {
    return GestureDetector(
      onTap: () => _enterFolder(index),
      onLongPress: () => _showFolderOptions(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder, size: 48, color: FolderHomePage.cobaltBlue),
          const SizedBox(height: 8),
          isEditing[index]
              ? SizedBox(
                width: 80,
                height: 30,
                child: TextField(
                  controller: controllers[index],
                  autofocus: true,
                  onSubmitted: (value) {
                    _renameFolder(folders[index]['id'], value);
                    setState(() => isEditing[index] = false);
                  },
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              )
              : Text(
                folders[index]['name'],
                style: const TextStyle(color: FolderHomePage.cobaltBlue),
              ),
        ],
      ),
    );
  }
}
