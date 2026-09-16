package com.fongmi.android.tv.api;

import android.util.Base64;

import com.fongmi.android.tv.utils.UrlUtil;
import com.github.catvod.net.OkHttp;
import com.github.catvod.utils.Json;
import com.github.catvod.utils.Util;

import java.io.IOException;
import java.io.InterruptedIOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import javax.crypto.Cipher;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;

import okhttp3.Call;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;

public class Decoder {

    private static final Pattern JS_URI = Pattern.compile("\"(\\.|\\.\\.)/(.?|.+?)\\.js\\?(.?|.+?)\"");
    private static final Pattern HTML_START = Pattern.compile("(?is)\\A[\\s\\uFEFF]*+(?:<!--.*?-->\\s*+)*+(?:<!doctype\\s+html\\b|<html\\b|<head\\b|<body\\b)");
    private static final Pattern HTML_LINK = Pattern.compile("(?is)(?:href|data-url)\\s*=\\s*[\"']([^\"']+)[\"']");
    private static final OkHttpClient CLIENT = OkHttp.client(TimeUnit.SECONDS.toMillis(6));
    private static final Map<String, String> COOKIES = new ConcurrentHashMap<>();

    public static String getJson(String url, String tag) throws Exception {
        if (Thread.currentThread().isInterrupted()) throw new InterruptedIOException("Canceled");
        String original = resolveConfigUrl(url);
        if (original == null || original.trim().isEmpty()) throw new IOException("Configuration URL is empty");
        Set<String> pending = new LinkedHashSet<>(configCandidates(original));
        List<String> attempts = new ArrayList<>();
        BrowserChallengeException challenge = null;
        while (!pending.isEmpty()) {
            String candidate = pending.iterator().next();
            pending.remove(candidate);
            try {
                Fetch fetch = fetch(candidate, tag);
                if (fetch.body.trim().isEmpty()) {
                    attempts.add(summary(candidate, "empty body"));
                    continue;
                }
                if (isBrowserChallenge(fetch.body)) {
                    challenge = new BrowserChallengeException(fetch.url);
                    attempts.add(summary(candidate, "browser verification required"));
                    throw challenge;
                }
                if (isHtml(fetch.body)) {
                    attempts.add(summary(candidate, "HTML"));
                    pending.addAll(discoverFeedCandidates(fetch.url, fetch.body));
                    continue;
                }
                return verify(fetch.url, fetch.body);
            } catch (InterruptedIOException e) {
                throw e;
            } catch (BrowserChallengeException browser) {
                challenge = browser;
                attempts.add(summary(candidate, "browser verification required"));
                break;
            } catch (Exception e) {
                attempts.add(summary(candidate, describe(e)));
            }
        }
        if (challenge != null) throw challenge;
        throw new IOException("Configuration request failed (" + original + "): " + String.join("; ", attempts));
    }

    public static void cancel(String tag) {
        cancel(CLIENT.dispatcher().queuedCalls(), tag);
        cancel(CLIENT.dispatcher().runningCalls(), tag);
    }

    private static void cancel(Iterable<Call> calls, String tag) {
        for (Call call : calls) if (tag.equals(call.request().tag(String.class))) call.cancel();
    }

    static String resolveConfigUrl(String url) {
        // Request the saved entry directly. A past public mirror can expire independently.
        return url;
    }

    static boolean isHtml(String data) {
        return HTML_START.matcher(data).find();
    }

    static boolean isBrowserChallenge(String data) {
        if (data == null || data.isEmpty()) return false;
        String value = data.toLowerCase(Locale.ROOT);
        return value.contains("/_guard/")
                || value.contains("/cdn-cgi/challenge-platform/")
                || value.contains("cf-chl-");
    }

    private static Fetch fetch(String url, String tag) throws IOException {
        Request.Builder builder = new Request.Builder().url(url).tag(String.class, tag);
        String cookie = cookie(url);
        if (!cookie.isEmpty()) builder.header("Cookie", cookie);
        Request request = builder.build();
        try (Response res = CLIENT.newCall(request).execute()) {
            okhttp3.HttpUrl httpUrl = res.request().url();
            String body = res.body() == null ? "" : res.body().string();
            if (res.code() == 456 || isBrowserChallenge(body)) throw new BrowserChallengeException(httpUrl.toString());
            if (!res.isSuccessful()) {
                throw new IOException("HTTP " + res.code() + " (" + httpUrl.host() + ")");
            }
            String responseUrl = url;
            responseUrl = httpUrl.toString();
            return new Fetch(responseUrl, body);
        }
    }

    private static String cookie(String url) {
        String host = host(url);
        if (host.isEmpty()) return "";
        return COOKIES.getOrDefault(host, "");
    }

    public static void rememberCookie(String url, String value) {
        String host = host(url);
        if (host.isEmpty() || value == null || value.isEmpty()) return;
        COOKIES.put(host, value);
    }

    private static String host(String url) {
        try {
            String host = okhttp3.HttpUrl.get(url).host();
            return host == null ? "" : host.toLowerCase(Locale.ROOT);
        } catch (Throwable ignored) {
            return "";
        }
    }

    static List<String> configCandidates(String url) {
        LinkedHashSet<String> candidates = new LinkedHashSet<>();
        if (url != null && !url.isEmpty()) {
            addRootCandidates(candidates, url);
        }
        if (!isFishHost(url)) return new ArrayList<>(candidates);
        addRootCandidates(candidates, "http://我不是.摸鱼儿.cc");
        addRootCandidates(candidates, "http://我不是.摸鱼儿.top");
        addRootCandidates(candidates, "https://6800.kstore.vip/fish.json");
        return new ArrayList<>(candidates);
    }

    private static void addRootCandidates(LinkedHashSet<String> candidates, String url) {
        if (url == null || url.isEmpty()) return;
        candidates.add(url);
        String alternate = alternateRoot(url);
        if (alternate != null) candidates.add(alternate);
        if (!isFishHost(url)) candidates.addAll(wwwRoots(url));
    }

    private static String alternateRoot(String url) {
        String lower = url.toLowerCase(Locale.ROOT);
        String scheme;
        if (lower.startsWith("http://")) scheme = "http://";
        else if (lower.startsWith("https://")) scheme = "https://";
        else return null;
        String rest = url.substring(scheme.length());
        int slash = rest.indexOf('/');
        String authority = slash < 0 ? rest : rest.substring(0, slash);
        String path = slash < 0 ? "" : rest.substring(slash);
        if (authority.isEmpty() || authority.contains("@") || authority.contains(":") || authority.contains("?") || authority.contains("#")) return null;
        if (authority.endsWith(".") || (!path.isEmpty() && !path.equals("/"))) return null;
        return ("http://".equals(scheme) ? "https://" : "http://") + rest;
    }

    private static List<String> wwwRoots(String url) {
        String lower = url.toLowerCase(Locale.ROOT);
        String scheme;
        if (lower.startsWith("http://")) scheme = "http://";
        else if (lower.startsWith("https://")) scheme = "https://";
        else return List.of();
        String rest = url.substring(scheme.length());
        int slash = rest.indexOf('/');
        String authority = slash < 0 ? rest : rest.substring(0, slash);
        String path = slash < 0 ? "" : rest.substring(slash);
        if (authority.isEmpty() || authority.contains("@") || authority.contains(":") || authority.contains("?") || authority.contains("#")) return List.of();
        if (authority.endsWith(".") || authority.startsWith("www.") || authority.matches("[0-9.]+")) return List.of();
        if (!authority.contains(".") || (!path.isEmpty() && !path.equals("/"))) return List.of();
        String alternateScheme = "http://".equals(scheme) ? "https://" : "http://";
        return List.of(scheme + "www." + rest, alternateScheme + "www." + rest);
    }

    private static boolean isFishHost(String url) {
        if (url == null) return false;
        String value = url.toLowerCase();
        return value.contains("xn--v4q818bf34b.cc")
                || value.contains("摸鱼儿.cc")
                || value.contains("摸鱼儿.top");
    }

    private static List<String> discoverFeedCandidates(String baseUrl, String html) {
        LinkedHashSet<String> candidates = new LinkedHashSet<>();
        Matcher matcher = HTML_LINK.matcher(html);
        while (matcher.find()) {
            String link = matcher.group(1).trim();
            if (!isFeedCandidate(link)) continue;
            String resolved = UrlUtil.resolve(baseUrl, link);
            if (resolved.startsWith("http://") || resolved.startsWith("https://")) candidates.add(resolved);
        }
        return new ArrayList<>(candidates);
    }

    static boolean isFeedCandidate(String url) {
        if (url == null || url.isEmpty()) return false;
        String value = url.toLowerCase();
        return value.contains(".json")
                || value.contains("config")
                || value.contains("fish")
                || (value.contains("摸鱼儿") && !value.contains("helper") && !value.contains("detail.php"))
                || (value.contains("xn--v4q818bf34b") && !value.contains("helper") && !value.contains("detail.php"))
                || value.contains("kstore.vip")
                || value.endsWith(".jpg")
                || value.endsWith(".txt");
    }

    private static String summary(String url, String reason) {
        String value = reason == null || reason.isEmpty() ? "unknown error" : reason;
        return url + " -> " + value;
    }

    private static String describe(Exception error) {
        if (error instanceof java.net.UnknownHostException) return "DNS unresolved";
        String message = error.getMessage();
        return message == null || message.isEmpty() ? error.getClass().getSimpleName() : message;
    }

    private record Fetch(String url, String body) {
    }

    public static final class BrowserChallengeException extends IOException {

        private final String url;

        BrowserChallengeException(String url) {
            super("Browser verification required (" + url + ")");
            this.url = url;
        }

        public String getUrl() {
            return url;
        }
    }

    private static String verify(String url, String data) throws Exception {
        if (data.isEmpty()) throw new Exception();
        if (Json.isObj(data)) return fix(url, data);
        if (data.contains("**")) data = base64(data);
        if (data.startsWith("2423")) data = cbc(data);
        return fix(url, data);
    }

    private static String fix(String url, String data) {
        Matcher matcher = JS_URI.matcher(data);
        while (matcher.find()) data = replace(url, data, matcher.group());
        if (data.contains("../")) data = data.replace("../", UrlUtil.resolve(url, "../"));
        if (data.contains("./")) data = data.replace("./", UrlUtil.resolve(url, "./"));
        if (data.contains("__JS1__")) data = data.replace("__JS1__", "./");
        if (data.contains("__JS2__")) data = data.replace("__JS2__", "../");
        return data;
    }

    private static String replace(String url, String data, String ext) {
        String t = ext.replace("\"./", "\"" + UrlUtil.resolve(url, "./"));
        t = t.replace("\"../", "\"" + UrlUtil.resolve(url, "../"));
        t = t.replace("./", "__JS1__").replace("../", "__JS2__");
        return data.replace(ext, t);
    }

    private static String cbc(String data) throws Exception {
        String decode = new String(Util.hex2byte(data)).toLowerCase();
        String key = padEnd(decode.substring(decode.indexOf("$#") + 2, decode.indexOf("#$")));
        String iv = padEnd(decode.substring(decode.length() - 13));
        SecretKeySpec keySpec = new SecretKeySpec(key.getBytes(), "AES");
        IvParameterSpec ivSpec = new IvParameterSpec(iv.getBytes());
        Cipher cipher = Cipher.getInstance("AES/CBC/PKCS5Padding");
        cipher.init(Cipher.DECRYPT_MODE, keySpec, ivSpec);
        data = data.substring(data.indexOf("2324") + 4, data.length() - 26);
        byte[] decryptData = cipher.doFinal(Util.hex2byte(data));
        return new String(decryptData, StandardCharsets.UTF_8);
    }

    private static String base64(String data) {
        String extract = extract(data);
        if (extract.isEmpty()) return data;
        return new String(Base64.decode(extract, Base64.DEFAULT));
    }

    private static String extract(String data) {
        Matcher matcher = Pattern.compile("[A-Za-z0-9]{8}\\*\\*").matcher(data);
        return matcher.find() ? data.substring(data.indexOf(matcher.group()) + 10) : "";
    }

    private static String padEnd(String key) {
        return key + "0000000000000000".substring(key.length());
    }
}
