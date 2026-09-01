package com.github.catvod.net;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

public final class XgMultipartBody extends XgRequestBody {

    private XgMultipartBody(String boundary, List<String[]> values) {
        super(encode(boundary, values), "multipart/form-data; boundary=" + boundary);
    }

    private static byte[] encode(String boundary, List<String[]> values) {
        try (ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            for (String[] value : values) {
                output.write(("--" + boundary + "\r\n").getBytes(StandardCharsets.UTF_8));
                output.write(("Content-Disposition: form-data; name=\"" + value[0].replace("\"", "%22") + "\"\r\n\r\n").getBytes(StandardCharsets.UTF_8));
                output.write(value[1].getBytes(StandardCharsets.UTF_8));
                output.write("\r\n".getBytes(StandardCharsets.UTF_8));
            }
            output.write(("--" + boundary + "--\r\n").getBytes(StandardCharsets.UTF_8));
            return output.toByteArray();
        } catch (IOException e) {
            throw new IllegalStateException(e);
        }
    }

    public static final class Builder {

        private final String boundary;
        private final List<String[]> values = new ArrayList<>();

        public Builder(String boundary) {
            this.boundary = boundary;
        }

        public Builder addFormDataPart(String name, String value) {
            values.add(new String[]{name == null ? "" : name, value == null ? "" : value});
            return this;
        }

        public XgMultipartBody build() {
            return new XgMultipartBody(boundary, values);
        }
    }
}
