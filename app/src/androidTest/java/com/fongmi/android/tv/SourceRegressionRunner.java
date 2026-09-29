package com.fongmi.android.tv;

import android.app.Instrumentation;
import android.os.Bundle;
import com.fongmi.android.tv.bean.Result;
import com.github.catvod.net.SourceException;
import com.github.catvod.net.SourceResponse;
import com.github.catvod.net.XgHttp;
import com.github.catvod.net.XgRequest;
import com.github.catvod.net.XgRequestBody;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import fi.iki.elonen.NanoHTTPD;

/** Device-side regression, no internet fixtures or production configuration changes. */
public final class SourceRegressionRunner extends Instrumentation {
    private final ConcurrentHashMap<String, AtomicInteger> counts = new ConcurrentHashMap<>();
    private int passed;
    private String base;

    @Override public void onCreate(Bundle arguments) { super.onCreate(arguments); start(); }

    @Override public void onStart() {
        NanoHTTPD fixture = new NanoHTTPD("127.0.0.1", 0) {
            @Override public Response serve(IHTTPSession session) {
                if (session.getMethod() == Method.POST) {
                    try { session.parseBody(new java.util.HashMap<>()); }
                    catch (Exception error) { return newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "fixture body error"); }
                }
                String path = session.getUri();
                int count = counts.computeIfAbsent(path, key -> new AtomicInteger()).incrementAndGet();
                if (path.equals("/html")) return newFixedLengthResponse("<!DOCTYPE html><html>fixture</html>");
                if (path.equals("/forbidden")) return newFixedLengthResponse(Response.Status.FORBIDDEN, "text/html", "<html>fixture</html>");
                if (path.equals("/empty") || path.equals("/recover-empty") && count == 1) return newFixedLengthResponse("");
                if (path.equals("/post") || path.equals("/recover-503") && count == 1)
                    return newFixedLengthResponse(Response.Status.SERVICE_UNAVAILABLE, "text/html", "<html>fixture</html>");
                if (path.equals("/xml")) return newFixedLengthResponse(Response.Status.OK, "text/xml", "<rss><list><video><id>fixture</id><name>Device fixture</name></video></list></rss>");
                return newFixedLengthResponse(Response.Status.OK, "application/json", "{\"list\":[{\"vod_id\":\"fixture\",\"vod_name\":\"Device fixture\"}],\"attempt\":" + count + "}");
            }
        };
        Bundle result = new Bundle();
        try {
            fixture.start();
            base = "http://127.0.0.1:" + fixture.getListeningPort();
            check("valid resource", !Result.fromJsonChecked(get("/valid")).getList().isEmpty());
            check("503 recovery", get("/recover-503").contains("\"attempt\":2"));
            check("empty recovery", get("/recover-empty").contains("\"attempt\":2"));
            expect("/html", SourceException.Kind.HTML, 1);
            expect("/forbidden", SourceException.Kind.HTTP, 1);
            expect("/empty", SourceException.Kind.EMPTY, 2);
            try {
                SourceResponse.fetch(() -> XgHttp.client().newCall(new XgRequest.Builder().url(base + "/post")
                        .post(XgRequestBody.create("query=test".getBytes(StandardCharsets.UTF_8), "application/x-www-form-urlencoded")).build()), false);
                throw new AssertionError("POST should fail");
            } catch (SourceException error) { check("POST not replayed", error.status == 503 && counts.get("/post").get() == 1); }
            String xml = SourceResponse.fetch(() -> XgHttp.call(base + "/xml"), true);
            check("XML preserved", !Result.fromTypeChecked(0, xml).getList().isEmpty());
            check("valid empty result", Result.fromJsonChecked("{\"list\":[]}").getList().isEmpty());
            check("BOM normalization", !Result.fromJsonChecked("\uFEFF" + get("/bom")).getList().isEmpty());
            try { Result.fromJsonChecked("{\"list\":123}"); throw new AssertionError("Invalid schema accepted"); }
            catch (SourceException expected) { check("bad schema reported", expected.kind == SourceException.Kind.FORMAT); }
            result.putString("stream", "\nPASS " + passed + " device regression checks\n");
            finish(-1, result);
        } catch (Throwable error) {
            result.putString("stream", "\nFAIL after " + passed + ": " + android.util.Log.getStackTraceString(error));
            finish(1, result);
        } finally { fixture.stop(); }
    }

    private String get(String path) throws Exception { return SourceResponse.fetch(() -> XgHttp.call(base + path), false); }
    private void expect(String path, SourceException.Kind kind, int count) throws Exception {
        try { get(path); throw new AssertionError("Expected failure " + path); }
        catch (SourceException error) { check(path, error.kind == kind && counts.get(path).get() == count); }
    }
    private void check(String name, boolean success) {
        if (!success) throw new AssertionError(name);
        passed++;
        Bundle status = new Bundle();
        status.putString("stream", "PASS " + name + "\n");
        sendStatus(0, status);
    }
}
