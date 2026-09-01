package com.fongmi.android.tv.player.extractor;

import android.net.Uri;

import com.fongmi.android.tv.player.Source;
import com.fongmi.android.tv.utils.UrlUtil;
import com.github.catvod.net.XgHttp;
import com.github.catvod.net.XgResponse;
import com.github.catvod.utils.Path;
import com.google.common.net.HttpHeaders;

import java.io.File;

public class Strm implements Source.Extractor {

    @Override
    public boolean match(Uri uri) {
        return UrlUtil.path(uri).endsWith(".strm");
    }

    @Override
    public String fetch(String url) throws Exception {
        if (url.startsWith("http")) return http(url);
        if (url.startsWith("file")) url = url.substring(7);
        return Path.read(new File(url)).split("\\R", 2)[0];
    }

    private String http(String url) throws Exception {
        try (XgResponse res = XgHttp.call(XgHttp.xgNoRedirect(), url).execute()) {
            String content = res.header(HttpHeaders.CONTENT_DISPOSITION, "");
            boolean text = content.contains(".strm") || content.contains(".txt");
            return text ? res.body().string().split("\\R", 2)[0] : url;
        }
    }

    @Override
    public void stop() {
    }

    @Override
    public void exit() {
    }
}
