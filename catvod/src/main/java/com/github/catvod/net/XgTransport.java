package com.github.catvod.net;

import com.google.common.net.HttpHeaders;

import java.io.IOException;
import java.io.InputStream;
import java.io.ByteArrayInputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.InetAddress;
import java.net.Proxy;
import java.net.URI;
import java.net.URL;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.zip.GZIPInputStream;
import java.util.zip.Inflater;
import java.util.zip.InflaterInputStream;

import javax.net.ssl.HttpsURLConnection;

final class XgTransport {

    private static final int MAX_REDIRECTS = 20;

    private XgTransport() {
    }

    static XgResponse execute(XgCall call) throws IOException {
        // WebDAV owns its authentication and redirects, independently of source-feed headers.
        if ("PROPFIND".equals(call.request().method())) return XgWebDavTransport.execute(call);
        XgRequest request = XgHttp.requestInterceptor().intercept(call.request());
        request = XgHttp.responseInterceptor().intercept(request);
        request = XgHttp.authInterceptor().intercept(request);
        return execute(call, request, 0, false, false);
    }

    private static XgResponse execute(XgCall call, XgRequest request, int redirects, boolean retriedAuth, boolean retriedProxy) throws IOException {
        if (call.isCanceled()) throw new IOException("Canceled");
        HttpURLConnection connection = open(call, request);
        int code;
        try {
            writeBody(connection, request.body());
            code = connection.getResponseCode();
        } catch (IOException error) {
            if (call.isCanceled()) throw new IOException("Canceled", error);
            connection.disconnect();
            throw error;
        }
        XgResponse response = response(call, connection, request, code);
        if (code == HttpURLConnection.HTTP_UNAUTHORIZED && !retriedAuth) {
            XgRequest retry = XgHttp.authInterceptor().authenticate(request, response.header(HttpHeaders.WWW_AUTHENTICATE));
            if (retry != null) {
                response.close();
                return execute(call, retry, redirects, true, retriedProxy);
            }
        }
        if (code == HttpURLConnection.HTTP_PROXY_AUTH && !retriedProxy) {
            XgRequest retry = XgHttp.authenticator().authenticate(request.url().uri(), proxy(request.url().uri()), request);
            if (retry != null) {
                response.close();
                return execute(call, retry, redirects, retriedAuth, true);
            }
        }
        if (code == HttpURLConnection.HTTP_MOVED_TEMP && response.header(HttpHeaders.LOCATION) != null) {
            XgHttp.responseInterceptor().rememberRedirect(response.header(HttpHeaders.LOCATION), request.url().toString());
        }
        if (code == HttpURLConnection.HTTP_NOT_ACCEPTABLE) {
            String source = XgHttp.responseInterceptor().fallbackRedirect(request.url().toString());
            if (source != null) {
                response.close();
                return syntheticRedirect(call, request, source);
            }
        }
        if (call.client().options().redirect && redirect(code) && response.header(HttpHeaders.LOCATION) != null && redirects < MAX_REDIRECTS) {
            String location = new URL(new URL(request.url().toString()), response.header(HttpHeaders.LOCATION)).toString();
            response.close();
            return execute(call, redirectRequest(request, code, location), redirects + 1, retriedAuth, retriedProxy);
        }
        return response;
    }

    private static XgResponse syntheticRedirect(XgCall call, XgRequest request, String source) {
        XgHeaders headers = new XgHeaders.Builder().set(HttpHeaders.LOCATION, source).build();
        Runnable close = () -> call.client().unregister(call);
        XgResponseBody body = new XgResponseBody(new ByteArrayInputStream(new byte[0]), 0, null, close);
        return new XgResponse(HttpURLConnection.HTTP_MOVED_TEMP, "Found", headers, body, request, close);
    }

    private static HttpURLConnection open(XgCall call, XgRequest request) throws IOException {
        URI uri = request.url().uri();
        Proxy proxy = proxy(uri);
        URL url = connectionUrl(call, uri, proxy);
        HttpURLConnection connection = (HttpURLConnection) (proxy == Proxy.NO_PROXY ? url.openConnection() : url.openConnection(proxy));
        call.connection(connection);
        connection.setInstanceFollowRedirects(false);
        connection.setConnectTimeout(timeout(call.client().options().timeout));
        connection.setReadTimeout(timeout(call.client().options().timeout));
        connection.setRequestMethod(request.method());
        if (request.headers().get(HttpHeaders.USER_AGENT) == null) {
            connection.setRequestProperty(HttpHeaders.USER_AGENT, XgHttp.userAgent());
        }
        for (Map.Entry<String, List<String>> entry : request.headers().toMultimap().entrySet()) {
            for (String value : entry.getValue()) connection.addRequestProperty(entry.getKey(), value);
        }
        XgCookieJar cookieJar = call.client().options().cookieJar;
        List<XgCookie> cookies = cookieJar.loadForRequest(XgUrl.require(uri.toString()));
        if (!cookies.isEmpty() && connection.getRequestProperty(HttpHeaders.COOKIE) == null) {
            StringBuilder value = new StringBuilder();
            for (XgCookie cookie : cookies) {
                if (value.length() > 0) value.append("; ");
                value.append(cookie.name()).append('=').append(cookie.value());
            }
            connection.setRequestProperty(HttpHeaders.COOKIE, value.toString());
        }
        if (!url.getHost().equalsIgnoreCase(uri.getHost())) connection.setRequestProperty(HttpHeaders.HOST, hostHeader(uri));
        if (connection instanceof HttpsURLConnection https) {
            if (call.client().options().sslSocketFactory != null) https.setSSLSocketFactory(call.client().options().sslSocketFactory);
            else https.setSSLSocketFactory(XgHttp.sslSocketFactory());
            if (call.client().options().hostnameVerifier != null) https.setHostnameVerifier(call.client().options().hostnameVerifier);
            else https.setHostnameVerifier((hostname, session) -> true);
        }
        return connection;
    }

    private static URL connectionUrl(XgCall call, URI uri, Proxy proxy) throws IOException {
        if (proxy != Proxy.NO_PROXY) return uri.toURL();
        if ("https".equalsIgnoreCase(uri.getScheme())) return uri.toURL();
        if (call.client().options().dns != null) {
            List<java.net.InetAddress> addresses = call.client().options().dns.lookup(uri.getHost());
            if (addresses != null && !addresses.isEmpty()) {
                String host = addresses.get(0).getHostAddress();
                return new URL(uri.getScheme(), host, uri.getPort(), uri.getRawPath() + (uri.getRawQuery() == null ? "" : "?" + uri.getRawQuery()));
            }
        }
        String mapped = XgHttp.dns().mappedHost(uri.getHost());
        if (!mapped.equals(uri.getHost())) {
            return new URL(uri.getScheme(), mapped, uri.getPort(), uri.getRawPath() + (uri.getRawQuery() == null ? "" : "?" + uri.getRawQuery()));
        }
        // Keep the original hostname for HTTP requests. Pinning the URL to the
        // first DoH address can select a dead endpoint and prevents
        // HttpURLConnection from trying the remaining addresses, unlike the
        // previous OkHttp transport.
        return uri.toURL();
    }

    private static Proxy proxy(URI uri) {
        List<Proxy> proxies = XgHttp.selector().select(uri);
        return proxies == null || proxies.isEmpty() ? Proxy.NO_PROXY : proxies.get(0);
    }

    private static void writeBody(HttpURLConnection connection, XgRequestBody body) throws IOException {
        if (body == null) return;
        byte[] content = body.content();
        connection.setDoOutput(true);
        if (body.contentType() != null && connection.getRequestProperty(HttpHeaders.CONTENT_TYPE) == null) connection.setRequestProperty(HttpHeaders.CONTENT_TYPE, body.contentType());
        connection.setFixedLengthStreamingMode(content.length);
        try (OutputStream output = connection.getOutputStream()) {
            output.write(content);
        }
    }

    private static XgResponse response(XgCall call, HttpURLConnection connection, XgRequest request, int code) throws IOException {
        Map<String, List<String>> fields = connection.getHeaderFields();
        XgHeaders.Builder headers = new XgHeaders.Builder();
        for (Map.Entry<String, List<String>> entry : fields.entrySet()) if (entry.getKey() != null) for (String value : entry.getValue()) headers.add(entry.getKey(), value);
        InputStream stream = code >= 400 ? connection.getErrorStream() : connection.getInputStream();
        if (stream == null) stream = new ByteArrayInputStream(new byte[0]);
        XgHeaders builtHeaders = headers.build();
        saveCookies(call, request, builtHeaders);
        String encoding = builtHeaders.get(HttpHeaders.CONTENT_ENCODING);
        if ("gzip".equalsIgnoreCase(encoding)) stream = new GZIPInputStream(stream);
        if ("deflate".equalsIgnoreCase(encoding)) stream = new InflaterInputStream(stream, new Inflater(true));
        Runnable close = () -> {
            connection.disconnect();
            call.client().unregister(call);
        };
        XgResponseBody body = new XgResponseBody(stream, connection.getContentLengthLong(), builtHeaders.get(HttpHeaders.CONTENT_TYPE), close);
        return new XgResponse(code, connection.getResponseMessage(), builtHeaders, body, request, close);
    }

    private static void saveCookies(XgCall call, XgRequest request, XgHeaders headers) {
        XgCookieJar jar = call.client().options().cookieJar;
        if (jar == XgCookieJar.NO_COOKIES) return;
        List<XgCookie> cookies = new ArrayList<>();
        for (Map.Entry<String, List<String>> entry : headers.toMultimap().entrySet()) {
            if (!HttpHeaders.SET_COOKIE.equalsIgnoreCase(entry.getKey())) continue;
            for (String value : entry.getValue()) {
                XgCookie cookie = XgCookie.parse(request.url(), value);
                if (cookie != null) cookies.add(cookie);
            }
        }
        if (!cookies.isEmpty()) jar.saveFromResponse(request.url(), cookies);
    }

    private static boolean redirect(int code) {
        return code == HttpURLConnection.HTTP_MOVED_PERM || code == HttpURLConnection.HTTP_MOVED_TEMP || code == HttpURLConnection.HTTP_SEE_OTHER || code == 307 || code == 308;
    }

    private static XgRequest redirectRequest(XgRequest request, int code, String location) {
        XgRequest.Builder builder = request.newBuilder().url(location);
        if ((code == HttpURLConnection.HTTP_MOVED_TEMP || code == HttpURLConnection.HTTP_SEE_OTHER) && !"GET".equals(request.method()) && !"HEAD".equals(request.method())) builder.get();
        return builder.build();
    }

    private static String hostHeader(URI uri) {
        return uri.getPort() < 0 ? uri.getHost() : uri.getHost() + ":" + uri.getPort();
    }

    private static int timeout(long timeout) {
        return (int) Math.min(Integer.MAX_VALUE, Math.max(1, timeout));
    }
}
