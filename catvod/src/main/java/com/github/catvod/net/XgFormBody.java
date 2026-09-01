package com.github.catvod.net;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

public final class XgFormBody extends XgRequestBody {

    private XgFormBody(List<String[]> values) {
        super(encode(values).getBytes(StandardCharsets.UTF_8), "application/x-www-form-urlencoded");
    }

    private static String encode(List<String[]> values) {
        StringBuilder result = new StringBuilder();
        for (String[] value : values) {
            if (result.length() > 0) result.append('&');
            result.append(URLEncoder.encode(value[0], StandardCharsets.UTF_8));
            result.append('=').append(URLEncoder.encode(value[1], StandardCharsets.UTF_8));
        }
        return result.toString();
    }

    public static final class Builder {

        private final List<String[]> values = new ArrayList<>();

        public Builder add(String name, String value) {
            values.add(new String[]{name == null ? "" : name, value == null ? "" : value});
            return this;
        }

        public XgFormBody build() {
            return new XgFormBody(values);
        }
    }
}
