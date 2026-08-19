import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const ZingMusicApp());
}

class ZingMusicApp extends StatelessWidget {
  const ZingMusicApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zing Music',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Dark iPhone Theme
        brightness: Brightness.dark,
      ),
      home: const MusicDashboard(),
    );
  }
}

class MusicDashboard extends StatefulWidget {
  const MusicDashboard({super.key});
  @override
  State<MusicDashboard> createState() => _MusicDashboardState();
}

class _MusicDashboardState extends State<MusicDashboard> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  List<SongModel> songs = [];
  bool hasPermission = false;
  SongModel? currentSong;

  @override
  void initState() {
    super.initState();
    checkAndRequestPermissions();
  }

  // 1. Permission aur Scanning (Voice recording hatane ka logic)
  void checkAndRequestPermissions() async {
    var status = await Permission.audio.status;
    if (status.isDenied) {
      status = await Permission.storage.request();
      status = await Permission.audio.request();
    }
    
    if (status.isGranted) {
      setState(() => hasPermission = true);
      
      // Sirf MUSIC fetch karega, alarms/ringtones/recordings ko ignore karega
      List<SongModel> fetchedSongs = await _audioQuery.querySongs(
        sortType: null,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
      
      // Filter: 1 minute se chhote audio (jaise WhatsApp audio/recordings) hata dega
      setState(() {
        songs = fetchedSongs.where((song) => (song.duration ?? 0) > 60000 && song.isMusic == true).toList();
      });
    }
  }

  // 2. Play Audio
  void playSong(SongModel song) async {
    setState(() => currentSong = song);
    await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(song.uri!)));
    _audioPlayer.play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Glow Effect (HTML jaisa)
          Positioned(
            top: -50, left: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withOpacity(0.15),
                boxShadow: [BoxShadow(blurRadius: 100, color: const Color(0xFF6366F1).withOpacity(0.15))]
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text.rich(TextSpan(
                    text: 'Zing ',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    children: [TextSpan(text: 'Music', style: TextStyle(color: Color(0xFF6366F1)))]
                  )),
                ),

                // Music List
                Expanded(
                  child: !hasPermission 
                    ? const Center(child: Text("Please allow storage permission to scan music."))
                    : songs.isEmpty 
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 100, left: 15, right: 15),
                          itemCount: songs.length,
                          itemBuilder: (context, index) {
                            final song = songs[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: QueryArtworkWidget(
                                  id: song.id,
                                  type: ArtworkType.AUDIO,
                                  nullArtworkWidget: const Icon(Icons.music_note, color: Colors.white54, size: 40),
                                ),
                                title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                                subtitle: Text(song.artist ?? "Unknown Artist", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                onTap: () => playSong(song),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // Mini Player (Niche chipka hua)
          if (currentSong != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(15),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    QueryArtworkWidget(
                      id: currentSong!.id,
                      type: ArtworkType.AUDIO,
                      nullArtworkWidget: const Icon(Icons.album, color: Colors.white, size: 40),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(currentSong!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          Text(currentSong!.artist ?? "Unknown", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                    StreamBuilder<PlayerState>(
                      stream: _audioPlayer.playerStateStream,
                      builder: (context, snapshot) {
                        final playing = snapshot.data?.playing ?? false;
                        return IconButton(
                          icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 35, color: Colors.white),
                          onPressed: () => playing ? _audioPlayer.pause() : _audioPlayer.play(),
                        );
                      }
                    )
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }
}
