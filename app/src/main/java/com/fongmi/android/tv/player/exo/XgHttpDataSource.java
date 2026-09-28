package com.fongmi.android.tv.player.exo;

import android.net.Uri;
import androidx.media3.datasource.BaseDataSource;
import androidx.media3.datasource.DataSpec;
import androidx.media3.datasource.HttpDataSource;
import com.github.catvod.net.XgCall;
import com.github.catvod.net.XgClient;
import com.github.catvod.net.XgHttp;
import com.github.catvod.net.XgRequest;
import com.github.catvod.net.XgResponse;
import java.io.IOException;
import java.io.InputStream;
import java.util.Collections;
import java.util.List;
import java.util.Map;

/** Media3 data source backed by the same stack used by configuration and parsing. */
public final class XgHttpDataSource extends BaseDataSource implements HttpDataSource {
    private static final String RANGE = "Range";
    private static final String ACCEPT_ENCODING = "Accept-Encoding";
    private final XgClient client;
    private final HttpDataSource.RequestProperties defaults;
    private XgCall call;
    private XgResponse response;
    private InputStream input;
    private DataSpec dataSpec;
    private Uri uri;
    private Map<String, List<String>> responseHeaders = Collections.emptyMap();
    private long bytesRemaining;
    private boolean opened;
    private int responseCode = -1;

    private XgHttpDataSource(XgClient client, HttpDataSource.RequestProperties defaults) {
        super(true);
        this.client = client;
        this.defaults = defaults;
    }

    @Override
    public long open(DataSpec dataSpec) throws HttpDataSource.HttpDataSourceException {
        this.dataSpec = dataSpec;
        this.uri = dataSpec.uri;
        transferInitializing(dataSpec);
        XgRequest.Builder builder = new XgRequest.Builder().url(uri.toString()).get();
        for (Map.Entry<String, String> entry : defaults.getSnapshot().entrySet()) builder.header(entry.getKey(), entry.getValue());
        for (Map.Entry<String, String> entry : dataSpec.httpRequestHeaders.entrySet()) builder.header(entry.getKey(), entry.getValue());
        if (!dataSpec.isFlagSet(DataSpec.FLAG_ALLOW_GZIP)) builder.header(ACCEPT_ENCODING, "identity");
        if (dataSpec.position != 0 || dataSpec.length != -1) {
            long end = dataSpec.length == -1 ? -1 : dataSpec.position + dataSpec.length - 1;
            builder.header(RANGE, end == -1 ? "bytes=" + dataSpec.position + "-" : "bytes=" + dataSpec.position + "-" + end);
        }
        try {
            call = client.newCall(builder.build());
            response = call.execute();
            responseCode = response.code();
            responseHeaders = response.headers().toMultimap();
            if (responseCode < 200 || responseCode > 299) throw new HttpDataSource.InvalidResponseCodeException(responseCode, response.message(), null, responseHeaders, dataSpec, null);
            input = response.body().byteStream();
            long contentLength = response.body().contentLength();
            long rangeLength = contentRangeLength(response.header("Content-Range"));
            if (rangeLength >= 0) contentLength = rangeLength;
            if (responseCode == 200 && dataSpec.position > 0) skipFully(dataSpec.position);
            bytesRemaining = dataSpec.length == -1 ? (contentLength < 0 ? -1 : Math.max(0, contentLength - (responseCode == 200 ? dataSpec.position : 0))) : dataSpec.length;
            opened = true;
            transferStarted(dataSpec);
            return bytesRemaining;
        } catch (HttpDataSource.HttpDataSourceException e) {
            closeQuietly();
            throw e;
        } catch (IOException e) {
            closeQuietly();
            throw HttpDataSource.HttpDataSourceException.createForIOException(e, dataSpec, HttpDataSource.HttpDataSourceException.TYPE_OPEN);
        } catch (RuntimeException e) {
            closeQuietly();
            throw HttpDataSource.HttpDataSourceException.createForIOException(new IOException(e), dataSpec, HttpDataSource.HttpDataSourceException.TYPE_OPEN);
        }
    }

    @Override
    public int read(byte[] buffer, int offset, int length) throws HttpDataSource.HttpDataSourceException {
        if (length == 0) return 0;
        if (bytesRemaining == 0) return -1;
        try {
            int count = input.read(buffer, offset, bytesRemaining == -1 ? length : (int) Math.min(length, bytesRemaining));
            if (count == -1) {
                if (bytesRemaining != -1) throw new IOException("Unexpected end of media stream");
                return -1;
            }
            if (bytesRemaining != -1) bytesRemaining -= count;
            bytesTransferred(count);
            return count;
        } catch (IOException e) {
            throw HttpDataSource.HttpDataSourceException.createForIOException(e, dataSpec, HttpDataSource.HttpDataSourceException.TYPE_READ);
        }
    }

    @Override public Uri getUri() { return uri; }
    @Override public Map<String, List<String>> getResponseHeaders() { return responseHeaders; }
    @Override public int getResponseCode() { return responseCode; }
    @Override public void setRequestProperty(String name, String value) { defaults.set(name, value); }
    @Override public void clearRequestProperty(String name) { defaults.remove(name); }
    @Override public void clearAllRequestProperties() { defaults.clear(); }

    @Override
    public void close() throws HttpDataSource.HttpDataSourceException {
        if (!opened) { closeQuietly(); return; }
        try {
            if (input != null) input.close();
            if (response != null) response.close();
        } catch (IOException e) {
            throw HttpDataSource.HttpDataSourceException.createForIOException(e, dataSpec, HttpDataSource.HttpDataSourceException.TYPE_CLOSE);
        } finally {
            input = null;
            response = null;
            call = null;
            opened = false;
            transferEnded();
        }
    }

    private void skipFully(long count) throws IOException {
        long skipped = 0;
        while (skipped < count) {
            long value = input.skip(count - skipped);
            if (value > 0) skipped += value;
            else if (input.read() == -1) throw new IOException("Unable to seek media stream");
            else skipped++;
        }
    }

    private static long contentRangeLength(String value) {
        if (value == null) return -1;
        int space = value.indexOf(' '), dash = value.indexOf('-'), slash = value.indexOf('/');
        if (space < 0 || dash < 0 || slash <= dash) return -1;
        try {
            long start = Long.parseLong(value.substring(space + 1, dash));
            long end = Long.parseLong(value.substring(dash + 1, slash));
            return end >= start ? end - start + 1 : -1;
        } catch (RuntimeException e) { return -1; }
    }

    private void closeQuietly() {
        try { if (response != null) response.close(); } catch (Exception ignored) {
        } finally {
            if (call != null) call.cancel();
            input = null;
            response = null;
            call = null;
            opened = false;
        }
    }

    public static final class Factory extends HttpDataSource.BaseFactory {
        private final XgClient client = XgHttp.player();
        @Override protected HttpDataSource createDataSourceInternal(HttpDataSource.RequestProperties properties) {
            return new XgHttpDataSource(client, properties);
        }
    }
}
