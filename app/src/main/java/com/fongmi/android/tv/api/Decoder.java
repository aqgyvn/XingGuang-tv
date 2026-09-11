package com.fongmi.android.tv.api;

import android.util.Base64;

import com.fongmi.android.tv.utils.UrlUtil;
import com.github.catvod.net.XgUrl;
import com.github.catvod.utils.Json;
import com.github.catvod.utils.Util;

import java.io.IOException;
import java.io.InterruptedIOException;
import java.net.URI;
import java.nio.charset.StandardCharsets;
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
    private static final String FISH_ENTRY_HOST = "xn--v4q818bf34b.cc";
    private static final String FISH_CONFIG_URL = "https://6800.kstore.vip/fish.json";
    private static final OkHttpClient CLIENT = new OkHttpClient();

    public static String getJson(String url, String tag) throws Exception {
        if (Thread.currentThread().isInterrupted()) throw new InterruptedIOException("Canceled");
        url = resolveConfigUrl(url);
        Request request = new Request.Builder().url(url).tag(String.class, tag).build();
        String responseUrl = url;
        String data;
        try (Response res = CLIENT.newCall(request).execute()) {
            okhttp3.HttpUrl httpUrl = res.request().url();
            int size = XgUrl.parse(url).querySize();
            if (httpUrl.querySize() == size) responseUrl = httpUrl.toString();
            data = res.body().string();
        }
        if (Thread.currentThread().isInterrupted()) throw new InterruptedIOException("Canceled");
        if (isHtml(data)) throw new IOException("Configuration endpoint returned HTML instead of a feed");
        return verify(responseUrl, data);
    }

    public static void cancel(String tag) {
        cancel(CLIENT.dispatcher().queuedCalls(), tag);
        cancel(CLIENT.dispatcher().runningCalls(), tag);
    }

    private static void cancel(Iterable<Call> calls, String tag) {
        for (Call call : calls) if (tag.equals(call.request().tag(String.class))) call.cancel();
    }

    static String resolveConfigUrl(String url) {
        XgUrl parsed = XgUrl.parse(url);
        if (parsed == null || !FISH_ENTRY_HOST.equalsIgnoreCase(parsed.host())) return url;
        URI uri = parsed.uri();
        boolean http = "http".equalsIgnoreCase(uri.getScheme());
        boolean https = "https".equalsIgnoreCase(uri.getScheme());
        if (!http && !https) return url;
        if (uri.getPort() != -1 && uri.getPort() != (https ? 443 : 80)) return url;
        // The public root publishes this direct feed. Leave private and custom URLs intact.
        if (!"/".equals(parsed.encodedPath()) || uri.getRawQuery() != null
                || uri.getRawUserInfo() != null || uri.getRawFragment() != null) return url;
        return FISH_CONFIG_URL;
    }

    static boolean isHtml(String data) {
        return HTML_START.matcher(data).find();
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
