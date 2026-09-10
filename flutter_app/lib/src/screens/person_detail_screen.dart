import 'package:flutter/material.dart';
import '../models/tmdb_media_models.dart';
import '../services/tmdb_person_service.dart';
import '../services/tmdb_image.dart';
import '../widgets/optimized_network_image.dart';
import 'movie_detail_screen.dart';

class PersonDetailScreen extends StatefulWidget {
  PersonDetailScreen(
      {super.key, required this.member, TmdbPersonService? service})
      : service = service ?? TmdbPersonService();
  final CastItem member;
  final TmdbPersonService service;
  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  PersonDetail? _person;
  List<CastItem>? _matches;
  String? _error;
  bool _loading = true;
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _load(widget.member.id > 0 ? widget.member.id : null);
  }

  Future<void> _load(int? id) async {
    _selectedId = id;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (id == null) {
        final matches = await widget.service.search(widget.member.name);
        if (!mounted) return;
        setState(() {
          _matches = matches;
          _loading = false;
        });
      } else {
        final person = await widget.service.fetch(id);
        if (!mounted) return;
        setState(() {
          _person = person;
          _matches = null;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Could not load person details. Check TMDB in Integrations and your connection, then retry.';
      });
    }
  }

  Widget _photo(String? path, {double width = 120, double height = 180}) =>
      ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: width,
            height: height,
            child: path == null
                ? const ColoredBox(
                    color: Color(0xFF222222),
                    child: Icon(Icons.person_outline, size: 48))
                : OptimizedNetworkImage(
                    url: getImageUrl(path, 'w500'),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.person_outline, size: 48)),
          ));

  @override
  Widget build(BuildContext context) {
    final person = _person;
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
          backgroundColor: const Color(0xFF050505),
          title: Text(person?.name ?? widget.member.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!),
                        TextButton(
                            onPressed: () => _load(_selectedId),
                            child: const Text('Retry'))
                      ])))
              : _matches != null
                  ? ListView(children: [
                      const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Choose the matching person')),
                      if (_matches!.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('No matching people found.')),
                      for (final member in _matches!)
                        ListTile(
                            leading: _photo(member.profilePath,
                                width: 40, height: 56),
                            title: Text(member.name),
                            onTap: () => _load(member.id)),
                    ])
                  : person == null
                      ? const SizedBox.shrink()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                          children: [
                              Center(
                                  child: _photo(person.profilePath,
                                      width: 180, height: 270)),
                              const SizedBox(height: 24),
                              Text(person.name,
                                  style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold)),
                              for (final entry in {
                                'Known for': person.department,
                                'Born': person.birthday,
                                'Died': person.deathday,
                                'Birthplace': person.birthplace
                              }.entries)
                                if (entry.value?.isNotEmpty == true)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child:
                                          Text('${entry.key}: ${entry.value}')),
                              if (person.aliases.isNotEmpty)
                                Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                        'Also known as: ${person.aliases.join(', ')}')),
                              const SizedBox(height: 24),
                              const Text('Biography',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              Text(
                                  person.biography.isEmpty
                                      ? 'No biography available.'
                                      : person.biography,
                                  style: const TextStyle(height: 1.5)),
                              if (person.photos.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                SizedBox(
                                    height: 180,
                                    child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: person.photos.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(width: 12),
                                        itemBuilder: (_, index) =>
                                            _photo(person.photos[index]))),
                              ],
                              const SizedBox(height: 24),
                              const Text('Movies & TV shows',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold)),
                              if (person.credits.isEmpty)
                                const Text('No filmography available.'),
                              for (final credit in person.credits)
                                Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: _photo(credit.media.posterPath,
                                          width: 48, height: 72),
                                      title: Text(credit.media.title),
                                      subtitle: Text([
                                        credit.media.mediaType == 'tv'
                                            ? 'TV show'
                                            : 'Movie',
                                        if (credit.media.releaseDate.isNotEmpty)
                                          credit.media.releaseDate
                                              .split('-')
                                              .first,
                                        if (credit.role.isNotEmpty) credit.role
                                      ].join(' · ')),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (_) => MovieDetailScreen(
                                                  id: credit.media.id,
                                                  mediaType:
                                                      credit.media.mediaType,
                                                  fallbackTitle:
                                                      credit.media.title,
                                                  fallbackPosterPath: credit
                                                      .media.posterPath))),
                                    )),
                            ]),
    );
  }
}
