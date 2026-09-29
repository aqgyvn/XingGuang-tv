package com.github.catvod.net;

import com.google.gson.JsonParser;
import java.io.IOException;
import java.io.InterruptedIOException;
import java.net.ConnectException;
import java.net.SocketException;
import java.net.SocketTimeoutException;
import java.util.Locale;
import java.util.function.Supplier;

/** Validation and bounded recovery for catalogue APIs only, never media or arbitrary HTML. */
public final class SourceResponse {
    private SourceResponse() {}

    public static String fetch(Supplier<XgCall> factory, boolean xml) throws IOException {
        for (int attempt = 0; ; attempt++) {
            checkInterrupted();
            XgCall call = factory.get();
            boolean mayRetry = attempt == 0 && "GET".equals(call.request().method());
            try (XgResponse response = call.execute()) {
                // Respect server-directed backoff instead of issuing an immediate retry.
                mayRetry &= response.header("Retry-After") == null;
                if (!response.isSuccessful()) throw new SourceException(SourceException.Kind.HTTP, response.code());
                String text = response.body().string();
                checkInterrupted();
                return xml ? requireContent(text) : requireObject(text);
            } catch (IOException error) {
                if (!mayRetry || !retryable(error) || Thread.currentThread().isInterrupted()) throw error;
                try {
                    Thread.sleep(250);
                } catch (InterruptedException interrupted) {
                    Thread.currentThread().interrupt();
                    throw new InterruptedIOException("Source request canceled");
                }
            }
        }
    }

    static boolean retryable(IOException error) {
        if (error instanceof SourceException source) {
            return source.kind == SourceException.Kind.EMPTY || source.kind == SourceException.Kind.HTTP
                    && (source.status == 502 || source.status == 503 || source.status == 504);
        }
        return error instanceof ConnectException || error instanceof SocketTimeoutException || error instanceof SocketException;
    }

    private static void checkInterrupted() throws InterruptedIOException {
        if (Thread.currentThread().isInterrupted()) throw new InterruptedIOException("Source request canceled");
    }

    public static String requireContent(String text) throws SourceException {
        String value = text == null ? "" : text.trim();
        if (value.startsWith("\uFEFF")) value = value.substring(1).trim();
        if (value.isEmpty()) throw new SourceException(SourceException.Kind.EMPTY, 0);
        String prefix = value.substring(0, Math.min(value.length(), 256)).toLowerCase(Locale.ROOT);
        if (prefix.startsWith("<!doctype html") || prefix.startsWith("<html")
                || prefix.startsWith("<head") || prefix.startsWith("<body")) {
            throw new SourceException(SourceException.Kind.HTML, 0);
        }
        return value;
    }

    public static String requireObject(String text) throws SourceException {
        String value = requireContent(text);
        try {
            if (JsonParser.parseString(value).isJsonObject()) return value;
        } catch (RuntimeException ignored) {
        }
        throw new SourceException(SourceException.Kind.FORMAT, 0);
    }
}
