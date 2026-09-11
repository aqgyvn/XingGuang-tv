package com.github.catvod.net.spider;

public final class XgResponse implements AutoCloseable {
    private final int code;
    private final String message;
    private final XgHeaders headers;
    private final XgResponseBody body;
    private final XgRequest request;
    XgResponse(com.github.catvod.net.XgResponse response, XgRequest request) {
        code = response.code(); message = response.message(); headers = convert(response.headers()); body = new XgResponseBody(response.body());
        com.github.catvod.net.XgRequest actual = response.request();
        this.request = request.newBuilder().url(actual.url().toString()).headers(convert(actual.headers()))
                .method(actual.method(), actual.body() == null ? null : new XgRequestBody(actual.body())).build();
    }
    private static XgHeaders convert(com.github.catvod.net.XgHeaders source) {
        XgHeaders.Builder builder = new XgHeaders.Builder();
        source.toMultimap().forEach((name, values) -> values.forEach(value -> builder.add(name, value)));
        return builder.build();
    }
    public int code() { return code; }
    public String message() { return message; }
    public boolean isSuccessful() { return code >= 200 && code < 300; }
    public boolean isRedirect() { return code >= 300 && code < 400; }
    public String header(String name) { return headers.get(name); }
    public String header(String name, String fallback) { String value = header(name); return value == null ? fallback : value; }
    public XgHeaders headers() { return headers; }
    public java.util.List<String> headers(String name) { return headers.values(name); }
    public XgResponseBody body() { return body; }
    public XgRequest request() { return request; }
    public void close() { body.close(); }
}
