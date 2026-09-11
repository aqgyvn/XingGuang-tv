package com.github.catvod.net.webdav;

import com.github.catvod.net.XgClient;
import com.github.catvod.net.XgHttp;
import com.github.catvod.net.XgRequest;
import com.github.catvod.net.XgRequestBody;
import com.github.catvod.net.XgResponse;
import com.github.catvod.net.XgUrl;

import java.io.IOException;
import java.io.InterruptedIOException;
import java.net.URI;
import java.util.List;

public final class XgWebDavClient implements XgWebDav {
    private static final int MAX_REDIRECTS = 5;
    private static final XgRequestBody PROPERTIES = XgRequestBody.create(
            "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
                    + "<d:propfind xmlns:d=\"DAV:\"><d:prop><d:resourcetype/>"
                    + "<d:getcontentlength/><d:getlastmodified/><d:getcontenttype/>"
                    + "</d:prop></d:propfind>", "application/xml; charset=utf-8");

    private final XgClient transport;
    private volatile XgDavAuth credentials;

    public XgWebDavClient() {
        this(XgHttp.noRedirect());
    }

    XgWebDavClient(XgClient transport) {
        this.transport = transport;
    }

    @Override public void setCredentials(String username, String password) {
        credentials = new XgDavAuth(username == null ? "" : username, password == null ? "" : password);
    }

    @Override public List<XgDavResource> list(String url) throws IOException {
        URI current = requestUri(url);
        XgDavAuth authentication = credentials;
        String authorization = null;
        int redirects = 0;
        int authAttempts = 0;
        while (true) {
            if (Thread.currentThread().isInterrupted()) throw new InterruptedIOException("WebDAV listing interrupted");
            XgRequest.Builder builder = new XgRequest.Builder().url(current.toASCIIString())
                    .method("PROPFIND", PROPERTIES).header("Depth", "1")
                    .header("Accept", "application/xml, text/xml").header("Accept-Encoding", "gzip");
            if (authorization != null) builder.header("Authorization", authorization);
            try (XgResponse response = transport.newCall(builder.build()).execute()) {
                int code = response.code();
                if (code == 401 && authentication != null && authAttempts < 2) {
                    authorization = authentication.authorization(response.headers(), current);
                    authAttempts++;
                    continue;
                }
                if (code == 301 || code == 302 || code == 307 || code == 308) {
                    String location = response.header("Location");
                    if (location == null || ++redirects > MAX_REDIRECTS) throw new IOException("Invalid WebDAV redirect chain");
                    URI next;
                    try {
                        next = requestUri(current.resolve(location.replace(" ", "%20")).toString());
                    } catch (IllegalArgumentException e) {
                        throw new IOException("Invalid WebDAV redirect URL", e);
                    }
                    if (!sameOrigin(current, next)) throw new IOException("WebDAV redirect changes origin; use the final server URL");
                    current = next;
                    authorization = null;
                    authAttempts = 0;
                    continue;
                }
                if (code != 207) throw new IOException("WebDAV PROPFIND returned HTTP " + code);
                return XgDavParser.parse(response.body().byteStream(), current);
            }
        }
    }

    static URI requestUri(String value) throws IOException {
        if (value == null || value.indexOf('\r') >= 0 || value.indexOf('\n') >= 0) throw new IOException("Invalid WebDAV URL");
        XgUrl parsed = XgUrl.parse(value.replace(" ", "%20").replaceAll("%(?![0-9a-fA-F]{2})", "%25"));
        if (parsed == null) throw new IOException("Invalid WebDAV URL");
        URI uri = parsed.uri();
        if ((!"http".equalsIgnoreCase(uri.getScheme()) && !"https".equalsIgnoreCase(uri.getScheme()))
                || uri.getHost() == null || uri.getRawUserInfo() != null || uri.getRawFragment() != null) {
            throw new IOException("Expected an HTTP(S) WebDAV URL with credentials set separately");
        }
        if (uri.getRawPath() == null || uri.getRawPath().isEmpty()) {
            return URI.create(uri.getScheme() + "://" + uri.getRawAuthority() + "/"
                    + (uri.getRawQuery() == null ? "" : "?" + uri.getRawQuery()));
        }
        return URI.create(uri.toASCIIString());
    }

    static boolean sameOrigin(URI first, URI second) {
        return first.getScheme().equalsIgnoreCase(second.getScheme())
                && first.getHost().equalsIgnoreCase(second.getHost()) && port(first) == port(second);
    }

    private static int port(URI uri) {
        return uri.getPort() >= 0 ? uri.getPort() : "https".equalsIgnoreCase(uri.getScheme()) ? 443 : 80;
    }
}
