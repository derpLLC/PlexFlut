import 'package:pex_flut/src/model/image.dart';
import 'package:pex_flut/src/model/video.dart';
import '../../../data/repository/media_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'media_list_event.dart';
import 'media_list_state.dart';
import 'package:rxdart/rxdart.dart';

const photoCode = 0;
const videoCode = 1;

class MediaListBloc extends Bloc<MediaListEvent, MediaListState> {
  MediaRepository mediaRepository = MediaRepository();
  int currentPhotoPage = 1;
  int currentVideoPage = 1;
  String keyWord = '';
  int mediaTypeCode = photoCode;
  List<Photo> photos = [];
  List<Video> videos = [];
  MediaListBloc() : super(MediaListInitialState());

  @override
  Stream<Transition<MediaListEvent, MediaListState>> transformEvents(
      Stream<MediaListEvent> events,
      TransitionFunction<MediaListEvent, MediaListState> transitionFn,
      ) {
    return super.transformEvents(
      events.debounceTime(const Duration(milliseconds: 500)),
      transitionFn,
    );
  }

  @override
  Stream<MediaListState> mapEventToState(MediaListEvent event) async* {
    final currentState = state;
    if (event is MediaListTypeChangeEvent) {
      mediaTypeCode = event.mediaTypeCode;
      yield mediaTypeCode == photoCode
          ? MediaListSuccessState(
          photos: photos, videos: videos, hasReachedMax: false)
          : MediaListSuccessState(
          photos: photos, videos: videos, hasReachedMax: false);
    }

    if (event is MediaListFetchedEvent && !_hasReachedMax(currentState)) {
      try {
        if (currentState is MediaListInitialState) {
          final List<Photo> nextPhotos = await mediaRepository.fetchData(
              mediaType: photoCode, page: 1, keyWord: keyWord);
          final List<Video> nextVideos = await mediaRepository.fetchData(
              mediaType: videoCode, page: 1, keyWord: keyWord);

          yield MediaListSuccessState(
              photos: nextPhotos, videos: nextVideos, hasReachedMax: false);
          photos.addAll(nextPhotos);
          videos.addAll(nextVideos);

          return;
        }
        if (currentState is MediaListSuccessState) {
          if (mediaTypeCode == photoCode) {
            final List<Photo> nextPhotos = await mediaRepository.fetchData(
                mediaType: mediaTypeCode,
                page: currentPhotoPage + 1,
                keyWord: keyWord);

            if (nextPhotos.isEmpty)
              yield currentState.copyWith(hasReachedMax: true);
            else {
              yield MediaListSuccessState(
                  photos: photos + nextPhotos,
                  videos: videos,
                  hasReachedMax: false);

              currentPhotoPage += 1;
              photos.addAll(nextPhotos);
              print('photos.length = ${photos.length}');

              return;
            }
          } else {
            final List<Video> nextVideos = await mediaRepository.fetchData(
                mediaType: mediaTypeCode,
                page: currentVideoPage + 1,
                keyWord: keyWord);

            if (nextVideos.isEmpty)
              yield currentState.copyWith(hasReachedMax: true);
            else {
              yield MediaListSuccessState(
                  photos: photos,
                  videos: videos + nextVideos,
                  hasReachedMax: false);

              currentVideoPage += 1;
              videos.addAll(nextVideos);
              print('videos.length = ${videos.length}');

              return;
            }
          }
        }
      } catch (_) {
        yield MediaListFailureState();
      }
    }

    if (event is SearchMediaEvent) {
      yield MediaListInitialState();
      keyWord = event.keyWord;
      _resetData();

      final List<Photo> nextPhotos = await mediaRepository.fetchData(
          mediaType: photoCode, page: 1, keyWord: keyWord);
      final List<Video> nextVideos = await mediaRepository.fetchData(
          mediaType: videoCode, page: 1, keyWord: keyWord);

      yield MediaListSuccessState(
          photos: nextPhotos, videos: nextVideos, hasReachedMax: false);
      photos.addAll(nextPhotos);
      videos.addAll(nextVideos);
    }
  }

  bool _hasReachedMax(MediaListState state) =>
      state is MediaListSuccessState && state.hasReachedMax;

  void _resetData() {
    photos = [];
    videos = [];
    currentPhotoPage = 1;
    currentVideoPage = 1;
  }
}