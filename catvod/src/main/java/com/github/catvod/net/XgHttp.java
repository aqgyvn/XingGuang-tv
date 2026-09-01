package com.github.catvod.net;

import android.annotation.SuppressLint;

import androidx.collection.ArrayMap;

import com.github.catvod.net.interceptor.AuthInterceptor;
import com.github.catvod.net.interceptor.RequestInterceptor;
import com.github.catvod.net.interceptor.ResponseInterceptor;
import com.github.catvod.utils.Util;

import java.security.SecureRandom;
import java.security.cert.X509Certificate;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSocketFactory;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;

public class XgHttp {

    private static final long TIMEOUT = TimeUnit.SECONDS.toMillis(30);

    private ResponseInterceptor responseInterceptor;
    private RequestInterceptor requestInterceptor;
    private AuthInterceptor authInterceptor;
    private XgAuthenticator authenticator;
    private XgProxySelector selector;
    private XgClient client;
    private XgClient player;
    private XgDns dns;
    private SSLSocketFactory sslSocketFactory;

    private static class Loader {
        static volatile XgHttp INSTANCE = new XgHttp();
    }

    public static XgHttp get() {
        return Loader.INSTANCE;
    }

    public void clear() {
        cancelAll();
        dns().clear();
        selector().clear();
        authenticator().clear();
        authInterceptor().clear();
        requestInterceptor().clear();
        responseInterceptor().clear();
    }

    public static XgDns dns() {
        if (get().dns != null) return get().dns;
        return get().dns = new XgDns();
    }

    public static ResponseInterceptor responseInterceptor() {
        if (get().responseInterceptor != null) return get().responseInterceptor;
        return get().responseInterceptor = new ResponseInterceptor();
    }

    public static RequestInterceptor requestInterceptor() {
        if (get().requestInterceptor != null) return get().requestInterceptor;
        return get().requestInterceptor = new RequestInterceptor();
    }

    public static AuthInterceptor authInterceptor() {
        if (get().authInterceptor != null) return get().authInterceptor;
        return get().authInterceptor = new AuthInterceptor();
    }

    public static XgAuthenticator authenticator() {
        if (get().authenticator != null) return get().authenticator;
        return get().authenticator = new XgAuthenticator();
    }

    public static XgProxySelector selector() {
        if (get().selector != null) return get().selector;
        return get().selector = new XgProxySelector();
    }

    public static XgClient client() {
        if (get().client != null) return get().client;
        return get().client = new XgClient(true, TIMEOUT);
    }

    public static XgClient xgClient() {
        return client();
    }

    public static XgClient player() {
        if (get().player != null) return get().player;
        return get().player = new XgClient(true, TIMEOUT);
    }

    public static XgClient client(long timeout) {
        return new XgClient(true, timeout);
    }

    public static XgClient xgClient(long timeout) {
        return client(timeout);
    }

    public static XgClient xgClient(boolean redirect, long timeout) {
        return client(redirect, timeout);
    }

    public static XgClient noRedirect() {
        return noRedirect(TIMEOUT);
    }

    public static XgClient noRedirect(long timeout) {
        return new XgClient(false, timeout);
    }

    public static XgClient xgNoRedirect() {
        return noRedirect();
    }

    public static XgClient client(boolean redirect, long timeout) {
        return redirect ? client(timeout) : noRedirect(timeout);
    }

    public static String string(String url) {
        if (!url.startsWith("http")) return "";
        try (XgResponse res = call(url).execute()) {
            return res.body().string();
        } catch (Exception e) {
            e.printStackTrace();
            return "";
        }
    }

    public static String string(String url, Map<String, String> headers) {
        if (!url.startsWith("http")) return "";
        try (XgResponse res = call(url, headers).execute()) {
            return res.body().string();
        } catch (Exception e) {
            e.printStackTrace();
            return "";
        }
    }

    public static XgCall newCall(String url) {
        return client().newCall(new XgRequest.Builder().url(url).build());
    }

    public static XgCall newCall(String url, String tag) {
        return client().newCall(new XgRequest.Builder().url(url).tag(tag).build());
    }

    public static XgCall newCall(XgClient client, String url) {
        return client.newCall(new XgRequest.Builder().url(url).build());
    }

    public static XgCall newCall(XgClient client, String url, String tag) {
        return client.newCall(new XgRequest.Builder().url(url).tag(tag).build());
    }

    public static XgCall newCall(String url, Map<String, String> headers) {
        return client().newCall(new XgRequest.Builder().url(url).headers(XgHeaders.of(headers)).build());
    }

    public static XgCall newCall(String url, Map<String, String> headers, ArrayMap<String, String> params) {
        return client().newCall(new XgRequest.Builder().url(buildUrl(url, params)).headers(XgHeaders.of(headers)).build());
    }

    public static XgCall newCall(String url, Map<String, String> headers, XgRequestBody body) {
        return client().newCall(new XgRequest.Builder().url(url).headers(XgHeaders.of(headers)).post(body).build());
    }

    public static XgCall newCall(XgClient client, String url, XgRequestBody body) {
        return client.newCall(new XgRequest.Builder().url(url).post(body).build());
    }

    public static XgCall call(String url) {
        return newCall(url);
    }

    public static XgCall call(String url, String tag) {
        return newCall(url, tag);
    }

    public static XgCall call(XgClient client, String url) {
        return newCall(client, url);
    }

    public static XgCall call(XgClient client, String url, String tag) {
        return newCall(client, url, tag);
    }

    public static XgCall call(String url, Map<String, String> headers) {
        return newCall(url, headers);
    }

    public static XgCall call(String url, Map<String, String> headers, ArrayMap<String, String> params) {
        return newCall(url, headers, params);
    }

    public static XgCall call(String url, Map<String, String> headers, XgRequestBody body) {
        return newCall(url, headers, body);
    }

    public static XgCall call(XgClient client, String url, XgRequestBody body) {
        return newCall(client, url, body);
    }

    public static XgFormBody xgBody(ArrayMap<String, String> params) {
        XgFormBody.Builder body = new XgFormBody.Builder();
        for (Map.Entry<String, String> entry : params.entrySet()) body.add(entry.getKey(), entry.getValue());
        return body.build();
    }

    public static XgFormBody toBody(ArrayMap<String, String> params) {
        return xgBody(params);
    }

    public static void cancel(String tag) {
        client().cancel(tag);
    }

    public static void cancel(XgClient client, String tag) {
        client.cancel(tag);
    }

    public static void cancelAll() {
        client().cancelAll();
        if (get().player != null) player().cancelAll();
    }

    static SSLSocketFactory sslSocketFactory() {
        if (get().sslSocketFactory != null) return get().sslSocketFactory;
        try {
            SSLContext context = SSLContext.getInstance("TLS");
            context.init(null, new TrustManager[]{trustAllCertificates()}, new SecureRandom());
            return get().sslSocketFactory = context.getSocketFactory();
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    static String userAgent() {
        return Util.XGHTTP;
    }

    private static String buildUrl(String url, ArrayMap<String, String> params) {
        StringBuilder builder = new StringBuilder(url);
        boolean query = url.contains("?");
        for (Map.Entry<String, String> entry : params.entrySet()) {
            builder.append(query ? '&' : '?');
            builder.append(java.net.URLEncoder.encode(entry.getKey(), java.nio.charset.StandardCharsets.UTF_8));
            builder.append('=').append(java.net.URLEncoder.encode(entry.getValue(), java.nio.charset.StandardCharsets.UTF_8));
            query = true;
        }
        return builder.toString();
    }

    @SuppressLint({"TrustAllX509TrustManager", "CustomX509TrustManager"})
    private static X509TrustManager trustAllCertificates() {
        return new X509TrustManager() {
            @Override
            public void checkClientTrusted(X509Certificate[] chain, String authType) {
            }

            @Override
            public void checkServerTrusted(X509Certificate[] chain, String authType) {
            }

            @Override
            public X509Certificate[] getAcceptedIssuers() {
                return new X509Certificate[0];
            }
        };
    }
}
