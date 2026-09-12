package com.github.catvod.net;

import androidx.collection.ArrayMap;

import com.github.catvod.net.interceptor.AuthInterceptor;
import com.github.catvod.net.interceptor.RequestInterceptor;
import com.github.catvod.net.interceptor.ResponseInterceptor;

import java.util.Map;
import java.util.Objects;
import java.util.concurrent.TimeUnit;

import okhttp3.Call;
import okhttp3.FormBody;
import okhttp3.Headers;
import okhttp3.HttpUrl;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;

public class OkHttp {

    private static final long TIMEOUT = TimeUnit.SECONDS.toMillis(30);

    private ResponseInterceptor responseInterceptor;
    private RequestInterceptor requestInterceptor;
    private AuthInterceptor authInterceptor;
    private OkAuthenticator authenticator;
    private OkProxySelector selector;
    private OkHttpClient client;
    private OkHttpClient player;
    private OkDns dns;

    private static class Loader {
        static volatile OkHttp INSTANCE = new OkHttp();
    }

    public static OkHttp get() {
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

    public static OkDns dns() {
        if (get().dns != null) return get().dns;
        return get().dns = (OkDns) XgHttp.dns();
    }

    public static ResponseInterceptor responseInterceptor() {
        if (get().responseInterceptor != null) return get().responseInterceptor;
        return get().responseInterceptor = XgHttp.responseInterceptor();
    }

    public static RequestInterceptor requestInterceptor() {
        if (get().requestInterceptor != null) return get().requestInterceptor;
        return get().requestInterceptor = XgHttp.requestInterceptor();
    }

    public static AuthInterceptor authInterceptor() {
        if (get().authInterceptor != null) return get().authInterceptor;
        return get().authInterceptor = XgHttp.authInterceptor();
    }

    public static OkAuthenticator authenticator() {
        if (get().authenticator != null) return get().authenticator;
        return get().authenticator = (OkAuthenticator) XgHttp.authenticator();
    }

    public static OkProxySelector selector() {
        if (get().selector != null) return get().selector;
        return get().selector = (OkProxySelector) XgHttp.selector();
    }

    public static OkHttpClient client() {
        if (get().client != null) return get().client;
        return get().client = getBuilder().build();
    }

    public static OkHttpClient player() {
        if (get().player != null) return get().player;
        return get().player = getBuilder().build();
    }

    public static OkHttpClient client(long timeout) {
        return client().newBuilder().connectTimeout(timeout, TimeUnit.MILLISECONDS).readTimeout(timeout, TimeUnit.MILLISECONDS).writeTimeout(timeout, TimeUnit.MILLISECONDS).build();
    }

    public static OkHttpClient noRedirect() {
        return noRedirect(TIMEOUT);
    }

    public static OkHttpClient noRedirect(long timeout) {
        return client().newBuilder().connectTimeout(timeout, TimeUnit.MILLISECONDS).readTimeout(timeout, TimeUnit.MILLISECONDS).writeTimeout(timeout, TimeUnit.MILLISECONDS).followRedirects(false).followSslRedirects(false).build();
    }

    public static OkHttpClient client(boolean redirect, long timeout) {
        return redirect ? client(timeout) : noRedirect(timeout);
    }

    public static String string(String url) {
        if (url == null || !url.startsWith("http")) return "";
        try (Response res = newCall(url).execute()) {
            return res.body().string();
        } catch (Exception e) {
            e.printStackTrace();
            return "";
        }
    }

    public static String string(String url, Map<String, String> headers) {
        if (url == null || !url.startsWith("http")) return "";
        try (Response res = newCall(url, headers).execute()) {
            return res.body().string();
        } catch (Exception e) {
            e.printStackTrace();
            return "";
        }
    }

    public static Call newCall(String url) {
        return client().newCall(new Request.Builder().url(url).build());
    }

    public static Call newCall(String url, String tag) {
        return client().newCall(new Request.Builder().url(url).tag(tag).build());
    }

    public static Call newCall(OkHttpClient client, String url) {
        return client.newCall(new Request.Builder().url(url).build());
    }

    public static Call newCall(OkHttpClient client, String url, String tag) {
        return client.newCall(new Request.Builder().url(url).tag(tag).build());
    }

    public static Call newCall(String url, Map<String, String> headers) {
        return client().newCall(new Request.Builder().url(url).headers(Headers.of(headers)).build());
    }

    public static Call newCall(String url, Map<String, String> headers, ArrayMap<String, String> params) {
        return client().newCall(new Request.Builder().url(buildUrl(url, params)).headers(Headers.of(headers)).build());
    }

    public static Call newCall(String url, Map<String, String> headers, RequestBody body) {
        return client().newCall(new Request.Builder().url(url).headers(Headers.of(headers)).post(body).build());
    }

    public static Call newCall(OkHttpClient client, String url, RequestBody body) {
        return client.newCall(new Request.Builder().url(url).post(body).build());
    }

    public static void cancel(String tag) {
        cancel(client(), tag);
    }

    public static void cancel(OkHttpClient client, String tag) {
        for (Call call : client.dispatcher().queuedCalls()) if (tag.equals(call.request().tag())) call.cancel();
        for (Call call : client.dispatcher().runningCalls()) if (tag.equals(call.request().tag())) call.cancel();
    }

    public static void cancelAll() {
        cancelAll(client());
    }

    public static void cancelAll(OkHttpClient client) {
        client.dispatcher().cancelAll();
    }

    public static FormBody toBody(ArrayMap<String, String> params) {
        FormBody.Builder body = new FormBody.Builder();
        for (Map.Entry<String, String> entry : params.entrySet()) body.add(entry.getKey(), entry.getValue());
        return body.build();
    }

    private static HttpUrl buildUrl(String url, ArrayMap<String, String> params) {
        HttpUrl.Builder builder = Objects.requireNonNull(HttpUrl.parse(url)).newBuilder();
        for (Map.Entry<String, String> entry : params.entrySet()) builder.addQueryParameter(entry.getKey(), entry.getValue());
        return builder.build();
    }

    private static OkHttpClient.Builder getBuilder() {
        // Use the platform trust store. Source headers, DNS and proxies share Xg state.
        return new OkHttpClient.Builder()
                .addInterceptor(OkHttpBridge::interceptRequest)
                .addNetworkInterceptor(OkHttpBridge::interceptResponse)
                .authenticator(OkHttpBridge::authenticate)
                .proxyAuthenticator(authenticator()).proxySelector(selector()).dns(dns())
                .connectTimeout(TIMEOUT, TimeUnit.MILLISECONDS)
                .readTimeout(TIMEOUT, TimeUnit.MILLISECONDS)
                .writeTimeout(TIMEOUT, TimeUnit.MILLISECONDS);
    }
}
