import 'package:flutter/material.dart';
import '../services/rawg_service.dart';

class GameTagWidget extends StatefulWidget {
  final String gameName;
  const GameTagWidget({super.key, required this.gameName});

  @override
  State<GameTagWidget> createState() => _GameTagWidgetState();
}

class _GameTagWidgetState extends State<GameTagWidget> {
  static final Map<String, String> _imageCache = {};
  static final Map<String, Future<String?>> _inFlightRequests = {};

  String? _imageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchImage();
  }

  Future<void> _fetchImage() async {
    if (_imageCache.containsKey(widget.gameName)) {
      if (mounted) {
        setState(() {
          _imageUrl = _imageCache[widget.gameName];
          _isLoading = false;
        });
      }
      return;
    }

    Future<String?> requestFuture;
    if (_inFlightRequests.containsKey(widget.gameName)) {
      requestFuture = _inFlightRequests[widget.gameName]!;
    } else {
      requestFuture = _doFetch();
      _inFlightRequests[widget.gameName] = requestFuture;
    }

    final url = await requestFuture;
    if (mounted) {
      setState(() {
        _imageUrl = url;
        _isLoading = false;
      });
    }
  }

  Future<String?> _doFetch() async {
    try {
      final rawg = RawgService();
      final results = await rawg.searchGames(widget.gameName, pageSize: 1);
      if (results.isNotEmpty && results.first.backgroundImage != null) {
        final url = results.first.backgroundImage!;
        _imageCache[widget.gameName] = url;
        return url;
      }
    } catch (e) {
      // ignore
    } finally {
      _inFlightRequests.remove(widget.gameName);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
           BoxShadow(
             color: Colors.black,
             offset: Offset(2, 2),
           )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isLoading)
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepOrange))
          else if (_imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(_imageUrl!, width: 24, height: 24, fit: BoxFit.cover),
            )
          else
            const Icon(Icons.videogame_asset, size: 24, color: Colors.black),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.gameName,
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
