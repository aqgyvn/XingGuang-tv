package com.fongmi.android.tv.impl;

import androidx.annotation.NonNull;

import com.github.catvod.net.XgHttp;
import com.github.catvod.net.XgRequest;
import com.github.catvod.net.XgRequestBody;
import com.github.catvod.net.XgResponse;

import org.schabi.newpipe.extractor.downloader.Downloader;
import org.schabi.newpipe.extractor.downloader.Request;
import org.schabi.newpipe.extractor.downloader.Response;
import org.schabi.newpipe.extractor.exceptions.ReCaptchaException;

import java.io.IOException;
import java.util.List;
import java.util.Map;

public final class NewPipeImpl extends Downloader {

    public static final String USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0";

    private static class Loader {
        static volatile NewPipeImpl INSTANCE = new NewPipeImpl();
    }

    public static NewPipeImpl get() {
        return Loader.INSTANCE;
    }

    @Override
    public Response execute(@NonNull Request request) throws IOException, ReCaptchaException {
        String httpMethod = request.httpMethod();
        String url = request.url();
        Map<String, List<String>> headers = request.headers();
        byte[] dataToSend = request.dataToSend();

        XgRequestBody requestBody = null;
        if (dataToSend != null) {
            requestBody = XgRequestBody.create(dataToSend);
        }

        XgRequest.Builder requestBuilder = new XgRequest.Builder().method(httpMethod, requestBody).url(url).addHeader("User-Agent", USER_AGENT);

        for (Map.Entry<String, List<String>> pair : headers.entrySet()) {
            String headerName = pair.getKey();
            List<String> headerValueList = pair.getValue();
            if (headerValueList.size() > 1) {
                for (String headerValue : headerValueList) {
                    requestBuilder.addHeader(headerName, headerValue);
                }
            } else if (headerValueList.size() == 1) {
                requestBuilder.header(headerName, headerValueList.get(0));
            }
        }

        try (XgResponse response = XgHttp.xgClient().newCall(requestBuilder.build()).execute()) {
            if (response.code() == 429) throw new ReCaptchaException("reCaptcha Challenge requested", url);
            String responseBodyToReturn = response.body().string();
            String latestUrl = response.url().toString();
            return new Response(response.code(), response.message(), response.headers().toMultimap(), responseBodyToReturn, latestUrl);
        }
    }
}
