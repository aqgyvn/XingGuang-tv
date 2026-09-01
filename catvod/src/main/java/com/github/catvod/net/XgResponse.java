package com.github.catvod.net;

import java.io.IOException;

public final class XgResponse implements AutoCloseable {

    private final int code;
    private final String message;
    private final XgHeaders headers;
    private final XgResponseBody body;
    private final XgRequest request;
    private final Runnable closeAction;

    XgResponse(int code, String message, XgHeaders headers, XgResponseBody body, XgRequest request, Runnable closeAction) {
        this.code = code;
        this.message = message == null ? "" : message;
        this.headers = headers;
        this.body = body;
        this.request = request;
        this.closeAction = closeAction;
    }

    public int code() {
        return code;
    }

    public String message() {
        return message;
    }

    public boolean isSuccessful() {
        return code >= 200 && code < 300;
    }

    public String header(String name) {
        return headers.get(name);
    }

    public String header(String name, String fallback) {
        String value = header(name);
        return value == null ? fallback : value;
    }

    public XgHeaders headers() {
        return headers;
    }

    public XgResponseBody body() {
        return body;
    }

    public XgUrl url() {
        return request.url();
    }

    public XgRequest request() {
        return request;
    }

    @Override
    public void close() {
        try {
            body.close();
        } catch (IOException ignored) {
        } finally {
            closeAction.run();
        }
    }
}
