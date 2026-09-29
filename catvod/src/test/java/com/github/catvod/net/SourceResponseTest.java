package com.github.catvod.net;

import okhttp3.mockwebserver.MockWebServer;
import okhttp3.mockwebserver.MockResponse;
import okhttp3.mockwebserver.Dispatcher;
import okhttp3.mockwebserver.RecordedRequest;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicInteger;
import static org.junit.Assert.*;

public class SourceResponseTest {
    private MockWebServer server;
    private XgClient client;
    private String url;
    private final AtomicInteger requests = new AtomicInteger();
    private String method;
    private String body;
    private String header;

    @Before public void setup() throws Exception {
        server = new MockWebServer();
        server.start();
        url = server.url("/api").toString();
        client = new XgClient(true, 1000);
        XgHttp.requestInterceptor().clear();
    }

    @After public void teardown() throws Exception { server.shutdown(); }

    private void serve(int firstStatus, String firstBody, String nextBody, boolean backoff) {
        server.setDispatcher(new Dispatcher() {
            @Override public MockResponse dispatch(RecordedRequest request) {
                int count = requests.incrementAndGet();
                method = request.getMethod();
                body = request.getBody().readUtf8();
                header = request.getHeader("X-Test");
                MockResponse response = new MockResponse().setResponseCode(count == 1 ? firstStatus : 200)
                        .setBody(count == 1 ? firstBody : nextBody);
                if (backoff) response.addHeader("Retry-After", "120");
                return response;
            }
        });
    }

    private String get() throws Exception {
        return SourceResponse.fetch(() -> client.newCall(new XgRequest.Builder().url(url).build()), false);
    }

    @Test public void transientServerErrorRecovers() throws Exception {
        serve(503, "<html>unavailable</html>", "{\"list\":[{}]}", false);
        assertEquals("{\"list\":[{}]}", get());
        assertEquals(2, requests.get());
    }

    @Test public void emptyResponseRecovers() throws Exception {
        serve(200, "", "{\"list\":[{}]}", false);
        assertEquals("{\"list\":[{}]}", get());
        assertEquals(2, requests.get());
    }

    @Test public void permanentEmptyIsNotASuccess() {
        serve(200, "", "", false);
        assertEquals(SourceException.Kind.EMPTY, assertThrows(SourceException.class, this::get).kind);
        assertEquals(2, requests.get());
    }

    @Test public void htmlDoesNotBecomeEmptyListOrTriggerRetry() {
        serve(200, "<!DOCTYPE html><html>secret</html>", "{}", false);
        SourceException error = assertThrows(SourceException.class, this::get);
        assertEquals(SourceException.Kind.HTML, error.kind);
        assertFalse(error.getMessage().contains("secret"));
        assertEquals(1, requests.get());
    }

    @Test public void statusTakesPrecedenceOverHtml() {
        serve(403, "<html>denied</html>", "{}", false);
        SourceException error = assertThrows(SourceException.class, this::get);
        assertEquals(SourceException.Kind.HTTP, error.kind);
        assertEquals(403, error.status);
        assertEquals(1, requests.get());
    }

    @Test public void respectsRetryAfter() {
        serve(503, "", "{}", true);
        assertThrows(SourceException.class, this::get);
        assertEquals(1, requests.get());
    }

    @Test public void postIsNotReplayedAndKeepsHeadersAndBody() {
        serve(503, "", "{}", false);
        assertThrows(SourceException.class, () -> SourceResponse.fetch(() -> client.newCall(new XgRequest.Builder()
                .url(url).header("X-Test", "value").post(XgRequestBody.create("q=abc".getBytes(StandardCharsets.UTF_8), "application/x-www-form-urlencoded")).build()), false));
        assertEquals(1, requests.get());
        assertEquals("POST", method);
        assertEquals("q=abc", body);
        assertEquals("value", header);
    }

    @Test public void validEmptyListIsNotRetried() throws Exception {
        serve(200, "{\"list\":[]}", "{}", false);
        assertEquals("{\"list\":[]}", get());
        assertEquals(1, requests.get());
    }

    @Test public void bomIsNormalizedAndInvalidJsonReported() throws Exception {
        assertEquals("{}", SourceResponse.requireObject(" \uFEFF {} "));
        for (String input : new String[]{"null", "[]", "42", "{broken", "text"}) {
            assertEquals(SourceException.Kind.FORMAT, assertThrows(SourceException.class, () -> SourceResponse.requireObject(input)).kind);
        }
        assertEquals("<rss/>", SourceResponse.requireContent("<rss/>"));
    }

    @Test public void interruptedRequestNeverStarts() {
        serve(200, "{}", "{}", false);
        Thread.currentThread().interrupt();
        try { assertThrows(java.io.InterruptedIOException.class, this::get); }
        finally { Thread.interrupted(); }
        assertEquals(0, requests.get());
    }
}
