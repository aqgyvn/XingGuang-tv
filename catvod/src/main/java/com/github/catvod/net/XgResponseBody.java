package com.github.catvod.net;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.concurrent.atomic.AtomicBoolean;

public final class XgResponseBody implements AutoCloseable {

    private final InputStream value;
    private final long contentLength;
    private final String contentType;
    private final Runnable closeAction;
    private final AtomicBoolean closed;

    XgResponseBody(InputStream value, long contentLength, String contentType, Runnable closeAction) {
        this.value = value;
        this.contentLength = contentLength;
        this.contentType = contentType;
        this.closeAction = closeAction;
        this.closed = new AtomicBoolean();
    }

    public byte[] bytes() throws IOException {
        try (InputStream input = value; ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[8192];
            int count;
            while ((count = input.read(buffer)) != -1) output.write(buffer, 0, count);
            return output.toByteArray();
        } finally {
            close();
        }
    }

    public String string() throws IOException {
        Charset charset = StandardCharsets.UTF_8;
        if (contentType != null) {
            int index = contentType.toLowerCase(Locale.ROOT).indexOf("charset=");
            if (index >= 0) {
                String name = contentType.substring(index + 8).split("[; ]", 2)[0].replace("\"", "");
                try {
                    charset = Charset.forName(name);
                } catch (Exception ignored) {
                }
            }
        }
        return new String(bytes(), charset);
    }

    public InputStream byteStream() {
        return value;
    }

    public long contentLength() {
        return contentLength;
    }

    @Override
    public void close() throws IOException {
        if (closed.compareAndSet(false, true)) {
            try {
                value.close();
            } finally {
                closeAction.run();
            }
        }
    }
}
