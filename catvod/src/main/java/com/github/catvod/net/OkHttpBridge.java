package com.github.catvod.net;

import java.io.IOException;
import java.util.List;
import java.util.ArrayList;

import okhttp3.Cookie;
import okhttp3.CookieJar;
import okhttp3.Headers;
import okhttp3.HttpUrl;
import okhttp3.Interceptor;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.Route;

/** Metadata adapter only: streaming request bodies are never consumed by interceptors. */
public final class OkHttpBridge {
    private OkHttpBridge() {}

    public static XgRequest metadata(Request request) {
        XgHeaders.Builder headers = new XgHeaders.Builder();
        for (int i = 0; i < request.headers().size(); i++) {
            headers.add(request.headers().name(i), request.headers().value(i));
        }
        return new XgRequest.Builder().url(request.url().toString()).headers(headers.build())
                .method(request.method(), null).build();
    }

    static Headers headers(XgHeaders source) {
        Headers.Builder headers = new Headers.Builder();
        source.toMultimap().forEach((name, values) -> values.forEach(value -> headers.add(name, value)));
        return headers.build();
    }

    public static Request apply(Request original, XgRequest metadata) {
        return original.newBuilder().url(metadata.url().toString()).headers(headers(metadata.headers())).build();
    }

    static Response interceptRequest(Interceptor.Chain chain) throws IOException {
        XgRequest request = XgHttp.requestInterceptor().intercept(metadata(chain.request()));
        request = XgHttp.authInterceptor().intercept(request);
        return chain.proceed(apply(chain.request(), request));
    }

    static Response interceptResponse(Interceptor.Chain chain) throws IOException {
        Request request = apply(chain.request(), XgHttp.responseInterceptor().intercept(metadata(chain.request())));
        Response response = chain.proceed(request);
        String location = response.header("Location");
        if (response.code() == 302 && location != null) {
            HttpUrl resolved = request.url().resolve(location);
            if (resolved != null) XgHttp.responseInterceptor().rememberRedirect(resolved.toString(), request.url().toString());
        }
        if (response.code() == 406) {
            String source = XgHttp.responseInterceptor().fallbackRedirect(request.url().toString());
            if (source != null) return response.newBuilder().code(302).message("Found").header("Location", source).build();
        }
        return response;
    }

    static Request authenticate(Route route, Response response) {
        int challenges = 0;
        for (Response item = response; item != null; item = item.priorResponse()) {
            if (item.code() == 401) challenges++;
        }
        if (challenges > 1) return null;
        XgRequest retry = XgHttp.authInterceptor().authenticate(metadata(response.request()), response.header("WWW-Authenticate"));
        return retry == null ? null : apply(response.request(), retry);
    }

    static CookieJar cookies(XgCookieJar jar) {
        return new CookieJar() {
            @Override public List<Cookie> loadForRequest(HttpUrl url) {
                List<Cookie> result = new ArrayList<>();
                XgUrl target = XgUrl.require(url.toString());
                for (XgCookie cookie : jar.loadForRequest(target)) {
                    if (!cookie.matches(target) || cookie.expiresAt() <= System.currentTimeMillis()) continue;
                    Cookie.Builder value = new Cookie.Builder().name(cookie.name()).value(cookie.value()).path(cookie.path());
                    if (cookie.hostOnly()) value.hostOnlyDomain(cookie.domain()); else value.domain(cookie.domain());
                    if (cookie.persistent()) value.expiresAt(cookie.expiresAt());
                    if (cookie.secure()) value.secure();
                    if (cookie.httpOnly()) value.httpOnly();
                    result.add(value.build());
                }
                return result;
            }
            @Override public void saveFromResponse(HttpUrl url, List<Cookie> cookies) {
                List<XgCookie> result = new ArrayList<>();
                for (Cookie cookie : cookies) {
                    result.add(new XgCookie(cookie.name(), cookie.value(), cookie.domain(), cookie.path(), cookie.expiresAt(),
                            cookie.secure(), cookie.httpOnly(), cookie.hostOnly(), cookie.persistent()));
                }
                jar.saveFromResponse(XgUrl.require(url.toString()), result);
            }
        };
    }
}
