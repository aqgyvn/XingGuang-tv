package com.github.catvod.net.webdav;

import com.github.catvod.net.XgHeaders;

import java.io.IOException;
import java.net.URI;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

final class XgDavAuth {
    private static final Pattern PARAMETER = Pattern.compile(
            "([\\w-]+)\\s*=\\s*(?:\"((?:\\\\.|[^\"\\\\])*)\"|([^,\\s]+))");
    private final String username;
    private final String password;

    XgDavAuth(String username, String password) {
        if (username.contains(":")) throw new IllegalArgumentException("WebDAV username contains a colon");
        this.username = username;
        this.password = password;
    }

    String authorization(XgHeaders headers, URI uri) throws IOException {
        String basic = null;
        for (Map.Entry<String, List<String>> entry : headers.toMultimap().entrySet()) {
            if (!entry.getKey().equalsIgnoreCase("WWW-Authenticate")) continue;
            for (String header : entry.getValue()) for (String challenge : challenges(header)) {
                if (challenge.regionMatches(true, 0, "Digest ", 0, 7)) return digest(parameters(challenge.substring(7)), uri);
                if (challenge.regionMatches(true, 0, "Basic ", 0, 6) || challenge.equalsIgnoreCase("Basic")) basic = challenge;
            }
        }
        if (basic == null) throw new IOException("Unsupported WebDAV authentication challenge");
        Charset charset = charset(parameters(basic.length() > 6 ? basic.substring(6) : ""));
        return "Basic " + Base64.getEncoder().encodeToString((username + ":" + password).getBytes(charset));
    }

    private String digest(Map<String, String> values, URI uri) throws IOException {
        String realm = values.get("realm");
        String nonce = values.get("nonce");
        if (realm == null || nonce == null || nonce.isEmpty()) throw new IOException("Incomplete WebDAV Digest challenge");
        String algorithm = values.getOrDefault("algorithm", "MD5").toUpperCase(Locale.ROOT);
        boolean session = algorithm.endsWith("-SESS");
        String hash = session ? algorithm.substring(0, algorithm.length() - 5) : algorithm;
        if (!hash.equals("MD5") && !hash.equals("SHA-256")) throw new IOException("Unsupported WebDAV Digest algorithm");
        boolean qop = values.containsKey("qop");
        if (qop && !List.of(values.get("qop").toLowerCase(Locale.ROOT).replace(" ", "").split(",")).contains("auth")) {
            throw new IOException("WebDAV Digest requires qop=auth");
        }
        Charset charset = charset(values);
        String cnonce = UUID.randomUUID().toString().replace("-", "");
        String path = uri.getRawPath() + (uri.getRawQuery() == null ? "" : "?" + uri.getRawQuery());
        String ha1 = hash(hash, username + ":" + realm + ":" + password, charset);
        if (session) ha1 = hash(hash, ha1 + ":" + nonce + ":" + cnonce, charset);
        String ha2 = hash(hash, "PROPFIND:" + path, charset);
        String response = hash(hash, ha1 + ":" + nonce + ":"
                + (qop ? "00000001:" + cnonce + ":auth:" : "") + ha2, charset);
        String result = "Digest username=" + quote(username) + ", realm=" + quote(realm)
                + ", nonce=" + quote(nonce) + ", uri=" + quote(path) + ", algorithm=" + algorithm
                + ", response=" + quote(response);
        if (qop) result += ", qop=auth, nc=00000001";
        if (qop || session) result += ", cnonce=" + quote(cnonce);
        if (values.containsKey("opaque")) result += ", opaque=" + quote(values.get("opaque"));
        return result;
    }

    private static Charset charset(Map<String, String> values) {
        return "UTF-8".equalsIgnoreCase(values.get("charset")) ? StandardCharsets.UTF_8 : StandardCharsets.ISO_8859_1;
    }

    private static Map<String, String> parameters(String value) throws IOException {
        Map<String, String> result = new LinkedHashMap<>();
        Matcher matcher = PARAMETER.matcher(value);
        while (matcher.find()) {
            String text = matcher.group(2) == null ? matcher.group(3) : matcher.group(2).replaceAll("\\\\(.)", "$1");
            if (result.put(matcher.group(1).toLowerCase(Locale.ROOT), text) != null) {
                throw new IOException("Repeated WebDAV authentication parameter");
            }
        }
        return result;
    }

    private static List<String> challenges(String header) {
        List<String> result = new ArrayList<>();
        boolean quoted = false;
        boolean escaped = false;
        int start = 0;
        for (int i = 0; i < header.length(); i++) {
            char c = header.charAt(i);
            if (escaped) { escaped = false; continue; }
            if (quoted && c == '\\') { escaped = true; continue; }
            if (c == '"') quoted = !quoted;
            if (c != ',' || quoted) continue;
            String tail = header.substring(i + 1).trim();
            if (tail.regionMatches(true, 0, "Basic ", 0, 6) || tail.regionMatches(true, 0, "Digest ", 0, 7)) {
                result.add(header.substring(start, i).trim());
                start = i + 1;
            }
        }
        result.add(header.substring(start).trim());
        return result;
    }

    private static String quote(String value) throws IOException {
        if (value.indexOf('\r') >= 0 || value.indexOf('\n') >= 0) throw new IOException("Invalid WebDAV authentication value");
        return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
    }

    private static String hash(String algorithm, String value, Charset charset) throws IOException {
        try {
            StringBuilder result = new StringBuilder();
            for (byte b : MessageDigest.getInstance(algorithm).digest(value.getBytes(charset))) {
                result.append(Character.forDigit((b >>> 4) & 15, 16)).append(Character.forDigit(b & 15, 16));
            }
            return result.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new IOException("Missing WebDAV Digest algorithm", e);
        }
    }
}
