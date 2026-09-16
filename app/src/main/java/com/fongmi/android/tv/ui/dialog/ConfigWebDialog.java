package com.fongmi.android.tv.ui.dialog;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.net.Uri;
import android.net.http.SslError;
import android.util.Log;
import android.view.ViewGroup;
import android.webkit.CookieManager;
import android.webkit.JavascriptInterface;
import android.webkit.SslErrorHandler;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;

import com.fongmi.android.tv.App;
import com.fongmi.android.tv.api.Decoder;
import com.github.catvod.net.OkHttp;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.google.gson.Gson;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;

import androidx.appcompat.app.AlertDialog;
import okhttp3.Request;
import okhttp3.Response;

/** Lets the user complete a site-side browser challenge before the config is retried. */
public final class ConfigWebDialog {

    private static final String TAG = "ConfigWebDialog";
    private static final String CHALLENGE_HTML = "<!DOCTYPE html><html><head><meta charset=\"UTF-8\">" +
            "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1.0\">" +
            "</head><body><script src=\"/_guard/html.js?js=slider_html\"></script></body></html>";
    private static final String[] CHALLENGE_COOKIES = {"guardret", "guard", "guarddata", "guardword", "_err"};
    private static boolean showing;
    private static AlertDialog current;
    private static Runnable completed;
    private static Runnable canceled;

    private ConfigWebDialog() {
    }

    public static synchronized void show(String url, Runnable complete, Runnable cancel) {
        if (showing || url == null || url.isEmpty()) return;
        showing = true;
        App.post(() -> open(url, complete, cancel, 0));
    }

    private static void open(String url, Runnable complete, Runnable cancel, int attempt) {
        Activity activity = App.activity();
        if (activity == null) {
            if (attempt < 50) App.post(() -> open(url, complete, cancel, attempt + 1), 100);
            else {
                reset();
                App.post(cancel);
            }
            return;
        }
        completed = null;
        canceled = cancel;
        CookieStore cookies = new CookieStore();
        WebView webView = new WebView(activity);
        webView.addJavascriptInterface(new CookieBridge(cookies), "XgChallenge");
        FrameLayout container = new FrameLayout(activity);
        container.addView(webView, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                Math.max(720, activity.getResources().getDisplayMetrics().heightPixels / 2)));
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setUseWideViewPort(true);
        settings.setLoadWithOverviewMode(true);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
        CookieManager manager = CookieManager.getInstance();
        manager.setAcceptCookie(true);
        manager.setAcceptThirdPartyCookies(webView, true);
        String existing = manager.getCookie(url);
        if (existing != null) cookies.update(existing);
        ChallengeClient client = new ChallengeClient(url, cookies);
        webView.setWebViewClient(client);
        current = new MaterialAlertDialogBuilder(activity)
                .setTitle("站点验证")
                .setView(container)
                .setPositiveButton("验证完成", (dialog, which) -> {
                    rememberCookie(url, cookies.header());
                    completed = complete;
                    canceled = null;
                    dialog.dismiss();
                })
                .setNegativeButton("取消", (dialog, which) -> dialog.dismiss())
                .setOnDismissListener(dialog -> {
                    Runnable success = completed;
                    Runnable failure = canceled;
                    if (current == dialog) current = null;
                    reset();
                    client.destroy();
                    webView.stopLoading();
                    webView.loadUrl("about:blank");
                    webView.destroy();
                    if (success != null) App.post(success);
                    else if (failure != null) App.post(failure);
                })
                .create();
        current.show();
        client.loadDocument(webView, url, null);
    }

    private static void rememberCookie(String url, String fallback) {
        try {
            CookieManager cookies = CookieManager.getInstance();
            String value = mergeCookies(cookies.getCookie(url), fallback);
            if (!value.isEmpty()) Decoder.rememberCookie(url, value);
            cookies.flush();
        } catch (Throwable ignored) {
        }
    }

    private static String mergeCookies(String first, String second) {
        LinkedHashMap<String, String> values = new LinkedHashMap<>();
        addCookies(values, first);
        addCookies(values, second);
        List<String> parts = new ArrayList<>();
        for (Map.Entry<String, String> entry : values.entrySet()) parts.add(entry.getKey() + "=" + entry.getValue());
        return String.join("; ", parts);
    }

    private static void addCookies(Map<String, String> values, String header) {
        if (header == null || header.isEmpty()) return;
        for (String item : header.split(";")) {
            int equals = item.indexOf('=');
            if (equals <= 0) continue;
            String name = item.substring(0, equals).trim();
            String value = item.substring(equals + 1).trim();
            if (!name.isEmpty()) values.put(name, value);
        }
    }

    private static void reset() {
        showing = false;
        completed = null;
        canceled = null;
    }

    private static final class ChallengeClient extends WebViewClient {

        private final String host;
        private final CookieStore cookies;
        private volatile boolean destroyed;

        private ChallengeClient(String url, CookieStore cookies) {
            this.host = Uri.parse(url).getHost();
            this.cookies = cookies;
        }

        private void destroy() {
            destroyed = true;
        }

        private boolean isTarget(Uri uri) {
            if (uri == null || host == null) return false;
            String scheme = uri.getScheme();
            if (!"http".equalsIgnoreCase(scheme) && !"https".equalsIgnoreCase(scheme)) return false;
            String requested = uri.getHost();
            if (requested == null) return false;
            return requested.equalsIgnoreCase(host) || requested.endsWith("." + host) || host.endsWith("." + requested);
        }

        private void loadDocument(WebView view, String url, Map<String, String> requestHeaders) {
            Log.d(TAG, "loadDocument " + url);
            String existing = CookieManager.getInstance().getCookie(url);
            if (existing != null) cookies.update(existing);
            String userAgent = view.getSettings().getUserAgentString();
            App.execute(() -> {
                try {
                    Request.Builder builder = new Request.Builder().url(url).tag(String.class, TAG);
                    if (requestHeaders != null) {
                        for (Map.Entry<String, String> entry : requestHeaders.entrySet()) {
                            if (isTransportHeader(entry.getKey())) continue;
                            builder.header(entry.getKey(), entry.getValue());
                        }
                    }
                    if (userAgent != null && !userAgent.isEmpty()) builder.header("User-Agent", userAgent);
                    String cookie = cookies.header();
                    if (!cookie.isEmpty()) builder.header("Cookie", cookie);
                    try (Response response = OkHttp.client(TimeUnit.SECONDS.toMillis(15)).newCall(builder.build()).execute()) {
                        cookies.remember(response.headers("Set-Cookie"));
                        byte[] body = response.body() == null ? new byte[0] : response.body().bytes();
                        Mime mime = Mime.parse(response.header("Content-Type", "text/html; charset=utf-8"));
                        if (response.code() == 456) {
                            cookies.clearChallenge();
                            body = CHALLENGE_HTML.getBytes(StandardCharsets.UTF_8);
                            mime = Mime.parse("text/html; charset=utf-8");
                        }
                        if (!mime.text) throw new IOException("Non-text verification document");
                        body = inject(body, mime);
                        String html = new String(body, Charset.forName(mime.charset));
                        String base = response.request().url().toString();
                        Mime responseMime = mime;
                        Log.d(TAG, "loadDocument response " + response.code() + " " + mime.type + " " + body.length);
                        App.post(() -> {
                            if (!destroyed) view.loadDataWithBaseURL(base, html, responseMime.type, responseMime.charset, null);
                        });
                    }
                } catch (Throwable ignored) {
                    Log.e(TAG, "loadDocument failed " + url, ignored);
                    App.post(() -> {
                        if (!destroyed) view.loadData("<html><body style=\"font-family:sans-serif;padding:24px\">站点验证页面加载失败，请点击“验证完成”重试。</body></html>", "text/html", "UTF-8");
                    });
                }
            });
        }

        @Override
        public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
            Uri uri = request.getUrl();
            if (isTarget(uri)) {
                loadDocument(view, uri.toString(), request.getRequestHeaders());
                return true;
            }
            return super.shouldOverrideUrlLoading(view, request);
        }

        @SuppressWarnings("deprecation")
        @Override
        public boolean shouldOverrideUrlLoading(WebView view, String url) {
            Uri uri = Uri.parse(url);
            if (isTarget(uri)) {
                loadDocument(view, url, null);
                return true;
            }
            return super.shouldOverrideUrlLoading(view, url);
        }

        @Override
        public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
            if (request.isForMainFrame() && isTarget(request.getUrl())) loadDocument(view, request.getUrl().toString(), request.getRequestHeaders());
            else super.onReceivedError(view, request, error);
        }


        @Override
        @SuppressLint("WebViewClientOnReceivedSslError")
        public void onReceivedSslError(WebView view, SslErrorHandler handler, SslError error) {
            handler.proceed();
        }

        @Override
        public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
            Uri uri = request.getUrl();
            String method = request.getMethod();
            if (!isTarget(uri)) return super.shouldInterceptRequest(view, request);
            if (!"GET".equalsIgnoreCase(method) && !"HEAD".equalsIgnoreCase(method)) return super.shouldInterceptRequest(view, request);
            Log.d(TAG, "intercept " + method + " " + uri);
            try {
                Request.Builder builder = new Request.Builder().url(uri.toString()).tag(String.class, TAG);
                for (Map.Entry<String, String> entry : request.getRequestHeaders().entrySet()) {
                    if (isTransportHeader(entry.getKey())) continue;
                    builder.header(entry.getKey(), entry.getValue());
                }
                String cookie = cookies.header();
                if (!cookie.isEmpty()) builder.header("Cookie", cookie);
                Request okRequest = builder.build();
                try (Response response = OkHttp.client(TimeUnit.SECONDS.toMillis(15)).newCall(okRequest).execute()) {
                    cookies.remember(response.headers("Set-Cookie"));
                    byte[] body = response.body() == null ? new byte[0] : response.body().bytes();
                    Mime mime = Mime.parse(response.header("Content-Type", "application/octet-stream"));
                    body = inject(body, mime);
                    String reason = response.message();
                    if (reason == null || reason.isEmpty()) reason = String.valueOf(response.code());
                    return new WebResourceResponse(mime.type, mime.charset, response.code(), reason,
                            responseHeaders(response), new ByteArrayInputStream(body));
                }
            } catch (Throwable ignored) {
                Log.e(TAG, "intercept failed " + uri, ignored);
                return super.shouldInterceptRequest(view, request);
            }
        }

        private byte[] inject(byte[] body, Mime mime) throws IOException {
            if (!mime.text) return body;
            Charset charset = Charset.forName(mime.charset);
            String text = new String(body, charset);
            String script = cookies.script();
            if (mime.html) {
                int head = text.toLowerCase(Locale.ROOT).indexOf("<head");
                int insert = head < 0 ? 0 : text.indexOf('>', head) + 1;
                if (insert > 0) text = text.substring(0, insert) + "<script>" + script + "</script>" + text.substring(insert);
                else text = "<script>" + script + "</script>" + text;
            } else {
                text = script + "\n" + text;
            }
            return text.getBytes(charset);
        }

        private Map<String, String> responseHeaders(Response response) {
            LinkedHashMap<String, String> headers = new LinkedHashMap<>();
            for (String name : response.headers().names()) {
                if (skipResponseHeader(name)) continue;
                String value = response.header(name);
                if (value != null) headers.put(name, value);
            }
            return headers;
        }

        private boolean isTransportHeader(String name) {
            String value = name.toLowerCase(Locale.ROOT);
            return value.equals("host") || value.equals("connection") || value.equals("content-length")
                    || value.equals("accept-encoding") || value.equals("cookie") || value.equals("transfer-encoding");
        }

        private boolean skipResponseHeader(String name) {
            String value = name.toLowerCase(Locale.ROOT);
            return value.equals("content-length") || value.equals("content-encoding") || value.equals("transfer-encoding")
                    || value.equals("connection") || value.equals("set-cookie");
        }
    }

    private static final class CookieBridge {

        private final CookieStore cookies;

        private CookieBridge(CookieStore cookies) {
            this.cookies = cookies;
        }

        @JavascriptInterface
        public void cookie(String value) {
            cookies.update(value);
        }

        @JavascriptInterface
        public String all() {
            return cookies.header();
        }
    }

    private static final class CookieStore {

        private final Map<String, String> values = new ConcurrentHashMap<>();
        private final Gson gson = new Gson();

        private void remember(List<String> headers) {
            for (String header : headers) {
                int end = header.indexOf(';');
                update(end < 0 ? header : header.substring(0, end));
            }
        }

        private void update(String header) {
            addCookies(values, header);
        }

        private void remove(String name) {
            values.remove(name);
        }

        private void clearChallenge() {
            for (String name : CHALLENGE_COOKIES) values.remove(name);
        }

        private String header() {
            List<String> parts = new ArrayList<>();
            for (Map.Entry<String, String> entry : values.entrySet()) parts.add(entry.getKey() + "=" + entry.getValue());
            return String.join("; ", parts);
        }

        private String script() {
            StringBuilder script = new StringBuilder("(function(){try{");
            for (Map.Entry<String, String> entry : values.entrySet()) {
                String cookie = entry.getKey() + "=" + entry.getValue() + "; path=/";
                script.append("document.cookie=").append(gson.toJson(cookie)).append(';');
            }
            script.append("var d=Object.getOwnPropertyDescriptor(Document.prototype,'cookie');")
                    .append("if(d&&d.set&&!window.__xgCookieHook){window.__xgCookieHook=true;")
                    .append("Object.defineProperty(Document.prototype,'cookie',{configurable:true,")
                    .append("get:function(){var n=d.get.call(document)||'';try{var x=window.XgChallenge.all()||'';return n+(x?'; '+x:'');}catch(e){return n;}},")
                    .append("set:function(v){d.set.call(document,v);try{window.XgChallenge.cookie(v);}catch(e){}}});}")
                    .append("try{window.XgChallenge.cookie(document.cookie);}catch(e){}")
                    .append("}catch(e){}})();");
            return script.toString();
        }
    }

    private static final class Mime {

        private final String type;
        private final String charset;
        private final boolean text;
        private final boolean html;

        private Mime(String type, String charset, boolean text, boolean html) {
            this.type = type;
            this.charset = charset;
            this.text = text;
            this.html = html;
        }

        private static Mime parse(String value) {
            String[] parts = value == null ? new String[0] : value.split(";");
            String type = parts.length == 0 || parts[0].trim().isEmpty() ? "application/octet-stream" : parts[0].trim();
            String charset = StandardCharsets.UTF_8.name();
            for (int i = 1; i < parts.length; i++) {
                String part = parts[i].trim();
                int equals = part.indexOf('=');
                if (equals > 0 && "charset".equalsIgnoreCase(part.substring(0, equals).trim())) {
                    charset = part.substring(equals + 1).trim().replace("\"", "");
                }
            }
            String lower = type.toLowerCase(Locale.ROOT);
            boolean html = lower.contains("html");
            boolean text = html || lower.startsWith("text/") || lower.contains("javascript")
                    || lower.contains("json") || lower.contains("xml");
            return new Mime(type, charset, text, html);
        }
    }
}
