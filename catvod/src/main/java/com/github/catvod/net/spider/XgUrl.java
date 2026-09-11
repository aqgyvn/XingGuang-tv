package com.github.catvod.net.spider;

import java.net.IDN;
import java.net.URI;
import java.net.URLDecoder;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Locale;

public final class XgUrl {
    private final URI value;

    private XgUrl(URI value) { this.value = value; }

    public static XgUrl parse(String url) {
        com.github.catvod.net.XgUrl parsed = com.github.catvod.net.XgUrl.parse(url);
        if (parsed == null) return null;
        URI uri = parsed.uri();
        if (!"http".equalsIgnoreCase(uri.getScheme()) && !"https".equalsIgnoreCase(uri.getScheme())) return null;
        return new XgUrl(uri);
    }

    public static XgUrl get(String url) {
        XgUrl value = parse(url);
        if (value == null) throw new IllegalArgumentException("Invalid HTTP URL: " + url);
        return value;
    }

    public String scheme() { return value.getScheme(); }
    public String host() { return value.getHost(); }
    public int port() { return value.getPort() >= 0 ? value.getPort() : "https".equalsIgnoreCase(scheme()) ? 443 : 80; }
    public String encodedPath() { return value.getRawPath() == null || value.getRawPath().isEmpty() ? "/" : value.getRawPath(); }
    public String encodedQuery() { return value.getRawQuery(); }
    public String encodedFragment() { return value.getRawFragment(); }
    public String username() {
        String info = value.getRawUserInfo();
        return info == null ? "" : decode(info.split(":", 2)[0]);
    }

    public String queryParameter(String name) {
        if (value.getRawQuery() == null) return null;
        for (String item : value.getRawQuery().split("&", -1)) {
            String[] pair = item.split("=", 2);
            if (decode(pair[0]).equals(name)) return pair.length == 1 ? null : decode(pair[1]);
        }
        return null;
    }

    public Builder newBuilder() { return new Builder(toString()); }
    public XgUrl resolve(String reference) {
        try { return parse(value.resolve(reference).toString()); }
        catch (IllegalArgumentException e) { return null; }
    }
    @Override public String toString() { return value.toString(); }
    @Override public boolean equals(Object other) { return other instanceof XgUrl && value.equals(((XgUrl) other).value); }
    @Override public int hashCode() { return value.hashCode(); }

    private static String decode(String text) {
        return URLDecoder.decode(text, StandardCharsets.UTF_8);
    }

    private static String encode(String text) {
        return URLEncoder.encode(text, StandardCharsets.UTF_8).replace("+", "%20");
    }

    public static final class Builder {
        private String scheme;
        private String host;
        private int port = -1;
        private String userInfo;
        private String path = "/";
        private String query;
        private String fragment;

        public Builder() {}

        public Builder(String source) {
            URI uri = XgUrl.get(source).value;
            scheme = uri.getScheme();
            host = uri.getHost();
            port = uri.getPort();
            userInfo = uri.getRawUserInfo();
            path = uri.getRawPath();
            query = uri.getRawQuery();
            fragment = uri.getRawFragment();
        }

        public Builder scheme(String value) {
            if (!"http".equalsIgnoreCase(value) && !"https".equalsIgnoreCase(value)) throw new IllegalArgumentException("Expected http or https");
            scheme = value.toLowerCase(Locale.ROOT);
            return this;
        }

        public Builder host(String value) {
            host = value.contains(":") ? value : IDN.toASCII(value).toLowerCase(Locale.ROOT);
            return this;
        }

        public Builder port(int value) {
            if (value < 1 || value > 65535) throw new IllegalArgumentException("Invalid port");
            port = value;
            return this;
        }

        public Builder addQueryParameter(String name, String value) {
            String part = encode(name) + (value == null ? "" : "=" + encode(value));
            query = query == null || query.isEmpty() ? part : query + "&" + part;
            return this;
        }

        public Builder addPathSegment(String value) {
            if (path == null || path.isEmpty()) path = "/";
            if (!path.endsWith("/")) path += "/";
            path += encode(value == null ? "" : value);
            return this;
        }

        public XgUrl build() {
            if (scheme == null || host == null) throw new IllegalStateException("URL scheme and host are required");
            String authority = host.contains(":") && !host.startsWith("[") ? "[" + host + "]" : host;
            String result = scheme + "://" + (userInfo == null ? "" : userInfo + "@") + authority
                    + (port < 0 ? "" : ":" + port) + (path == null || path.isEmpty() ? "/" : path)
                    + (query == null ? "" : "?" + query) + (fragment == null ? "" : "#" + fragment);
            return XgUrl.get(result);
        }
    }
}
