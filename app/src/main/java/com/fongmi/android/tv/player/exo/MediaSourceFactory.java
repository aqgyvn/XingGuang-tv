package com.fongmi.android.tv.player.exo;

import static androidx.media3.extractor.ts.DefaultTsPayloadReaderFactory.FLAG_ENABLE_HDMV_DTS_AUDIO_STREAMS;

import android.net.Uri;
import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.media3.common.C;
import androidx.media3.common.MediaItem;
import androidx.media3.datasource.DataSource;
import androidx.media3.datasource.DefaultDataSource;
import androidx.media3.exoplayer.drm.DrmSessionManagerProvider;
import androidx.media3.exoplayer.hls.HlsMediaSource;
import androidx.media3.exoplayer.source.ConcatenatingMediaSource2;
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory;
import androidx.media3.exoplayer.source.MediaSource;
import androidx.media3.exoplayer.upstream.LoadErrorHandlingPolicy;
import androidx.media3.extractor.DefaultExtractorsFactory;
import androidx.media3.extractor.ExtractorsFactory;
import androidx.media3.extractor.ts.TsExtractor;

import com.fongmi.android.tv.App;

import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

public class MediaSourceFactory implements MediaSource.Factory {

    private ExtractorsFactory extractorsFactory;

    @NonNull
    @Override
    public MediaSource.Factory setDrmSessionManagerProvider(@NonNull DrmSessionManagerProvider drmSessionManagerProvider) {
        return this;
    }

    @NonNull
    @Override
    public MediaSource.Factory setLoadErrorHandlingPolicy(@NonNull LoadErrorHandlingPolicy loadErrorHandlingPolicy) {
        return this;
    }

    @NonNull
    @Override
    public @C.ContentType int[] getSupportedTypes() {
        return new DefaultMediaSourceFactory(new DefaultDataSource.Factory(App.get(), new XgHttpDataSource.Factory()), getExtractorsFactory()).getSupportedTypes();
    }

    @NonNull
    @Override
    public MediaSource createMediaSource(@NonNull MediaItem mediaItem) {
        if (mediaItem.mediaId.contains("***") && mediaItem.mediaId.contains("|||")) {
            return createConcatenatingMediaSource(mediaItem);
        }
        return createSingleMediaSource(mediaItem);
    }

    private MediaSource createSingleMediaSource(MediaItem mediaItem) {
        DataSource.Factory sourceFactory = buildDataSourceFactory(mediaItem);
        if (isHls(mediaItem)) {
            return new HlsMediaSource.Factory(sourceFactory)
                    .setPlaylistParserFactory(new HlsPlaylistParserFactory())
                    .createMediaSource(mediaItem);
        }
        return new DefaultMediaSourceFactory(sourceFactory, getExtractorsFactory()).createMediaSource(mediaItem);
    }

    private boolean isHls(MediaItem mediaItem) {
        if (mediaItem.localConfiguration == null) return false;
        Uri uri = mediaItem.localConfiguration.uri;
        String path = uri.getPath() == null ? "" : uri.getPath().toLowerCase(Locale.ROOT);
        String mime = mediaItem.localConfiguration.mimeType == null ? "" : mediaItem.localConfiguration.mimeType.toLowerCase(Locale.ROOT);
        return androidx.media3.common.util.Util.inferContentType(uri, mediaItem.localConfiguration.mimeType) == C.CONTENT_TYPE_HLS
                || mime.equals("application/vnd.apple.mpegurl")
                || mime.equals("application/x-mpegurl")
                || path.endsWith(".m3u8")
                || path.endsWith(".m3u");
    }

    private MediaSource createConcatenatingMediaSource(MediaItem mediaItem) {
        ConcatenatingMediaSource2.Builder builder = new ConcatenatingMediaSource2.Builder();
        for (String split : mediaItem.mediaId.split("\\*\\*\\*")) {
            String[] info = split.split("\\|\\|\\|", 2);
            if (info.length < 2) continue;
            try {
                MediaItem item = mediaItem.buildUpon().setUri(Uri.parse(info[0])).setMediaId(info[0]).build();
                builder.add(createSingleMediaSource(item), Long.parseLong(info[1]));
            } catch (RuntimeException ignored) {
                // Ignore malformed concatenated entries instead of breaking the whole playlist.
            }
        }
        return builder.build();
    }

    private ExtractorsFactory getExtractorsFactory() {
        if (extractorsFactory == null) {
            extractorsFactory = new DefaultExtractorsFactory()
                    .setTsExtractorFlags(FLAG_ENABLE_HDMV_DTS_AUDIO_STREAMS)
                    .setTsExtractorTimestampSearchBytes(TsExtractor.DEFAULT_TIMESTAMP_SEARCH_BYTES * 10);
        }
        return extractorsFactory;
    }

    private DataSource.Factory buildDataSourceFactory(MediaItem mediaItem) {
        XgHttpDataSource.Factory httpFactory = new XgHttpDataSource.Factory();
        Map<String, String> headers = getHeaders(mediaItem);
        if (!headers.isEmpty()) httpFactory.setDefaultRequestProperties(headers);
        return new androidx.media3.datasource.cache.CacheDataSource.Factory()
                .setCache(CacheManager.get().getCache())
                .setUpstreamDataSourceFactory(new DefaultDataSource.Factory(App.get(), httpFactory))
                .setCacheWriteDataSinkFactory(null)
                .setFlags(androidx.media3.datasource.cache.CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR);
    }

    private Map<String, String> getHeaders(MediaItem mediaItem) {
        Map<String, String> headers = new HashMap<>();
        Bundle extras = mediaItem.requestMetadata.extras;
        if (extras != null) {
            for (String key : extras.keySet()) {
                Object value = extras.get(key);
                if (value != null) headers.put(key, value.toString());
            }
        }
        return headers;
    }
}
