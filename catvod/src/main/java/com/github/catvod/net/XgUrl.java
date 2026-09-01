package com.github.catvod.net;

import java.net.URI;
import java.net.URISyntaxException;
import java.net.IDN;

public final class XgUrl {

    private final URI value;

    private XgUrl(URI value) {
        this.value = value;
    }

    public static XgUrl parse(String url) {
        try {
            URI value = new URI(url);
            if (value.getScheme() == null) return null;
            if (value.getHost() != null) return new XgUrl(value);
            String normalized = normalizeInternationalHost(url, value);
            return normalized == null ? null : new XgUrl(new URI(normalized));
        } catch (URISyntaxException e) {
            return null;
        }
    }

    private static String normalizeInternationalHost(String url, URI value) {
        String authority = value.getRawAuthority();
        if (authority == null || authority.isEmpty()) return null;
        int at = authority.lastIndexOf('@');
        String userInfo = at >= 0 ? authority.substring(0, at + 1) : "";
        String hostPort = at >= 0 ? authority.substring(at + 1) : authority;
        String host;
        String port = "";
        if (hostPort.startsWith("[")) {
            int end = hostPort.indexOf(']');
            if (end < 0) return null;
            host = hostPort.substring(0, end + 1);
            port = hostPort.substring(end + 1);
        } else {
            int colon = hostPort.lastIndexOf(':');
            if (colon > 0 && hostPort.indexOf(':') == colon) {
                host = hostPort.substring(0, colon);
                port = hostPort.substring(colon);
            } else {
                host = hostPort;
            }
        }
        try {
            String asciiHost = host.startsWith("[") ? host : IDN.toASCII(host);
            int schemeEnd = url.indexOf("://");
            if (schemeEnd < 0) return null;
            int authorityStart = schemeEnd + 3;
            int suffixStart = url.length();
            for (int i = authorityStart; i < url.length(); i++) {
                char c = url.charAt(i);
                if (c == '/' || c == '?' || c == '#') {
                    suffixStart = i;
                    break;
                }
            }
            return url.substring(0, authorityStart) + userInfo + asciiHost + port + url.substring(suffixStart);
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    static XgUrl require(String url) {
        XgUrl value = parse(url);
        if (value == null) throw new IllegalArgumentException("Invalid URL: " + url);
        return value;
    }

    public String host() {
        return value.getHost();
    }

    public int querySize() {
        String query = value.getRawQuery();
        return query == null || query.isEmpty() ? 0 : query.split("&", -1).length;
    }

    public String encodedPath() {
        String path = value.getRawPath();
        return path == null || path.isEmpty() ? "/" : path;
    }

    public URI uri() {
        return value;
    }

    public String toString() {
        return value.toString();
    }
}
