package com.fongmi.android.tv.player.exo;

import android.net.Uri;

import androidx.media3.exoplayer.hls.playlist.HlsMediaPlaylist;
import androidx.media3.exoplayer.hls.playlist.HlsMultivariantPlaylist;
import androidx.media3.exoplayer.hls.playlist.HlsPlaylist;
import androidx.media3.exoplayer.hls.playlist.HlsPlaylistParser;
import androidx.media3.exoplayer.upstream.ParsingLoadable;

import com.fongmi.android.tv.Setting;
import com.fongmi.android.tv.server.process.Hls;
import com.orhanobut.logger.Logger;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

public class HlsPlaylistParserFactory implements androidx.media3.exoplayer.hls.playlist.HlsPlaylistParserFactory {

    private static final int MAX_PLAYLIST_SIZE = 1024 * 1024;

    @Override
    public ParsingLoadable.Parser<HlsPlaylist> createPlaylistParser() {
        return new Parser(new HlsPlaylistParser());
    }

    @Override
    public ParsingLoadable.Parser<HlsPlaylist> createPlaylistParser(HlsMultivariantPlaylist multivariantPlaylist, HlsMediaPlaylist mediaPlaylist) {
        return new Parser(new HlsPlaylistParser(multivariantPlaylist, mediaPlaylist));
    }

    private record Parser(HlsPlaylistParser delegate) implements ParsingLoadable.Parser<HlsPlaylist> {

        @Override
        public HlsPlaylist parse(Uri uri, InputStream input) throws IOException {
            byte[] original = read(input);
            byte[] playlist = original;
            if (Setting.isVideoPurify()) {
                try {
                    String content = new String(original, StandardCharsets.UTF_8);
                    if (content.startsWith("\uFEFF")) content = content.substring(1);
                    playlist = Hls.filter(content, uri.toString()).getBytes(StandardCharsets.UTF_8);
                } catch (Throwable e) {
                    Logger.t("HlsAdFilter").e(e, "In-player HLS filtering failed: %s", uri);
                }
            }
            return delegate.parse(uri, new ByteArrayInputStream(playlist));
        }

        private static byte[] read(InputStream input) throws IOException {
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            byte[] buffer = new byte[8192];
            int count;
            while ((count = input.read(buffer)) != -1) {
                if (output.size() + count > MAX_PLAYLIST_SIZE) throw new IOException("Playlist exceeds 1 MiB");
                output.write(buffer, 0, count);
            }
            return output.toByteArray();
        }
    }
}
