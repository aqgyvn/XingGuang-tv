package com.github.catvod.net;

import java.io.IOException;
import java.io.InputStream;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.zip.GZIPInputStream;
import java.util.zip.Inflater;
import java.util.zip.InflaterInputStream;

import okhttp3.Call;
import okhttp3.MediaType;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import okhttp3.ResponseBody;

/** Keeps the existing Xg API while all ordinary HTTP execution uses official OkHttp. */
final class XgTransport {
    private XgTransport() {}

    static XgResponse execute(XgCall call) throws IOException {
        // Preserve the separately tested project WebDAV backend.
        if ("PROPFIND".equals(call.request().method())) return XgWebDavTransport.execute(call);
        if (call.isCanceled() || Thread.currentThread().isInterrupted()) throw new java.io.InterruptedIOException("Canceled");
        XgRequest original = call.request();
        RequestBody body = null;
        if (original.body() != null) {
            String type = original.body().contentType();
            body = RequestBody.create(original.body().content(), type == null ? null : MediaType.parse(type));
        }
        Request request = new Request.Builder().url(original.url().toString())
                .headers(OkHttpBridge.headers(original.headers())).method(original.method(), body)
                .tag(String.class, original.tag()).build();
        Call execution = call.client().transport().newCall(request);
        call.cancellation(execution::cancel);
        Response response = execution.execute();
        AtomicBoolean closed = new AtomicBoolean();
        Runnable close = () -> {
            if (closed.compareAndSet(false, true)) {
                response.close();
                call.cancellation(null);
                call.client().unregister(call);
            }
        };
        try {
            ResponseBody result = response.body();
            if (result == null) throw new IOException("Empty HTTP response body");
            InputStream stream = result.byteStream();
            long length = result.contentLength();
            // OkHttp handles transparent gzip; explicit Accept-Encoding remains the caller's choice.
            String encoding = response.header("Content-Encoding");
            if ("gzip".equalsIgnoreCase(encoding)) {
                stream = new GZIPInputStream(stream);
                length = -1;
            } else if ("deflate".equalsIgnoreCase(encoding)) {
                stream = new InflaterInputStream(stream, new Inflater(true));
                length = -1;
            }
            XgRequest finalRequest = OkHttpBridge.metadata(response.request()).newBuilder().tag(original.tag()).build();
            XgResponseBody value = new XgResponseBody(stream, length, response.header("Content-Type"), close);
            return new XgResponse(response.code(), response.message(), finalHeaders(response), value, finalRequest, close);
        } catch (IOException | RuntimeException error) {
            close.run();
            throw error;
        }
    }

    private static XgHeaders finalHeaders(Response response) {
        XgHeaders.Builder headers = new XgHeaders.Builder();
        for (int i = 0; i < response.headers().size(); i++) {
            headers.add(response.headers().name(i), response.headers().value(i));
        }
        return headers.build();
    }
}
